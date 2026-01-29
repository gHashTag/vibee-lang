# 📋 ПОЛНАЯ КАРТА ИЗМЕНЕНИЙ ДЛЯ СЛЕДУЮЩЕГО АГЕНТА

**СТАТУС:** ✅ АНАЛИЗ ЗАВЕРШЕН | 🚫 РЕАЛИЗАЦИЯ НЕВОЗМОЖНА БЕЗ ПЕРЕСТРОЙКИ
**СЛОЖНОСТЬ:** ⭐⭐⭐⭐⭐ (MAX)
**ВРЕМЯ:** ~4-6 часов полного понимания + 2 часа изменений

---

## ══════════════════════════════════════════════════════════════════════════
## ЧТО НАДО СДЕЛАТЬ (ТОЧНЫЙ ПЛАН)
## ══════════════════════════════════════════════════════════════════════════

### ФАЗА 1: ПОНИМАНИЕ (2 часа)
**Цель:** Понять архитектуру vibee gen

**Шаги:**
1. Изучить `src/vibeec/codegen_v4.zig` (616 строк)
   - Понять структуру `generateZig()` (строки ~252-300)
   - Понять, где вызывается `generateZigTest()` (строка 297)
   - Понять, почему она генерирует только тесты

2. Изучить `src/vibeec/parser_v3.zig` (~1200 строк)
   - Найти `Behavior` struct (строка ~178)
   - Понять, как парсятся `behaviors` из .vibee
   - Понять, почему там нет поля `implementation`

3. Создать блок-схему:
   ```
   .vibee file → parser_v3 → Specification → codegen_v4 → .zig code
                                   (Behavior)
                                        ↓
                                 (no impl field)
                                        ↓
                                 (can only gen tests)
   ```

**Результат:** Понимание, ЧТО именно нужно менять.

---

### ФАЗА 2: ИЗМЕНЕНИЯ ПАРСЕРА (1 час)
**Цель:** Добавить поле `implementation` в Behavior

**Файл:** `src/vibeec/parser_v3.zig`

**Строка ~178-184:**

**СТАРЫЙ КОД:**
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

**НОВЫЙ КОД:**
```zig
pub const Behavior = struct {
    name: []const u8 = "",
    given: []const u8 = "",
    when: []const u8 = "",
    then: []const u8 = "",
    test_cases: ArrayList(TestCase),
    implementation: []const u8 = "", // ← ДОБАВИТЬ ЭТО

    pub fn init(allocator: Allocator) Behavior {
        _ = allocator;
        return .{
            .test_cases = .empty,
            .implementation = "", // ← ДОБАВИТЬ ЭТО
        };
    }
};
```

**ВАЖНО:** Проверить, есть ли еще места, где создается Behavior struct.

---

### ФАЗА 3: ИЗМЕНЕНИЯ ПАРСИНГА (1 час)
**Цель:** Парсить `implementation` из .vibee

**Файл:** `src/vibeec/parser_v3.zig`

**Найти:** Где парсятся `behaviors` (строки ~XXX-YYY)

**ДОБАВИТЬ ЛОГИКУ:**
Когда видишь `- name: behavior_name`, нужно проверять, есть ли после него:
- `implementation: |` (многострочная)
- `implementation: value` (однострочная)

И добавлять в Behavior.

**ПОИСК:**
```bash
grep -n "\"behavior\"" src/vibeec/parser_v3.zig | head -5
```

---

### ФАЗА 4: ИЗМЕНЕНИЯ ГЕНЕРАТОРА (2 часа)
**Цель:** Генерировать функции из `implementation`

**Файл:** `src/vibeec/codegen_v4.zig`

