# Getting Started with VIBEE

## Prerequisites

- Zig 0.13.0 or later
- Git

## Installation

```bash
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang

# Build the compiler
cd src/vibeec
zig build -Doptimize=ReleaseFast
```

## Your First Specification

Create a file `hello.vibee`:

```yaml
name: hello
version: "1.0.0"
language: zig
module: hello

behaviors:
  - name: greet
    given: A name is provided
    when: greet function is called
    then: Returns greeting message

functions:
  - name: greet
    params: {name: str}
    returns: str
```

## Generate Code

```bash
vibeec gen hello.vibee --output src/
```

This generates `src/hello.zig` with:
- Function stubs matching your specification
- Test cases for each behavior
- Documentation comments

## Run Tests

```bash
zig test src/hello.zig
```

## Next Steps

- Read [Specification Format](SPECIFICATION_FORMAT.md) for full syntax
- See [examples/](../../examples/) for more complex examples
- Review [Formal Specification](../academic/VIBEE_FORMAL_SPECIFICATION.md) for theory
