# AGENTS.md - AI Agent Guidelines for VIBEE Development

**Author**: Dmitrii Vasilev

## Overview

This document provides guidelines for AI agents working on the VIBEE project. All agents must follow the **Creation Pattern** and **Predictive Algorithmic Systematics (PAS)** methodology.

---

## ⛔ CRITICAL PROHIBITIONS

### NEVER CREATE THESE FILE TYPES MANUALLY:

```
❌ .html files (except runtime/runtime.html)
❌ .css files
❌ .js files  
❌ .ts files
❌ .jsx files
❌ .tsx files
❌ .zig files in trinity/output/ (ONLY GENERATED)
❌ .py files (ONLY GENERATED)
```

### WHY?

VIBEE uses specification-first development:

```
specs/*.vibee → vibee gen → trinity/output/*.zig
```

### ALLOWED TO EDIT:

```
src/vibeec/*.zig - Compiler source code
specs/*.vibee - Specifications
```

### NEVER EDIT:

```
trinity/output/*.zig - Generated code (will be overwritten)
```

---

## ⚡ VIBEE PIPELINE (MANDATORY)

### Step 1: Create .vibee specification

```yaml
# specs/tri/my_feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      name: String
      count: Int

behaviors:
  - name: my_behavior
    given: Input
    when: Action
    then: Result
```

### Step 2: Generate .zig code

```bash
vibee gen specs/tri/my_feature.vibee
# Output: trinity/output/my_feature.zig
```

### Step 3: Test generated code

```bash
zig test trinity/output/my_feature.zig
```

### Type Mapping Reference:

| VIBEE Type | Zig Type |
|------------|----------|
| `String` | `[]const u8` |
| `Int` | `i64` |
| `Float` | `f64` |
| `Bool` | `bool` |
| `Option<T>` | `?[]const u8` |
| `List<T>` | `[]const u8` |
| `Map<K,V>` | `std.StringHashMap([]const u8)` |
| `Timestamp` | `i64` |
| `Object` | `[]const u8` |

### Reserved Words Handling:

Fields named `error`, `type`, `return`, etc. are automatically escaped as `@"error"`.

### Comments and Defaults:

```yaml
# These are handled automatically:
field: String  # comment is stripped
field: String = "default"  # default is stripped
field: String | Int  # union uses first type
```

---

## 📁 File Organization

```
vibee-lang/
├── specs/tri/              # .vibee specifications (SOURCE)
│   ├── ai_provider.vibee
│   ├── file_operations.vibee
│   └── ...
├── trinity/output/         # Generated .zig (DO NOT EDIT)
│   ├── ai_provider.zig
│   ├── file_operations.zig
│   └── ...
├── src/vibeec/             # Compiler (CAN EDIT)
│   ├── gen_cmd.zig
│   ├── zig_codegen.zig
│   ├── vibee_parser.zig
│   └── ...
├── bin/vibee               # CLI binary
└── generated/crush/zig/    # CLI source
```

---

## 🔧 Commands Reference

```bash
# PRIMARY WORKFLOW
vibee gen specs/tri/feature.vibee              # Generate single
for f in specs/tri/*.vibee; do vibee gen "$f"; done  # Generate all

# TEST
zig test trinity/output/feature.zig            # Test single
cd trinity/output && for f in *.zig; do zig test "$f"; done  # Test all

# REBUILD COMPILER (only if modifying src/vibeec/)
cd src/vibeec && zig build-exe gen_cmd.zig

# REBUILD CLI (only if modifying generated/crush/zig/)
cd generated/crush/zig && zig build-exe main.zig -O ReleaseFast
cp main ../../../bin/vibee

# OTHER COMMANDS
vibee help                    # Show all commands
vibee eval "△ ∧ ○"           # Ternary logic
vibee phi                     # Sacred constants
vibee commit                  # AI git commit
vibee truth and               # Truth tables
```

---

## GIT HOOKS ENFORCEMENT

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

## 🤖 Agent Reasoning (Claude Code Pattern)

### 7-Phase Feature Development Workflow

Based on [Claude Code](https://github.com/anthropics/claude-code) architecture:

```
Phase 1: Discovery      → Understand what to build
Phase 2: Exploration    → Launch parallel explorer agents
Phase 3: Clarification  → Ask ALL questions (CRITICAL)
Phase 4: Architecture   → Present multiple approaches
Phase 5: Implementation → Wait for approval, then build
Phase 6: Review         → Launch parallel reviewer agents
Phase 7: Summary        → Document what was accomplished
```

### Agent Types

```yaml
code_explorer:
  mission: Trace execution paths, map architecture layers
  tools: [glob, grep, ls, read, todo_write]
  output: List of 5-10 key files to read

code_architect:
  mission: Design approaches with different tradeoffs
  focuses: [minimal_changes, clean_architecture, pragmatic_balance]
  output: Comparison with recommendation

code_reviewer:
  mission: Check quality, bugs, conventions
  focuses: [simplicity, correctness, conventions]
  output: Findings ranked by severity
```

### Core Principles

1. **Ask clarifying questions early** - Before designing, not during
2. **Understand before acting** - Read files before writing code
3. **Read files from agents** - Build context from agent findings
4. **Simple and elegant** - Follow codebase conventions
5. **Use TodoWrite** - Track progress through all phases

### VIBEE Agent Workflow

```bash
# 1. Create .vibee specification
vim specs/tri/feature.vibee

# 2. Generate .zig code
vibee gen specs/tri/feature.vibee

# 3. Test generated code
zig test trinity/output/feature.zig

# 4. Iterate if tests fail
# Fix .vibee, regenerate, test again
```

### Generated Agent Reasoning Module

```bash
# Specification
specs/tri/agent_reasoning.vibee

# Generated code (8 tests pass)
trinity/output/agent_reasoning.zig
```

---

**Remember**: Every improvement follows the Creation Pattern. Every algorithm improvement uses PAS. Every feature starts with a specification.

```
Source → Transformer → Result
Known → PAS → Predicted
Specification → vibee gen → Code
```
