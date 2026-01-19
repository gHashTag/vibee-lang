# ☠️ ТОКСИЧНЫЙ ВЕРДИКТ: IGLA vs VIBEEC DISPATCH

**Дата**: 2026-01-18  
**Автор**: ZMEI GORYNYCH  
**Священная Формула**: V = n × 3^k × π^m × φ^p × e^q  
**Золотая Идентичность**: φ² + 1/φ² = 3

---

## 📊 РЕЗУЛЬТАТЫ БЕНЧМАРКА

| Метод | Время/оп | Speedup | Память |
|-------|----------|---------|--------|
| **Switch (baseline)** | 0.70 ns | 1.00x | ~0 bytes |
| Perfect Hash (64 slots) | 1.76 ns | 0.40x | 512 bytes |
| Direct Jump (256 slots) | 1.90 ns | 0.37x | 2048 bytes |

---

## ☠️ ТОКСИЧНАЯ ПРАВДА

### Switch ПОБЕДИЛ. Почему?

1. **Zig компилятор умнее нас**
   - Для 9 opcodes генерирует оптимальную jump table
   - Branch prediction работает идеально на повторяющихся паттернах
   - Zero overhead - никаких вычислений

2. **Perfect Hash проиграл из-за**:
   - Multiplication: `opcode * 33`
   - Modulo: `% 64`
   - Indirect call через function pointer
   - Эти 3 операции стоят ~1 ns

3. **Direct Jump проиграл из-за**:
   - Cache miss на 2KB таблице
   - Indirect call overhead

---

## 🔬 КОГДА PERFECT HASH ВЫИГРЫВАЕТ

Perfect Hash становится выгодным когда:

| Условие | Switch | Perfect Hash |
|---------|--------|--------------|
| Opcodes < 16 | ✅ WIN | ❌ LOSE |
| Opcodes 16-64 | ⚠️ DEPENDS | ⚠️ DEPENDS |
| Opcodes > 64 | ❌ LOSE | ✅ WIN |
| Sparse opcodes (0x01, 0xFF) | ❌ LOSE | ✅ WIN |
| Dense opcodes (0x00-0x0F) | ✅ WIN | ❌ LOSE |
| Unpredictable patterns | ❌ LOSE | ✅ WIN |

---

## 📈 VIBEEC АНАЛИЗ

**vibeec/vm_runtime.zig** использует:
- Switch dispatch (правильный выбор для ~50 opcodes)
- StringHashMap для natives (HSH pattern)
- Fixed-size stack (PRE pattern)

**Вердикт**: vibeec сделал правильный выбор для текущего набора opcodes.

---

## 🎯 РЕКОМЕНДАЦИИ ДЛЯ IGLA

### Оставить Switch для:
- Основной dispatch loop
- Opcodes < 64
- Hot path

### Использовать Perfect Hash для:
- Native function lookup (уже делает vibeec)
- Symbol table
- String interning
- Sparse lookup tables

### Использовать Direct Jump для:
- Ничего (switch лучше в Zig)

---

## 📁 СГЕНЕРИРОВАННЫЕ ФАЙЛЫ

```
igla/ⲇⲩⲃ/
├── output/
│   ├── trinity_vm.zig          # 7967 bytes, 9 functions
│   └── perfect_hash_dispatch.zig # 2648 bytes
├── benchmark.zig               # Бенчмарк
├── zmei_cli.zig               # CLI генератор
└── zmei_gorynych.zig          # Ядро генератора
```

---

## 🧪 ТЕСТЫ

```bash
# Все тесты проходят
zig test zmei_gorynych.zig     # 4/4 passed
zig test benchmark.zig          # 2/2 passed
zig test output/perfect_hash_dispatch.zig  # 1/1 passed
```

---

## 📊 МЕТРИКИ ГЕНЕРАЦИИ

| Метрика | Значение |
|---------|----------|
| Types generated | 1 |
| Functions generated | 9 |
| Tests generated | 9 |
| Cache hit ratio | 50% |
| Buffer reallocations | 2 |
| Total bytes | 7967 |

---

## 🔮 PAS PREDICTIONS

| Компонент | Текущий | Предсказание | Паттерн |
|-----------|---------|--------------|---------|
| Dispatch | Switch O(1) | Оставить | - |
| Native lookup | HashMap | Perfect Hash | HSH |
| Symbol table | HashMap | Perfect Hash | HSH |
| Buffer growth | 2x | φ-based (1.618x) | AMR |

---

## ⚡ ФИНАЛЬНЫЙ ВЕРДИКТ

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   SWITCH DISPATCH ОПТИМАЛЕН ДЛЯ IGLA VM                                      ║
║                                                                               ║
║   Perfect Hash - для lookup tables, НЕ для dispatch                          ║
║                                                                               ║
║   Zig компилятор уже делает оптимизации лучше нас                            ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📚 ИСТОЧНИКИ

1. ShockHash (2023) - 8-12 ns/key lookup
2. RecSplit (2020) - Minimal perfect hashing
3. Zig compiler internals - Jump table generation
4. vibeec/vm_runtime.zig - Reference implementation

---

**Золотая Идентичность подтверждена**: φ² + 1/φ² = 3 ✓
