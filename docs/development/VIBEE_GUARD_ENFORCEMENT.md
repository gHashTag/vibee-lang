# 🛡️ VIBEE Guard - Запрет Ручного Кода на Уровне Компилятора

**Принцип**: Только .vibee спецификации! Ручной код запрещен!

## 🎯 Концепция

**VIBEE Guard** - система защиты на уровне компилятора, которая **физически блокирует** создание ручного кода.

### Правило #1: Только .vibee Спецификации
```
✅ РАЗРЕШЕНО:
- src/pollen/**/*.vibee     # Спецификации
- docs/**/*.md              # Документация
- README.md                 # Главный README
- vibee.toml                # Конфигурация
- .gitignore                # Git конфигурация

❌ ЗАПРЕЩЕНО:
- src/modules/**/*.zig      # Ручной код
- src/lib/**/*.gleam        # Ручной код
- src/**/*.rs               # Ручной код
- src/**/*.ts               # Ручной код
```

### Правило #2: Сгенерированный Код Только в storage/
```
✅ РАЗРЕШЕНО:
- src/storage/zig/**/*.zig  # Сгенерированный код

❌ ЗАПРЕЩЕНО:
- src/modules/**/*.zig      # Ручной код в modules
- src/lib/**/*.zig          # Ручной код в lib
```

## 🏗️ Архитектура Защиты

### 4 Уровня Защиты

```
Level 1: File System Watcher
    ↓
Level 2: Git Pre-commit Hook
    ↓
Level 3: IDE Integration
    ↓
Level 4: CI/CD Check
```

## 📝 Спецификация

### vibee_guard/spec.vibee

**Возможности**:
- File system watcher - блокирует создание файлов
- Git pre-commit hook - блокирует коммиты
- IDE integration - блокирует сохранение
- Repository scanner - находит нарушения

## 🔒 Level 1: File System Watcher

### Как Работает

```bash
# Запустить guard в фоне
vibee guard watch &

# Попытка создать ручной код
echo "pub fn main() {}" > src/modules/manual.zig

# ❌ ЗАБЛОКИРОВАНО!
Error: Manual code forbidden!
File: src/modules/manual.zig
Use: vibee gen spec.vibee instead
```

### Конфигурация

```toml
# vibee.toml
[guard]
enabled = true
strict_mode = true

# Разрешенные расширения
allowed_extensions = [".vibee", ".md", ".toml", ".json", ".yaml"]

# Разрешенные пути
allowed_paths = [
  "src/pollen/",
  "docs/",
  "README.md",
  "vibee.toml"
]

# Исключения (для миграции)
exceptions = [
  "src/archive/",
  ".archive/"
]
```

### Автозапуск

```bash
# Добавить в .bashrc или .zshrc
if [ -f vibee.toml ]; then
  vibee guard watch --daemon &
fi
```

## 🔒 Level 2: Git Pre-commit Hook

### Установка

```bash
vibee guard install-hooks
```

**Создает**: `.git/hooks/pre-commit`

### Как Работает

```bash
# Попытка закоммитить ручной код
git add src/modules/manual.zig
git commit -m "add manual code"

# ❌ ЗАБЛОКИРОВАНО!
🛡️ VIBEE Guard: Manual code detected!

Blocked files:
  - src/modules/manual.zig (manual Zig code)

✅ Allowed:
  - Only .vibee specs in src/pollen/
  - Documentation in docs/
  - Generated code in src/storage/

💡 Suggestion:
  Create spec: src/pollen/manual/spec.vibee
  Generate: vibee gen src/pollen/manual/spec.vibee

Commit blocked!
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Запустить VIBEE Guard
vibee guard validate-commit

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Commit blocked by VIBEE Guard!"
  echo "Only .vibee specs allowed!"
  exit 1
fi
```

## 🔒 Level 3: IDE Integration

### VSCode Extension

**Файл**: `.vscode/settings.json`

```json
{
  "vibee.guard.enabled": true,
  "vibee.guard.strictMode": true,
  "vibee.guard.blockSave": true,
  
  "files.watcherExclude": {
    "src/modules/**/*.zig": true,
    "src/lib/**/*.zig": true
  },
  
  "files.readonlyInclude": {
    "src/storage/**": true
  }
}
```

