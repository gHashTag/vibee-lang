"""
VIBEE BitNet Visualization Tests

Unit тесты для модуля визуализации.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import pytest
import tempfile
import os
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch
from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Mock Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class MockBenchmarkResult:
    """Mock результат бенчмарка"""
    name: str
    timestamp: str = "2025-01-25T12:00:00"
    duration_seconds: float = 5.0
    metrics: Dict[str, Any] = field(default_factory=dict)
    parameters: Dict[str, Any] = field(default_factory=dict)
    raw_data: List[float] = field(default_factory=list)
    error: Optional[str] = None


@dataclass
class MockBenchmarkSuite:
    """Mock набор результатов"""
    name: str = "Test Suite"
    version: str = "1.0.0"
    timestamp: str = "2025-01-25T12:00:00"
    device: str = "/dev/bitnet0"
    model_path: str = "model.bin"
    results: List[MockBenchmarkResult] = field(default_factory=list)
    system_info: Dict[str, Any] = field(default_factory=dict)


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def sample_latency_data():
    """Тестовые данные latency"""
    return [10.5, 11.2, 10.8, 12.1, 10.3, 11.0, 10.9, 11.5, 10.7, 11.1]


@pytest.fixture
def latency_result(sample_latency_data):
    """Mock latency результат"""
    return MockBenchmarkResult(
        name="latency",
        metrics={
            "mean": 11.01,
            "p50": 10.95,
            "p95": 12.1,
            "p99": 12.1,
            "min": 10.3,
            "max": 12.1,
            "std": 0.5
        },
        parameters={
            "input_length": 32,
            "warmup_runs": 5,
            "measurement_runs": 10
        },
        raw_data=sample_latency_data
    )


@pytest.fixture
def throughput_result():
    """Mock throughput результат"""
    return MockBenchmarkResult(
        name="throughput",
        metrics={
            "tokens_per_second": 1250.5,
            "total_tokens": 12505
        },
        parameters={
            "input_length": 32,
            "output_length": 64
        }
    )


@pytest.fixture
def memory_result():
    """Mock memory результат"""
    return MockBenchmarkResult(
        name="memory",
        metrics={
            "bandwidth_gbps": 48.5,
            "total_bytes": 1000000
        },
        parameters={
            "transfer_size": 65536,
            "iterations": 100
        }
    )


@pytest.fixture
def full_suite(latency_result, throughput_result, memory_result):
    """Полный mock suite"""
    suite = MockBenchmarkSuite()
    suite.results = [latency_result, throughput_result, memory_result]
    return suite


@pytest.fixture
def mock_matplotlib():
    """Mock matplotlib"""
    with patch.dict('sys.modules', {
        'matplotlib': MagicMock(),
        'matplotlib.pyplot': MagicMock(),
        'matplotlib.patches': MagicMock(),
        'matplotlib.figure': MagicMock(),
        'numpy': MagicMock()
    }):
        yield


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты инициализации
# ═══════════════════════════════════════════════════════════════════════════════

class TestVisualizerInit:
    """Тесты инициализации BenchmarkVisualizer"""
    
    def test_init_with_suite(self, full_suite, mock_matplotlib):
        """Инициализация с suite"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        assert viz._suite is full_suite
        assert viz._config is not None
    
    def test_init_without_suite(self, mock_matplotlib):
        """Инициализация без suite"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        assert viz._suite is None
    
    def test_init_custom_config(self, full_suite, mock_matplotlib):
        """Инициализация с кастомной конфигурацией"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        custom_config = {
            "figsize": (12, 8),
            "dpi": 200,
            "font_size": 14
        }
        
        viz = BenchmarkVisualizer(full_suite, config=custom_config)
        
        assert viz._config["figsize"] == (12, 8)
        assert viz._config["dpi"] == 200
        assert viz._config["font_size"] == 14
    
    def test_default_config(self, mock_matplotlib):
        """Проверка конфигурации по умолчанию"""
        from bitnet.benchmark.visualization import DEFAULT_CONFIG
        
        assert "figsize" in DEFAULT_CONFIG
        assert "dpi" in DEFAULT_CONFIG
        assert "style" in DEFAULT_CONFIG


class TestCheckDependencies:
    """Тесты проверки зависимостей"""
    
    def test_missing_matplotlib(self):
        """Отсутствие matplotlib"""
        with patch.dict('sys.modules', {'matplotlib': None}):
            # Перезагрузить модуль для проверки
            pass  # Тест концептуальный
    
    def test_missing_numpy(self):
        """Отсутствие numpy"""
        with patch.dict('sys.modules', {'numpy': None}):
            pass  # Тест концептуальный


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Latency Charts
# ═══════════════════════════════════════════════════════════════════════════════

