# .999 API Reference

## Core Module (ⲕⲟⲣⲉ)

Import: `Ⲯ ⲕⲟⲣⲉ`

### I/O Functions

#### print

```999
Ⲫ print(Ⲁ value: any) → void
```

Outputs value to stdout with newline.

```999
print("Hello")
print(42)
print(△)
```

#### input

```999
Ⲫ input(Ⲁ prompt: Ⲧⲉⲝⲧ) → Ⲧⲉⲝⲧ
```

Reads line from stdin.

```999
Ⲃ name = input("Enter name: ")
```

### Math Functions

#### abs

```999
Ⲫ abs(Ⲁ x: Ⲫⲗⲟⲁⲧ) → Ⲫⲗⲟⲁⲧ
```

Returns absolute value.

#### sqrt

```999
Ⲫ sqrt(Ⲁ x: Ⲫⲗⲟⲁⲧ) → Ⲫⲗⲟⲁⲧ
```

Returns square root.

#### pow

```999
Ⲫ pow(Ⲁ base: Ⲫⲗⲟⲁⲧ, Ⲁ exp: Ⲫⲗⲟⲁⲧ) → Ⲫⲗⲟⲁⲧ
```

Returns base raised to exponent.

#### min / max

```999
Ⲫ min(Ⲁ a: Ⲫⲗⲟⲁⲧ, Ⲁ b: Ⲫⲗⲟⲁⲧ) → Ⲫⲗⲟⲁⲧ
Ⲫ max(Ⲁ a: Ⲫⲗⲟⲁⲧ, Ⲁ b: Ⲫⲗⲟⲁⲧ) → Ⲫⲗⲟⲁⲧ
```

Returns minimum/maximum of two values.

#### floor / ceil / round

```999
Ⲫ floor(Ⲁ x: Ⲫⲗⲟⲁⲧ) → Ⲓⲛⲧ
Ⲫ ceil(Ⲁ x: Ⲫⲗⲟⲁⲧ) → Ⲓⲛⲧ
Ⲫ round(Ⲁ x: Ⲫⲗⲟⲁⲧ) → Ⲓⲛⲧ
```

Rounding functions.

### String Functions

#### len

```999
Ⲫ len(Ⲁ s: Ⲧⲉⲝⲧ) → Ⲓⲛⲧ
```

Returns string length.

#### substr

```999
Ⲫ substr(Ⲁ s: Ⲧⲉⲝⲧ, Ⲁ start: Ⲓⲛⲧ, Ⲁ length: Ⲓⲛⲧ) → Ⲧⲉⲝⲧ
```

Returns substring.

#### split

```999
Ⲫ split(Ⲁ s: Ⲧⲉⲝⲧ, Ⲁ delimiter: Ⲧⲉⲝⲧ) → [Ⲧⲉⲝⲧ]
```

Splits string by delimiter.

#### join

```999
Ⲫ join(Ⲁ parts: [Ⲧⲉⲝⲧ], Ⲁ separator: Ⲧⲉⲝⲧ) → Ⲧⲉⲝⲧ
```

Joins strings with separator.

#### trim

```999
Ⲫ trim(Ⲁ s: Ⲧⲉⲝⲧ) → Ⲧⲉⲝⲧ
```

Removes leading/trailing whitespace.

#### upper / lower

```999
Ⲫ upper(Ⲁ s: Ⲧⲉⲝⲧ) → Ⲧⲉⲝⲧ
Ⲫ lower(Ⲁ s: Ⲧⲉⲝⲧ) → Ⲧⲉⲝⲧ
```

Case conversion.

---

## Trinity Module (ⲧⲣⲓⲛⲓⲧⲩ)

Import: `Ⲯ ⲧⲣⲓⲛⲓⲧⲩ`

### Trit Type

Three-valued logic type with values:
- `△` (True)
- `▽` (False)
- `○` (Unknown)

### Logic Functions

#### trit_and

```999
Ⲫ trit_and(Ⲁ a: Trit, Ⲁ b: Trit) → Trit
```

Kleene strong conjunction.

| a | b | result |
|---|---|--------|
| △ | △ | △ |
| △ | ○ | ○ |
| △ | ▽ | ▽ |
| ○ | △ | ○ |
| ○ | ○ | ○ |
| ○ | ▽ | ▽ |
| ▽ | △ | ▽ |
| ▽ | ○ | ▽ |
| ▽ | ▽ | ▽ |

#### trit_or

```999
Ⲫ trit_or(Ⲁ a: Trit, Ⲁ b: Trit) → Trit
```

Kleene strong disjunction.

| a | b | result |
|---|---|--------|
| △ | △ | △ |
| △ | ○ | △ |
| △ | ▽ | △ |
| ○ | △ | △ |
| ○ | ○ | ○ |
| ○ | ▽ | ○ |
| ▽ | △ | △ |
| ▽ | ○ | ○ |
| ▽ | ▽ | ▽ |

#### trit_not

```999
Ⲫ trit_not(Ⲁ a: Trit) → Trit
```

Kleene negation.

| a | result |
|---|--------|
| △ | ▽ |
| ○ | ○ |
| ▽ | △ |

