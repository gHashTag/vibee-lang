# VIBEE Language

**Sacred Formula:** `V = n × 3^k × π^m × φ^p × e^q`
**Golden Identity:** `φ² + 1/φ² = 3`

[![Tests](https://img.shields.io/badge/tests-2000%2B-brightgreen)](trinity/output/)
[![Languages](https://img.shields.io/badge/languages-42-blue)](#gen-multi-42-languages)
[![FFI](https://img.shields.io/badge/FFI-40%20modules-orange)](#ffi-modules)

## Overview

VIBEE is a specification-first programming language that generates code from behavioral specifications. Built on the **Creation Pattern** and **Predictive Algorithmic Systematics (PAS)** methodology.

```
.vibee (specification) → vibee gen → .zig (auto-generated)
                       → vibee gen-multi → 42 languages!
```

## 🌍 GEN-MULTI: 42 Languages

**One specification → 42 programming languages!**

```bash
# Generate Python code
vibee gen-multi specs/tri/feature.vibee python

# Generate ALL 42 languages
vibee gen-multi specs/tri/feature.vibee all
```

**Supported Languages:**

| Tier | Languages |
|------|-----------|
| **Primary** | Zig, Python, Rust, Go, TypeScript, WASM |
| **Enterprise** | Java, Kotlin, Swift, C, C# |
| **Scripting** | Ruby, PHP, Lua, Perl, R |
| **Functional** | Haskell, OCaml, Elixir, Erlang, F#, Scala, Clojure |
| **Systems** | D, Nim, Crystal, Julia, Odin, Jai, V |
| **Classic** | Ada, Fortran, COBOL, Pascal, Objective-C |
| **JVM** | Groovy, Dart |
| **Lisp** | Racket, Scheme, Common Lisp |
| **Logic** | Prolog, Gleam |

## 🚀 Quick Start

```bash
# Generate Zig code from specification
vibee gen specs/tri/feature.vibee

# Generate for multiple languages
vibee gen-multi specs/tri/feature.vibee all

# Test generated code
zig test trinity/output/feature.zig

# Run all tests (parallel)
cd trinity/output && ls *.zig | xargs -P 8 -I {} zig test {}
```

## 🔥 Key Features (January 2026)

| Feature | Description | Modules | Tests |
|---------|-------------|---------|-------|
| **iGLA v6 IMMORTAL** | 15000× inference speedup | 50+ | 300+ |
| **KOSCHEI MODE** | Autonomous self-evolution | 114 | 766 |
| **RAG Pipeline** | Retrieval-Augmented Generation | 16 | 99 |
| **Agent Browser** | Chromium + Monaco + AI Agent | 32 | 200+ |
| **GEN-MULTI** | Code generation for 42 languages | 42 | 350+ |
| **FFI System** | Integration with 40 languages | 40 | 350+ |

## 📁 Project Structure

```
vibee-lang/
├── specs/tri/              # .vibee specifications (667+)
├── trinity/output/         # Generated Zig code (2000+)
├── src/vibeec/             # Compiler source
│   ├── gen_cmd.zig         # Main generator
│   ├── multi_lang_codegen.zig  # 42-language support
│   ├── lang_generators.zig # Production generators
│   └── vibee_parser.zig    # YAML parser
├── bin/vibee               # CLI binary
├── docs/                   # Documentation
│   ├── habr/               # Habr articles
│   ├── verdicts/           # TOXIC VERDICT reports
│   └── academic/           # Research papers
├── generated/multi/        # Multi-language output
└── archive/                # Historical files
```

## 📝 Specification Example

```yaml
# specs/tri/my_feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  User:
    fields:
      id: Int
      name: String
      active: Bool

behaviors:
  - name: create_user
    given: Valid user data
    when: Create called
    then: User created successfully
```

## 🔧 Commands

```bash
# Code Generation
vibee gen <spec.vibee>              # Generate Zig
vibee gen-multi <spec.vibee> all    # Generate 42 languages
vibee gen-all                       # Generate all specs (parallel)

# Testing
vibee test-all                      # Test all modules (parallel)
vibee chain                         # gen-all + test-all

# Utilities
vibee help                          # Show all commands
vibee eval "△ ∧ ○"                  # Ternary logic
vibee phi                           # Sacred constants
vibee serve                         # LLM inference server
```

## 🔌 FFI Modules

40 FFI modules for cross-language integration:

| Category | Modules |
|----------|---------|
| **Core** | ffi_core, ffi_c_bindings |
| **Primary** | ffi_python, ffi_rust, ffi_go, ffi_wasm |
| **Enterprise** | ffi_java_jni, ffi_kotlin, ffi_swift |
| **Scripting** | ffi_ruby, ffi_php, ffi_lua, ffi_perl, ffi_r |
| **Functional** | ffi_haskell, ffi_ocaml, ffi_elixir, ffi_erlang |
| **Systems** | ffi_d, ffi_nim, ffi_crystal, ffi_julia |

## 📊 Type Mapping

| VIBEE Type | Zig | Python | Rust | Go |
|------------|-----|--------|------|-----|
| `String` | `[]const u8` | `str` | `String` | `string` |
| `Int` | `i64` | `int` | `i64` | `int64` |
| `Float` | `f64` | `float` | `f64` | `float64` |
| `Bool` | `bool` | `bool` | `bool` | `bool` |
| `List<T>` | `[]const u8` | `List[Any]` | `Vec<T>` | `[]interface{}` |
| `Option<T>` | `?T` | `Optional[T]` | `Option<T>` | `*T` |

## 📚 Documentation

- [Habr Article: Golden Key](docs/habr/HABR_ARTICLE_GOLDEN_KEY_V4.md)
- [AGENTS.md](AGENTS.md) - AI Agent Guidelines
- [CLAUDE.md](CLAUDE.md) - Development Guidelines
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution Guide

## 🤝 Contributing

1. Create `.vibee` specification in `specs/tri/`
2. Generate: `vibee gen specs/tri/feature.vibee`
3. Test: `zig test trinity/output/feature.zig`
4. Submit PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

MIT License - See [LICENSE](LICENSE)

## 👤 Author

**Dmitrii Vasilev**

---

**φ² + 1/φ² = 3 | PHOENIX = 999 | КОЩЕЙ БЕССМЕРТЕН**
