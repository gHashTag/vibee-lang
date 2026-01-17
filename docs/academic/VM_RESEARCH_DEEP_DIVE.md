# VM Research Deep Dive - Научные основы для VIBEE

## 1. LuaJIT (Mike Pall)

### Ключевые техники

**Trace Compilation:**
```
1. Интерпретатор выполняет код
2. Обнаружение hot loop (>100 итераций)
3. Запись trace (последовательность операций)
4. Компиляция trace в native code
5. Выполнение native code
6. Side exit при guard failure → возврат к интерпретатору
```

**SSA IR (Static Single Assignment):**
```
Каждая переменная присваивается ОДИН раз
a = 1       →  a1 = 1
a = a + 1   →  a2 = a1 + 1
a = a * 2   →  a3 = a2 * 2
```

**Преимущества SSA:**
- Упрощает оптимизации
- Dead code elimination тривиален
- Constant propagation очевиден

**Register Allocation (Linear Scan):**
```
Для каждой переменной:
1. Определить live range (начало-конец использования)
2. Выделить регистр если свободен
3. Spill в память если регистров нет
```

### Производительность LuaJIT

| Benchmark | LuaJIT | CPython | Ratio |
|-----------|--------|---------|-------|
| fib(35) | 0.8s | 80s | 100x |
| mandelbrot | 0.3s | 30s | 100x |
| nbody | 0.5s | 50s | 100x |

---

## 2. V8 (Google Chrome)

### Hidden Classes

```javascript
// JavaScript
obj.x = 1;  // Hidden class C0 → C1
obj.y = 2;  // Hidden class C1 → C2
```

**Inline Cache:**
```
// Первый вызов
obj.x → lookup("x") → offset 0 → cache(C1, offset 0)

// Последующие вызовы
obj.x → check(class == C1) → load offset 0  // O(1)!
```

### Tiered Compilation

```
Уровень 0: Interpreter (Ignition)
    ↓ (hot function detected)
Уровень 1: Baseline JIT (Sparkplug)
    ↓ (very hot function)
Уровень 2: Optimizing JIT (TurboFan)
    ↓ (deoptimization if assumptions fail)
Уровень 0: Back to interpreter
```

### Deoptimization

```javascript
function add(a, b) {
    return a + b;  // Optimized for integers
}

add(1, 2);      // OK, integers
add(1, 2);      // OK, integers
add("a", "b");  // DEOPT! String concatenation
```

---

## 3. PyPy (Meta-Tracing)

### RPython Approach

```
1. Написать интерпретатор на RPython (restricted Python)
2. RPython компилируется в C
3. Tracing JIT генерируется АВТОМАТИЧЕСКИ
```

**Meta-Tracing:**
```
Trace записывается на уровне ИНТЕРПРЕТАТОРА, не программы.
Это позволяет JIT работать для ЛЮБОГО языка.
```

### Escape Analysis

```python
def foo():
    point = Point(1, 2)  # Allocation
    return point.x + point.y

# После escape analysis:
def foo():
    x = 1  # Scalar replacement
    y = 2
    return x + y  # No allocation!
```

---

## 4. GraalVM (Oracle)

### Truffle Framework

```java
// AST Node
class AddNode extends Node {
    @Specialization
    int doInt(int a, int b) {
        return a + b;
    }
    
    @Specialization
    double doDouble(double a, double b) {
        return a + b;
    }
}
```

**Partial Evaluation:**
```
Интерпретатор + Программа → Специализированный код

Truffle "сворачивает" интерпретатор с конкретной программой,
получая оптимизированный код.
```

### Polyglot

```
JavaScript → Truffle AST → Graal IR → Native
Python     → Truffle AST → Graal IR → Native
Ruby       → Truffle AST → Graal IR → Native
```

---

## 5. Ключевые Papers

### Must Read (Обязательно)

1. **"Trace-based Just-in-Time Type Specialization for Dynamic Languages"**
   - Gal et al., PLDI 2009
   - Основа TraceMonkey (Firefox)
   - DOI: 10.1145/1542476.1542528

2. **"An Efficient Implementation of SELF"**
   - Chambers, Ungar, OOPSLA 1989
   - Polymorphic Inline Caches
   - DOI: 10.1145/74877.74884

3. **"The Implementation of Lua 5.0"**
   - Ierusalimschy et al., 2005
   - Register-based VM design
   - https://www.lua.org/doc/jucs05.pdf

4. **"One VM to Rule Them All"**
   - Würthinger et al., Onward! 2013
   - Truffle/Graal framework
   - DOI: 10.1145/2509578.2509581