#### trit_xor

```999
Ⲫ trit_xor(Ⲁ a: Trit, Ⲁ b: Trit) → Trit
```

Exclusive or with uncertainty propagation.

#### trit_implies

```999
Ⲫ trit_implies(Ⲁ a: Trit, Ⲁ b: Trit) → Trit
```

Material implication: `¬a ∨ b`

### Conversion Functions

#### to_trit

```999
Ⲫ to_trit(Ⲁ b: Ⲃⲟⲟⲗ) → Trit
```

Converts boolean to trit.

```999
to_trit(true)   // △
to_trit(false)  // ▽
```

#### to_bool

```999
Ⲫ to_bool(Ⲁ t: Trit) → Ⲃⲟⲟⲗ?
```

Converts trit to optional boolean. Returns `○` for unknown.

#### is_known

```999
Ⲫ is_known(Ⲁ t: Trit) → Ⲃⲟⲟⲗ
```

Returns true if trit is △ or ▽.

#### is_unknown

```999
Ⲫ is_unknown(Ⲁ t: Trit) → Ⲃⲟⲟⲗ
```

Returns true if trit is ○.

### Aggregation Functions

#### trit_all

```999
Ⲫ trit_all(Ⲁ values: [Trit]) → Trit
```

Returns △ if all values are △, ▽ if any is ▽, ○ otherwise.

#### trit_any

```999
Ⲫ trit_any(Ⲁ values: [Trit]) → Trit
```

Returns △ if any value is △, ▽ if all are ▽, ○ otherwise.

#### trit_majority

```999
Ⲫ trit_majority(Ⲁ values: [Trit]) → Trit
```

Returns the majority value, or ○ if no clear majority.

#### trit_consensus

```999
Ⲫ trit_consensus(Ⲁ values: [Trit]) → Trit
```

Returns value if all agree, ○ otherwise.

---

## Collections Module (ⲕⲟⲗⲗⲉⲕⲧ)

Import: `Ⲯ ⲕⲟⲗⲗⲉⲕⲧ`

### Array Functions

#### len

```999
Ⲫ len[T](Ⲁ arr: [T]) → Ⲓⲛⲧ
```

Returns array length.

#### push

```999
Ⲫ push[T](Ⲃ arr: [T], Ⲁ value: T) → void
```

Appends value to array.

#### pop

```999
Ⲫ pop[T](Ⲃ arr: [T]) → T?
```

Removes and returns last element.

#### first / last

```999
Ⲫ first[T](Ⲁ arr: [T]) → T?
Ⲫ last[T](Ⲁ arr: [T]) → T?
```

Returns first/last element or ○.

#### map

```999
Ⲫ map[T, U](Ⲁ arr: [T], Ⲁ f: Ⲫ(T) → U) → [U]
```

Transforms each element.

```999
Ⲃ nums = [1, 2, 3]
Ⲃ doubled = map(nums, Ⲫ(x) { Ⲣ x * 2 })
// [2, 4, 6]
```

#### filter

```999
Ⲫ filter[T](Ⲁ arr: [T], Ⲁ pred: Ⲫ(T) → Ⲃⲟⲟⲗ) → [T]
```

Keeps elements matching predicate.

#### reduce

```999
Ⲫ reduce[T, U](Ⲁ arr: [T], Ⲁ init: U, Ⲁ f: Ⲫ(U, T) → U) → U
```

Reduces array to single value.

```999
Ⲃ sum = reduce([1, 2, 3], 0, Ⲫ(acc, x) { Ⲣ acc + x })
// 6
```

#### find

```999
Ⲫ find[T](Ⲁ arr: [T], Ⲁ pred: Ⲫ(T) → Ⲃⲟⲟⲗ) → T?
```

Returns first matching element or ○.

#### contains

```999
Ⲫ contains[T](Ⲁ arr: [T], Ⲁ value: T) → Ⲃⲟⲟⲗ
```

Checks if array contains value.

#### sort

```999
Ⲫ sort[T](Ⲃ arr: [T]) → void
Ⲫ sort_by[T, K](Ⲃ arr: [T], Ⲁ key: Ⲫ(T) → K) → void
```

Sorts array in place.

#### reverse

```999
Ⲫ reverse[T](Ⲃ arr: [T]) → void
```

Reverses array in place.

### Map Functions

#### Map[K, V]

```999
Ⲏ Map[K, V] {
    Ⲫ new() → Map[K, V]
    Ⲫ get(Ⲥ, Ⲁ key: K) → V?
    Ⲫ set(Ⲥ, Ⲁ key: K, Ⲁ value: V) → void
    Ⲫ has(Ⲥ, Ⲁ key: K) → Ⲃⲟⲟⲗ
    Ⲫ delete(Ⲥ, Ⲁ key: K) → Ⲃⲟⲟⲗ
    Ⲫ keys(Ⲥ) → [K]
    Ⲫ values(Ⲥ) → [V]
    Ⲫ len(Ⲥ) → Ⲓⲛⲧ
}
```

---

## Uncertainty Module (ⲁⲛⲥⲉⲣⲧ)

