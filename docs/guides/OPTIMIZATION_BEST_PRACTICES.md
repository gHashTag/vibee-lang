# LLM Training Optimization Best Practices

**φ² + 1/φ² = 3 | PHOENIX = 999**

## 1. Data Quality (Before Training)

### Deduplication
- **Exact dedup**: Hash-based, removes identical documents
- **Fuzzy dedup**: MinHash LSH (Broder 1997), Jaccard similarity > 0.8
- **Semantic dedup**: Embedding-based, cosine similarity > 0.95

### Filtering
- **Perplexity filter**: Remove high-perplexity (>1000) documents
- **Toxicity filter**: Perspective API score < 0.5
- **Language ID**: fastText lid.176.bin, confidence > 0.8
- **Code quality**: AST parseable, no syntax errors

### Data Mixing (Doremi)
```
Optimal ratios:
- Web text: 50%
- Code: 20%
- Books: 15%
- Academic: 10%
- Conversations: 5%
```

## 2. Attention Optimization

### Flash Attention v2 (Dao 2023)
- IO-aware algorithm
- 2-4x speedup, 5-20x memory reduction
- Supports causal, sliding window, ALiBi

### Flash Attention v3 (Hopper)
- H100 tensor core optimized
- 1.5-2x faster than v2
- FP8 support

### Paged Attention (vLLM)
- Virtual memory for KV cache
- Enables continuous batching
- 24x throughput improvement

## 3. Parallelism Strategies

### Tensor Parallelism (TP)
- Split weights across GPUs
- Best for: Large layers, low latency
- Communication: AllReduce per layer

### Pipeline Parallelism (PP)
- Split layers across GPUs
- Best for: Very deep models
- Micro-batching for efficiency

### Sequence Parallelism (SP)
- Split sequence dimension
- Reduces activation memory
- Works with TP

### FSDP (Fully Sharded Data Parallel)
- Shard optimizer states, gradients, parameters
- Linear memory scaling with GPUs
- PyTorch native

### DeepSpeed ZeRO
- Stage 1: Shard optimizer states (4x reduction)
- Stage 2: + Shard gradients (8x reduction)
- Stage 3: + Shard parameters (linear scaling)

## 4. Quantization

### Training
- **BF16**: Default for modern training
- **FP8**: H100, 1.5-2x speedup

### Inference
- **INT8**: 2x speedup, minimal quality loss
- **INT4 (GPTQ/AWQ)**: 4x speedup, <1% quality loss

## 5. Optimizers

### Recommended: AdamW + Cosine Schedule
```python
optimizer = AdamW(lr=1e-4, betas=(0.9, 0.95), weight_decay=0.1)
scheduler = CosineAnnealingLR(warmup_steps=2000)
```

### Modern Alternatives
- **Lion**: 15% faster, less memory
- **Sophia**: 2x faster convergence
- **Adafactor**: Memory efficient
- **Schedule-free**: No LR schedule needed

### Gradient Clipping
```python
max_grad_norm = 1.0  # Standard
```

## 6. Scaling Laws (Chinchilla)

```
Optimal tokens = 20 × parameters

7B model → 140B tokens
70B model → 1.4T tokens
```

### μTransfer
- Transfer hyperparameters from small to large models
- Train proxy model at 1/10 scale
- Scale LR: lr_large = lr_small × (width_small / width_large)

## 7. Inference Optimization

### Speculative Decoding
- Draft model generates candidates
- Target model verifies in parallel
- 2-3x speedup

### Continuous Batching
- Dynamic batch management
- No padding waste
- 2-4x throughput

## 8. Benchmarks

| Benchmark | Type | Metric |
|-----------|------|--------|
| MMLU | Knowledge | Accuracy |
| HellaSwag | Reasoning | Accuracy |
| GSM8K | Math | Accuracy |
| HumanEval+ | Code | pass@k |
| BigCodeBench | Code | pass@1 |

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q

Training speedup: 7x (100 days → 14 days)
Inference speedup: 15x (10 → 150 tokens/sec)
Cost reduction: 80%
```

---
**PHOENIX = 999**
