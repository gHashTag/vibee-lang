// VIBEE Advanced Features - Complete Reference
// 25+ features that make VIBEE superior to Python/TypeScript/Rust

## 1. Pipe Operator |>

**VIBEE** ✅
```vibee
data
  |> validate()
  |> transform()
  |> save()
```

**Python/TypeScript** ❌
```python
save(transform(validate(data)))  # Nested hell
```

**Rule:** Always use pipe for function chains

---

## 2. Pattern Matching with Guards

**VIBEE** ✅
```vibee
case user:
  User(age) if age >= 18 → "Adult"
  User(age) if age >= 13 → "Teen"
  _ → "Child"
```

**TypeScript** ❌
```typescript
if (user.age >= 18) return "Adult";
else if (user.age >= 13) return "Teen";
else return "Child";
```

**Rule:** Use `case` with guards, not if/else chains

---

## 3. List Comprehensions

**VIBEE** ✅
```vibee
[x * 2 for x in numbers if x > 0]
```

**TypeScript** ❌
```typescript
numbers.filter(x => x > 0).map(x => x * 2)
```

**Rule:** Use comprehensions for filter+map

---

## 4. Extension Methods (55+)

**VIBEE** ✅
```vibee
"hello".capitalize()
[1, 2, 3].first()
5.is_even()
```

**Python/TypeScript** ❌
```python
"hello".capitalize()  # Only some
numbers[0] if numbers else None
5 % 2 == 0
```

**Rule:** Use built-in extension methods

---

## 5. Try Operator (use)

**VIBEE** ✅
```vibee
use user <- get_user(id)
use validated <- validate(user)
use saved <- save(validated)
Ok(saved)
```

**TypeScript** ❌
```typescript
const user = await getUser(id);
if (!user) return;
const validated = validate(user);
if (!validated) return;
```

**Rule:** Use `use` for Result chains

---

## 6. Decorators (52 Built-in)

**VIBEE** ✅ (52 decorators)
```vibee
@retry(3)
@timeout(5000)
@cache(ttl: 60)
@llm(model: "gpt-4")
fn process_data(input):
  // ...
```

**Python** (~10 decorators)
```python
@retry(3)  # Manual implementation
def process_data(input):
    pass
```

**Rule:** Use decorators for cross-cutting concerns

**Available decorators:**
- `@retry(n)` - Retry on failure
- `@timeout(ms)` - Timeout
- `@cache(ttl: seconds)` - Cache results
- `@llm(model, temperature)` - LLM call
- `@async` - Async function
- `@deprecated(msg)` - Mark deprecated
- `@test` - Test function
- `@benchmark` - Benchmark
- `@sql(query)` - SQL query
- `@derive(Json, Eq, Ord)` - Auto-derive traits
- ... 42 more

---

## 7. Smart Constructors

**VIBEE** ✅
```vibee
@smart_constructor(validate: validate_email)
type Email: Email(value: str)

// Auto-generated:
new_email("user@example.com")  // Returns Result
```

**TypeScript** ❌
```typescript
class Email {
  constructor(value: string) {
    if (!validateEmail(value)) throw new Error();
    this.value = value;
  }
}
```

**Rule:** Use `@smart_constructor` for validated types

---

## 8. SQL DSL

**VIBEE** ✅
```vibee
@sql "SELECT * FROM users WHERE id = $1"
  with [id] → User
```

**TypeScript** ❌
```typescript
const user = await db.query(
  "SELECT * FROM users WHERE id = $1",
  [id]
);
```

**Rule:** Use `@sql` for type-safe queries

---

## 9. Operator Sections

**VIBEE** ✅
```vibee
list.filter(numbers, (> 5))
list.map(numbers, (* 2))
list.fold(numbers, 0, (+))
```

**Python** ❌
```python
filter(lambda x: x > 5, numbers)
map(lambda x: x * 2, numbers)
```

**Rule:** Use operator sections instead of lambdas

---

## 10. With Statement