Import: `Ⲯ ⲁⲛⲥⲉⲣⲧ`

### Uncertain[T] Type

```999
Ⲏ Uncertain[T] {
    Ⲃ value: T
    Ⲃ certainty: Trit
    Ⲃ confidence: Ⲫⲗⲟⲁⲧ  // 0.0 to 1.0
}
```

### Constructor Functions

#### certain

```999
Ⲫ certain[T](Ⲁ value: T) → Uncertain[T]
```

Creates certain value (certainty = △, confidence = 1.0).

#### uncertain

```999
Ⲫ uncertain[T](Ⲁ value: T, Ⲁ confidence: Ⲫⲗⲟⲁⲧ) → Uncertain[T]
```

Creates uncertain value (certainty = ○).

#### unknown

```999
Ⲫ unknown[T]() → Uncertain[T]
```

Creates unknown value (certainty = ▽, confidence = 0.0).

### Propagation Functions

#### propagate_and

```999
Ⲫ propagate_and[T](Ⲁ a: Uncertain[T], Ⲁ b: Uncertain[T]) → Uncertain[T]
```

Propagates uncertainty through AND operation.

#### propagate_or

```999
Ⲫ propagate_or[T](Ⲁ a: Uncertain[T], Ⲁ b: Uncertain[T]) → Uncertain[T]
```

Propagates uncertainty through OR operation.

#### combine

```999
Ⲫ combine[T](Ⲁ values: [Uncertain[T]], Ⲁ strategy: CombineStrategy) → Uncertain[T]
```

Combines multiple uncertain values.

Strategies:
- `CombineStrategy.Average` - Average confidence
- `CombineStrategy.Min` - Minimum confidence
- `CombineStrategy.Max` - Maximum confidence
- `CombineStrategy.Weighted` - Weighted by confidence

---

## File Module (ⲫⲁⲓⲗ)

Import: `Ⲯ ⲫⲁⲓⲗ`

### File Operations

#### read_file

```999
Ⲫ read_file(Ⲁ path: Ⲧⲉⲝⲧ) → Result[Ⲧⲉⲝⲧ, Error]
```

Reads entire file as string.

#### write_file

```999
Ⲫ write_file(Ⲁ path: Ⲧⲉⲝⲧ, Ⲁ content: Ⲧⲉⲝⲧ) → Result[void, Error]
```

Writes string to file.

#### append_file

```999
Ⲫ append_file(Ⲁ path: Ⲧⲉⲝⲧ, Ⲁ content: Ⲧⲉⲝⲧ) → Result[void, Error]
```

Appends string to file.

#### file_exists

```999
Ⲫ file_exists(Ⲁ path: Ⲧⲉⲝⲧ) → Ⲃⲟⲟⲗ
```

Checks if file exists.

#### delete_file

```999
Ⲫ delete_file(Ⲁ path: Ⲧⲉⲝⲧ) → Result[void, Error]
```

Deletes file.

---

## Result Type

```999
Ⲏ Result[T, E] {
    Ⲫ ok(Ⲁ value: T) → Result[T, E]
    Ⲫ err(Ⲁ error: E) → Result[T, E]
    Ⲫ is_ok(Ⲥ) → Ⲃⲟⲟⲗ
    Ⲫ is_err(Ⲥ) → Ⲃⲟⲟⲗ
    Ⲫ unwrap(Ⲥ) → T
    Ⲫ unwrap_or(Ⲥ, Ⲁ default: T) → T
    Ⲫ map[U](Ⲥ, Ⲁ f: Ⲫ(T) → U) → Result[U, E]
}
```

---

## Operators

### Arithmetic

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `%` | Modulo |
| `**` | Power |

### Comparison

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less or equal |
| `>=` | Greater or equal |

### Logical

| Operator | Description |
|----------|-------------|
| `&&` | Boolean AND |
| `\|\|` | Boolean OR |
| `!` | Boolean NOT |
| `∧` | Ternary AND |
| `∨` | Ternary OR |
| `¬` | Ternary NOT |

### Assignment

| Operator | Description |
|----------|-------------|
| `=` | Assign |
| `+=` | Add and assign |
| `-=` | Subtract and assign |
| `*=` | Multiply and assign |
| `/=` | Divide and assign |

### Range

| Operator | Description |
|----------|-------------|
| `..` | Exclusive range |
| `..=` | Inclusive range |

### Membership

| Operator | Description |
|----------|-------------|
| `∈` | Element of |
| `∉` | Not element of |

---

## Reserved Keywords

| Coptic | ASCII | Meaning |
|--------|-------|---------|
| Ⲫ | fn | Function |
| Ⲁ | let | Immutable binding |
| Ⲃ | var | Mutable binding |
| Ⲏ | struct | Structure |
| Ⲉ | if | Conditional |
| Ⲱ | else | Alternative |
| Ⲝ | for | Loop |
| Ⲣ | return | Return |
| Ⲥ | self | Self reference |
| Ⲯ | import | Import |
| △ | true | True |
| ▽ | false | False |
| ○ | unknown | Unknown |
