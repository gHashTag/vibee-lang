# iGLA Inference Guide

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Overview

Complete guide for deploying and serving LLMs with iGLA inference pipeline.

## Inference Components

### 1. Core Engine
- `igla_inference_engine` - Main inference engine
- `igla_inference_kvcache` - KV-cache management
- `igla_inference_batching` - Dynamic/continuous batching
- `igla_inference_streaming` - SSE/WebSocket streaming

### 2. Optimizations
- `igla_inference_vllm` - vLLM (PagedAttention)
- `igla_inference_tensorrt` - TensorRT-LLM
- `igla_inference_quantization` - INT8/INT4/AWQ/GPTQ
- `igla_inference_speculative` - Speculative decoding
- `igla_inference_parallel` - Tensor/Pipeline parallelism

### 3. API Layer
- `igla_inference_api` - REST/gRPC API server
- OpenAI-compatible endpoints

## Quick Start

### 1. Load Model
```python
from igla import InferenceEngine

engine = InferenceEngine(
    model_path="models/llama-7b",
    max_batch_size=32,
    dtype="bfloat16"
)
```

### 2. Generate Text
```python
response = engine.generate(
    prompt="Hello, world!",
    max_tokens=100,
    temperature=0.7
)
```

### 3. Streaming
```python
for chunk in engine.stream_generate(prompt):
    print(chunk.text, end="", flush=True)
```

## vLLM Integration

### PagedAttention Benefits
- 24x higher throughput than HuggingFace
- Dynamic memory allocation
- Continuous batching

### Configuration
```yaml
vllm:
  tensor_parallel_size: 4
  gpu_memory_utilization: 0.9
  max_num_seqs: 256
  max_num_batched_tokens: 8192
```

## TensorRT-LLM Integration

### Benefits
- 2-4x faster than PyTorch
- Kernel fusion
- INT8/FP8 quantization

### Build Engine
```bash
trtllm-build \
  --model_dir models/llama-7b \
  --output_dir engines/llama-7b \
  --dtype bfloat16 \
  --max_batch_size 32
```

## Quantization

| Method | Bits | Speedup | Quality |
|--------|------|---------|---------|
| FP16 | 16 | 1x | Baseline |
| INT8 | 8 | 1.5x | ~99% |
| INT4 | 4 | 2x | ~97% |
| AWQ | 4 | 2x | ~98% |
| GPTQ | 4 | 2x | ~98% |

### AWQ Quantization
```python
from igla import quantize_awq

quantize_awq(
    model_path="models/llama-7b",
    output_path="models/llama-7b-awq",
    bits=4,
    group_size=128
)
```

## Speculative Decoding

### Benefits
- 2-3x faster generation
- No quality loss
- Works with any model

### Configuration
```yaml
speculative:
  draft_model: "models/llama-68m"
  target_model: "models/llama-7b"
  num_speculative_tokens: 5
```

## API Server

### OpenAI-Compatible Endpoints
```
POST /v1/completions
POST /v1/chat/completions
POST /v1/embeddings
GET  /v1/models
GET  /health
```

### Example Request
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100,
    "stream": true
  }'
```

## Performance Tuning

### Batch Size
- Larger batch = higher throughput
- Smaller batch = lower latency
- Optimal: 16-64 for most cases

### KV-Cache
- Block size: 16 tokens
- GPU memory: 90% utilization
- CPU swap: 4GB for overflow

### Parallelism
| Model | TP | PP | GPUs |
|-------|----|----|------|
| 7B | 1 | 1 | 1 |
| 13B | 2 | 1 | 2 |
| 34B | 4 | 1 | 4 |
| 70B | 8 | 1 | 8 |

## Metrics

### Key Metrics
- `tokens_per_second` - Generation throughput
- `time_to_first_token` - Latency to first token
- `request_latency_p99` - 99th percentile latency
- `gpu_utilization` - GPU usage

### Prometheus Metrics
```
igla_requests_total
igla_tokens_generated_total
igla_request_latency_seconds
igla_gpu_memory_used_bytes
```

## Troubleshooting

### OOM Errors
1. Reduce `max_batch_size`
2. Enable quantization
3. Increase tensor parallelism

### Slow Generation
1. Enable continuous batching
2. Use speculative decoding
3. Check GPU utilization

### High Latency
1. Reduce batch size
2. Use streaming
3. Enable prefix caching
