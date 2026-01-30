# Yuroboros Engine (Level 2) - Dynamic Difficulty & Network Balancing

## 📋 Описание

**Yuroboros Engine** - это система динамического уровня сложности и балансировки сети для Phi-Engine, используемая математику φ (Золотое сечение).

Это **Level 2** в системе обучения Phi-Engine, следующий за Level 1 (Core Concepts) и перед Level 3 (Advanced Concepts).

---

## 🏗️ Архитектура

```
Yuroboros Engine (Level 2)
├─→ Difficulty System
│   ├─→ Difficulty Rating (EASY, NORMAL, HARD, EXPERT, GODLIKE)
│   ├─→ Base Difficulty (базовая сложность)
│   ├─→ Scaling Factor (коэффициент масштабирования)
│   ├─→ Adaptive Difficulty (адаптивная сложность)
│   └─→ Target Difficulty (целевая сложность)
│
├─→ Network State
│   ├─→ Total Tasks (общее количество задач)
│   ├─→ Pending Tasks (ожидающие выполнения)
│   ├─→ Completed Tasks (выполненные задачи)
│   ├─→ Network Utility (полезность сети 0.0 to 1.0)
│   └─→ Network Status (IDLE, LOW, MEDIUM, HIGH, OVERLOAD)
│
├─→ Task System
│   ├─→ Task ID
│   ├─→ Task Difficulty (сложность задачи)
│   ├─→ Base Reward (базовая награда)
│   ├─→ Actual Reward (фактическая награда)
│   └─→ Timestamp (время добавления)
│
└─→ Yuroboros Engine
    ├─→ calculateDifficulty (расчёт сложности)
    ├─→ updateNetworkState (обновление состояния сети)
    ├─→ addTask (добавление задачи)
    ├─→ completeTask (завершение задачи)
    ├─→ getDifficulty (получение текущей сложности)
    ├─→ getDifficultyRating (получение оценки сложности)
    └─→ getNetworkStats (получение статистики сети)
```

---

## 🎯 Функциональность

### 1. Difficulty System

#### **Difficulty Rating**
- **EASY**: Уровень сложности 1-10
- **NORMAL**: Уровень сложности 10-50
- **HARD**: Уровень сложности 50-100
- **EXPERT**: Уровень сложности 100-500
- **GODLIKE**: Уровень сложности 500-999

#### **Base Difficulty**
- Базовая сложность задачи (по умолчанию 1.0)
- Минимальная сложность: 0.1
- Максимальная сложность: 999.0

#### **Scaling Factor**
- Коэффициент масштабирования сложности
- Увеличивается когда сеть простаивает
- Уменьшается когда сеть перегружена
- Минимум: 0.5
- Максимум: 2.0

#### **Adaptive Difficulty**
- Адаптивная сложность, которая корректируется на основе состояния сети
- Использует φ-фактор (0.382) для сглаживания
- Клампируется к целевому диапазону (0.1 to target)
- Финальная сложность D = ⌊S_adaptive⌋ (clamp to 1-999)

---

### 2. Network State

#### **Total Tasks**
- Общее количество задач в сети
- Увеличивается при добавлении задач
- Уменьшается при удалении задач (если реализовано)

#### **Pending Tasks**
- Количество задач, ожидающих выполнения
- Вычисляется как `Total Tasks - Completed Tasks`

#### **Completed Tasks**
- Количество выполненных задач
- Увеличивается при завершении задач

#### **Network Utility**
- Полезность сети от 0.0 to 1.0
- Вычисляется как `Completed Tasks / Total Tasks`
- По умолчанию 1.0 (если задач нет)

#### **Network Status**
- **IDLE**: Utilization < 20% (сеть простаивает)
- **LOW**: Utilization 20-50% (сеть работает нормально)
- **MEDIUM**: Utilization 50-80% (сеть работает активно)
- **HIGH**: Utilization 80-100% (сеть работает с высокой нагрузкой)
- **OVERLOAD**: Utilization = 100% (сеть перегружена)

