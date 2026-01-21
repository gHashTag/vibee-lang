# IGLA SWE-bench Benchmark Runner Guide

Run real-world GitHub issue benchmarks with IGLA SWE Agent.

## Quick Start

```bash
# Show benchmark info
vibee bench info

# Run evaluation on 5 instances
vibee bench run --dataset lite --limit 5

# Generate report
vibee bench report --run-id igla-run-001

# Compare with competitors
vibee bench compare
```

## Datasets

| Dataset | Instances | Description |
|---------|-----------|-------------|
| `lite` | 300 | Curated subset for faster evaluation |
| `verified` | 500 | Human-verified solvable instances |
| `full` | 2294 | Complete SWE-bench dataset |
| `multimodal` | 517 | Issues with visual elements |

## Commands

### `vibee bench info`

Display benchmark system information including:
- Sacred constants (φ, φ², 1/φ²)
- Dataset sizes
- Competitor scores
- IGLA module counts

### `vibee bench download`

Download SWE-bench dataset from HuggingFace.

```bash
vibee bench download --dataset lite
```

Or use the shell script:
```bash
./scripts/download_swe_bench.sh
```

### `vibee bench run`

Run benchmark evaluation.

```bash
vibee bench run --dataset lite --limit 5 --timeout 1800 --run-id my-run
```

Options:
- `--dataset <name>`: lite, verified, full (default: lite)
- `--limit <n>`: Maximum instances to run
- `--timeout <s>`: Timeout per instance in seconds
- `--workers <n>`: Parallel workers
- `--run-id <id>`: Run identifier

### `vibee bench report`

Generate evaluation report.

```bash
vibee bench report --run-id my-run
```

### `vibee bench compare`

Compare results with competitors.

```bash
vibee bench compare --baseline swe-agent
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IGLA SWE-BENCH RUNNER                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Loader    │───▶│   Harness   │───▶│  Evaluator  │         │
│  │  (14 tests) │    │  (17 tests) │    │  (15 tests) │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │                    Reporter                          │       │
│  │                   (15 tests)                         │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  Total: 4 modules, 61 tests                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

### Loader (`igla_swe_bench_loader.zig`)

Loads and parses SWE-bench dataset:
- `load_lite()` - Load 300 Lite instances
- `load_verified()` - Load 500 Verified instances
- `filter_instances()` - Filter by repo, version
- `parse_fail_to_pass()` - Parse expected test results

### Harness (`igla_swe_bench_harness.zig`)

Execution environment:
- `setup_environment()` - Clone repo, checkout commit
- `apply_patch()` - Apply prediction patch
- `run_tests()` - Execute test suite
- `run_batch()` - Parallel execution

### Evaluator (`igla_swe_bench_evaluator.zig`)

Result grading:
- `grade_fail_to_pass()` - Check if expected tests pass
- `grade_pass_to_pass()` - Check for regressions
- `calculate_resolved_percentage()` - Compute score
- `compare_to_baseline()` - Compare with competitors

### Reporter (`igla_swe_bench_reporter.zig`)

Report generation:
- `format_as_markdown()` - Markdown report
- `format_as_json()` - JSON export
- `generate_repo_breakdown()` - Per-repo stats
- `compare_to_competitors()` - Leaderboard comparison

## Data Format

SWE-bench instance structure:

```json
{
  "instance_id": "sqlfluff__sqlfluff-1625",
  "repo": "sqlfluff/sqlfluff",
  "base_commit": "14e1a23a3166b9a645a16de96f694c77a5d4abb7",
  "patch": "diff --git a/...",
  "test_patch": "diff --git a/...",
  "problem_statement": "Issue description...",
  "FAIL_TO_PASS": "[\"test_foo\", \"test_bar\"]",
  "PASS_TO_PASS": "[\"test_existing\"]"
}
```

## Competitor Scores

| Model | SWE-Lite | Verified | Full |
|-------|----------|----------|------|
| SWE-Agent | 12.29% | 18.00% | 12.47% |
| Devin | 13.86% | 22.00% | 13.86% |
| OpenHands | 21.00% | 33.00% | 21.00% |
| AutoCodeRover | 19.00% | 28.00% | 19.00% |
| Agentless | 27.33% | 41.00% | 27.33% |

## IGLA Advantages

- **26 specialized modules** for SWE tasks
- **Matryoshka acceleration** - φ-optimized task decomposition
- **Trinity amplification** - 3^k agent enhancement
- **Self-improvement loop** - Continuous learning
- **177 tests, 100% pass rate**

## File Locations

```
data/swe_bench/
├── sample_instances.json    # 5 sample instances
├── swe_bench_lite.json      # Full Lite dataset (after download)
└── swe_bench_lite.parquet   # Raw parquet file

logs/bench/<run-id>/
├── report.json              # Evaluation report
├── instances/               # Per-instance logs
└── patches/                 # Generated patches
```

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q

φ² + 1/φ² = 3 ✓
PHOENIX = 999
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
