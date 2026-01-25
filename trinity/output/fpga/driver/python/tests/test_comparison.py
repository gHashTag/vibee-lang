"""
VIBEE BitNet Comparison Tests

Unit тесты для модуля сравнения бенчмарков.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
import json
import tempfile
import os
from pathlib import Path

from bitnet.benchmark.comparison import (
    ComparisonStatus,
    ComparisonResult,
    ThresholdConfig,
    BenchmarkComparison,
    RegressionReport,
    BenchmarkComparator,
    compare_metric,
    is_higher_better,
    generate_text_report,
    generate_markdown_report,
    compare_files,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def baseline_suite():
    """Baseline результаты"""
    return {
        "timestamp": "2025-01-01T00:00:00",
        "model_path": "model_v1.bin",
        "results": [
            {
                "name": "latency",
                "metrics": {"mean": 10.0, "p95": 15.0, "p99": 20.0}
            },
            {
                "name": "throughput",
                "metrics": {"tokens_per_second": 1000}
            },
            {
                "name": "memory",
                "metrics": {"bandwidth_gbps": 50.0}
            }
        ]
    }


@pytest.fixture
def current_suite_regression():
    """Текущие результаты с регрессиями"""
    return {
        "timestamp": "2025-01-25T00:00:00",
        "model_path": "model_v2.bin",
        "results": [
            {
                "name": "latency",
                "metrics": {"mean": 12.0, "p95": 18.0, "p99": 25.0}
            },
            {
                "name": "throughput",
                "metrics": {"tokens_per_second": 900}
            },
            {
                "name": "memory",
                "metrics": {"bandwidth_gbps": 45.0}
            }
        ]
    }


@pytest.fixture
def current_suite_improved():
    """Текущие результаты с улучшениями"""
    return {
        "timestamp": "2025-01-25T00:00:00",
        "model_path": "model_v2.bin",
        "results": [
            {
                "name": "latency",
                "metrics": {"mean": 8.0, "p95": 12.0, "p99": 16.0}
            },
            {
                "name": "throughput",
                "metrics": {"tokens_per_second": 1200}
            },
            {
                "name": "memory",
                "metrics": {"bandwidth_gbps": 55.0}
            }
        ]
    }


@pytest.fixture
def current_suite_unchanged():
    """Текущие результаты без изменений"""
    return {
        "timestamp": "2025-01-25T00:00:00",
        "model_path": "model_v2.bin",
        "results": [
            {
                "name": "latency",
                "metrics": {"mean": 10.2, "p95": 15.3, "p99": 20.5}
            },
            {
                "name": "throughput",
                "metrics": {"tokens_per_second": 1010}
            },
            {
                "name": "memory",
                "metrics": {"bandwidth_gbps": 50.5}
            }
        ]
    }


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты compare_metric
# ═══════════════════════════════════════════════════════════════════════════════

class TestCompareMetric:
    """Тесты функции compare_metric"""
    
    def test_regression_latency(self):
        """Регрессия latency (увеличение)"""
        result = compare_metric("mean", 10.0, 12.0, threshold=5.0, higher_is_better=False)
        
        assert result.status == ComparisonStatus.REGRESSION
        assert result.percent_diff == 20.0
        assert result.absolute_diff == 2.0
    
    def test_improvement_latency(self):
        """Улучшение latency (уменьшение)"""
        result = compare_metric("mean", 10.0, 8.0, threshold=5.0, higher_is_better=False)
        
        assert result.status == ComparisonStatus.IMPROVED
        assert result.percent_diff == -20.0
        assert result.absolute_diff == -2.0
    
    def test_unchanged(self):
        """Без изменений (в пределах порога)"""
        result = compare_metric("mean", 10.0, 10.2, threshold=5.0, higher_is_better=False)
        
        assert result.status == ComparisonStatus.UNCHANGED
        assert abs(result.percent_diff) < 5.0
    
    def test_throughput_improvement(self):
        """Улучшение throughput (увеличение)"""
        result = compare_metric("tokens_per_second", 1000, 1200, threshold=5.0, higher_is_better=True)
        
        assert result.status == ComparisonStatus.IMPROVED
        assert result.percent_diff == 20.0
    
    def test_throughput_regression(self):
        """Регрессия throughput (уменьшение)"""
        result = compare_metric("tokens_per_second", 1000, 800, threshold=5.0, higher_is_better=True)
        
        assert result.status == ComparisonStatus.REGRESSION
        assert result.percent_diff == -20.0
    
    def test_zero_baseline(self):
        """Нулевой baseline"""
        result = compare_metric("mean", 0.0, 10.0, threshold=5.0, higher_is_better=False)
        
        assert result.percent_diff == 100.0
    
    def test_exact_threshold(self):
        """Точно на пороге"""
        result = compare_metric("mean", 100.0, 105.0, threshold=5.0, higher_is_better=False)
        
        # На границе порога - unchanged
        assert result.status == ComparisonStatus.UNCHANGED
    
    def test_just_over_threshold(self):
        """Чуть выше порога"""
        result = compare_metric("mean", 100.0, 106.0, threshold=5.0, higher_is_better=False)
        
        assert result.status == ComparisonStatus.REGRESSION


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты is_higher_better
# ═══════════════════════════════════════════════════════════════════════════════

class TestIsHigherBetter:
    """Тесты функции is_higher_better"""
    
    def test_throughput_metrics(self):
        """Throughput метрики - больше лучше"""
        assert is_higher_better("tokens_per_second") is True
        assert is_higher_better("throughput") is True
        assert is_higher_better("bandwidth_gbps") is True
    
    def test_latency_metrics(self):
        """Latency метрики - меньше лучше"""
        assert is_higher_better("mean") is False
        assert is_higher_better("p95") is False
        assert is_higher_better("p99") is False
    
    def test_unknown_metric(self):
        """Неизвестная метрика - по умолчанию False"""
        assert is_higher_better("unknown_metric") is False


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты ThresholdConfig
# ═══════════════════════════════════════════════════════════════════════════════

class TestThresholdConfig:
    """Тесты конфигурации порогов"""
    
    def test_default_values(self):
        """Значения по умолчанию"""
        config = ThresholdConfig()
        
        assert config.latency_mean == 5.0
        assert config.latency_p95 == 10.0
        assert config.throughput == 5.0
    
    def test_get_threshold(self):
        """Получение порога для метрики"""
        config = ThresholdConfig()
        
        assert config.get_threshold("mean") == 5.0
        assert config.get_threshold("p95") == 10.0
        assert config.get_threshold("p99") == 15.0
        assert config.get_threshold("tokens_per_second") == 5.0
    
    def test_get_threshold_unknown(self):
        """Порог для неизвестной метрики"""
        config = ThresholdConfig()
        
        assert config.get_threshold("unknown") == config.default
    
    def test_custom_thresholds(self):
        """Кастомные пороги"""
        config = ThresholdConfig(latency_mean=10.0, throughput=3.0)
        
        assert config.latency_mean == 10.0
        assert config.throughput == 3.0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты ComparisonResult
# ═══════════════════════════════════════════════════════════════════════════════

class TestComparisonResult:
    """Тесты ComparisonResult"""
    
    def test_to_dict(self):
        """Сериализация в dict"""
        result = ComparisonResult(
            metric_name="mean",
            baseline_value=10.0,
            current_value=12.0,
            absolute_diff=2.0,
            percent_diff=20.0,
            status=ComparisonStatus.REGRESSION
        )
        
        d = result.to_dict()
        
        assert d["metric_name"] == "mean"
        assert d["baseline_value"] == 10.0
        assert d["current_value"] == 12.0
        assert d["status"] == "regression"


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты BenchmarkComparison
# ═══════════════════════════════════════════════════════════════════════════════

class TestBenchmarkComparison:
    """Тесты BenchmarkComparison"""
    
    def test_has_regression(self):
        """Проверка наличия регрессий"""
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10, 12, 2, 20, ComparisonStatus.REGRESSION),
            ComparisonResult("p95", 15, 15, 0, 0, ComparisonStatus.UNCHANGED),
        ]
        
        assert comparison.has_regression is True
    
    def test_has_improvement(self):
        """Проверка наличия улучшений"""
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10, 8, -2, -20, ComparisonStatus.IMPROVED),
        ]
        
        assert comparison.has_improvement is True
    
    def test_no_regression(self):
        """Нет регрессий"""
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10, 10, 0, 0, ComparisonStatus.UNCHANGED),
        ]
        
        assert comparison.has_regression is False


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты RegressionReport
# ═══════════════════════════════════════════════════════════════════════════════

class TestRegressionReport:
    """Тесты RegressionReport"""
    
    def test_counts(self):
        """Подсчёт метрик"""
        report = RegressionReport(
            baseline_timestamp="2025-01-01",
            current_timestamp="2025-01-25",
            baseline_model="v1",
            current_model="v2"
        )
        
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10, 12, 2, 20, ComparisonStatus.REGRESSION),
            ComparisonResult("p95", 15, 12, -3, -20, ComparisonStatus.IMPROVED),
            ComparisonResult("p99", 20, 20, 0, 0, ComparisonStatus.UNCHANGED),
        ]
        report.benchmark_comparisons = [comparison]
        
        assert report.total_metrics == 3
        assert report.regression_count == 1
        assert report.improved_count == 1
        assert report.unchanged_count == 1
    
    def test_has_regressions(self):
        """Проверка has_regressions"""
        report = RegressionReport(
            baseline_timestamp="2025-01-01",
            current_timestamp="2025-01-25",
            baseline_model="v1",
            current_model="v2"
        )
        
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10, 12, 2, 20, ComparisonStatus.REGRESSION),
        ]
        report.benchmark_comparisons = [comparison]
        
        assert report.has_regressions is True
    
    def test_to_json(self):
        """Сериализация в JSON"""
        report = RegressionReport(
            baseline_timestamp="2025-01-01",
            current_timestamp="2025-01-25",
            baseline_model="v1",
            current_model="v2"
        )
        
        json_str = report.to_json()
        parsed = json.loads(json_str)
        
        assert parsed["baseline_timestamp"] == "2025-01-01"
        assert "has_regressions" in parsed


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты BenchmarkComparator
# ═══════════════════════════════════════════════════════════════════════════════

class TestBenchmarkComparator:
    """Тесты BenchmarkComparator"""
    
    def test_set_baseline(self, baseline_suite):
        """Установка baseline"""
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline_suite)
        
        assert comparator._baseline is not None
        assert comparator._baseline["model_path"] == "model_v1.bin"
    
    def test_set_current(self, current_suite_regression):
        """Установка current"""
        comparator = BenchmarkComparator()
        comparator.set_current(current_suite_regression)
        
        assert comparator._current is not None
    
    def test_compare_regression(self, baseline_suite, current_suite_regression):
        """Сравнение с регрессиями"""
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline_suite)
        comparator.set_current(current_suite_regression)
        
        report = comparator.compare()
        
        assert report.has_regressions is True
        assert report.regression_count > 0
    
    def test_compare_improved(self, baseline_suite, current_suite_improved):
        """Сравнение с улучшениями"""
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline_suite)
        comparator.set_current(current_suite_improved)
        
        report = comparator.compare()
        
        assert report.improved_count > 0
    
    def test_compare_unchanged(self, baseline_suite, current_suite_unchanged):
        """Сравнение без изменений"""
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline_suite)
        comparator.set_current(current_suite_unchanged)
        
        report = comparator.compare()
        
        assert report.unchanged_count > 0
    
    def test_compare_without_data(self):
        """Сравнение без данных"""
        comparator = BenchmarkComparator()
        
        with pytest.raises(ValueError):
            comparator.compare()
    
    def test_load_baseline_file(self, baseline_suite):
        """Загрузка baseline из файла"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(baseline_suite, f)
            path = f.name
        
        try:
            comparator = BenchmarkComparator()
            comparator.load_baseline(path)
            
            assert comparator._baseline is not None
        finally:
            os.unlink(path)
    
    def test_save_baseline(self, baseline_suite):
        """Сохранение baseline"""
        comparator = BenchmarkComparator()
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            path = f.name
        
        try:
            comparator.save_baseline(baseline_suite, path)
            
            with open(path, 'r') as f:
                loaded = json.load(f)
            
            assert loaded["model_path"] == baseline_suite["model_path"]
        finally:
            os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Report Generators
