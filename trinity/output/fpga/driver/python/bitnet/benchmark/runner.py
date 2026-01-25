"""
VIBEE BitNet Benchmark Runner

Основной модуль для запуска бенчмарков

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import time
import json
import statistics
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Any, Optional, Callable
from datetime import datetime
import numpy as np

from ..core import BitNet, BitNetError

# ═══════════════════════════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class BenchmarkResult:
    """Результат одного бенчмарка"""
    name: str
    timestamp: str
    duration_seconds: float
    metrics: Dict[str, Any]
    parameters: Dict[str, Any]
    raw_data: List[float] = field(default_factory=list)
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)


@dataclass
class BenchmarkSuite:
    """Набор результатов бенчмарков"""
    name: str
    version: str
    timestamp: str
    device: str
    model_path: str
    results: List[BenchmarkResult] = field(default_factory=list)
    system_info: Dict[str, Any] = field(default_factory=dict)
    
    def add_result(self, result: BenchmarkResult):
        self.results.append(result)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "timestamp": self.timestamp,
            "device": self.device,
            "model_path": self.model_path,
            "system_info": self.system_info,
            "results": [r.to_dict() for r in self.results],
        }
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Statistics Helpers
# ═══════════════════════════════════════════════════════════════════════════════

def calculate_statistics(data: List[float]) -> Dict[str, float]:
    """Вычислить статистики для списка измерений"""
    if not data:
        return {}
    
    sorted_data = sorted(data)
    n = len(sorted_data)
    
    return {
        "min": min(data),
        "max": max(data),
        "mean": statistics.mean(data),
        "median": statistics.median(data),
        "std": statistics.stdev(data) if n > 1 else 0,
        "p50": sorted_data[int(n * 0.50)],
        "p90": sorted_data[int(n * 0.90)],
        "p95": sorted_data[int(n * 0.95)],
        "p99": sorted_data[min(int(n * 0.99), n - 1)],
    }


def warmup(func: Callable, runs: int = 5):
    """Прогрев перед измерениями"""
    for _ in range(runs):
        func()


# ═══════════════════════════════════════════════════════════════════════════════
# Benchmark Runner
# ═══════════════════════════════════════════════════════════════════════════════

class BenchmarkRunner:
    """
    Основной класс для запуска бенчмарков.
    
    Example:
        >>> runner = BenchmarkRunner("/dev/bitnet0", "model.bin")
        >>> runner.run_all()
        >>> runner.save_results("results.json")
    """
    
    VERSION = "1.0.0"
    
    def __init__(
        self,
        device: str = "/dev/bitnet0",
        model_path: Optional[str] = None,
        verbose: bool = True
    ):
        """
        Args:
            device: Путь к устройству BitNet
            model_path: Путь к файлу с весами
            verbose: Выводить прогресс
        """
        self.device = device
        self.model_path = model_path
        self.verbose = verbose
        self._bn: Optional[BitNet] = None
        self._suite: Optional[BenchmarkSuite] = None
        
    def _log(self, message: str):
        """Вывод сообщения если verbose=True"""
        if self.verbose:
            print(message)
    
    def _get_system_info(self) -> Dict[str, Any]:
        """Собрать информацию о системе"""
        import platform
        
        info = {
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "processor": platform.processor(),
        }
        
        # Попробуем получить информацию о BitNet
        try:
            if self._bn:
                model_info = self._bn.model_info
                info["bitnet"] = {
                    "num_layers": model_info.num_layers,
                    "hidden_size": model_info.hidden_size,
                    "vocab_size": model_info.vocab_size,
                }
        except:
            pass
        
        return info
    
    def setup(self):
        """Инициализация BitNet контекста"""
        self._log(f"Connecting to {self.device}...")
        self._bn = BitNet(self.device)
        
        if self.model_path:
            self._log(f"Loading weights from {self.model_path}...")
            self._bn.load_weights(self.model_path)
        
        self._suite = BenchmarkSuite(
            name="BitNet Benchmark Suite",
            version=self.VERSION,
            timestamp=datetime.now().isoformat(),
            device=self.device,
            model_path=self.model_path or "",
            system_info=self._get_system_info()
        )
        
        self._log("Setup complete\n")
    
    def teardown(self):
        """Освобождение ресурсов"""
        if self._bn:
            self._bn.close()
            self._bn = None
    
    def __enter__(self):
        self.setup()
        return self
    
    def __exit__(self, *args):
        self.teardown()
    
    def run_benchmark(
        self,
        name: str,
        func: Callable[[], float],
        warmup_runs: int = 5,
        measurement_runs: int = 100,
        parameters: Optional[Dict[str, Any]] = None
    ) -> BenchmarkResult:
        """
        Запустить один бенчмарк.
        
        Args:
            name: Название бенчмарка
            func: Функция, возвращающая измеренное значение
            warmup_runs: Количество прогревочных запусков
            measurement_runs: Количество измерений
            parameters: Параметры бенчмарка
        
        Returns:
            BenchmarkResult с результатами
        """
        self._log(f"Running: {name}")
        self._log(f"  Warmup: {warmup_runs} runs")
        
        start_time = time.time()
        
        try:
            # Warmup
            for _ in range(warmup_runs):
                func()
            
            # Measurements
            self._log(f"  Measuring: {measurement_runs} runs")
            measurements = []
            
            for i in range(measurement_runs):
                value = func()
                measurements.append(value)
                
                if self.verbose and (i + 1) % 10 == 0:
                    print(f"    Progress: {i + 1}/{measurement_runs}", end="\r")
            
            if self.verbose:
                print()  # New line after progress
            
            # Calculate statistics
            stats = calculate_statistics(measurements)
            
            duration = time.time() - start_time
            
            result = BenchmarkResult(
                name=name,
                timestamp=datetime.now().isoformat(),
                duration_seconds=duration,
                metrics=stats,
                parameters=parameters or {},
                raw_data=measurements
            )
            
            self._log(f"  Mean: {stats['mean']:.3f}, P95: {stats['p95']:.3f}")
            self._log(f"  Duration: {duration:.2f}s\n")
            
        except Exception as e:
            result = BenchmarkResult(
                name=name,
                timestamp=datetime.now().isoformat(),
                duration_seconds=time.time() - start_time,
                metrics={},
                parameters=parameters or {},
                error=str(e)
            )
            self._log(f"  ERROR: {e}\n")
        
        if self._suite:
            self._suite.add_result(result)
        
        return result
    
    def run_latency_sweep(
        self,
        input_lengths: List[int] = [16, 32, 64, 128, 256, 512],
        warmup_runs: int = 5,
        measurement_runs: int = 100
    ) -> List[BenchmarkResult]:
        """Измерение latency при разных длинах входа"""
        from .latency import LatencyBenchmark
        
        bench = LatencyBenchmark(self._bn)
        results = []
        
        for length in input_lengths:
            result = bench.run(
                input_length=length,
                warmup_runs=warmup_runs,
                measurement_runs=measurement_runs
            )
            results.append(result)
            if self._suite:
                self._suite.add_result(result)
        
        return results
    
    def run_throughput_test(
        self,
        input_length: int = 128,
        output_lengths: List[int] = [16, 32, 64, 128],
        warmup_runs: int = 5,
        measurement_runs: int = 50
    ) -> List[BenchmarkResult]:
        """Измерение throughput"""
        from .throughput import ThroughputBenchmark
        
        bench = ThroughputBenchmark(self._bn)
        results = []
        
        for output_length in output_lengths:
            result = bench.run(
                input_length=input_length,
                output_length=output_length,
                warmup_runs=warmup_runs,
                measurement_runs=measurement_runs
            )
            results.append(result)
            if self._suite:
                self._suite.add_result(result)
        
        return results
    
    def run_memory_benchmark(
        self,
        transfer_sizes: List[int] = [4096, 16384, 65536, 262144],
        iterations: int = 100
    ) -> List[BenchmarkResult]:
        """Измерение memory bandwidth"""
        from .memory import MemoryBenchmark
        
        bench = MemoryBenchmark(self._bn)
        results = []
        
        for size in transfer_sizes:
            result = bench.run(
                transfer_size=size,
                iterations=iterations
            )
            results.append(result)
            if self._suite:
                self._suite.add_result(result)
        
        return results
    
    def run_all(self) -> BenchmarkSuite:
        """Запустить все бенчмарки"""
        self._log("=" * 60)
        self._log("VIBEE BitNet Benchmark Suite")
        self._log("=" * 60 + "\n")
        
        self.run_latency_sweep()
        self.run_throughput_test()
        self.run_memory_benchmark()
        
        self._log("=" * 60)
        self._log("All benchmarks complete!")
        self._log("=" * 60)
        
        return self._suite
    
    def save_results(self, path: str, format: str = "json"):
        """
        Сохранить результаты в файл.
        
        Args:
            path: Путь к файлу
            format: Формат (json, csv, markdown)
        """
        from .report import ReportGenerator
        
        if not self._suite:
            raise ValueError("No results to save. Run benchmarks first.")
        
        generator = ReportGenerator(self._suite)
        
        if format == "json":
            generator.save_json(path)
        elif format == "csv":
            generator.save_csv(path)
        elif format == "markdown":
            generator.save_markdown(path)
        else:
            raise ValueError(f"Unknown format: {format}")
        
        self._log(f"Results saved to {path}")
    
    @property
    def results(self) -> Optional[BenchmarkSuite]:
        """Получить результаты"""
        return self._suite
