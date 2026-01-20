# VIBEE Pipeline Architecture

## Зачем мы это делаем?

### Проблема традиционного подхода

```
Традиционный подход:
Программист → пишет код → тесты → баги → фиксы → повторить

Проблемы:
1. Код пишется без формальной спецификации
2. Тесты пишутся после кода (или не пишутся)
3. Нет единого источника правды
4. Сложно генерировать код для разных языков
5. Нет научной основы для улучшений
```

### Решение: Specification-First Development

```
VIBEE подход:
Спецификация → Компилятор → Код + Тесты (автоматически)

Преимущества:
1. Спецификация = единый источник правды
2. Тесты генерируются из behaviors
3. Код генерируется для любого языка
4. PAS DAEMONS предсказывают улучшения
5. Научная основа (12 papers, 150K citations)
```

---

## Текущий Pipeline (v35)

### Проблема: Ручной код в ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ

```yaml
# specs/tri/example.vibee

name: example
types:
  - name: User
    fields:
      - name: id
        type: Int

# ПРОБЛЕМА: Код пишется вручную!
ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ: """
pub const User = struct {
    id: i64,  // ← Это написано руками
};
"""
```

### Почему это плохо:

1. **Дублирование** - types описаны дважды (в spec и в коде)
2. **Рассинхронизация** - spec и код могут разойтись
3. **Ручная работа** - нарушает идею автогенерации
4. **Ошибки** - человек может ошибиться в коде

---

## Целевой Pipeline (v36+)

### Решение: Автоматическая генерация

```yaml
# specs/tri/example.vibee

name: example
version: "1.0.0"
language: zig

types:
  - name: User
    fields:
      - name: id
        type: Int
      - name: name
        type: String
      - name: email
        type: String

behaviors:
  - name: create_user
    given: "Valid user data"
    when: "create_user is called"
    then: "Return new User"
    test_cases:
      - name: test_create_valid
        input: '{"id": 1, "name": "John"}'
        expected: '{"id": 1}'

# НЕТ ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ - код генерируется автоматически!
```

### Компилятор генерирует:

```zig
// АВТОМАТИЧЕСКИ СГЕНЕРИРОВАНО из example.vibee

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// Из types:
pub const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
};

// Из behaviors:
pub fn create_user(id: i64, name: []const u8, email: []const u8) User {
    return User{
        .id = id,
        .name = name,
        .email = email,
    };
}

// Из test_cases:
test "test_create_valid" {
    const user = create_user(1, "John", "john@example.com");
    try std.testing.expectEqual(@as(i64, 1), user.id);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + 1.0/phi_sq, 0.0001);
}
```

---

## Архитектура компилятора

```
┌─────────────────────────────────────────────────────────────┐
│                    VIBEEC COMPILER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   PARSER    │ →  │  ANALYZER   │ →  │  CODEGEN    │     │
│  │             │    │             │    │             │     │
│  │ YAML → AST  │    │ Type Check  │    │ AST → Code  │     │
│  │             │    │ Validate    │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         ↓                  ↓                  ↓             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    CODE TEMPLATES                    │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │  Zig    │ Python │  Go   │ Rust  │  TS   │ Gleam   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Этапы компиляции:

1. **Parser** - читает .vibee, строит AST
2. **Analyzer** - проверяет типы, валидирует
3. **CodeGen** - генерирует код для целевого языка

---

## Type Mapping

| VIBEE Type | Zig | Python | Go | Rust | TypeScript |
|------------|-----|--------|-----|------|------------|
| String | `[]const u8` | `str` | `string` | `String` | `string` |
| Int | `i64` | `int` | `int64` | `i64` | `number` |
| Float | `f64` | `float` | `float64` | `f64` | `number` |
| Bool | `bool` | `bool` | `bool` | `bool` | `boolean` |
| List<T> | `[]T` | `list[T]` | `[]T` | `Vec<T>` | `T[]` |
| Option<T> | `?T` | `Optional[T]` | `*T` | `Option<T>` | `T \| null` |

---

## Behavior → Function Mapping

```yaml
# Спецификация
behaviors:
  - name: calculate_total
    given: "List of prices"
    when: "calculate_total is called"
    then: "Return sum of prices"
    params:
      - name: prices
        type: List<Float>
    returns: Float
```

### Генерируется:

**Zig:**
```zig
pub fn calculate_total(prices: []const f64) f64 {
    var total: f64 = 0;
    for (prices) |price| {
        total += price;
    }
    return total;
}
```

**Python:**
```python
def calculate_total(prices: list[float]) -> float:
    return sum(prices)
```

**Go:**
```go
func CalculateTotal(prices []float64) float64 {
    var total float64
    for _, price := range prices {
        total += price
    }
    return total
}
```

---

## Test Generation

```yaml
# Спецификация
test_cases:
  - name: test_empty_list
    input: '{"prices": []}'
    expected: '0.0'
  
  - name: test_single_item
    input: '{"prices": [10.0]}'
    expected: '10.0'
  
  - name: test_multiple_items
    input: '{"prices": [10.0, 20.0, 30.0]}'
    expected: '60.0'
```

### Генерируется:

```zig
test "test_empty_list" {
    const result = calculate_total(&[_]f64{});
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 0.0001);
}

test "test_single_item" {
    const result = calculate_total(&[_]f64{10.0});
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), result, 0.0001);
}

test "test_multiple_items" {
    const result = calculate_total(&[_]f64{10.0, 20.0, 30.0});
    try std.testing.expectApproxEqAbs(@as(f64, 60.0), result, 0.0001);
}
```

---

## PAS DAEMONS Integration

### Автоматический анализ алгоритмов:

```yaml
behaviors:
  - name: search_item
    given: "Sorted list and target"
    when: "search_item is called"
    then: "Return index or -1"
    
    # PAS автоматически определяет:
    pas_analysis:
      current_complexity: O(n)      # Линейный поиск
      optimal_complexity: O(log n)  # Бинарный поиск
      applicable_patterns:
        - D&C: 0.85  # Divide-and-Conquer подходит
        - PRE: 0.20  # Precomputation менее применим
      recommendation: "Use binary search (D&C pattern)"
```

---

## Roadmap

### v36: Basic Auto-Generation
- [ ] Генерация структур из types
- [ ] Генерация функций из behaviors
- [ ] Генерация тестов из test_cases

### v37: Multi-Language
- [ ] Python codegen
- [ ] Go codegen
- [ ] Rust codegen

### v38: PAS Integration
- [ ] Автоматический анализ сложности
- [ ] Рекомендации по оптимизации
- [ ] Применение паттернов

### v39: Full Pipeline
- [ ] IDE интеграция
- [ ] Hot reload
- [ ] Incremental compilation

---

## Команды

```bash
# Текущий (ручной)
./bin/tri-extract specs/tri/example.vibee

# Целевой (автоматический)
vibeec compile specs/tri/example.vibee --target zig
vibeec compile specs/tri/example.vibee --target python
vibeec compile specs/tri/example.vibee --target go
```

---

## Заключение

**Почему это важно:**

1. **Единый источник правды** - спецификация определяет всё
2. **Автоматизация** - код генерируется, не пишется
3. **Мультиязычность** - один spec → много языков
4. **Тестируемость** - тесты из спецификации
5. **Научная основа** - PAS предсказывает улучшения

```
φ² + 1/φ² = 3

Specification → Compiler → Code
Known → PAS → Predicted
```
