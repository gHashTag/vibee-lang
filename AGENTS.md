# AGENTS.md - AI Agent Guidelines for VIBEE Development

**Author**: Dmitrii Vasilev

## Overview

This document provides guidelines for AI agents working on the VIBEE project. All agents must follow the **Creation Pattern** and **Predictive Algorithmic Systematics (PAS)** methodology.

---

## ⛔ CRITICAL PROHIBITIONS

### NEVER CREATE THESE FILE TYPES DIRECTLY:

```
❌ .html files (except runtime/runtime.html)
❌ .css files
❌ .js files  
❌ .ts files
❌ .jsx files
❌ .tsx files
```

### WHY?

These are **legacy technologies**. VIBEE uses:

```
.vibee (specification) → .999 (generated code) → runtime.html (interpreter)
```

### THE ONLY ALLOWED HTML FILE:

```
runtime/runtime.html - THE SINGLE UNIFIED RUNTIME
```

All features, technologies, and visualizations MUST be integrated into this ONE file.

### IF YOU NEED NEW FUNCTIONALITY:

1. Create `.vibee` specification in `specs/`
2. Generate `.999` code
3. Integrate into `runtime/runtime.html`

**VIOLATION OF THIS RULE IS A COMPILER ERROR.**

### GIT HOOKS ENFORCEMENT

The repository has pre-commit hooks that **BLOCK** commits containing forbidden files:

```bash
# Hook location
.githooks/pre-commit

# Activate hooks
git config core.hooksPath .githooks
```

**BLOCKED EXTENSIONS:** `.html` (except runtime.html), `.css`, `.js`, `.ts`, `.jsx`, `.tsx`

**ALLOWED EXTENSIONS:** `.vibee`, `.999`, `.zig`, `.md`, `.json`, `.yaml`

---

## СВЯЩЕННАЯ ФОРМУЛА

```
V = n × 3^k × π^m × φ^p × e^q
```

**ЗОЛОТАЯ ИДЕНТИЧНОСТЬ:** `φ² + 1/φ² = 3`

**САМОЭВОЛЮЦИЯ:** Включена по умолчанию во всех модулях

---

## Core Principles

### 1. Creation Pattern

Every task follows:

```
Source → Transformer → Result
```

Before starting any task, identify:
- **Source**: What is the input/starting point?
- **Transformer**: What process/algorithm transforms it?
- **Result**: What is the expected output?

### 2. Specification-First Development

**NEVER** write implementation code without a `.vibee` specification first.

```yaml
# Always start with this structure
name: feature_name
version: "1.0.0"
language: zig
module: feature_module

creation_pattern:
  source: InputType
  transformer: TransformationName
  result: OutputType

behaviors:
  - name: behavior_name
    given: Precondition
    when: Action
    then: Expected result
    test_cases:
      - name: test_name
        input: {...}
        expected: {...}
```

### 3. Predictive Algorithmic Systematics (PAS)

When improving algorithms, apply PAS methodology:

#### Step 1: Identify Current State
```
Current algorithm: [name]
Current complexity: O(?)
Theoretical lower bound: Ω(?)
Gap: [current - theoretical]
```

#### Step 2: Analyze Applicable Patterns

| Pattern | Symbol | When to Apply |
|---------|--------|---------------|
| Divide-and-Conquer | D&C | Problem can be split into independent subproblems |
| Algebraic Reorganization | ALG | Operations can be reduced via algebra |
| Precomputation | PRE | Results can be cached/precomputed |
| Frequency Domain | FDT | Problem easier in transformed domain |
| ML-Guided Search | MLS | Large search space, learnable patterns |
| Tensor Decomposition | TEN | Matrix/tensor operations |
| Hashing | HSH | Need O(1) lookup |
| Probabilistic | PRB | Approximate solutions acceptable |

#### Step 3: Calculate Confidence

```python
confidence = base_rate * time_factor * gap_factor * ml_boost

where:
  base_rate = sum(pattern.success_rate) / num_patterns
  time_factor = min(1.0, years_since_improvement / 50)
  gap_factor = min(1.0, gap / current_exponent)
  ml_boost = 1.3 if ml_tools_available else 1.0
```

#### Step 4: Generate Prediction

