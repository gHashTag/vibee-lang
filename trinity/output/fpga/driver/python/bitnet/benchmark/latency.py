"""
VIBEE BitNet Latency Benchmarks

Измерение latency inference

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import time
from typing import List, Dict, Any, Optional
from datetime import datetime
import numpy as np

from ..core import BitNet
from .runner import BenchmarkResult, calculate_statistics

# ═══════════════════════════════════════════════════════════════════════════════
# Latency Benchmark
# ═══════════════════════════════════════════════════════════════════════════════

class LatencyBenchmark:
    """
    Бенчмарк для измерения latency.
    
    Измеряет:
    - First token latency (время до первого токена)
    - Total latency (общее время inference)
    - Per-token latency (среднее время на токен)
    """
    
    def __init__(self, bitnet: BitNet):
        """
        Args:
            bitnet: Инициализированный BitNet контекст
        """
        self._bn = bitnet
    
    def measure_single(
        self,
        input_length: int,
        output_length: int = 1
    ) -> Dict[str, float]:
        """
        Одно измерение latency.
        
        Args:
            input_length: Длина входной последовательности
            output_length: Ожидаемая длина выхода
        
        Returns:
            Dict с метриками latency
        """
        # Генерируем случайные токены
        input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
        
        # Измеряем время
        start = time.perf_counter()
        output = self._bn.inference(input_tokens, max_output=output_length)
        end = time.perf_counter()
        
        total_latency_ms = (end - start) * 1000
        num_output_tokens = len(output)
        
        return {
            "total_latency_ms": total_latency_ms,
            "num_output_tokens": num_output_tokens,
            "per_token_latency_ms": total_latency_ms / max(num_output_tokens, 1),
            "input_length": input_length,
        }
    
    def run(
        self,
        input_length: int = 128,
        output_length: int = 1,
        warmup_runs: int = 5,
        measurement_runs: int = 100
    ) -> BenchmarkResult:
        """
        Запустить бенчмарк latency.
        
        Args:
            input_length: Длина входной последовательности
            output_length: Ожидаемая длина выхода
            warmup_runs: Количество прогревочных запусков
            measurement_runs: Количество измерений
        
        Returns:
            BenchmarkResult с результатами
        """
        start_time = time.time()
        
        # Warmup
        for _ in range(warmup_runs):
            self.measure_single(input_length, output_length)
        
        # Measurements
        latencies = []
        per_token_latencies = []
        
        for _ in range(measurement_runs):
            result = self.measure_single(input_length, output_length)
            latencies.append(result["total_latency_ms"])
            per_token_latencies.append(result["per_token_latency_ms"])
        
        # Calculate statistics
        latency_stats = calculate_statistics(latencies)
        per_token_stats = calculate_statistics(per_token_latencies)
        
        metrics = {
            "total_latency": latency_stats,
            "per_token_latency": per_token_stats,
            "first_token_latency_ms": latency_stats["mean"],  # Approximation
        }
        
        return BenchmarkResult(
            name=f"latency_input{input_length}",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics=metrics,
            parameters={
                "input_length": input_length,
                "output_length": output_length,
                "warmup_runs": warmup_runs,
                "measurement_runs": measurement_runs,
            },
            raw_data=latencies
        )


class LatencySweep:
    """
    Sweep по разным длинам входа для построения графика latency.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
        self._bench = LatencyBenchmark(bitnet)
    
    def run(
        self,
        input_lengths: List[int] = [16, 32, 64, 128, 256, 512, 1024],
        warmup_runs: int = 5,
        measurement_runs: int = 50
    ) -> List[BenchmarkResult]:
        """
        Запустить sweep по длинам входа.
        
        Args:
            input_lengths: Список длин входа
            warmup_runs: Количество прогревочных запусков
            measurement_runs: Количество измерений
        
        Returns:
            Список BenchmarkResult для каждой длины
        """
        results = []
        
        for length in input_lengths:
            result = self._bench.run(
                input_length=length,
                warmup_runs=warmup_runs,
                measurement_runs=measurement_runs
            )
            results.append(result)
        
        return results
    
    def get_summary(self, results: List[BenchmarkResult]) -> Dict[str, List[float]]:
        """
        Получить сводку для построения графика.
        
        Returns:
            Dict с input_lengths и соответствующими latencies
        """
        input_lengths = []
        mean_latencies = []
        p95_latencies = []
        
        for result in results:
            input_lengths.append(result.parameters["input_length"])
            mean_latencies.append(result.metrics["total_latency"]["mean"])
            p95_latencies.append(result.metrics["total_latency"]["p95"])
        
        return {
            "input_lengths": input_lengths,
            "mean_latency_ms": mean_latencies,
            "p95_latency_ms": p95_latencies,
        }


class FirstTokenLatency:
    """
    Специализированный бенчмарк для измерения time-to-first-token (TTFT).
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
    
    def measure(
        self,
        input_length: int,
        warmup_runs: int = 5,
        measurement_runs: int = 100
    ) -> BenchmarkResult:
        """
        Измерить TTFT.
        
        Args:
            input_length: Длина входной последовательности
            warmup_runs: Количество прогревочных запусков
            measurement_runs: Количество измерений
        
        Returns:
            BenchmarkResult с TTFT метриками
        """
        start_time = time.time()
        
        # Warmup
        for _ in range(warmup_runs):
            input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
            self._bn.inference(input_tokens, max_output=1)
        
        # Measurements
        ttft_values = []
        
        for _ in range(measurement_runs):
            input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
            
            start = time.perf_counter()
            self._bn.inference(input_tokens, max_output=1)
            end = time.perf_counter()
            
            ttft_values.append((end - start) * 1000)
        
        stats = calculate_statistics(ttft_values)
        
        return BenchmarkResult(
            name=f"ttft_input{input_length}",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics={
                "ttft_ms": stats,
            },
            parameters={
                "input_length": input_length,
                "warmup_runs": warmup_runs,
                "measurement_runs": measurement_runs,
            },
            raw_data=ttft_values
        )
