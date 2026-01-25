"""
VIBEE BitNet Memory Benchmark Tests

Unit тесты для модуля измерения memory bandwidth.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
from unittest.mock import Mock, patch, MagicMock

from .mock_bitnet import MockBitNet, create_mock_bitnet


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def mock_driver():
    """Создать mock драйвер"""
    return create_mock_bitnet(
        bandwidth_gbps=50.0,
        jitter=0.0,
        preload_weights=True
    )


@pytest.fixture
def slow_memory_driver():
    """Mock драйвер с медленной памятью"""
    return create_mock_bitnet(
        bandwidth_gbps=10.0,
        jitter=0.0,
        preload_weights=True
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты вычисления bandwidth
# ═══════════════════════════════════════════════════════════════════════════════

class TestBandwidthCalculation:
    """Тесты вычисления bandwidth"""
    
    def test_basic_bandwidth(self):
        """Базовое вычисление GB/s"""
        bytes_transferred = 1_000_000_000  # 1 GB
        time_seconds = 0.02  # 20 мс
        bandwidth = bytes_transferred / time_seconds / 1e9
        assert bandwidth == 50.0
    
    def test_bandwidth_small_transfer(self):
        """Bandwidth для маленького трансфера"""
        bytes_transferred = 4096  # 4 KB
        time_seconds = 0.000001  # 1 мкс
        bandwidth = bytes_transferred / time_seconds / 1e9
        assert abs(bandwidth - 4.096) < 0.001
    
    def test_bandwidth_units(self):
        """Проверка единиц измерения"""
        # 1 GB за 1 секунду = 1 GB/s
        bytes_transferred = 1e9
        time_seconds = 1.0
        bandwidth_gbps = bytes_transferred / time_seconds / 1e9
        assert bandwidth_gbps == 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты MemoryBenchmark
# ═══════════════════════════════════════════════════════════════════════════════

class TestMemoryBenchmark:
    """Тесты класса MemoryBenchmark"""
    
    def test_init(self, mock_driver):
        """Проверка инициализации"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            assert bench._driver is mock_driver
    
    def test_run_benchmark(self, mock_driver):
        """Проверка запуска бенчмарка"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=65536,
                iterations=5
            )
            
            assert result is not None
            assert result.name == "memory"
            assert "bandwidth_gbps" in result.metrics
            assert "transfer_size" in result.parameters
    
    def test_different_transfer_sizes(self, mock_driver):
        """Проверка разных размеров трансфера"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            
            sizes = [4096, 16384, 65536]
            results = []
            
            for size in sizes:
                result = bench.run(
                    transfer_size=size,
                    iterations=3
                )
                results.append(result)
            
            assert len(results) == 3
            for r in results:
                assert r.metrics["bandwidth_gbps"] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты DMA операций
# ═══════════════════════════════════════════════════════════════════════════════

class TestDMAOperations:
    """Тесты DMA операций"""
    
    def test_dma_write(self, mock_driver):
        """Проверка DMA write"""
        data = bytes(4096)
        transfer_time = mock_driver.dma_write(data)
        
        assert transfer_time > 0
        # 4KB при 50 GB/s ≈ 0.00000008 сек
        assert transfer_time < 0.001
    
    def test_dma_read(self, mock_driver):
        """Проверка DMA read"""
        data, transfer_time = mock_driver.dma_read(4096)
        
        assert len(data) == 4096
        assert transfer_time > 0
    
    def test_dma_bandwidth_consistency(self, mock_driver):
        """Проверка согласованности bandwidth"""
        size = 1_000_000  # 1 MB
        
        write_time = mock_driver.dma_write(bytes(size))
        _, read_time = mock_driver.dma_read(size)
        
        write_bandwidth = size / write_time / 1e9
        read_bandwidth = size / read_time / 1e9
        
        # Оба должны быть около 50 GB/s
        assert 40 < write_bandwidth < 60
        assert 40 < read_bandwidth < 60


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты граничных случаев
# ═══════════════════════════════════════════════════════════════════════════════

class TestMemoryEdgeCases:
    """Тесты граничных случаев"""
    
    def test_minimal_transfer(self, mock_driver):
        """Минимальный размер трансфера"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=1,  # 1 байт
                iterations=3
            )
            
            assert result is not None
    
    def test_large_transfer(self, mock_driver):
        """Большой размер трансфера"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=1_000_000,  # 1 MB
                iterations=2
            )
            
            assert result is not None
            assert result.metrics["bandwidth_gbps"] > 0
    
    def test_single_iteration(self, mock_driver):
        """Одна итерация"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=4096,
                iterations=1
            )
            
            assert result is not None
    
    def test_slow_memory(self, slow_memory_driver):
        """Медленная память"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(slow_memory_driver)
            result = bench.run(
                transfer_size=65536,
                iterations=3
            )
            
            # Bandwidth должен быть около 10 GB/s
            assert 5 < result.metrics["bandwidth_gbps"] < 15


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты метрик
# ═══════════════════════════════════════════════════════════════════════════════

class TestMemoryMetrics:
    """Тесты метрик памяти"""
    
    def test_bandwidth_positive(self, mock_driver):
        """Bandwidth должен быть положительным"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=65536,
                iterations=5
            )
            
            assert result.metrics["bandwidth_gbps"] > 0
    
    def test_total_bytes_transferred(self, mock_driver):
        """Проверка общего объёма данных"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=4096,
                iterations=10
            )
            
            # total_bytes = transfer_size * iterations * 2 (read + write)
            expected_bytes = 4096 * 10 * 2
            if "total_bytes" in result.metrics:
                assert result.metrics["total_bytes"] == expected_bytes
    
    def test_parameters_recorded(self, mock_driver):
        """Проверка записи параметров"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            bench = MemoryBenchmark(mock_driver)
            result = bench.run(
                transfer_size=8192,
                iterations=7
            )
            
            assert result.parameters["transfer_size"] == 8192
            assert result.parameters["iterations"] == 7


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты сравнения
# ═══════════════════════════════════════════════════════════════════════════════

class TestMemoryComparison:
    """Тесты сравнения результатов"""
    
    def test_fast_vs_slow_memory(self, mock_driver, slow_memory_driver):
        """Сравнение быстрой и медленной памяти"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.memory import MemoryBenchmark
            
            fast_bench = MemoryBenchmark(mock_driver)
            slow_bench = MemoryBenchmark(slow_memory_driver)
            
            fast_result = fast_bench.run(transfer_size=65536, iterations=3)
            slow_result = slow_bench.run(transfer_size=65536, iterations=3)
            
            # Быстрая память должна иметь больший bandwidth
            assert fast_result.metrics["bandwidth_gbps"] > slow_result.metrics["bandwidth_gbps"]