class TestLatencyCharts:
    """Тесты графиков latency"""
    
    def test_plot_latency_histogram(self, full_suite, mock_matplotlib):
        """Тест гистограммы latency"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        # Mock plt.subplots
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_latency_histogram()
            
            # Проверяем что subplots был вызван
            mock_plt.subplots.assert_called_once()
            
            # Проверяем что hist был вызван
            mock_ax.hist.assert_called_once()
    
    def test_plot_latency_histogram_empty_data(self, mock_matplotlib):
        """Тест гистограммы с пустыми данными"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        empty_result = MockBenchmarkResult(name="latency", raw_data=[])
        suite = MockBenchmarkSuite(results=[empty_result])
        
        viz = BenchmarkVisualizer(suite)
        
        with patch('bitnet.benchmark.visualization.plt'):
            with pytest.raises(ValueError):
                viz.plot_latency_histogram()
    
    def test_plot_latency_percentiles(self, full_suite, mock_matplotlib):
        """Тест bar chart percentiles"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_latency_percentiles()
            
            mock_ax.bar.assert_called_once()
    
    def test_plot_latency_boxplot(self, full_suite, mock_matplotlib):
        """Тест boxplot"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        mock_ax.boxplot.return_value = {"boxes": [MagicMock()]}
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_latency_boxplot()
            
            mock_ax.boxplot.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Throughput Charts
# ═══════════════════════════════════════════════════════════════════════════════

