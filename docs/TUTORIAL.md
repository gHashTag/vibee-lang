# .999 Language Tutorial

**Ternary Logic Programming with Coptic Symbols**

## Introduction

.999 is a programming language based on ternary (three-valued) logic. Unlike traditional binary logic (true/false), .999 uses three values:

| Symbol | Name | Meaning |
|--------|------|---------|
| △ | True | Definitely true |
| ▽ | False | Definitely false |
| ○ | Unknown | Uncertain, null, or undefined |

This makes .999 ideal for:
- Database queries with NULL values
- Sensor data with uncertainty
- AI/ML confidence levels
- Quantum-inspired computing

## Quick Start

### Hello World

```999
Ⲯ ⲕⲟⲣⲉ

Ⲫ main() {
    print("Hello, .999!")
}

main()
```

### Variables and Types

```999
// Immutable binding
Ⲁ x = 42

// Mutable binding
Ⲃ y = 10
y = 20  // OK

// Type annotations
Ⲃ name: Ⲧⲉⲝⲧ = "Alice"
Ⲃ age: Ⲓⲛⲧ = 25
Ⲃ pi: Ⲫⲗⲟⲁⲧ = 3.14159
Ⲃ active: Ⲃⲟⲟⲗ = △
```

## Coptic Alphabet Reference

### Keywords

| Symbol | Meaning | Usage |
|--------|---------|-------|
| Ⲫ | Function | `Ⲫ name() { }` |
| Ⲁ | Immutable | `Ⲁ x = 5` |
| Ⲃ | Mutable | `Ⲃ y = 10` |
| Ⲏ | Struct | `Ⲏ Point { }` |
| Ⲉ | If | `Ⲉ condition { }` |
| Ⲱ | Else | `Ⲱ { }` |
| Ⲝ | For loop | `Ⲝ i ∈ range { }` |
| Ⲣ | Return | `Ⲣ value` |
| Ⲥ | Self | `Ⲥ.field` |
| Ⲯ | Import | `Ⲯ module` |

### Types

| Symbol | Type |
|--------|------|
| Ⲓⲛⲧ | Integer |
| Ⲫⲗⲟⲁⲧ | Float |
| Ⲧⲉⲝⲧ | String |
| Ⲃⲟⲟⲗ | Boolean |
| Trit | Ternary value |

## Ternary Logic

### Basic Operations

```999
Ⲯ ⲧⲣⲓⲛⲓⲧⲩ

Ⲫ main() {
    // Ternary values
    Ⲃ yes: Trit = △
    Ⲃ no: Trit = ▽
    Ⲃ maybe: Trit = ○
    
    // Ternary AND (Kleene logic)
    print(trit_and(△, △))  // △
    print(trit_and(△, ○))  // ○
    print(trit_and(▽, ○))  // ▽
    
    // Ternary OR
    print(trit_or(△, ○))   // △
    print(trit_or(▽, ○))   // ○
    print(trit_or(▽, ▽))   // ▽
    
    // Ternary NOT
    print(trit_not(△))     // ▽
    print(trit_not(▽))     // △
    print(trit_not(○))     // ○
}
```

### Truth Tables

**AND (trit_and)**
|   | △ | ○ | ▽ |
|---|---|---|---|
| △ | △ | ○ | ▽ |
| ○ | ○ | ○ | ▽ |
| ▽ | ▽ | ▽ | ▽ |

**OR (trit_or)**
|   | △ | ○ | ▽ |
|---|---|---|---|
| △ | △ | △ | △ |
| ○ | △ | ○ | ○ |
| ▽ | △ | ○ | ▽ |

**NOT (trit_not)**
| Input | Output |
|-------|--------|
| △ | ▽ |
| ○ | ○ |
| ▽ | △ |

## Control Flow

### Conditionals

```999
Ⲫ check_age(Ⲁ age: Ⲓⲛⲧ) → Ⲧⲉⲝⲧ {
    Ⲉ age >= 18 {
        Ⲣ "Adult"
    } Ⲱ Ⲉ age >= 13 {
        Ⲣ "Teenager"
    } Ⲱ {
        Ⲣ "Child"
    }
}
```

### Ternary Conditionals

```999
Ⲫ process(Ⲁ status: Trit) {
    Ⲉ status == △ {
        print("Confirmed")
    } Ⲱ Ⲉ status == ○ {
        print("Pending verification")
    } Ⲱ {
        print("Rejected")
    }
}
```

### Loops

```999
// Range loop
Ⲝ i ∈ 0..10 {
    print(i)
}

// Collection loop
Ⲃ items = [1, 2, 3, 4, 5]
Ⲝ item ∈ items {
    print(item)
}

// While-style loop
Ⲃ count = 0
Ⲝ count < 10 {
    print(count)
    count += 1
}
```

## Functions

### Basic Functions

