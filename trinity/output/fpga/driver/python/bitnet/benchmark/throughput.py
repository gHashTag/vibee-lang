"""
VIBEE BitNet Throughput Benchmarks

Измерение throughput (токенов в секунду)

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
# Throughput Benchmark
# ═══════════════════════════════════════════════════════════════════════════════

class ThroughputBenchmark:
    """
    Бенчмарк для измерения throughput.
    
    Измеряет:
    - Tokens per second (токенов в секунду)
    - Inferences per second (inference в секунду)
    - Batch throughput (throughput при batch processing)
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
        output_length: int
    ) -> Dict[str, float]:
        """
        Одно измерение throughput.
        
        Args:
            input_length: Длина входной последовательности
            output_length: Максимальная длина выхода
        
        Returns:
            Dict с метриками throughput
        """
        input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
        
        start = time.perf_counter()
        output = self._bn.inference(input_tokens, max_output=output_length)
        end = time.perf_counter()
        
        elapsed = end - start
        num_output_tokens = len(output)
        total_tokens = input_length + num_output_tokens
        
        return {
            "elapsed_seconds": elapsed,
            "input_tokens": input_length,
            "output_tokens": num_output_tokens,
            "total_tokens": total_tokens,
            "tokens_per_second": total_tokens / elapsed if elapsed > 0 else 0,
            "output_tokens_per_second": num_output_tokens / elapsed if elapsed > 0 else 0,
        }
    
    def run(
        self,
        input_length: int = 128,
        output_length: int = 64,
        warmup_runs: int = 5,
        measurement_runs: int = 50
    ) -> BenchmarkResult:
        """
        Запустить бенчмарк throughput.
        
        Args:
            input_length: Длина входной последовательности
            output_length: Максимальная длина выхода
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
        tokens_per_second = []
        output_tokens_per_second = []
        total_tokens_generated = 0
        total_time = 0
        
        for _ in range(measurement_runs):
            result = self.measure_single(input_length, output_length)
            tokens_per_second.append(result["tokens_per_second"])
            output_tokens_per_second.append(result["output_tokens_per_second"])
            total_tokens_generated += result["output_tokens"]
            total_time += result["elapsed_seconds"]
        
        # Calculate statistics
        tps_stats = calculate_statistics(tokens_per_second)
        output_tps_stats = calculate_statistics(output_tokens_per_second)
        
        # Aggregate throughput
        aggregate_throughput = total_tokens_generated / total_time if total_time > 0 else 0
        inferences_per_second = measurement_runs / total_time if total_time > 0 else 0
        
        metrics = {
            "tokens_per_second": tps_stats,
            "output_tokens_per_second": output_tps_stats,
            "aggregate_throughput": aggregate_throughput,
            "inferences_per_second": inferences_per_second,
            "total_tokens_generated": total_tokens_generated,
        }
        
        return BenchmarkResult(
            name=f"throughput_in{input_length}_out{output_length}",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics=metrics,
            parameters={
                "input_length": input_length,
                "output_length": output_length,
                "warmup_runs": warmup_runs,
                "measurement_runs": measurement_runs,
            },
            raw_data=tokens_per_second
        )


class BatchThroughput:
    """
    Измерение throughput при batch processing.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
    
    def run(
        self,
        batch_sizes: List[int] = [1, 2, 4, 8, 16],
        input_length: int = 64,
        output_length: int = 32,
        warmup_runs: int = 3,
        measurement_runs: int = 20
    ) -> List[BenchmarkResult]:
        """
        Измерить throughput при разных batch sizes.
        
        Args:
            batch_sizes: Список размеров batch
            input_length: Длина входной последовательности
            output_length: Максимальная длина выхода
            warmup_runs: Количество прогревочных запусков
            measurement_runs: Количество измерений
        
        Returns:
            Список BenchmarkResult для каждого batch size
        """
        results = []
        
        for batch_size in batch_sizes:
            result = self._run_batch(
                batch_size=batch_size,
                input_length=input_length,
                output_length=output_length,
                warmup_runs=warmup_runs,
                measurement_runs=measurement_runs
            )
            results.append(result)
        
        return results
    
    def _run_batch(
        self,
        batch_size: int,
        input_length: int,
        output_length: int,
        warmup_runs: int,
        measurement_runs: int
    ) -> BenchmarkResult:
        """Запустить бенчмарк для одного batch size"""
        start_time = time.time()
        
        # Warmup
        for _ in range(warmup_runs):
            self._process_batch(batch_size, input_length, output_length)
        
        # Measurements
        throughputs = []
        latencies = []
        
        for _ in range(measurement_runs):
            start = time.perf_counter()
            total_tokens = self._process_batch(batch_size, input_length, output_length)
            end = time.perf_counter()
            
            elapsed = end - start
            throughputs.append(total_tokens / elapsed if elapsed > 0 else 0)
            latencies.append(elapsed * 1000)  # ms
        
        tps_stats = calculate_statistics(throughputs)
        latency_stats = calculate_statistics(latencies)
        
        return BenchmarkResult(
            name=f"batch_throughput_bs{batch_size}",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics={
                "tokens_per_second": tps_stats,
                "batch_latency_ms": latency_stats,
                "per_sample_latency_ms": latency_stats["mean"] / batch_size,
            },
            parameters={
                "batch_size": batch_size,
                "input_length": input_length,
                "output_length": output_length,
            },
            raw_data=throughputs
        )
    
    def _process_batch(
        self,
        batch_size: int,
        input_length: int,
        output_length: int
    ) -> int:
        """Обработать batch и вернуть общее количество токенов"""
        total_tokens = 0
        
        for _ in range(batch_size):
            input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
            output = self._bn.inference(input_tokens, max_output=output_length)
            total_tokens += input_length + len(output)
        
        return total_tokens


