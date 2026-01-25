"""
VIBEE BitNet Benchmark Report Generator

Генерация отчётов в различных форматах

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import json
import csv
from io import StringIO
from typing import List, Dict, Any, Optional
from datetime import datetime

from .runner import BenchmarkSuite, BenchmarkResult

# ═══════════════════════════════════════════════════════════════════════════════
# Report Generator
# ═══════════════════════════════════════════════════════════════════════════════

class ReportGenerator:
    """
    Генератор отчётов для результатов бенчмарков.
    
    Поддерживает форматы:
    - JSON (машиночитаемый)
    - CSV (для анализа в Excel/pandas)
    - Markdown (человекочитаемый)
    """
    
    def __init__(self, suite: BenchmarkSuite):
        """
        Args:
            suite: Результаты бенчмарков
        """
        self.suite = suite
    
    # ─────────────────────────────────────────────────────────────────────────
    # JSON
    # ─────────────────────────────────────────────────────────────────────────
    
    def to_json(self, indent: int = 2) -> str:
        """Конвертировать в JSON"""
        return self.suite.to_json()
    
    def save_json(self, path: str):
        """Сохранить в JSON файл"""
        with open(path, "w") as f:
            f.write(self.to_json())
    
    # ─────────────────────────────────────────────────────────────────────────
    # CSV
    # ─────────────────────────────────────────────────────────────────────────
    
    def to_csv(self) -> str:
        """Конвертировать в CSV"""
        output = StringIO()
        writer = csv.writer(output)
        
        # Header
        writer.writerow([
            "benchmark_name",
            "timestamp",
            "duration_seconds",
            "metric_name",
            "metric_value",
            "metric_unit",
        ])
        
        # Data
        for result in self.suite.results:
            for metric_name, metric_value in result.metrics.items():
                if isinstance(metric_value, dict):
                    for stat_name, stat_value in metric_value.items():
                        if isinstance(stat_value, (int, float)):
                            writer.writerow([
                                result.name,
                                result.timestamp,
                                result.duration_seconds,
                                f"{metric_name}_{stat_name}",
                                stat_value,
                                self._get_unit(metric_name),
                            ])
                elif isinstance(metric_value, (int, float)):
                    writer.writerow([
                        result.name,
                        result.timestamp,
                        result.duration_seconds,
                        metric_name,
                        metric_value,
                        self._get_unit(metric_name),
                    ])
        
        return output.getvalue()
    
    def save_csv(self, path: str):
        """Сохранить в CSV файл"""
        with open(path, "w") as f:
            f.write(self.to_csv())
    
    def _get_unit(self, metric_name: str) -> str:
        """Получить единицу измерения для метрики"""
        units = {
            "latency": "ms",
            "throughput": "tok/s",
            "bandwidth": "GB/s",
            "tokens_per_second": "tok/s",
            "time": "ms",
            "cycles": "cycles",
        }
        
        for key, unit in units.items():
            if key in metric_name.lower():
                return unit
        
        return ""
    
    # ─────────────────────────────────────────────────────────────────────────
    # Markdown
    # ─────────────────────────────────────────────────────────────────────────
    
    def to_markdown(self) -> str:
        """Конвертировать в Markdown"""
        lines = []
        
        # Header
        lines.append("# VIBEE BitNet Benchmark Report")
        lines.append("")
        lines.append(f"**Generated:** {self.suite.timestamp}")
        lines.append(f"**Device:** {self.suite.device}")
        lines.append(f"**Model:** {self.suite.model_path}")
        lines.append("")
        
        # System Info
        if self.suite.system_info:
            lines.append("## System Information")
            lines.append("")
            lines.append("| Property | Value |")
            lines.append("|----------|-------|")
            for key, value in self.suite.system_info.items():
                if isinstance(value, dict):
                    for k, v in value.items():
                        lines.append(f"| {key}.{k} | {v} |")
                else:
                    lines.append(f"| {key} | {value} |")
            lines.append("")
        
        # Summary Table
        lines.append("## Summary")
        lines.append("")
        lines.append("| Benchmark | Mean | P95 | Duration |")
        lines.append("|-----------|------|-----|----------|")
        
        for result in self.suite.results:
            if result.error:
                lines.append(f"| {result.name} | ERROR | - | {result.duration_seconds:.2f}s |")
            else:
                # Find main metric
                main_metric = self._get_main_metric(result)
                if main_metric:
                    mean = main_metric.get("mean", "N/A")
                    p95 = main_metric.get("p95", "N/A")
                    if isinstance(mean, float):
                        mean = f"{mean:.3f}"
                    if isinstance(p95, float):
                        p95 = f"{p95:.3f}"
                    lines.append(f"| {result.name} | {mean} | {p95} | {result.duration_seconds:.2f}s |")
                else:
                    lines.append(f"| {result.name} | - | - | {result.duration_seconds:.2f}s |")
        
        lines.append("")
        
        # Detailed Results
        lines.append("## Detailed Results")
        lines.append("")
        
        for result in self.suite.results:
            lines.append(f"### {result.name}")
            lines.append("")
            
            if result.error:
                lines.append(f"**Error:** {result.error}")
                lines.append("")
                continue
            
            # Parameters
            if result.parameters:
                lines.append("**Parameters:**")
                lines.append("")
                for key, value in result.parameters.items():
                    lines.append(f"- {key}: {value}")
                lines.append("")
            
            # Metrics
            lines.append("**Metrics:**")
            lines.append("")
            lines.append("| Metric | Min | Mean | Median | P95 | P99 | Max |")
            lines.append("|--------|-----|------|--------|-----|-----|-----|")
            
            for metric_name, metric_value in result.metrics.items():
                if isinstance(metric_value, dict) and "mean" in metric_value:
                    lines.append(
                        f"| {metric_name} | "
                        f"{self._fmt(metric_value.get('min'))} | "
                        f"{self._fmt(metric_value.get('mean'))} | "
                        f"{self._fmt(metric_value.get('median'))} | "
                        f"{self._fmt(metric_value.get('p95'))} | "
                        f"{self._fmt(metric_value.get('p99'))} | "
                        f"{self._fmt(metric_value.get('max'))} |"
                    )
            
            lines.append("")
        
        # Footer
        lines.append("---")
        lines.append("")
        lines.append("**φ² + 1/φ² = 3 | PHOENIX = 999**")
        
        return "\n".join(lines)
    
    def save_markdown(self, path: str):
        """Сохранить в Markdown файл"""
        with open(path, "w") as f:
            f.write(self.to_markdown())
    
    def _fmt(self, value) -> str:
        """Форматировать значение"""
        if value is None:
            return "-"
        if isinstance(value, float):
            return f"{value:.3f}"
        return str(value)
    
    def _get_main_metric(self, result: BenchmarkResult) -> Optional[Dict]:
        """Получить основную метрику для результата"""
        # Приоритет метрик
        priority = [
            "total_latency",
            "tokens_per_second",
            "bandwidth_gbps",
            "throughput",
            "latency",
        ]
        
        for name in priority:
            for metric_name, metric_value in result.metrics.items():
                if name in metric_name.lower() and isinstance(metric_value, dict):
                    return metric_value
        
        # Вернуть первую dict метрику
        for metric_value in result.metrics.values():
            if isinstance(metric_value, dict) and "mean" in metric_value:
                return metric_value
        
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# Comparison Report
# ═══════════════════════════════════════════════════════════════════════════════

class ComparisonReport:
    """
    Генератор отчёта сравнения с baseline.
    """
    
    def __init__(
        self,
        current: BenchmarkSuite,
        baseline: Optional[BenchmarkSuite] = None
    ):
        """
        Args:
            current: Текущие результаты
            baseline: Baseline для сравнения (опционально)
        """
        self.current = current
        self.baseline = baseline
    
    def to_markdown(self) -> str:
        """Генерировать сравнительный отчёт"""
        lines = []
        
        lines.append("# BitNet Benchmark Comparison")
        lines.append("")
        
        if not self.baseline:
            lines.append("*No baseline provided for comparison*")
            lines.append("")
            return "\n".join(lines)
        
        lines.append("| Benchmark | Current | Baseline | Change |")
        lines.append("|-----------|---------|----------|--------|")
        
        # Match benchmarks by name
        baseline_map = {r.name: r for r in self.baseline.results}
        
        for result in self.current.results:
            if result.name in baseline_map:
                baseline_result = baseline_map[result.name]
                
                current_metric = self._get_main_value(result)
                baseline_metric = self._get_main_value(baseline_result)
                
                if current_metric and baseline_metric:
                    change = ((current_metric - baseline_metric) / baseline_metric) * 100
                    change_str = f"{change:+.1f}%"
                    
                    # Color coding (in markdown)
                    if change > 5:
                        change_str = f"🟢 {change_str}"
                    elif change < -5:
                        change_str = f"🔴 {change_str}"
                    else:
                        change_str = f"🟡 {change_str}"
                    
                    lines.append(
                        f"| {result.name} | "
                        f"{current_metric:.3f} | "
                        f"{baseline_metric:.3f} | "
                        f"{change_str} |"
                    )
        
        lines.append("")
        
        return "\n".join(lines)
    
    def _get_main_value(self, result: BenchmarkResult) -> Optional[float]:
        """Получить основное значение метрики"""
        for metric_value in result.metrics.values():
            if isinstance(metric_value, dict) and "mean" in metric_value:
                return metric_value["mean"]
        return None