**Строка ~295-299:**

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
// Behaviors with implementations
for (spec.behaviors.items) |behavior| {
    if (behavior.implementation.len > 0) {
        // Generate REAL function from implementation
        try self.generateZigFunction(&behavior);
        self.functions_generated += 1;
    } else {
        // Generate test (fallback)
        try self.generateZigTest(&behavior);
        self.tests_generated += 1;
    }
}
```

**СТРОКА ~389 (после generateZigTest):** Добавить новую функцию:

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

### ФАЗА 5: ПЕРЕСБОРКА (30 минут)
**Цель:** Проверить, что все работает

**Шаги:**
1. `zig build`
2. Если ошибка - откатить изменения
3. Если успех - запустить `vibee gen test.vibee`

---

## ══════════════════════════════════════════════════════════════════════════
## ОЖИДАЕМЫЕ СЛОЖНОСТИ
## ══════════════════════════════════════════════════════════════════════════

### 🚨 СЛОЖНОСТЬ #1: Zig Type System
**Проблема:** Behavior struct используется везде.
**Что может сломаться:**
- Все места, где создается Behavior struct
- Все места, где парсятся .vibee файлы
- Все тесты parser_v3

**Решение:** Поиск + систематические изменения.

---

### 🚨 СЛОЖНОСТЬ #2: Парсинг Многострочных
**Проблема:** `implementation: |` может занимать 10+ строк.
**Что может сломаться:**
- Парсер должен знать, когда заканчивается implementation
- Сложность отступов и форматирования

**Решение:** Использовать state machine (как для многострочных строк).

---

### 🚨 СЛОЖНОСТЬ #3: Обратная Совместимость
**Проблема:** Все существующие .vibee спецификации не имеют implementation.
**Что может сломаться:**
- Старые .vibee файлы должны продолжать работать
- Генератор должен падать gracefully, если implementation нет

**Решение:** Ветка if (behavior.implementation.len > 0).

---

## ══════════════════════════════════════════════════════════════════════════
## КАК ЭТО ПРОВЕРИТЬ
## ══════════════════════════════════════════════════════════════════════════

### ТЕСТ #1: Минимальный Пример
**Создать файл:** `test_true_compilation.vibee`

```yaml
name: test_real_func
version: "1.0.0"
language: zig
module: test_real_func

behaviors:
  - name: add_numbers
    given: Int, Int
    when: Addition
    then: Int
    description: Adds two numbers
    implementation: |
      const a = 10;
      const b = 20;
      return a + b;

constants:
  - PHI: 1.618033988749895
```

**Запустить:**
```bash
vibee gen test_true_compilation.vibee
```

**ОЖИДАЕМЫЙ РЕЗУЛЬТАТ:** `test_real_func.zig` с реальной функцией `add_numbers()`:

```zig
pub fn add_numbers() Int !void {
    // Addition

    // Implementation:
    const a = 10;
    const b = 20;
    return a + b;

}
```

### ТЕСТ #2: Обратная Совместимость
**Запустить:** `vibee gen specs/tri/uroboros_decoder.vibee`

**ОЖИДАЕМЫЙ РЕЗУЛЬТАТ:** Генерируется нормально (implementation нет → генерится test).

---

## ══════════════════════════════════════════════════════════════════════════
## КОМАНДЫ ДЛЯ ОТЛАДКИ
## ══════════════════════════════════════════════════════════════════════════

```bash
# 1. Найти Behavior struct
grep -n "pub const Behavior" src/vibeec/parser_v3.zig

# 2. Найти где парсятся behaviors
grep -n "\"behavior\"" src/vibeec/parser_v3.zig | head -10

# 3. Найти где генерируются тесты
grep -n "generateZigTest" src/vibeec/codegen_v4.zig

# 4. Пересобрать vibee
zig build

# 5. Тестировать
vibee gen test_true_compilation.vibee

# 6. Проверить сгенерированный код
cat trinity/output/test_true_compilation.zig | grep -A10 "pub fn"
```

---

## ══════════════════════════════════════════════════════════════════════════
## КРИТИЧЕСКИЙ РЕЗУЛЬВАТОР
## ══════════════════════════════════════════════════════════════════════════

**Сравнить РЕЗУЛЬТАТЫ:**

| Тест | ДО ( vibee gen ) | ПОСЛЕ ( vibee gen ) |
|------|------------------|------------------------|
| Генерация функций | ❌ Нет (только тесты) | ✅ Да (из implementation) |
| Обратная совместимость | N/A | ✅ Старые .vibee работают |
| Ошибки компиляции | N/A | ✅ Сгенерированный код компилируется |

**ЕСЛИ:**
- ✅ Все три теста пройдены → УСПЕХ
- ❌ Любой тест не прошел → ОТКАТ, изучить ошибку

---

## ══════════════════════════════════════════════════════════════════════════
## ДОПОЛНИТЕЛЬНО: АВТОМАТИЗАЦИЯ
## ══════════════════════════════════════════════════════════════════════════

**ЕСЛИ ВСЁ РАБОТАЕТ:**

Создать скрипт `auto_self_compilation.sh`:

```bash
#!/bin/bash
# ПОЛНАЯ АВТОМАТИЗАЦИЯ САМОПОГЛОЩЕНИЯ

