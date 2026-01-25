"""
VIBEE BitNet Mock Driver

Mock объект для тестирования без реального FPGA оборудования.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import time
import random
from dataclasses import dataclass
from typing import Optional, List, Dict, Any


# ═══════════════════════════════════════════════════════════════════════════════
# Mock Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class MockBitNetStatus:
    """Фиктивный статус акселератора"""
    state: str = "IDLE"
    current_layer: int = 0
    tokens_processed: int = 0
    error_code: int = 0


@dataclass
class MockBitNetPerformance:
    """Фиктивные метрики производительности"""
    total_cycles: int = 0
    dma_cycles: int = 0
    compute_cycles: int = 0
    tokens_per_second: int = 1000
    inference_count: int = 0


@dataclass
class MockBitNetModelInfo:
    """Фиктивная информация о модели"""
    num_layers: int = 12
    hidden_size: int = 768
    vocab_size: int = 32000
    max_seq_len: int = 2048
    weight_size: int = 100_000_000


# ═══════════════════════════════════════════════════════════════════════════════
# Mock BitNet Driver
# ═══════════════════════════════════════════════════════════════════════════════

class MockBitNet:
    """
    Mock реализация BitNet драйвера для тестирования.
    
    Имитирует поведение реального драйвера с настраиваемыми параметрами:
    - latency_ms: базовая задержка inference (по умолчанию 10 мс)
    - throughput_tps: токенов в секунду (по умолчанию 1000)
    - bandwidth_gbps: пропускная способность памяти (по умолчанию 50 GB/s)
    - jitter: случайное отклонение в % (по умолчанию 10%)
    
    Пример:
        >>> mock = MockBitNet(latency_ms=15.0, jitter=5.0)
        >>> mock.load_weights("model.bin")
        >>> result = mock.inference([1, 2, 3])
    """
    
    def __init__(
        self,
        device: str = "/dev/bitnet0",
        latency_ms: float = 10.0,
        throughput_tps: float = 1000.0,
        bandwidth_gbps: float = 50.0,
        jitter: float = 10.0
    ):
        """
        Args:
            device: Путь к устройству (игнорируется в mock)
            latency_ms: Базовая задержка inference в миллисекундах
            throughput_tps: Токенов в секунду
            bandwidth_gbps: Пропускная способность памяти в GB/s
            jitter: Случайное отклонение в процентах
        """
        self.device = device
        self._latency_ms = latency_ms
        self._throughput_tps = throughput_tps
        self._bandwidth_gbps = bandwidth_gbps
        self._jitter = jitter / 100.0
        
        self._is_open = True
        self._weights_loaded = False
        self._model_path: Optional[str] = None
        self._inference_count = 0
        self._tokens_processed = 0
        
        self._status = MockBitNetStatus()
        self._performance = MockBitNetPerformance()
        self._model_info = MockBitNetModelInfo()
    
    def _add_jitter(self, value: float) -> float:
        """Добавить случайное отклонение к значению"""
        if self._jitter <= 0:
            return value
        delta = value * self._jitter
        return value + random.uniform(-delta, delta)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # Основные методы
    # ═══════════════════════════════════════════════════════════════════════════
    
    def load_weights(self, path: str) -> None:
        """Загрузить веса модели (имитация)"""
        self._model_path = path
        self._weights_loaded = True
        self._status.state = "IDLE"
        # Имитация времени загрузки
        time.sleep(0.001)
    
    def inference(
        self,
        input_tokens: List[int],
        max_tokens: int = 1
    ) -> List[int]:
        """
        Выполнить inference (имитация).
        
        Args:
            input_tokens: Входные токены
            max_tokens: Максимум токенов для генерации
        
        Returns:
            Список сгенерированных токенов
        """
        if not self._weights_loaded:
            raise RuntimeError("Веса не загружены")
        
        self._status.state = "RUNNING"
        
        # Имитация задержки
        latency = self._add_jitter(self._latency_ms) / 1000.0
        time.sleep(latency)
        
        self._inference_count += 1
        self._tokens_processed += len(input_tokens) + max_tokens
        self._status.tokens_processed = self._tokens_processed
        self._performance.inference_count = self._inference_count
        
        self._status.state = "IDLE"
        
        # Возвращаем фиктивные токены
        return [random.randint(1, 32000) for _ in range(max_tokens)]
    
    def generate(
        self,
        input_tokens: List[int],
        max_new_tokens: int = 64,
        temperature: float = 1.0
    ) -> List[int]:
        """
        Генерация последовательности токенов.
        
        Args:
            input_tokens: Входные токены
            max_new_tokens: Количество новых токенов
            temperature: Температура сэмплирования
        
        Returns:
            Сгенерированные токены
        """
        output = []
        for _ in range(max_new_tokens):
            token = self.inference(input_tokens + output, max_tokens=1)[0]
            output.append(token)
        return output
    
    # ═══════════════════════════════════════════════════════════════════════════
    # DMA операции
    # ═══════════════════════════════════════════════════════════════════════════
    
    def dma_write(self, data: bytes, offset: int = 0) -> float:
        """
        Запись данных через DMA (имитация).
        
        Args:
            data: Данные для записи
            offset: Смещение в памяти
        
        Returns:
            Время передачи в секундах
        """
        size_gb = len(data) / 1e9
        transfer_time = size_gb / self._bandwidth_gbps
        transfer_time = self._add_jitter(transfer_time)
        time.sleep(transfer_time)
        return transfer_time
    
    def dma_read(self, size: int, offset: int = 0) -> tuple:
        """
        Чтение данных через DMA (имитация).
        
        Args:
            size: Размер данных в байтах
            offset: Смещение в памяти
        
        Returns:
            (данные, время передачи)
        """
        size_gb = size / 1e9
        transfer_time = size_gb / self._bandwidth_gbps
        transfer_time = self._add_jitter(transfer_time)
        time.sleep(transfer_time)
        return bytes(size), transfer_time
    
    # ═══════════════════════════════════════════════════════════════════════════
    # Статус и метрики
    # ═══════════════════════════════════════════════════════════════════════════
    
    @property
    def status(self) -> MockBitNetStatus:
        """Получить статус акселератора"""
        return self._status
    
    @property
    def performance(self) -> MockBitNetPerformance:
        """Получить метрики производительности"""
        self._performance.tokens_per_second = int(self._throughput_tps)
        return self._performance
    
    @property
    def model_info(self) -> MockBitNetModelInfo:
        """Получить информацию о модели"""
        return self._model_info
    
    @property
    def is_open(self) -> bool:
        """Проверить, открыто ли устройство"""
        return self._is_open
    
    # ═══════════════════════════════════════════════════════════════════════════
    # Управление ресурсами
    # ═══════════════════════════════════════════════════════════════════════════
    
    def close(self) -> None:
        """Закрыть устройство"""
        self._is_open = False
    
    def reset(self) -> None:
        """Сбросить акселератор"""
        self._status = MockBitNetStatus()
        self._inference_count = 0
        self._tokens_processed = 0
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Фабрика для создания mock объектов
# ═══════════════════════════════════════════════════════════════════════════════

def create_mock_bitnet(
    latency_ms: float = 10.0,
    throughput_tps: float = 1000.0,
    bandwidth_gbps: float = 50.0,
    jitter: float = 10.0,
    preload_weights: bool = True
) -> MockBitNet:
    """
    Создать настроенный mock BitNet драйвер.
    
    Args:
        latency_ms: Базовая задержка inference
        throughput_tps: Токенов в секунду
        bandwidth_gbps: Пропускная способность памяти
        jitter: Случайное отклонение в %
        preload_weights: Автоматически загрузить веса
    
    Returns:
        Настроенный MockBitNet
    """
    mock = MockBitNet(
        latency_ms=latency_ms,
        throughput_tps=throughput_tps,
        bandwidth_gbps=bandwidth_gbps,
        jitter=jitter
    )
    
    if preload_weights:
        mock.load_weights("mock_model.bin")
    
    return mock
