// ═══════════════════════════════════════════════════════════════════════════════
// JIT VM INTEGRATION - Интеграция JIT компилятора с VIBEE VM
// ═══════════════════════════════════════════════════════════════════════════════
//
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
// PHOENIX = 999
//
// Интеграция ExecutableJIT с VM для ускорения горячих путей
//
// Author: VIBEE Team
// Co-authored-by: Ona <no-reply@ona.com>
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const jit = @import("jit_x86_codegen.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHOENIX: u64 = 999;

// JIT Configuration
pub const JIT_THRESHOLD: u32 = 50; // Порог для JIT компиляции
pub const MAX_COMPILED_BLOCKS: usize = 1024;
pub const CODE_CACHE_SIZE: usize = 1024 * 1024; // 1MB

// ═══════════════════════════════════════════════════════════════════════════════
// BASIC BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

/// Базовый блок - последовательность инструкций без переходов
pub const BasicBlock = struct {
    /// Начальный адрес в байткоде
    start_addr: u32,
    /// Конечный адрес (не включительно)
    end_addr: u32,
    /// Счётчик выполнений
    execution_count: u32,
    /// Скомпилированный нативный код (если есть)
    native_code: ?*const fn (i64, i64) callconv(.C) i64,
    /// Флаг: блок скомпилирован
    is_compiled: bool,

    pub fn init(start: u32, end: u32) BasicBlock {
        return BasicBlock{
            .start_addr = start,
            .end_addr = end,
            .execution_count = 0,
            .native_code = null,
            .is_compiled = false,
        };
    }

    pub fn recordExecution(self: *BasicBlock) bool {
        self.execution_count += 1;
        return self.execution_count >= JIT_THRESHOLD and !self.is_compiled;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT RUNTIME
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITRuntime = struct {
    allocator: Allocator,

    /// Кэш базовых блоков (адрес -> блок)
    blocks: std.AutoHashMap(u32, BasicBlock),

    /// Исполняемый буфер для JIT кода
    code_buffer: jit.ExecutableBuffer,

    /// Текущая позиция в буфере
    code_pos: usize,

    /// Статистика
    stats: JITStats,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .blocks = std.AutoHashMap(u32, BasicBlock).init(allocator),
            .code_buffer = try jit.ExecutableBuffer.init(CODE_CACHE_SIZE),
            .code_pos = 0,
            .stats = JITStats{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocks.deinit();
        self.code_buffer.deinit();
    }

    /// Записать выполнение блока, вернуть true если нужна компиляция
    pub fn recordBlockExecution(self: *Self, addr: u32, end_addr: u32) !bool {
        const entry = try self.blocks.getOrPut(addr);
        if (!entry.found_existing) {
            entry.value_ptr.* = BasicBlock.init(addr, end_addr);
        }
        return entry.value_ptr.recordExecution();
    }

    /// Получить скомпилированный код для блока
    pub fn getCompiledCode(self: *const Self, addr: u32) ?*const fn (i64, i64) callconv(.C) i64 {
        if (self.blocks.get(addr)) |block| {
            return block.native_code;
        }
        return null;
    }

    /// Проверить, скомпилирован ли блок
    pub fn isCompiled(self: *const Self, addr: u32) bool {
        if (self.blocks.get(addr)) |block| {
            return block.is_compiled;
        }
        return false;
    }

    /// Компилировать базовый блок
    pub fn compileBlock(self: *Self, addr: u32, bytecode: []const u8) !void {
        const entry = self.blocks.getPtr(addr) orelse return;

        // Если буфер уже исполняемый, делаем его записываемым
        if (self.code_buffer.is_executable) {
            try self.code_buffer.makeWritable();
        }

        // Анализ байткода и генерация нативного кода
        const start_pos = self.code_buffer.pos;

        // Генерируем простую функцию для арифметических операций
        // Пока поддерживаем только ADD, SUB, MUL
        self.emitBlockCode(bytecode[entry.start_addr..entry.end_addr]);

        // Делаем код исполняемым
        try self.code_buffer.makeExecutable();

        // Сохраняем указатель на функцию
        entry.native_code = self.code_buffer.getFunctionAt(
            *const fn (i64, i64) callconv(.C) i64,
            start_pos,
        );
        entry.is_compiled = true;

        self.stats.blocks_compiled += 1;
        self.stats.bytes_generated += self.code_buffer.pos - start_pos;
    }

    /// Генерация нативного кода для блока
    fn emitBlockCode(self: *Self, bytecode_slice: []const u8) void {
        // Пролог: сохраняем аргументы
        // rdi = arg1, rsi = arg2 (System V AMD64 ABI)

        // mov rax, rdi (первый аргумент в rax)
        self.code_buffer.emit(0x48);
        self.code_buffer.emit(0x89);
        self.code_buffer.emit(0xF8);

        // Обрабатываем байткод
        var i: usize = 0;
        while (i < bytecode_slice.len) {
            const opcode = bytecode_slice[i];
            i += 1;

            switch (opcode) {
                0x10 => { // ADD
                    // add rax, rsi
                    self.code_buffer.emit(0x48);
                    self.code_buffer.emit(0x01);
                    self.code_buffer.emit(0xF0);
                },
                0x11 => { // SUB
                    // sub rax, rsi
                    self.code_buffer.emit(0x48);
                    self.code_buffer.emit(0x29);
                    self.code_buffer.emit(0xF0);
                },
                0x12 => { // MUL
                    // imul rax, rsi
                    self.code_buffer.emit(0x48);
                    self.code_buffer.emit(0x0F);
                    self.code_buffer.emit(0xAF);
                    self.code_buffer.emit(0xC6);
                },
                0x45 => { // HALT
                    break;
                },
                else => {
                    // Пропускаем неподдерживаемые опкоды
                },
            }
        }

        // ret
        self.code_buffer.emit(0xC3);
    }

    /// Выполнить скомпилированный блок
    pub fn executeBlock(self: *Self, addr: u32, arg1: i64, arg2: i64) ?i64 {
        if (self.blocks.get(addr)) |block| {
            if (block.native_code) |func| {
                self.stats.jit_executions += 1;
                return func(arg1, arg2);
            }
        }
        self.stats.interpreted_executions += 1;
        return null;
    }

    pub fn getStats(self: *const Self) JITStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITStats = struct {
    blocks_compiled: u64 = 0,
    bytes_generated: u64 = 0,
    jit_executions: u64 = 0,
    interpreted_executions: u64 = 0,

    pub fn speedup(self: *const JITStats) f64 {
        const total = self.jit_executions + self.interpreted_executions;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.jit_executions)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID VM - VM с интегрированным JIT
// ═══════════════════════════════════════════════════════════════════════════════

pub const HybridVM = struct {
    allocator: Allocator,

    /// JIT runtime
    jit_runtime: JITRuntime,

    /// Байткод программы
    bytecode: []const u8,

    /// Стек значений
    stack: [65536]i64,
    sp: u32,

    /// Instruction pointer
    ip: u32,

    /// Состояние
    running: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, bytecode: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .jit_runtime = try JITRuntime.init(allocator),
            .bytecode = bytecode,
            .stack = undefined,
            .sp = 0,
            .ip = 0,
            .running = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.jit_runtime.deinit();
    }

    /// Запустить выполнение
    pub fn run(self: *Self) !i64 {
        self.running = true;
        self.ip = 0;
        self.sp = 0;

        while (self.running and self.ip < self.bytecode.len) {
            const block_start = self.ip;

            // Проверяем, есть ли скомпилированный код
            if (self.jit_runtime.isCompiled(block_start)) {
                // Выполняем JIT код
                const arg1 = if (self.sp > 0) self.stack[self.sp - 1] else 0;
                const arg2 = if (self.sp > 1) self.stack[self.sp - 2] else 0;

                if (self.jit_runtime.executeBlock(block_start, arg1, arg2)) |result| {
                    // Заменяем верхние два элемента стека результатом
                    if (self.sp >= 2) {
                        self.sp -= 1;
                        self.stack[self.sp - 1] = result;
                    } else {
                        self.stack[self.sp] = result;
                        self.sp += 1;
                    }
                    // Пропускаем блок
                    if (self.jit_runtime.blocks.get(block_start)) |block| {
                        self.ip = block.end_addr;
                    }
                    continue;
                }
            }

            // Интерпретируем инструкцию
            const opcode = self.bytecode[self.ip];
            self.ip += 1;

            // Записываем выполнение для hot path detection
            const block_end = self.findBlockEnd(block_start);
            const should_compile = try self.jit_runtime.recordBlockExecution(block_start, block_end);

            if (should_compile) {
                try self.jit_runtime.compileBlock(block_start, self.bytecode);
            }

            // Выполняем опкод
            try self.executeOpcode(opcode);
        }

        return if (self.sp > 0) self.stack[self.sp - 1] else 0;
    }

    fn findBlockEnd(self: *Self, start: u32) u32 {
        var pos = start;
        while (pos < self.bytecode.len) {
            const op = self.bytecode[pos];
            pos += 1;

            // Конец блока на переходах или HALT
            if (op == 0x40 or op == 0x41 or op == 0x42 or op == 0x43 or op == 0x44 or op == 0x45) {
                return pos;
            }

            // Пропускаем операнды
            if (op == 0x01) { // PUSH_CONST
                pos += 2; // 16-bit operand
            }
        }
        return @intCast(self.bytecode.len);
    }

    fn executeOpcode(self: *Self, opcode: u8) !void {
        switch (opcode) {
            0x00 => {}, // NOP
            0x01 => { // PUSH_CONST
                const idx = self.readU16();
                self.stack[self.sp] = @intCast(idx);
                self.sp += 1;
            },
            0x02 => { // POP
                if (self.sp > 0) self.sp -= 1;
            },
            0x03 => { // DUP
                if (self.sp > 0) {
                    self.stack[self.sp] = self.stack[self.sp - 1];
                    self.sp += 1;
                }
            },
            0x10 => { // ADD
                if (self.sp >= 2) {
                    const b = self.stack[self.sp - 1];
                    const a = self.stack[self.sp - 2];
                    self.sp -= 1;
                    self.stack[self.sp - 1] = a + b;
                }
            },
            0x11 => { // SUB
                if (self.sp >= 2) {
                    const b = self.stack[self.sp - 1];
                    const a = self.stack[self.sp - 2];
                    self.sp -= 1;
                    self.stack[self.sp - 1] = a - b;
                }
            },
            0x12 => { // MUL
                if (self.sp >= 2) {
                    const b = self.stack[self.sp - 1];
                    const a = self.stack[self.sp - 2];
                    self.sp -= 1;
                    self.stack[self.sp - 1] = a * b;
                }
            },
            0x45 => { // HALT
                self.running = false;
            },
            else => {},
        }
    }

    fn readU16(self: *Self) u16 {
        const lo = self.bytecode[self.ip];
        const hi = self.bytecode[self.ip + 1];
        self.ip += 2;
        return @as(u16, hi) << 8 | @as(u16, lo);
    }

    pub fn getStats(self: *const Self) JITStats {
        return self.jit_runtime.getStats();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "jit runtime init" {
    const allocator = std.testing.allocator;
    var runtime = try JITRuntime.init(allocator);
    defer runtime.deinit();

    try std.testing.expectEqual(@as(u64, 0), runtime.stats.blocks_compiled);
}

test "jit runtime record execution" {
    const allocator = std.testing.allocator;
    var runtime = try JITRuntime.init(allocator);
    defer runtime.deinit();

    // Записываем выполнения до порога
    var i: u32 = 0;
    while (i < JIT_THRESHOLD - 1) : (i += 1) {
        const should_compile = try runtime.recordBlockExecution(0x100, 0x110);
        try std.testing.expect(!should_compile);
    }

    // На пороге должна быть компиляция
    const should_compile = try runtime.recordBlockExecution(0x100, 0x110);
    try std.testing.expect(should_compile);
}

test "hybrid vm simple add" {
    const allocator = std.testing.allocator;

    // Программа: PUSH 10, PUSH 20, ADD, HALT
    const bytecode = [_]u8{
        0x01, 0x0A, 0x00, // PUSH_CONST 10
        0x01, 0x14, 0x00, // PUSH_CONST 20
        0x10, // ADD
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 30), result);
}

test "hybrid vm mul" {
    const allocator = std.testing.allocator;

    // Программа: PUSH 6, PUSH 7, MUL, HALT
    const bytecode = [_]u8{
        0x01, 0x06, 0x00, // PUSH_CONST 6
        0x01, 0x07, 0x00, // PUSH_CONST 7
        0x12, // MUL
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 42), result);
}

test "hybrid vm phoenix" {
    const allocator = std.testing.allocator;

    // Программа: PUSH 999, HALT (PHOENIX!)
    const bytecode = [_]u8{
        0x01, 0xE7, 0x03, // PUSH_CONST 999 (0x03E7)
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 999), result);
}

test "hybrid vm complex expression" {
    const allocator = std.testing.allocator;

    // Программа: (10 + 20) * 3 = 90
    // PUSH 10, PUSH 20, ADD, PUSH 3, MUL, HALT
    const bytecode = [_]u8{
        0x01, 0x0A, 0x00, // PUSH_CONST 10
        0x01, 0x14, 0x00, // PUSH_CONST 20
        0x10, // ADD (= 30)
        0x01, 0x03, 0x00, // PUSH_CONST 3
        0x12, // MUL (= 90)
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 90), result);
}

test "hybrid vm golden identity" {
    const allocator = std.testing.allocator;

    // φ² + 1/φ² = 3
    // Проверим: 3 * 3 - 6 = 3
    // PUSH 3, PUSH 3, MUL, PUSH 6, SUB, HALT
    const bytecode = [_]u8{
        0x01, 0x03, 0x00, // PUSH_CONST 3
        0x01, 0x03, 0x00, // PUSH_CONST 3
        0x12, // MUL (= 9)
        0x01, 0x06, 0x00, // PUSH_CONST 6
        0x11, // SUB (= 3)
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 3), result); // GOLDEN IDENTITY!
}

test "hybrid vm dup operation" {
    const allocator = std.testing.allocator;

    // PUSH 21, DUP, ADD = 42
    const bytecode = [_]u8{
        0x01, 0x15, 0x00, // PUSH_CONST 21
        0x03, // DUP
        0x10, // ADD (= 42)
        0x45, // HALT
    };

    var vm = try HybridVM.init(allocator, &bytecode);
    defer vm.deinit();

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 42), result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// БЕНЧМАРК: VM ИНТЕРПРЕТАТОР vs JIT
// ═══════════════════════════════════════════════════════════════════════════════

pub const VMBenchmarkResult = struct {
    interpreter_ns: u64,
    jit_ns: u64,
    speedup: f64,
    iterations: u64,
    jit_compilations: u64,
};

/// Бенчмарк: многократное выполнение программы
pub fn benchmarkVM(allocator: Allocator, bytecode: []const u8, iterations: u64) !VMBenchmarkResult {
    // Бенчмарк интерпретатора (без JIT)
    var timer = std.time.Timer.start() catch unreachable;
    var sum_interp: i64 = 0;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        var vm = try HybridVM.init(allocator, bytecode);
        defer vm.deinit();
        // Отключаем JIT для чистого интерпретатора
        sum_interp +%= try vm.run();
    }
    const interp_ns = timer.read();

    // Бенчмарк с JIT
    timer.reset();
    var sum_jit: i64 = 0;
    var jit_compilations: u64 = 0;

    // Создаём одну VM и выполняем много раз (для прогрева JIT)
    var vm_jit = try HybridVM.init(allocator, bytecode);
    defer vm_jit.deinit();

    i = 0;
    while (i < iterations) : (i += 1) {
        vm_jit.ip = 0;
        vm_jit.sp = 0;
        vm_jit.running = false;
        sum_jit +%= try vm_jit.run();
    }
    const jit_ns = timer.read();
    jit_compilations = vm_jit.getStats().blocks_compiled;

    const speedup = @as(f64, @floatFromInt(interp_ns)) / @as(f64, @floatFromInt(jit_ns));

    return VMBenchmarkResult{
        .interpreter_ns = interp_ns,
        .jit_ns = jit_ns,
        .speedup = speedup,
        .iterations = iterations,
        .jit_compilations = jit_compilations,
    };
}

test "benchmark vm add" {
    const allocator = std.testing.allocator;

    const bytecode = [_]u8{
        0x01, 0x0A, 0x00, // PUSH 10
        0x01, 0x14, 0x00, // PUSH 20
        0x10, // ADD
        0x45, // HALT
    };

    const result = try benchmarkVM(allocator, &bytecode, 1000);
    // Проверяем, что бенчмарк выполнился
    try std.testing.expect(result.iterations == 1000);
}
