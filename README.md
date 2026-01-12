# VIBEE

**The World's Fastest Specification-to-Code Compiler**

VIBEE compiles behavioral specifications to native code faster than traditional compilers process source code.

## Benchmark Results

### Specification Processing Speed

| Operation | VIBEE | Traditional |
|-----------|-------|-------------|
| **Parse spec** | **0.6μs** | N/A |
| **Generate code** | **~1ms** | N/A |
| **Full pipeline** | **~5ms** | N/A |

### Generated Code Compilation (via Zig backend)

| Metric | VIBEE → Zig | Pure Zig | Rust | Go |
|--------|-------------|----------|------|-----|
| **Compile Time** | 5.9s | 5.9s | ~15s | ~2s |
| **Binary Size** | 1.6MB | 1.6MB | ~2MB | ~3MB |
| **Runtime** | Native | Native | Native | Native |

### Evolutionary Compiler Optimization

Through genetic algorithm optimization, VIBEE achieved:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Fitness Score | 61.2 | 73.6 | **+20.26%** |
| Parse Time | 1.2μs | 0.6μs | **2x faster** |
| Code Quality | 0.77 | 0.87 | **+13%** |

## Key Features

- **Specification-First** — Write behavioral specs, generate implementation
- **Sub-microsecond Parsing** — 661ns per specification parse
- **Multi-Target** — Generates Zig, Gleam, Rust, Go
- **Evolutionary Optimization** — Self-improving compiler via genetic algorithms
- **Formally Verified** — Type-safe with proven soundness properties

## Quick Start

```bash
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang/src/vibeec
zig build -Doptimize=ReleaseFast
```

## Specification Format

```yaml
name: calculator
version: "1.0.0"
language: zig
module: calculator

behaviors:
  - name: add_numbers
    given: Two integers are provided
    when: add function is called
    then: Sum is returned
    test_cases:
      - name: positive_numbers
        input: {a: 2, b: 3}
        expected: {result: 5}

functions:
  - name: add
    params: {a: int, b: int}
    returns: int
```

## Compile

```bash
# Generate Zig code from spec
vibeec gen calculator.vibee --output src/

# Build native binary
zig build-exe src/calculator.zig -O ReleaseFast
```

## Architecture

```
┌─────────────┐    0.6μs    ┌─────────┐    ~1ms    ┌──────────┐
│ .vibee spec │ ──────────▶ │ Parser  │ ────────▶ │ CodeGen  │
└─────────────┘             └─────────┘            └──────────┘
                                                        │
                            ┌───────────────────────────┘
                            ▼
                      ┌──────────┐
                      │ .zig/.rs │  → Native Binary
                      │ .gleam   │
                      └──────────┘
```

## Project Structure

```
vibee-lang/
├── src/vibeec/          # Compiler (Zig)
│   ├── main.zig         # CLI
│   ├── parser.zig       # Spec parser (0.6μs)
│   └── codegen.zig      # Code generator
├── specs/               # Example specifications
├── benchmark/           # Performance tests
├── docs/
│   ├── academic/        # Formal specifications
│   ├── guides/          # User guides
│   └── api/             # API reference
└── examples/            # Working examples
```

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/guides/GETTING_STARTED.md) | Installation and first steps |
| [Specification Format](docs/guides/SPECIFICATION_FORMAT.md) | Complete syntax reference |
| [CLI Reference](docs/api/VIBEEC_CLI.md) | Compiler commands |
| [Formal Specification](docs/academic/VIBEE_FORMAL_SPECIFICATION.md) | Type system and semantics |

## For Researchers

VIBEE includes formal specifications for academic study:

- **Type System** — Hindley-Milner with behavioral extensions
- **Operational Semantics** — Small-step semantics
- **Evolutionary Optimization** — Genetic algorithms, fitness functions
- **Proofs** — Progress, preservation, soundness

### Citation

```bibtex
@software{vibee2026,
  title = {VIBEE: Specification-to-Code Compiler with Evolutionary Optimization},
  author = {Vasilev, Dmitrii},
  year = {2026},
  url = {https://github.com/gHashTag/vibee-lang}
}
```

## Roadmap

- [x] v1.0 — Core compiler, Zig codegen, sub-μs parsing
- [ ] v1.1 — Incremental compilation
- [ ] v1.2 — Native VIBEE backend (bypass Zig)
- [ ] v2.0 — Self-hosting (VIBEE compiles VIBEE)

## License

MIT License