### Как Работает

```
User пытается создать manual.zig
    ↓
VSCode Extension перехватывает
    ↓
Вызывает vibee guard validate
    ↓
❌ Блокирует сохранение
    ↓
Показывает ошибку:
"Manual code forbidden! Use .vibee specs"
```

### Автодополнение

Вместо создания `.zig` файла, VSCode предлагает:

```
💡 Create .vibee spec instead?

  [Create spec.vibee]  [Learn more]  [Cancel]
```

## 🔒 Level 4: CI/CD Check

### GitHub Actions

**Файл**: `.github/workflows/guard.yml`

```yaml
name: VIBEE Guard

on: [push, pull_request]

jobs:
  guard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install VIBEE
        run: |
          curl -sSL https://vibee.dev/install.sh | sh
          
      - name: Run VIBEE Guard
        run: |
          vibee guard scan --strict
          
      - name: Block if violations found
        run: |
          if [ $? -ne 0 ]; then
            echo "❌ Manual code detected!"
            exit 1
          fi
```

### Результат

```
❌ CI Failed: VIBEE Guard

Manual code detected:
  - src/modules/manual.zig
  - src/lib/helper.gleam

Only .vibee specs allowed!

Create specs:
  - src/pollen/manual/spec.vibee
  - src/pollen/helper/spec.vibee
```

## 📊 Команды

### Запуск Guard

```bash
# Watch mode (блокирует в реальном времени)
vibee guard watch

# Daemon mode (фоновый процесс)
vibee guard watch --daemon

# Остановить
vibee guard stop
```

### Сканирование

```bash
# Сканировать весь проект
vibee guard scan

# Строгий режим (exit 1 если нарушения)
vibee guard scan --strict

# Сканировать конкретную директорию
vibee guard scan src/modules/

# Показать детали
vibee guard scan --verbose
```

### Git Hooks

```bash
# Установить pre-commit hook
vibee guard install-hooks

# Удалить hook
vibee guard uninstall-hooks

# Проверить commit вручную
vibee guard validate-commit
```

### IDE Integration

```bash
# Установить VSCode extension
vibee guard install-vscode

# Настроить IDE
vibee guard setup-ide --ide vscode
```

## 📋 Отчеты

### Scan Report

```bash
$ vibee guard scan

🛡️ VIBEE Guard - Repository Scan

📊 Statistics:
  Total files: 1,234
  .vibee specs: 45
  Generated code: 890
  Documentation: 120
  
❌ Violations found: 3

1. src/modules/manual.zig
   Type: Manual code
   Severity: Critical
   Message: Manual Zig code in modules/
   Suggestion: Create src/pollen/manual/spec.vibee

2. src/lib/helper.gleam
   Type: Manual code
   Severity: Critical
   Message: Manual Gleam code in lib/
   Suggestion: Create src/pollen/helper/spec.vibee

3. src/storage/manual_edit.zig
   Type: Manual edit of generated code
   Severity: High
   Message: Generated code was manually edited
   Suggestion: Update spec and regenerate

💡 Suggestions:
  - Run: vibee guard fix --auto
  - Create missing specs
  - Regenerate code

❌ Repository not clean!
```

### Auto-fix

```bash
$ vibee guard fix --auto

🛡️ VIBEE Guard - Auto-fix

Fixing violations...

1. src/modules/manual.zig
   ✅ Created spec: src/pollen/manual/spec.vibee
   ✅ Generated code: src/storage/zig/manual.zig
   ✅ Moved to archive: src/archive/manual.zig.bak

2. src/lib/helper.gleam
   ✅ Created spec: src/pollen/helper/spec.vibee
   ✅ Generated code: src/storage/zig/helper.zig
   ✅ Moved to archive: src/archive/helper.gleam.bak

3. src/storage/manual_edit.zig
   ⚠️  Manual review needed
   Suggestion: Check diff and update spec

✅ Fixed: 2/3 violations
⚠️  Manual review: 1

Run: vibee guard scan
```