```999
Ⲫ add(Ⲁ a: Ⲓⲛⲧ, Ⲁ b: Ⲓⲛⲧ) → Ⲓⲛⲧ {
    Ⲣ a + b
}

Ⲫ greet(Ⲁ name: Ⲧⲉⲝⲧ) {
    print("Hello, " + name + "!")
}
```

### Generic Functions

```999
Ⲫ identity[T](Ⲁ value: T) → T {
    Ⲣ value
}

Ⲫ swap[T](Ⲃ a: T, Ⲃ b: T) {
    Ⲁ temp = a
    a = b
    b = temp
}
```

## Structs

### Definition

```999
Ⲏ Point {
    Ⲃ x: Ⲫⲗⲟⲁⲧ
    Ⲃ y: Ⲫⲗⲟⲁⲧ
    
    Ⲫ new(Ⲁ x: Ⲫⲗⲟⲁⲧ, Ⲁ y: Ⲫⲗⲟⲁⲧ) → Point {
        Ⲣ Point { x: x, y: y }
    }
    
    Ⲫ distance(Ⲥ, Ⲁ other: Point) → Ⲫⲗⲟⲁⲧ {
        Ⲁ dx = Ⲥ.x - other.x
        Ⲁ dy = Ⲥ.y - other.y
        Ⲣ sqrt(dx * dx + dy * dy)
    }
}
```

### Usage

```999
Ⲃ p1 = Point.new(0.0, 0.0)
Ⲃ p2 = Point.new(3.0, 4.0)
print(p1.distance(p2))  // 5.0
```

## Testing

### Test Blocks

```999
⊡ test "addition" {
    ⊜! add(2, 3) == 5
}

⊡ test "ternary_logic" {
    ⊜! trit_and(△, △) == △
    ⊜! trit_and(△, ○) == ○
    ⊜! trit_or(▽, △) == △
}
```

### Running Tests

```bash
# Run all tests in a file
./vibeec test examples/my_program.999

# Run specific test
./vibeec test examples/my_program.999 --filter "addition"
```

## Practical Examples

### Nullable Values

```999
Ⲏ Maybe[T] {
    Ⲃ value: T?
    Ⲃ has_value: Trit
    
    Ⲫ some(Ⲁ v: T) → Maybe[T] {
        Ⲣ Maybe { value: v, has_value: △ }
    }
    
    Ⲫ none() → Maybe[T] {
        Ⲣ Maybe { value: ○, has_value: ▽ }
    }
    
    Ⲫ unknown() → Maybe[T] {
        Ⲣ Maybe { value: ○, has_value: ○ }
    }
}
```

### Database Query

```999
Ⲫ find_user(Ⲁ id: Ⲓⲛⲧ) → Maybe[User] {
    Ⲃ result = db.query("SELECT * FROM users WHERE id = ?", id)
    
    Ⲉ result.error {
        Ⲣ Maybe.unknown()  // Query failed, uncertain
    } Ⲱ Ⲉ result.empty {
        Ⲣ Maybe.none()     // Not found
    } Ⲱ {
        Ⲣ Maybe.some(result.first())
    }
}
```

### Sensor Fusion

```999
Ⲫ fuse_readings(Ⲁ sensors: [Sensor]) → Trit {
    Ⲃ true_count = 0
    Ⲃ false_count = 0
    Ⲃ unknown_count = 0
    
    Ⲝ sensor ∈ sensors {
        Ⲉ sensor.reading == △ { true_count += 1 }
        Ⲱ Ⲉ sensor.reading == ▽ { false_count += 1 }
        Ⲱ { unknown_count += 1 }
    }
    
    // Majority voting with uncertainty
    Ⲉ true_count > false_count + unknown_count {
        Ⲣ △
    } Ⲱ Ⲉ false_count > true_count + unknown_count {
        Ⲣ ▽
    } Ⲱ {
        Ⲣ ○
    }
}
```

## Best Practices

### 1. Use Ternary Logic for Uncertainty

```999
// Bad: Using null checks
Ⲉ value != ○ { ... }

// Good: Using ternary logic
Ⲉ value.certainty == △ { ... }
```

### 2. Propagate Uncertainty

```999
// Bad: Ignoring unknown values
Ⲫ process(Ⲁ a: Trit, Ⲁ b: Trit) → Trit {
    Ⲣ a && b  // Loses uncertainty
}

// Good: Proper propagation
Ⲫ process(Ⲁ a: Trit, Ⲁ b: Trit) → Trit {
    Ⲣ trit_and(a, b)  // Preserves uncertainty
}
```

### 3. Document Ternary Semantics

```999
// Document what ○ means in your context
Ⲏ Vote {
    Ⲃ value: Trit  // △=yes, ▽=no, ○=abstain
}
```

## Next Steps

- Read the [API Reference](API.md)
- Explore [Examples](../examples/)
- Learn about [WASM Compilation](WASM.md)
- Set up [VS Code Extension](VSCODE.md)