# ═══════════════════════════════════════════════════════════════════════════════

class TestReportGenerators:
    """Тесты генераторов отчётов"""
    
    @pytest.fixture
    def sample_report(self):
        """Пример отчёта"""
        report = RegressionReport(
            baseline_timestamp="2025-01-01",
            current_timestamp="2025-01-25",
            baseline_model="model_v1.bin",
            current_model="model_v2.bin"
        )
        
        comparison = BenchmarkComparison(benchmark_name="latency")
        comparison.comparisons = [
            ComparisonResult("mean", 10.0, 12.0, 2.0, 20.0, ComparisonStatus.REGRESSION),
            ComparisonResult("p95", 15.0, 12.0, -3.0, -20.0, ComparisonStatus.IMPROVED),
        ]
        report.benchmark_comparisons = [comparison]
        
        return report
    
    def test_generate_text_report(self, sample_report):
        """Генерация текстового отчёта"""
        text = generate_text_report(sample_report)
        
        assert "Benchmark Comparison Report" in text or "VIBEE" in text
        assert "Baseline" in text
        assert "regression" in text.lower() or "❌" in text
    
    def test_generate_markdown_report(self, sample_report):
        """Генерация Markdown отчёта"""
        md = generate_markdown_report(sample_report)
        
        assert "# Benchmark Comparison Report" in md
        assert "|" in md  # Таблицы
        assert "❌" in md or "✅" in md
    
    def test_text_report_contains_stats(self, sample_report):
        """Текстовый отчёт содержит статистику"""
        text = generate_text_report(sample_report)
        
        assert "Improved" in text or "improved" in text.lower()
        assert "Regression" in text or "regression" in text.lower()
    
    def test_markdown_report_has_tables(self, sample_report):
        """Markdown отчёт содержит таблицы"""
        md = generate_markdown_report(sample_report)
        
        assert "| Metric |" in md or "| metric |" in md.lower()
        assert "|-----" in md


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты compare_files
# ═══════════════════════════════════════════════════════════════════════════════

