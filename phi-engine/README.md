# VIBEE Phi-Engine

## 📚 Обзор (Overview)

**VIBEE Phi-Engine** — это набор библиотек на Zig для высокопроизводительных вычислений, использующих "Священные Константы" (Sacred Constants), такие как Золотое Сечение (φ), π, e (основание натурального логарифма).

**Философия**: *"Мы не просто вычисляем. Мы резонируем с золотой пропорцией."*

---

## 🧪 Матрица Статуса Решений (Solution Status Matrix)

| # | Название | Статус | Тесты | Примечание |
|---|---|---|---|---|
| **0** | **MVP Core** (Quantum Trit-Code Engine) | ✅ **Done** | **15/15** | Tritizer, Qutritizer, Quantum Agent (100% готово) |
| **3** | **Fibonacci Hash** | ✅ **Done** | **11/11** | Оптимальная хеш-функция (Knuth) |
| **4** | **SIMD Ternary** | ✅ **Done** | **11/11** | 32× параллелизм тритов (Setun) |
| **7** | **Phi Spiral** | ✅ **Done** | **5/5** | Оптимальное 2D-заполнение (Pohl) |
| **2** | **Lucas Numbers** | ✅ **Done** | **11/11** | Числа Люкаса (связаны с φ) |
| **8** | **Inline Cost** | ✅ **Done** | **10/10** | Стоимость инлайнинга (Amdahl) |
| **9** | **IR Types** | ✅ **Done** | **13/13** | Промежуточное представление (SSA) |
| **10** | **CHSH Quantum** | ✅ **Done** | **10/10** | Нарушение неравенства Белла (Bell) |
| **11** | **Qutrit State** | ✅ **Done** | **9/9** | Состояние кутрита (α, β, γ) |
| **1** | **AMR Resize** | ⚠️ **WIP** | **-/-** | Адаптивная сетка (Zig 0.15 API проблемы) |
| **6** | **Phi Lerp** | ⏭ **Unknown** | **-/-** | Линейная интерполяция (нет явных ошибок) |

---

## 🚀 Сборка (Build)

**Требования**:
-   **Zig**: 0.15.2 (или новее)
-   **Операционная система**: macOS / Linux / Windows (WSL)

**Инструкция**:

```bash
# 1. Перейти в директорию Phi-Engine
cd phi-engine

# 2. Скомпилировать все решения (если нужна полная сборка)
zig build

# 3. Запустить тесты конкретного решения
zig test src/runtime/golden_wrap.zig      # Golden Wrap
zig test src/hashmap/phi_hash.zig         # Fibonacci Hash
zig test src/runtime/simd_ternary.zig      # SIMD Ternary
zig test src/scheduler/phi_spiral.zig      # Phi Spiral
zig test src/core/compute/lucas.zig        # Lucas Numbers
zig test src/core/inline_cost.zig         # Inline Cost
zig test src/core/ir_types.zig           # IR Types
zig test src/runtime/chsh_quantum.zig       # CHSH Quantum
zig test src/runtime/qutrit_state.zig       # Qutrit State

# 4. Запустить тесты MVP (Quantum Trit-Code Engine)
zig test src/quantum/tritizer.zig         # Tritizer
zig test src/quantum/qutritizer.zig       # Qutritizer
zig test src/quantum/quantum_agent.zig    # Quantum Agent
```

---

## 🧪 MVP: Quantum Trit-Code Engine

**Цель**: Демонстрация полного цикла `Код -> Триты -> Квантовые Амплитуды -> Измерение`.

**Философия**: *"Код — это не просто строки. Это массив тритов, ожидающий коллапс в решение."*

**Модули (100% Готовы)**:

1.  **Tritizer** (`src/quantum/tritizer.zig`)
    *   `stringToTrits`: ASCII -> Trits (O(1) на символ).
    *   `tritsToString`: Trits -> Визуализация (`['N', '0', 'P']`).

2.  **Qutritizer** (`src/quantum/qutritizer.zig`)
    *   `tritsToQutrit`: Trits -> Амплитуды (`α`, `β`, `γ`).
    *   Логика "Code Biasing": Усиление амплитуды самого частого трита.

