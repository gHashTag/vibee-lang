# VIBEE BitNet Python Bindings

**Священная Формула:** V = n × 3^k × π^m × φ^p × e^q  
**Золотое Тождество:** φ² + 1/φ² = 3 | PHOENIX = 999

---

Python обёртка для BitNet FPGA акселератора с интеграцией NumPy и PyTorch.

## Установка

```bash
# Из исходников
cd trinity/output/fpga/driver/python
pip install -e .

# С PyTorch поддержкой
pip install -e ".[torch]"

# Для разработки
pip install -e ".[dev]"
```

## Требования

- Python >= 3.8
- NumPy >= 1.20
- libbitnet.so (скомпилированная библиотека)
- Устройство /dev/bitnet0 (BitNet FPGA)

Опционально:
- PyTorch >= 2.0 (для torch_api)

## Быстрый старт

### Базовый пример

```python
from bitnet import BitNet
import numpy as np

# Создаём контекст
with BitNet("/dev/bitnet0") as bn:
    # Загружаем веса
    bn.load_weights("model.bin")
    
    # Inference
    input_tokens = np.array([1, 2, 3, 4, 5], dtype=np.int32)
    output = bn.inference(input_tokens, max_output=100)
    
    print(f"Generated {len(output)} tokens")
```

### Функциональный API

```python
from bitnet import bitnet_inference
import numpy as np

# Одна строка для inference
output = bitnet_inference(
    np.array([1, 2, 3, 4, 5]),
    model_path="model.bin"
)
```

### PyTorch интеграция

```python
import torch
from bitnet import BitNetModule

# Как nn.Module
model = BitNetModule(model_path="model.bin")
input_ids = torch.tensor([[1, 2, 3, 4, 5]])
output = model(input_ids)

# HuggingFace-style генерация
from bitnet import BitNetForCausalLM

model = BitNetForCausalLM.from_pretrained("model.bin")
output = model.generate(input_ids, max_new_tokens=50)
```

## API Reference

### BitNet Class

```python
class BitNet:
    def __init__(self, device: str = "/dev/bitnet0")
    
    # Веса
    def load_weights(self, model_path: str)
    def load_weights_from_array(self, weights: np.ndarray, layer_id: int = -1)
    
    # Inference
    def inference(self, input_tokens, max_output: int = 1024) -> np.ndarray
    def inference_async(self, input_tokens)
    def wait(self, timeout_ms: int = -1) -> bool
    def get_output(self, max_output: int = 1024) -> np.ndarray
    def abort()
    def reset()
    
    # Properties
    @property
    def status -> BitNetStatus
    @property
    def performance -> BitNetPerformance
    @property
    def model_info -> BitNetModelInfo
    @property
    def is_busy -> bool
```

### NumPy Functions

```python
# Простой inference
bitnet_inference(input_tokens, model_path, device="/dev/bitnet0") -> np.ndarray

# Batch inference
bitnet_batch_inference(input_batch, model_path, device="/dev/bitnet0") -> np.ndarray

# Утилиты
tokens_to_numpy(tokens) -> np.ndarray
pad_sequences(sequences, max_len=None, pad_token_id=0) -> np.ndarray
unpad_sequence(sequence, pad_token_id=0) -> np.ndarray
```

### PyTorch Module

```python
class BitNetModule(nn.Module):
    def __init__(self, device="/dev/bitnet0", model_path=None)
    def forward(self, input_ids, max_length=1024, attention_mask=None) -> torch.Tensor
    def generate(self, input_ids, max_new_tokens=100, ...) -> torch.Tensor

class BitNetForCausalLM(BitNetModule):
    @classmethod
    def from_pretrained(cls, model_path, device="/dev/bitnet0")
```

### Data Classes

```python
@dataclass
class BitNetStatus:
    state: str           # "IDLE", "RUNNING", "ERROR", etc.
    current_layer: int
    tokens_processed: int
    error_code: int

@dataclass
class BitNetPerformance:
    total_cycles: int
    dma_cycles: int
    compute_cycles: int
    tokens_per_second: int
    inference_count: int

@dataclass
class BitNetModelInfo:
    num_layers: int
    hidden_size: int
    vocab_size: int
    max_seq_len: int
    weight_size: int
```

## Примеры

### Асинхронный inference

```python
from bitnet import BitNet

with BitNet() as bn:
    bn.load_weights("model.bin")
    
    # Запуск async
    bn.inference_async([1, 2, 3, 4, 5])
    
    # Делаем что-то пока ждём
    print("Processing...")
    
    # Ожидание с таймаутом
    if bn.wait(timeout_ms=5000):
        output = bn.get_output()
        print(f"Got {len(output)} tokens")
    else:
        print("Timeout!")
        bn.abort()
```

### Streaming генерация

```python
from bitnet.numpy_api import BitNetStream

with BitNetStream("model.bin") as stream:
    for token in stream.generate([1, 2, 3], max_tokens=100, stop_token_id=2):
        print(token, end=" ", flush=True)
```

### Batch обработка

```python
import numpy as np
from bitnet import bitnet_batch_inference

# Batch входных данных
batch = np.array([
    [1, 2, 3, 0, 0],  # padded
    [4, 5, 6, 7, 8],
], dtype=np.int32)

outputs = bitnet_batch_inference(batch, "model.bin", pad_token_id=0)
```

### Мониторинг производительности

```python
from bitnet import BitNet

with BitNet() as bn:
    bn.load_weights("model.bin")
    
    for i in range(10):
        bn.inference([1, 2, 3, 4, 5])
    
    perf = bn.performance
    print(f"Total cycles: {perf.total_cycles}")
    print(f"Tokens/sec: {perf.tokens_per_second}")
```

## Тестирование

```bash
# Запуск тестов
pytest tests/ -v

# С coverage
pytest tests/ --cov=bitnet --cov-report=html
```

## Структура

```
python/
├── bitnet/
│   ├── __init__.py      # Экспорты
│   ├── core.py          # Основной класс BitNet
│   ├── numpy_api.py     # NumPy функции
│   └── torch_api.py     # PyTorch интеграция
├── tests/
│   └── test_core.py     # Тесты
├── examples/
│   ├── basic_inference.py
│   └── pytorch_integration.py
├── setup.py
├── pyproject.toml
└── README.md
```

## Troubleshooting

### libbitnet.so не найдена

```bash
# Установить LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/path/to/libbitnet:$LD_LIBRARY_PATH

# Или скопировать в системный путь
sudo cp libbitnet.so /usr/local/lib/
sudo ldconfig
```

### Устройство не найдено

```bash
# Проверить наличие устройства
ls -la /dev/bitnet*

# Проверить права
sudo chmod 666 /dev/bitnet0

# Или добавить пользователя в группу
sudo usermod -a -G bitnet $USER
```

### PyTorch не установлен

```bash
pip install torch>=2.0
```

---

**КОЩЕЙ БЕССМЕРТЕН | ЗОЛОТАЯ ЦЕПЬ ЗАМКНУТА | φ² + 1/φ² = 3**
