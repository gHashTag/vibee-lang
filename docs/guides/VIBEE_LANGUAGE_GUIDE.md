# VIBEE Language Guide

**Sacred Formula:** `V = n × 3^k × π^m × φ^p × e^q`
**Golden Identity:** `φ² + 1/φ² = 3`

## Overview

VIBEE is a **specification-first** language. You write `.vibee` files that describe WHAT your code should do, and the compiler generates HOW (implementation code).

```
.vibee (specification) → vibee gen → .zig / .py / .rs / ... (42 languages)
```

## Quick Start

```bash
# Generate Zig from specification
vibee gen specs/tri/my_feature.vibee

# Generate for all 42 languages
vibee gen-multi specs/tri/my_feature.vibee all

# Test generated code
zig test trinity/output/my_feature.zig
```

---

## .vibee File Structure

Every `.vibee` file has this structure:

```yaml
# Header
name: feature_name
version: "1.0.0"
language: zig
module: feature_module

# Optional: Sacred constants
sacred_constants:
  phi: 1.618033988749895
  trinity: 3.0

# Types (structs/classes)
types:
  TypeName:
    fields:
      field1: String
      field2: Int

# Behaviors (functions)
behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
```

---

## Types

### Basic Types

| VIBEE Type | Description | Zig | Python | Rust |
|------------|-------------|-----|--------|------|
| `String` | Text | `[]const u8` | `str` | `String` |
| `Int` | Integer | `i64` | `int` | `i64` |
| `Float` | Decimal | `f64` | `float` | `f64` |
| `Bool` | Boolean | `bool` | `bool` | `bool` |
| `Timestamp` | Unix time | `i64` | `int` | `i64` |

### Generic Types

| VIBEE Type | Description | Zig | Python |
|------------|-------------|-----|--------|
| `List<T>` | Array/List | `[]const u8` | `List[T]` |
| `Option<T>` | Nullable | `?T` | `Optional[T]` |
| `Map<K,V>` | Dictionary | `StringHashMap` | `Dict[K,V]` |

### Defining Custom Types

```yaml
types:
  User:
    fields:
      id: Int
      name: String
      email: String
      active: Bool
      created_at: Timestamp

  Config:
    fields:
      host: String
      port: Int
      debug: Bool
      tags: List<String>
      metadata: Option<String>
```

**Generated Zig:**
```zig
pub const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
    active: bool,
    created_at: i64,
};
```

**Generated Python:**
```python
@dataclass
class User:
    id: int
    name: str
    email: str
    active: bool
    created_at: int
```

---

## Behaviors

Behaviors define functions using Given/When/Then pattern:

```yaml
behaviors:
  - name: create_user
    given: Valid user data
    when: Create called
    then: User created successfully

  - name: validate_email
    given: Email string
    when: Validation performed
    then: Returns true if valid format

  - name: calculate_total
    given: List of items with prices
    when: Sum calculated
    then: Returns total price
```

**Generated Zig:**
```zig
/// Given: Valid user data, When: Create called, Then: User created successfully
pub fn create_user() void {
    // TODO: implement
}

/// Given: Email string, When: Validation performed, Then: Returns true if valid format
pub fn validate_email() void {
    // TODO: implement
}
```

---

## Sacred Constants

Include mathematical constants in your spec:

```yaml
sacred_constants:
  phi: 1.618033988749895      # Golden ratio
  trinity: 3.0                 # φ² + 1/φ² = 3
  pi: 3.141592653589793
  e: 2.718281828459045
  phoenix: 999
```

**Generated:**
```zig
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;
```

---

## Creation Pattern

Every spec can define a transformation pattern:

```yaml
creation_pattern:
  source: InputType
  transformer: ProcessName
  result: OutputType
```

This documents the data flow:
```
Source → Transformer → Result
```

---

## Complete Example

```yaml
# specs/tri/user_service.vibee
name: user_service
version: "1.0.0"
language: zig
module: user_service

sacred_constants:
  phi: 1.618033988749895
  max_users: 1000

types:
  User:
    fields:
      id: Int
      name: String
      email: String
      role: String
      active: Bool

  CreateUserRequest:
    fields:
      name: String
      email: String
      role: String

  UserResponse:
    fields:
      success: Bool
      user: Option<User>
      error: Option<String>

creation_pattern:
  source: CreateUserRequest
  transformer: UserService
  result: UserResponse

behaviors:
  - name: create_user
    given: Valid CreateUserRequest
    when: Service processes request
    then: Returns UserResponse with new user

  - name: get_user_by_id
    given: User ID
    when: Lookup performed
    then: Returns User if found

  - name: delete_user
    given: User ID
    when: Delete called
    then: Returns success status

  - name: list_active_users
    given: No parameters
    when: Query executed
    then: Returns list of active users
```

**Generate:**
```bash
vibee gen specs/tri/user_service.vibee
# Output: trinity/output/user_service.zig
```

---

## Reserved Words

These field names are automatically escaped:

| Field Name | Escaped As |
|------------|------------|
| `error` | `@"error"` |
| `type` | `@"type"` |
| `return` | `@"return"` |
| `fn` | `@"fn"` |
| `const` | `@"const"` |

---

## Multi-Language Generation

Generate code for 42 languages:

```bash
# Single language
vibee gen-multi specs/tri/user_service.vibee python
vibee gen-multi specs/tri/user_service.vibee rust
vibee gen-multi specs/tri/user_service.vibee go

# All 42 languages
vibee gen-multi specs/tri/user_service.vibee all
```

**Supported Languages:**
- **Primary:** Zig, Python, Rust, Go, TypeScript, WASM
- **Enterprise:** Java, Kotlin, Swift, C, C#
- **Scripting:** Ruby, PHP, Lua, Perl, R
- **Functional:** Haskell, OCaml, Elixir, Erlang, F#, Scala, Clojure
- **Systems:** D, Nim, Crystal, Julia, Odin, Jai, V
- **Classic:** Ada, Fortran, COBOL, Pascal, Objective-C
- **Lisp:** Racket, Scheme, Common Lisp
- **Logic:** Prolog, Gleam

---

## Best Practices

### 1. Naming Conventions
- Use `snake_case` for names and fields
- Use `PascalCase` for type names
- Be descriptive but concise

### 2. Type Design
- Keep types focused (single responsibility)
- Use `Option<T>` for nullable fields
- Group related fields together

### 3. Behaviors
- One behavior = one function
- Clear Given/When/Then descriptions
- Cover edge cases in descriptions

### 4. Organization
- One feature per `.vibee` file
- Group related specs in directories
- Use version suffixes for iterations

---

## Commands Reference

```bash
# Generate Zig (default)
vibee gen <spec.vibee>

# Generate specific language
vibee gen-multi <spec.vibee> <language>

# Generate all 42 languages
vibee gen-multi <spec.vibee> all

# Test generated code
zig test trinity/output/<module>.zig

# Show help
vibee help

# Sacred constants
vibee phi

# Ternary logic
vibee eval "△ ∧ ○"
```

---

## File Locations

| Path | Purpose |
|------|---------|
| `specs/tri/*.vibee` | Your specifications |
| `trinity/output/*.zig` | Generated Zig (DO NOT EDIT) |
| `generated/multi/*` | Multi-language output |
| `src/vibeec/*.zig` | Compiler source |

---

**φ² + 1/φ² = 3 | PHOENIX = 999 | КОЩЕЙ БЕССМЕРТЕН**
