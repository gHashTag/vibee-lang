# 🚀 VIBEE INIT - План Реализации

**Цель**: Автоматизировать все что мы сделали вручную!

## 📋 Что Автоматизировать

### 1. Создание Структуры
```bash
vibee init
```
**Создает**:
- `src/pollen/` - спецификации
- `src/storage/` - сгенерированный код
- `src/modules/` - функциональные модули
- `src/lib/` - библиотеки
- `src/tooling/` - инструменты
- `docs/` - документация

### 2. Организация Проекта
```bash
vibee organize
```
**Делает**:
- Находит дубликаты
- Объединяет похожие модули
- Перемещает в правильные места
- Архивирует старый код
- Удаляет пустые директории

### 3. VSCode Расширение
```bash
vibee init --vscode
```
**Настраивает**:
- Иконку для .vibee файлов (🐝)
- Подсветку синтаксиса
- LSP интеграцию
- Автодополнение

## 🏗️ Архитектура CLI

### Структура vibee

```
vibee/
├── src/
│   ├── main.zig              # Entry point
│   ├── cli/
│   │   ├── init.zig          # vibee init
│   │   ├── organize.zig      # vibee organize
│   │   ├── gen.zig           # vibee gen
│   │   ├── build.zig         # vibee build
│   │   ├── watch.zig         # vibee watch
│   │   └── doctor.zig        # vibee doctor
│   │
│   ├── core/
│   │   ├── scanner.zig       # Сканирование проекта
│   │   ├── classifier.zig    # Классификация файлов
│   │   ├── organizer.zig     # Организация структуры
│   │   └── merger.zig        # Объединение дубликатов
│   │
│   ├── templates/
│   │   ├── project.zig       # Шаблон проекта
│   │   ├── vibee_toml.zig    # vibee.toml
│   │   ├── gitignore.zig     # .gitignore
│   │   └── readme.zig        # README.md
│   │
│   └── vscode/
│       ├── extension.zig     # VSCode расширение
│       └── settings.zig      # VSCode настройки
│
└── build.zig
```

## 📝 Спецификации

### 1. vibee_cli/spec.vibee
✅ Создана: `src/pollen/vibee_cli/spec.vibee`

**Содержит**:
- `init_project` - инициализация
- `organize_project` - организация
- `generate_code` - генерация
- `watch_mode` - watch режим
- `build_project` - компиляция
- `doctor_check` - диагностика

### 2. vibee_organizer/spec.vibee
**Нужно создать**:
- Алгоритм сканирования
- Правила классификации
- Логика объединения
- Архивирование

### 3. vibee_templates/spec.vibee
**Нужно создать**:
- Шаблоны проектов
- Конфигурационные файлы
- Примеры спецификаций

## 🔄 Алгоритм vibee organize

### Шаг 1: Сканирование
```zig
pub fn scan_project(path: []const u8) !ProjectStructure {
    var structure = ProjectStructure.init();
    
    // Рекурсивно сканировать директории
    var walker = try std.fs.walkDir(path);
    while (try walker.next()) |entry| {
        if (entry.kind == .Directory) {
            try structure.addDirectory(entry.path);
        } else if (entry.kind == .File) {
            try structure.addFile(entry.path);
        }
    }
    
    return structure;
}
```

### Шаг 2: Классификация
```zig
pub fn classify_directory(path: []const u8) DirectoryType {
    // Проверить содержимое
    if (contains_vibee_files(path)) return .Pollen;
    if (is_generated_code(path)) return .Storage;
    if (is_functional_module(path)) return .Module;
    if (is_library(path)) return .Library;
    if (is_tooling(path)) return .Tooling;
    if (is_old_code(path)) return .Archive;
    
    return .Unknown;
}
```

### Шаг 3: Поиск Дубликатов
```zig
pub fn find_duplicates(structure: ProjectStructure) ![]DuplicatePair {
    var duplicates = std.ArrayList(DuplicatePair).init(allocator);
    
    // Известные дубликаты
    const known_pairs = [_][]const []const u8{
        &[_][]const u8{"telegram", "telegram_bot"},
        &[_][]const u8{"data", "database"},
        &[_][]const u8{"docs", "documentation"},
        &[_][]const u8{"tools", "tooling"},
    };
    
    for (known_pairs) |pair| {
        if (structure.hasDirectory(pair[0]) and 
            structure.hasDirectory(pair[1])) {
            try duplicates.append(DuplicatePair{
                .first = pair[0],
                .second = pair[1],
            });
        }
    }
    
    return duplicates.toOwnedSlice();
}
```

### Шаг 4: Объединение
```zig
pub fn merge_directories(src: []const u8, dst: []const u8) !void {
    // Создать целевую директорию
    try std.fs.makeDirAbsolute(dst);
    
    // Скопировать все файлы
    var walker = try std.fs.walkDir(src);
    while (try walker.next()) |entry| {
        const rel_path = entry.path[src.len..];
        const dst_path = try std.fs.path.join(allocator, &[_][]const u8{dst, rel_path});
        
        if (entry.kind == .File) {
            try std.fs.copyFileAbsolute(entry.path, dst_path, .{});
        }
    }
    
    // Переместить оригинал в архив
    const archive_path = try std.fmt.allocPrint(
        allocator, 
        "src/archive/{s}_original", 
        .{std.fs.path.basename(src)}
    );
    try std.fs.renameAbsolute(src, archive_path);
}
```

