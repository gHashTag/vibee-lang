# .999 Quick Start Guide

Get up and running with .999 in 5 minutes.

## Installation

### From Source

```bash
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang/src/vibeec
zig build
```

### Verify Installation

```bash
./zig-out/bin/vibeec --version
```

## Your First Program

Create `hello.999`:

```999
Ⲯ ⲕⲟⲣⲉ

Ⲫ main() {
    print("Hello, .999!")
}

main()
```

Run it:

```bash
./vibeec run hello.999
```

## Ternary Logic Example

Create `ternary.999`:

```999
Ⲯ ⲧⲣⲓⲛⲓⲧⲩ

Ⲫ main() {
    // Three truth values
    Ⲃ yes: Trit = △
    Ⲃ no: Trit = ▽
    Ⲃ maybe: Trit = ○
    
    // Kleene logic
    print(trit_and(yes, maybe))  // ○
    print(trit_or(yes, maybe))   // △
    print(trit_not(maybe))       // ○
}

main()
```

## VS Code Setup

1. Install the .999 extension from `vscode-999/`
2. Open any `.999` file
3. Enjoy syntax highlighting and LSP support

## WASM Compilation

```bash
./vibeec compile --target wasm hello.999 -o hello.wasm
```

## Next Steps

- [Full Tutorial](TUTORIAL.md)
- [API Reference](API.md)
- [Examples](../examples/)
