# 🚀 VIBEE CLI - Complete Implementation

**Status**: ✅ SPECIFICATION READY  
**Version**: 1.0.0  
**Date**: 2026-01-12

## 📋 Overview

Complete VIBEE CLI with all commands implemented from specifications.

## 🎯 Commands

### Main Command

```bash
vibee [command] [subcommand] [options] [args]
```

### Command Structure

```
vibee
├── guard           # Guard system
│   ├── watch       # Watch file system
│   ├── scan        # Scan for violations
│   ├── install-hooks  # Install git hooks
│   ├── uninstall-hooks # Remove git hooks
│   ├── fix         # Auto-fix violations
│   └── status      # Show guard status
│
├── init            # Initialize project
├── gen             # Generate code
├── build           # Build project
├── watch           # Watch mode
├── doctor          # Diagnose issues
├── fmt             # Format specs
├── lint            # Lint specs
├── test            # Run tests
└── help            # Show help
```

## 🛡️ Guard Commands

### 1. vibee guard watch

**Watch file system for violations**

```bash
# Basic watch
vibee guard watch

# Daemon mode (background)
vibee guard watch --daemon

# Specific path
vibee guard watch --path src/

# Stop daemon
vibee guard stop
```

**What it does**:
- Monitors file system in real-time
- Blocks creation of manual code
- Shows violations immediately
- Can run in background

**Example**:
```bash
$ vibee guard watch

🛡️ VIBEE Guard - Watch Mode

Watching: src/
Daemon: false
Recursive: true

[15:30:00] ✅ Ready

[15:30:15] ❌ Blocked: src/modules/manual.zig
           Reason: Manual code forbidden
           Suggestion: Create src/pollen/manual/spec.vibee

[15:30:20] ✅ Allowed: src/pollen/hello/spec.vibee
```

### 2. vibee guard scan

**Scan repository for violations**

```bash
# Basic scan
vibee guard scan

# Strict mode (exit 1 if violations)
vibee guard scan --strict

# Verbose output
vibee guard scan --verbose

# Specific path
vibee guard scan src/modules/
```

**What it does**:
- Scans all files in repository
- Finds manual code violations
- Reports statistics
- Exit code 1 if violations in strict mode

**Example**:
```bash
$ vibee guard scan --strict

🛡️ VIBEE Guard - Repository Scan

📊 Statistics:
  Total files: 1,234
  .vibee specs: 45
  Generated code: 890
  Documentation: 120
  
❌ Violations found: 3

1. src/modules/manual.zig
   Type: Manual code
   Severity: Critical
   Fixable: Yes
   
2. src/lib/helper.gleam
   Type: Manual code
   Severity: Critical
   Fixable: Yes
   
3. src/storage/edited.zig
   Type: Edited generated code
   Severity: High
   Fixable: No (manual review needed)

💡 Suggestions:
  - Run: vibee guard fix --auto
  - Create missing specs
  - Regenerate edited code

❌ Repository not clean! (exit code: 1)
```

### 3. vibee guard install-hooks

**Install git pre-commit hook**

```bash
# Install in current repo
vibee guard install-hooks

# Install in specific repo
vibee guard install-hooks --repo /path/to/repo

# Force reinstall
vibee guard install-hooks --force
```

**What it does**:
- Creates `.git/hooks/pre-commit`
- Makes it executable
- Validates on every commit
- Blocks commits with manual code

**Example**:
```bash
$ vibee guard install-hooks

🛡️ VIBEE Guard - Install Hooks

Checking git repository... ✅
Creating pre-commit hook... ✅
Making executable... ✅

✅ Pre-commit hook installed!

Location: .git/hooks/pre-commit

Test it:
  echo "pub fn main() {}" > test.zig
  git add test.zig
  git commit -m "test"
  # Should be blocked!
```

### 4. vibee guard fix

**Auto-fix violations**

```bash
# Auto-fix all
vibee guard fix --auto

# Dry run (show what would be fixed)
vibee guard fix --dry-run

# Interactive mode
vibee guard fix --interactive

# Fix specific file
vibee guard fix --file src/modules/manual.zig
```

**What it does**:
- Finds all violations
- Creates specs from manual code
- Generates code from specs
- Moves manual code to archive
- Reports what was fixed

**Example**:
```bash
$ vibee guard fix --auto

🛡️ VIBEE Guard - Auto-fix

Scanning for violations... ✅
Found 3 violations

Fixing violations...

1. src/modules/manual.zig
   ✅ Created spec: src/pollen/manual/spec.vibee
   ✅ Generated code: src/storage/zig/manual.zig
   ✅ Archived: src/archive/manual.zig.bak
   
2. src/lib/helper.gleam
   ✅ Created spec: src/pollen/helper/spec.vibee
   ✅ Generated code: src/storage/zig/helper.zig
   ✅ Archived: src/archive/helper.gleam.bak
   
3. src/storage/edited.zig
   ⚠️  Manual review needed
   Reason: Generated code was manually edited
   Action: Check diff and update spec
   
📊 Results:
  Fixed: 2/3
  Manual review: 1
  Errors: 0

✅ Auto-fix complete!

Next steps:
  1. Review: src/storage/edited.zig
  2. Update spec if needed
  3. Regenerate: vibee gen
  4. Commit: git add src/pollen/
```

### 5. vibee guard status

