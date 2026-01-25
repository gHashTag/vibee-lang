#!/usr/bin/env python3
"""
VIBEE BitNet Benchmark CLI

Командная строка для запуска бенчмарков

Священная Формула: V = n × 3^k × π^m × φ^p × e^q
Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999

Copyright (c) 2024 VIBEE Project
"""

import argparse
import sys
from pathlib import Path

from .runner import BenchmarkRunner
from .latency import LatencyBenchmark, LatencySweep, FirstTokenLatency
from .throughput import ThroughputBenchmark, BatchThroughput, SustainedThroughput
from .memory import MemoryBenchmark, WeightLoadingBenchmark, DMABandwidthSweep
from .report import ReportGenerator


def main():
    parser = argparse.ArgumentParser(
        description="VIBEE BitNet Benchmark Suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all benchmarks
  python -m bitnet.benchmark --model model.bin --output results.json

  # Run specific benchmark
  python -m bitnet.benchmark --model model.bin --benchmark latency

  # Run with custom parameters
  python -m bitnet.benchmark --model model.bin --warmup 10 --runs 200

  # Generate markdown report
  python -m bitnet.benchmark --model model.bin --format markdown --output report.md

φ² + 1/φ² = 3 | PHOENIX = 999
        """
    )
    
    # Required arguments
    parser.add_argument(
        "--model", "-m",
        type=str,
        required=True,
        help="Path to model weights file"
    )
    
    # Optional arguments
    parser.add_argument(
        "--device", "-d",
        type=str,
        default="/dev/bitnet0",
        help="BitNet device path (default: /dev/bitnet0)"
    )
    
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output file path (default: stdout)"
    )
    
    parser.add_argument(
        "--format", "-f",
        type=str,
        choices=["json", "csv", "markdown", "text"],
        default="text",
        help="Output format (default: text)"
    )
    
    parser.add_argument(
        "--benchmark", "-b",
        type=str,
        choices=["all", "latency", "throughput", "memory", "sustained"],
        default="all",
        help="Benchmark to run (default: all)"
    )
    
    parser.add_argument(
        "--warmup", "-w",
        type=int,
        default=5,
        help="Number of warmup runs (default: 5)"
    )
    
    parser.add_argument(
        "--runs", "-r",
        type=int,
        default=100,
        help="Number of measurement runs (default: 100)"
    )
    
    parser.add_argument(
        "--input-length", "-i",
        type=int,
        default=128,
        help="Input sequence length (default: 128)"
    )
    
    parser.add_argument(
        "--output-length", "-l",
        type=int,
        default=64,
        help="Output sequence length (default: 64)"
    )
    
    parser.add_argument(
        "--duration",
        type=int,
        default=60,
        help="Duration for sustained benchmark in seconds (default: 60)"
    )
    
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress progress output"
    )
    
    parser.add_argument(
        "--plot",
        action="store_true",
        help="Generate visualization plots"
    )
    
    parser.add_argument(
        "--plot-dir",
        type=str,
        default="plots",
        help="Directory for plot output (default: plots)"
    )
    
    parser.add_argument(
        "--plot-format",
        type=str,
        choices=["png", "svg", "pdf"],
        default="png",
        help="Plot output format (default: png)"
    )
    
    parser.add_argument(
        "--version", "-v",
        action="version",
        version="BitNet Benchmark Suite 1.0.0"
    )
    
    args = parser.parse_args()
    
    # Run benchmarks
    try:
        run_benchmarks(args)
    except KeyboardInterrupt:
        print("\nBenchmark interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def run_benchmarks(args):
    """Запустить бенчмарки с заданными параметрами"""
    
    print("=" * 60)
    print("VIBEE BitNet Benchmark Suite")
    print("=" * 60)
    print(f"Device: {args.device}")
    print(f"Model: {args.model}")
    print(f"Benchmark: {args.benchmark}")
    print("=" * 60)
    print()
    
    with BenchmarkRunner(
        device=args.device,
        model_path=args.model,
        verbose=not args.quiet
    ) as runner:
        
        if args.benchmark == "all":
            runner.run_all()
        
        elif args.benchmark == "latency":
            runner.run_latency_sweep(
                input_lengths=[16, 32, 64, 128, 256, 512],
                warmup_runs=args.warmup,
                measurement_runs=args.runs
            )
        
        elif args.benchmark == "throughput":
            runner.run_throughput_test(
                input_length=args.input_length,
                output_lengths=[16, 32, 64, 128],
                warmup_runs=args.warmup,
                measurement_runs=args.runs
            )
        
        elif args.benchmark == "memory":
            runner.run_memory_benchmark(
                transfer_sizes=[4096, 16384, 65536, 262144],
                iterations=args.runs
            )
        
        elif args.benchmark == "sustained":
            from .throughput import SustainedThroughput
            bench = SustainedThroughput(runner._bn)
            result = bench.run(
                duration_seconds=args.duration,
                input_length=args.input_length,
                output_length=args.output_length
            )
            runner._suite.add_result(result)
        
        # Output results
        if args.output:
            runner.save_results(args.output, format=args.format)
        else:
            # Print to stdout
            if args.format == "json":
                print(runner.results.to_json())
            elif args.format == "markdown":
                generator = ReportGenerator(runner.results)
                print(generator.to_markdown())
            elif args.format == "csv":
                generator = ReportGenerator(runner.results)
                print(generator.to_csv())
            else:
                # Text format
                print_summary(runner.results)
        
        # Generate plots if requested
        if args.plot:
            generate_plots(runner.results, args.plot_dir, args.plot_format)


def generate_plots(suite, output_dir: str, format: str):
    """Генерация графиков визуализации"""
    try:
        from .visualization import BenchmarkVisualizer
        
        print()
        print("=" * 60)
        print("GENERATING PLOTS")
        print("=" * 60)
        
        viz = BenchmarkVisualizer(suite)
        
        # Создать все доступные графики
        plots_created = []
        
        try:
            viz.plot_latency_histogram()
            plots_created.append("latency_histogram")
        except (ValueError, Exception):
            pass
        
        try:
            viz.plot_latency_percentiles()
            plots_created.append("latency_percentiles")
        except (ValueError, Exception):
            pass
        
        try:
            viz.plot_throughput_bar()
            plots_created.append("throughput_bar")
        except (ValueError, Exception):
            pass
        
        try:
            viz.plot_memory_bandwidth()
            plots_created.append("memory_bandwidth")
        except (ValueError, Exception):
            pass
        
        try:
            viz.plot_summary_dashboard()
            plots_created.append("summary_dashboard")
        except (ValueError, Exception):
            pass
        
        # Сохранить
        saved = viz.save_all(output_dir, formats=[format])
        
        print(f"Plots saved to: {output_dir}/")
        for name in plots_created:
            print(f"  - {name}.{format}")
        
        viz.close_all()
        
    except ImportError as e:
        print(f"Warning: Could not generate plots - {e}")
        print("Install matplotlib: pip install matplotlib")


def print_summary(suite):
    """Вывести краткую сводку результатов"""
    print()
    print("=" * 60)
    print("BENCHMARK RESULTS SUMMARY")
    print("=" * 60)
    print()
    
    for result in suite.results:
        print(f"📊 {result.name}")
        print("-" * 40)
        
        if result.error:
            print(f"  ❌ Error: {result.error}")
        else:
            for metric_name, metric_value in result.metrics.items():
                if isinstance(metric_value, dict):
                    if "mean" in metric_value:
                        print(f"  {metric_name}:")
                        print(f"    Mean: {metric_value['mean']:.3f}")
                        print(f"    P95:  {metric_value.get('p95', 'N/A'):.3f}" if isinstance(metric_value.get('p95'), (int, float)) else "")
                else:
                    print(f"  {metric_name}: {metric_value}")
        
        print(f"  Duration: {result.duration_seconds:.2f}s")
        print()
    
    print("=" * 60)
    print("φ² + 1/φ² = 3 | PHOENIX = 999")
    print("=" * 60)


if __name__ == "__main__":
    main()
