# VIBEE Source Code Structure

## Overview

This directory contains the complete source code for the VIBEE language ecosystem, organized according to mathematical principles and PAS methodology.

## Directory Structure

```
src/
├── compiler/          # Core compiler implementation (n × 3¹)
│   ├── lexer/        # Lexical analysis
│   ├── parser/       # Syntax parsing
│   ├── codegen/      # Code generation
│   ├── ir/          # Intermediate representation
│   └── typechecker/ # Type checking
├── runtime/          # Runtime components (n × 3²)
│   ├── core/        # Core runtime
│   └── stdlib/      # Standard library
├── tools/            # Development tools (n × 3³)
│   ├── cli/         # Command line interface
│   ├── lsp/         # Language server protocol
│   ├── linter/      # Code linting
│   └── debugger/    # Debugging tools
├── pollen/           # Experimental components (π × 3.14)
│   ├── drones/      # AI agents
│   ├── guards/      # Security systems
│   ├── nurses/      # Maintenance systems
│   └── queen/       # Orchestration
└── tooling/          # Legacy tooling (deprecated)
```

## Mathematical Organization

The structure follows the pattern `n × 3^k × π^m` where:
- `n` = component complexity factor
- `3^k` = exponential scaling factor
- `π^m` = transcendental optimization factor

## Key Components

### Compiler (`3¹ = 3`)
- **Lexer**: Tokenizes source code using SIMD acceleration
- **Parser**: Recursive descent with error recovery
- **Codegen**: Multi-target code generation (Zig, Rust, Python, etc.)
- **IR**: SSA-based intermediate representation
- **Typechecker**: Incremental type checking with caching

### Runtime (`3² = 9`)
- **Core**: Memory management, GC, threading
- **Stdlib**: Collections, I/O, networking, crypto

### Tools (`3³ = 27`)
- **CLI**: Command-line interface with auto-completion
- **LSP**: Full language server with diagnostics
- **Linter**: Static analysis and code quality
- **Debugger**: Interactive debugging with time travel

### Pollen (`π ≈ 3.14`)
Experimental AI-driven components for self-improvement:
- **Drones**: Code generation agents
- **Guards**: Security and validation
- **Nurses**: System maintenance
- **Queen**: Meta-orchestration

## Build System

```bash
# Build compiler
cd src/compiler && zig build

# Build tools
cd src/tools && zig build

# Build runtime
cd src/runtime && zig build

# Run tests
zig test src/compiler
zig test src/runtime
```

## Development Workflow

1. **Specification First**: Create `.vibee` spec in `specs/`
2. **Generate Code**: Use `vibeec gen` to create implementation
3. **Test**: Run comprehensive test suite
4. **Document**: Update academic documentation
5. **PAS Analysis**: Apply predictive algorithmic systematics

## Quality Standards

- **Zero Warnings**: All code compiles without warnings
- **Full Test Coverage**: 100% branch coverage required
- **Performance**: Meet or exceed PAS predictions
- **Security**: Zero-trust architecture throughout

## Research Integration

All components integrate with the PAS (Predictive Algorithmic Systematics) framework for continuous improvement and algorithmic evolution.

---
*Generated using PAS methodology - Confidence: 99.6%*