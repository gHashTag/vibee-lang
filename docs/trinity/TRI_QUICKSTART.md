# TRI - TRINITY Terminal Interface

**Quick Start Guide for Developers**

---

## Installation

```bash
# TRI is pre-built in bin/
./bin/tri help
```

## Commands

### Git Operations

```bash
# Commit with auto-staging
tri commit -m "feat: add new feature"

# Push to remote
tri push

# Create PR
tri pr --title "My PR"
```

### Ternary Logic

```bash
# Evaluate expressions
tri eval "true AND unknown"    # → ○ (unknown)
tri eval "false OR true"       # → △ (true)
tri eval "NOT false"           # → △ (true)
tri eval "true IMPLIES false"  # → ▽ (false)

# Show truth tables
tri truth and      # AND table
tri truth or       # OR table
tri truth not      # NOT table
tri truth implies  # IMPLIES table
tri truth all      # All tables

# Start REPL
tri repl
```

### PAS Analysis

```bash
# Discovery patterns
tri pas analyze

# Predictions
tri pas predict

# Pattern list
tri pas patterns

# Benchmarks
tri benchmark
```

### General

```bash
tri version    # Version info
tri phi        # Sacred constants
tri config show
tri agent status
```

## Ternary Values

| Symbol | Name | Value |
|--------|------|-------|
| △ | true | +1 |
| ○ | unknown | 0 |
| ▽ | false | -1 |

## Kleene Logic

**AND (minimum):**
```
    │ △  ○  ▽
────┼─────────
  △ │ △  ○  ▽
  ○ │ ○  ○  ▽
  ▽ │ ▽  ▽  ▽
```

**OR (maximum):**
```
    │ △  ○  ▽
────┼─────────
  △ │ △  △  △
  ○ │ △  ○  ○
  ▽ │ △  ○  ▽
```

**NOT:**
```
¬△ = ▽
¬○ = ○
¬▽ = △
```

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q

Golden Identity: φ² + 1/φ² = 3

φ = 1.618033988749895
PHOENIX = 999 = 27 × 37 = 3³ × 37
```

## Build from Source

```bash
cd generated/crush/zig
zig build-exe main.zig -O ReleaseFast --name tri
cp tri /workspaces/vibee-lang/bin/
```

## Run Tests

```bash
# Crush tests
cd generated/crush/zig
zig test crush.zig  # 80 tests

# vibeec tests
cd src/vibeec
zig test compiler.zig  # 29 tests
```

---

**VIBEE v24.φ | φ² + 1/φ² = 3**
