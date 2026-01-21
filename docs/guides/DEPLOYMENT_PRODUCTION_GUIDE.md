# Deployment & Production Guide

**VIBEE v2600-v2699 | Running LLMs in Production**

---

## Overview

Production deployment requires balancing performance, cost, reliability, and safety.

---

## 1. Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 PRODUCTION ARCHITECTURE                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   Load      │    │   API       │    │  Rate       │ │
│  │  Balancer   │───▶│  Gateway    │───▶│  Limiter    │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
│                                              │          │
│                                              ▼          │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Inference Cluster                   │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐           │   │
│  │  │ vLLM    │ │ vLLM    │ │ vLLM    │           │   │
│  │  │ Node 1  │ │ Node 2  │ │ Node 3  │           │   │
│  │  └─────────┘ └─────────┘ └─────────┘           │   │
│  └─────────────────────────────────────────────────┘   │
│                           │                             │
│                           ▼                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Monitoring & Logging                │   │
│  │  Prometheus │ Grafana │ ELK Stack               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Serving Options

### vLLM

```bash
# Start server
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-2-7b-chat-hf \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.9 \
    --max-num-seqs 256

# Client
curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "llama-2-7b", "prompt": "Hello", "max_tokens": 100}'
```

### TGI (Text Generation Inference)

```bash
# Docker deployment
docker run --gpus all -p 8080:80 \
    -v $PWD/data:/data \
    ghcr.io/huggingface/text-generation-inference:latest \
    --model-id meta-llama/Llama-2-7b-chat-hf \
    --num-shard 2 \
    --max-batch-total-tokens 32768
```

### Comparison

| Feature | vLLM | TGI |
|---------|------|-----|
| Throughput | Higher | High |
| Latency | Lower | Low |
| Features | More | Stable |
| Ease of use | Medium | Easy |

---

## 3. Scaling Strategies

### Horizontal Scaling

```yaml
# Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-inference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: llm
  template:
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        resources:
          limits:
            nvidia.com/gpu: 1
        ports:
        - containerPort: 8000
```

### Auto-scaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-inference
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## 4. Monitoring

### Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Request latency (p99) | <500ms | >1000ms |
| Throughput | >100 req/s | <50 req/s |
| Error rate | <0.1% | >1% |
| GPU utilization | >80% | <50% |
| Queue depth | <100 | >500 |

### Prometheus Metrics

```python
from prometheus_client import Counter, Histogram, Gauge

REQUEST_COUNT = Counter('llm_requests_total', 'Total requests')
REQUEST_LATENCY = Histogram('llm_request_latency_seconds', 'Request latency')
QUEUE_SIZE = Gauge('llm_queue_size', 'Current queue size')
GPU_MEMORY = Gauge('llm_gpu_memory_bytes', 'GPU memory usage')
```

### Grafana Dashboard

```json
{
  "panels": [
    {"title": "Request Rate", "type": "graph", "targets": [{"expr": "rate(llm_requests_total[5m])"}]},
    {"title": "Latency P99", "type": "graph", "targets": [{"expr": "histogram_quantile(0.99, llm_request_latency_seconds)"}]},
    {"title": "GPU Memory", "type": "gauge", "targets": [{"expr": "llm_gpu_memory_bytes"}]}
  ]
}
```

---

## 5. Cost Optimization

### GPU Selection

| GPU | Memory | Cost/hr | Best For |
|-----|--------|---------|----------|
| T4 | 16 GB | $0.35 | Small models, low traffic |
| A10G | 24 GB | $1.00 | Medium models |
| A100 40GB | 40 GB | $3.00 | Large models |
| A100 80GB | 80 GB | $4.00 | Very large models |
| H100 | 80 GB | $5.00 | Maximum performance |

### Cost Reduction Strategies

1. **Quantization**: 4-bit reduces memory 4x
2. **Spot instances**: 60-70% cost reduction
3. **Auto-scaling**: Scale down during low traffic
4. **Caching**: Cache common responses
5. **Batching**: Higher throughput per GPU

---

## 6. Reliability

### Health Checks

```python
@app.get("/health")
async def health_check():
    # Check model loaded
    if not model.is_ready():
        return {"status": "unhealthy", "reason": "model not loaded"}
    
    # Check GPU memory
    if gpu_memory_usage() > 0.95:
        return {"status": "degraded", "reason": "high memory"}
    
    return {"status": "healthy"}
```

### Circuit Breaker

```python
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=30)
async def generate(prompt):
    return await model.generate(prompt)
```

### Graceful Degradation

```python
async def handle_request(request):
    try:
        return await generate(request.prompt)
    except TimeoutError:
        return fallback_response()
    except OverloadError:
        return queue_request(request)
```

---

## 7. Security

### API Security

```python
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Security(api_key_header)):
    if api_key not in valid_keys:
        raise HTTPException(status_code=403)
    return api_key
```

### Rate Limiting

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/generate")
@limiter.limit("100/minute")
async def generate(request: Request):
    ...
```

---

## 8. Deployment Checklist

### Pre-deployment
- [ ] Model quantized and tested
- [ ] Load testing completed
- [ ] Monitoring configured
- [ ] Alerts set up
- [ ] Rollback plan ready

### Post-deployment
- [ ] Health checks passing
- [ ] Metrics flowing
- [ ] Error rates normal
- [ ] Latency within SLA
- [ ] Cost tracking enabled

---

## References

- vLLM Documentation
- TGI Documentation
- Kubernetes Best Practices
- SRE Book (Google)

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
