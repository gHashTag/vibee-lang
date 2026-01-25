"""
VIBEE BitNet Benchmark Visualization

Модуль визуализации результатов бенчмарков.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

from typing import List, Dict, Any, Optional, Tuple, Union
from pathlib import Path
import json

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.figure import Figure
    from matplotlib.axes import Axes
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False


# ═══════════════════════════════════════════════════════════════════════════════
# Цветовая схема VIBEE
# ═══════════════════════════════════════════════════════════════════════════════

COLORS = {
    "primary": "#6366F1",
    "secondary": "#8B5CF6",
    "success": "#10B981",
    "warning": "#F59E0B",
    "error": "#EF4444",
    "latency": "#3B82F6",
    "throughput": "#10B981",
    "memory": "#F59E0B",
    "p50": "#3B82F6",
    "p95": "#F59E0B",
    "p99": "#EF4444",
}

# ═══════════════════════════════════════════════════════════════════════════════
# Конфигурация по умолчанию
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_CONFIG = {
    "figsize": (10, 6),
    "dpi": 150,
    "style": "seaborn-v0_8-whitegrid",
    "font_size": 12,
    "title_size": 14,
    "grid": True,
    "grid_alpha": 0.3,
}


# ═══════════════════════════════════════════════════════════════════════════════
# Проверка зависимостей
# ═══════════════════════════════════════════════════════════════════════════════

def check_dependencies():
    """Проверить наличие matplotlib и numpy"""
    if not HAS_MATPLOTLIB:
        raise ImportError(
            "matplotlib не установлен. Установите: pip install matplotlib"
        )
    if not HAS_NUMPY:
        raise ImportError(
            "numpy не установлен. Установите: pip install numpy"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Базовый класс визуализации
# ═══════════════════════════════════════════════════════════════════════════════

class BenchmarkVisualizer:
    """
    Визуализатор результатов бенчмарков.
    
    Пример:
        >>> viz = BenchmarkVisualizer(suite)
        >>> viz.plot_latency_histogram()
        >>> viz.save_all("output/")
    """
    
    def __init__(
        self,
        suite: Any = None,
        config: Optional[Dict[str, Any]] = None
    ):
        """
        Args:
            suite: BenchmarkSuite с результатами
            config: Конфигурация визуализации
        """
        check_dependencies()
        
        self._suite = suite
        self._config = {**DEFAULT_CONFIG, **(config or {})}
        self._figures: List[Tuple[str, Figure]] = []
        
        # Применить стиль
        try:
            plt.style.use(self._config["style"])
        except:
            pass  # Стиль может быть недоступен
    
    def _create_figure(
        self,
        title: str,
        figsize: Optional[Tuple[int, int]] = None
    ) -> Tuple[Figure, Axes]:
        """Создать новую фигуру"""
        fig, ax = plt.subplots(
            figsize=figsize or self._config["figsize"],
            dpi=self._config["dpi"]
        )
        ax.set_title(title, fontsize=self._config["title_size"], fontweight="bold")
        
        if self._config["grid"]:
            ax.grid(True, alpha=self._config["grid_alpha"])
        
        return fig, ax
    
    def _get_results_by_name(self, name: str) -> List[Any]:
        """Получить результаты по имени бенчмарка"""
        if not self._suite:
            return []
        return [r for r in self._suite.results if r.name == name]

    # ═══════════════════════════════════════════════════════════════════════════
    # Latency Charts
    # ═══════════════════════════════════════════════════════════════════════════
    
    def plot_latency_histogram(
        self,
        result: Any = None,
        bins: int = 30,
        show_stats: bool = True
    ) -> Figure:
        """
        Гистограмма распределения latency.
        
        Args:
            result: BenchmarkResult (или первый latency результат из suite)
            bins: Количество bins
            show_stats: Показать mean/median линии
        
        Returns:
            matplotlib Figure
        """
        if result is None:
            results = self._get_results_by_name("latency")
            if not results:
                raise ValueError("Нет данных latency")
            result = results[0]
        
        data = result.raw_data
        if not data:
            raise ValueError("raw_data пуст")
        
        fig, ax = self._create_figure("Latency Distribution")
        
        # Гистограмма
        n, bins_edges, patches = ax.hist(
            data, bins=bins,
            color=COLORS["latency"],
            alpha=0.7,
            edgecolor="white",
            linewidth=0.5
        )
        
        if show_stats:
            mean_val = np.mean(data)
            median_val = np.median(data)
            
            ax.axvline(mean_val, color=COLORS["error"], linestyle="--",
                      linewidth=2, label=f"Mean: {mean_val:.2f} ms")
            ax.axvline(median_val, color=COLORS["success"], linestyle="-.",
                      linewidth=2, label=f"Median: {median_val:.2f} ms")
            ax.legend(loc="upper right")
        
        ax.set_xlabel("Latency (ms)", fontsize=self._config["font_size"])
        ax.set_ylabel("Frequency", fontsize=self._config["font_size"])
        
        plt.tight_layout()
        self._figures.append(("latency_histogram", fig))
        return fig
    
    def plot_latency_percentiles(
        self,
        result: Any = None
    ) -> Figure:
        """
        Bar chart с percentiles latency.
        
        Args:
            result: BenchmarkResult с metrics
        
        Returns:
            matplotlib Figure
        """
        if result is None:
            results = self._get_results_by_name("latency")
            if not results:
                raise ValueError("Нет данных latency")
            result = results[0]
        
        metrics = result.metrics
        
        percentiles = ["min", "p50", "p95", "p99", "max"]
        values = [metrics.get(p, 0) for p in percentiles]
        colors = [COLORS["success"], COLORS["p50"], COLORS["p95"], 
                  COLORS["p99"], COLORS["error"]]
        
        fig, ax = self._create_figure("Latency Percentiles")
        
        bars = ax.bar(percentiles, values, color=colors, edgecolor="white", linewidth=1)
        
        # Добавить значения над барами
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                   f"{val:.2f}", ha="center", va="bottom", fontsize=10)
        
        ax.set_xlabel("Percentile", fontsize=self._config["font_size"])
        ax.set_ylabel("Latency (ms)", fontsize=self._config["font_size"])
        
        plt.tight_layout()
        self._figures.append(("latency_percentiles", fig))
        return fig
    
    def plot_latency_boxplot(
        self,
        results: Optional[List[Any]] = None
    ) -> Figure:
        """
        Box plot для сравнения latency.
        
        Args:
            results: Список BenchmarkResult
        
        Returns:
            matplotlib Figure
        """
        if results is None:
            results = self._get_results_by_name("latency")
        
        if not results:
            raise ValueError("Нет данных latency")
        
        fig, ax = self._create_figure("Latency Comparison")
        
        data = [r.raw_data for r in results if r.raw_data]
        labels = [f"Run {i+1}" for i in range(len(data))]
        
        bp = ax.boxplot(data, labels=labels, patch_artist=True)
        
        for patch in bp["boxes"]:
            patch.set_facecolor(COLORS["latency"])
            patch.set_alpha(0.7)
        
        ax.set_xlabel("Benchmark Run", fontsize=self._config["font_size"])
        ax.set_ylabel("Latency (ms)", fontsize=self._config["font_size"])
        
        plt.tight_layout()
        self._figures.append(("latency_boxplot", fig))
        return fig

    # ═══════════════════════════════════════════════════════════════════════════
    # Throughput Charts
    # ═══════════════════════════════════════════════════════════════════════════
    
    def plot_throughput_bar(
        self,
        results: Optional[List[Any]] = None
    ) -> Figure:
        """
        Bar chart throughput.
        
        Args:
            results: Список BenchmarkResult
        
        Returns:
            matplotlib Figure
        """
        if results is None:
            results = self._get_results_by_name("throughput")
        
        if not results:
            raise ValueError("Нет данных throughput")
        
        fig, ax = self._create_figure("Throughput Performance")
        
        labels = []
        values = []
        
        for r in results:
            tps = r.metrics.get("tokens_per_second", 0)
            params = r.parameters
            label = f"in={params.get('input_length', '?')}\nout={params.get('output_length', '?')}"
            labels.append(label)
            values.append(tps)
        
        bars = ax.bar(labels, values, color=COLORS["throughput"], 
                     edgecolor="white", linewidth=1)
        
        # Значения над барами
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 10,
                   f"{val:.0f}", ha="center", va="bottom", fontsize=10)
        
        ax.set_xlabel("Configuration", fontsize=self._config["font_size"])
        ax.set_ylabel("Tokens/sec", fontsize=self._config["font_size"])
        
        plt.tight_layout()
        self._figures.append(("throughput_bar", fig))
        return fig
    
    def plot_throughput_scaling(
        self,
        results: Optional[List[Any]] = None
    ) -> Figure:
        """
        Line chart scaling throughput.
        
        Args:
            results: Список BenchmarkResult с разными batch sizes
        
        Returns:
            matplotlib Figure
        """
        if results is None:
            results = self._get_results_by_name("throughput")
        
        if not results:
            raise ValueError("Нет данных throughput")
        
        fig, ax = self._create_figure("Throughput Scaling")
        
        # Сортировать по output_length
        sorted_results = sorted(
            results,
            key=lambda r: r.parameters.get("output_length", 0)
        )
        
        x = [r.parameters.get("output_length", 0) for r in sorted_results]
        y = [r.metrics.get("tokens_per_second", 0) for r in sorted_results]
        
        ax.plot(x, y, marker="o", markersize=8, linewidth=2,
               color=COLORS["throughput"], label="Measured")
        
        # Идеальная линия (линейное масштабирование)
        if x and y:
            ideal_y = [y[0] * (xi / x[0]) if x[0] > 0 else 0 for xi in x]
            ax.plot(x, ideal_y, linestyle="--", color=COLORS["secondary"],
                   alpha=0.5, label="Ideal scaling")
        
        ax.set_xlabel("Output Length (tokens)", fontsize=self._config["font_size"])
        ax.set_ylabel("Tokens/sec", fontsize=self._config["font_size"])
        ax.legend()
        
        plt.tight_layout()
        self._figures.append(("throughput_scaling", fig))
        return fig

    # ═══════════════════════════════════════════════════════════════════════════
    # Memory Charts
    # ═══════════════════════════════════════════════════════════════════════════
    
    def plot_memory_bandwidth(
        self,
        results: Optional[List[Any]] = None
    ) -> Figure:
        """
        Bar chart memory bandwidth.
        
        Args:
            results: Список BenchmarkResult
        
        Returns:
            matplotlib Figure
        """
        if results is None:
            results = self._get_results_by_name("memory")
        
        if not results:
            raise ValueError("Нет данных memory")
        
        fig, ax = self._create_figure("Memory Bandwidth")
        
        labels = []
        values = []
        
        for r in results:
            bw = r.metrics.get("bandwidth_gbps", 0)
            size = r.parameters.get("transfer_size", 0)
            label = f"{size // 1024} KB" if size >= 1024 else f"{size} B"
            labels.append(label)
            values.append(bw)
        
        bars = ax.bar(labels, values, color=COLORS["memory"],
                     edgecolor="white", linewidth=1)
        
        # Значения над барами
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                   f"{val:.1f}", ha="center", va="bottom", fontsize=10)
        
        ax.set_xlabel("Transfer Size", fontsize=self._config["font_size"])
        ax.set_ylabel("Bandwidth (GB/s)", fontsize=self._config["font_size"])
        
        # Добавить линию теоретического максимума
        ax.axhline(y=50, color=COLORS["error"], linestyle="--",
                  alpha=0.5, label="Theoretical max (50 GB/s)")
        ax.legend()
        
        plt.tight_layout()
        self._figures.append(("memory_bandwidth", fig))
        return fig

    # ═══════════════════════════════════════════════════════════════════════════
    # Dashboard
    # ═══════════════════════════════════════════════════════════════════════════
    
    def plot_summary_dashboard(self) -> Figure:
        """
        Summary dashboard со всеми ключевыми метриками.
        
        Returns:
            matplotlib Figure
        """
        if not self._suite:
            raise ValueError("Suite не задан")
        
        fig = plt.figure(figsize=(14, 10), dpi=self._config["dpi"])
        fig.suptitle(
            f"VIBEE BitNet Benchmark Summary\n{self._suite.model_path}",
            fontsize=16, fontweight="bold"
        )
        
        # 2x2 grid
        gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
        
        # 1. Latency histogram
        ax1 = fig.add_subplot(gs[0, 0])
        latency_results = self._get_results_by_name("latency")
        if latency_results and latency_results[0].raw_data:
            data = latency_results[0].raw_data
            ax1.hist(data, bins=20, color=COLORS["latency"], alpha=0.7, edgecolor="white")
            ax1.axvline(np.mean(data), color=COLORS["error"], linestyle="--", label=f"Mean: {np.mean(data):.2f}")
            ax1.set_title("Latency Distribution", fontweight="bold")
            ax1.set_xlabel("Latency (ms)")
            ax1.set_ylabel("Frequency")
            ax1.legend(fontsize=8)
        else:
            ax1.text(0.5, 0.5, "No latency data", ha="center", va="center")
            ax1.set_title("Latency Distribution", fontweight="bold")
        
        # 2. Latency percentiles
        ax2 = fig.add_subplot(gs[0, 1])
        if latency_results:
            metrics = latency_results[0].metrics
            percs = ["p50", "p95", "p99"]
            vals = [metrics.get(p, 0) for p in percs]
            colors = [COLORS["p50"], COLORS["p95"], COLORS["p99"]]
            ax2.bar(percs, vals, color=colors, edgecolor="white")
            ax2.set_title("Latency Percentiles", fontweight="bold")
            ax2.set_ylabel("Latency (ms)")
        else:
            ax2.text(0.5, 0.5, "No latency data", ha="center", va="center")
            ax2.set_title("Latency Percentiles", fontweight="bold")
        
        # 3. Throughput
        ax3 = fig.add_subplot(gs[1, 0])
        throughput_results = self._get_results_by_name("throughput")
        if throughput_results:
            tps_values = [r.metrics.get("tokens_per_second", 0) for r in throughput_results]
            labels = [f"Config {i+1}" for i in range(len(tps_values))]
            ax3.bar(labels, tps_values, color=COLORS["throughput"], edgecolor="white")
            ax3.set_title("Throughput", fontweight="bold")
            ax3.set_ylabel("Tokens/sec")
        else:
            ax3.text(0.5, 0.5, "No throughput data", ha="center", va="center")
            ax3.set_title("Throughput", fontweight="bold")
        
        # 4. Memory bandwidth
        ax4 = fig.add_subplot(gs[1, 1])
        memory_results = self._get_results_by_name("memory")
        if memory_results:
            bw_values = [r.metrics.get("bandwidth_gbps", 0) for r in memory_results]
            labels = [f"{r.parameters.get('transfer_size', 0)//1024}KB" for r in memory_results]
            ax4.bar(labels, bw_values, color=COLORS["memory"], edgecolor="white")
            ax4.axhline(y=50, color=COLORS["error"], linestyle="--", alpha=0.5)
            ax4.set_title("Memory Bandwidth", fontweight="bold")
            ax4.set_ylabel("GB/s")
        else:
            ax4.text(0.5, 0.5, "No memory data", ha="center", va="center")
            ax4.set_title("Memory Bandwidth", fontweight="bold")
        
        plt.tight_layout(rect=[0, 0, 1, 0.95])
        self._figures.append(("summary_dashboard", fig))
        return fig

    # ═══════════════════════════════════════════════════════════════════════════
    # Сохранение
    # ═══════════════════════════════════════════════════════════════════════════
    
    def save(
        self,
        name: str,
        fig: Figure,
        output_dir: Union[str, Path],
        formats: List[str] = ["png"]
    ) -> List[str]:
        """
        Сохранить фигуру в файл.
        
        Args:
            name: Имя файла (без расширения)
            fig: matplotlib Figure
            output_dir: Директория для сохранения
            formats: Форматы (png, svg, pdf)
        
        Returns:
            Список путей к сохранённым файлам
        """
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        saved = []
        for fmt in formats:
            path = output_dir / f"{name}.{fmt}"
            fig.savefig(path, format=fmt, bbox_inches="tight", facecolor="white")
            saved.append(str(path))
        
        return saved
    
    def save_all(
        self,
        output_dir: Union[str, Path],
        formats: List[str] = ["png"]
    ) -> Dict[str, List[str]]:
        """
        Сохранить все созданные фигуры.
        
        Args:
            output_dir: Директория для сохранения
            formats: Форматы
        
        Returns:
            Dict с именами и путями
        """
        result = {}
        for name, fig in self._figures:
            paths = self.save(name, fig, output_dir, formats)
            result[name] = paths
        return result
    
    def show(self):
        """Показать все фигуры"""
        plt.show()
    
    def close_all(self):
        """Закрыть все фигуры"""
        for _, fig in self._figures:
            plt.close(fig)
        self._figures.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Удобные функции
# ═══════════════════════════════════════════════════════════════════════════════

def visualize_results(
    suite: Any,
    output_dir: Optional[Union[str, Path]] = None,
    show: bool = False
) -> BenchmarkVisualizer:
    """
    Быстрая визуализация результатов.
    
    Args:
        suite: BenchmarkSuite
        output_dir: Директория для сохранения (опционально)
        show: Показать графики
    
    Returns:
        BenchmarkVisualizer
    """
    viz = BenchmarkVisualizer(suite)
    
    # Создать все графики
    try:
        viz.plot_latency_histogram()
    except ValueError:
        pass
    
    try:
        viz.plot_latency_percentiles()
    except ValueError:
        pass
    
    try:
        viz.plot_throughput_bar()
    except ValueError:
        pass
    
    try:
        viz.plot_memory_bandwidth()
    except ValueError:
        pass
    
    try:
        viz.plot_summary_dashboard()
    except ValueError:
        pass
    
    if output_dir:
        viz.save_all(output_dir)
    
    if show:
        viz.show()
    
    return viz
