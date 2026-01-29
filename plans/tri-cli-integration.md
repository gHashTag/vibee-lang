# План интеграции .tri формата в VIBEE CLI

## Обзор

Этот план описывает интеграцию .tri формата (троичный формат для хранения спецификаций) в CLI компилятора VIBEE. .tri формат использует триты {-1, 0, +1} вместо битов для хранения данных.

## Архитектура

### Компоненты

```
┌─────────────────────────────────────────────────────────────────┐
│                    VIBEE CLI ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  cli_main.zig ──────┐                                         │
│                     │                                         │
│                     ▼                                         │
│  ┌─────────────────────────────┐                             │
│  │   Command Dispatcher         │                             │
│  └─────────────────────────────┘                             │
│                     │                                         │
│         ┌─────────┼─────────┐                               │
│         ▼         ▼         ▼                               │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                       │
│  │ compile │ │   run   │ │ tri_cmd │ ◄─── НОВЫЙ МОДУЛЬ      │
│  └─────────┘ └─────────┘ └─────────┘                       │
│                              │                                 │
│                  ┌───────────┼───────────┐                   │
│                  ▼           ▼           ▼                   │
│           ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│           │ tri_file │ │  tvc_int │ │  bit_    │            │
│           │    _io   │ │  egration│ │  packing │            │
│           └──────────┘ └──────────┘ └──────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Команды .tri CLI

```
./bin/vibee tri <subcommand> [options]

Subcommands:
  init <path>          Инициализировать TVC репозиторий
  create <file>        Создать .tri файл из .vibee
  read <file>          Прочитать .tri файл и декодировать
  commit [-m msg]      Создать коммит в TVC
  log                  Показать историю коммитов
  status               Показать статус репозитория
  diff <file1> <file2> Показать разницу между .tri файлами
  checkout <commit>    Восстановить состояние из коммита
  validate <file>      Валидировать .tri файл
  info <file>          Показать информацию о .tri файле
  encode <text>        Закодировать текст в триты
  decode <trits>       Декодировать триты в текст
  pack <file>          Упаковать триты в байты
  unpack <file>        Распаковать байты в триты
  help                 Показать справку
