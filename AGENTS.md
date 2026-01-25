# AGENTS.md - AI Agent Guidelines for VIBEE Development

**Author**: Dmitrii Vasilev

## Overview

This document provides guidelines for AI agents working on the VIBEE project. All agents must follow the **Golden Chain** workflow.

---

## 🚨 AUTONOMOUS DEVELOPMENT LOOP (KOSCHEI PATTERN)

### Core Principles:

1. **Specification-First**: NEVER write implementation code directly
2. **Auto-Generation**: Code is GENERATED from specs, not written manually
3. **Continuous Improvement**: Loop until EXIT_SIGNAL or completion
4. **Self-Validation**: Run tests after each generation

### Development Loop:

```
┌─────────────────────────────────────────────────────────────────┐
│                    KOSCHEI DEVELOPMENT LOOP                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. ANALYZE task requirements                                   │
│           ↓                                                     │
│  2. CREATE .vibee specification in specs/tri/                   │
│           ↓                                                     │
│  3. RUN: ./bin/vibee gen specs/tri/feature.vibee                │
│           ↓                                                     │
│  4. TEST: zig test trinity/output/feature.zig                   │
│           ↓                                                     │
│  5. CHECK: All tests passing?                                   │
│           ↓                                                     │
│     YES → Write TOXIC VERDICT + TECH TREE SELECT → EXIT         │
│     NO  → ITERATE (go to step 2)                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⛔ CRITICAL PROHIBITIONS

### 🚫 ANTI-PATTERN #1: WRITING .zig CODE MANUALLY

```
❌ NEVER write .zig code directly - this is an ANTI-PATTERN!
❌ ALL .zig code MUST be GENERATED from .vibee specifications
❌ The only exception: src/vibeec/*.zig (compiler source code)
```

### NEVER CREATE THESE FILE TYPES MANUALLY:

```
❌ .html files (except runtime/runtime.html)
❌ .css files
❌ .js files  
❌ .ts files
❌ .jsx files
❌ .tsx files
❌ .zig files - ANTI-PATTERN! Use .vibee → gen → .zig
❌ .py files (ONLY GENERATED)
❌ .v files - ANTI-PATTERN! Use .vibee (language: varlog) → gen → .v
```

### WHY?

VIBEE uses specification-first development:

```
specs/*.vibee (language: zig)    → vibee gen → trinity/output/*.zig
specs/*.vibee (language: varlog) → vibee gen → trinity/output/fpga/*.v
```

### CORRECT WORKFLOW:

```bash
# 1. Create specification (NOT code!)
cat > specs/tri/my_feature.vibee << 'EOF'
name: my_feature
version: "1.0.0"
language: varlog  # For FPGA/Verilog
# OR
language: zig     # For software
module: my_feature
...
EOF

# 2. Generate code (NEVER write it manually!)
./bin/vibee gen specs/tri/my_feature.vibee

# 3. Test generated code
zig test trinity/output/my_feature.zig
# OR for Verilog:
iverilog trinity/output/fpga/my_feature.v
```

### ALLOWED TO EDIT:

```
src/vibeec/*.zig - Compiler source code ONLY
specs/tri/*.vibee - Specifications (NO manual code blocks!)
docs/*.md - Documentation
```

### NEVER EDIT:

```
trinity/output/*.zig - Generated code (will be overwritten)
trinity/output/fpga/*.v - Generated Verilog (will be overwritten)
generated/*.zig - Generated code (will be overwritten)
```

---

## ⚡ VIBEE PIPELINE (MANDATORY)

### Step 1: Create .vibee specification

```yaml
# specs/tri/my_feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      name: String
      count: Int

behaviors:
  - name: my_behavior
    given: Input
    when: Action
    then: Result
```

### Step 2: Generate .zig code

```bash
./bin/vibee gen specs/tri/my_feature.vibee
# Output: trinity/output/my_feature.zig
```

### Step 3: Test generated code

```bash
zig test trinity/output/my_feature.zig
```

### Type Mapping Reference:

| VIBEE Type | Zig Type |
|------------|----------|
| `String` | `[]const u8` |
| `Int` | `i64` |
| `Float` | `f64` |
| `Bool` | `bool` |
| `Option<T>` | `?[]const u8` |
| `List<T>` | `[]const u8` |
| `Map<K,V>` | `std.StringHashMap([]const u8)` |
| `Timestamp` | `i64` |
| `Object` | `[]const u8` |

---

## 🔥 MANDATORY: TOXIC VERDICT

After EVERY task completion, write harsh self-criticism:

```
╔══════════════════════════════════════════════════════════════════╗
║                    🔥 TOXIC VERDICT 🔥                           ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT WAS DONE:                                                   ║
║ - [specifically what was implemented]                            ║
║                                                                  ║
║ WHAT FAILED:                                                     ║
║ - [honest about mistakes]                                        ║
║                                                                  ║
║ METRICS:                                                         ║
║ - Before: X | After: Y | Δ = Z%                                  ║
║                                                                  ║
║ SELF-CRITICISM:                                                  ║
║ - [harsh analysis without rose-colored glasses]                  ║
║ - [what could have been done better]                             ║
║                                                                  ║
║ SCORE: [1-10]/10                                                 ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 🌳 MANDATORY: TECH TREE SELECT

After toxic verdict, propose 3 options for next research:

```
┌─────────────────────────────────────────────────────────────────┐
│              🌳 TECH TREE - SELECT NEXT                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [A] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★☆☆☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  [B] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★★☆☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  [C] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★★★☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  RECOMMENDATION: [A/B/C] because [reason]                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 File Organization

```
vibee-lang/
├── specs/tri/              # .vibee specifications (SOURCE)
│   ├── ai_provider.vibee
│   ├── file_operations.vibee
│   └── ...
├── trinity/output/         # Generated .zig (DO NOT EDIT)
│   ├── ai_provider.zig
│   ├── file_operations.zig
│   └── ...
├── src/vibeec/             # Compiler (CAN EDIT)
│   ├── gen_cmd.zig
│   ├── zig_codegen.zig
│   ├── vibee_parser.zig
│   └── ...
├── bin/vibee               # CLI binary
└── docs/                   # Documentation
```

---

## 🔧 Commands Reference

```bash
# PRIMARY WORKFLOW
./bin/vibee gen specs/tri/feature.vibee              # Generate single
for f in specs/tri/*.vibee; do ./bin/vibee gen "$f"; done  # Generate all

# TEST
zig test trinity/output/feature.zig            # Test single
cd trinity/output && for f in *.zig; do zig test "$f"; done  # Test all

# GOLDEN CHAIN
./bin/vibee koschei          # Show 16 links
./bin/vibee koschei chain    # Architecture
./bin/vibee koschei status   # Status
```

---

## 🏆 EXIT_SIGNAL

Agent must continue iterations until:
1. All tests pass
2. Specification is complete
3. TOXIC VERDICT is written
4. TECH TREE SELECT is proposed
5. Changes are committed

```yaml
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

---

## GIT HOOKS ENFORCEMENT

The repository has pre-commit hooks that **BLOCK** commits containing forbidden files:

```bash
# Hook location
.githooks/pre-commit

# Activate hooks
git config core.hooksPath .githooks
```

**BLOCKED EXTENSIONS:** `.html` (except runtime.html), `.css`, `.js`, `.ts`, `.jsx`, `.tsx`

**ALLOWED EXTENSIONS:** `.vibee`, `.999`, `.zig`, `.md`, `.json`, `.yaml`

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
