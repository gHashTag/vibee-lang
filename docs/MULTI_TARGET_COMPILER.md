# MULTI-TARGET VIBEE COMPILER v54000

## Overview

VIBEE теперь поддерживает генерацию кода в **8 языков** из единой `.vibee` спецификации.

## Supported Targets

| Target | Extension | Status | Tests |
|--------|-----------|--------|-------|
| **Zig** | .zig | ✅ STABLE | PASS |
| **Rust** | .rs | ✅ READY | PASS |
| **Python** | .py | ✅ READY | PASS |
| **Go** | .go | ✅ READY | PASS |
| **TypeScript** | .ts | ✅ READY | PASS |
| **Gleam** | .gleam | ✅ READY | PASS |
| **C** | .c/.h | ✅ READY | PASS |
| **WASM** | .wasm | ✅ READY | PASS |

## Type Mappings

### VIBEE → All Languages

| VIBEE | Zig | Rust | Python | Go | TypeScript | Gleam | C |
|-------|-----|------|--------|-----|------------|-------|---|
| `String` | `[]const u8` | `String` | `str` | `string` | `string` | `String` | `char*` |
| `Int` | `i64` | `i64` | `int` | `int64` | `number` | `Int` | `int64_t` |
| `Float` | `f64` | `f64` | `float` | `float64` | `number` | `Float` | `double` |
| `Bool` | `bool` | `bool` | `bool` | `bool` | `boolean` | `Bool` | `bool` |
| `Option<T>` | `?T` | `Option<T>` | `Optional[T]` | `*T` | `T \| undefined` | `Option(T)` | `T*` |
| `List<T>` | `[]T` | `Vec<T>` | `List[T]` | `[]T` | `T[]` | `List(T)` | `T*` |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              .vibee SPECIFICATION                               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VIBEE PARSER                                       │
│                         (Language-Independent AST)                              │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ ZIG BACKEND │ │RUST BACKEND │ │  PY BACKEND │ │ GO BACKEND  │ │ TS BACKEND  │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
       │               │               │               │               │
       ▼               ▼               ▼               ▼               ▼
   .zig file       .rs file        .py file        .go file        .ts file
```

## Usage

### Generate for specific target

```bash
# Zig (default)
vibee gen specs/my_spec.vibee

# Rust
vibee gen specs/my_spec.vibee --target rust

# Python
vibee gen specs/my_spec.vibee --target python

# Go
vibee gen specs/my_spec.vibee --target go

# TypeScript
vibee gen specs/my_spec.vibee --target typescript

# Gleam
vibee gen specs/my_spec.vibee --target gleam

# C
vibee gen specs/my_spec.vibee --target c

# WASM
vibee gen specs/my_spec.vibee --target wasm
```

### Generate for all targets

```bash
vibee gen specs/my_spec.vibee --all-targets
```

## Backend Features

### Zig Backend
- WASM exports
- Comptime support
- Built-in tests
- SIMD optimization

### Rust Backend
- Derive macros (Debug, Clone, Serialize)
- Serde support
- Module system
- Cargo integration

### Python Backend
- Dataclasses
- Type hints (PEP 484)
- Docstrings
- Pytest integration

### Go Backend
- JSON struct tags
- Interface support
- Go modules
- Testing package

### TypeScript Backend
- Interfaces and classes
- Strict mode
- ES modules
- Jest integration

### Gleam Backend
- Type definitions
- Pattern matching
- OTP integration
- Erlang/JS targets

### C Backend
- Header generation
- Typedef structs
- stdint.h types
- Memory management

### WASM Backend
- Binary module
- Export functions
- Memory management
- WAT output option

## Specifications

| File | Types | Behaviors | Tests |
|------|-------|-----------|-------|
| multi_target_compiler_v54000.vibee | 12 | 22 | 23 |
| type_mappings_v54100.vibee | 8 | 36 | 37 |
| codegen_backends_v54200.vibee | 16 | 22 | 23 |
| **TOTAL** | **36** | **80** | **83** |

## φ² + 1/φ² = 3 | PHOENIX = 999
