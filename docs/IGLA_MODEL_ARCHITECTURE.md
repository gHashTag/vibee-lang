# iGLA Model Architecture

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Transformer Architecture

```
Input Tokens
    ↓
[Embedding Layer]
    ↓
┌─────────────────────────────────────┐
│         Transformer Block           │
│  ┌─────────────────────────────┐   │
│  │      RMSNorm                │   │
│  └─────────────────────────────┘   │
│              ↓                      │
│  ┌─────────────────────────────┐   │
│  │   Multi-Head Attention      │   │
│  │   (GQA + Ring Attention)    │   │
│  └─────────────────────────────┘   │
│              ↓                      │
│  ┌─────────────────────────────┐   │
│  │      RMSNorm                │   │
│  └─────────────────────────────┘   │
│              ↓                      │
│  ┌─────────────────────────────┐   │
│  │   Feed-Forward (SwiGLU)     │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
    ↓ (× N layers)
[RMSNorm]
    ↓
[LM Head]
    ↓
Output Logits
```

## Model Configurations

### 7B Model
```yaml
hidden_size: 4096
num_layers: 32
num_heads: 32
num_kv_heads: 8  # GQA
intermediate_size: 11008
vocab_size: 32000
max_position: 8192
rope_theta: 10000
```

### 13B Model
```yaml
hidden_size: 5120
num_layers: 40
num_heads: 40
num_kv_heads: 8
intermediate_size: 13824
vocab_size: 32000
max_position: 8192
rope_theta: 10000
```

### 34B Model
```yaml
hidden_size: 8192
num_layers: 48
num_heads: 64
num_kv_heads: 8
intermediate_size: 22016
vocab_size: 32000
max_position: 16384
rope_theta: 500000
```

### 70B Model
```yaml
hidden_size: 8192
num_layers: 80
num_heads: 64
num_kv_heads: 8
intermediate_size: 28672
vocab_size: 32000
max_position: 32768
rope_theta: 500000
```

### KOSHEY Model
```yaml
hidden_size: 4096
num_layers: 32
num_heads: 32
num_kv_heads: 8
intermediate_size: 11008
vocab_size: 32000
max_position: 131072  # Extended context
rope_theta: 1000000
ring_attention: true
ewc_enabled: true
moe_enabled: optional
```

## Attention Mechanisms

### Grouped Query Attention (GQA)
```
Q: [batch, seq, num_heads, head_dim]
K: [batch, seq, num_kv_heads, head_dim]
V: [batch, seq, num_kv_heads, head_dim]

# KV heads are shared across query heads
# Reduces memory by num_heads/num_kv_heads
```

### Ring Attention (KOSHEY)
```
# Distributes attention across devices
# Enables 128K+ context lengths
# Memory: O(seq/num_devices) per device
```

## Positional Encoding

### RoPE (Rotary Position Embedding)
```
θ_i = base^(-2i/d)
R(m) = [cos(mθ), sin(mθ)]

# Apply rotation to Q and K
Q_rot = Q * cos(mθ) + rotate(Q) * sin(mθ)
K_rot = K * cos(mθ) + rotate(K) * sin(mθ)
```

## Normalization

### RMSNorm
```
RMSNorm(x) = x / sqrt(mean(x²) + ε) * γ

# Faster than LayerNorm (no mean subtraction)
# Used in Llama, Mistral, etc.
```

## Activation

### SwiGLU
```
SwiGLU(x) = Swish(xW₁) ⊙ (xW₂)
Swish(x) = x * sigmoid(x)

# Better than ReLU/GELU for LLMs
# Used in Llama 2/3, PaLM, etc.
```

## Memory Requirements

| Model | FP32 | BF16 | INT8 | INT4 |
|-------|------|------|------|------|
| 7B | 28GB | 14GB | 7GB | 3.5GB |
| 13B | 52GB | 26GB | 13GB | 6.5GB |
| 34B | 136GB | 68GB | 34GB | 17GB |
| 70B | 280GB | 140GB | 70GB | 35GB |

## Training Memory (per GPU)

| Model | Full | LoRA | QLoRA |
|-------|------|------|-------|
| 7B | 80GB | 24GB | 12GB |
| 13B | 160GB | 40GB | 20GB |
| 34B | 400GB | 80GB | 40GB |
| 70B | 800GB | 160GB | 80GB |

## KOSHEY Optimizations

### Tier 1-3: Basic
- Mixed precision (BF16)
- Gradient checkpointing
- Flash Attention

### Tier 4-6: Advanced
- Ring Attention
- EWC (Elastic Weight Consolidation)
- Sequence parallelism

### Tier 7-9: Expert
- MoE (Mixture of Experts)
- Continual learning
- Dynamic batching

### Tier 10: Full Stack
- All optimizations combined
- 128K+ context
- Lifelong learning