### Шаг 5: Организация
```zig
pub fn organize_project(dry_run: bool) !OrganizeResult {
    var result = OrganizeResult{};
    
    // 1. Сканировать
    const structure = try scan_project("src");
    result.dirs_before = structure.directory_count;
    
    // 2. Найти проблемы
    const empty_dirs = try find_empty_directories(structure);
    const duplicates = try find_duplicates(structure);
    const misplaced = try find_misplaced_files(structure);
    
    if (dry_run) {
        // Показать что будет сделано
        print_organize_plan(empty_dirs, duplicates, misplaced);
        return result;
    }
    
    // 3. Удалить пустые
    for (empty_dirs) |dir| {
        try std.fs.deleteTreeAbsolute(dir);
        result.removed += 1;
    }
    
    // 4. Объединить дубликаты
    for (duplicates) |pair| {
        const target = get_merge_target(pair);
        try merge_directories(pair.first, target);
        try merge_directories(pair.second, target);
        result.merged += 1;
    }
    
    // 5. Переместить модули
    try move_to_modules(structure);
    try move_to_lib(structure);
    try move_to_archive(structure);
    
    // 6. Финальное сканирование
    const final_structure = try scan_project("src");
    result.dirs_after = final_structure.directory_count;
    result.archived = count_archived_dirs();
    
    return result;
}
```

## 📦 Шаблоны

### vibee.toml
```zig
const VIBEE_TOML_TEMPLATE =
    \\[project]
    \\name = "{s}"
    \\version = "0.1.0"
    \\authors = ["Your Name <you@example.com>"]
    \\
    \\[compiler]
    \\target = "{s}"
    \\optimization = "ReleaseFast"
    \\features = ["InlineSmallFunctions", "UnrollLoops", "VectorizeLoops"]
    \\
    \\[paths]
    \\specs = "src/pollen"
    \\output = "src/storage"
    \\modules = "src/modules"
    \\lib = "src/lib"
    \\tooling = "src/tooling"
    \\archive = "src/archive"
    \\
    \\[organization]
    \\auto_organize = true
    \\merge_duplicates = true
    \\archive_old = true
    \\clean_empty = true
    \\
    \\[vscode]
    \\install_extension = true
    \\icon_theme = "vibee-icons"
    \\
    \\[git]
    \\auto_init = true
    \\ignore_generated = true
;

pub fn generate_vibee_toml(name: []const u8, target: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(
        allocator,
        VIBEE_TOML_TEMPLATE,
        .{name, target}
    );
}
```

### .gitignore
```zig
const GITIGNORE_TEMPLATE =
    \\# VIBEE Generated Code
    \\src/storage/
    \\
    \\# Build artifacts
    \\zig-cache/
    \\zig-out/
    \\*.o
    \\*.so
    \\*.dylib
    \\*.exe
    \\
    \\# IDE
    \\.vscode/
    \\.idea/
    \\*.swp
    \\
    \\# OS
    \\.DS_Store
    \\Thumbs.db
;
```

### README.md
```zig
const README_TEMPLATE =
    \\# {s}
    \\
    \\VIBEE project initialized with `vibee init`.
    \\
    \\## Quick Start
    \\
    \\```bash
    \\# Generate code from specs
    \\vibee gen src/pollen/examples/hello.vibee
    \\
    \\# Build project
    \\vibee build
    \\
    \\# Watch mode
    \\vibee watch
    \\```
    \\
    \\## Structure
    \\
    \\```
    \\src/
    \\├── pollen/      # Specifications (.vibee)
    \\├── storage/     # Generated code
    \\├── modules/     # Functional modules
    \\├── lib/         # Libraries
    \\└── tooling/     # Development tools
    \\```
    \\
    \\## Documentation
    \\
    \\See `docs/` for more information.
;
```

## 🎯 Примеры Спецификаций

### hello.vibee
```yaml
name: hello
version: "1.0.0"
language: zig
module: hello
target: hello.zig

behaviors:
  - name: greet
    given: Name provided
    when: greet function called
    then: Greeting message returned
    test_cases:
      - name: greet_alice
        input: {name: "Alice"}
        expected: {message: "Hello, Alice!"}

types:
  Greeting:
    message: String

functions:
  - name: greet
    params: {name: String}
    returns: Greeting

imports:
  - std
```

### counter.vibee
```yaml
name: counter
version: "1.0.0"
language: zig
module: counter
target: counter.zig

behaviors:
  - name: increment
    given: Counter state
    when: increment called
    then: Counter increased by 1
    test_cases:
      - name: increment_from_zero
        input: {count: 0}
        expected: {count: 1}

types:
  Counter:
    count: Int

functions:
  - name: increment
    params: {counter: Counter}
    returns: Counter
    
  - name: decrement
    params: {counter: Counter}
    returns: Counter
    
  - name: reset
    params: {counter: Counter}
    returns: Counter

imports:
  - std
```

## 🚀 Roadmap

### Week 1: Core CLI
- [ ] Создать `vibee` CLI структуру
- [ ] Реализовать `vibee init`
- [ ] Реализовать `vibee gen`
- [ ] Создать шаблоны проектов

### Week 2: Auto-Organization
- [ ] Реализовать `vibee organize`
- [ ] Алгоритм сканирования
- [ ] Классификация директорий
- [ ] Объединение дубликатов
- [ ] Архивирование

### Week 3: Advanced Features
- [ ] Реализовать `vibee watch`
- [ ] Реализовать `vibee doctor`
- [ ] VSCode интеграция
- [ ] Документация

## ✅ Следующие Шаги

1. **Сгенерировать vibee CLI**:
```bash
./vibee_gen_v2.sh src/pollen/vibee_cli/spec.vibee src/storage/zig/vibee_cli/
```

2. **Скомпилировать**:
```bash
cd src/storage/zig/vibee_cli
zig build-exe -O ReleaseFast vibee.zig
```

3. **Установить**:
```bash
cp vibee /usr/local/bin/
```

4. **Тестировать**:
```bash
vibee init test-project
cd test-project
vibee organize
```

---

**Автоматизация начинается! 🚀**
