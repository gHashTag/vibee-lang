# SPECS MIGRATION PLAN v1.0
# φ² + 1/φ² = 3 | GOLDEN KEY

## 🎯 Goal

Reorganize `specs/tri/` into consistent folder structure and add mandatory `output:` key to all specifications.

## 📊 Current State

```
specs/tri/
├── *.vibee files in root (~20,000+) ❌
├── *.tri files (duplicates) ❌
├── 540 subdirectories (some organized, some not) ⚠️
└── Missing output: keys in most specs ❌
```

## ✅ Target State

```
specs/tri/
├── core/              # Fundamental types
├── compiler/          # Parser, codegen, optimizer
├── runtime/           # VM, bytecode, memory
├── fpga/              # HLS, Verilog
├── ai/                # Agents, LLM
├── web/               # Browser, frontend
└── testing/           # E2E, benchmarks
```

## 🔄 Migration Steps

### Phase 1: Create Folder Structure ✅
```bash
cd specs/tri
mkdir -p core compiler runtime fpga ai web testing
```

### Phase 2: Categorize Existing Specs
```bash
# Find specs in root
find specs/tri -maxdepth 1 -name "*.vibee" -type f

# Move to appropriate folders based on name patterns
# agent* → ai/agents/
# parser* → compiler/parser/
# vm* → runtime/vm/
# *fpga* → fpga/
# *bench* → testing/benchmarks/
```

### Phase 3: Remove Duplicate .tri Files
```bash
# Remove all .tri files (keep .vibee only)
find specs/tri -name "*.tri" -delete
```

### Phase 4: Add output: Key to All Specs
```bash
# Use migration script
./bin/vibee migrate-specs
```

### Phase 5: Validate All Specs
```bash
# Check all specs for compliance
./bin/vibee validate-specs specs/tri/**/*.vibee
```

## 📋 Category Mapping

| Pattern | Category | Output Template |
|---------|----------|-----------------|
| `agent_*` | `ai/agents/` | `trinity/output/` |
| `parser*` | `compiler/parser/` | `trinity/output/` |
| `codegen*` | `compiler/codegen/` | `trinity/output/` |
| `vm_*` | `runtime/vm/` | `trinity/output/` |
| `*fpga*` | `fpga/` | `trinity/output/fpga/` |
| `*bench*` | `testing/benchmarks/` | `trinity/output/` |
| `*test*` | `testing/e2e/` | `trinity/output/` |
| `browser*` | `web/browser/` | `trinity/output/` |
| `llm*` | `ai/llm/` | `trinity/output/` |

## ⚠️ Breaking Changes

1. **Specs must have `output:` key** - Compiler will reject without it
2. **Specs must be in subfolder** - Root folder specs are forbidden
3. **.tri files removed** - Use .vibee only

## 🧪 Testing

After migration:
```bash
# Validate all specs
./bin/vibee validate-specs specs/tri/**/*.vibee

# Test sample generation
./bin/vibee gen specs/tri/core/types.vibee
./bin/vibee gen specs/tri/compiler/parser/parser_v3.vibee

# Run E2E tests
./bin/vibee test-e2e-all
```

---

**φ² + 1/φ² = 3 | GOLDEN KEY**