class TestThroughputCharts:
    """Тесты графиков throughput"""
    
    def test_plot_throughput_bar(self, full_suite, mock_matplotlib):
        """Тест bar chart throughput"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_throughput_bar()
            
            mock_ax.bar.assert_called_once()
    
    def test_plot_throughput_scaling(self, mock_matplotlib):
        """Тест scaling chart"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        # Создать несколько throughput результатов
        results = [
            MockBenchmarkResult(
                name="throughput",
                metrics={"tokens_per_second": 1000},
                parameters={"input_length": 32, "output_length": 16}
            ),
            MockBenchmarkResult(
                name="throughput",
                metrics={"tokens_per_second": 1500},
                parameters={"input_length": 32, "output_length": 32}
            ),
            MockBenchmarkResult(
                name="throughput",
                metrics={"tokens_per_second": 2000},
                parameters={"input_length": 32, "output_length": 64}
            )
        ]
        
        suite = MockBenchmarkSuite(results=results)
        viz = BenchmarkVisualizer(suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_throughput_scaling()
            
            # Должен быть вызван plot для line chart
            assert mock_ax.plot.called


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Memory Charts
# ═══════════════════════════════════════════════════════════════════════════════

class TestMemoryCharts:
    """Тесты графиков memory"""
    
    def test_plot_memory_bandwidth(self, full_suite, mock_matplotlib):
        """Тест bar chart bandwidth"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            fig = viz.plot_memory_bandwidth()
            
            mock_ax.bar.assert_called_once()
            # Проверяем что добавлена линия теоретического максимума
            mock_ax.axhline.assert_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Dashboard
# ═══════════════════════════════════════════════════════════════════════════════

class TestDashboard:
    """Тесты summary dashboard"""
    
    def test_plot_summary_dashboard(self, full_suite, mock_matplotlib):
        """Тест создания dashboard"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        mock_fig = MagicMock()
        mock_fig.add_gridspec.return_value = MagicMock()
        mock_fig.add_subplot.return_value = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.figure.return_value = mock_fig
            
            fig = viz.plot_summary_dashboard()
            
            # Проверяем что figure создан
            mock_plt.figure.assert_called_once()
            # Проверяем что gridspec создан
            mock_fig.add_gridspec.assert_called_once()
    
    def test_plot_summary_dashboard_no_suite(self, mock_matplotlib):
        """Тест dashboard без suite"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        
        with patch('bitnet.benchmark.visualization.plt'):
            with pytest.raises(ValueError):
                viz.plot_summary_dashboard()


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Save
# ═══════════════════════════════════════════════════════════════════════════════

class TestSave:
    """Тесты сохранения"""
    
    def test_save_single(self, mock_matplotlib):
        """Тест сохранения одного файла"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        mock_fig = MagicMock()
        
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = viz.save("test_plot", mock_fig, tmpdir, formats=["png"])
            
            assert len(paths) == 1
            assert paths[0].endswith(".png")
            mock_fig.savefig.assert_called_once()
    
    def test_save_multiple_formats(self, mock_matplotlib):
        """Тест сохранения в нескольких форматах"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        mock_fig = MagicMock()
        
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = viz.save("test_plot", mock_fig, tmpdir, formats=["png", "svg", "pdf"])
            
            assert len(paths) == 3
            assert mock_fig.savefig.call_count == 3
    
    def test_save_all(self, full_suite, mock_matplotlib):
        """Тест сохранения всех графиков"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer(full_suite)
        
        # Добавить mock figures
        mock_fig1 = MagicMock()
        mock_fig2 = MagicMock()
        viz._figures = [("plot1", mock_fig1), ("plot2", mock_fig2)]
        
        with tempfile.TemporaryDirectory() as tmpdir:
            result = viz.save_all(tmpdir, formats=["png"])
            
            assert "plot1" in result
            assert "plot2" in result
    
    def test_save_creates_directory(self, mock_matplotlib):
        """Тест создания директории"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        mock_fig = MagicMock()
        
        with tempfile.TemporaryDirectory() as tmpdir:
            new_dir = os.path.join(tmpdir, "new_subdir", "plots")
            paths = viz.save("test", mock_fig, new_dir)
            
            assert os.path.exists(new_dir)


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

class TestCleanup:
    """Тесты очистки"""
    
    def test_close_all(self, mock_matplotlib):
        """Тест закрытия всех figures"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        viz = BenchmarkVisualizer()
        
        mock_fig1 = MagicMock()
        mock_fig2 = MagicMock()
        viz._figures = [("plot1", mock_fig1), ("plot2", mock_fig2)]
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            viz.close_all()
            
            # Проверяем что close вызван для каждой figure
            assert mock_plt.close.call_count == 2
            # Проверяем что список очищен
            assert len(viz._figures) == 0


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Colors
# ═══════════════════════════════════════════════════════════════════════════════

class TestColors:
    """Тесты цветовой схемы"""
    
    def test_colors_defined(self):
        """Проверка определения цветов"""
        from bitnet.benchmark.visualization import COLORS
        
        required_colors = ["primary", "secondary", "latency", "throughput", "memory"]
        for color in required_colors:
            assert color in COLORS
            assert COLORS[color].startswith("#")
    
    def test_color_format(self):
        """Проверка формата цветов (hex)"""
        from bitnet.benchmark.visualization import COLORS
        
        for name, color in COLORS.items():
            assert len(color) == 7  # #RRGGBB
            assert color[0] == "#"


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

class TestHelperFunctions:
    """Тесты вспомогательных функций"""
    
    def test_visualize_results(self, full_suite, mock_matplotlib):
        """Тест функции visualize_results"""
        from bitnet.benchmark.visualization import visualize_results
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        mock_ax.boxplot.return_value = {"boxes": [MagicMock()]}
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            mock_plt.figure.return_value = mock_fig
            mock_fig.add_gridspec.return_value = MagicMock()
            mock_fig.add_subplot.return_value = mock_ax
            
            viz = visualize_results(full_suite)
            
            assert viz is not None
            assert isinstance(viz._figures, list)


# ═══════════════════════════════════════════════════════════════════════════════
# Тесты Edge Cases
# ═══════════════════════════════════════════════════════════════════════════════

class TestEdgeCases:
    """Тесты граничных случаев"""
    
    def test_empty_suite(self, mock_matplotlib):
        """Пустой suite"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        suite = MockBenchmarkSuite(results=[])
        viz = BenchmarkVisualizer(suite)
        
        with patch('bitnet.benchmark.visualization.plt'):
            with pytest.raises(ValueError):
                viz.plot_latency_histogram()
    
    def test_no_latency_results(self, mock_matplotlib):
        """Suite без latency результатов"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        suite = MockBenchmarkSuite(results=[
            MockBenchmarkResult(name="throughput", metrics={"tokens_per_second": 1000})
        ])
        viz = BenchmarkVisualizer(suite)
        
        with patch('bitnet.benchmark.visualization.plt'):
            with pytest.raises(ValueError):
                viz.plot_latency_histogram()
    
    def test_single_data_point(self, mock_matplotlib):
        """Один data point"""
        from bitnet.benchmark.visualization import BenchmarkVisualizer
        
        result = MockBenchmarkResult(
            name="latency",
            raw_data=[10.0],
            metrics={"mean": 10.0, "p50": 10.0, "p95": 10.0, "p99": 10.0}
        )
        suite = MockBenchmarkSuite(results=[result])
        viz = BenchmarkVisualizer(suite)
        
        mock_fig = MagicMock()
        mock_ax = MagicMock()
        
        with patch('bitnet.benchmark.visualization.plt') as mock_plt:
            mock_plt.subplots.return_value = (mock_fig, mock_ax)
            
            # Должен работать даже с одной точкой
            fig = viz.plot_latency_histogram()
            assert fig is not None