```

## Детальный план

### Шаг 1: Создать спецификацию tri_cmd.vibee

**Файл:** `specs/tri/tri_cmd.vibee`

**Цель:** Определить интерфейс для всех CLI команд .tri

**Типы:**
- `TriCommand` - enum для всех подкоманд
- `TriArgs` - структура для аргументов команды
- `TriResult` - результат выполнения команды
- `TVCRepository` - состояние TVC репозитория
- `TriFileInfo` - информация о .tri файле
- `CommitInfo` - информация о коммите
- `DiffResult` - результат сравнения файлов

**Behaviors:**
1. `parse_command` - разобрать аргументы CLI
2. `execute_init` - инициализировать TVC репозиторий
3. `execute_create` - создать .tri файл из .vibee
4. `execute_read` - прочитать .tri файл
5. `execute_commit` - создать коммит
6. `execute_log` - показать историю
7. `execute_status` - показать статус
8. `execute_diff` - показать разницу
9. `execute_checkout` - восстановить состояние
10. `execute_validate` - валидировать файл
11. `execute_info` - показать информацию
12. `execute_encode` - закодировать текст
13. `execute_decode` - декодировать триты
14. `execute_pack` - упаковать триты
15. `execute_unpack` - распаковать триты
16. `print_help` - показать справку
17. `handle_error` - обработать ошибку

### Шаг 2: Сгенерировать код из спецификации

**Команда:** `./bin/vibee gen specs/tri/tri_cmd.vibee`

**Ожидаемый результат:** `specs/tri/tri_cmd.vibee.zig` с тестами

### Шаг 3: Протестировать сгенерированный код

**Команда:** `zig test specs/tri/tri_cmd.vibee.zig`

**Ожидаемый результат:** Все тесты проходят

### Шаг 4: Создать файл src/vibeec/tri_cmd.zig

**Файл:** `src/vibeec/tri_cmd.zig`

**Цель:** Реализовать логику всех .tri CLI команд

**Импорты:**
```zig
const std = @import("std");
const tri_format = @import("../../specs/tri/tri_format.vibee.zig");
const tri_file_io = @import("../../specs/tri/tri_file_io.vibee.zig");
const trit_bit_packing = @import("../../specs/tri/trit_bit_packing.vibee.zig");
const tvc_integration = @import("../../specs/tri/tvc_integration.vibee.zig");
const ascii_trit_table = @import("../../specs/tri/ascii_trit_table.vibee.zig");
```

**Функции:**
- `runTriCommand(allocator, args) !void` - главная точка входа
- `handleInit(allocator, path) !void` - инициализация TVC
- `handleCreate(allocator, vibee_file) !void` - создание .tri из .vibee
- `handleRead(allocator, tri_file) !void` - чтение .tri
- `handleCommit(allocator, message) !void` - коммит
- `handleLog(allocator) !void` - история
- `handleStatus(allocator) !void` - статус
- `handleDiff(allocator, file1, file2) !void` - diff
- `handleCheckout(allocator, commit_id) !void` - checkout
- `handleValidate(allocator, file) !void` - валидация
- `handleInfo(allocator, file) !void` - информация
- `handleEncode(allocator, text) !void` - кодирование
- `handleDecode(allocator, trits) !void` - декодирование
- `handlePack(allocator, file) !void` - упаковка
- `handleUnpack(allocator, file) !void` - распаковка
- `printTriHelp() !void` - справка

### Шаг 5: Интегрировать tri_cmd в cli_main.zig

**Изменения в `src/vibeec/cli_main.zig`:**

1. Добавить импорт:
```zig
const tri_cmd = @import("tri_cmd.zig");
```

2. Добавить в enum Command:
```zig
const Command = enum {
    // ... существующие команды ...
    tri_fmt, // .tri формат (отличается от tri - компиляция в .tri)
    // ...
};
```

3. Добавить в parseCommand:
```zig
if (std.mem.eql(u8, arg, "tri-fmt") or std.mem.eql(u8, arg, "tf")) return .tri_fmt;
```

4. Добавить в main() switch:
```zig
.tri_fmt => {
    if (args.len < 3) {
        printError("Missing subcommand for 'tri-fmt'");
        printTriFmtUsage();
        return;
    }
    try tri_cmd.runTriCommand(allocator, args[2..]);
},
```

5. Добавить printTriFmtUsage():
```zig
fn printTriFmtUsage() void {
    std.debug.print(
        \\TRI FORMAT COMMANDS
        \\
        \\Usage: vibee tri-fmt <subcommand> [options]
        \\
        \\Subcommands:
        \\  init <path>          Initialize TVC repository
        \\  create <file>        Create .tri file from .vibee
        \\  read <file>          Read .tri file and decode
        \\  commit [-m msg]      Create TVC commit
        \\  log                  Show commit history
        \\  status               Show repository status
        \\  diff <file1> <file2> Show diff between .tri files
        \\  checkout <commit>    Restore state from commit
        \\  validate <file>      Validate .tri file
        \\  info <file>          Show .tri file information
        \\  encode <text>        Encode text to trits
        \\  decode <trits>       Decode trits to text
        \\  pack <file>          Pack trits to bytes
        \\  unpack <file>        Unpack bytes to trits
        \\  help                 Show this help
        \\
        \\Examples:
        \\  vibee tri-fmt init .tvc
        \\  vibee tri-fmt create specs/tri/tri_format.vibee
        \\  vibee tri-fmt read specs/tri/tri_format.tri
        \\  vibee tri-fmt commit -m "Initial commit"
        \\  vibee tri-fmt log
        \\
    , .{});
}
```

### Шаг 6: Протестировать все команды .tri CLI

**Тестовые сценарии:**
1. Инициализация TVC репозитория
2. Создание .tri файла из .vibee
3. Чтение .tri файла
4. Создание коммита
5. Просмотр истории
6. Просмотр статуса
7. Сравнение файлов
8. Восстановление из коммита
9. Валидация файла
10. Просмотр информации о файле
11. Кодирование текста
12. Декодирование тритов
13. Упаковка тритов
14. Распаковка байтов

## Диаграмма потока данных

```
┌─────────────────────────────────────────────────────────────────┐
│                    .tri FORMAT DATA FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  .vibee файл ──► encode ──► TritStream ──► pack ──► .tri файл │
│       ▲                                                           │
│       │                                                           │
│       └───◄─── decode ──◄── TritStream ──◄─── unpack ──◄───     │
│                                                                 │
│  .tri файл ──► unpack ──► TritStream ──► decode ──► .vibee     │
│       │                                                           │
│       │                                                           │
│       └───► diff ──► TritDiff ──► TVC Commit ──► Akashic      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Зависимости

