# Distributed Training Guide

**VIBEE v2104-v2111, v2169-v2175 | Scaling to Multiple GPUs**

---

## Overview

Distributed training enables training models that don't fit on a single GPU and accelerates training through parallelism.

---

## 1. Parallelism Strategies

```
┌─────────────────────────────────────────────────────────┐
│              PARALLELISM STRATEGIES                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Data Parallel (DP)                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                       │
│  │GPU 0│ │GPU 1│ │GPU 2│ │GPU 3│  Same model,         │
│  │Batch│ │Batch│ │Batch│ │Batch│  different data      │
│  │ 0   │ │ 1   │ │ 2   │ │ 3   │                       │
│  └─────┘ └─────┘ └─────┘ └─────┘                       │
│                                                         │
│  Tensor Parallel (TP)                                   │
│  ┌─────────────────────────────────┐                   │
│  │         Single Layer            │                   │
│  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │  Split weights    │
│  │  │G0 │ │G1 │ │G2 │ │G3 │       │  across GPUs      │
│  │  └───┘ └───┘ └───┘ └───┘       │                   │
│  └─────────────────────────────────┘                   │
│                                                         │
│  Pipeline Parallel (PP)                                 │
│  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐                │
│  │GPU 0│──▶│GPU 1│──▶│GPU 2│──▶│GPU 3│  Different     │
│  │L1-4 │   │L5-8 │   │L9-12│   │L13-16│ layers        │
│  └─────┘   └─────┘   └─────┘   └─────┘                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. ZeRO Optimization

### ZeRO Stages

```
┌─────────────────────────────────────────────────────────┐
│                    ZeRO STAGES                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Baseline (No ZeRO):                                    │
│  Each GPU: [Params] [Gradients] [Optimizer States]     │
│  Memory: 16 bytes/param (FP32)                         │
│                                                         │
│  ZeRO Stage 1 (Optimizer Sharding):                    │
│  GPU 0: [P] [G] [O_0]    GPU 1: [P] [G] [O_1]         │
│  Memory: 4x reduction in optimizer states              │
│                                                         │
│  ZeRO Stage 2 (+ Gradient Sharding):                   │
│  GPU 0: [P] [G_0] [O_0]  GPU 1: [P] [G_1] [O_1]       │
│  Memory: 8x reduction                                  │
│                                                         │
│  ZeRO Stage 3 (+ Parameter Sharding):                  │
│  GPU 0: [P_0] [G_0] [O_0]  GPU 1: [P_1] [G_1] [O_1]   │
│  Memory: Linear scaling with GPUs                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### DeepSpeed ZeRO

```python
# deepspeed_config.json
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {"device": "cpu"},
        "offload_param": {"device": "cpu"},
        "overlap_comm": true,
        "contiguous_gradients": true,
        "reduce_bucket_size": 5e8
    }
}
```

---

## 3. FSDP (PyTorch Native)

```python
from torch.distributed.fsdp import (
    FullyShardedDataParallel as FSDP,
    MixedPrecision,
    ShardingStrategy,
)

# Wrap model
model = FSDP(
    model,
    sharding_strategy=ShardingStrategy.FULL_SHARD,  # ZeRO-3
    mixed_precision=MixedPrecision(
        param_dtype=torch.bfloat16,
        reduce_dtype=torch.bfloat16,
        buffer_dtype=torch.bfloat16,
    ),
    device_id=torch.cuda.current_device(),
    use_orig_params=True,  # For torch.compile
)
```

### Sharding Strategies

| Strategy | Memory | Communication |
|----------|--------|---------------|
| NO_SHARD | Highest | Lowest |
| SHARD_GRAD_OP | Medium | Medium |
| FULL_SHARD | Lowest | Highest |
| HYBRID_SHARD | Balanced | Balanced |

---

## 4. Tensor Parallelism

```python
# Megatron-style column parallel
class ColumnParallelLinear:
    def __init__(self, in_features, out_features, world_size):
        self.weight = nn.Parameter(
            torch.empty(out_features // world_size, in_features)
        )
    
    def forward(self, x):
        # Each GPU computes partial output
        local_output = F.linear(x, self.weight)
        # All-gather to combine
        return all_gather(local_output)
```

### When to Use TP

- Single node with NVLink (fast interconnect)
- Very large layers that don't fit on one GPU
- Typically TP=2, 4, or 8 within a node

