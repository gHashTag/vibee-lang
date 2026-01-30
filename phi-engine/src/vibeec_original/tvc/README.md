# TVC MVP - Trinary Virtual Code Architecture

## Overview

TVC (Trinary Virtual Code) is an intermediate representation that bridges binary logic to ternary execution. It allows VIBEE specifications to be compiled to both binary machine code (for standard hardware) and ternary code (for specialized ternary processors).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    VIBEE SPECIFICATION                       │
│               (specs/tri/*.vibee)                            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TVC PARSER                                 │
│           (tvc_parser.zig)                                  │
│  • Parses .vibee specifications                             │
│  • Generates TVC Intermediate Representation (IR)               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              TVC INTERMEDIATE REPRESENTATION                 │
│                   (tvc_ir.zig)                              │
│  • Trit-based types (-1, 0, 1)                            │
│  • Trinary logic operations (NOT, AND, OR, XOR, IMPLIES)    │
│  • Arithmetic operations (ADD, SUB, MUL, DIV)                │
│  • Control flow (JUMP, JUMP_IF, CALL, RET)                 │
│  • Memory operations (LOAD, STORE, ALLOC, FREE)             │
└──────────┬──────────────────────────────┬───────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────┐    ┌─────────────────────────┐
│  BINARY CODEGEN    │    │  TERNARY CODEGEN      │
│ (binary_codegen.zig)│    │(ternary_codegen.zig)   │
├─────────────────────┤    ├─────────────────────────┤
│ • x86_64 (ELF64)  │    │ • TRIT-CPU           │
│ • ARM64 (ARM64)     │    │ • QUBIT-HYBRID      │
│ • WebAssembly (WASM)│    │                     │
└──────────┬──────────┘    └──────────┬──────────┘
           │                            │
           ▼                            ▼
┌─────────────────────┐    ┌─────────────────────────┐
│   BINARY EXECUTABLE │    │   TERNARY EXECUTABLE   │
│  (x86_64.bin,      │    │  (trit_cpu.trit,       │
│   arm64.bin,        │    │   qubit.trit)          │
│   wasm.wasm)        │    │                       │
└─────────────────────┘    └─────────────────────────┘
```

## TVC Intermediate Representation

### Core Types

```zig
pub const Trit = enum(i2) {
    neg1 = -1,  // False / Off
    zero = 0,   // Unknown / Neutral
    pos1 = 1,   // True / On
};

pub const TVCType = enum {
    i64_trit,      // 64 trit integer (balanced ternary)
    f64_trit,      // 64 trit float
    trit_array,    // Array of trits
    struct_trit,   // Trinary structure
    function_ref,  // Function reference
    unknown,
};
```

### Trinary Logic Operations

TVC implements native trinary logic:

- **trit NOT**: `(-1 → 1, 0 → 0, 1 → -1)`
- **trit AND**: `min(A, B)` - balanced ternary AND
- **trit OR**: `max(A, B)` - balanced ternary OR
- **trit XOR**: `A * B` - trinary multiplication
- **trit IMPLIES**: `min(1 - A + B, 1)` - trinary implication

### TVC Instruction Set

```zig
pub const TVCOpcode = enum(u8) {
    // Trinary Logic Operations
    t_not = 0x00,      // Trinary NOT
    t_and = 0x01,      // Trinary AND
    t_or = 0x02,       // Trinary OR
    t_xor = 0x03,      // Trinary XOR
    t_implies = 0x04,  // Trinary implication

    // Arithmetic
    add = 0x10,
    sub = 0x11,
    mul = 0x12,
    div = 0x13,
    mod = 0x14,

    // Control Flow
    jump = 0x20,
    jump_if = 0x21,
    jump_if_not = 0x22,
    call = 0x23,
    ret = 0x24,

    // Memory
    load = 0x30,
    store = 0x31,
    alloc = 0x32,
    free = 0x33,

    // Stack
    push = 0x40,
    pop = 0x41,
    dup = 0x42,
    swap = 0x43,

    // Special
    nop = 0xF0,
    halt = 0xFF,
};
```

## Usage

### Run Demo

```bash
cd src/vibeec/tvc
zig build-exe tvc_demo.zig -femit-bin -O ReleaseFast --name tvc_demo
./tvc_demo
```

### TVC Components

1. **tvc_ir.zig** - Core IR types and structures
2. **tvc_parser.zig** - Parses .vibee to TVC IR
3. **binary_codegen.zig** - Generates binary code (x86_64, ARM64, WASM)
4. **ternary_codegen.zig** - Generates ternary code (TRIT-CPU, QUBIT-HYBRID)
5. **tvc_cli.zig** - Main CLI interface (WIP)
6. **tvc_demo.zig** - Standalone demonstration

## Binary Targets

### x86_64

- **Format**: ELF64
- **Magic**: `\x7FELF\x02\x01\x01\x00`
- **Architecture**: 64-bit x86
- **Byte Order**: Little-endian

### ARM64

- **Format**: ARM64
- **Magic**: `\x64\x65\x66\x78`
- **Architecture**: 64-bit ARM
- **Byte Order**: Little-endian

### WebAssembly

- **Format**: WASM
- **Magic**: `\x00asm`
- **Version**: 1.0
- **Byte Order**: Little-endian

## Ternary Targets

### TRIT-CPU (Balanced Ternary CPU)

- **Format**: Custom ternary encoding
- **Magic**: `TRIT\x01\x00\x00\x00`
- **Encoding**: 2 trits per byte (balanced ternary)
  - Trit -1 → `0b01`
  - Trit 0 → `0b10`
  - Trit 1 → `0b11`

### QUBIT-HYBRID (Quantum-Ternary Hybrid)

- **Format**: Quantum-ternary hybrid encoding
- **Magic**: `QUBT\x01\x00\x00\x00`
- **Encoding**: 2 trits per byte with quantum superposition markers

## Key Features

1. **Single IR → Multiple Targets**: One TVC IR can generate code for both binary and ternary architectures
2. **Native Trinary Logic**: TVC implements balanced ternary logic natively, not mapped to binary
3. **Zero-Cost Abstraction**: TVC IR maps directly to efficient machine code
4. **VIBEE Integration**: Parses VIBEE specifications directly without manual coding
5. **Hardware Agnostic**: Generate code for current binary hardware or future ternary hardware

## Advantages Over Binary-Only Compilation

1. **Expressiveness**: Trinary logic is more expressive than binary (3 states vs 2)
2. **Efficiency**: Balanced ternary can represent more information per digit
3. **Quantum Compatibility**: Trinary maps naturally to quantum computing (3-level quantum bits)
4. **Future-Proof**: Ready for ternary hardware when it becomes available

## Examples

### Trinary Logic Example

```zig
// VIBEE specification
behaviors:
  - name: trinary_deduce
    given: "Premises and rules"
    when: "Deduction requested"
    then: "Returns inference"

// Generated TVC IR
pub const TVCInstruction{
    .opcode = .t_not,
    .operands = &[_]u64{0},
    .location = 0,
};

pub const TVCInstruction{
    .opcode = .t_and,
    .operands = &[_]u64{1, 2},
    .location = 1,
};
```

### Binary Code Generation

```zig
// TVC: trit NOT
// → Binary: XOR with immediate
0x48, 0x35, 0x01, 0x00  // xor rax, 1 (x86_64)

// TVC: trit AND
// → Binary: AND operation
0x48, 0x21, 0xC8  // and rax, rcx (x86_64)
```

### Ternary Code Generation

```zig
// TVC: trit NOT
// → Ternary: Native trit NOT
[1, 1, -1]  // Load operand, NOT opcode, Negate

// TVC: trit AND
// → Ternary: Native trit AND
[1, 0, 1, 0, 1]  // Load ops, AND opcode, Compute min, Store result
```

## Development Status

### Completed
- ✅ TVC IR definition (tvc_ir.zig)
- ✅ Binary code emitter (x86_64, ARM64, WASM)
- ✅ Ternary code emitter (TRIT-CPU, QUBIT-HYBRID)
- ✅ Standalone demo (tvc_demo.zig)

### In Progress
- 🚧 Full TVC parser (.vibee → TVC IR)
- 🚧 CLI interface (tvc_cli.zig)
- 🚧 Complete integration with VIBEE

### Future Work
- 🔮 Optimizations
- 🔮 Debug information
- 🔮 Standard library bindings
- 🔮 Runtime support

## Links

- [VIBEE Language Spec](../../docs/VIBEE_SPEC.md)
- [Ternary Computing Resources](https://en.wikipedia.org/wiki/Ternary_computer)
- [Balanced Ternary](https://en.wikipedia.org/wiki/Balanced_ternary)

## License

Same as VIBEE project.
