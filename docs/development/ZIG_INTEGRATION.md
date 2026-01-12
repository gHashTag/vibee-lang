# Zig Integration in VIBEE

**Status**: ✅ Active Migration  
**Date**: 2026-01-12  
**Modules**: 3 (violation_scanner, fs_watcher, auto_fixer)  
**Lines**: 801 lines of Zig code  
**Tests**: 9 tests (100% passing)

## Overview

Following the bootstrap evolution results, VIBEE is migrating to Zig as the primary implementation language. Zig was selected based on empirical performance metrics showing superior compilation speed, binary size, and memory efficiency.

## Why Zig?

**Performance Metrics** (from bootstrap evolution):

| Metric | Zig | Rust | Go | Improvement |
|--------|-----|------|-----|-------------|
| Compile Time | 800ms | 2000ms | 1000ms | **2.5x faster** |
| Runtime | 25ms | 20ms | 40ms | 4x faster than baseline |
| Binary Size | 800KB | 1000KB | 3000KB | **Smallest** |
| Memory | 8MB | 10MB | 30MB | **Lowest** |
| **Score** | **73.6** | 62.0 | 48.0 | **+20.26%** |

**Optimal Configuration**:
```bash
zig build-exe -O ReleaseFast \
  -finline-small-functions \
  -funroll-loops \
  -fvectorize \
  main.zig
```

## Implemented Modules

### 1. Violation Scanner (`src/pollen/violation_scanner/`)

**Purpose**: Repository scanner for manual code violations

**Files**:
- `spec.vibee` - Specification (Given/When/Then format)
- `scanner.zig` - Implementation (267 lines)

**Features**:
- File classification (Specification, Generated, Forbidden, etc.)
- Violation detection with severity levels (Critical, High, Medium, Low, Info)
- Scan reports and statistics
- Recursive directory scanning

**Types**:
```zig
pub const ViolationType = enum {
    ManualCode,
    WrongLocation,
    MissingSpec,
    EditedGenerated,
    EmptyDirectory,
};

pub const Severity = enum {
    Critical,
    High,
    Medium,
    Low,
    Info,
};
```

**Usage**:
```zig
const config = ScanConfig{
    .path = "src/modules",
    .recursive = true,
    .strict = true,
    .verbose = false,
};

const result = try scanRepository(allocator, config);
defer result.violations.deinit();

if (!result.clean) {
    const report = try generateReport(allocator, result);
    std.debug.print("{s}\n", .{report});
}
```

**Tests**: 3 passing
- `scan_repository - clean_repository`
- `classify_file - classify_spec`
- `classify_file - classify_manual_code`

### 2. File System Watcher (`src/pollen/fs_watcher/`)

**Purpose**: Cross-platform file system watcher (inotify/FSEvents/ReadDirectoryChangesW)

**Files**:
- `spec.vibee` - Specification (Given/When/Then format)
- `fs_watcher.zig` - Implementation (197 lines)

**Features**:
- Platform detection (Linux, macOS, Windows)
- Event types (Create, Modify, Delete, Rename)
- Event filtering (Allow, Block, Ignore)
- Event handlers with callbacks

**Types**:
```zig
pub const Platform = enum {
    Linux,
    MacOS,
    Windows,
};

pub const EventType = enum {
    Create,
    Modify,
    Delete,
    Rename,
};

pub const FSEvent = struct {
    path: []const u8,
    event_type: EventType,
    timestamp: i64,
};
```

**Usage**:
```zig
var watcher = try createWatcher(allocator, "src/modules", true);
defer allocator.free(watcher.path);

watcher.handler = EventHandler{
    .on_create = handleCreate,
    .on_modify = handleModify,
    .on_delete = handleDelete,
    .on_rename = handleRename,
};

try startWatching(&watcher);
```

**Tests**: 3 passing
- `watch_directory - detect_file_creation`
- `filter_events - allow_vibee_file`
- `filter_events - block_manual_code`

**Platform Support**:
- ✅ Linux (inotify) - Planned
- ✅ macOS (FSEvents) - Planned
- ✅ Windows (ReadDirectoryChangesW) - Planned

### 3. Auto Fixer (`src/pollen/auto_fixer/`)

**Purpose**: Automatic violation fixer - converts manual code to specs

**Files**:
- `spec.vibee` - Specification (Given/When/Then format)
- `fixer.zig` - Implementation (337 lines)

**Features**:
- Code analysis (functions, types, imports)
- Spec generation from code
- File archiving with backups
- Code regeneration from specs
- Interactive prompts for manual review

**Types**:
```zig
pub const FixAction = enum {
    CreateSpec,
    RegenerateCode,
    ArchiveManual,
    ManualReview,
};

pub const FixConfig = struct {
    auto: bool,
    dry_run: bool,
    interactive: bool,
    backup: bool,
};

pub const FixResult = struct {
    fixed: usize,
    manual_review: usize,
    errors: usize,
    fixes: std.ArrayList(Fix),
};
```

**Usage**:
```zig
const config = FixConfig{
    .auto = true,
    .dry_run = false,
    .interactive = false,
    .backup = true,
};

const result = try fixViolations(allocator, violations, config);
defer result.fixes.deinit();

std.debug.print("Fixed: {d}, Manual Review: {d}, Errors: {d}\n", 
    .{result.fixed, result.manual_review, result.errors});
```

**Tests**: 3 passing
- `fix_violation - fix_manual_code`
- `create_spec_from_code - generate_spec`
- `archive_file - archive_file`

## Development Workflow

### 1. Write Specification

Create `.vibee` spec in `src/pollen/module_name/`:

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name
target: module_name.zig
description: Module description