**VIBEE** ✅
```vibee
with user <- get_user(id),
     validated <- validate(user),
     saved <- save(validated):
  Ok(saved)
```

**TypeScript** ❌
```typescript
const user = await getUser(id);
const validated = validate(user);
const saved = await save(validated);
```

**Rule:** Use `with` for multiple bindings

---

## 11. Destructuring

**VIBEE** ✅
```vibee
let (a, b, c) = tuple
let [first, ..rest] = list
let User(name, age) = user
```

**Rule:** Always destructure instead of indexing

---

## 12. Optional Chaining

**VIBEE** ✅
```vibee
user?.profile?.name?.length
```

**Python** ❌
```python
if user and user.profile and user.profile.name:
    length = len(user.profile.name)
```

**Rule:** Use `?.` for safe navigation

---

## 13. Guard Clauses

**VIBEE** ✅
```vibee
fn divide(a, b):
  guard b != 0 else: return Error("Division by zero")
  Ok(a / b)
```

**TypeScript** ⚠️
```typescript
if (b === 0) throw new Error();
return a / b;
```

**Rule:** Use `guard` for early returns

---

## 14. Context Managers

**VIBEE** ✅
```vibee
with file <- open("data.txt"):
  read_lines(file)
// Auto-closes
```

**Rule:** Use `with` for resource management

---

## 15. Sigils

**VIBEE** ✅
```vibee
~r/\d+/        // Regex
~s"hello"      // String
~w[a b c]      // Word list
~j{key: "val"} // JSON
```

**Rule:** Use sigils for literals

---

## 16. Range Operator

**VIBEE** ✅
```vibee
1..10          // [1, 2, ..., 10]
1..=10         // Inclusive
'a'..'z'       // Character range
```

**Rule:** Use `..` for ranges

---

## 17. Elvis Operator

**VIBEE** ✅
```vibee
name ?: "Unknown"
value ?: default
```

**Rule:** Use `?:` for default values

---

## 18. Spread Operator

**VIBEE** ✅
```vibee
[1, 2, ..old_list, 5, 6]
{..old_dict, key: "new"}
```

**Rule:** Use `..` for spreading

---

## 19. Type Aliases

**VIBEE** ✅
```vibee
type UserId = int
type Email = str
type Result<T> = Result(T, str)
```

**Rule:** Use type aliases for clarity

---

## 20. Opaque Types

**VIBEE** ✅
```vibee
@opaque
type Password: Password(str)
// Internal hidden
```

**Rule:** Use `@opaque` for encapsulation

---

## 21. Builder Pattern

**VIBEE** ✅
```vibee
@builder
type Request:
  url: str!
  method: str = "GET"
  headers: dict(str, str) = {}

Request()
  .url("api.com")
  .method("POST")
  .build()
```

**Rule:** Use `@builder` for complex construction

---

## 22. JSON Derive

**VIBEE** ✅
```vibee
@derive(Json)
type User:
  id: int!
  name: str!

// Auto-generated:
user.to_json()
User.from_json(json)
```

**Rule:** Use `@derive(Json)` for serialization

---

## 23. Async/Await

**VIBEE** ✅
```vibee
@async
fn fetch_data(url):
  await http.get(url)
```

**Rule:** Use `@async` for async functions

---

## 24. Tap Operator (Debug)

**VIBEE** ✅
```vibee
data
  |>> tap(fn(x) { io.println(x) })
  |> process()
```

**Rule:** Use `|>>` for debugging in pipes

---

## 25. Conditional Pipe (Result)

**VIBEE** ✅
```vibee
id
  |>? get_user()
  |>? validate()
  |>? save()
```

**Rule:** Use `|>?` for Result chains

---

## Bonus Features

### 26. String Interpolation

**VIBEE** ✅
```vibee
"Hello {name}, you have {count} messages"
"Result: {x + y * 2}"
"User: {user.name.uppercase()}"
```

**Rule:** Always use interpolation, never concat

---

