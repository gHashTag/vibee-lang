"""
VIBEE BitNet Benchmark Comparison

Модуль сравнения результатов бенчмарков для обнаружения регрессий.

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import json
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Any, Optional, Union
from pathlib import Path
from enum import Enum
from datetime import datetime


# ═══════════════════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════════════════

class ComparisonStatus(Enum):
    """Статус сравнения метрики"""
    IMPROVED = "improved"       # Улучшение
    REGRESSION = "regression"   # Регрессия
    UNCHANGED = "unchanged"     # Без изменений
    NEW = "new"                 # Новая метрика
    REMOVED = "removed"         # Удалённая метрика


# ═══════════════════════════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class ThresholdConfig:
    """Пороги для определения регрессий (в процентах)"""
    latency_mean: float = 5.0
    latency_p95: float = 10.0
    latency_p99: float = 15.0
    throughput: float = 5.0
    memory_bandwidth: float = 10.0
    default: float = 5.0
    
    def get_threshold(self, metric_name: str) -> float:
        """Получить порог для метрики"""
        mapping = {
            "mean": self.latency_mean,
            "p95": self.latency_p95,
            "p99": self.latency_p99,
            "tokens_per_second": self.throughput,
            "bandwidth_gbps": self.memory_bandwidth,
        }
        return mapping.get(metric_name, self.default)


@dataclass
class ComparisonResult:
    """Результат сравнения одной метрики"""
    metric_name: str
    baseline_value: float
    current_value: float
    absolute_diff: float
    percent_diff: float
    status: ComparisonStatus
    threshold: float = 5.0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "metric_name": self.metric_name,
            "baseline_value": self.baseline_value,
            "current_value": self.current_value,
            "absolute_diff": self.absolute_diff,
            "percent_diff": self.percent_diff,
            "status": self.status.value,
            "threshold": self.threshold,
        }


@dataclass
class BenchmarkComparison:
    """Сравнение двух benchmark результатов"""
    benchmark_name: str
    comparisons: List[ComparisonResult] = field(default_factory=list)
    
    @property
    def has_regression(self) -> bool:
        return any(c.status == ComparisonStatus.REGRESSION for c in self.comparisons)
    
    @property
    def has_improvement(self) -> bool:
        return any(c.status == ComparisonStatus.IMPROVED for c in self.comparisons)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "benchmark_name": self.benchmark_name,
            "comparisons": [c.to_dict() for c in self.comparisons],
            "has_regression": self.has_regression,
            "has_improvement": self.has_improvement,
        }


@dataclass
class RegressionReport:
    """Полный отчёт о регрессиях"""
    baseline_timestamp: str
    current_timestamp: str
    baseline_model: str
    current_model: str
    benchmark_comparisons: List[BenchmarkComparison] = field(default_factory=list)
    
    @property
    def total_metrics(self) -> int:
        return sum(len(bc.comparisons) for bc in self.benchmark_comparisons)
    
    @property
    def improved_count(self) -> int:
        return sum(
            1 for bc in self.benchmark_comparisons
            for c in bc.comparisons
            if c.status == ComparisonStatus.IMPROVED
        )
    
    @property
    def regression_count(self) -> int:
        return sum(
            1 for bc in self.benchmark_comparisons
            for c in bc.comparisons
            if c.status == ComparisonStatus.REGRESSION
        )
    
    @property
    def unchanged_count(self) -> int:
        return sum(
            1 for bc in self.benchmark_comparisons
            for c in bc.comparisons
            if c.status == ComparisonStatus.UNCHANGED
        )
    
    @property
    def has_regressions(self) -> bool:
        return self.regression_count > 0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "baseline_timestamp": self.baseline_timestamp,
            "current_timestamp": self.current_timestamp,
            "baseline_model": self.baseline_model,
            "current_model": self.current_model,
            "total_metrics": self.total_metrics,
            "improved_count": self.improved_count,
            "regression_count": self.regression_count,
            "unchanged_count": self.unchanged_count,
            "has_regressions": self.has_regressions,
            "benchmark_comparisons": [bc.to_dict() for bc in self.benchmark_comparisons],
        }
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Comparison Functions
# ═══════════════════════════════════════════════════════════════════════════════

def compare_metric(
    metric_name: str,
    baseline_value: float,
    current_value: float,
    threshold: float = 5.0,
    higher_is_better: bool = False
) -> ComparisonResult:
    """
    Сравнить две метрики.
    
    Args:
        metric_name: Имя метрики
        baseline_value: Базовое значение
        current_value: Текущее значение
        threshold: Порог для определения регрессии (%)
        higher_is_better: True для throughput, False для latency
    
    Returns:
        ComparisonResult
    """
    if baseline_value == 0:
        percent_diff = 100.0 if current_value > 0 else 0.0
    else:
        percent_diff = ((current_value - baseline_value) / baseline_value) * 100
    
    absolute_diff = current_value - baseline_value
    
    # Определить статус
    if higher_is_better:
        # Для throughput: больше = лучше
        if percent_diff > threshold:
            status = ComparisonStatus.IMPROVED
        elif percent_diff < -threshold:
            status = ComparisonStatus.REGRESSION
        else:
            status = ComparisonStatus.UNCHANGED
    else:
        # Для latency: меньше = лучше
        if percent_diff < -threshold:
            status = ComparisonStatus.IMPROVED
        elif percent_diff > threshold:
            status = ComparisonStatus.REGRESSION
        else:
            status = ComparisonStatus.UNCHANGED
    
    return ComparisonResult(
        metric_name=metric_name,
        baseline_value=baseline_value,
        current_value=current_value,
        absolute_diff=absolute_diff,
        percent_diff=percent_diff,
        status=status,
        threshold=threshold,
    )


def is_higher_better(metric_name: str) -> bool:
    """Определить, является ли большее значение лучшим"""
    higher_better_metrics = {
        "tokens_per_second",
        "throughput",
        "bandwidth_gbps",
        "total_tokens",
    }
    return metric_name in higher_better_metrics


# ═══════════════════════════════════════════════════════════════════════════════
# BenchmarkComparator Class
# ═══════════════════════════════════════════════════════════════════════════════

class BenchmarkComparator:
    """
    Сравнение результатов бенчмарков.
    
    Пример:
        >>> comparator = BenchmarkComparator()
        >>> comparator.load_baseline("baseline.json")
        >>> comparator.load_current("current.json")
        >>> report = comparator.compare()
        >>> print(report.to_markdown())
    """
    
    def __init__(self, thresholds: Optional[ThresholdConfig] = None):
        """
        Args:
            thresholds: Конфигурация порогов
        """
        self._thresholds = thresholds or ThresholdConfig()
        self._baseline: Optional[Dict[str, Any]] = None
        self._current: Optional[Dict[str, Any]] = None
    
    def load_baseline(self, path: Union[str, Path]) -> None:
        """Загрузить baseline результаты из JSON"""
        with open(path, 'r') as f:
            self._baseline = json.load(f)
    
    def load_current(self, path: Union[str, Path]) -> None:
        """Загрузить текущие результаты из JSON"""
        with open(path, 'r') as f:
            self._current = json.load(f)
    
    def set_baseline(self, data: Dict[str, Any]) -> None:
        """Установить baseline из dict"""
        self._baseline = data
    
    def set_current(self, data: Dict[str, Any]) -> None:
        """Установить current из dict"""
        self._current = data
    
    def compare(self) -> RegressionReport:
        """
        Сравнить baseline и current результаты.
        
        Returns:
            RegressionReport
        """
        if not self._baseline or not self._current:
            raise ValueError("Baseline и current должны быть загружены")
        
        report = RegressionReport(
            baseline_timestamp=self._baseline.get("timestamp", "unknown"),
            current_timestamp=self._current.get("timestamp", "unknown"),
            baseline_model=self._baseline.get("model_path", "unknown"),
            current_model=self._current.get("model_path", "unknown"),
        )
        
        # Создать индекс baseline результатов по имени
        baseline_results = {
            r["name"]: r for r in self._baseline.get("results", [])
        }
        
        # Сравнить каждый текущий результат
        for current_result in self._current.get("results", []):
            name = current_result["name"]
            baseline_result = baseline_results.get(name)
            
            if baseline_result:
                comparison = self._compare_results(baseline_result, current_result)
                report.benchmark_comparisons.append(comparison)
        
        return report
    
    def _compare_results(
        self,
        baseline: Dict[str, Any],
        current: Dict[str, Any]
    ) -> BenchmarkComparison:
        """Сравнить два benchmark результата"""
        comparison = BenchmarkComparison(benchmark_name=baseline["name"])
        
        baseline_metrics = baseline.get("metrics", {})
        current_metrics = current.get("metrics", {})
        
        # Сравнить все метрики
        all_metrics = set(baseline_metrics.keys()) | set(current_metrics.keys())
        
        for metric_name in all_metrics:
            baseline_value = baseline_metrics.get(metric_name)
            current_value = current_metrics.get(metric_name)
            
            # Пропустить не-числовые метрики
            if not isinstance(baseline_value, (int, float)) or \
               not isinstance(current_value, (int, float)):
                continue
            
            threshold = self._thresholds.get_threshold(metric_name)
            higher_better = is_higher_better(metric_name)
            
            result = compare_metric(
                metric_name=metric_name,
                baseline_value=float(baseline_value),
                current_value=float(current_value),
                threshold=threshold,
                higher_is_better=higher_better,
            )
            
            comparison.comparisons.append(result)
        
        return comparison
    
    def save_baseline(self, data: Dict[str, Any], path: Union[str, Path]) -> None:
        """Сохранить результаты как новый baseline"""
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Report Generators
# ═══════════════════════════════════════════════════════════════════════════════

def generate_text_report(report: RegressionReport) -> str:
    """Генерация текстового отчёта"""
    lines = []
    
    lines.append("=" * 70)
    lines.append("VIBEE BitNet Benchmark Comparison Report")
    lines.append("=" * 70)
    lines.append("")
    lines.append(f"Baseline: {report.baseline_timestamp} ({report.baseline_model})")
    lines.append(f"Current:  {report.current_timestamp} ({report.current_model})")
    lines.append("")
    lines.append(f"Total metrics:  {report.total_metrics}")
    lines.append(f"Improved:       {report.improved_count} ✅")
    lines.append(f"Regressions:    {report.regression_count} ❌")
    lines.append(f"Unchanged:      {report.unchanged_count}")
    lines.append("")
    
    for bc in report.benchmark_comparisons:
        lines.append("-" * 70)
        lines.append(f"Benchmark: {bc.benchmark_name}")
        lines.append("-" * 70)
        
        for c in bc.comparisons:
            status_icon = {
                ComparisonStatus.IMPROVED: "✅",
                ComparisonStatus.REGRESSION: "❌",
                ComparisonStatus.UNCHANGED: "➖",
                ComparisonStatus.NEW: "🆕",
                ComparisonStatus.REMOVED: "🗑️",
            }.get(c.status, "?")
            
            sign = "+" if c.percent_diff > 0 else ""
            lines.append(
                f"  {status_icon} {c.metric_name}: "
                f"{c.baseline_value:.3f} → {c.current_value:.3f} "
                f"({sign}{c.percent_diff:.1f}%)"
            )
        
        lines.append("")
    
    lines.append("=" * 70)
    
    if report.has_regressions:
        lines.append("⚠️  REGRESSIONS DETECTED!")
    else:
        lines.append("✅ No regressions detected")
    
    lines.append("=" * 70)
    
    return "\n".join(lines)


def generate_markdown_report(report: RegressionReport) -> str:
    """Генерация Markdown отчёта для GitHub"""
    lines = []
    
    lines.append("# Benchmark Comparison Report")
    lines.append("")
    lines.append(f"**Baseline:** {report.baseline_timestamp}")
    lines.append(f"**Current:** {report.current_timestamp}")
    lines.append("")
    
    # Summary
    lines.append("## Summary")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("|--------|-------|")
    lines.append(f"| Total | {report.total_metrics} |")
    lines.append(f"| Improved | {report.improved_count} |")
    lines.append(f"| Regressions | {report.regression_count} |")
    lines.append(f"| Unchanged | {report.unchanged_count} |")
    lines.append("")
    
    # Status badge
    if report.has_regressions:
        lines.append("**Status:** ❌ Regressions detected")
    else:
        lines.append("**Status:** ✅ No regressions")
    lines.append("")
    
    # Details
    lines.append("## Details")
    lines.append("")
    
    for bc in report.benchmark_comparisons:
        lines.append(f"### {bc.benchmark_name.title()}")
        lines.append("")
        lines.append("| Metric | Baseline | Current | Diff | Status |")
        lines.append("|--------|----------|---------|------|--------|")
        
        for c in bc.comparisons:
            status_icon = {
                ComparisonStatus.IMPROVED: "✅",
                ComparisonStatus.REGRESSION: "❌",
                ComparisonStatus.UNCHANGED: "➖",
            }.get(c.status, "?")
            
            sign = "+" if c.percent_diff > 0 else ""
            lines.append(
                f"| {c.metric_name} | {c.baseline_value:.3f} | "
                f"{c.current_value:.3f} | {sign}{c.percent_diff:.1f}% | {status_icon} |"
            )
        
        lines.append("")
    
    return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════════════
# CLI Integration
# ═══════════════════════════════════════════════════════════════════════════════

def compare_files(
    baseline_path: Union[str, Path],
    current_path: Union[str, Path],
    output_format: str = "text",
    fail_on_regression: bool = False
) -> int:
    """
    Сравнить два файла с результатами.
    
    Args:
        baseline_path: Путь к baseline JSON
        current_path: Путь к current JSON
        output_format: Формат вывода (text, markdown, json)
        fail_on_regression: Вернуть exit code 1 при регрессиях
    
    Returns:
        Exit code (0 = success, 1 = regressions)
    """
    comparator = BenchmarkComparator()
    comparator.load_baseline(baseline_path)
    comparator.load_current(current_path)
    
    report = comparator.compare()
    
    if output_format == "json":
        print(report.to_json())
    elif output_format == "markdown":
        print(generate_markdown_report(report))
    else:
        print(generate_text_report(report))
    
    if fail_on_regression and report.has_regressions:
        return 1
    
    return 0


# ═══════════════════════════════════════════════════════════════════════════════
# Visualization
# ═══════════════════════════════════════════════════════════════════════════════

# Цвета для визуализации
COMPARISON_COLORS = {
    "improved": "#10B981",
    "regression": "#EF4444",
    "unchanged": "#6B7280",
    "baseline": "#3B82F6",
    "current": "#8B5CF6",
}


class ComparisonVisualizer:
    """
    Визуализация результатов сравнения бенчмарков.
    
    Пример:
        >>> viz = ComparisonVisualizer(report)
        >>> viz.plot_diff_chart()
        >>> viz.plot_comparison_bars()
        >>> viz.save_all("plots/")
    """
    
    def __init__(self, report: RegressionReport, config: dict = None):
        """
        Args:
            report: RegressionReport для визуализации
            config: Конфигурация (figsize, dpi, etc.)
        """
        self._report = report
        self._config = config or {
            "figsize": (10, 6),
            "dpi": 150,
            "font_size": 12,
        }
        self._figures = []
        
        # Проверка matplotlib
        try:
            import matplotlib.pyplot as plt
            self._plt = plt
        except ImportError:
            raise ImportError("matplotlib не установлен. pip install matplotlib")
    
    def plot_diff_chart(self) -> "Figure":
        """
        Горизонтальный bar chart с процентными изменениями.
        
        Зелёный = улучшение, красный = регрессия, серый = без изменений.
        
        Returns:
            matplotlib Figure
        """
        fig, ax = self._plt.subplots(figsize=self._config["figsize"], dpi=self._config["dpi"])
        
        # Собрать все метрики
        metrics = []
        values = []
        colors = []
        
        for bc in self._report.benchmark_comparisons:
            for c in bc.comparisons:
                label = f"{bc.benchmark_name}.{c.metric_name}"
                metrics.append(label)
                values.append(c.percent_diff)
                
                if c.status == ComparisonStatus.IMPROVED:
                    colors.append(COMPARISON_COLORS["improved"])
                elif c.status == ComparisonStatus.REGRESSION:
                    colors.append(COMPARISON_COLORS["regression"])
                else:
                    colors.append(COMPARISON_COLORS["unchanged"])
        
        # Горизонтальный bar chart
        y_pos = range(len(metrics))
        bars = ax.barh(y_pos, values, color=colors, edgecolor="white", linewidth=0.5)
        
        ax.set_yticks(y_pos)
        ax.set_yticklabels(metrics, fontsize=self._config["font_size"] - 2)
        ax.set_xlabel("Change (%)", fontsize=self._config["font_size"])
        ax.set_title(
            f"Benchmark Comparison: {self._report.baseline_model} → {self._report.current_model}",
            fontsize=self._config["font_size"] + 2,
            fontweight="bold"
        )
        
        # Вертикальная линия на 0
        ax.axvline(x=0, color="black", linewidth=0.8)
        
        # Добавить значения на барах
        for bar, val in zip(bars, values):
            x_pos = bar.get_width()
            sign = "+" if val > 0 else ""
            ax.text(
                x_pos + (1 if val >= 0 else -1),
                bar.get_y() + bar.get_height() / 2,
                f"{sign}{val:.1f}%",
                va="center",
                ha="left" if val >= 0 else "right",
                fontsize=9
            )
        
        # Легенда
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor=COMPARISON_COLORS["improved"], label="Improved"),
            Patch(facecolor=COMPARISON_COLORS["regression"], label="Regression"),
            Patch(facecolor=COMPARISON_COLORS["unchanged"], label="Unchanged"),
        ]
        ax.legend(handles=legend_elements, loc="lower right")
        
        self._plt.tight_layout()
        self._figures.append(("diff_chart", fig))
        return fig
    
    def plot_comparison_bars(self) -> "Figure":
        """
        Grouped bar chart: baseline vs current для каждой метрики.
        
        Returns:
            matplotlib Figure
        """
        import numpy as np
        
        fig, ax = self._plt.subplots(figsize=self._config["figsize"], dpi=self._config["dpi"])
        
        # Собрать данные
        metrics = []
        baseline_values = []
        current_values = []
        
        for bc in self._report.benchmark_comparisons:
            for c in bc.comparisons:
                label = f"{bc.benchmark_name}\n{c.metric_name}"
                metrics.append(label)
                baseline_values.append(c.baseline_value)
                current_values.append(c.current_value)
        
        x = np.arange(len(metrics))
        width = 0.35
        
        bars1 = ax.bar(x - width/2, baseline_values, width, 
                       label="Baseline", color=COMPARISON_COLORS["baseline"],
                       edgecolor="white", linewidth=0.5)
        bars2 = ax.bar(x + width/2, current_values, width,
                       label="Current", color=COMPARISON_COLORS["current"],
                       edgecolor="white", linewidth=0.5)
        
        ax.set_ylabel("Value", fontsize=self._config["font_size"])
        ax.set_title("Baseline vs Current", fontsize=self._config["font_size"] + 2, fontweight="bold")
        ax.set_xticks(x)
        ax.set_xticklabels(metrics, fontsize=self._config["font_size"] - 2)
        ax.legend()
        
        self._plt.tight_layout()
        self._figures.append(("comparison_bars", fig))
        return fig
    
    def plot_status_summary(self) -> "Figure":
        """
        Pie chart со статусами: improved, regression, unchanged.
        
        Returns:
            matplotlib Figure
        """
        fig, ax = self._plt.subplots(figsize=(8, 8), dpi=self._config["dpi"])
        
        sizes = [
            self._report.improved_count,
            self._report.regression_count,
            self._report.unchanged_count,
        ]
        labels = ["Improved", "Regression", "Unchanged"]
        colors = [
            COMPARISON_COLORS["improved"],
            COMPARISON_COLORS["regression"],
            COMPARISON_COLORS["unchanged"],
        ]
        
        # Убрать нулевые значения
        non_zero = [(s, l, c) for s, l, c in zip(sizes, labels, colors) if s > 0]
        if non_zero:
            sizes, labels, colors = zip(*non_zero)
        
        wedges, texts, autotexts = ax.pie(
            sizes, labels=labels, colors=colors,
            autopct=lambda pct: f"{pct:.1f}%\n({int(pct/100*sum(sizes))})",
            startangle=90,
            explode=[0.05] * len(sizes)
        )
        
        ax.set_title(
            f"Comparison Summary\n{self._report.total_metrics} metrics",
            fontsize=self._config["font_size"] + 2,
            fontweight="bold"
        )
        
        self._figures.append(("status_summary", fig))
        return fig
    
    def plot_comparison_dashboard(self) -> "Figure":
        """
        Dashboard со всеми графиками сравнения.
        
        Returns:
            matplotlib Figure
        """
        fig = self._plt.figure(figsize=(14, 10), dpi=self._config["dpi"])
        fig.suptitle(
            f"Benchmark Comparison Dashboard\n{self._report.baseline_model} → {self._report.current_model}",
            fontsize=14,
            fontweight="bold"
        )
        
        gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
        
        # 1. Diff chart (top-left)
        ax1 = fig.add_subplot(gs[0, 0])
        self._plot_diff_on_ax(ax1)
        
        # 2. Status summary (top-right)
        ax2 = fig.add_subplot(gs[0, 1])
        self._plot_status_on_ax(ax2)
        
        # 3. Comparison bars (bottom, full width)
        ax3 = fig.add_subplot(gs[1, :])
        self._plot_bars_on_ax(ax3)
        
        self._plt.tight_layout(rect=[0, 0, 1, 0.95])
        self._figures.append(("comparison_dashboard", fig))
        return fig
    
    def _plot_diff_on_ax(self, ax):
        """Diff chart на заданном axes"""
        metrics = []
        values = []
        colors = []
        
        for bc in self._report.benchmark_comparisons:
            for c in bc.comparisons:
                metrics.append(f"{bc.benchmark_name}.{c.metric_name}")
                values.append(c.percent_diff)
                if c.status == ComparisonStatus.IMPROVED:
                    colors.append(COMPARISON_COLORS["improved"])
                elif c.status == ComparisonStatus.REGRESSION:
                    colors.append(COMPARISON_COLORS["regression"])
                else:
                    colors.append(COMPARISON_COLORS["unchanged"])
        
        y_pos = range(len(metrics))
        ax.barh(y_pos, values, color=colors, edgecolor="white")
        ax.set_yticks(y_pos)
        ax.set_yticklabels(metrics, fontsize=9)
        ax.axvline(x=0, color="black", linewidth=0.8)
        ax.set_xlabel("Change (%)")
        ax.set_title("Metric Changes", fontweight="bold")
    
    def _plot_status_on_ax(self, ax):
        """Status pie на заданном axes"""
        sizes = [
            self._report.improved_count,
            self._report.regression_count,
            self._report.unchanged_count,
        ]
        labels = ["Improved", "Regression", "Unchanged"]
        colors = [
            COMPARISON_COLORS["improved"],
            COMPARISON_COLORS["regression"],
            COMPARISON_COLORS["unchanged"],
        ]
        
        non_zero = [(s, l, c) for s, l, c in zip(sizes, labels, colors) if s > 0]
        if non_zero:
            sizes, labels, colors = zip(*non_zero)
            ax.pie(sizes, labels=labels, colors=colors, autopct="%1.0f%%", startangle=90)
        ax.set_title("Status Summary", fontweight="bold")
    
    def _plot_bars_on_ax(self, ax):
        """Comparison bars на заданном axes"""
        import numpy as np
        
        metrics = []
        baseline_values = []
        current_values = []
        
        for bc in self._report.benchmark_comparisons:
            for c in bc.comparisons:
                metrics.append(f"{bc.benchmark_name}.{c.metric_name}")
                baseline_values.append(c.baseline_value)
                current_values.append(c.current_value)
        
        x = np.arange(len(metrics))
        width = 0.35
        
        ax.bar(x - width/2, baseline_values, width, label="Baseline",
               color=COMPARISON_COLORS["baseline"], edgecolor="white")
        ax.bar(x + width/2, current_values, width, label="Current",
               color=COMPARISON_COLORS["current"], edgecolor="white")
        
        ax.set_xticks(x)
        ax.set_xticklabels(metrics, rotation=45, ha="right", fontsize=9)
        ax.set_ylabel("Value")
        ax.set_title("Baseline vs Current", fontweight="bold")
        ax.legend()
    
    def save(self, name: str, fig, output_dir: Union[str, Path], formats: list = None) -> list:
        """Сохранить фигуру"""
        formats = formats or ["png"]
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        saved = []
        for fmt in formats:
            path = output_dir / f"{name}.{fmt}"
            fig.savefig(path, format=fmt, bbox_inches="tight", facecolor="white")
            saved.append(str(path))
        
        return saved
    
    def save_all(self, output_dir: Union[str, Path], formats: list = None) -> dict:
        """Сохранить все фигуры"""
        result = {}
        for name, fig in self._figures:
            paths = self.save(name, fig, output_dir, formats)
            result[name] = paths
        return result
    
    def close_all(self):
        """Закрыть все фигуры"""
        for _, fig in self._figures:
            self._plt.close(fig)
        self._figures.clear()


def visualize_comparison(
    report: RegressionReport,
    output_dir: Union[str, Path] = None,
    show: bool = False
) -> ComparisonVisualizer:
    """
    Быстрая визуализация сравнения.
    
    Args:
        report: RegressionReport
        output_dir: Директория для сохранения
        show: Показать графики
    
    Returns:
        ComparisonVisualizer
    """
    viz = ComparisonVisualizer(report)
    
    viz.plot_diff_chart()
    viz.plot_comparison_bars()
    viz.plot_status_summary()
    viz.plot_comparison_dashboard()
    
    if output_dir:
        viz.save_all(output_dir)
    
    if show:
        viz._plt.show()
    
    return viz
