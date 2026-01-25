"""
VIBEE BitNet Memory Benchmarks

Измерение memory bandwidth и DMA производительности

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
# Memory Benchmark
# ═══════════════════════════════════════════════════════════════════════════════

class MemoryBenchmark:
    """
    Бенчмарк для измерения memory bandwidth.
    
    Измеряет:
    - DMA read bandwidth (скорость чтения)
    - DMA write bandwidth (скорость записи)
    - Weight loading time (время загрузки весов)
    """
    
    def __init__(self, bitnet: BitNet):
        """
        Args:
            bitnet: Инициализированный BitNet контекст
        """
        self._bn = bitnet
    
    def run(
        self,
        transfer_size: int = 65536,
        iterations: int = 100
    ) -> BenchmarkResult:
        """
        Запустить бенчмарк memory bandwidth.
        
        Args:
            transfer_size: Размер передачи в байтах
            iterations: Количество итераций
        
        Returns:
            BenchmarkResult с результатами
        """
        start_time = time.time()
        
        # Измеряем через inference с разными размерами данных
        # Это косвенное измерение, так как прямой доступ к DMA недоступен
        
        # Количество токенов для заданного размера (4 байта на токен)
        num_tokens = transfer_size // 4
        
        bandwidths = []
        
        for _ in range(iterations):
            input_tokens = np.random.randint(1, 1000, size=num_tokens, dtype=np.int32)
            
            start = time.perf_counter()
            output = self._bn.inference(input_tokens, max_output=1)
            end = time.perf_counter()
            
            elapsed = end - start
            # Приблизительный bandwidth: input + output данные
            total_bytes = (num_tokens + len(output)) * 4
            bandwidth_gbps = (total_bytes / elapsed) / (1024 ** 3)
            bandwidths.append(bandwidth_gbps)
        
        stats = calculate_statistics(bandwidths)
        
        return BenchmarkResult(
            name=f"memory_bandwidth_{transfer_size}B",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics={
                "bandwidth_gbps": stats,
                "transfer_size_bytes": transfer_size,
                "effective_bandwidth_gbps": stats["mean"],
            },
            parameters={
                "transfer_size": transfer_size,
                "iterations": iterations,
            },
            raw_data=bandwidths
        )


class WeightLoadingBenchmark:
    """
    Бенчмарк для измерения времени загрузки весов.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
    
    def run(
        self,
        model_path: str,
        iterations: int = 10
    ) -> BenchmarkResult:
        """
        Измерить время загрузки весов.
        
        Args:
            model_path: Путь к файлу с весами
            iterations: Количество итераций
        
        Returns:
            BenchmarkResult с результатами
        """
        import os
        
        start_time = time.time()
        
        # Получаем размер файла
        file_size = os.path.getsize(model_path)
        
        load_times = []
        bandwidths = []
        
        for _ in range(iterations):
            # Reset перед каждой загрузкой
            self._bn.reset()
            
            start = time.perf_counter()
            self._bn.load_weights(model_path)
            end = time.perf_counter()
            
            elapsed = end - start
            load_times.append(elapsed * 1000)  # ms
            bandwidths.append((file_size / elapsed) / (1024 ** 3))  # GB/s
        
        time_stats = calculate_statistics(load_times)
        bw_stats = calculate_statistics(bandwidths)
        
        return BenchmarkResult(
            name="weight_loading",
            timestamp=datetime.now().isoformat(),
            duration_seconds=time.time() - start_time,
            metrics={
                "load_time_ms": time_stats,
                "bandwidth_gbps": bw_stats,
                "file_size_mb": file_size / (1024 ** 2),
            },
            parameters={
                "model_path": model_path,
                "iterations": iterations,
            },
            raw_data=load_times
        )


class MemoryUtilization:
    """
    Измерение утилизации памяти.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
    
    def measure(self) -> Dict[str, Any]:
        """
        Измерить текущую утилизацию памяти.
        
        Returns:
            Dict с метриками памяти
        """
        # Получаем информацию о модели
        model_info = self._bn.model_info
        
        # Оценка использования памяти
        # Веса: num_layers * hidden_size^2 * 2 bits (ternary) / 8
        estimated_weight_size = (
            model_info.num_layers * 
            model_info.hidden_size ** 2 * 
            2 / 8  # 2 bits per weight
        )
        
        # Буферы: input + output + intermediate
        buffer_size = (
            model_info.max_seq_len * model_info.hidden_size * 4 * 3  # 3 buffers
        )
        
        total_estimated = estimated_weight_size + buffer_size
        
        return {
            "estimated_weight_size_mb": estimated_weight_size / (1024 ** 2),
            "estimated_buffer_size_mb": buffer_size / (1024 ** 2),
            "total_estimated_mb": total_estimated / (1024 ** 2),
            "model_info": {
                "num_layers": model_info.num_layers,
                "hidden_size": model_info.hidden_size,
                "vocab_size": model_info.vocab_size,
                "max_seq_len": model_info.max_seq_len,
            }
        }


class DMABandwidthSweep:
    """
    Sweep по разным размерам передачи для построения графика bandwidth.
    """
    
    def __init__(self, bitnet: BitNet):
        self._bn = bitnet
        self._bench = MemoryBenchmark(bitnet)
    
    def run(
        self,
        transfer_sizes: List[int] = [1024, 4096, 16384, 65536, 262144, 1048576],
        iterations: int = 50
    ) -> List[BenchmarkResult]:
        """
        Запустить sweep по размерам передачи.
        
        Args:
            transfer_sizes: Список размеров передачи в байтах
            iterations: Количество итераций для каждого размера
        
        Returns:
            Список BenchmarkResult для каждого размера
        """
        results = []
        
        for size in transfer_sizes:
            result = self._bench.run(
                transfer_size=size,
                iterations=iterations
            )
            results.append(result)
        
        return results
    
    def get_summary(self, results: List[BenchmarkResult]) -> Dict[str, List[float]]:
        """
        Получить сводку для построения графика.
        
        Returns:
            Dict с transfer_sizes и соответствующими bandwidths
        """
        sizes = []
        bandwidths = []
        
        for result in results:
            sizes.append(result.parameters["transfer_size"])
            bandwidths.append(result.metrics["bandwidth_gbps"]["mean"])
        
        return {
            "transfer_sizes_bytes": sizes,
            "bandwidth_gbps": bandwidths,
        }
