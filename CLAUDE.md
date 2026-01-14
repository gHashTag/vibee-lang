# CLAUDE.md - VIBEE Development Guidelines

**Author**: Dmitrii Vasilev

---

## ⛔ ABSOLUTE PROHIBITION - READ FIRST

### NEVER CREATE THESE FILES:

| Forbidden | Reason |
|-----------|--------|
| `*.html` | Legacy web technology |
| `*.css` | Legacy styling |
| `*.js` | Legacy scripting |
| `*.ts` | Legacy TypeScript |
| `*.jsx` | Legacy React |
| `*.tsx` | Legacy React+TS |

### THE ONLY EXCEPTION:

```
runtime/runtime.html - THE SINGLE UNIFIED RUNTIME
```

This is the ONLY HTML file in the entire project. ALL functionality integrates here.

### VIBEE ARCHITECTURE:

```
.vibee (spec) → .999 (code) → runtime.html (interpreter)
```

**Creating separate HTML/CSS/JS files is a COMPILATION ERROR.**

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
# Build compiler
cd src/vibeec && zig build

# Run tests
zig test src/vibeec/parser.zig
zig test src/vibeec/codegen.zig
zig test src/vibeec/pas.zig

# Generate code from spec
./zig-out/bin/vibeec gen specs/my_feature.vibee

# Run benchmarks
zig run benchmark/parser_bench.zig
```

## Contributing

1. Create `.vibee` specification
2. Generate implementation
3. Add tests
4. Submit PR with spec file

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.
