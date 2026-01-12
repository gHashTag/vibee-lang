# VIBEE Specification Format

## Overview

VIBEE specifications use YAML syntax with Behavior-Driven Development (BDD) format.

## File Extension

All specification files must use the `.vibee` extension.

## Structure

```yaml
# Required metadata
name: module_name
version: "1.0.0"
language: zig          # Target language: zig, gleam, rust, go
module: path/to/module

# Optional metadata
description: Module description

# Behavioral specifications (Given/When/Then)
behaviors:
  - name: behavior_name
    given: Precondition description
    when: Action description
    then: Expected outcome
    test_cases:
      - name: test_case_name
        input: {param1: value1}
        expected: {result: value}

# Type definitions
types:
  TypeName:
    field1: type1
    field2: type2

# Function signatures
functions:
  - name: function_name
    params: {param1: type1, param2: type2}
    returns: ReturnType

# Dependencies
imports:
  - std
  - other_module
```

## Behaviors (Required)

Each behavior follows the Given/When/Then pattern:

| Field | Description |
|-------|-------------|
| `name` | Unique identifier for the behavior |
| `given` | Precondition or initial state |
| `when` | Action or trigger |
| `then` | Expected outcome or postcondition |
| `test_cases` | Optional list of concrete test cases |

### Example

```yaml
behaviors:
  - name: create_user
    given: Valid user data is provided
    when: create_user function is called
    then: User is created and returned with ID
    test_cases:
      - name: valid_user
        input: {name: "Alice", age: 30}
        expected: {id: 1, name: "Alice", age: 30}
      - name: invalid_age
        input: {name: "Bob", age: -1}
        expected: {error: "invalid_age"}
```

## Types

Define custom types with their fields:

```yaml
types:
  User:
    id: int
    name: str
    age: int
    email: str?      # Optional field (nullable)
  
  Result:
    success: bool
    data: User?
    error: str?
```

### Supported Base Types

| Type | Description |
|------|-------------|
| `int` | Integer (i32/i64) |
| `float` | Floating point (f64) |
| `str` | String |
| `bool` | Boolean |
| `void` | No return value |
| `Type?` | Optional/nullable type |
| `[Type]` | List/array of type |
| `{K: V}` | Map/dictionary |

## Functions

Define function signatures:

```yaml
functions:
  - name: create_user
    params: {name: str, age: int}
    returns: Result<User, Error>
  
  - name: get_user
    params: {id: int}
    returns: User?
  
  - name: delete_user
    params: {id: int}
    returns: bool
```

## Complete Example

```yaml
name: user_service
version: "1.0.0"
language: zig
module: services/user
description: User management service

behaviors:
  - name: create_user
    given: Valid user data with name and age
    when: create_user is called
    then: New user is created with unique ID
    test_cases:
      - name: create_valid_user
        input: {name: "Alice", age: 30}
        expected: {created: true}

  - name: get_user_by_id
    given: User exists in database
    when: get_user is called with valid ID
    then: User data is returned

  - name: handle_invalid_id
    given: No user with given ID exists
    when: get_user is called with invalid ID
    then: None is returned

types:
  User:
    id: int
    name: str
    age: int
    created_at: int

  CreateUserRequest:
    name: str
    age: int

functions:
  - name: create_user
    params: {request: CreateUserRequest}
    returns: Result<User, str>

  - name: get_user
    params: {id: int}
    returns: User?

  - name: delete_user
    params: {id: int}
    returns: bool

imports:
  - std
  - std.time
```

## Validation Rules

1. `name` must be a valid identifier (alphanumeric + underscore)
2. `version` must follow semantic versioning
3. `language` must be one of: `zig`, `gleam`, `rust`, `go`
4. All behaviors must have `given`, `when`, `then` fields
5. Type names must start with uppercase letter
6. Function names must start with lowercase letter

## Best Practices

1. **One behavior per function** - Each behavior should map to one function
2. **Descriptive names** - Use clear, descriptive names for behaviors
3. **Complete test cases** - Include both success and error cases
4. **Document edge cases** - Use behaviors to document edge cases
5. **Keep specs focused** - One module per domain concept
