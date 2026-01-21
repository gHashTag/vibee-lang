# TOXIC VERDICT MVP: MiniLM CPU Training

**Версия**: 1.0.0  
**Дата**: 2026-01-21  
**Статус**: ✅ ЗАВЕРШЕНО

---

## Обзор

Реализация полного пайплайна тренировки MiniLM на CPU для задачи классификации токсичности текста на русском языке.

## Архитектура v66xx

```
┌─────────────────────────────────────────────────────────────────┐
│                    MiniLM CPU Training Pipeline                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  v6600_mini_lm_cpu.zig          ← Модель MiniLM (6 слоёв)       │
│       ↓                                                         │
│  v6601_tensor_autograd_cpu.zig  ← Тензоры с автоградом          │
│       ↓                                                         │
│  v6602_linear_backward.zig      ← Linear + backward pass        │
│       ↓                                                         │
│  v6603_adam_optimizer.zig       ← Adam оптимизатор              │
│       ↓                                                         │
│  v6604_training_loop_cpu.zig    ← Цикл тренировки               │
│       ↓                                                         │
│  v6605_cosine_scheduler.zig     ← Cosine LR scheduler           │
│       ↓                                                         │
│  v6606_loss_backward.zig        ← Cross-entropy + backward      │
│       ↓                                                         │
│  v6607_gelu_backward.zig        ← GELU activation + backward    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Спецификации (.vibee)

| Файл | Назначение | Тесты |
|------|------------|-------|
| `v6600_mini_lm_cpu.vibee` | MiniLM модель | 9 |
| `v6601_tensor_autograd_cpu.vibee` | Тензоры с градиентами | 9 |
| `v6602_linear_backward.vibee` | Linear слой с backward | 9 |
| `v6603_adam_optimizer.vibee` | Adam оптимизатор | 7 |
| `v6604_training_loop_cpu.vibee` | Цикл тренировки | 9 |
| `v6605_cosine_scheduler.vibee` | Cosine LR scheduler | 7 |
| `v6606_loss_backward.vibee` | Cross-entropy loss | 8 |
| `v6607_gelu_backward.vibee` | GELU активация | 8 |

**Всего**: 8 спецификаций, 66 тестов

## Параметры модели

```yaml
MiniLM Configuration:
  vocab_size: 30522
  hidden_size: 384
  num_layers: 6
  num_heads: 12
  intermediate_size: 1536
  max_seq_length: 128
  num_classes: 2  # toxic / non-toxic
```

## Параметры тренировки

```yaml
Training Configuration:
  batch_size: 32
  learning_rate: 2e-5
  warmup_steps: 100
  total_steps: 1000
  weight_decay: 0.01
  adam_beta1: 0.9
  adam_beta2: 0.999
  adam_epsilon: 1e-8
```

## Бенчмарк

```
═══════════════════════════════════════════
BENCHMARK: v66xx MiniLM CPU Training
═══════════════════════════════════════════

v6600_mini_lm_cpu.zig:        1833ms (9 tests)
v6601_tensor_autograd_cpu.zig: 1824ms (9 tests)
v6602_linear_backward.zig:    1776ms (9 tests)
v6603_adam_optimizer.zig:     1850ms (7 tests)
v6604_training_loop_cpu.zig:  1831ms (9 tests)
v6605_cosine_scheduler.zig:   1810ms (7 tests)
v6606_loss_backward.zig:      1822ms (8 tests)
v6607_gelu_backward.zig:      1795ms (8 tests)

═══════════════════════════════════════════
TOTAL: 66 tests in 14541ms
Average: 1817ms per module
═══════════════════════════════════════════
```

## Компоненты

### 1. Tensor Autograd (v6601)

Тензоры с поддержкой автоматического дифференцирования:
- `requires_grad` флаг
- `grad` буфер для градиентов
- `zero_grad()` обнуление градиентов
- `backward()` обратное распространение

### 2. Linear Backward (v6602)

Полносвязный слой с backward pass:
- Forward: `y = x @ W^T + b`
- Backward: `dW = x^T @ dy`, `db = sum(dy)`, `dx = dy @ W`

### 3. Adam Optimizer (v6603)

Adam оптимизатор с momentum и adaptive learning rate:
- First moment: `m = β₁ * m + (1 - β₁) * g`
- Second moment: `v = β₂ * v + (1 - β₂) * g²`
- Bias correction: `m̂ = m / (1 - β₁^t)`, `v̂ = v / (1 - β₂^t)`
- Update: `θ = θ - lr * m̂ / (√v̂ + ε)`

### 4. Training Loop (v6604)

Цикл тренировки с:
- Batch generation
- Forward pass
- Loss computation
- Backward pass
- Optimizer step
- Gradient zeroing

### 5. Cosine Scheduler (v6605)

Cosine annealing с warmup:
- Warmup: linear от 0 до `lr_max`
- Cosine: `lr = lr_min + 0.5 * (lr_max - lr_min) * (1 + cos(π * t / T))`

### 6. Loss Backward (v6606)

Cross-entropy loss с backward:
- Softmax: `p = exp(x) / sum(exp(x))`
- Loss: `L = -sum(y * log(p))`
- Gradient: `dL/dx = p - y`

### 7. GELU Backward (v6607)

GELU активация с backward:
- Forward: `GELU(x) = x * Φ(x)` где `Φ` - CDF нормального распределения
- Backward: `dGELU/dx = Φ(x) + x * φ(x)` где `φ` - PDF

## Использование

```bash
# Генерация кода из спецификаций
for f in specs/tri/v660*.vibee; do vibee gen "$f"; done

# Запуск тестов
cd trinity/output
for f in v660*.zig; do zig test "$f"; done

# Тренировка модели (пример)
zig build-exe train_minilm.zig
./train_minilm --data toxic_ru.csv --epochs 3
```

## Следующие шаги

1. **v67xx**: GPU ускорение через CUDA/Metal
2. **v68xx**: Distributed training
3. **v69xx**: Quantization (INT8/INT4)
4. **v70xx**: ONNX export

## Creation Pattern

```
Source: .vibee спецификации (8 файлов)
Transformer: vibee gen
Result: .zig модули (66 тестов, 100% pass)
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