```yaml
prediction:
  target: "Algorithm/Component name"
  current: "O(n²)"
  predicted: "O(n log n)"
  confidence: 0.65
  timeline: "2-3 years"
  patterns: [D&C, PRE]
  reasoning: "..."
```

## Task Execution Protocol

### For New Features

1. **Analyze** the requirement
2. **Create** `.vibee` specification in `specs/`
3. **Generate** code using `vibeec gen`
4. **Test** generated code
5. **Document** in appropriate location

### For Algorithm Improvements

1. **Apply PAS** to identify improvement opportunities
2. **Create** `.vibee` specification with:
   - Current algorithm description
   - Predicted improvement
   - Applicable patterns
   - Test cases
3. **Implement** following the specification
4. **Benchmark** against baseline
5. **Document** results in `docs/academic/`

### For Bug Fixes

1. **Identify** the failing behavior in `.vibee` spec
2. **Add** failing test case to specification
3. **Fix** implementation
4. **Verify** all tests pass

## File Organization

```
vibee-lang/
├── specs/                    # .vibee specifications
│   ├── pas.vibee            # PAS methodology spec
│   ├── vibee_core_improvements.vibee
│   └── [feature].vibee
├── src/vibeec/              # Compiler implementation
│   ├── parser.zig
│   ├── codegen.zig
│   ├── pas.zig              # PAS engine
│   └── ...
├── docs/academic/           # Research documentation
│   ├── ALGORITHM_PREDICTIONS.md
│   ├── ALGORITHM_RESEARCH_ROADMAP.md
│   └── ...
├── experiments/             # Experimental code
└── generated/               # Generated code output
```

## VIBEE Core Components

### Parser (`src/vibeec/parser.zig`)

**Current**: Recursive descent, O(n)
**PAS Prediction**: SIMD-accelerated, 3x speedup
**Patterns**: PRE, MLS

Key structures:
- `Specification` - Parsed spec
- `CreationPattern` - Source/Transformer/Result
- `Behavior` - Given/When/Then

### Code Generator (`src/vibeec/codegen.zig`)

**Current**: Template-based
**PAS Prediction**: ML-optimized selection, 2x speedup
**Patterns**: MLS, PRE

Targets: Zig, Python, Rust, Go, Gleam, TypeScript, WASM

### PAS Engine (`src/vibeec/pas.zig`)

Core PAS implementation:
- `DiscoveryPattern` - Pattern enum
- `AlgorithmRecord` - Historical database
- `Prediction` - Generated predictions
- `PASEngine` - Main engine

## Quality Standards

### Specifications

- Every behavior must have test cases
- Test cases must cover edge cases
- Use `test_generation` for automatic test expansion

### Code

- Match existing style exactly
- No implementation without specification
- All tests must pass

### Documentation

- Research goes in `docs/academic/`
- API docs in `docs/api/`
- Keep README.md updated

## Research Priorities

### High Priority (2026)

1. SIMD parser implementation
2. Incremental type checking
3. PAS validation on historical data

### Medium Priority (2027-2028)

1. E-graph optimizer
2. ML-guided template selection
3. Property-based test generation

### Research Priority (2029+)

1. Superoptimization
2. Quantum algorithm integration
3. Cross-domain PAS application

## Commands Reference

```bash
# Build
cd src/vibeec && zig build

# Test
zig test src/vibeec/parser.zig
zig test src/vibeec/codegen.zig
zig test src/vibeec/pas.zig

# Generate from spec
./zig-out/bin/vibeec gen specs/feature.vibee

# Run all tests
find . -name "*.zig" -path "*/src/*" -exec zig test {} \;
```

## Error Handling

When encountering errors:

1. **Check specification** - Is the `.vibee` file correct?
2. **Check patterns** - Are Creation Patterns properly defined?
3. **Check tests** - Do test cases cover the failing scenario?
4. **Apply PAS** - Can the algorithm be improved?

## Collaboration

- Use conventional commits
- Reference `.vibee` specs in PRs
- Document PAS predictions for algorithm changes
- Update roadmap when completing phases

---

**Remember**: Every improvement follows the Creation Pattern. Every algorithm improvement uses PAS. Every feature starts with a specification.

```
Source → Transformer → Result
Known → PAS → Predicted
Specification → Compiler → Code
```