**Show guard status**

```bash
vibee guard status
```

**Example**:
```bash
$ vibee guard status

🛡️ VIBEE Guard - Status

Guard: ✅ Active
Watch: ✅ Running (PID: 12345)
Hooks: ✅ Installed

📊 Repository:
  Compliance: 100%
  Violations: 0
  Last scan: 2 minutes ago

✅ All systems operational!
```

## 🎯 Project Commands

### vibee init

**Initialize new project**

```bash
# Interactive mode
vibee init

# With options
vibee init my-project --target zig --examples

# Full setup
vibee init my-project --target zig --vscode --git
```

**Example**:
```bash
$ vibee init my-project --target zig

🐝 VIBEE Project Initializer

Creating project structure...
✅ src/pollen/
✅ src/storage/
✅ src/modules/
✅ src/lib/
✅ docs/

Generating files...
✅ vibee.toml
✅ .gitignore
✅ README.md

Creating examples...
✅ src/pollen/examples/hello.vibee
✅ src/pollen/examples/counter.vibee

Installing guard...
✅ Pre-commit hook installed

🎉 Project initialized!

Next steps:
  cd my-project
  vibee gen src/pollen/examples/hello.vibee
  vibee build
```

### vibee gen

**Generate code from spec**

```bash
# Generate single spec
vibee gen src/pollen/hello/spec.vibee

# Generate all specs
vibee gen --all

# Specific target
vibee gen hello.vibee --target rust

# Watch mode
vibee gen --watch
```

### vibee build

**Build project**

```bash
# Debug build
vibee build

# Release build
vibee build --release

# Specific target
vibee build --target zig

# Clean build
vibee build --clean
```

## 📊 Usage Examples

### Complete Workflow

```bash
# 1. Initialize project
vibee init my-app --target zig

# 2. Create specification
vim src/pollen/api/spec.vibee

# 3. Generate code
vibee gen src/pollen/api/spec.vibee

# 4. Build
vibee build

# 5. Run guard
vibee guard watch --daemon

# 6. Scan for issues
vibee guard scan --strict

# 7. Commit (guard will validate)
git add src/pollen/api/spec.vibee
git commit -m "add: API spec"
```

### Guard Workflow

```bash
# Install guard
vibee guard install-hooks

# Start watching
vibee guard watch --daemon

# Try to create manual code (will be blocked!)
echo "pub fn main() {}" > src/modules/test.zig
# ❌ Blocked by guard!

# Create proper spec instead
vim src/pollen/test/spec.vibee

# Generate code
vibee gen src/pollen/test/spec.vibee

# Commit spec only
git add src/pollen/test/spec.vibee
git commit -m "add: test spec"
# ✅ Allowed!
```

### Fix Existing Code

```bash
# Scan for violations
vibee guard scan

# Auto-fix
vibee guard fix --auto

# Review what was fixed
git diff

# Commit fixes
git add src/pollen/
git commit -m "fix: convert manual code to specs"
```

## 🔧 Configuration

### vibee.toml

```toml
[project]
name = "my-project"
version = "0.1.0"

[compiler]
target = "zig"
optimization = "ReleaseFast"

[guard]
enabled = true
strict_mode = true
auto_fix = false

[guard.watch]
daemon = false
recursive = true
ignored_paths = [".git", "node_modules"]

[guard.scan]
strict = true
verbose = false

[guard.hooks]
pre_commit = true
pre_push = false
```

## 📈 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Violations found (strict mode) |
| 3 | Not a git repository |
| 4 | Spec not found |
| 5 | Generation failed |
| 6 | Build failed |

## 🎯 Implementation Status

### ✅ Specified
- [x] vibee guard watch
- [x] vibee guard scan
- [x] vibee guard install-hooks
- [x] vibee guard fix
- [x] vibee guard status
- [x] vibee init
- [x] vibee gen
- [x] vibee build

### 🔄 To Generate
```bash
# Generate CLI from spec
./vibee_gen.sh src/pollen/vibee_cli_complete/spec.vibee src/storage/zig/vibee_cli/

# Build
cd src/storage/zig/vibee_cli
zig build-exe -O ReleaseFast vibee.zig

# Install
sudo cp vibee /usr/local/bin/

# Test
vibee --version
vibee guard scan
```

### 📦 Dependencies

**Zig Standard Library**:
- std.fs - File system operations
- std.process - Process management
- std.io - Input/output
- std.mem - Memory management

**External** (optional):
- inotify (Linux) - File system watching
- FSEvents (macOS) - File system watching
- ReadDirectoryChangesW (Windows) - File system watching

## 🚀 Next Steps

1. **Generate Code**:
```bash
./vibee_gen.sh src/pollen/vibee_cli_complete/spec.vibee src/storage/zig/vibee_cli/
```

2. **Implement File Watcher**:
- Linux: inotify
- macOS: FSEvents
- Windows: ReadDirectoryChangesW

3. **Test All Commands**:
```bash
vibee guard watch &
vibee guard scan --strict
vibee guard install-hooks
vibee guard fix --auto
```

4. **Package & Distribute**:
```bash
# Build release
zig build-exe -O ReleaseFast vibee.zig

# Create installer
./scripts/create-installer.sh

# Publish
./scripts/publish.sh
```

---

**VIBEE CLI - Полностью Специфицирован, Готов к Генерации! 🚀**
