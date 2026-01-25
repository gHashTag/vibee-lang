# VIBEE BitNet Benchmark Suite

Performance benchmarking for BitNet FPGA inference.

## Installation

```bash
pip install -e .
```

## Usage

### Command Line

```bash
# Run all benchmarks
python -m bitnet.benchmark --model model.bin

# Specific benchmark types
python -m bitnet.benchmark --model model.bin --type latency
python -m bitnet.benchmark --model model.bin --type throughput
python -m bitnet.benchmark --model model.bin --type memory

# Custom parameters
python -m bitnet.benchmark --model model.bin \
    --iterations 100 \
    --warmup 10 \
    --batch-sizes 1,8,16,32

# Output formats
python -m bitnet.benchmark --model model.bin --format json --output results.json
python -m bitnet.benchmark --model model.bin --format csv --output results.csv
python -m bitnet.benchmark --model model.bin --format markdown --output results.md
```

### Python API

```python
from bitnet import BitNet
from bitnet.benchmark import (
    BenchmarkRunner,
    LatencyBenchmark,
    ThroughputBenchmark,
    MemoryBenchmark,
    ReportGenerator
)

# Initialize
driver = BitNet()
driver.load_model("model.bin")

# Run benchmarks
runner = BenchmarkRunner(driver)
results = runner.run_all(iterations=100, warmup=10)

# Generate report
report = ReportGenerator(results)
report.to_json("results.json")
report.to_markdown("results.md")
```

## Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| Latency (mean) | ms | Average inference time |
| Latency (p50) | ms | Median latency |
| Latency (p95) | ms | 95th percentile |
| Latency (p99) | ms | 99th percentile |
| Throughput | tokens/sec | Processing rate |
| Memory Bandwidth | GB/s | Data transfer rate |
| Memory Usage | MB | Peak memory consumption |

## Output Example

```
╔══════════════════════════════════════════════════════════════════╗
║              VIBEE BitNet Benchmark Results                      ║
╠══════════════════════════════════════════════════════════════════╣
║ Model: model.bin                                                 ║
║ Iterations: 100 | Warmup: 10                                     ║
╠══════════════════════════════════════════════════════════════════╣
║ LATENCY                                                          ║
║   Mean:    12.45 ms                                              ║
║   P50:     11.89 ms                                              ║
║   P95:     15.23 ms                                              ║
║   P99:     18.67 ms                                              ║
╠══════════════════════════════════════════════════════════════════╣
║ THROUGHPUT                                                       ║
║   Tokens/sec: 1,245.67                                           ║
║   Batch size: 32                                                 ║
╠══════════════════════════════════════════════════════════════════╣
║ MEMORY                                                           ║
║   Bandwidth: 45.23 GB/s                                          ║
║   Peak usage: 512 MB                                             ║
╚══════════════════════════════════════════════════════════════════╝
```

## Visualization

Generate plots with `--plot` flag:

```bash
# Generate all plots
python -m bitnet.benchmark --model model.bin --plot --plot-dir plots/

# Specific format
python -m bitnet.benchmark --model model.bin --plot --plot-format svg
```

### Python API

```python
from bitnet.benchmark import BenchmarkVisualizer, visualize_results

# Quick visualization
viz = visualize_results(suite, output_dir="plots/", show=True)

# Manual control
viz = BenchmarkVisualizer(suite)
viz.plot_latency_histogram()
viz.plot_latency_percentiles()
viz.plot_throughput_bar()
viz.plot_memory_bandwidth()
viz.plot_summary_dashboard()
viz.save_all("plots/", formats=["png", "svg"])
```

### Available Charts

| Chart | Description |
|-------|-------------|
| `latency_histogram` | Distribution of latency with mean/median |
| `latency_percentiles` | Bar chart of P50, P95, P99 |
| `latency_boxplot` | Comparison across runs |
| `throughput_bar` | Tokens/sec by configuration |
| `throughput_scaling` | Scaling efficiency |
| `memory_bandwidth` | GB/s by transfer size |
| `summary_dashboard` | 2x2 grid with all metrics |

### Output Formats

- **PNG** - Default, best for reports
- **SVG** - Vector, best for web
- **PDF** - Best for publications

## Architecture

```
bitnet/benchmark/
├── __init__.py      # Public API exports
├── __main__.py      # Module entry point
├── cli.py           # Command-line interface
├── runner.py        # Benchmark orchestration
├── latency.py       # Latency measurements
├── throughput.py    # Throughput measurements
├── memory.py        # Memory bandwidth tests
├── report.py        # Report generation (JSON/CSV/MD)
└── visualization.py # Matplotlib charts
```

## Testing

```bash
# Run all tests
python -m pytest tests/ -v

# Run specific test
python -m pytest tests/test_visualization.py -v
```

## CI/CD

Automated testing via GitHub Actions:
- Python 3.9, 3.10, 3.11, 3.12
- Syntax validation
- Unit tests with coverage
- Lint checks (flake8)

[![Benchmark Tests](https://github.com/gHashTag/vibee-lang/actions/workflows/benchmark-tests.yml/badge.svg)](https://github.com/gHashTag/vibee-lang/actions/workflows/benchmark-tests.yml)
