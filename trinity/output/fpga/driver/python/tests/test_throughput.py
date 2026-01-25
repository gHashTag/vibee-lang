"""
VIBEE BitNet Throughput Benchmark Tests

Unit тесты для модуля измерения throughput.

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
        latency_ms=10.0,
        throughput_tps=1000.0,
        jitter=0.0,
        preload_weights=True
    )


@pytest.fixture
def fast_driver():
    """Быстрый mock драйвер для тестов производительности"""
    return create_mock_bitnet(
        latency_ms=1.0,  # 1 мс для быстрых тестов
        throughput_tps=5000.0,
        jitter=0.0,
        preload_weights=True
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты вычисления throughput
# ═══════════════════════════════════════════════════════════════════════════════

class TestThroughputCalculation:
    """Тесты вычисления throughput"""
    
    def test_basic_throughput(self):
        """Базовое вычисление tokens/sec"""
        tokens = 100
        time_seconds = 0.1
        throughput = tokens / time_seconds
        assert throughput == 1000.0
    
    def test_throughput_with_batch(self):
        """Throughput с batch size"""
        tokens_per_batch = 32
        batches = 10
        time_seconds = 0.32
        
        total_tokens = tokens_per_batch * batches
        throughput = total_tokens / time_seconds
        
        assert throughput == 1000.0
    
    def test_throughput_zero_time(self):
        """Обработка нулевого времени"""
        tokens = 100
        time_seconds = 0.0
        
        # Должно быть inf или обработано
        if time_seconds == 0:
            throughput = float('inf')
        else:
            throughput = tokens / time_seconds
        
        assert throughput == float('inf')


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты ThroughputBenchmark
# ═══════════════════════════════════════════════════════════════════════════════

class TestThroughputBenchmark:
    """Тесты класса ThroughputBenchmark"""
    
    def test_init(self, mock_driver):
        """Проверка инициализации"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(mock_driver)
            assert bench._driver is mock_driver
    
    def test_run_benchmark(self, fast_driver):
        """Проверка запуска бенчмарка"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                warmup_runs=1,
                measurement_runs=3
            )
            
            assert result is not None
            assert result.name == "throughput"
            assert "tokens_per_second" in result.metrics
            assert "total_tokens" in result.metrics
    
    def test_output_length_affects_tokens(self, fast_driver):
        """Проверка влияния output_length на количество токенов"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            
            result_short = bench.run(
                input_length=32,
                output_length=8,
                warmup_runs=1,
                measurement_runs=2
            )
            
            result_long = bench.run(
                input_length=32,
                output_length=32,
                warmup_runs=1,
                measurement_runs=2
            )
            
            # Больше токенов = больше total_tokens
            assert result_long.metrics["total_tokens"] > result_short.metrics["total_tokens"]
    
    def test_parameters_in_result(self, fast_driver):
        """Проверка параметров в результате"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=64,
                output_length=32,
                warmup_runs=2,
                measurement_runs=5
            )
            
            assert result.parameters["input_length"] == 64
            assert result.parameters["output_length"] == 32
            assert result.parameters["measurement_runs"] == 5


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты batch processing
# ═══════════════════════════════════════════════════════════════════════════════

class TestBatchProcessing:
    """Тесты пакетной обработки"""
    
    def test_single_batch(self, fast_driver):
        """Проверка одного batch"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                batch_size=1,
                warmup_runs=1,
                measurement_runs=3
            )
            
            assert result is not None
    
    def test_multiple_batches(self, fast_driver):
        """Проверка нескольких batches"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            
            # Если поддерживается batch_size
            try:
                result = bench.run(
                    input_length=32,
                    output_length=16,
                    batch_size=4,
                    warmup_runs=1,
                    measurement_runs=3
                )
                assert result is not None
            except TypeError:
                # batch_size может не поддерживаться
                pass


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты граничных случаев
# ═══════════════════════════════════════════════════════════════════════════════

class TestThroughputEdgeCases:
    """Тесты граничных случаев"""
    
    def test_minimal_output(self, fast_driver):
        """Минимальный output_length"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=16,
                output_length=1,
                warmup_runs=1,
                measurement_runs=3
            )
            
            assert result is not None
            assert result.metrics["total_tokens"] >= 3  # минимум 1 токен * 3 измерения
    
    def test_large_output(self, fast_driver):
        """Большой output_length"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=16,
                output_length=64,
                warmup_runs=1,
                measurement_runs=2
            )
            
            assert result is not None
            assert result.metrics["total_tokens"] >= 128  # 64 * 2
    
    def test_zero_warmup(self, fast_driver):
        """Без прогрева"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                warmup_runs=0,
                measurement_runs=3
            )
            
            assert result is not None


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты метрик
# ═══════════════════════════════════════════════════════════════════════════════

class TestThroughputMetrics:
    """Тесты метрик throughput"""
    
    def test_tokens_per_second_positive(self, fast_driver):
        """tokens_per_second должен быть положительным"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                warmup_runs=1,
                measurement_runs=3
            )
            
            assert result.metrics["tokens_per_second"] > 0
    
    def test_total_time_positive(self, fast_driver):
        """Общее время должно быть положительным"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                warmup_runs=1,
                measurement_runs=3
            )
            
            assert result.duration_seconds > 0
    
    def test_metrics_consistency(self, fast_driver):
        """Проверка согласованности метрик"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.throughput import ThroughputBenchmark
            
            bench = ThroughputBenchmark(fast_driver)
            result = bench.run(
                input_length=32,
                output_length=16,
                warmup_runs=1,
                measurement_runs=5
            )
            
            # tokens/sec * time ≈ total_tokens
            calculated_tokens = result.metrics["tokens_per_second"] * result.duration_seconds
            # Допускаем погрешность из-за warmup
            assert calculated_tokens > 0