---

## 5. Pipeline Parallelism

```python
# GPipe-style micro-batching
def gpipe_forward(model_chunks, micro_batches):
    # Forward pass
    for mb in micro_batches:
        for chunk in model_chunks:
            mb = chunk(mb)
    
    # Backward pass (reverse order)
    for mb in reversed(micro_batches):
        for chunk in reversed(model_chunks):
            chunk.backward(mb)
```

### Pipeline Schedules

| Schedule | Bubble | Memory |
|----------|--------|--------|
| GPipe | High | Low |
| 1F1B | Medium | Medium |
| Interleaved | Low | Higher |
| Zero Bubble | Minimal | Highest |

---

## 6. Communication Optimization

### All-Reduce Algorithms

```
Ring All-Reduce:
GPU0 ──▶ GPU1 ──▶ GPU2 ──▶ GPU3
  ▲                          │
  └──────────────────────────┘

Tree All-Reduce:
    GPU0
   /    \
GPU1    GPU2
  |       |
GPU3    GPU4
```

### Gradient Compression

```python
# Top-K compression
def compress_gradient(grad, k=0.01):
    flat = grad.flatten()
    k_elements = int(len(flat) * k)
    values, indices = torch.topk(flat.abs(), k_elements)
    return values, indices

# Random sparsification
def random_sparse(grad, p=0.01):
    mask = torch.rand_like(grad) < p
    return grad * mask / p
```

---

## 7. Hybrid Parallelism

### 3D Parallelism (DP + TP + PP)

```
┌─────────────────────────────────────────────────────────┐
│                  3D PARALLELISM                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Node 0 (TP=4)          Node 1 (TP=4)                  │
│  ┌───┬───┬───┬───┐      ┌───┬───┬───┬───┐             │
│  │G0 │G1 │G2 │G3 │      │G4 │G5 │G6 │G7 │  PP Stage 0 │
│  └───┴───┴───┴───┘      └───┴───┴───┴───┘             │
│         │                      │                        │
│         ▼                      ▼                        │
│  ┌───┬───┬───┬───┐      ┌───┬───┬───┬───┐             │
│  │G8 │G9 │G10│G11│      │G12│G13│G14│G15│  PP Stage 1 │
│  └───┴───┴───┴───┘      └───┴───┴───┴───┘             │
│                                                         │
│  DP across nodes with same PP stage                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Configuration Example

```python
# 64 GPUs total
# 8 nodes × 8 GPUs per node

TP = 4   # Within node (NVLink)
PP = 2   # Across 2 stages
DP = 8   # 64 / (4 * 2) = 8 replicas
```

---

## 8. Fault Tolerance

### Checkpointing Strategy

```python
# Async checkpointing
def async_checkpoint(model, path):
    state = model.state_dict()
    thread = threading.Thread(
        target=torch.save,
        args=(state, path)
    )
    thread.start()
    return thread

# Sharded checkpointing
from torch.distributed.checkpoint import save, load

save(
    state_dict=model.state_dict(),
    storage_writer=FileSystemWriter(path),
)
```

### Elastic Training

```python
# torchrun with elastic
torchrun \
    --nnodes=1:4 \
    --nproc_per_node=8 \
    --rdzv_backend=c10d \
    --rdzv_endpoint=master:29500 \
    train.py
```

---

## 9. Best Practices

### Memory Estimation

```python
# Per-GPU memory for training
def estimate_memory(params_b, precision="bf16"):
    bytes_per_param = 2 if precision == "bf16" else 4
    
    # Model weights
    model_mem = params_b * bytes_per_param
    
    # Gradients
    grad_mem = params_b * bytes_per_param
    
    # Optimizer states (AdamW)
    opt_mem = params_b * 8  # m and v in FP32
    
    # Activations (rough estimate)
    act_mem = params_b * 2 * bytes_per_param
    
    return model_mem + grad_mem + opt_mem + act_mem
```

### Scaling Efficiency

```
Ideal: Linear speedup with GPUs
Reality: Communication overhead

Efficiency = (Time_1GPU / Time_NGPU) / N

Target: >80% efficiency
```

---

## References

- Rajbhandari et al. (2020): ZeRO
- Zhao et al. (2023): PyTorch FSDP
- Shoeybi et al. (2019): Megatron-LM
- Narayanan et al. (2021): Efficient Large-Scale Training

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
