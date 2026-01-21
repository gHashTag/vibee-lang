# iGLA Serve Guide

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Overview

`vibee serve` starts an OpenAI-compatible inference server with real LLM inference via llama.cpp.

## Quick Start

```bash
# Mock server (for testing, no model needed)
vibee serve

# Real inference with GGUF model
vibee serve -m models/tinyllama-1.1b-q4_k_m.gguf

# Custom port and context size
vibee serve -m model.gguf --port 3000 --ctx 4096 --threads 8
```

## Download a Model

```bash
# TinyLlama 1.1B (638MB, fast)
curl -L -o models/tinyllama.gguf \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# Phi-2 2.7B (1.6GB, smarter)
curl -L -o models/phi-2.gguf \
  "https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf"

# Llama 2 7B (4GB, best quality)
curl -L -o models/llama-2-7b.gguf \
  "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q4_K_M.gguf"
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `-m, --model` | none | Path to GGUF model (enables real inference) |
| `--port` | 8000 | Server port |
| `--host` | 0.0.0.0 | Server host |
| `--ctx` | 2048 | Context size |
| `--threads` | 4 | CPU threads |

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/v1/models` | List available models |
| POST | `/v1/completions` | Text completion |
| POST | `/v1/chat/completions` | Chat completion (supports streaming) |

## SSE Streaming

Real-time token streaming is supported via `stream: true`:

```bash
# Streaming request
curl -N -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}],"stream":true}'
```

Response format (Server-Sent Events):
```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":"!"}}]}
data: {"choices":[{"delta":{"content":" How"}}]}
...
data: [DONE]
```

### Streaming Demo Script

```bash
# Use the included demo script
./scripts/stream_chat.sh 8001 "Your question here"
```

### Python Streaming Example

```python
import requests
import json

response = requests.post(
    "http://localhost:8001/v1/chat/completions",
    json={"messages": [{"role": "user", "content": "Hello!"}], "stream": True},
    stream=True
)

for line in response.iter_lines():
    if line:
        data = line.decode().removeprefix("data: ")
        if data != "[DONE]":
            chunk = json.loads(data)
            content = chunk["choices"][0]["delta"].get("content", "")
            print(content, end="", flush=True)
```

## API Examples

### Health Check
```bash
curl http://localhost:8000/health
```
Response:
```json
{"status":"healthy","version":"1.0.0","trinity":true}
```

### List Models
```bash
curl http://localhost:8000/v1/models
```
Response:
```json
{
  "object": "list",
  "data": [
    {"id": "igla-7b", "object": "model", "owned_by": "vibee"},
    {"id": "igla-koshey", "object": "model", "owned_by": "vibee"}
  ]
}
```

### Chat Completion
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "igla-7b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```
Response:
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "model": "igla-7b",
  "choices": [{
    "index": 0,
    "message": {"role": "assistant", "content": "Hello! I am iGLA assistant."},
    "finish_reason": "stop"
  }],
  "usage": {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30}
}
```

### Text Completion
```bash
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "igla-7b",
    "prompt": "Hello, world!"
  }'
```

### Sacred Constants
```bash
curl http://localhost:8000/phi
```
Response:
```json
{
  "phi": 1.618033988749895,
  "phi_squared": 2.618033988749895,
  "inv_phi_squared": 0.381966011250105,
  "trinity": 3.0,
  "phoenix": 999,
  "verified": true
}
```

### Prometheus Metrics
```bash
curl http://localhost:8000/metrics
```
Response:
```
# HELP igla_requests_total Total requests
# TYPE igla_requests_total counter
igla_requests_total 42

# HELP igla_tokens_generated Total tokens
# TYPE igla_tokens_generated counter
igla_tokens_generated 1000

# HELP igla_uptime_seconds Uptime
# TYPE igla_uptime_seconds gauge
igla_uptime_seconds 3600
```

## OpenAI SDK Compatibility

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="igla-7b",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    vibee serve                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Router    │  │  Handlers   │  │ Middleware  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              VM Trinity Runtime                      │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐            │   │
│  │  │ Ternary │  │ Sacred  │  │ Memory  │            │   │
│  │  │  Logic  │  │Constants│  │ Manager │            │   │
│  │  └─────────┘  └─────────┘  └─────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Description |
|--------|-------------|
| `igla_serve_server` | HTTP server core |
| `igla_serve_router` | Request routing |
| `igla_serve_handlers` | API handlers |
| `igla_serve_middleware` | Auth, logging, rate-limit |
| `igla_serve_websocket` | WebSocket streaming |
| `igla_serve_openai` | OpenAI compatibility |

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | 8000 | Server port |
| `--host` | 0.0.0.0 | Server host |

## Supported Models

Any GGUF format model works:

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| TinyLlama 1.1B | 638MB | 45 tok/s | ⭐⭐ | Quick tests, low RAM |
| Phi-2 2.7B | 1.7GB | 16 tok/s | ⭐⭐⭐ | Reasoning, balanced |
| Mistral 7B | 4.1GB | ~8 tok/s | ⭐⭐⭐⭐ | Production quality |
| Llama 2 7B | 4GB | ~8 tok/s | ⭐⭐⭐⭐ | General purpose |

### Benchmark Results (CPU, 4 threads)

```
TinyLlama 1.1B:  45 tokens/sec, basic math ✅, reasoning ⚠️
Phi-2 2.7B:      16 tokens/sec, math ✅, reasoning ✅
Mistral 7B:      ~8 tokens/sec, best quality overall
```

## Performance Tips

1. **Use Q4_K_M quantization** - Best speed/quality balance
2. **Set context size** - Lower = faster (`--ctx 512` for quick tests)
3. **Increase threads** - Match your CPU cores (`--threads 8`)
4. **Use GPU** - Build llama.cpp with CUDA for 10x speedup

## Sacred Formula

```
φ² + 1/φ² = 3
V = n × 3^k × π^m × φ^p × e^q
PHOENIX = 999
```
