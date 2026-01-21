# iGLA Deployment Guide

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

## Overview

Production deployment guide for iGLA inference services.

## Deployment Components

### Infrastructure
- `igla_deploy_docker` - Container images
- `igla_deploy_kubernetes` - K8s manifests
- `igla_deploy_autoscaling` - HPA/VPA
- `igla_deploy_loadbalancer` - Traffic distribution
- `igla_deploy_monitoring` - Prometheus/Grafana
- `igla_deploy_service_mesh` - Istio/Linkerd

## Docker Deployment

### Dockerfile
```dockerfile
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

# Install dependencies
RUN apt-get update && apt-get install -y python3 python3-pip

# Install iGLA
COPY requirements.txt .
RUN pip3 install -r requirements.txt

# Copy model
COPY models/ /models/

# Copy application
COPY app/ /app/

WORKDIR /app
EXPOSE 8000

CMD ["python3", "server.py"]
```

### Build & Run
```bash
# Build image
docker build -t igla-inference:latest .

# Run with GPU
docker run --gpus all -p 8000:8000 \
  -v /path/to/models:/models \
  igla-inference:latest
```

### Docker Compose
```yaml
version: '3.8'
services:
  inference:
    image: igla-inference:latest
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    ports:
      - "8000:8000"
    volumes:
      - ./models:/models
    environment:
      - MODEL_PATH=/models/llama-7b
      - MAX_BATCH_SIZE=32
```

## Kubernetes Deployment

### Deployment Manifest
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: igla-inference
  namespace: igla
spec:
  replicas: 3
  selector:
    matchLabels:
      app: igla-inference
  template:
    metadata:
      labels:
        app: igla-inference
    spec:
      containers:
      - name: inference
        image: igla-inference:latest
        ports:
        - containerPort: 8000
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "32Gi"
            cpu: "8"
        volumeMounts:
        - name: model-storage
          mountPath: /models
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: model-pvc
      nodeSelector:
        nvidia.com/gpu.product: NVIDIA-A100-SXM4-80GB
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: igla-inference
  namespace: igla
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
  selector:
    app: igla-inference
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: igla-ingress
  namespace: igla
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
spec:
  rules:
  - host: api.igla.ai
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: igla-inference
            port:
              number: 8000
```

## Autoscaling

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: igla-hpa
  namespace: igla
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: igla-inference
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
```

### Vertical Pod Autoscaler
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: igla-vpa
  namespace: igla
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: igla-inference
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: inference
      minAllowed:
        cpu: "4"
        memory: "16Gi"
      maxAllowed:
        cpu: "16"
        memory: "64Gi"
```

## Monitoring

### Prometheus ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: igla-monitor
  namespace: igla
spec:
  selector:
    matchLabels:
      app: igla-inference
  endpoints:
  - port: metrics
    interval: 15s
```

### Grafana Dashboard
Key panels:
- Requests per second
- Token throughput
- P50/P95/P99 latency
- GPU utilization
- Memory usage
- Queue depth

### Alerts
```yaml
groups:
- name: igla-alerts
  rules:
  - alert: HighLatency
    expr: igla_request_latency_p99 > 5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High inference latency"
      
  - alert: GPUMemoryHigh
    expr: igla_gpu_memory_used_percent > 95
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "GPU memory nearly full"
```

## Load Balancing

### NGINX Configuration
```nginx
upstream igla_backend {
    least_conn;
    server inference-1:8000 weight=1;
    server inference-2:8000 weight=1;
    server inference-3:8000 weight=1;
    
    keepalive 32;
}

server {
    listen 80;
    
    location / {
        proxy_pass http://igla_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 3600s;
    }
    
    location /v1/chat/completions {
        proxy_pass http://igla_backend;
        proxy_buffering off;
        chunked_transfer_encoding on;
    }
}
```

## Service Mesh (Istio)

### VirtualService
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: igla-vs
  namespace: igla
spec:
  hosts:
  - igla-inference
  http:
  - route:
    - destination:
        host: igla-inference
        subset: v1
      weight: 90
    - destination:
        host: igla-inference
        subset: v2
      weight: 10
    timeout: 60s
    retries:
      attempts: 3
      perTryTimeout: 20s
```

### DestinationRule
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: igla-dr
  namespace: igla
spec:
  host: igla-inference
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s
```

## Production Checklist

### Pre-deployment
- [ ] Model quantized (INT4/INT8)
- [ ] Health checks configured
- [ ] Resource limits set
- [ ] Secrets managed (API keys)
- [ ] TLS certificates ready

### Deployment
- [ ] Rolling update strategy
- [ ] PodDisruptionBudget set
- [ ] Autoscaling configured
- [ ] Monitoring enabled
- [ ] Alerts configured

### Post-deployment
- [ ] Load testing completed
- [ ] Latency benchmarks met
- [ ] Failover tested
- [ ] Backup strategy verified
- [ ] Runbook documented

## Cost Optimization

| Instance | GPU | $/hour | Tokens/s | $/1M tokens |
|----------|-----|--------|----------|-------------|
| g5.xlarge | A10G | $1.00 | 50 | $5.50 |
| g5.2xlarge | A10G | $1.21 | 80 | $4.20 |
| p4d.24xlarge | 8xA100 | $32.77 | 2000 | $4.55 |
| p5.48xlarge | 8xH100 | $98.32 | 6000 | $4.55 |

### Tips
1. Use spot instances for non-critical workloads
2. Right-size GPU memory
3. Enable request batching
4. Use quantization
5. Implement request caching