class SustainedThroughput:
    """
    Измерение устойчивого throughput при длительной нагрузке.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
    
    def run(
        self,
        duration_seconds: int = 60,
        input_length: int = 128,
        output_length: int = 64,
        sample_interval: float = 1.0
    ) -> BenchmarkResult:
        """
        Измерить устойчивый throughput.
        
        Args:
            duration_seconds: Длительность теста в секундах
            input_length: Длина входной последовательности
            output_length: Максимальная длина выхода
            sample_interval: Интервал сэмплирования в секундах
        
        Returns:
            BenchmarkResult с временным рядом throughput
        """
        start_time = time.time()
        
        throughput_samples = []
        timestamps = []
        total_tokens = 0
        total_inferences = 0
        
        sample_start = time.time()
        sample_tokens = 0
        
        while time.time() - start_time < duration_seconds:
            input_tokens = np.random.randint(1, 1000, size=input_length, dtype=np.int32)
            output = self._bn.inference(input_tokens, max_output=output_length)
            
            tokens = input_length + len(output)
            total_tokens += tokens
            sample_tokens += tokens
            total_inferences += 1
            
            # Sample throughput
            if time.time() - sample_start >= sample_interval:
                elapsed = time.time() - sample_start
                throughput_samples.append(sample_tokens / elapsed)
                timestamps.append(time.time() - start_time)
                sample_start = time.time()
                sample_tokens = 0
        
        total_duration = time.time() - start_time
        
        stats = calculate_statistics(throughput_samples)
        
        return BenchmarkResult(
            name="sustained_throughput",
            timestamp=datetime.now().isoformat(),
            duration_seconds=total_duration,
            metrics={
                "throughput_over_time": stats,
                "average_throughput": total_tokens / total_duration,
                "total_tokens": total_tokens,
                "total_inferences": total_inferences,
                "timestamps": timestamps,
                "samples": throughput_samples,
            },
            parameters={
                "duration_seconds": duration_seconds,
                "input_length": input_length,
                "output_length": output_length,
                "sample_interval": sample_interval,
            },
            raw_data=throughput_samples
        )
