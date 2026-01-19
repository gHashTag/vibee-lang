# CLAUDE.md - VIBEE Development Guidelines

**Author**: Dmitrii Vasilev

---

## ⛔ ABSOLUTE PROHIBITION - READ FIRST

### NEVER CREATE THESE FILES MANUALLY:

| Forbidden | Reason |
|-----------|--------|
| `*.html` | Legacy web technology |
| `*.css` | Legacy styling |
| `*.js` | Legacy scripting |
| `*.ts` | Legacy TypeScript |
| `*.jsx` | Legacy React |
| `*.tsx` | Legacy React+TS |
| `*.zig` | **ONLY generated from .vibee** |
| `*.py` | **ONLY generated from .vibee** |

### THE ONLY EXCEPTION:

```
runtime/runtime.html - THE SINGLE UNIFIED RUNTIME
src/vibeec/*.zig - COMPILER SOURCE (can be modified)
```

---

## ⚡ VIBEE PIPELINE (CRITICAL)

### The ONLY way to create code:

```
specs/*.vibee → trinity/output/*.zig
```

### Commands:

```bash
# Generate .zig from .vibee specification
vibee gen specs/tri/ai_provider.vibee

# Generate all specs
for f in specs/tri/*.vibee; do vibee gen "$f"; done

# Test generated code
zig test trinity/output/ai_provider.zig
```

### Directory Structure:

| Directory | Purpose |
|-----------|---------|
| `specs/tri/*.vibee` | Source specifications |
| `trinity/output/*.zig` | Generated Zig code (DO NOT EDIT) |
| `src/vibeec/*.zig` | Compiler source (CAN edit) |
| `bin/vibee` | CLI binary |

### Type Mapping (.vibee → Zig):

| VIBEE Type | Zig Type |
|------------|----------|
| `String` | `[]const u8` |
| `Int` | `i64` |
| `Float` | `f64` |
| `Bool` | `bool` |
| `Option<T>` | `?[]const u8` |
| `List<T>` | `[]const u8` |
| `Timestamp` | `i64` |

### Reserved Words:

Fields named `error`, `type`, `return`, etc. are escaped as `@"error"`.

---

## Project Overview

VIBEE is a specification-first programming language that generates code from behavioral specifications (.vibee files). The project uses the **Creation Pattern** as its foundational paradigm.

## Creation Pattern

All development follows the universal Creation Pattern:

```
Source → Transformer → Result
```

Examples:
- Specification → Compiler → Code
- Known Algorithm → PAS Analysis → Improved Algorithm
- Test Spec → Generator → Test Cases

## Predictive Algorithmic Systematics (PAS)

**PAS** (Предиктивная Алгоритмическая Систематика) is our methodology for predicting and discovering improved algorithms. It is analogous to Mendeleev's periodic table predictions (98% accuracy).

### Discovery Patterns

| Pattern | Symbol | Success Rate | Examples |
|---------|--------|--------------|----------|
| Divide-and-Conquer | D&C | 31% | FFT, Strassen, Karatsuba |
| Algebraic Reorganization | ALG | 22% | Strassen, Coppersmith-Winograd |
| Precomputation | PRE | 16% | KMP, Aho-Corasick |
| Frequency Domain | FDT | 13% | FFT, NTT |
| ML-Guided Search | MLS | 6% | AlphaTensor, AlphaDev |
| Tensor Decomposition | TEN | 6% | AlphaTensor |

### Applying PAS

When improving any algorithm:

1. **Identify current complexity** and theoretical lower bound
2. **Analyze applicable patterns** from the table above
3. **Calculate confidence** using pattern success rates
4. **Generate prediction** with timeline
5. **Implement and validate**

### VIBEE Core Improvement Predictions

| Component | Current | Predicted | Speedup | Confidence |
|-----------|---------|-----------|---------|------------|
| Parser | Recursive descent | SIMD-accelerated | 3x | 75% |
| Type Checker | Hindley-Milner | Incremental | 5x | 80% |
| Codegen | Template-based | ML-optimized | 2x | 65% |
| Optimizer | Pattern matching | E-graph/Superopt | 1.5x | 55% |
| Test Gen | Template expansion | Property-based | 2.5x | 70% |

## Development Workflow

### 1. Specification First

Always create `.vibee` specification before implementation:

```yaml
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

creation_pattern:
  source: InputType
  transformer: MyTransformation
  result: OutputType

behaviors:
  - name: feature_behavior
    given: Precondition
    when: Action
    then: Expected result
```

