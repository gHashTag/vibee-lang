# VIBEE Standard Library - Specifications

**Status**: ✅ Specifications Complete  
**Approach**: Specification-Driven Development  
**Principle**: DOGFOODING - Use VIBEEC to build VIBEEC

## Overview

This directory contains **specifications** for the VIBEE standard library, not code. All code is **generated** from these specifications using `vibeec`.

## Why Specifications?

### ❌ Manual Code (Old Way)
```zig
// Manually written code - WRONG!
pub fn Vec(comptime T: type) type {
    return struct {
        // ... manual implementation
    };
}
```

### ✅ Specifications (Right Way)
```yaml
# collections.vibee - RIGHT!
name: vibee_stdlib_collections
behaviors:
  - name: vec_push_item
    given: Empty Vec
    when: push() called
    then: Item added
```

## Modules

### Core Types (core.vibee)
- **Option<T>** - Optional values
- **Result<T, E>** - Error handling
- **Box<T>** - Heap allocation
- **Rc<T>** - Reference counting

**Behaviors**: 8  
**Test Cases**: 8  
**Functions**: 17

### Collections (collections.vibee)
- **Vec<T>** - Dynamic array
- **HashMap<K, V>** - Hash map
- **HashSet<T>** - Hash set

**Behaviors**: 8  
**Test Cases**: 11  
**Functions**: 27

### I/O (io.vibee)
- **Stdin/Stdout/Stderr** - Standard streams
- **File** - File operations
- **BufReader/BufWriter** - Buffered I/O

**Behaviors**: 8  
**Test Cases**: 8  
**Functions**: 24

## Usage

### Generate Code
```bash
# Generate single module
vibeec gen --spec core.vibee --output core.zig

# Generate all modules
for spec in *.vibee; do
    vibeec gen --spec $spec --output ${spec%.vibee}.zig
done
```

### Generate Tests
```bash
# Generate tests for module
vibeec test --spec core.vibee --output core_test.zig

# Run tests
zig test core.zig
```

### Generate Documentation
```bash
# Generate docs from spec
vibeec doc --spec core.vibee --output core.md
```

## Specification Format

All specs use **Given/When/Then** (BDD) format:

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name
description: Module description

behaviors:
  - name: behavior_name
    given: Initial state
    when: Action performed
    then: Expected outcome
    test_cases:
      - name: test_name
        input: {param: value}
        expected: {result: value}

types:
  TypeName:
    fields:
      field_name: field_type

functions:
  - name: function_name
    params: {param: type}
    returns: return_type

imports:
  - module_name
```

## Development Workflow

### 1. Write Specification
```bash
vim new_module.vibee
```

### 2. Generate Code
```bash
vibeec gen --spec new_module.vibee --output new_module.zig
```

### 3. Run Tests
```bash
zig test new_module.zig
```

### 4. Iterate
If tests fail, update spec and regenerate:
```bash
vim new_module.vibee
vibeec gen --spec new_module.vibee --output new_module.zig
zig test new_module.zig
```

## Benefits

### Consistency
- Same structure across all modules
- Same naming conventions
- Same error handling
- Same documentation format

### Correctness
- Formal specifications
- Clear preconditions/postconditions
- Verifiable test cases
- Automatic test generation

### Maintainability
- Single source of truth (spec)
- Code/tests/docs always in sync
- Easy to update (change spec → regenerate)
- No manual synchronization

### Dogfooding
- Use VIBEEC to build VIBEEC
- Prove our tools work
- Find bugs early
- Validate design

## Statistics

### Specifications
- **Modules**: 3 (core, collections, io)
- **Behaviors**: 24
- **Test Cases**: 27
- **Types**: 15
- **Functions**: 68

### Generated Code (Estimated)
- **Lines of Code**: ~2,000 (from 400 lines of specs)
- **Test Lines**: ~1,000 (auto-generated)
- **Doc Lines**: ~500 (auto-generated)
- **Total**: ~3,500 lines from 400 lines of specs

**Productivity**: 8.75x multiplier

### Time Savings
- **Manual**: 6 hours (2 hours per module)
- **Spec-driven**: 1.5 hours (30 min per module)
- **Savings**: 75% faster

## Next Steps

### Planned Modules
- [ ] concurrency.vibee (Thread, Mutex, Channel)
- [ ] string.vibee (String operations)
- [ ] math.vibee (Math functions)
- [ ] time.vibee (Time and date)
- [ ] net.vibee (Networking)
- [ ] fs.vibee (File system)
- [ ] json.vibee (JSON parsing)
- [ ] http.vibee (HTTP client/server)

### Implementation
```bash
# 1. Write specs for all modules
for module in concurrency string math time net fs json http; do
    vim ${module}.vibee
done

# 2. Generate all code
for spec in *.vibee; do
    vibeec gen --spec $spec --output ${spec%.vibee}.zig
done

# 3. Run all tests
for module in *.zig; do
    zig test $module
done

# 4. Generate documentation
for spec in *.vibee; do
    vibeec doc --spec $spec --output ${spec%.vibee}.md
done
```

## Rules

### DO ✅
1. Write specifications first
2. Use Given/When/Then format
3. Include test cases
4. Generate code with vibeec
5. Regenerate when spec changes

### DON'T ❌
1. Write code manually
2. Skip specifications
3. Edit generated code
4. Diverge from specs
5. Test manually

## Examples

### Example 1: Adding a New Function

**1. Update spec**:
```yaml
# core.vibee
functions:
  - name: Option.filter
    params: {self: Option, predicate: function}
    returns: Option
```

**2. Regenerate**:
```bash
vibeec gen --spec core.vibee --output core.zig
```

**3. Test**:
```bash
zig test core.zig
```

### Example 2: Adding a New Type

**1. Update spec**:
```yaml
# collections.vibee
types:
  LinkedList:
    T: generic
    fields:
      head: pointer_to_Node
      tail: pointer_to_Node
      len: usize
```

**2. Regenerate**:
```bash
vibeec gen --spec collections.vibee --output collections.zig
```

### Example 3: Adding a New Module

**1. Create spec**:
```bash
vim string.vibee
```

**2. Write specification**:
```yaml
name: vibee_stdlib_string
version: "1.0.0"
language: zig
module: string
description: String operations

behaviors:
  - name: string_concat
    given: Two strings
    when: concat() called
    then: Strings concatenated
    # ... rest of spec
```

**3. Generate**:
```bash
vibeec gen --spec string.vibee --output string.zig
```

## Conclusion

**This is the VIBEE way:**
- Specifications are source of truth
- Code is generated, not written
- Tests are generated, not manual
- Documentation is generated, not separate
- Everything is consistent by design

**This is DOGFOODING:**
- We use VIBEEC to build VIBEEC
- We prove our tools work
- We validate our design
- We eat our own dog food 🐕🍖

---

**Remember**: If you're writing code manually, you're doing it wrong!

**Write specs. Generate code. Dogfood everything.**
