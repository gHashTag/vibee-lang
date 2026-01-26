# VIBEE Tools

## py2vibee - Python to VIBEE Specification Converter

**Source Specification:** `specs/tri/py2vibee.vibee`

### Overview

`py2vibee` converts Python source code to `.vibee` specifications for multiple target languages:

- **Hardware Targets:** `varlog`, `verilog` (FPGA/ASIC)
- **Software Targets:** `zig`, `python`, `rust`, `go`

### Generation Process

This tool is **auto-generated** from its specification following the VIBEE Golden Chain:

```
specs/tri/py2vibee.vibee → vibee gen-multi → tools/py2vibee.py
```

**DO NOT EDIT** `tools/py2vibee.py` manually. All changes must be made to the specification.

### Usage

```bash
# Basic conversion (default target: varlog)
py2vibee input.py --output output.vibee

# Specify target language
py2vibee input.py --target verilog --output fpga_module.vibee
py2vibee input.py --target zig --output software_module.vibee

# Show help
py2vibee --help
```

### Features

1. **AST Parsing:** Full Python AST parsing with `ast` module
2. **Type Inference:** From annotations, variable names, and context
3. **Multi-target Support:** Generates appropriate specifications for each target
4. **Hardware Signals:** Automatic signal generation for Verilog targets (clk, rst_n, start, done, busy)
5. **BDD-style Behaviors:** Generates Given-When-Then behavioral specifications

### Example Workflow

```python
# examples/adder.py
def adder(a: int, b: int) -> int:
    return a + b
```

```bash
# Convert to VIBEE specification
py2vibee examples/adder.py --target varlog --output specs/tri/adder.vibee

# Generate Verilog from specification
vibee gen specs/tri/adder.vibee
# Output: trinity/output/fpga/adder.v
```

### Implementation Notes

The tool follows the **specification-first** principle:

1. **Specification:** `specs/tri/py2vibee.vibee` defines:
   - Types: `Py2VibeeConverter`, `FunctionInfo`, `Argument`, etc.
   - Behaviors: `convert`, `parse_python_file`, `extract_functions`, etc.
   - Test data and metadata

2. **Generation:** The Python implementation is generated from this specification using `vibee gen-multi` with `language: python`.

3. **Testing:** Generated code includes built-in tests based on specification behaviors.

### Supported Python Constructs

- Function definitions with type annotations
- Basic types: `int`, `float`, `str`, `bool`, `list`, `dict`, `tuple`, `None`
- Nested type hints: `List[int]`, `Dict[str, int]`, `Tuple[int, bool]`
- Docstrings (preserved as descriptions)

### Hardware Generation

For `varlog`/`verilog` targets, the tool automatically adds:

- Clock (`clk`), reset (`rst_n`), control (`start`, `done`, `busy`) signals
- Parameter width inference (Int→32-bit, Bool→1-bit, etc.)
- Basic FSM skeleton (placeholder for future enhancement)

### Contributing

To modify `py2vibee`:

1. Edit `specs/tri/py2vibee.vibee`
2. Regenerate: `vibee gen-multi specs/tri/py2vibee.vibee python`
3. Test: `python tools/py2vibee.py --help`

**Never edit `tools/py2vibee.py` directly** - changes will be overwritten.

---

**Sacred Formula:** φ² + 1/φ² = 3  
**Golden Identity Verified** | **PHOENIX = 999**  
**КОЩЕЙ БЕССМЕРТЕН** | **GOLDEN CHAIN IS CLOSED**