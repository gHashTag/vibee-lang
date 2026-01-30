# BUILD SCRIPT - PHI-ENGINE v1.0

## Overview

Скрипт для генерации кода из `.vibee` спецификаций и тестирования.

## Usage

```bash
# 1. Generate code from all specifications
./build.sh --all

# 2. Generate code from specific solution
./build.sh --solution amr_resize

# 3. Test generated code
./build.sh --test

# 4. Clean build artifacts
./build.sh --clean
```

## Environment Requirements

- Zig 0.15.2 or later
- VIBEE Compiler (./bin/vibee)
- Shell: bash or zsh

## Commands Reference

| Command | Description |
|---------|-------------|
| `--all` | Generate code for all 11 solutions |
| `--solution <name>` | Generate code for specific solution (e.g., amr_resize) |
| `--test` | Run tests for generated code |
| `--clean` | Remove build artifacts |
| `--doc` | Generate documentation from specs |
| `--bench` | Run benchmarks |

## Build Output

Generated code is placed in `phi-engine/src/{folder}/`.

Test results are placed in `phi-engine/build/test-results/`.

## Example Workflow

```bash
# 1. Generate code for AMR Resize
./build.sh --solution amr_resize

# 2. Run tests
zig test phi-engine/src/core/amr.zig

# 3. Check test results
cat phi-engine/build/test-results/amr_resize.log

# 4. Commit changes
git add phi-engine/src/core/amr.zig
git commit -m "Implement AMR Resize (Solution #1) - CLRS Ch.17"
```

## Exit Codes

| Code | Meaning |
|------|----------|
| 0 | Success |
| 1 | VIBEE compiler not found |
| 2 | Zig not found |
| 3 | Invalid solution name |
| 4 | Compilation failed |
| 5 | Tests failed |

## Integration with AGENTS.md V2.0

This script follows the **PHI-LOCKED LINEAR DEVELOPMENT LOOP**:

1. Implement Solution X (one of the 11)
2. Write Zig code in `phi-engine/src/{folder}/`
3. Test with `zig test`
4. Commit changes
5. NEXT: Solution X+1

**NO TOXIC VERDICT. NO TECH TREE. NO MULTI-AGENT COORDINATION.**

Just engineering with scientific proofs.

---

**φ² + 1/φ² = 3 | PHI-LOCKED PROTOCOL | VIBEE v1.0**
