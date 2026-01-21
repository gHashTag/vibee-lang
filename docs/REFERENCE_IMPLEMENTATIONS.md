# VIBEE ML Reference Implementations

**Production-ready implementations of LLM training and inference optimizations**

---

## Overview

VIBEE ML provides reference implementations in both Python and Zig, covering the complete LLM engineering stack.

---

## Python Library (`vibee_ml`)

### Installation

```bash
# Basic installation
pip install vibee-ml

# With training dependencies
pip install vibee-ml[training]

# With inference dependencies
pip install vibee-ml[inference]

# Full installation
pip install vibee-ml[all]
```

### Quick Start

```python
from vibee_ml import TrainingAccelerator, Lion, InferenceEngine

# Training with optimizations
accelerator = TrainingAccelerator(
    mixed_precision="bf16",
    gradient_checkpointing=True,
    flash_attention=True,
)
model = accelerator.prepare(model)

# Custom optimizer
optimizer = Lion(model.parameters(), lr=1e-4, weight_decay=0.1)

# Training loop
for batch in dataloader:
    with accelerator.autocast():
        loss = model(batch)
    accelerator.backward(loss)
    accelerator.step(optimizer)
    accelerator.zero_grad(optimizer)
```

### Modules

| Module | Description |
|--------|-------------|
| `vibee_ml.training` | Training acceleration (Flash Attention, Mixed Precision, ZeRO) |
| `vibee_ml.inference` | Inference optimization (Quantization, KV Cache, Serving) |
| `vibee_ml.optimizers` | Custom optimizers (Lion, Sophia, Schedule-Free) |
| `vibee_ml.safety` | Safety and alignment (Guardrails, Content Filtering) |
| `vibee_ml.evaluation` | Benchmarking and evaluation |
| `vibee_ml.deployment` | Production deployment utilities |
| `vibee_ml.data` | Data processing (Deduplication, Filtering, Packing) |

---

## Zig Library (`vibee_ml`)

### Building

```bash
cd implementations/zig
zig build
zig build test
zig build bench
```

### Modules

| Module | Description |
|--------|-------------|
| `core.zig` | Base types and sacred constants |
| `attention.zig` | Flash Attention implementation |
| `optimizers.zig` | Lion, AdamW optimizers |
| `quantization.zig` | INT8/INT4 quantization |

### Example

```zig
const vibee = @import("vibee_ml");

// Sacred constants
const phi = vibee.PHI;  // 1.618033988749895
const identity = vibee.GOLDEN_IDENTITY;  // 3.0

// Optimizer step
vibee.optimizers.lionStep(&params, &grads, &momentum, config);

// Quantization
vibee.quantization.quantizeInt8(&data, &output, params);
```

---

## CLI Tools

### vibee-train

```bash
# Quick training setup
vibee-train --model meta-llama/Llama-2-7b-hf \
    --data ./data \
    --output ./output \
    --bf16 \
    --flash-attention \
    --zero-stage 3
```

### vibee-serve

```bash
# Start inference server
vibee-serve --model meta-llama/Llama-2-7b-chat-hf \
    --port 8000 \
    --backend vllm \
    --tensor-parallel 2
```

---

## Docker Images

### Inference

```bash
docker build -f tools/docker/Dockerfile.inference -t vibee-inference .
docker run --gpus all -p 8000:8000 vibee-inference \
    --model meta-llama/Llama-2-7b-chat-hf
```

### Training

```bash
docker build -f tools/docker/Dockerfile.training -t vibee-training .
docker run --gpus all -v ./data:/data vibee-training
```

---

## Kubernetes Deployment

```bash
kubectl apply -f tools/k8s/deployment.yaml
```

Features:
- Auto-scaling based on CPU and requests
- Health checks and readiness probes
- GPU resource management
- Load balancer service

---

## Benchmarks

### Python

```bash
cd implementations/python
pytest benchmarks/ -v --benchmark-only
```

### Zig

```bash
cd implementations/zig
zig build bench
./zig-out/bin/bench
```

---

## API Reference

### TrainingAccelerator

```python
class TrainingAccelerator:
    def __init__(
        self,
        mixed_precision: str = "bf16",
        gradient_checkpointing: bool = True,
        flash_attention: bool = True,
        compile_model: bool = True,
        max_grad_norm: float = 1.0,
    ): ...
    
    def prepare(self, model: nn.Module) -> nn.Module: ...
    def autocast(self) -> ContextManager: ...
    def backward(self, loss: Tensor) -> None: ...
    def step(self, optimizer: Optimizer) -> None: ...
    def zero_grad(self, optimizer: Optimizer) -> None: ...
```

### Lion Optimizer

```python
class Lion(Optimizer):
    def __init__(
        self,
        params: Iterable[Parameter],
        lr: float = 1e-4,
        betas: Tuple[float, float] = (0.9, 0.99),
        weight_decay: float = 0.1,
    ): ...
```

### InferenceEngine

```python
class InferenceEngine:
    def __init__(
        self,
        model: nn.Module,
        tokenizer: Any,
        config: Optional[InferenceConfig] = None,
    ): ...
    
    def generate(
        self,
        prompt: str,
        max_tokens: int = 256,
        temperature: float = 0.7,
    ) -> GenerationResponse: ...
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
