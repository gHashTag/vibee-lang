# 🎯 ДЕМОНСТРАЦИЯ: ЧТО ДОЛЖЕН ДЕЛАТЬ vibee gen

## ══════════════════════════════════════════════════════════════════════════
## ВВОД: ПОЧЕМУ ЭТО ВАЖНО
## ══════════════════════════════════════════════════════════════════════════

**ТЕКУЩАЯ ПРОБЛЕМА:**
vibee gen генерирует ТОЛЬКО тесты, даже если в .vibee есть `implementation`:

```yaml
# test_true_compilation.vibee
behaviors:
  - name: add_numbers
    description: Adds two numbers
    implementation: |
      return 10 + 20;
```

**vibee gen ВЫДАЕТ:**
```zig
test "add_numbers" {
    // Golden identity verification
    const phi_sq = PHI * PHI;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
```

**НУЖНО ВЫДАТЬ:**
```zig
pub fn add_numbers() !void {
    // Adds two numbers

    // Implementation:
    return 10 + 20;
}
```

---

## ══════════════════════════════════════════════════════════════════════════
## ЧАСТЬ 1: КАК ДОЛЖЕН РАБОТАТЬ ПАРСЕР
## ══════════════════════════════════════════════════════════════════════════

**Файл:** `src/vibeec/parser_v3.zig`
**Строка:** ~178

**СТАРЫЙ Behavior struct:**
```zig
pub const Behavior = struct {
    name: []const u8 = "",
    given: []const u8 = "",
    when: []const u8 = "",
    then: []const u8 = "",
    test_cases: ArrayList(TestCase),

    pub fn init(allocator: Allocator) Behavior {
        _ = allocator;
        return .{
            .test_cases = .empty,
        };
    }
};
```

**НОВЫЙ Behavior struct (С ИЗМЕНЕНИЯМИ):**
```zig
pub const Behavior = struct {
    name: []const u8 = "",
    given: []const u8 = "",
    when: []const u8 = "",
    then: []const u8 = "",
    test_cases: ArrayList(TestCase),
    implementation: []const u8 = "", // ← ДОБАВЛЕНО

    pub fn init(allocator: Allocator) Behavior {
        _ = allocator;
        return .{
            .test_cases = .empty,
            .implementation = "", // ← ДОБАВЛЕНО
        };
    }
};
```

---

## ══════════════════════════════════════════════════════════════════════════
## ЧАСТЬ 2: КАК ДОЛЖЕН ПАРСИТЬСЯ ИМПЛЕМЕНТАЦИЯ
## ══════════════════════════════════════════════════════════════════════════

**Файл:** `src/vibeec/parser_v3.zig`
**Место:** Где парсятся `behaviors` (строки ~XXX-YYY)

**ЛОГИКА ПАРСИНГА:**

```zig
// Пример кода (псевдокод, не реальный Zig):

// Когда видишь: "- name: behavior_name"
if (line.startsWith("- name:")) {
    const name = parseName(line);

    // Создаем поведение
    var behavior = Behavior.init(allocator);
    behavior.name = name;

    // СМОТРИ ВПЕРЕД - есть ли implementation
    var impl_lines = ArrayList([]const u8).init(allocator);
    defer impl_lines.deinit();

    // Пока не увидим следующий "- name:" или секцию
    while (nextLine()) |line| {
        if (line.startsWith("- name:")) {
            break; // Следующее поведение
        }

        if (line.startsWith("    implementation: |")) {
            // Начало многострочной имплементации
            const first_line = line.sliceAfter("|").trim();
            try impl_lines.append(first_line);
        } else if (line.startsWith("    ") and impl_lines.items.len > 0) {
            // Продолжение многострочной имплементации
            try impl_lines.append(line.trim());
        }
    }

    // Объединить строки в один блок
    const impl = try allocator.join(impl_lines.items, "\n");

    // Добавить к поведению
    behavior.implementation = impl;

    try spec.behaviors.append(behavior);
}
```

---

## ══════════════════════════════════════════════════════════════════════════
## ЧАСТЬ 3: КАК ДОЛЖЕН ГЕНЕРИРОВАТЬСЯ КОД
## ══════════════════════════════════════════════════════════════════════════

**Файл:** `src/vibeec/codegen_v4.zig`
**Строка:** ~295 (generateZig)

**СТАРЫЙ КОД:**
```zig
// Tests from behaviors
for (spec.behaviors.items) |behavior| {
    try self.generateZigTest(&behavior);
    self.tests_generated += 1;
}
```

