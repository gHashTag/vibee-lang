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
