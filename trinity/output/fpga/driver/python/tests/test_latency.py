"""
VIBEE BitNet Latency Benchmark Tests

Unit тесты для модуля измерения latency.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
import statistics
from unittest.mock import Mock, patch, MagicMock

from .mock_bitnet import MockBitNet, create_mock_bitnet


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def mock_driver():
    """Создать mock драйвер с предзагруженными весами"""
    return create_mock_bitnet(
        latency_ms=10.0,
        jitter=0.0,  # Без jitter для предсказуемых тестов
        preload_weights=True
    )


@pytest.fixture
def sample_latencies():
    """Тестовые данные latency"""
    return [10.5, 11.2, 10.8, 12.1, 10.3, 11.0, 10.9, 11.5, 10.7, 11.1]


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты статистических функций
# ═══════════════════════════════════════════════════════════════════════════════

class TestStatistics:
    """Тесты вычисления статистик"""
    
    def test_calculate_mean(self, sample_latencies):
        """Проверка вычисления среднего"""
        mean = statistics.mean(sample_latencies)
        assert abs(mean - 11.01) < 0.01
    
    def test_calculate_median(self, sample_latencies):
        """Проверка вычисления медианы"""
        median = statistics.median(sample_latencies)
        assert abs(median - 10.95) < 0.01
    
    def test_calculate_percentiles(self, sample_latencies):
        """Проверка вычисления перцентилей"""
        sorted_data = sorted(sample_latencies)
        n = len(sorted_data)
        
        p50 = sorted_data[int(n * 0.50)]
        p90 = sorted_data[int(n * 0.90)]
        
        assert p50 == 10.9
        assert p90 == 11.5
    
    def test_empty_data(self):
        """Проверка обработки пустых данных"""
        with pytest.raises(statistics.StatisticsError):
            statistics.mean([])
    
    def test_single_value(self):
        """Проверка одного значения"""
        data = [10.0]
        assert statistics.mean(data) == 10.0
        assert statistics.median(data) == 10.0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты LatencyBenchmark
# ═══════════════════════════════════════════════════════════════════════════════

class TestLatencyBenchmark:
    """Тесты класса LatencyBenchmark"""
    
    def test_init(self, mock_driver):
        """Проверка инициализации"""
        # Импортируем с патчем зависимостей
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            assert bench._driver is mock_driver
    
    def test_measure_single_inference(self, mock_driver):
        """Проверка измерения одного inference"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            
            # Измеряем время одного inference
            import time
            start = time.perf_counter()
            mock_driver.inference([1, 2, 3], max_tokens=1)
            elapsed = (time.perf_counter() - start) * 1000  # мс
            
            # Должно быть около 10 мс (latency_ms=10.0, jitter=0)
            assert 9.0 < elapsed < 15.0
    
    def test_run_benchmark(self, mock_driver):
        """Проверка запуска бенчмарка"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=16,
                warmup_runs=2,
                measurement_runs=5
            )
            
            assert result is not None
            assert result.name == "latency"
            assert "mean" in result.metrics
            assert "p50" in result.metrics
            assert "p95" in result.metrics
            assert "p99" in result.metrics
            assert len(result.raw_data) == 5
    
    def test_warmup_runs(self, mock_driver):
        """Проверка прогревочных запусков"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            
            initial_count = mock_driver._inference_count
            
            bench.run(
                input_length=16,
                warmup_runs=3,
                measurement_runs=5
            )
            
            # Должно быть 3 warmup + 5 measurement = 8 вызовов
            assert mock_driver._inference_count == initial_count + 8
    
    def test_different_input_lengths(self, mock_driver):
        """Проверка разных длин входа"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            
            results = []
            for length in [16, 32, 64]:
                result = bench.run(
                    input_length=length,
                    warmup_runs=1,
                    measurement_runs=3
                )
                results.append(result)
            
            assert len(results) == 3
            for r in results:
                assert r.metrics["mean"] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты граничных случаев
# ═══════════════════════════════════════════════════════════════════════════════

class TestLatencyEdgeCases:
    """Тесты граничных случаев"""
    
    def test_zero_warmup(self, mock_driver):
        """Проверка без прогрева"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=16,
                warmup_runs=0,
                measurement_runs=5
            )
            
            assert result is not None
            assert len(result.raw_data) == 5
    
    def test_single_measurement(self, mock_driver):
        """Проверка одного измерения"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=16,
                warmup_runs=1,
                measurement_runs=1
            )
            
            assert result is not None
            assert len(result.raw_data) == 1
    
    def test_high_jitter(self):
        """Проверка с высоким jitter"""
        driver = create_mock_bitnet(
            latency_ms=10.0,
            jitter=50.0,  # 50% jitter
            preload_weights=True
        )
        
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(driver)
            result = bench.run(
                input_length=16,
                warmup_runs=2,
                measurement_runs=10
            )
            
            # С высоким jitter std должен быть больше
            assert result.metrics["std"] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты результатов
# ═══════════════════════════════════════════════════════════════════════════════

class TestLatencyResults:
    """Тесты структуры результатов"""
    
    def test_result_structure(self, mock_driver):
        """Проверка структуры результата"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=32,
                warmup_runs=2,
                measurement_runs=5
            )
            
            # Проверяем обязательные поля
            assert hasattr(result, 'name')
            assert hasattr(result, 'timestamp')
            assert hasattr(result, 'duration_seconds')
            assert hasattr(result, 'metrics')
            assert hasattr(result, 'parameters')
            assert hasattr(result, 'raw_data')
    
    def test_result_to_dict(self, mock_driver):
        """Проверка сериализации в dict"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=32,
                warmup_runs=2,
                measurement_runs=5
            )
            
            d = result.to_dict()
            assert isinstance(d, dict)
            assert "name" in d
            assert "metrics" in d
    
    def test_result_to_json(self, mock_driver):
        """Проверка сериализации в JSON"""
        with patch.dict('sys.modules', {'numpy': MagicMock()}):
            from bitnet.benchmark.latency import LatencyBenchmark
            import json
            
            bench = LatencyBenchmark(mock_driver)
            result = bench.run(
                input_length=32,
                warmup_runs=2,
                measurement_runs=5
            )
            
            json_str = result.to_json()
            parsed = json.loads(json_str)
            assert parsed["name"] == "latency"
