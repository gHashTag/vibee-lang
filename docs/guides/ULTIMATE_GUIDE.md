# VIBEE ML Ultimate Guide

**The Complete Reference for LLM Training and Inference**

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Training](#training)
3. [Inference](#inference)
4. [Optimizers](#optimizers)
5. [Safety](#safety)
6. [Data Processing](#data-processing)
7. [Deployment](#deployment)
8. [Best Practices](#best-practices)

---

## Quick Start

### Installation

```bash
# Basic
pip install vibee-ml

# Full installation
pip install vibee-ml[all]
```

### 5-Minute Training Setup

```python
from vibee_ml import TrainingAccelerator, Lion

# Initialize accelerator
accelerator = TrainingAccelerator(
    mixed_precision="bf16",
    gradient_checkpointing=True,
    flash_attention=True,
)

# Prepare model
model = accelerator.prepare(model)
optimizer = Lion(model.parameters(), lr=1e-4)

# Training loop
for batch in dataloader:
    with accelerator.autocast():
        loss = model(batch)
    accelerator.backward(loss)
    accelerator.step(optimizer)
    accelerator.zero_grad(optimizer)
```

---

## Training

### Memory Optimization Hierarchy

1. **BF16 Mixed Precision** - 50% memory reduction
2. **Gradient Checkpointing** - Trade compute for memory
3. **Flash Attention** - O(N) memory attention
4. **ZeRO Stage 3** - Shard everything across GPUs

### Recommended Configuration

```python
config = {
    "mixed_precision": "bf16",
    "gradient_checkpointing": True,
    "flash_attention": True,
    "compile_model": True,
    "max_grad_norm": 1.0,
}
```

---

## Inference

### Quantization Guide

| Method | Memory | Quality | Speed |
|--------|--------|---------|-------|
| FP16 | 100% | 100% | 1.0x |
| INT8 | 50% | 99.5% | 2.0x |
| INT4 AWQ | 25% | 98.5% | 3.0x |
| INT4 GPTQ | 25% | 98.2% | 2.8x |

### Serving with vLLM

```bash
vibee-serve --model meta-llama/Llama-2-7b-chat-hf \
    --port 8000 \
    --tensor-parallel 2 \
    --gpu-memory-utilization 0.9
```

---

## Optimizers

### Lion (Recommended)

- 33% less memory than AdamW
- Use 3-10x smaller LR
- Use 3-10x larger weight decay

```python
from vibee_ml import Lion

optimizer = Lion(
    model.parameters(),
    lr=1e-5,  # 10x smaller than AdamW
    weight_decay=0.1,  # 10x larger than AdamW
)
```

### Sophia (Faster Convergence)

- 2x faster convergence claimed
- Higher compute per step
- Good for large models

### Schedule-Free AdamW

- No learning rate schedule needed
- Simpler hyperparameter tuning

---

## Safety

### Guardrails

```python
from vibee_ml import Guardrails, GuardrailConfig

guardrails = Guardrails(GuardrailConfig(
    pii_detection=True,
    max_output_length=4096,
))

result = guardrails.check_output(response)
if not result.passed:
    print(f"Blocked: {result.violations}")
```

### Content Filtering

```python
from vibee_ml import ContentFilter

filter = ContentFilter()
result = filter.check(text)
if result.blocked:
    print(f"Toxic content: {result.category}")
```

---

## Data Processing

### Deduplication

```python
from vibee_ml import deduplicate

# MinHash-based near-duplicate removal
unique_texts = deduplicate(texts, method="minhash")
```

### Quality Filtering

```python
from vibee_ml import filter_quality

clean_texts = filter_quality(
    texts,
    min_length=50,
    min_unique_ratio=0.3,
)
```

### Sequence Packing

```python
from vibee_ml import pack_sequences

packed = pack_sequences(
    tokenized_sequences,
    max_seq_length=4096,
)
# Efficiency: 95%+ token utilization
```

---

## Deployment

### Docker

```bash
# Build
docker build -f tools/docker/Dockerfile.inference -t vibee-inference .

# Run
docker run --gpus all -p 8000:8000 vibee-inference
```

### Kubernetes

```bash
kubectl apply -f tools/k8s/deployment.yaml
```

Features:
- Auto-scaling (1-10 replicas)
- Health checks
- GPU scheduling

---

## Best Practices

### Training Checklist

- [ ] Use BF16 mixed precision
- [ ] Enable gradient checkpointing
- [ ] Enable Flash Attention
- [ ] Use Lion or AdamW optimizer
- [ ] Set max_grad_norm=1.0
- [ ] Use sequence packing
- [ ] Deduplicate training data

### Inference Checklist

- [ ] Quantize to INT8 or INT4
- [ ] Use vLLM or TGI for serving
- [ ] Enable KV cache
- [ ] Use continuous batching
- [ ] Set appropriate batch size
- [ ] Monitor latency P99

### Safety Checklist

- [ ] Enable PII detection
- [ ] Add content filtering
- [ ] Set output length limits
- [ ] Log all interactions
- [ ] Implement rate limiting

---

## Sacred Constants

```
φ = 1.618033988749895
φ² + 1/φ² = 3
PHOENIX = 999
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
