# Best Practices v2000 - Complete LLM Development Guide

**φ² + 1/φ² = 3 | PHOENIX = 999**

## 1. Data Curation Best Practices

### Pipeline Architecture

```
Raw Web Data
    │
    ▼
┌─────────────────┐
│ URL Filtering   │ → Block known bad domains
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ HTML Extraction │ → Trafilatura/Resiliparse
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Language ID     │ → FastText lid.176.bin, conf > 0.8
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Quality Filter  │ → FineWeb-Edu classifier, score > 3
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Deduplication   │ → MinHash LSH + Semantic
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Toxicity Filter │ → Perspective API, score < 0.5
└────────┬────────┘
         │
         ▼
    Clean Data
```

### Recommended Tools

| Stage | Tool | Why |
|-------|------|-----|
| Extraction | Trafilatura | Best quality/speed ratio |
| Language ID | FastText | Fast, accurate |
| Quality | FineWeb-Edu | Proven on 15T tokens |
| Dedup | DataTrove | HuggingFace standard |
| Pipeline | Dolma | AI2 production-tested |

### Data Mixing Formula

```python
optimal_mix = {
    "web_filtered": 0.50,  # FineWeb-Edu score > 3
    "code": 0.20,          # The Stack v2
    "math": 0.10,          # ProofPile + OpenWebMath
    "books": 0.10,         # Gutenberg + others
    "academic": 0.05,      # arXiv, PubMed
    "conversations": 0.05  # ShareGPT filtered
}
```

## 2. Pre-Training Best Practices

### Model Configuration

```python
# 7B model optimal config
config = {
    "hidden_size": 4096,
    "num_layers": 32,
    "num_heads": 32,
    "intermediate_size": 11008,  # 2.7x hidden
    "vocab_size": 32000,
    "max_position_embeddings": 8192,
    "rope_theta": 500000,  # For long context
    "attention_bias": False,
    "mlp_bias": False,
}
```

### Training Hyperparameters

```python
# Chinchilla-optimal for 7B
training_config = {
    "tokens": 140_000_000_000,  # 20x params
    "batch_size": 4_000_000,    # tokens per step
    "learning_rate": 3e-4,
    "min_lr": 3e-5,             # 10% of max
    "warmup_steps": 2000,
    "lr_schedule": "cosine",
    "weight_decay": 0.1,
    "grad_clip": 1.0,
    "beta1": 0.9,
    "beta2": 0.95,
    "eps": 1e-8,
}
```

### Distributed Training Setup

```python
# 8 GPU setup
distributed_config = {
    "strategy": "fsdp",
    "sharding_strategy": "FULL_SHARD",
    "mixed_precision": "bf16",
    "activation_checkpointing": True,
    "gradient_accumulation": 8,
}

# 64+ GPU setup
distributed_config = {
    "strategy": "megatron",
    "tensor_parallel": 8,
    "pipeline_parallel": 4,
    "data_parallel": 2,
    "sequence_parallel": True,
}
```

## 3. Fine-Tuning Best Practices

### LoRA Configuration

```python
# Optimal LoRA config
lora_config = {
    "r": 64,
    "lora_alpha": 128,  # 2x r
    "lora_dropout": 0.05,
    "target_modules": [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj"
    ],
    "bias": "none",
}
```

### QLoRA for Memory Efficiency

```python
# 4-bit QLoRA
qlora_config = {
    "load_in_4bit": True,
    "bnb_4bit_compute_dtype": "bfloat16",
    "bnb_4bit_quant_type": "nf4",
    "bnb_4bit_use_double_quant": True,
    **lora_config
}
```

### Training Settings

```python
# SFT settings
sft_config = {
    "learning_rate": 2e-5,
    "num_epochs": 3,
    "batch_size": 4,
    "gradient_accumulation": 4,
    "warmup_ratio": 0.03,
    "lr_scheduler": "cosine",
    "max_seq_length": 4096,
}
```

## 4. Alignment Best Practices

### DPO Configuration

```python
# DPO optimal settings
dpo_config = {
    "beta": 0.1,  # KL penalty
    "learning_rate": 5e-7,
    "num_epochs": 1,
    "batch_size": 4,
    "max_length": 1024,
    "max_prompt_length": 512,
}
```

### SimPO (Reference-Free)

```python
# SimPO settings
simpo_config = {
    "beta": 2.0,
    "gamma": 0.5,  # Target margin
    "learning_rate": 1e-6,
}
```

### Preference Data Format

```json
{
    "prompt": "Explain quantum computing",
    "chosen": "Quantum computing uses quantum bits...",
    "rejected": "Quantum computing is like regular computing..."
}
```

## 5. Inference Best Practices

### vLLM Deployment

```python
# vLLM optimal config
vllm_config = {
    "tensor_parallel_size": 4,
    "max_model_len": 8192,
    "gpu_memory_utilization": 0.9,
    "enforce_eager": False,
    "enable_prefix_caching": True,
}
```

### Quantization Selection

| Use Case | Quantization | Why |
|----------|--------------|-----|
| Production (quality) | AWQ INT4 | Best quality/speed |
| Production (speed) | GPTQ INT4 | Fastest |
| Edge/Mobile | GGUF Q4_K_M | CPU compatible |
| Research | FP16 | No quality loss |
| Extreme compression | AQLM 2-bit | Smallest size |

### Serving Configuration

```python
# Production serving
serving_config = {
    "max_batch_size": 256,
    "max_waiting_tokens": 20,
    "continuous_batching": True,
    "speculative_decoding": True,
    "draft_model": "TinyLlama-1.1B",
}
```

## 6. Evaluation Best Practices

### Benchmark Suite

```python
# Comprehensive evaluation
eval_suite = {
    # Knowledge
    "mmlu": {"shots": 5},
    "arc_challenge": {"shots": 25},
    
    # Reasoning
    "hellaswag": {"shots": 10},
    "winogrande": {"shots": 5},
    "bbh": {"shots": 3, "cot": True},
    
    # Math
    "gsm8k": {"shots": 8, "cot": True},
    "math": {"shots": 4, "cot": True},
    
    # Code
    "humaneval": {"temperature": 0.1, "n": 10},
    "mbpp": {"temperature": 0.1, "n": 10},
    
    # Instruction
    "mt_bench": {"judge": "gpt-4"},
    "alpaca_eval": {"judge": "gpt-4-turbo"},
}
```

### Contamination Check

```python
# Always check for contamination
contamination_check = {
    "method": "n-gram overlap",
    "n": 13,
    "threshold": 0.8,
    "check_train_data": True,
}
```

## 7. Production Checklist

### Pre-Deployment

- [ ] Run full evaluation suite
- [ ] Check for contamination
- [ ] Test edge cases
- [ ] Benchmark latency/throughput
- [ ] Test quantized model quality
- [ ] Safety evaluation (ToxiGen, BBQ)

### Deployment

- [ ] Set up monitoring
- [ ] Configure rate limiting
- [ ] Enable request logging
- [ ] Set up A/B testing
- [ ] Configure auto-scaling

### Post-Deployment

- [ ] Monitor quality metrics
- [ ] Track user feedback
- [ ] Analyze failure cases
- [ ] Plan iterative improvements

## Sacred Best Practice Formula

```
Success = φ × (Data_Quality × Training_Efficiency × Alignment_Quality)

Where:
- Data_Quality = Curation_Score × Diversity × Freshness
- Training_Efficiency = Speed × Memory_Efficiency × Scaling
- Alignment_Quality = Helpfulness × Safety × Honesty

Target: Success > φ³ = 4.236
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