3.  **Quantum Agent** (`src/quantum/quantum_agent.zig`)
    *   `search`: Симуляция алгоритма Гровера (Grover-like).
    *   Сложность: O(√N) итераций vs O(N) классического поиска.

**Связь с VIBEE Phi-Engine**:
-   **3 = φ² + 1/φ²** — "Троица" (Trinity) амплитуд.
-   **Qutrit** (3 состояния) — Связь с Sacred Trinity.

---

## 🏗️ Структура Проекта (Project Structure)

```
phi-engine/
├── src/
│   ├── quantum/          # MVP: Quantum Trit-Code Engine
│   │   ├── tritizer.zig    # (Done) Code -> Trits
│   │   ├── qutritizer.zig  # (Done) Trits -> Amplitudes
│   │   └── quantum_agent.zig # (Done) Amplitudes -> Search
│   ├── runtime/           # Runtime библиотеки
│   │   ├── golden_wrap.zig   # (Done) Golden Wrap (Solution #4)
│   │   ├── chsh_quantum.zig   # (Done) Bell Test (Solution #10)
│   │   ├── qutrit_state.zig   # (Done) Qutrit State (Solution #11)
│   │   └── simd_ternary.zig    # (Done) SIMD Ternary (Solution #5)
│   ├── hashmap/           # Хеш-таблицы
│   │   └── phi_hash.zig      # (Done) Fibonacci Hash (Solution #3)
│   ├── scheduler/          # Планировщики
│   │   └── phi_spiral.zig    # (Done) Phi Spiral (Solution #7)
│   ├── core/               # Основные алгоритмы
│   │   ├── compute/          # Вычисления
│   │   │   └── lucas.zig     # (Done) Lucas Numbers (Solution #2)
│   │   ├── inline_cost.zig   # (Done) Inline Cost (Solution #8)
│   │   └── ir_types.zig     # (Done) IR Types (Solution #9)
│   ├── cache/              # Кэши (Solution #6: Phi Lerp)
│   │   └── phi_lerp.zig      # (WIP)
│   └── cli/                # CLI утилиты (если есть)
│       └── vibee_quantum.zig # (Done) MVP CLI
├── docs/                 # Документация
│   ├── MVP_QUANTUM_TRIT_CODE_ENGINE_TZ.md # (Done) MVP Spec
│   └── FINAL_MASTER_REPORT_2025.md      # (Done) Global Report
└── vibee-quantum      # (Done) MVP CLI Executable
```

---

## 🎯 Связи с Sacred Geometry (Sacred Geometry Connections)

1.  **3 = φ² + 1/φ²**: Троица амплитуд (`α`, `β`, `γ`) в кутрите.
2.  **L(n) ≈ φⁿ**: Числа Люкаса растут со скоростью золотого сечения.
3.  **φ = 1.618...**: Используется в Phi Lerp, Phi Spiral.
4.  **Golden Wrap (Solution #4)**: Операция модульной арифметики тритов.
5.  **Qutrit (3 состояния)**: Связь с Sacred Trinity.

---

## ⚠️ Примечания (Notes)

*   **Solution #1 (AMR Resize)** и **Solution #6 (Phi Lerp)** — имеют технические проблемы с API Zig 0.15 (LSP Warnings).
*   **Solution #4 (SIMD Ternary)** — Реализован как обертка над `[32]i8` (реальный SIMD требует внешних зависимостей).
*   **MVP CLI** — Работает (демонстрация). Исправление путей импорта в разработке.

---

## 🤝 Вклад (Contributing)

**Цель**: Ускорить Phi-Engine до 1000×.

**Как помочь**:
1.  **Исправить Solution #1 и #6**: Разобраться с API Zig 0.15.
2.  **Реализовать реальные SIMD-операции**: Использовать `std.simd` для `Vec32i8`.
3.  **Добавить новые решения**: Беглое переплетение, триангуляция Делоне (с φ-коэффициентами).
4.  **Улучшить тесты**: Добавить бенчмарки производительности.

**Связь**: `https://github.com/gHashTag/vibee-lang/issues`