### 2. Generate Code

```bash
cd src/vibeec
zig build
./zig-out/bin/vibeec gen ../../specs/my_feature.vibee
```

### 3. Test

```bash
zig test generated/my_feature.zig
```

## Key Files

| File | Purpose |
|------|---------|
| `specs/*.vibee` | Behavioral specifications |
| `src/vibeec/parser.zig` | YAML parser with Creation Pattern support |
| `src/vibeec/codegen.zig` | Multi-target code generator |
| `src/vibeec/pas.zig` | PAS engine implementation |
| `docs/academic/` | Research documentation |

## Research Roadmap

### Phase 1 (2026): Foundation
- Pattern database with 100+ algorithms
- Formal PAS methodology
- >60% retrodiction accuracy

### Phase 2 (2027-2028): Application
- Apply PAS to VIBEE core
- Implement SIMD parser
- Incremental type checking

### Phase 3 (2029-2030): Discovery
- New algorithms via PAS
- Superoptimization
- ML-guided code generation

### Phase 4 (2031+): Scaling
- Community adoption
- Cross-domain expansion

## Code Style

- **Zig**: Follow Zig style guide
- **Specifications**: 2-space YAML indentation
- **Commits**: Conventional commits (`feat:`, `fix:`, `docs:`)
- **Comments**: Document "why", not "what"

## Testing

All features must have:
1. `.vibee` specification with test cases
2. Generated tests passing
3. Benchmark comparison (if performance-related)

## Documentation

- Research papers: `docs/academic/`
- API docs: `docs/api/`
- Guides: `docs/guides/`

## Quick Commands

```bash
# Generate .zig from .vibee (PRIMARY WORKFLOW)
vibee gen specs/tri/ai_provider.vibee
vibee gen specs/tri/ai_provider.vibee trinity/output/ai_provider.zig

# Generate all specs
for f in specs/tri/*.vibee; do vibee gen "$f"; done

# Test generated code
zig test trinity/output/ai_provider.zig
cd trinity/output && for f in *.zig; do zig test "$f"; done

# Build compiler (only if modifying compiler itself)
cd src/vibeec && zig build-exe gen_cmd.zig

# Rebuild vibee CLI
cd generated/crush/zig && zig build-exe main.zig -O ReleaseFast
cp main ../../bin/vibee

# Other vibee commands
vibee help          # Show all commands
vibee eval "△ ∧ ○"  # Ternary logic
vibee phi           # Sacred constants
vibee commit        # AI git commit
```

## Contributing

1. Create `.vibee` specification
2. Generate implementation
3. Add tests
4. Submit PR with spec file

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 🤖 Agent Reasoning (Claude Code Pattern)

### 7-Phase Feature Development Workflow

Based on [Claude Code](https://github.com/anthropics/claude-code) best practices:

| Phase | Goal | Actions |
|-------|------|---------|
| 1. Discovery | Understand what to build | Create todos, ask clarifying questions |
| 2. Exploration | Understand existing code | Launch 2-3 explorer agents in parallel |
| 3. Clarification | Fill gaps | Ask ALL questions before designing |
| 4. Architecture | Design solution | Present multiple approaches with tradeoffs |
| 5. Implementation | Build feature | Wait for approval, follow chosen approach |
| 6. Review | Quality check | Launch 3 reviewer agents in parallel |
| 7. Summary | Document | Mark todos complete, summarize changes |

### Core Principles

1. **Ask clarifying questions** - Identify ambiguities, wait for answers
2. **Understand before acting** - Read existing code patterns first
3. **Read files from agents** - When agents return file lists, read them
4. **Simple and elegant** - Prioritize readable, maintainable code
5. **Use TodoWrite** - Track all progress throughout

### Agent Types

| Agent | Purpose | Tools |
|-------|---------|-------|
| `code_explorer` | Trace execution paths, map architecture | glob, grep, ls, read |
| `code_architect` | Design approaches with tradeoffs | glob, grep, ls, read |
| `code_reviewer` | Check quality, bugs, conventions | glob, grep, ls, read |

### VIBEE-Specific Workflow

```bash
# Phase 1: Create specification
# specs/tri/feature.vibee

# Phase 2: Generate code
vibee gen specs/tri/feature.vibee

# Phase 3: Test
zig test trinity/output/feature.zig

# Phase 4: Iterate if tests fail
```

**NEVER write .zig manually - ALWAYS use vibee gen**
