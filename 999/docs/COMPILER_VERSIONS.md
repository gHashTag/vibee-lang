# Сравнительная таблица версий компилятора 999

## Обзор версий

| Версия | Файл | Описание | Уровень |
|--------|------|----------|---------|
| v1 | `compiler.999` | Базовый компилятор | Учебный |
| v2 | `compiler_v2.999` | SSA + оптимизации | Продвинутый |
| v3 | `compiler_v3.999` | Полный оптимизирующий компилятор | Production |

## Детальное сравнение

### Архитектура

| Компонент | v1 | v2 | v3 |
|-----------|----|----|-----|
| IR | Линейная | SSA | MLIR-подобная |
| Уровни IR | 1 | 1 | 3 (HIR/MIR/LIR) |
| Диалекты | - | - | core, arith, cf, memref, vector |

### Оптимизации

| Оптимизация | v1 | v2 | v3 |
|-------------|----|----|-----|
| Constant folding | ✅ | ✅ | ✅ |
| Dead code elimination | ✅ | ✅ | ✅ |
| Common subexpression | - | ✅ | ✅ |
| Copy propagation | - | ✅ | ✅ |
| Strength reduction | - | ✅ | ✅ |
| Loop invariant motion | - | ✅ | ✅ |
| Inlining | - | ✅ | ✅ |
| Tail call optimization | - | ✅ | ✅ |
| Loop unrolling | - | - | ✅ |
| Loop tiling | - | - | ✅ |
| Loop fusion | - | - | ✅ |
| Loop interchange | - | - | ✅ |
| Polyhedral | - | - | ✅ |
| Auto-vectorization | - | - | ✅ |
| Superoptimization | - | - | ✅ |
| ML-guided | - | - | ✅ |
| Escape analysis | - | - | ✅ |

### Анализы

| Анализ | v1 | v2 | v3 |
|--------|----|----|-----|
| Типов | Базовый | Полный | Полный |
| Потока данных | - | ✅ | ✅ |
| Зависимостей | - | - | ✅ |
| Alias analysis | - | - | ✅ |
| Escape analysis | - | - | ✅ |

### Целевые платформы

| Платформа | v1 | v2 | v3 |
|-----------|----|----|-----|
| Интерпретатор | ✅ | ✅ | ✅ |
| x86-64 | - | ✅ | ✅ |
| ARM64 | - | ✅ | ✅ |
| RISC-V | - | - | ✅ |
| WASM | - | - | ✅ |
| SIMD (AVX) | - | - | ✅ |
| SIMD (NEON) | - | - | ✅ |
| Троичный | ✅ | ✅ | ✅ |

### Производительность (относительно v1)

| Метрика | v1 | v2 | v3 |
|---------|----|----|-----|
| Время компиляции | 1x | 1.5x | 2x |
| Скорость кода | 1x | 3x | 10x |
| Размер кода | 1x | 0.8x | 0.6x |

## Файлы компилятора v3

```
src/999/
├── compiler_v3.999      # Главный модуль компилятора
├── mlir.999             # MLIR-подобная многоуровневая IR
├── polyhedral.999       # Polyhedral оптимизации циклов
├── autovectorize.999    # Auto-vectorization (SIMD)
├── superopt.999         # Superoptimizer
├── mlopt.999            # ML-guided оптимизации
├── escape.999           # Escape analysis
├── pgo.999              # Profile-guided optimization
├── lto.999              # Link-time optimization
├── parallel.999         # Автораспараллеливание (OpenMP-style)
└── gpu.999              # GPU кодогенерация (CUDA/OpenCL)
```

## Рекомендации по использованию

- **v1**: Изучение основ компиляции
- **v2**: Практические проекты
- **v3**: Исследования, высокопроизводительные вычисления

## CLI использование v3

```bash
# Базовая компиляция
999c program.999 -o program

# Максимальная оптимизация
999c -O3 -flto -fvectorize program.999 -o program_fast

# С PGO (двухэтапная компиляция)
999c -fprofile-gen program.999 -o program_instrumented
./program_instrumented < training_data.txt
999c -O3 -fprofile-use=profile.pgo program.999 -o program_pgo

# GPU offloading
999c -O3 -fcuda matrix.999 -o matrix_gpu

# Автораспараллеливание
999c -O3 -fopenmp parallel.999 -o parallel

# WebAssembly
999c --target=wasm32 app.999 -o app.wasm
```

## Roadmap

### v4 (планируется)
- Инкрементальная компиляция
- Распределённая компиляция (distcc-style)
- Формальная верификация оптимизаций
- Квантовые алгоритмы (экспериментально)