# 1. Поглотить все модули
for module in cli_main compiler coptic_parser vm_runtime; do
  ./bin/uroboros-deep src/vibeec/${module}.zig fossil_${module}.tri
done

# 2. Создать .vibee из fossils
for module in cli_main compiler coptic_parser vm_runtime; do
  ./bin/fossil-to-vibee fossil_${module}.tri ${module}_auto.vibee
done

# 3. Сгенерировать .zig из .vibee
for module in cli_main compiler coptic_parser vm_runtime; do
  vibee gen ${module}_auto.vibee
done

echo "✓ ПОЛНЫЙ ЦИКЛ АВТОМАТИЧЕСКИ ЗАВЕРШЕН"
```

---

## ══════════════════════════════════════════════════════════════════════════
## ЧТОБЫ НЕ ПРОПУСТИТЬ
## ══════════════════════════════════════════════════════════════════════════

1. ❌ НЕ изменять существующие .vibee файлы
   - Они должны работать и после изменений
   - Добавьте implementation в НОВЫЕ .vibee

2. ❌ НЕ удалять поле `test_cases` из Behavior struct
   - Оно нужно для обратной совместимости
   - Сделайте его optional

3. ❌ НЕ забывать про отступы в generateZigFunction
   - Implementation должен быть с правильными отступами
   - Используйте `indent()` и `dedent()`

4. ❌ НЕ пропускать фазу пересборки
   - Изменения должны компилироваться
   - В противном случае - откат

---

## ══════════════════════════════════════════════════════════════════════════
## ОЖИДАЕМЫЕ СТАТУСЫ И ДЕЙСТВИЯ
## ══════════════════════════════════════════════════════════════════════════

### СТАТУС #1: ПОНИМАНИЕ (2 часа)
**ДЕЙСТВИЯ:**
- Чтение `codegen_v4.zig` и `parser_v3.zig`
- Создание блок-схемы
- Отсутствие изменений кода

**ПРОВЕРКА:** Объяснить, ЧТО и ГДЕ нужно менять.

### СТАТУС #2: ИЗМЕНЕНИЯ (3 часа)
**ДЕЙСТВИЯ:**
- Добавление `implementation` в Behavior struct
- Изменение парсинга behaviors
- Изменение генерации функций
- Пересборка vibee

**ПРОВЕРКА:** `zig build` + тест на простом примере.

### СТАТУС #3: ДОКАЗАТЕЛЬСТВО (1 час)
**ДЕЙСТВИЯ:**
- Запуск на тестовом .vibee с implementation
- Проверка сгенерированного кода
- Доказательство f(f(x)) = x

**ПРОВЕРКА:** Полный цикл самопоглощения работает.

### СТАТУС #4: УСПЕХ
**ДЕЙСТВИЯ:**
- Автоматизация на всех модулях
- Интеграция с существующим vibeec
- Создание Бога (или хотя бы демона).

**ПРОВЕРКА:** Все модули самопоглощены.

---

## ══════════════════════════════════════════════════════════════════════════
## ФИНАЛЬНАЯ РЕКОМЕНДАЦИЯ
## ══════════════════════════════════════════════════════════════════════════

**ПОСЛЕДУЮЩЕМУ АГЕНТУ:**

1. **НЕ создавай новых инструментов.** (Uroboros, ast-extractor - все это уже есть)
2. **НЕ пытайся обойти vibee gen.** (Это невозможно, это часть системы)
3. **ИЗМЕНИ vibee gen ИЗНУТРИ.** (Единственный реальный путь)
4. **СЛЕДУЙ КАРТЕ.** (Все изменения заданы точно)
5. **БУДЬ ПАЦИЕНТНЫМ.** (Это займет 4-6 часов, а не 2 часа)
6. **ДОКАЖИ РЕЗУЛЬТАТЫ.** (Создание нового файла, который доказывает самопоглощение)

**УСПЕХ СЛЕДУЮЩЕГО АГЕНТА:**

| Метрика | Требуется | Уверенность |
|---------|-----------|-------------|
| Понимание системы | 80% | 90% (есть карта) |
| Изменение парсера | 90% | 70% (просто) |
| Изменение генератора | 80% | 60% (сложнее) |
| Интеграция | 70% | 50% (много краев) |
| **ИТОГ** | **75%** | **65%** |

**Это ВОЗМОЖНО.** Но это требует полного погружения в существующую систему, а не создания новой вокруг неё.

---

**Создатель (Creator) - 2024**
**Наследие: Полная карта изменений + инструменты + отчеты**
**Статус: Готов для последующего агента**