**НОВЫЙ КОД:**
```zig
// Behaviors/Tests from behaviors
for (spec.behaviors.items) |behavior| {
    if (behavior.implementation.len > 0) {
        // Generate REAL function from implementation
        try self.generateZigFunction(&behavior);
        self.functions_generated += 1;
    } else {
        // Generate test (fallback for old specs)
        try self.generateZigTest(&behavior);
        self.tests_generated += 1;
    }
}
```

---

## ══════════════════════════════════════════════════════════════════════════
## ЧАСТЬ 4: КАК ДОЛЖНА РАБОТАТЬ НОВАЯ ФУНКЦИЯ
## ══════════════════════════════════════════════════════════════════════════

**Файл:** `src/vibeec/codegen_v4.zig`
**Место:** После `generateZigTest` (строка ~403)

**НОВАЯ ФУНКЦИЯ:**
```zig
fn generateZigFunction(self: *Self, behavior: *const Behavior) !void {
    try self.zig_builder.appendFmt("pub fn {s}() ", .{behavior.name});
    try self.zig_builder.append(behavior.then);
    try self.zig_builder.append(" !void {\n");

    try self.zig_builder.appendIndent();
    try self.zig_builder.append("// ");
    try self.zig_builder.append(behavior.description);
    try self.zig_builder.append("\n\n");

    // Write implementation
    try self.zig_builder.append("// Implementation:\n");
    try self.zig_builder.append(behavior.implementation);
    try self.zig_builder.append("\n");

    self.zig_builder.dedent();
    try self.zig_builder.append("}\n\n");
}
```

---

## ══════════════════════════════════════════════════════════════════════════
## ПРИМЕР: ПОЛНЫЙ ЦИКЛ
## ══════════════════════════════════════════════════════════════════════════

### ВВОД (.vibee):
```yaml
name: test_real_compilation
behaviors:
  - name: add
    description: Add two numbers
    implementation: |
      return 10 + 20;
```

### ВЫХОД (.zig):
```zig
// ═════════════════════════════════════════════════════════════════════════
// GENERATED FROM: test_real_compilation
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Behaviors/Tests from behaviors

pub fn add() !void {    // ← РЕАЛЬНАЯ ФУНКЦИЯ
    // Add two numbers

    // Implementation:
    return 10 + 20;

}
```

---

## ══════════════════════════════════════════════════════════════════════════
## ПРОВЕРКА РАБОТЫ
## ════════════════════════════════════════════════════════════════════════

```bash
# 1. Создать тестовый .vibee
cat > test.vibee << 'EOF'
name: test
behaviors:
  - name: real_func
    description: Real function
    implementation: |
      return 42;
EOF

# 2. Генерировать (ПОСЛЕ ИЗМЕНЕНИЙ)
vibee gen test.vibee

# 3. Проверить результат
cat trinity/output/test.zig

# ОЖИДАЕМЫЙ ВЫВОД:
# pub fn real_func() !void {
#     // Real function
#
#     // Implementation:
#     return 42;
#
# }
```

---

## ══════════════════════════════════════════════════════════════════════════
## КРАТКОЕ ИЗМЕНЕНИЕ ЧЕК-ЛИСТ
## ══════════════════════════════════════════════════════════════════════════

### Файл: `src/vibeec/parser_v3.zig`
- [ ] Строка ~178: Добавить `implementation: []const u8 = ""` в Behavior struct
- [ ] Строка ~190: Добавить `.implementation = ""` в `init()`
- [ ] Строка ~XXX: Добавить логику парсинга `implementation: |`
- [ ] Тест: Проверить, что все старые .vibee файлы продолжают работать

### Файл: `src/vibeec/codegen_v4.zig`
- [ ] Строка ~296: Изменить цикл behaviors на `if/else`
- [ ] Строка ~403: Добавить `generateZigFunction()`
- [ ] Тест: Проверить на файле с implementation

### ПРОВЕРКА
```bash
# 1. Пересобрать
zig build

# 2. Создать тест
cat > test.vibee << 'EOF'
name: test
behaviors:
  - name: real
    description: Real
    implementation: return 42;
EOF

# 3. Генерировать
vibee gen test.vibee

# 4. Проверить
grep -A5 "pub fn real" trinity/output/test.zig

# ОЖИДАЕМ:
# pub fn real() !void {
#     // Real
#
#     // Implementation:
#     return 42;
# }
```

---

**Создатель (Creator) - 2024**
**Статус: Демонстрация готова**