# Memory Optimization Guide

**VIBEE v2100-v2111 | Training Larger Models on Limited Hardware**

---

## Overview

Memory is often the primary bottleneck for LLM training. This guide covers techniques to reduce memory usage while maintaining training quality.

---

## 1. Memory Breakdown

```
┌─────────────────────────────────────────────────────────┐
│           GPU MEMORY DURING TRAINING                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  7B Model (FP32):                                       │
│  ┌─────────────────────────────────────────────┐       │
│  │ Model Parameters      │  28 GB (7B × 4 bytes)│       │
│  ├───────────────────────┼─────────────────────┤       │
│  │ Gradients             │  28 GB              │       │
│  ├───────────────────────┼─────────────────────┤       │
│  │ Optimizer States      │  56 GB (AdamW m,v)  │       │
│  ├───────────────────────┼─────────────────────┤       │
│  │ Activations           │  Variable (batch)   │       │
│  └───────────────────────┴─────────────────────┘       │
│                                                         │
│  Total: 112 GB + Activations                           │
│  (Doesn't fit on single 80GB A100!)                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Mixed Precision Training

### BF16 Training

```python
# PyTorch native
model = model.to(torch.bfloat16)

# Or with autocast
with torch.autocast(device_type='cuda', dtype=torch.bfloat16):
    output = model(input)
    loss = criterion(output, target)

# Gradients in FP32 for stability
scaler = torch.cuda.amp.GradScaler()
scaler.scale(loss).backward()
scaler.step(optimizer)
scaler.update()
```

### Memory Savings

```
FP32: 4 bytes/param → 28 GB for 7B
BF16: 2 bytes/param → 14 GB for 7B
FP8:  1 byte/param  → 7 GB for 7B (H100)
```

---

## 3. Gradient Checkpointing

### How It Works

```
Without checkpointing:
Forward:  [A1] → [A2] → [A3] → [A4] → Loss
          Keep all activations in memory

With checkpointing:
Forward:  [A1] → [A2] → [A3] → [A4] → Loss
          Only keep checkpointed activations
Backward: Recompute A2, A3 from A1 when needed
```

### Implementation

```python
from torch.utils.checkpoint import checkpoint

class TransformerBlock(nn.Module):
    def forward(self, x):
        # Checkpoint this block
        return checkpoint(self._forward, x, use_reentrant=False)
    
    def _forward(self, x):
        x = x + self.attention(self.norm1(x))
        x = x + self.mlp(self.norm2(x))
        return x
```

### Selective Checkpointing

```python
def selective_checkpoint(model, checkpoint_ratio=0.5):
    """Checkpoint every other layer."""
    for i, layer in enumerate(model.layers):
        if i % 2 == 0:
            layer.use_checkpoint = True
```

### Trade-offs

| Checkpoint Ratio | Memory Savings | Compute Overhead |
|------------------|----------------|------------------|
| 0% (none) | 0% | 0% |
| 50% | 40-50% | 15-20% |
| 100% (all) | 60-80% | 30-40% |

---

## 4. Activation Compression

### Quantized Activations

```python
def compress_activation(tensor):
    """Compress to INT8 for storage."""
    scale = tensor.abs().max() / 127
    quantized = (tensor / scale).round().to(torch.int8)
    return quantized, scale

def decompress_activation(quantized, scale):
    """Decompress back to FP16."""
    return quantized.to(torch.float16) * scale
```

### Memory Savings

- INT8 activations: 50% reduction
- Combined with checkpointing: 70-80% reduction

---

## 5. Optimizer State Optimization

### Adam-mini

```python
# Standard AdamW: 12 bytes/param
# Adam-mini: 6 bytes/param (shared states)

class AdamMini:
    def __init__(self, params, lr=1e-4):
        # Share m, v across parameters in same layer
        self.shared_states = {}
```

### 8-bit Optimizers

```python
import bitsandbytes as bnb

optimizer = bnb.optim.Adam8bit(
    model.parameters(),
    lr=1e-4,
    betas=(0.9, 0.999)
)
# 8 bytes/param instead of 12
```

### Lion Optimizer

```python
from lion_pytorch import Lion

