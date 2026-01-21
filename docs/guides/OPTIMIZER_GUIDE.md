# Optimizer Selection Guide

**VIBEE v2130-v2145 | Choosing the Right Optimizer**

---

## Overview

Optimizer choice significantly impacts training speed, memory usage, and final model quality. This guide covers modern optimizers and when to use them.

---

## 1. Optimizer Comparison

| Optimizer | Memory/Param | Convergence | Best For |
|-----------|--------------|-------------|----------|
| AdamW | 12 bytes | Baseline | General |
| Lion | 8 bytes | Faster | Large models |
| Sophia | 12 bytes | 2x faster | Research |
| Adam-mini | 6 bytes | Similar | Memory-limited |
| Schedule-Free | 8 bytes | No tuning | Simplicity |
| Muon | 8 bytes | Fast | Hidden layers |
| Shampoo | 16+ bytes | Large batch | Distributed |

---

## 2. AdamW (Baseline)

```python
optimizer = torch.optim.AdamW(
    model.parameters(),
    lr=1e-4,
    betas=(0.9, 0.999),
    eps=1e-8,
    weight_decay=0.01
)
```

**Memory**: 12 bytes/param (m, v, param)
**When to use**: Default choice, well-understood

---

## 3. Lion (Google Brain)

```python
# pip install lion-pytorch
from lion_pytorch import Lion

optimizer = Lion(
    model.parameters(),
    lr=1e-4,  # Use 3-10x smaller than AdamW
    betas=(0.9, 0.99),
    weight_decay=0.1  # Use 3-10x larger than AdamW
)
```

**Memory**: 8 bytes/param (m, param only)
**Key insight**: Sign of momentum, not magnitude
**When to use**: Large models, memory-constrained

---

## 4. Sophia (Second-Order)

```python
# Approximate Hessian diagonal
optimizer = Sophia(
    model.parameters(),
    lr=1e-4,
    betas=(0.965, 0.99),
    rho=0.04,
    weight_decay=0.1
)
```

**Memory**: 12 bytes/param
**Key insight**: Uses Hessian diagonal for adaptive LR
**When to use**: Research, 2x faster convergence claimed

---

## 5. Adam-mini

```python
# Shares optimizer states across parameters
optimizer = AdamMini(
    model.parameters(),
    lr=1e-4,
    betas=(0.9, 0.999),
    weight_decay=0.01
)
```

**Memory**: 6 bytes/param (shared statistics)
**Key insight**: Parameters in same layer share states
**When to use**: Extreme memory constraints

---

## 6. Schedule-Free

```python
from schedulefree import AdamWScheduleFree

optimizer = AdamWScheduleFree(
    model.parameters(),
    lr=1e-3,  # Higher LR, no schedule needed
    betas=(0.9, 0.999),
    weight_decay=0.01
)

# Training loop
optimizer.train()  # Before training
# ... training ...
optimizer.eval()   # Before evaluation
```

**Memory**: 8 bytes/param
**Key insight**: No learning rate schedule needed
**When to use**: Simplicity, less hyperparameter tuning

---

## 7. Learning Rate Scheduling

### Cosine Annealing
```python
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
    optimizer,
    T_max=total_steps,
    eta_min=1e-6
)
```

### Warmup + Cosine Decay (WSD)
```python
def get_lr(step, warmup_steps, total_steps, max_lr, min_lr):
    if step < warmup_steps:
        return max_lr * step / warmup_steps
    progress = (step - warmup_steps) / (total_steps - warmup_steps)
    return min_lr + 0.5 * (max_lr - min_lr) * (1 + cos(pi * progress))
```

### Linear Warmup
```python
warmup_steps = int(0.03 * total_steps)  # 3% warmup
```

---

## 8. Gradient Clipping

```python
# Norm clipping (recommended)
torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)

# Value clipping (less common)
torch.nn.utils.clip_grad_value_(model.parameters(), clip_value=1.0)
```

**When to use**: Always for LLM training, prevents exploding gradients

---

## 9. Weight Decay

```python
# Decoupled weight decay (AdamW)
# Applied directly to weights, not through gradient

# Typical values:
# - Small models: 0.01
# - Large models: 0.1
# - With Lion: 0.1-0.3 (higher than AdamW)
```

---

## 10. Decision Tree

```
Start
  │
  ├─ Memory constrained?
  │   ├─ Yes → Adam-mini or Lion
  │   └─ No → Continue
  │
  ├─ Want simplicity?
  │   ├─ Yes → Schedule-Free AdamW
  │   └─ No → Continue
  │
  ├─ Large batch distributed?
  │   ├─ Yes → Shampoo
  │   └─ No → Continue
  │
  ├─ Research/experimental?
  │   ├─ Yes → Sophia
  │   └─ No → Continue
  │
  └─ Default → AdamW with cosine schedule
```

---

## 11. Hyperparameter Transfer (muP)

```python
# Train small model, transfer hyperparameters to large model
# Key: Use muP parameterization

# Small model (128M)
small_lr = 1e-3
small_wd = 0.1

# Large model (7B) - same hyperparameters work!
large_lr = 1e-3  # No change needed
large_wd = 0.1   # No change needed
```

---

## 12. Common Mistakes

1. **LR too high with Lion**: Use 3-10x smaller than AdamW
2. **WD too low with Lion**: Use 3-10x higher than AdamW
3. **No warmup**: Always use warmup for stability
4. **No gradient clipping**: Essential for LLMs
5. **Wrong beta2**: Use 0.95-0.99 for LLMs, not 0.999

---

## References

- Loshchilov & Hutter (2019): AdamW
- Chen et al. (2023): Lion
- Liu et al. (2024): Sophia
- Zhang et al. (2024): Adam-mini
- Defazio et al. (2024): Schedule-Free

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