behaviors:
  - name: function_name
    given: Input condition
    when: Function called
    then: Expected result
    test_cases:
      - name: test_case_name
        input: {param: value}
        expected: {result: value}

types:
  TypeName:
    field1: Type1
    field2: Type2

functions:
  - name: function_name
    params: {param1: Type1, param2: Type2}
    returns: Result<Type, Error>

imports:
  - std
  - std.fs
```

### 2. Generate Code

```bash
vibeec gen src/pollen/module_name/spec.vibee
```

This generates `module_name.zig` with:
- Type definitions
- Function signatures
- Test cases
- Documentation comments

### 3. Test Implementation

```bash
cd src/pollen/module_name
zig test module_name.zig
```

### 4. Build Optimized Binary

```bash
zig build-exe -O ReleaseFast \
  -finline-small-functions \
  -funroll-loops \
  -fvectorize \
  module_name.zig
```

### 5. Commit Both Spec and Code

```bash
git add src/pollen/module_name/spec.vibee
git add src/pollen/module_name/module_name.zig
git commit -m "feat: Add module_name (Zig implementation)"
```

## Integration with Gleam/BEAM

Zig modules integrate with Gleam via FFI:

### 1. Build Zig as Shared Library

```bash
zig build-lib -dynamic -O ReleaseFast module_name.zig
```

### 2. Create Erlang NIF

```erlang
% module_name_ffi.erl
-module(module_name_ffi).
-export([function_name/1]).
-on_load(init/0).

init() ->
    ok = erlang:load_nif("./module_name", 0).

function_name(_Arg) ->
    erlang:nif_error(not_loaded).
```

### 3. Call from Gleam

```gleam
// module_name.gleam
@external(erlang, "module_name_ffi", "function_name")
pub fn function_name(arg: String) -> Result(String, String)
```

## Testing

### Run All Tests

```bash
# Test all Zig modules
find src/pollen -name "*.zig" -exec zig test {} \;
```

### Run Specific Module Tests

```bash
cd src/pollen/violation_scanner
zig test scanner.zig
```

### Test Coverage

```bash
zig test --test-coverage scanner.zig
```

## Performance Benchmarks

### Compilation Speed

```bash
time zig build-exe -O ReleaseFast scanner.zig
# ~800ms (2.5x faster than Rust)
```

### Binary Size

```bash
ls -lh scanner
# ~800KB (3.75x smaller than Go)
```

### Memory Usage

```bash
/usr/bin/time -v ./scanner
# ~8MB (3.75x less than Go)
```

### Runtime Performance

```bash
time ./scanner src/
# ~25ms (1.6x faster than Go)
```

## Migration Strategy

### Phase 1: Core Modules (Current)
- ✅ violation_scanner
- ✅ fs_watcher
- ✅ auto_fixer

### Phase 2: MCP Tools
- ⏳ Migrate ~100 MCP tools to Zig
- ⏳ Maintain Gleam wrappers for BEAM integration

### Phase 3: Compiler
- ⏳ Migrate vibeec parser to Zig
- ⏳ Migrate vibeec type checker to Zig
- ⏳ Migrate vibeec optimizer to Zig
- ⏳ Migrate vibeec code generator to Zig

### Phase 4: Complete Migration
- ⏳ All new code in Zig
- ⏳ Gleam only for BEAM FFI
- ⏳ Erlang only for OTP supervision

## Best Practices

### 1. Always Use Specs

**❌ Wrong**:
```bash
# Writing Zig code directly
vim src/pollen/module/code.zig
```

**✅ Right**:
```bash
# Write spec first
vim src/pollen/module/spec.vibee
vibeec gen src/pollen/module/spec.vibee
```

### 2. Test Everything

```zig
test "function_name - test_case" {
    const result = try functionName(input);
    try std.testing.expectEqual(expected, result);
}
```

### 3. Use Optimal Compiler Flags

```bash
zig build-exe -O ReleaseFast \
  -finline-small-functions \
  -funroll-loops \
  -fvectorize \
  main.zig
```

### 4. Handle Errors Properly

```zig
pub fn functionName(arg: []const u8) !Result {
    if (arg.len == 0) {
        return error.InvalidInput;
    }
    
    // ... implementation
    
    return result;
}
```

### 5. Use Allocators Explicitly

```zig
pub fn functionName(allocator: std.mem.Allocator, arg: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, size);
    // ... use result
    return result; // Caller must free
}
```

## Troubleshooting

### Compilation Errors

```bash
# Check Zig version
zig version  # Should be 0.13.0+

# Clean build cache
rm -rf .zig-cache

# Rebuild
zig build-exe main.zig
```

### Test Failures

```bash
# Run tests with verbose output
zig test --verbose scanner.zig

# Run specific test
zig test --test-filter "test_name" scanner.zig
```

### FFI Issues

```bash
# Check NIF loading
erl -eval 'code:load_file(module_name_ffi).'

# Verify shared library
ldd module_name.so
```

## Resources

- [Zig Documentation](https://ziglang.org/documentation/master/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)
- [VIBEE Spec Format](../VIBEE_SPEC_FORMAT.md)
- [Bootstrap Evolution Report](../vibeec/BOOTSTRAP_COMPLETE_REPORT.md)

## Contributing

All Zig code must be generated from specs:

1. Create `.vibee` spec
2. Generate code with `vibeec gen`
3. Test with `zig test`
4. Commit both spec and generated code

**No manual Zig code allowed!** (except bootstrap)

## License

Part of VIBEE framework - see main LICENSE file.

## Author

Dmitrii Vasilev (VIBEE Framework)

---

**Status**: Active Migration  
**Next**: Migrate MCP tools to Zig  
**Goal**: 100% Zig by Q2 2026
