# IGLA Self-Improvement Loop Guide

Reflexion-based iterative improvement for SWE Agent.

## Overview

The Self-Improvement Loop implements the Reflexion pattern from [Shinn et al. 2023](https://arxiv.org/abs/2303.11366):

1. **Attempt** - Try to solve the problem
2. **Evaluate** - Check if solution works
3. **Reflect** - Analyze what went wrong
4. **Improve** - Apply reflection to generate better solution
5. **Repeat** - Until success or max iterations

## Quick Start

```bash
# Run demo
python3 scripts/self_improve.py --max-iterations 5

# With custom threshold
python3 scripts/self_improve.py --max-iterations 10 --threshold 0.05
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 IGLA SELF-IMPROVEMENT LOOP                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Reflexion  │───▶│  Failure    │───▶│   Prompt    │         │
│  │    Loop     │    │  Analyzer   │    │  Optimizer  │         │
│  │ (13 tests)  │    │ (13 tests)  │    │ (13 tests)  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              Experience Memory                       │       │
│  │                  (14 tests)                          │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  Total: 4 modules, 53 tests                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### ReflexionLoop

Main improvement loop:

```python
from self_improve import ReflexionLoop

loop = ReflexionLoop(max_iterations=5, improvement_threshold=0.1)
result = loop.run(problem, initial_patch, test_func, llm_client)
```

### FailureAnalyzer

Categorizes failures:

| Category | Description | Score |
|----------|-------------|-------|
| `patch_syntax` | Syntax error in patch | 0.1 |
| `patch_application` | Patch won't apply | 0.2 |
| `test_failure` | Tests fail | 0.5 |
| `edge_case` | Edge case not handled | 0.6 |
| `logic_error` | Logic bug | 0.4 |
| `timeout` | Execution timeout | 0.3 |

### ExperienceMemory

Episodic memory for past experiences:

```python
from self_improve import ExperienceMemory

memory = ExperienceMemory(max_size=1000)
memory.store(instance_id, problem, solution, reflection, success, score, tags)
similar = memory.retrieve_similar(problem, limit=5)
```

### PromptOptimizer

Genetic algorithm for prompt optimization:

- **Mutation**: Add constraints, examples, simplify
- **Crossover**: Combine successful prompts
- **Selection**: Tournament selection

## Reflection Format

```
Reflection on Attempt N:

WHAT HAPPENED:
- Test passed: False
- Error category: test_failure
- Root cause: Test assertion failed

WHAT WENT WRONG:
AssertionError: expected True, got False

WHAT TO DO DIFFERENTLY:
- Review test expectations, check edge cases
- Confidence: 80%

KEY INSIGHT:
Based on this failure, I should focus on test assertion failed
and ensure the next attempt addresses this specific issue.
```

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_iterations` | 5 | Maximum improvement attempts |
| `improvement_threshold` | 0.1 | Min improvement to continue |
| `memory_size` | 1000 | Max experiences to store |

## Integration with SWE-bench

```python
from self_improve import ReflexionLoop
from swe_harness import SWEBenchHarness

harness = SWEBenchHarness()
loop = ReflexionLoop(max_iterations=5)

def test_func(patch):
    result = harness.evaluate_instance(instance, patch)
    return result['resolved'], result.get('error', '')

result = loop.run(
    problem=instance['problem_statement'],
    initial_patch=generated_patch,
    test_func=test_func
)
```

## Modules

| Module | Tests | Description |
|--------|-------|-------------|
| `igla_self_improve_loop` | 13 | Main Reflexion loop |
| `igla_failure_analyzer` | 13 | Failure categorization |
| `igla_prompt_optimizer` | 13 | Prompt evolution |
| `igla_experience_memory` | 14 | Episodic memory |

## Example Output

```
======================================================================
IGLA SELF-IMPROVEMENT LOOP (Reflexion)
======================================================================
Max iterations: 5
Improvement threshold: 0.1
======================================================================

[Iteration 1/5]
  Category: test_failure
  Score: 0.50
  Suggested: Review test expectations, check edge cases
  Status: Continuing improvement

[Iteration 2/5]
  Category: edge_case
  Score: 0.60
  Suggested: Add bounds checking, handle None/empty cases
  Status: Continuing improvement

[Iteration 3/5]
  ✓ TEST PASSED!
  Status: Test passed!

======================================================================
RESULTS
======================================================================
Success: True
Iterations: 3
Best score: 1.00
Improvement: [0.5, 0.6, 1.0]
======================================================================
φ² + 1/φ² = 3 | PHOENIX = 999
```

## Statistics

| Metric | Value |
|--------|-------|
| Modules | 4 |
| Tests | 53 |
| Pass rate | 100% |

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