class TestCompareFiles:
    """Тесты функции compare_files"""
    
    def test_compare_files_regression(self, baseline_suite, current_suite_regression):
        """Сравнение файлов с регрессиями"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(baseline_suite, f)
            baseline_path = f.name
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(current_suite_regression, f)
            current_path = f.name
        
        try:
            # Без fail_on_regression
            exit_code = compare_files(baseline_path, current_path, fail_on_regression=False)
            assert exit_code == 0
            
            # С fail_on_regression
            exit_code = compare_files(baseline_path, current_path, fail_on_regression=True)
            assert exit_code == 1
        finally:
            os.unlink(baseline_path)
            os.unlink(current_path)
    
    def test_compare_files_no_regression(self, baseline_suite, current_suite_improved):
        """Сравнение файлов без регрессий"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(baseline_suite, f)
            baseline_path = f.name
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(current_suite_improved, f)
            current_path = f.name
        
        try:
            exit_code = compare_files(baseline_path, current_path, fail_on_regression=True)
            assert exit_code == 0
        finally:
            os.unlink(baseline_path)
            os.unlink(current_path)


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Edge Cases
# ═══════════════════════════════════════════════════════════════════════════════

class TestEdgeCases:
    """Тесты граничных случаев"""
    
    def test_empty_results(self):
        """Пустые результаты"""
        comparator = BenchmarkComparator()
        comparator.set_baseline({"timestamp": "t1", "model_path": "m1", "results": []})
        comparator.set_current({"timestamp": "t2", "model_path": "m2", "results": []})
        
        report = comparator.compare()
        
        assert report.total_metrics == 0
        assert report.has_regressions is False
    
    def test_missing_metric_in_current(self, baseline_suite):
        """Метрика отсутствует в current"""
        current = {
            "timestamp": "2025-01-25",
            "model_path": "model_v2.bin",
            "results": [
                {"name": "latency", "metrics": {"mean": 10.0}}  # Нет p95, p99
            ]
        }
        
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline_suite)
        comparator.set_current(current)
        
        report = comparator.compare()
        
        # Должен сравнить только общие метрики
        assert report.total_metrics >= 1
    
    def test_non_numeric_metrics(self):
        """Не-числовые метрики игнорируются"""
        baseline = {
            "timestamp": "t1",
            "model_path": "m1",
            "results": [
                {"name": "test", "metrics": {"mean": 10.0, "status": "ok"}}
            ]
        }
        current = {
            "timestamp": "t2",
            "model_path": "m2",
            "results": [
                {"name": "test", "metrics": {"mean": 12.0, "status": "ok"}}
            ]
        }
        
        comparator = BenchmarkComparator()
        comparator.set_baseline(baseline)
        comparator.set_current(current)
        
        report = comparator.compare()
        
        # Только числовая метрика mean
        assert report.total_metrics == 1
    
    def test_very_small_values(self):
        """Очень маленькие значения"""
        result = compare_metric("latency", 0.001, 0.002, threshold=5.0, higher_is_better=False)
        
        assert result.percent_diff == 100.0
        assert result.status == ComparisonStatus.REGRESSION
    
    def test_negative_values(self):
        """Отрицательные значения (если допустимы)"""
        result = compare_metric("delta", -10.0, -8.0, threshold=5.0, higher_is_better=True)
        
        # -8 > -10, улучшение
        assert result.percent_diff == -20.0  # (-8 - (-10)) / -10 * 100
