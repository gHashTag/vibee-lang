# Changelog

All notable changes to the VIBEE language and compiler.

## [Unreleased]

### Added

#### Creation Pattern Support (from Mathematical Experiments)

Analysis of Collatz, Goldbach, and Twin Prime conjectures revealed patterns that are now first-class language features.

**Parser Enhancements:**
- `CreationPattern` struct: Defines `Source → Transformer → Result` relationships
- `IterationType` enum: `single`, `until_fixed_point`, `until_condition`, `bounded`, `infinite`
- `TransformerType` enum: `pure`, `iterative`, `filter`, `mapping`, `generator`
- `Transformer` struct: Named transformers with type classification
- `TestGeneration` struct: Automatic test generation configuration

**Code Generator Enhancements:**
- Automatic iteration scaffolding for `until_condition` and `until_fixed_point` patterns
- `IterationResult` type with steps, max_reached, and convergence tracking
- `Statistics` type for range analysis
- `analyze_range()` function for statistical analysis over transformations
- Transformer-specific code generation:
  - `pure`: Simple function
  - `filter`: Predicate function + `filter_range_*` helper
  - `mapping`: Binary function + `find_pairs_*` helper
  - `generator`: Iterator struct with `next()` method
- Automatic test generation:
  - Boundary tests (zero, one, max values)
  - Stress tests (configurable ranges)
  - Property tests (idempotence, monotonicity)

**New .vibee Syntax:**

```yaml
creation_pattern:
  source: PositiveInteger
  transformer: collatz_step
  result: One
  iteration: until_condition
  condition: equals(1)
  max_steps: 10000

transformers:
  - name: collatz_step
    type: pure
    input: u64
    output: u64
    rule: "n/2 if even, 3n+1 if odd"

test_generation:
  boundary: true
  stress: true
  property: true
  coverage: 80
```

### Tests

- Parser: 11 tests (4 new for Creation Pattern)
- Code Generator: 10 tests (3 new for Creation Pattern)
- Total compiler tests: 21 (all passing)

### Documentation

- Added `docs/CREATION_PATTERN_IMPROVEMENTS.md`: Design document for improvements
- Added `docs/academic/UNSOLVED_PROBLEMS_CREATION_PATTERN_ANALYSIS.md`: Research paper

### Experiments

- `experiments/collatz_conjecture.vibee`: Collatz specification (13 tests)
- `experiments/goldbach_conjecture.vibee`: Goldbach specification (16 tests)
- `experiments/twin_primes.vibee`: Twin Primes specification (12 tests)
- All 41 experiment tests passing

---

## [1.0.0] - 2026-01-12

### Initial Release

- VIBEE specification language with Given/When/Then behavioral format
- Multi-target code generation: Zig, Python, Rust, Go, Gleam, TypeScript, WASM
- Parser for .vibee YAML specifications
- Type definitions and function signatures
- Test case generation from specifications
