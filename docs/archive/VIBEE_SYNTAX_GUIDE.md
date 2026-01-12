# VIBEE Syntax Guide

**CRITICAL:** This is the CORRECT VIBEE syntax! Not simplified Gleam!

## String Operations

### ❌ WRONG (What I was writing):
```vibee
let result = string.concat([a, b, c])
let lower = string.lowercase(text)
let check = string.starts_with(text, "prefix")
```

### ✅ CORRECT (Real VIBEE):
```vibee
let result = [a, b, c] · string.concat
let lower = text · string.lowercase
let check = string."prefix" · starts_with(text)
```

### String Interpolation

**VIBEE has advanced string interpolation!**

```vibee
// Simple interpolation
let name = "Alice"
let msg = "Hello, {name}!"

// Expression interpolation
let count = 5
let msg = "Found {count + 1} items"

// Method calls in strings
let msg = "User: {user.name · string.uppercase}"
```

## Operators

### Pipe Operator: `·` (middle dot)

```vibee
// Chain operations
result = data
  · list.filter(fn(x) { x > 0 })
  · list.map(fn(x) { x * 2 })
  · list.sum

// Method calls
text · string.lowercase · string.trim
```

### Arrow: `→`

```vibee
// Function types
fn process(x: int) → str

// Case expressions
case value:
  Some(x) → x
  None → 0
```

### Optional/Required: `?` and `!`

```vibee
// Type definitions
type User:
  id: int!           // Required field
  name: str!         // Required field
  email: str?        // Optional field
  phone: str?        // Optional field
```

### Null/None: `∅`

```vibee
// Instead of None
let result = ∅

// Pattern matching
case value:
  ∅ → "empty"
  Some(x) → x
```

## Type Syntax

### Struct Definition

```vibee
struct User:
  id: int!
  name: str!
  email: str?
  created_at: int! = 0  // Default value
```

### Enum Definition

```vibee
@enum
type Status:
  Active
  Inactive
  Pending
```

### Function Types

```vibee
// Simple function
fn greet(name: str) → str:
  "Hello, {name}!"

// With multiple params
fn add(a: int, b: int) → int:
  a + b

// With optional params
fn format(text: str, uppercase: bool? = false) → str:
  case uppercase:
    Some(true) → text · string.uppercase
    _ → text
```

## Pattern Matching

### Case Expressions

```vibee
// Simple case
case status:
  Active → "Running"
  Inactive → "Stopped"
  Pending → "Waiting"

// With guards
case value:
  x if x > 100 → "High"
  x if x > 50 → "Medium"
  _ → "Low"

// Destructuring
case result:
  Ok(value) → value
  Error(msg) → "Failed: {msg}"
```

### String Matching

```vibee
// Prefix matching
case true:
  _ if string."telegram_" · starts_with(name) → CategoryTelegram
  _ if string."github_" · starts_with(name) → CategoryGitHub
  _ → CategoryOther
```

## List Operations

### List Methods

```vibee
// Map
let doubled = numbers · list.map(fn(x) { x * 2 })

// Filter
let positive = numbers · list.filter(fn(x) { x > 0 })

// Fold
let sum = numbers · list.fold(0, fn(acc, x) { acc + x })

// Chain operations
let result = data
  · list.filter(fn(x) { x > 0 })
  · list.map(fn(x) { x * 2 })
  · list.take(10)
```

### List Comprehensions

```vibee
// Simple comprehension
let squares = [x * x | x <- numbers]

// With filter
let even_squares = [x * x | x <- numbers, x % 2 == 0]

// Multiple generators
let pairs = [(x, y) | x <- [1, 2, 3], y <- [4, 5, 6]]
```

## Dict Operations

```vibee
// Create
let dict = dict.new()

// Insert with pipe
let dict = dict
  · dict.insert("key1", value1)
  · dict.insert("key2", value2)

// Get with pipe
let value = dict · dict.get("key1")
```

## Result/Option Handling

### Result

