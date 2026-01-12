# VIBEEC Command Line Interface

## Synopsis

```
vibeec <command> [options] [arguments]
```

## Commands

### generate (gen)

Generate code from a specification file.

```bash
vibeec gen <spec.vibee> [--output <dir>]
```

**Arguments:**
- `<spec.vibee>` - Path to the specification file

**Options:**
- `--output <dir>` - Output directory (default: current directory)

**Examples:**
```bash
vibeec gen specs/user.vibee
vibeec gen specs/user.vibee --output src/generated/
```

### check

Validate a specification file without generating code.

```bash
vibeec check <spec.vibee>
```

**Output:**
```
Valid spec: user_service v1.0.0
  Module: services/user
  Language: zig
  Behaviors: 3
  Types: 2
  Functions: 3
```

### version

Display compiler version.

```bash
vibeec version
```

**Output:**
```
vibeec 1.0.0
```

### help

Display help information.

```bash
vibeec help
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | File not found |
| 3 | Parse error |
| 4 | Code generation error |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `VIBEEC_OUTPUT` | Default output directory |
| `VIBEEC_VERBOSE` | Enable verbose output (1/0) |

## Generated Code Structure

For a specification `user.vibee`, the compiler generates:

```
user.zig
├── Header comment (source, version, module)
├── Imports
├── Type definitions
├── Function stubs with documentation
└── Test cases for each behavior
```

## Example Workflow

```bash
# 1. Create specification
cat > user.vibee << 'EOF'
name: user
version: "1.0.0"
language: zig
module: user

behaviors:
  - name: create_user
    given: Valid user data
    when: create_user called
    then: User created
EOF

# 2. Validate
vibeec check user.vibee

# 3. Generate
vibeec gen user.vibee --output src/

# 4. Test
zig test src/user.zig
```
