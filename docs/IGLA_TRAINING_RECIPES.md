# iGLA Training Recipes

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Recipe 1: 7B Base Model

### Configuration
```yaml
model:
  hidden_size: 4096
  num_layers: 32
  num_heads: 32
  num_kv_heads: 8
  intermediate_size: 11008
  vocab_size: 32000
  max_position: 8192

training:
  learning_rate: 3e-4
  min_lr: 3e-5
  batch_size: 4M tokens
  warmup_steps: 2000
  total_steps: 100000
  weight_decay: 0.1
  gradient_clip: 1.0

optimizer:
  type: AdamW
  beta1: 0.9
  beta2: 0.95
  epsilon: 1e-8

scheduler:
  type: cosine
  warmup_ratio: 0.02

distributed:
  strategy: FSDP
  precision: BF16
  gradient_checkpointing: true
```

### Data Mix
```yaml
data:
  total_tokens: 140B
  mix:
    web: 0.50
    code: 0.20
    books: 0.15
    academic: 0.10
    conversation: 0.05
```

### Hardware
- 64 A100 80GB GPUs
- 4-6 weeks training time
- ~$50k compute cost

---

## Recipe 2: 7B + KOSHEY

### Configuration
```yaml
model:
  hidden_size: 4096
  num_layers: 32
  num_heads: 32
  num_kv_heads: 8
  intermediate_size: 11008
  vocab_size: 32000
  max_position: 131072  # Extended!

koshey:
  tier: 6
  ring_attention: true
  ewc_enabled: true
  ewc_lambda: 5000
  fisher_samples: 1000

training:
  learning_rate: 3e-4
  min_lr: 3e-5
  batch_size: 2M tokens  # Reduced for long context
  warmup_steps: 2000
  total_steps: 100000
  weight_decay: 0.1
  gradient_clip: 1.0
```

### Hardware
- 128 A100 80GB GPUs (for Ring Attention)
- 6-8 weeks training time
- ~$100k compute cost

---

## Recipe 3: LoRA Fine-tuning

### Configuration
```yaml
base_model: llama-7b

lora:
  rank: 64
  alpha: 128
  dropout: 0.05
  target_modules:
    - q_proj
    - k_proj
    - v_proj
    - o_proj
    - gate_proj
    - up_proj
    - down_proj

training:
  learning_rate: 2e-4
  batch_size: 128
  epochs: 3
  warmup_ratio: 0.03
  weight_decay: 0.0
  gradient_clip: 1.0

optimizer:
  type: AdamW
  beta1: 0.9
  beta2: 0.999
```

### Hardware
- 1 A100 80GB GPU
- 2-4 hours training time
- ~$10 compute cost

---

## Recipe 4: QLoRA Fine-tuning

### Configuration
```yaml
base_model: llama-7b

quantization:
  bits: 4
  quant_type: nf4
  double_quant: true
  compute_dtype: bfloat16

lora:
  rank: 64
  alpha: 16
  dropout: 0.05
  target_modules:
    - q_proj
    - v_proj

training:
  learning_rate: 2e-4
  batch_size: 4
  gradient_accumulation: 4
  epochs: 3
  warmup_ratio: 0.03
```

### Hardware
- 1 RTX 4090 24GB GPU
- 4-8 hours training time
- ~$5 compute cost

---

## Recipe 5: DPO Alignment

### Configuration
```yaml
base_model: llama-7b-sft

dpo:
  beta: 0.1
  loss_type: sigmoid
  label_smoothing: 0.0
  reference_free: false

training:
  learning_rate: 5e-7
  batch_size: 8
  gradient_accumulation: 4
  epochs: 1
  warmup_ratio: 0.1
  weight_decay: 0.0

data:
  format: preference_pairs
  max_length: 2048
  max_prompt_length: 1024
```

### Hardware
- 4 A100 80GB GPUs
- 4-8 hours training time
- ~$100 compute cost

---

## Recipe 6: SFT + DPO Pipeline

### Stage 1: SFT
```yaml
base_model: llama-7b

sft:
  learning_rate: 2e-5
  batch_size: 128
  epochs: 3
  data: instruction_dataset
```

### Stage 2: DPO
```yaml
base_model: llama-7b-sft

dpo:
  beta: 0.1
  learning_rate: 5e-7
  epochs: 1
  data: preference_dataset
```

### Total Time
- SFT: 8 hours
- DPO: 4 hours
- Total: ~12 hours

---

## Recipe 7: MoE 8x7B

### Configuration
```yaml
model:
  hidden_size: 4096
  num_layers: 32
  num_heads: 32
  num_kv_heads: 8
  intermediate_size: 14336

moe:
  num_experts: 8
  num_experts_per_tok: 2
  router_aux_loss_coef: 0.01

training:
  learning_rate: 2e-4
  batch_size: 4M tokens
  total_steps: 100000
  expert_capacity_factor: 1.25
```

### Hardware
- 256 A100 80GB GPUs
- 8-12 weeks training time
- ~$500k compute cost

---

## Recipe 8: Continual Learning

### Configuration
```yaml
base_model: llama-7b-pretrained

continual:
  method: ewc
  ewc_lambda: 5000
  fisher_samples: 1000
  
curriculum:
  phases:
    - name: domain_1
      tokens: 10B
      lr: 1e-4
    - name: domain_2
      tokens: 10B
      lr: 5e-5
    - name: domain_3
      tokens: 10B
      lr: 2e-5
```

### Hardware
- 64 A100 80GB GPUs
- 2-3 weeks per phase
- ~$30k per phase

---

## Quick Reference

| Recipe | Model | Method | GPUs | Time | Cost |
|--------|-------|--------|------|------|------|
| 1 | 7B | Pretrain | 64 | 4-6w | $50k |
| 2 | 7B | KOSHEY | 128 | 6-8w | $100k |
| 3 | 7B | LoRA | 1 | 2-4h | $10 |
| 4 | 7B | QLoRA | 1 | 4-8h | $5 |
| 5 | 7B | DPO | 4 | 4-8h | $100 |
| 6 | 7B | SFT+DPO | 4 | 12h | $150 |
| 7 | 8x7B | MoE | 256 | 8-12w | $500k |
| 8 | 7B | Continual | 64 | 6-9w | $90k |