### Внешние зависимости:
- Нет (только стандартная библиотека Zig)

### Внутренние зависимости:
- `specs/tri/tri_format.vibee.zig` - базовые типы .tri
- `specs/tri/tri_file_io.vibee.zig` - операции с файлами
- `specs/tri/trit_bit_packing.vibee.zig` - упаковка тритов
- `specs/tri/tvc_integration.vibee.zig` - TVC
- `specs/tri/ascii_trit_table.vibee.zig` - таблица кодирования

## Структура файлов

```
vibee-lang/
├── specs/tri/
│   ├── tri_format.vibee              ✓ создан
│   ├── tri_format.vibee.zig          ✓ сгенерирован
│   ├── trit_code_table.vibee        ✓ создан
│   ├── trit_code_table.vibee.zig    ✓ сгенерирован
│   ├── ascii_trit_table.vibee       ✓ создан
│   ├── ascii_trit_table.vibee.zig   ✓ сгенерирован
│   ├── tvc_integration.vibee        ✓ создан
│   ├── tvc_integration.vibee.zig    ✓ сгенерирован
│   ├── tri_file_io.vibee           ✓ создан
│   ├── tri_file_io.vibee.zig       ✓ сгенерирован
│   ├── trit_bit_packing.vibee      ✓ создан
│   ├── trit_bit_packing.vibee.zig  ✓ сгенерирован
│   ├── vibee_cli_tri.vibee         ✓ создан
│   ├── vibee_cli_tri.vibee.zig     ✓ сгенерирован
│   ├── tri_cmd.vibee               ○ будет создан
│   └── tri_cmd.vibee.zig           ○ будет сгенерирован
├── src/vibeec/
│   ├── cli_main.zig                 ○ будет изменен
│   └── tri_cmd.zig                 ○ будет создан
└── .tvc/                           ○ будет создан при инициализации
    ├── commits/
    └── HEAD
```

## Риски и митигация

### Риск 1: Конфликт имен команд
**Проблема:** В `cli_main.zig` уже есть команда `.tri` для компиляции в Trinity Native code.

**Решение:** Использовать `tri-fmt` или `trifmt` для команд работы с .tri форматом.

### Риск 2: Несовместимость с существующим workflow
**Проблема:** .tri формат может нарушить существующий workflow разработки.

**Решение:** .tri формат является опциональным. Существующий workflow с .vibee файлами остается неизменным.

### Риск 3: Производительность
**Проблема:** Кодирование/декодирование тритов может быть медленным.

**Решение:** Использовать SIMD операции для ускорения (будет добавлено позже).

## Следующие шаги

После завершения этого плана:

1. **Реализация REPL для .tri** - интерактивный режим для работы с .tri файлами
2. **Интеграция с FPGA** - использование .tri файлов для FPGA разработки
3. **Оптимизация производительности** - SIMD ускорение операций с тритами
4. **Инструменты визуализации** - графическое отображение тритных потоков
5. **Интеграция с CI/CD** - автоматическое тестирование .tri файлов

## Справка

### .tri формат

**Заголовок (Header):**
- Магическое число: `TRI` (3 трита: +1, 0, -1)
- Версия: 2 трита
- Длина тела: N тритов

**Тело (Body):**
- Поток тритов: закодированные данные
- Кодирование: 5 тритов на символ (3^5 = 243 комбинации)

### TVC (TritaryVC)

Система контроля версий для .tri файлов:
- Хранит только разницы (diffs) между коммитами
- Diff = trit_new - trit_old
- Компактное хранение в Akashic Records

## Заключение

Этот план обеспечивает полную интеграцию .tri формата в VIBEE CLI, позволяя пользователям:
- Создавать и читать .tri файлы
- Управлять версиями через TVC
- Кодировать и декодировать данные
- Упаковывать и распаковывать триты

Все операции следуют принципу specification-first: спецификации создаются в `.vibee`, код генерируется автоматически, а реализация CLI пишется только в `src/vibeec/*`.