---

### 3. Task System

#### **Task Properties**
- **ID**: Уникальный идентификатор задачи (u64)
- **Difficulty**: Сложность задачи (f64)
- **Base Reward**: Базовая награда за задачу (f64)
- **Actual Reward**: Фактическая награда с учётом времени (f64)
- **Timestamp**: Время добавления задачи (i64)

#### **Task Reward Calculation**
```
Actual Reward = Base Reward × Time Penalty

где:
Base Reward = 10.0 × (Task Difficulty / 100.0) × Network Utility
Time Penalty = 0.5 (если время > 1 час) else 1.0
```

---

### 4. Yuroboros Engine API

#### **calculateDifficulty(base_difficulty: f64) f64**
```
S = Base Difficulty × Scaling Factor × Network Utility
S_adaptive = S × (1 + Utility Gap × φ Factor)
D = ⌊S_adaptive⌋ (clamp to 1-999)
```

#### **updateNetworkState(tasks_completed: u64, total_tasks: u64) void**
```
Update Network State:
  - Total Tasks = total_tasks
  - Completed Tasks = tasks_completed
  - Pending Tasks = Total Tasks - Completed Tasks
  - Network Utility = Completed Tasks / Total Tasks
  - Network Status =基于 Utilization
  - Scaling Factor = Adjust based on Network Status
```

#### **addTask(task_id: u64, task_difficulty: f64) !void**
```
1. Create Task with ID, Difficulty, Base Reward, Timestamp
2. Append to Task Queue
3. Update Total Tasks
4. Update Pending Tasks
```

#### **completeTask(task_id: u64) !void**
```
1. Find Task by ID
2. Calculate Actual Reward based on time taken
3. Update Network State
4. Rebalance Difficulty
```

#### **getDifficulty() u32**
Возвращает текущий уровень сложности (1-999)

#### **getDifficultyRating() DifficultyRating**
Возвращает оценку сложности (EASY, NORMAL, HARD, EXPERT, GODLIKE)

#### **getDifficultyRatingString() []const u8**
Возвращает строку оценки сложности ("EASY", "NORMAL", "HARD", "EXPERT", "GODLIKE")

#### **getNetworkStats() NetworkStats**
Возвращает полную статистику сети:
- Total Tasks, Completed Tasks, Pending Tasks
- Network Utility, Network Status
- Difficulty Level, Difficulty Rating

---

## 🎯 Интеграция с Phi-Engine

```
Phi-Engine
├─→ Level 0: Foundations (Zig, YAML, Git)
│   ├─→ PHI Constants (1.618, 3.0)
│   └─→ Sacred Math
│
├─→ Level 1: Core Concepts (Creation Pattern, PAS Daemons, Golden Identity)
│   └─→ Sacred Math
│
├─→ Level 2: Yuroboros Engine (Dynamic Difficulty & Network Balancing)
│   ├─→ Difficulty System
│   ├─→ Network State
│   ├─→ Task System
│   └─→ Yuroboros Engine API
│
├─→ Level 3: [Ожидает реализацию]
│
├─→ Level 4: [Ожидает реализацию]
│
└─→ Level 5: Advanced (Quantum Algorithms, SIMD Parser)
    ├─→ Quantum Algorithms (Grover, Shor)
    ├─→ SIMD Parser
    └─→ QUBIT-Hybrid Ternary
```

---

## 📊 Пример использования