```vibee
// Create results
let success = Ok(value)
let failure = Error("message")

// Pattern matching
case result:
  Ok(v) → "Success: {v}"
  Error(e) → "Error: {e}"

// Chaining
let result = input
  · validate
  · result.map(process)
  · result.unwrap_or(default)
```

### Option

```vibee
// Create options
let some = Some(value)
let none = ∅

// Pattern matching
case option:
  Some(v) → v
  ∅ → default

// Chaining
let result = option
  · option.map(fn(x) { x * 2 })
  · option.unwrap_or(0)
```

## Comments

```vibee
// Single line comment

/* Multi-line
   comment */

/// Documentation comment
/// for functions and types
```

## Annotations

```vibee
@enum
type Status: ...

@struct
type User: ...

@deprecated("Use new_function instead")
fn old_function() → str: ...

@test
fn test_something(): ...
```

## Examples: Before & After

### Example 1: String Operations

**❌ WRONG (What I wrote):**
```vibee
fn format_message(msg: Message) -> str {
  let direction = case msg.is_outgoing {
    True -> "→"
    False -> "←"
  }
  
  direction + " [" + int.to_string(msg.id) + "] " + msg.from_name
}
```

**✅ CORRECT (Real VIBEE):**
```vibee
fn format_message(msg: Message) → str:
  let direction = case msg.is_outgoing:
    true → "→"
    false → "←"
  
  "{direction} [{msg.id}] {msg.from_name}"
```

### Example 2: List Processing

**❌ WRONG:**
```vibee
fn filter_and_map(items: list(int)) -> list(int) {
  items
  |> list.filter(fn(x) { x > 0 })
  |> list.map(fn(x) { x * 2 })
}
```

**✅ CORRECT:**
```vibee
fn filter_and_map(items: list(int)) → list(int):
  items
  · list.filter(fn(x) { x > 0 })
  · list.map(fn(x) { x * 2 })
```

### Example 3: Type Definitions

**❌ WRONG:**
```vibee
type Message {
  id: int
  text: str
  from_id: option(str)
}
```

**✅ CORRECT:**
```vibee
struct Message:
  id: int!
  text: str!
  from_id: str?
```

### Example 4: Pattern Matching

**❌ WRONG:**
```vibee
case dict.get(obj, "key") {
  Ok(value) -> Some(value)
  Error(_) -> None
}
```

**✅ CORRECT:**
```vibee
case obj · dict.get("key"):
  Ok(value) → Some(value)
  Error(_) → ∅
```

## Key Differences from Gleam

| Feature | Gleam | VIBEE |
|---------|-------|-------|
| Pipe | `\|>` | `·` |
| Arrow | `->` | `→` |
| None | `None` | `∅` |
| Required field | `field: Type` | `field: Type!` |
| Optional field | `field: Option(Type)` | `field: Type?` |
| String concat | `<>` | `+` or `"{a}{b}"` |
| Function def | `pub fn name() -> Type` | `fn name() → Type:` |
| Type def | `type Name { ... }` | `struct Name: ...` |
| Enum | `type Name { A B C }` | `@enum type Name: A B C` |
| Method call | `module.func(value)` | `value · module.func` |
| String interp | Not available | `"Hello {name}"` |

## Migration Checklist

When migrating code to VIBEE:

- [ ] Replace `|>` with `·`
- [ ] Replace `->` with `→`
- [ ] Replace `None` with `∅`
- [ ] Replace `Some(x)` with `Some(x)` (same)
- [ ] Replace `"a" <> "b"` with `"a" + "b"` or `"{a}{b}"`
- [ ] Replace `pub fn` with `fn`
- [ ] Replace `type Name { }` with `struct Name:`
- [ ] Add `!` to required fields
- [ ] Add `?` to optional fields
- [ ] Use string interpolation instead of concat
- [ ] Use `·` for method calls
- [ ] Replace `:` with `:` in function bodies (same)
- [ ] Replace `{` `}` with `:` and indentation

## Conclusion

VIBEE syntax is:
- More concise than Gleam
- More expressive (string interpolation)
- More visual (·, →, ∅)
- More type-safe (!, ?)
- More readable (less punctuation)

**Always use VIBEE syntax in plugins, not Gleam!**
