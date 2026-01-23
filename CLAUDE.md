# CLAUDE.md - GOLDEN CHAIN Development Guidelines

**Author**: Dmitrii Vasilev
**Sacred Formula**: `V = n × 3^k × π^m × φ^p × e^q`
**Golden Identity**: `φ² + 1/φ² = 3`

---

## 🚨 FIRST: RUN KOSCHEI

```bash
./bin/vibee koschei
```

This shows 16 links of the Golden Chain - **MANDATORY** development cycle!

---

## ⛓️ GOLDEN CHAIN - 16 LINKS

> *"By the curved seashore stands a green oak, a golden chain upon that oak..."*

```
┌────┬──────────────────┬─────────────────────────────────────────┐
│  # │ LINK             │ DESCRIPTION                             │
├────┼──────────────────┼─────────────────────────────────────────┤
│  1 │ BASELINE         │ Analyze current version                 │
│  2 │ METRICS          │ Collect metrics v(n-1)                  │
│  3 │ PAS ANALYZE      │ Research scientific papers              │
│  4 │ TECH TREE        │ Build technology tree                   │
│  5 │ SPEC CREATE      │ Create .vibee specifications            │
│  6 │ CODE GENERATE    │ Generate .zig from .vibee               │
│  7 │ TEST RUN         │ Run all tests                           │
│  8 │ BENCHMARK PREV   │ ⚡ COMPARE with v(n-1) [CRITICAL]       │
│  9 │ BENCHMARK THEORY │ Compare with theoretical max            │
│ 10 │ DELTA REPORT     │ Report v(n) - v(n-1)                    │
│ 11 │ OPTIMIZE         │ Optimize based on results               │
│ 12 │ DOCS             │ Documentation with proofs               │
│ 13 │ GIT              │ Commit with changelog                   │
│ 14 │ TOXIC VERDICT    │ 🔥 HARSH SELF-CRITICISM                 │
│ 15 │ TECH TREE SELECT │ 🌳 Choose next research                 │
│ 16 │ LOOP/EXIT        │ Decision: v(n+1) or EXIT                │
└────┴──────────────────┴─────────────────────────────────────────┘
```

---

## 🔥 LINK 14: TOXIC VERDICT

After each iteration - **MANDATORY** write harsh self-criticism:

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
║ - Before: X tok/s | After: Y tok/s | Δ = Z%                      ║
║                                                                  ║
║ SELF-CRITICISM:                                                  ║
║ - [harsh analysis without rose-colored glasses]                  ║
║ - [what could have been done better]                             ║
║                                                                  ║
║ SCORE: [1-10]/10                                                 ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 🌳 LINK 15: TECH TREE SELECT

After self-criticism - propose 3 options from Tech Tree for next iteration:

```
┌─────────────────────────────────────────────────────────────────┐
│              🌳 TECH TREE - SELECT NEXT                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Current branch: [name]                                         │
│                                                                 │
│  OPTIONS FOR NEXT RESEARCH:                                     │
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

## 🔥 MINIMAL CYCLE

For EVERY task execute at minimum these links:

```bash
# [5] SPEC CREATE
cat > specs/tri/feature.vibee << 'EOF'
name: feature
version: "1.0.0"
language: zig
module: feature

types:
  MyType:
    fields:
      name: String

behaviors:
  - name: my_func
    given: Input
    when: Action
    then: Result
EOF

# [6] CODE GENERATE
./bin/vibee gen specs/tri/feature.vibee

# [7] TEST RUN
zig test trinity/output/feature.zig

# [14] TOXIC VERDICT
# Write harsh self-criticism!

# [15] TECH TREE SELECT
# Propose 3 options for next research!

# [16] LOOP/EXIT
# Tests passed? → EXIT or new iteration
# Tests failed? → Return to [5]
```

---

## ⛔ FORBIDDEN

### NEVER create manually:

| Forbidden | Reason |
|-----------|--------|
| `*.html` | Legacy |
| `*.css` | Legacy |
| `*.js` | Legacy |
| `*.ts` | Legacy |
| `*.zig` in `trinity/output/` | Auto-generated! |

### ALLOWED to edit:

| Allowed | Description |
|---------|-------------|
| `specs/tri/*.vibee` | Specifications |
| `src/vibeec/*.zig` | Compiler |
| `docs/*.md` | Documentation |

---

## 📝 .vibee FORMAT

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int
      field3: Bool
      field4: Float
      field5: List<String>
      field6: Option<Int>

behaviors:
  - name: function_name
    given: Precondition description
    when: Action description
    then: Expected result
```

---

## 🔧 COMMANDS

```bash
# EXECUTION (ONLY VM - NO INTERPRETER!)
./bin/vibee run <file.999>   # Run via bytecode VM (5x faster!)

# GOLDEN CHAIN
./bin/vibee koschei          # 16 links (default)
./bin/vibee koschei chain    # Lukomorye architecture
./bin/vibee koschei status   # Status from Learned Cat

# GENERATION
./bin/vibee gen <spec.vibee>                    # Zig
./bin/vibee gen-multi <spec.vibee> all           # 42 languages

# TESTING
zig test trinity/output/<module>.zig
```

---

## ⚡ EXECUTION MODEL

**ONLY BYTECODE VM!** Tree-walking interpreter is DEPRECATED.

```
.999 SOURCE → PARSER → AST → BYTECODE COMPILER → VM EXECUTION
```

**Why VM only:**
- 5-6x faster than interpreter
- Proper stack-based execution
- Native functions (print, len, range, etc.)
- Foundation for JIT compilation

**NEVER use coptic_interpreter.zig directly!**

---

## 📁 STRUCTURE

```
vibee-lang/
├── specs/tri/          # .vibee (SOURCE)
├── trinity/output/     # .zig (DO NOT EDIT!)
├── src/vibeec/         # Compiler
├── bin/vibee           # CLI
└── docs/               # Documentation
```

---

## 🏆 EXIT_SIGNAL

Complete work when:

```
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