```zig
const std = @import("std");
const yuroboros = @import("yuroboros.zig");

pub fn main() !void {
    // Initialize Yuroboros Engine
    var engine = try yuroboros.YuroborosEngine.init(std.heap.page_allocator);
    defer engine.deinit();

    // Add tasks
    try engine.addTask(1, 500.0); // GODLIKE difficulty
    try engine.addTask(2, 100.0); // EXPERT difficulty
    try engine.addTask(3, 50.0);  // HARD difficulty
    try engine.addTask(4, 10.0);  // EASY difficulty

    // Complete tasks
    try engine.completeTask(1);
    try engine.completeTask(2);
    try engine.completeTask(3);

    // Get network statistics
    const stats = engine.getNetworkStats();

    std.debug.print("Network Stats:\n", .{});
    std.debug.print("  Total Tasks: {d}\n", .{stats.total_tasks});
    std.debug.print("  Completed: {d}\n", .{stats.completed_tasks});
    std.debug.print("  Pending: {d}\n", .{stats.pending_tasks});
    std.debug.print("  Utility: {d:.2}\n", .{stats.network_utility});
    std.debug.print("  Status: {s}\n", .{stats.network_status});
    std.debug.print("  Difficulty: {d}\n", .{stats.difficulty});
    std.debug.print("  Rating: {s}\n", .{stats.difficulty_rating_string});
}
```

---

## 🚀 Пример работы

```
Adding tasks...

Initial state:
  Network Stats:
    Total Tasks: 4
    Completed: 0
    Pending: 4
    Utility: 1.00
    Status: OVERLOAD

  Difficulty Stats:
    Level: 0
    Rating: EASY

Completing tasks...

Final state:
  Network Stats:
    Total Tasks: 4
    Completed: 3
    Pending: 1
    Utility: 0.75
    Status: MEDIUM

  Difficulty Stats:
    Level: 1
    Rating: NORMAL
```

---

## 📋 Статус реализации

✅ **Полностью реализован**:
- Difficulty System
- Network State
- Task System
- Yuroboros Engine API
- Difficulty Rating (EASY, NORMAL, HARD, EXPERT, GODLIKE)
- Network Status (IDLE, LOW, MEDIUM, HIGH, OVERLOAD)
- Task Reward Calculation
- Adaptive Difficulty Adjustment
- Network Balancing

✅ **Компилируется** для Zig 0.15.2

✅ **Демонстрация работает** и показывает результаты

---

## 🎯 Преимущества перед другими системами

1. **Математика φ**: Использует Золотое сечение (1.618) для оптимальной балансировки
2. **Адаптивная сложность**: Корректируется на основе состояния сети
3. **Сетевая балансировка**: Обеспечивает равномерное распределение нагрузки
4. **Мотивация**: Более сложные задачи дают больше награды
5. **Автоматизация**: Полностью автоматическая система балансировки

---

## 🔗 Связь с TVC

Yuroboros Engine можно интегрировать с TVC для:
- **Оценка сложности TVC спецификаций**
- **Балансировка сложности TVC задач**
- **Мотивация за сложные TVC программы**

---

## 🚀 Следующие шаги

1. **Интеграция с TVC**: Использовать Yuroboros для оценки сложности TVC задач
2. **Интеграция с Phi-Engine**: Встроить Yuroboros в основной движок Phi-Engine
3. **Расширение Difficulty Rating**: Добавить больше уровней (например, INSANE, NIGHTMARE)
4. **Расширение Network Status**: Добавить больше статусов (например, DEAD, MAINTENANCE)
5. **Добавление профилей сложности**: Разные профили для разных типов задач

---

## 📝 Файлы

- `phi-engine/src/core/learning/yuroboros.zig` - Yuroboros Engine (Level 2)
- `yuroboros_demo` - Демонстрация Yuroboros Engine

---

## 🎊 Заключение

Yuroboros Engine (Level 2) - это полноценная система динамического уровня сложности и балансировки сети для Phi-Engine, использующая математику φ (Золотое сечение).

**Преимущества**:
- ✅ Адаптивная сложность
- ✅ Сетевая балансировка
- ✅ Математика φ
- ✅ Полностью автоматическая
- ✅ Готов к интеграции с Phi-Engine и TVC

**Статус**: ✅ **Полностью реализован** и **готов к использованию**.
