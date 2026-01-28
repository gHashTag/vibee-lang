# SPECS STRUCTURE v2.0

## 📁 Mandatory Folder Hierarchy

```
specs/tri/
├── core/                    # Fundamental types & behaviors
│   ├── types.vibee
│   ├── behaviors.vibee
│   └── constants.vibee
│
├── compiler/                # VIBEE compiler internals
│   ├── parser/
│   │   ├── lexer.vibee
│   │   └── parser_v3.vibee
│   ├── codegen/
│   │   ├── zig_codegen.vibee
│   │   ├── varlog_codegen.vibee
│   │   └── multi_codegen.vibee
│   ├── optimizer/
│   │   ├── egraph.vibee
│   │   └── inline.vibee
│   └── type_checker.vibee
│
├── runtime/                 # VM and runtime systems
│   ├── vm_trinity.vibee
│   ├── bytecode.vibee
│   ├── memory/
│   │   ├── gc.vibee
│   │   └── memory_pool.vibee
│   └── jit/
│       ├── tier1.vibee
│       └── tier2.vibee
│
├── fpga/                    # Hardware generation
│   ├── hls/
│   │   ├── pipelining.vibee
│   │   └── memory.vibee
│   ├── vendor/
│   │   ├── xilinx.vibee
│   │   ├── intel.vibee
│   │   └── lattice.vibee
│   └── cores/
│       ├── bitnet.vibee
│       └── talu.vibee
│
├── ai/                      # AI & Agents
│   ├── agents/
│   │   ├── orchestration.vibee
│   │   ├── reasoning.vibee
│   │   └── tools.vibee
│   ├── llm/
│   │   ├── providers.vibee
│   │   └── routing.vibee
│   └── memory/
│       ├── vector_store.vibee
│       └── context.vibee
│
├── web/                     # Web & Browser
│   ├── browser/
│   │   ├── cdp.vibee
│   │   ├── puppeteer.vibee
│   │   └── automation.vibee
│   ├── frontend/
│   │   ├── components.vibee
│   │   └── state.vibee
│   └── api/
│       └── handlers.vibee
│
├── testing/                 # Testing & Benchmarks
│   ├── e2e/
│   │   ├── framework.vibee
│   │   └── runner.vibee
│   ├── benchmarks/
│   │   ├── performance.vibee
│   │   └── comparison.vibee
│   └── proofs/
│       └── formal.vibee
│
└── vendor/                  # Third-party integrations
    ├── ffi/
    └── protocols/
```

## 📝 .vibee Specification Format v2.0

### MANDATORY FIELDS:

```yaml
name: module_name
version: "1.0.0"
language: zig|python|rust|go|varlog|typescript|tsx
module: module_name
output: trinity/output/{{module}}.zig  # ← NEW! MANDATORY!

types:
  TypeName:
    fields:
      field_name: Type
      # Optional constraints:
      width: 32      # for varlog (bit width)
      constraint: "x > 0"
      default: value

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
    # Optional:
    benchmarks:
      - name: "Small input"
        input: {size: 10}
        expected_max_ms: 1
      - name: "Large input"
        input: {size: 1000000}
        expected_max_ms: 100
```

### Output Path Templates:

| Language | Output Template |
|----------|----------------|
| `zig` | `trinity/output/{{module}}.zig` |
| `varlog` | `trinity/output/fpga/{{module}}.v` |
| `tsx` | `trinity-os/src/components/{{module}}.tsx` |
| `python` | `generated/python/{{module}}.py` |
| `rust` | `generated/rust/{{module}}.rs` |

## ⛔ FORBIDDEN:

- Creating `.tri` files (use `.vibee` only)
- Specs without `output:` key
- Files in `specs/tri/` root (must be in subfolder)
- Manual creation of files in `trinity/output/`
- Manual creation of files in `trinity-os/src/` (use specs!)

---

**φ² + 1/φ² = 3 | GOLDEN KEY**
