# iGLA Model Training Guide

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Overview

Complete guide for training LLMs with iGLA + KOSHEY optimizations.

## Training Pipeline Components

### 1. Data Pipeline
- `igla_training_data_pipeline` - Data loading, preprocessing, batching
- `igla_training_tokenizer` - BPE/SentencePiece tokenization
- `igla_training_data_mixing` - Domain mixing ratios

### 2. Architecture
- `igla_training_architecture` - Transformer architecture
- `igla_training_attention` - Ring Attention (KOSHEY)
- `igla_training_moe` - Mixture of Experts
- `igla_training_positional` - RoPE/ALiBi
- `igla_training_normalization` - RMSNorm
- `igla_training_activation` - SwiGLU

### 3. Optimization
- `igla_training_optimizer` - AdamW/LAMB
- `igla_training_scheduler` - Cosine/WSD
- `igla_training_gradient` - Accumulation/Clipping
- `igla_training_regularization` - Dropout/Weight decay

### 4. Distributed Training
- `igla_training_distributed` - FSDP/DeepSpeed
- `igla_training_mixed_precision` - BF16/FP16
- `igla_training_checkpointing` - Checkpoint management

### 5. Continual Learning (KOSHEY)
- `igla_training_ewc` - Elastic Weight Consolidation
- `igla_training_continual` - Lifelong learning
- `igla_training_curriculum` - Curriculum learning

## Model Architectures

| Model | Params | Layers | Heads | Hidden | Context |
|-------|--------|--------|-------|--------|---------|
| 7B | 7B | 32 | 32 | 4096 | 8192 |
| 13B | 13B | 40 | 40 | 5120 | 8192 |
| 34B | 34B | 48 | 64 | 8192 | 16384 |
| 70B | 70B | 80 | 64 | 8192 | 32768 |
| KOSHEY | 7B+ | 32+ | 32+ | 4096+ | 131072 |

## Fine-tuning Methods

| Method | Memory | Speed | Quality |
|--------|--------|-------|---------|
| LoRA | Low | Fast | Good |
| QLoRA | Very Low | Medium | Good |
| DoRA | Low | Fast | Better |
| Full | High | Slow | Best |

## Alignment Methods

| Method | Complexity | Data Needs | Quality |
|--------|------------|------------|---------|
| SFT | Low | Medium | Good |
| DPO | Medium | Low | Better |
| RLHF | High | High | Best |
| Constitutional | Medium | Low | Good |

## Cost Estimates (A100 cluster)

| Model | GPU Hours | Cost | Timeline |
|-------|-----------|------|----------|
| 7B | 10,000 | ~$50k | 4-6 weeks |
| 13B | 25,000 | ~$125k | 6-8 weeks |
| 34B | 80,000 | ~$400k | 2-3 months |
| 70B | 200,000 | ~$1M | 3-4 months |

## Quick Start

```bash
# Generate all training modules
for f in specs/tri/igla_training*.vibee; do vibee gen "$f"; done

# Test all modules
cd trinity/output && for f in igla_training*.zig; do zig test "$f"; done
```

## KOSHEY Integration

KOSHEY tiers for training:
- **v1-v3**: Basic optimizations
- **v4-v6**: Ring Attention + EWC
- **v7-v9**: MoE + Continual Learning
- **v10**: Full KOSHEY stack

## Chinchilla Scaling Laws

Compute-optimal training:
```
D_opt ≈ 20 × N
```
Where N = parameters, D = tokens.

| Model | Optimal Tokens |
|-------|----------------|
| 7B | 140B |
| 13B | 260B |
| 34B | 680B |
| 70B | 1.4T |

## Sacred Constants

- φ = 1.618033988749895 (Golden Ratio)
- trinity = 3.0
- phoenix = 999
- φ² + 1/φ² = 3 (Golden Identity)