5. **"Tracing the Meta-Level: PyPy's Tracing JIT Compiler"**
   - Bolz et al., ICOOOLPS 2009
   - Meta-tracing approach
   - DOI: 10.1145/1565824.1565827

### Advanced (Продвинутые)

6. **"Fast, Effective Code Generation in a Just-In-Time Java Compiler"**
   - Adl-Tabatabai et al., PLDI 1998
   - Linear scan register allocation
   - DOI: 10.1145/277650.277740

7. **"Equality Saturation: A New Approach to Optimization"**
   - Tate et al., POPL 2009
   - E-graphs for optimization
   - DOI: 10.1145/1480881.1480915

8. **"Partial Evaluation and Automatic Program Generation"**
   - Jones, Gomard, Sestoft, 1993
   - Теоретическая основа Truffle
   - ISBN: 0-13-020249-5

---

## 6. Применение к VIBEE

### Фаза 1: Register-based VM (v0.2.0)

**Изменения:**
```zig
// Было (stack-based)
PUSH a
PUSH b
ADD
POP result

// Станет (register-based)
ADD r0, r1, r2  // r0 = r1 + r2
```

**Ожидаемое ускорение:** 1.5-2x

### Фаза 2: Inline Caching (v0.2.0)

```zig
// Inline cache structure
const InlineCache = struct {
    cached_type: ?TypeId,
    cached_offset: u16,
    
    fn lookup(self: *InlineCache, obj: *Object, name: []const u8) Value {
        if (obj.type_id == self.cached_type) {
            return obj.fields[self.cached_offset];  // Fast path
        }
        // Slow path: full lookup + update cache
        const offset = obj.type.lookupField(name);
        self.cached_type = obj.type_id;
        self.cached_offset = offset;
        return obj.fields[offset];
    }
};
```

### Фаза 3: Tracing JIT (v0.3.0)

```zig
// Trace recording
const TraceRecorder = struct {
    instructions: ArrayList(TraceIR),
    guards: ArrayList(Guard),
    
    fn recordLoop(self: *TraceRecorder, vm: *VM) void {
        const loop_header = vm.ip;
        
        while (true) {
            const op = vm.fetch();
            
            // Record with type guards
            switch (op) {
                .ADD => {
                    const a_type = vm.peek(0).type;
                    const b_type = vm.peek(1).type;
                    
                    self.guards.append(.{ .type_check, a_type });
                    self.guards.append(.{ .type_check, b_type });
                    
                    if (a_type == .INT and b_type == .INT) {
                        self.instructions.append(.add_int);
                    } else {
                        self.instructions.append(.add_float);
                    }
                },
                // ...
            }
            
            if (vm.ip == loop_header) break;  // Loop complete
        }
    }
};
```

### Фаза 4: Full JIT (v1.0.0)

```zig
// Native code emission (x86-64)
const NativeEmitter = struct {
    code: ArrayList(u8),
    
    fn emitAddInt(self: *NativeEmitter, dst: Reg, src1: Reg, src2: Reg) void {
        // ADD dst, src1, src2
        // x86-64: add rax, rbx
        self.code.appendSlice(&[_]u8{
            0x48, 0x01, 0xd8,  // add rax, rbx
        });
    }
};
```

---

## 7. Метрики успеха

| Версия | fib(30) | vs Python | vs LuaJIT | Статус |
|--------|---------|-----------|-----------|--------|
| v0.1.0 | 92.8ms | 1.1x | 0.01x | ТЕКУЩАЯ |
| v0.2.0 | 45ms | 2.3x | 0.02x | Цель Q2 2026 |
| v0.3.0 | 5ms | 20x | 0.2x | Цель Q4 2026 |
| v1.0.0 | 1.5ms | 70x | 0.7x | Цель 2028 |

---

## 8. Честная оценка

**Что мы можем достичь:**
- v0.2.0 реалистичен за 2-3 месяца
- v0.3.0 требует 6-12 месяцев серьёзной работы
- v1.0.0 - это 2+ года при полной занятости

**Что мы НЕ можем:**
- Превзойти LuaJIT (Mike Pall - гений, 10+ лет работы)
- Конкурировать с V8 (команда Google, миллионы $)
- Достичь GraalVM уровня (Oracle research)

**Реалистичная цель:**
- Быть в 2-5x от LuaJIT
- Быть быстрее PyPy
- Быть полезным для обучения

---

*"Знание своих ограничений - первый шаг к их преодолению."*