## 🎯 Workflow

### Правильный Workflow

```bash
# 1. Создать спецификацию
vim src/pollen/my_module/spec.vibee

# 2. Сгенерировать код
vibee gen src/pollen/my_module/spec.vibee

# 3. Скомпилировать
vibee build

# 4. Закоммитить ТОЛЬКО спецификацию
git add src/pollen/my_module/spec.vibee
git commit -m "add: my_module spec"

# ✅ Успешно!
```

### Неправильный Workflow (Заблокирован!)

```bash
# 1. Попытка создать ручной код
vim src/modules/my_module.zig

# ❌ ЗАБЛОКИРОВАНО File System Watcher!
Error: Manual code forbidden!

# 2. Попытка закоммитить
git add src/modules/my_module.zig
git commit -m "add manual code"

# ❌ ЗАБЛОКИРОВАНО Pre-commit Hook!
Commit blocked by VIBEE Guard!

# 3. Попытка push
git push

# ❌ ЗАБЛОКИРОВАНО CI/CD!
CI Failed: Manual code detected
```

## 🔧 Конфигурация

### Строгий Режим

```toml
[guard]
strict_mode = true

# Блокировать все, кроме .vibee
block_all_code = true

# Блокировать редактирование сгенерированного кода
block_generated_edits = true

# Автоматически удалять нарушения
auto_delete = false  # Осторожно!
```

### Режим Миграции

```toml
[guard]
strict_mode = false

# Разрешить существующий код
allow_existing = true

# Только предупреждения
warnings_only = true

# Исключения
exceptions = [
  "src/archive/",
  "src/legacy/"
]
```

### Кастомные Правила

```toml
[guard.rules]
# Разрешить README в модулях
allow_readme = true

# Разрешить тесты (временно)
allow_tests = true
allow_test_extensions = [".test.zig"]

# Разрешить конфигурацию
allow_config = true
allow_config_extensions = [".toml", ".json", ".yaml"]
```

## 📈 Метрики

### Dashboard

```bash
vibee guard dashboard
```

**Показывает**:
- Количество .vibee спецификаций
- Количество сгенерированного кода
- Нарушения за последние 7 дней
- Топ нарушителей (файлы)
- Compliance score (0-100%)

### Compliance Score

```
100% - Идеально! Только .vibee спецификации
90-99% - Отлично! Минимум нарушений
80-89% - Хорошо, но есть нарушения
70-79% - Требуется внимание
<70% - Критично! Много ручного кода
```

## 🎓 Обучение

### Для Новых Разработчиков

```bash
# Интерактивный туториал
vibee guard tutorial

# Показывает:
# 1. Почему только .vibee
# 2. Как создать спецификацию
# 3. Как сгенерировать код
# 4. Что делать при ошибках
```

### Подсказки

```bash
# При попытке создать ручной код
❌ Error: Manual code forbidden!

💡 Did you mean to:
  1. Create spec: src/pollen/my_module/spec.vibee
  2. Generate code: vibee gen src/pollen/my_module/spec.vibee
  3. Learn more: vibee guard help

📚 Tutorial: vibee guard tutorial
```

## 🚀 Преимущества

### 1. Гарантированная Консистентность
Весь код генерируется из спецификаций - нет расхождений.

### 2. Автоматическая Документация
Спецификации = документация. Всегда актуальна.

### 3. Легкая Миграция
Изменил спецификацию → регенерировал код. Готово!

### 4. Безопасность
Невозможно случайно добавить ручной код.

### 5. Code Review
Ревьюить спецификации проще, чем код.

### 6. Обучение
Новые разработчики сразу учатся правильному workflow.

## 📊 Статистика

**До VIBEE Guard**:
- Ручной код: 80%
- Сгенерированный: 20%
- Расхождения: Часто
- Документация: Устаревшая

**После VIBEE Guard**:
- Ручной код: 0%
- Сгенерированный: 100%
- Расхождения: Невозможны
- Документация: Всегда актуальна

---

**VIBEE Guard - физическая защита от ручного кода! 🛡️**
