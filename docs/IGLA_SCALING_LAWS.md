# iGLA Scaling Laws

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Chinchilla Scaling Laws

### Compute-Optimal Training

The Chinchilla paper (Hoffmann et al., 2022) established:

```
D_opt ≈ 20 × N
```

Where:
- N = number of parameters
- D = number of training tokens
- D_opt = optimal tokens for compute budget

### Optimal Token Counts

| Model Size | Parameters | Optimal Tokens |
|------------|------------|----------------|
| 1B | 1,000,000,000 | 20B |
| 7B | 7,000,000,000 | 140B |
| 13B | 13,000,000,000 | 260B |
| 34B | 34,000,000,000 | 680B |
| 70B | 70,000,000,000 | 1.4T |
| 175B | 175,000,000,000 | 3.5T |

### Loss Scaling

```
L(N, D) = E + A/N^α + B/D^β

Where:
- E ≈ 1.69 (irreducible loss)
- A ≈ 406.4
- B ≈ 410.7
- α ≈ 0.34
- β ≈ 0.28
```

## Compute Budget

### FLOPs Estimation

```
C ≈ 6 × N × D

Where:
- C = total FLOPs
- N = parameters
- D = tokens
- 6 = forward + backward passes
```

### GPU Hours

```
GPU_hours = C / (GPU_TFLOPS × 3600 × utilization)

A100 (80GB): ~312 TFLOPS (BF16)
H100 (80GB): ~989 TFLOPS (BF16)
```

| Model | Tokens | FLOPs | A100 Hours | H100 Hours |
|-------|--------|-------|------------|------------|
| 7B | 140B | 5.9e21 | 10,500 | 3,300 |
| 13B | 260B | 2.0e22 | 35,700 | 11,200 |
| 34B | 680B | 1.4e23 | 249,000 | 78,500 |
| 70B | 1.4T | 5.9e23 | 1,050,000 | 331,000 |

## Learning Rate Scaling

### Linear Scaling Rule

```
lr_scaled = lr_base × (batch_size / base_batch_size)
```

### Square Root Scaling

```
lr_scaled = lr_base × sqrt(batch_size / base_batch_size)
```

### Recommended LR by Model Size

| Model | Base LR | Min LR |
|-------|---------|--------|
| 7B | 3e-4 | 3e-5 |
| 13B | 2e-4 | 2e-5 |
| 34B | 1.5e-4 | 1.5e-5 |
| 70B | 1e-4 | 1e-5 |

## Batch Size Scaling

### Critical Batch Size

```
B_crit ≈ B_noise / L

Where:
- B_noise ≈ 2e8 (noise scale)
- L = current loss
```

### Recommended Batch Sizes

| Model | Tokens/Batch | Sequences (2K) |
|-------|--------------|----------------|
| 7B | 4M | 2,000 |
| 13B | 4M | 2,000 |
| 34B | 8M | 4,000 |
| 70B | 16M | 8,000 |

## Context Length Scaling

### Memory Scaling

```
Memory ∝ seq_length² (standard attention)
Memory ∝ seq_length (Flash Attention)
Memory ∝ seq_length/num_devices (Ring Attention)
```

### Compute Scaling

```
FLOPs ∝ seq_length² (attention)
FLOPs ∝ seq_length (FFN)
```

## KOSHEY Scaling Benefits

### Ring Attention

```
# Standard: O(seq²) memory per device
# Ring: O(seq²/num_devices) memory per device

# 8 GPUs, 128K context:
# Standard: 128K² = 16B elements (impossible)
# Ring: 16K² = 256M elements (feasible)
```

### EWC Scaling

```
# Memory overhead: O(N) for Fisher matrix diagonal
# Compute overhead: O(N) per step
# Benefit: No catastrophic forgetting
```

## Practical Guidelines

### 1. Start Small
- Train 1B model first
- Validate pipeline
- Scale up gradually

### 2. Monitor Metrics
- Loss curve
- Gradient norm
- Learning rate
- GPU utilization

### 3. Checkpoint Frequently
- Every 1000 steps minimum
- Keep last 5 checkpoints
- Save optimizer state

### 4. Use Mixed Precision
- BF16 for training
- FP32 for accumulation
- 2x memory savings

## Sacred Scaling

### Golden Ratio in Scaling

```
φ = 1.618033988749895

# Layer scaling
hidden_next = hidden × φ

# Depth scaling
layers_next = layers × φ

# Width scaling
heads_next = heads × φ
```

### Trinity Principle

```
# Three-phase training:
# 1. Warmup (φ% of steps)
# 2. Main training (φ² × steps)
# 3. Cooldown (1/φ × steps)
```