### 27. Method Call Syntax

**VIBEE** ✅
```vibee
text.lowercase().trim()
numbers.filter(fn(x) { x > 0 }).map(fn(x) { x * 2 })
```

**Rule:** Use `.method()` not `module.func(value)`

---

### 28. Struct Syntax

**VIBEE** ✅
```vibee
struct User:
  id: int!           // Required
  name: str!         // Required
  email: str?        // Optional
  age: int = 0       // Default
```

**Rule:** Use `struct` with field markers

---

### 29. Enum Syntax

**VIBEE** ✅
```vibee
@enum
type Status:
  Active
  Inactive
  Pending
```

**Rule:** Use `@enum` annotation

---

### 30. Arrow Syntax

**VIBEE** ✅
```vibee
fn process(x: int) → str:
  "{x}"

case value:
  Some(x) → x
  ∅ → 0
```

**Rule:** Use `→` for arrows, `∅` for None

---

## Strict Mode Rules Summary

| # | Feature | Severity | Check |
|---|---------|----------|-------|
| 1 | Pipe Operator | Error | Nested calls → pipe |
| 2 | Pattern Matching | Warning | if/else → case |
| 3 | List Comprehension | Warning | .filter().map() → [x for x] |
| 4 | Extension Methods | Suggestion | Use built-ins |
| 5 | Try Operator | Suggestion | Manual Result → use |
| 6 | Decorators | Suggestion | Use @decorator |
| 7 | Smart Constructors | Suggestion | Use @smart_constructor |
| 8 | SQL DSL | Suggestion | Use @sql |
| 9 | Operator Sections | Suggestion | lambda → (> 5) |
| 10 | With Statement | Suggestion | Multiple bindings → with |
| 11 | Destructuring | Suggestion | Indexing → destructure |
| 12 | Optional Chaining | Suggestion | Manual checks → ?. |
| 13 | Guard Clauses | Suggestion | if return → guard |
| 14 | Context Managers | Suggestion | Manual close → with |
| 15 | Sigils | Suggestion | Use ~r// ~s"" |
| 16 | Range Operator | Suggestion | list.range → .. |
| 17 | Elvis Operator | Suggestion | case default → ?: |
| 18 | Spread Operator | Suggestion | Manual concat → .. |
| 19 | Type Aliases | Suggestion | Primitive → alias |
| 20 | Opaque Types | Suggestion | Public → @opaque |
| 21 | Builder Pattern | Suggestion | Manual → @builder |
| 22 | JSON Derive | Suggestion | Manual → @derive(Json) |
| 23 | Async/Await | Suggestion | Callbacks → @async |
| 24 | Tap Operator | Suggestion | Debug → \|>> |
| 25 | Conditional Pipe | Suggestion | Manual Result → \|>? |
| 26 | String Interpolation | Warning | Concat → "{var}" |
| 27 | Method Calls | Warning | module.func() → .method() |
| 28 | Struct Syntax | Error | type → struct |
| 29 | Enum Syntax | Error | Missing @enum |
| 30 | Arrow Syntax | Error | -> → → |

## Enabling Strict Mode

```bash
# Check file
vibee check --strict file.vibee

# Check all files
vibee check --strict src/

# Auto-fix (where possible)
vibee fix --strict file.vibee
```

## Strict Mode Levels

```vibee
// Level 1: Errors only (default)
@strict(level: 1)

// Level 2: Errors + Warnings
@strict(level: 2)

// Level 3: Errors + Warnings + Suggestions
@strict(level: 3)
```

## Disabling Rules

```vibee
// Disable specific rule
@allow(NoPipeOperator)
fn legacy_code():
  save(transform(validate(data)))

// Disable for file
@allow(NoStringInterpolation, NoPipeOperator)
```

## Conclusion

VIBEE has **30+ advanced features** that make code:
- More concise
- More readable
- More type-safe
- More maintainable
- More performant

**Always use VIBEE idioms, not Python/TypeScript patterns!**
