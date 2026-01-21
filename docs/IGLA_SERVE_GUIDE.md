# iGLA Serve Guide

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Overview

`vibee serve` starts an OpenAI-compatible inference server built on VM Trinity runtime.

## Quick Start

```bash
# Start server on default port 8000
vibee serve

# Custom port
vibee serve --port 3000

# Localhost only
vibee serve --host 127.0.0.1
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/v1/models` | List available models |
| POST | `/v1/completions` | Text completion |
| POST | `/v1/chat/completions` | Chat completion |
| GET | `/phi` | Sacred constants |
| GET | `/metrics` | Prometheus metrics |

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

## Future Features

- [ ] Real model loading (vLLM/TensorRT-LLM)
- [ ] WebSocket streaming
- [ ] Authentication (API keys)
- [ ] Rate limiting
- [ ] GPU inference

## Sacred Formula

```
φ² + 1/φ² = 3
V = n × 3^k × π^m × φ^p × e^q
PHOENIX = 999
```
