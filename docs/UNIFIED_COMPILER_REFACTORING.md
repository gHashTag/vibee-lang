# UNIFIED COMPILER REFACTORING v53000

## Проблема: Дублирование логики

До рефакторинга в `src/vibeec/` было много дублирующихся компонентов:

### Парсеры (4 версии)
| Файл | Строк | Функций | Статус |
|------|-------|---------|--------|
| vibee_parser.zig | 1,331 | 40 | Главный |
| parser_v3.zig | 625 | 12 | Legacy |
| simd_parser_v2.zig | 465 | 12 | WIP |
| simd_parser_igla.zig | 76 | 0 | Stub |

### Кодогенераторы (6 версий)
| Файл | Строк | Функций | Статус |
|------|-------|---------|--------|
| zig_codegen.zig | 712 | 39 | Главный |
| codegen_v4.zig | 616 | 30 | Legacy |
| codegen_wasm.zig | 468 | 30 | WIP |
| ml_codegen_igla.zig | 536 | 25 | WIP |
| auto_codegen.zig | 409 | 22 | Active |
| spec_generator.zig | 325 | - | Active |

### Компиляторы (2 версии)
| Файл | Строк | Статус |
|------|-------|--------|
| compiler.zig | 799 | Главный |
| spec_compiler.zig | 572 | Active |

**Итого: 5,000+ строк дублирующегося кода**

## Решение: Единая спецификация

Создана единая `.vibee` спецификация `unified_compiler_v53000.vibee`:

### Объединённые типы (17)

```
CORE:
- CompilerConfig
- SourceFile

PARSER (unified):
- Token
- ParsedSpec
- TypeDefinition
- FieldDefinition
- BehaviorDefinition
- ParseMetrics

CODEGEN (unified):
- CodegenTarget
- GeneratedCode
- CodegenMetrics
- CodeBuffer

OPTIMIZER (unified):
- OptimizationPass
- OptimizationResult

COMPILER (unified):
- CompilationUnit
- CompilationResult
- CompilerState
```

### Объединённые behaviors (18)

```
PARSER:
- tokenize
- tokenize_simd
- parse_spec
- parse_types
- parse_behaviors

CODEGEN:
- generate_code
- generate_zig
- generate_wasm
- generate_structs
- generate_functions
- generate_tests

OPTIMIZER:
- optimize
- apply_dce
- apply_inlining

COMPILER:
- compile
- compile_incremental
- compile_parallel
- validate_output
```

## Результат

### Сгенерированный файл
```
trinity/output/unified_compiler_v53000.zig
- 350 строк
- 17 типов
- 18 behaviors
- 19 тестов
```

### Тесты
```
19/19 tests passed (100%)
```

## Архитектура

```
┌─────────────────────────────────────────────────────────────────────┐
│                    unified_compiler_v53000.vibee                    │
│                         (ЕДИНАЯ СПЕЦИФИКАЦИЯ)                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    unified_compiler_v53000.zig                      │
│                      (СГЕНЕРИРОВАННЫЙ КОД)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   PARSER    │  │   CODEGEN   │  │  OPTIMIZER  │  │  COMPILER  │ │
│  │             │  │             │  │             │  │            │ │
│  │ - tokenize  │  │ - gen_zig   │  │ - optimize  │  │ - compile  │ │
│  │ - parse     │  │ - gen_wasm  │  │ - dce       │  │ - incr     │ │
│  │ - simd      │  │ - gen_tests │  │ - inline    │  │ - parallel │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Преимущества

1. **Единая точка истины** - одна спецификация вместо 10+ файлов
2. **Нет дублирования** - каждый тип и behavior определён один раз
3. **Автогенерация** - код генерируется из спецификации
4. **Тестируемость** - 19 автоматических тестов
5. **Расширяемость** - легко добавить новые targets

## Миграция

Старые файлы в `src/vibeec/` остаются для обратной совместимости.
Новая разработка должна использовать `unified_compiler_v53000`.

## φ² + 1/φ² = 3 | PHOENIX = 999