optimizer = Lion(model.parameters(), lr=1e-4)
# 8 bytes/param (no v state)
```

---

## 6. ZeRO Memory Savings

### Per-GPU Memory

```
8 GPUs, 7B model, BF16:

No ZeRO:
  Params: 14 GB × 8 = 112 GB total (14 GB each)
  Grads:  14 GB × 8 = 112 GB total
  Opt:    28 GB × 8 = 224 GB total
  Per GPU: 56 GB

ZeRO-1 (Optimizer Sharding):
  Params: 14 GB each
  Grads:  14 GB each
  Opt:    28 GB / 8 = 3.5 GB each
  Per GPU: 31.5 GB

ZeRO-2 (+ Gradient Sharding):
  Params: 14 GB each
  Grads:  14 GB / 8 = 1.75 GB each
  Opt:    3.5 GB each
  Per GPU: 19.25 GB

ZeRO-3 (+ Parameter Sharding):
  Params: 14 GB / 8 = 1.75 GB each
  Grads:  1.75 GB each
  Opt:    3.5 GB each
  Per GPU: 7 GB
```

---

## 7. Offloading

### CPU Offload

```python
# DeepSpeed ZeRO-Offload
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "cpu",
            "pin_memory": true
        },
        "offload_param": {
            "device": "cpu",
            "pin_memory": true
        }
    }
}
```

### NVMe Offload

```python
# For even larger models
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "nvme",
            "nvme_path": "/local_nvme"
        }
    }
}
```

### Trade-offs

| Offload Target | Memory Savings | Speed Impact |
|----------------|----------------|--------------|
| None | 0% | Baseline |
| CPU | 50-80% | 2-3x slower |
| NVMe | 90%+ | 5-10x slower |

---

## 8. Memory-Efficient Attention

### Flash Attention

```python
from flash_attn import flash_attn_func

# O(N) memory instead of O(N²)
output = flash_attn_func(q, k, v, causal=True)
```

### Memory Comparison

```
Standard Attention (seq_len=8192):
  Attention matrix: 8192 × 8192 × 4 bytes = 256 MB per head
  32 heads = 8 GB per layer!

Flash Attention:
  No materialized attention matrix
  O(N) memory = ~100 MB per layer
```

---

## 9. Practical Configurations

### 7B Model on Single 24GB GPU

```python
config = {
    "precision": "bf16",
    "gradient_checkpointing": True,
    "batch_size": 1,
    "gradient_accumulation": 16,
    "optimizer": "8bit_adam",
    "flash_attention": True,
}
# Effective batch size: 16
# Memory: ~20 GB
```

### 70B Model on 8× 80GB GPUs

```python
config = {
    "precision": "bf16",
    "zero_stage": 3,
    "gradient_checkpointing": True,
    "batch_size": 1,
    "gradient_accumulation": 8,
    "flash_attention": True,
    "sequence_length": 4096,
}
# Per-GPU memory: ~60 GB
```

### 405B Model on 128× H100s

```python
config = {
    "precision": "fp8",
    "tensor_parallel": 8,
    "pipeline_parallel": 4,
    "data_parallel": 4,
    "zero_stage": 1,
    "gradient_checkpointing": True,
    "flash_attention_3": True,
}
```

---

## 10. Memory Debugging

### PyTorch Memory Profiler

```python
import torch.cuda

# Track allocations
torch.cuda.memory._record_memory_history()

# Training step
output = model(input)
loss.backward()

# Get snapshot
snapshot = torch.cuda.memory._snapshot()
torch.cuda.memory._dump_snapshot("memory.pickle")
```

### Common Issues

1. **Memory leak**: Tensors not freed
   - Solution: `del tensor; torch.cuda.empty_cache()`

2. **Fragmentation**: Many small allocations
   - Solution: Use memory pools, larger batch sizes

3. **Peak during backward**: Gradients + activations
   - Solution: Gradient checkpointing

---

## References

- Micikevicius et al. (2018): Mixed Precision Training
- Chen et al. (2016): Gradient Checkpointing
- Rajbhandari et al. (2020): ZeRO
- Dao et al. (2022): FlashAttention

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
