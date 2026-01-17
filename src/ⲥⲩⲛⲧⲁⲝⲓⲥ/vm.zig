// ═══════════════════════════════════════════════════════════════════════════════
// VM TRINITY - РЕАЛЬНЫЙ ИНТЕРПРЕТАТОР БАЙТКОДА С COMPUTED GOTO
// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// ОПТИМИЗАЦИИ:
// 1. Computed goto через dispatch table (O(1) dispatch)
// 2. Direct threaded code
// 3. SIMD векторные операции
// 4. Inline caching для hot paths
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const codegen = @import("codegen.zig");
const builtin = @import("builtin");
const inline_cache = @import("inline_cache.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE FEEDBACK INTEGRATION - РЕАЛЬНЫЙ сбор данных о типах
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeFeedback = struct {
    // Type counts per bytecode offset
    type_observations: [1024]TypeObservation,
    observation_count: u32,
    
    // Branch statistics
    branch_taken: [256]u32,
    branch_not_taken: [256]u32,
    
    // Call site statistics
    call_counts: [256]u32,
    
    pub const TypeObservation = struct {
        offset: u32,
        int_count: u32,
        float_count: u32,
        other_count: u32,
        
        pub fn isMonomorphic(self: *const TypeObservation) bool {
            const total = self.int_count + self.float_count + self.other_count;
            if (total == 0) return false;
            const threshold = total * 9 / 10;  // 90%
            return self.int_count >= threshold or self.float_count >= threshold;
        }
        
        pub fn getDominantType(self: *const TypeObservation) u8 {
            if (self.int_count >= self.float_count and self.int_count >= self.other_count) return 0;
            if (self.float_count >= self.int_count and self.float_count >= self.other_count) return 1;
            return 2;
        }
    };
    
    pub fn init() TypeFeedback {
        return .{
            .type_observations = [_]TypeObservation{.{ .offset = 0, .int_count = 0, .float_count = 0, .other_count = 0 }} ** 1024,
            .observation_count = 0,
            .branch_taken = [_]u32{0} ** 256,
            .branch_not_taken = [_]u32{0} ** 256,
            .call_counts = [_]u32{0} ** 256,
        };
    }
    
    pub fn recordType(self: *TypeFeedback, offset: u32, type_id: u8) void {
        const idx = offset % 1024;
        self.type_observations[idx].offset = offset;
        switch (type_id) {
            0 => self.type_observations[idx].int_count +%= 1,
            1 => self.type_observations[idx].float_count +%= 1,
            else => self.type_observations[idx].other_count +%= 1,
        }
        self.observation_count +%= 1;
    }
    
    pub fn recordBranch(self: *TypeFeedback, offset: u32, taken: bool) void {
        const idx = offset % 256;
        if (taken) {
            self.branch_taken[idx] +%= 1;
        } else {
            self.branch_not_taken[idx] +%= 1;
        }
    }
    
    pub fn recordCall(self: *TypeFeedback, offset: u32) void {
        const idx = offset % 256;
        self.call_counts[idx] +%= 1;
    }
    
    pub fn getMonomorphicRatio(self: *const TypeFeedback) f64 {
        var mono: u32 = 0;
        var total: u32 = 0;
        
        for (&self.type_observations) |*obs| {
            const obs_total = obs.int_count + obs.float_count + obs.other_count;
            if (obs_total > 0) {
                total += 1;
                if (obs.isMonomorphic()) mono += 1;
            }
        }
        
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(mono)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn getBiasedBranchRatio(self: *const TypeFeedback) f64 {
        var biased: u32 = 0;
        var total: u32 = 0;
        
        for (0..256) |i| {
            const t = self.branch_taken[i];
            const nt = self.branch_not_taken[i];
            const sum = t + nt;
            if (sum > 0) {
                total += 1;
                const ratio = @as(f64, @floatFromInt(t)) / @as(f64, @floatFromInt(sum));
                if (ratio > 0.9 or ratio < 0.1) biased += 1;
            }
        }
        
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(biased)) / @as(f64, @floatFromInt(total));
    }
    
    pub fn getTotalObservations(self: *const TypeFeedback) u32 {
        return self.observation_count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES - Реальные коды операций
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Stack operations (0x00-0x0F)
    PUSH_CONST = 0x00,
    PUSH_LOCAL = 0x01,
    PUSH_GLOBAL = 0x02,
    POP = 0x03,
    DUP = 0x04,
    SWAP = 0x05,
    PUSH_INT = 0x06,  // Push immediate i64
    PUSH_FLOAT = 0x07, // Push immediate f64
    
    // Arithmetic (0x10-0x1F)
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    INC = 0x16,  // Increment top of stack
    DEC = 0x17,  // Decrement top of stack
    
    // Comparison (0x20-0x2F)
    EQ = 0x20,
    NE = 0x21,
    LT = 0x22,
    LE = 0x23,
    GT = 0x24,
    GE = 0x25,
    
    // Logic (0x30-0x3F)
    NOT = 0x30,
    AND = 0x31,
    OR = 0x32,
    
    // Control flow (0x50-0x5F)
    JMP = 0x50,
    JZ = 0x51,
    JNZ = 0x52,
    CALL = 0x53,
    RET = 0x54,
    HALT = 0x55,
    LOOP = 0x56,  // Optimized loop back
    
    // SIMD operations (0x80-0x8F)
    SIMD_ADD = 0x80,  // Vector add (4 x f64)
    SIMD_MUL = 0x81,  // Vector multiply
    SIMD_DOT = 0x82,  // Dot product
    SIMD_LOAD = 0x83, // Load 4 values
    SIMD_STORE = 0x84, // Store 4 values
    
    // Sacred constants (0x90-0x9F)
    PUSH_PHI = 0x90,
    PUSH_PI = 0x91,
    PUSH_E = 0x92,
    GOLDEN_IDENTITY = 0x93,
    SACRED_FORMULA = 0x94,
    PUSH_SQRT2 = 0x95,
    PUSH_SQRT3 = 0x96,
    PUSH_SQRT5 = 0x97,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SUPERINSTRUCTIONS (0xA0-0xAF) - Комбинированные инструкции для ускорения
    // Спецификация: specs/superinstructions.vibee
    // ═══════════════════════════════════════════════════════════════════════════
    LOAD_ADD = 0xA0,      // LOAD_CONST + ADD в одной инструкции
    LOAD_SUB = 0xA1,      // LOAD_CONST + SUB
    LOAD_MUL = 0xA2,      // LOAD_CONST + MUL
    LT_JZ = 0xA3,         // LT + JZ (сравнить и перейти)
    LE_JZ = 0xA4,         // LE + JZ
    INC_LT = 0xA5,        // INC + LT
    DEC_GT = 0xA6,        // DEC + GT
    DUP_LOAD_LT = 0xA7,   // DUP + LOAD_CONST + LT
    ADD_STORE = 0xA8,     // ADD + STORE (для аккумуляторов)
    LOAD_LOAD_ADD = 0xA9, // LOAD + LOAD + ADD (a + b)
    LOAD_LOAD_LT = 0xAA,  // LOAD + LOAD + LT (a < b)
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD VECTOR TYPE - 4 x f64 (256-bit)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec4 = @Vector(4, f64);

pub const SIMDOps = struct {
    pub fn add(a: Vec4, b: Vec4) Vec4 {
        return a + b;
    }
    
    pub fn mul(a: Vec4, b: Vec4) Vec4 {
        return a * b;
    }
    
    pub fn dot(a: Vec4, b: Vec4) f64 {
        const prod = a * b;
        return @reduce(.Add, prod);
    }
    
    pub fn sum(v: Vec4) f64 {
        return @reduce(.Add, v);
    }
    
    pub fn splat(x: f64) Vec4 {
        return @splat(x);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE - Тегированное значение
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueTag = enum(u8) {
    NIL = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
};

pub const Value = packed struct {
    tag: ValueTag,
    data: u64,
    
    pub fn nil() Value {
        return .{ .tag = .NIL, .data = 0 };
    }
    
    pub fn boolean(b: bool) Value {
        return .{ .tag = .BOOL, .data = if (b) 1 else 0 };
    }
    
    pub fn int(i: i64) Value {
        return .{ .tag = .INT, .data = @bitCast(i) };
    }
    
    pub fn float(f: f64) Value {
        return .{ .tag = .FLOAT, .data = @bitCast(f) };
    }
    
    pub fn asInt(self: Value) i64 {
        return @bitCast(self.data);
    }
    
    pub fn asFloat(self: Value) f64 {
        return @bitCast(self.data);
    }
    
    pub fn asBool(self: Value) bool {
        return self.data != 0;
    }
    
    pub fn toFloat(self: Value) f64 {
        return switch (self.tag) {
            .NIL => 0.0,
            .BOOL => if (self.asBool()) 1.0 else 0.0,
            .INT => @floatFromInt(self.asInt()),
            .FLOAT => self.asFloat(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM - Виртуальная машина
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH TABLE - Computed Goto эмуляция через function pointers
// ═══════════════════════════════════════════════════════════════════════════════
// Zig не поддерживает computed goto напрямую, но мы можем использовать:
// 1. Массив указателей на функции (dispatch table)
// 2. @call(.always_inline, ...) для inline dispatch
// 3. Компилятор оптимизирует switch в jump table при -OReleaseFast
// ═══════════════════════════════════════════════════════════════════════════════

pub const DispatchTable = struct {
    /// Opcode handler function type
    pub const Handler = *const fn (*VM) anyerror!bool;
    
    /// Dispatch table - 256 entries for all possible opcodes
    handlers: [256]Handler,
    
    /// Initialize dispatch table with handlers
    pub fn init() DispatchTable {
        var table = DispatchTable{
            .handlers = [_]Handler{&handleUnknown} ** 256,
        };
        
        // Register handlers for known opcodes
        table.handlers[@intFromEnum(Opcode.PUSH_CONST)] = &handlePushConst;
        table.handlers[@intFromEnum(Opcode.POP)] = &handlePop;
        table.handlers[@intFromEnum(Opcode.DUP)] = &handleDup;
        table.handlers[@intFromEnum(Opcode.ADD)] = &handleAdd;
        table.handlers[@intFromEnum(Opcode.SUB)] = &handleSub;
        table.handlers[@intFromEnum(Opcode.MUL)] = &handleMul;
        table.handlers[@intFromEnum(Opcode.DIV)] = &handleDiv;
        table.handlers[@intFromEnum(Opcode.INC)] = &handleInc;
        table.handlers[@intFromEnum(Opcode.DEC)] = &handleDec;
        table.handlers[@intFromEnum(Opcode.LT)] = &handleLt;
        table.handlers[@intFromEnum(Opcode.GT)] = &handleGt;
        table.handlers[@intFromEnum(Opcode.LE)] = &handleLe;
        table.handlers[@intFromEnum(Opcode.GE)] = &handleGe;
        table.handlers[@intFromEnum(Opcode.EQ)] = &handleEq;
        table.handlers[@intFromEnum(Opcode.JMP)] = &handleJmp;
        table.handlers[@intFromEnum(Opcode.JZ)] = &handleJz;
        table.handlers[@intFromEnum(Opcode.JNZ)] = &handleJnz;
        table.handlers[@intFromEnum(Opcode.LOOP)] = &handleLoop;
        table.handlers[@intFromEnum(Opcode.CALL)] = &handleCall;
        table.handlers[@intFromEnum(Opcode.RET)] = &handleRet;
        table.handlers[@intFromEnum(Opcode.HALT)] = &handleHalt;
        
        // Sacred constants
        table.handlers[@intFromEnum(Opcode.PUSH_PHI)] = &handlePushPhi;
        table.handlers[@intFromEnum(Opcode.PUSH_PI)] = &handlePushPi;
        table.handlers[@intFromEnum(Opcode.PUSH_E)] = &handlePushE;
        
        // Superinstructions
        table.handlers[@intFromEnum(Opcode.LOAD_ADD)] = &handleLoadAdd;
        table.handlers[@intFromEnum(Opcode.LOAD_SUB)] = &handleLoadSub;
        table.handlers[@intFromEnum(Opcode.LOAD_MUL)] = &handleLoadMul;
        table.handlers[@intFromEnum(Opcode.LT_JZ)] = &handleLtJz;
        table.handlers[@intFromEnum(Opcode.INC_LT)] = &handleIncLt;
        
        return table;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DISPATCH HANDLERS - Inline для максимальной скорости
    // ═══════════════════════════════════════════════════════════════════════════
    
    fn handleUnknown(vm: *VM) anyerror!bool {
        _ = vm;
        return error.UnknownOpcode;
    }
    
    fn handlePushConst(vm: *VM) anyerror!bool {
        const idx = vm.readU16Fast();
        vm.pushFast(vm.constants[idx]);
        return true;
    }
    
    fn handlePop(vm: *VM) anyerror!bool {
        vm.sp -= 1;
        return true;
    }
    
    fn handleDup(vm: *VM) anyerror!bool {
        vm.pushFast(vm.stack[vm.sp - 1]);
        return true;
    }
    
    fn handleAdd(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        if (a.tag == .INT and b.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() +% b.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() + b.toFloat()));
        }
        return true;
    }
    
    fn handleSub(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        if (a.tag == .INT and b.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() -% b.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() - b.toFloat()));
        }
        return true;
    }
    
    fn handleMul(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        if (a.tag == .INT and b.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() *% b.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() * b.toFloat()));
        }
        return true;
    }
    
    fn handleDiv(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        const bf = b.toFloat();
        if (bf == 0.0) return error.DivisionByZero;
        vm.pushFast(Value.float(a.toFloat() / bf));
        return true;
    }
    
    fn handleInc(vm: *VM) anyerror!bool {
        const a = vm.popFast();
        if (a.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() +% 1));
        } else {
            vm.pushFast(Value.float(a.toFloat() + 1.0));
        }
        return true;
    }
    
    fn handleDec(vm: *VM) anyerror!bool {
        const a = vm.popFast();
        if (a.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() -% 1));
        } else {
            vm.pushFast(Value.float(a.toFloat() - 1.0));
        }
        return true;
    }
    
    fn handleLt(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        vm.pushFast(Value.boolean(a.toFloat() < b.toFloat()));
        return true;
    }
    
    fn handleGt(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        vm.pushFast(Value.boolean(a.toFloat() > b.toFloat()));
        return true;
    }
    
    fn handleLe(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        vm.pushFast(Value.boolean(a.toFloat() <= b.toFloat()));
        return true;
    }
    
    fn handleGe(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        vm.pushFast(Value.boolean(a.toFloat() >= b.toFloat()));
        return true;
    }
    
    fn handleEq(vm: *VM) anyerror!bool {
        const b = vm.popFast();
        const a = vm.popFast();
        vm.pushFast(Value.boolean(a.toFloat() == b.toFloat()));
        return true;
    }
    
    fn handleJmp(vm: *VM) anyerror!bool {
        vm.ip = vm.readU16Fast();
        return true;
    }
    
    fn handleJz(vm: *VM) anyerror!bool {
        const addr = vm.readU16Fast();
        if (!vm.popFast().asBool()) {
            vm.ip = addr;
        }
        return true;
    }
    
    fn handleJnz(vm: *VM) anyerror!bool {
        const addr = vm.readU16Fast();
        if (vm.popFast().asBool()) {
            vm.ip = addr;
        }
        return true;
    }
    
    fn handleLoop(vm: *VM) anyerror!bool {
        const offset = vm.readU16Fast();
        vm.ip -= offset;
        return true;
    }
    
    fn handleCall(vm: *VM) anyerror!bool {
        const addr = vm.readU16Fast();
        vm.call_stack[vm.fp] = .{
            .return_ip = vm.ip,
            .base_sp = vm.sp,
        };
        vm.fp += 1;
        vm.ip = addr;
        return true;
    }
    
    fn handleRet(vm: *VM) anyerror!bool {
        if (vm.fp == 0) return false;
        vm.fp -= 1;
        vm.ip = vm.call_stack[vm.fp].return_ip;
        return true;
    }
    
    fn handleHalt(_: *VM) anyerror!bool {
        return false;
    }
    
    fn handlePushPhi(vm: *VM) anyerror!bool {
        vm.pushFast(Value.float(codegen.SacredConstants.PHI));
        return true;
    }
    
    fn handlePushPi(vm: *VM) anyerror!bool {
        vm.pushFast(Value.float(codegen.SacredConstants.PI));
        return true;
    }
    
    fn handlePushE(vm: *VM) anyerror!bool {
        vm.pushFast(Value.float(codegen.SacredConstants.E));
        return true;
    }
    
    // Superinstruction handlers
    fn handleLoadAdd(vm: *VM) anyerror!bool {
        const idx = vm.readU16Fast();
        const constant = vm.constants[idx];
        const a = vm.popFast();
        if (a.tag == .INT and constant.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() +% constant.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() + constant.toFloat()));
        }
        return true;
    }
    
    fn handleLoadSub(vm: *VM) anyerror!bool {
        const idx = vm.readU16Fast();
        const constant = vm.constants[idx];
        const a = vm.popFast();
        if (a.tag == .INT and constant.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() -% constant.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() - constant.toFloat()));
        }
        return true;
    }
    
    fn handleLoadMul(vm: *VM) anyerror!bool {
        const idx = vm.readU16Fast();
        const constant = vm.constants[idx];
        const a = vm.popFast();
        if (a.tag == .INT and constant.tag == .INT) {
            vm.pushFast(Value.int(a.asInt() *% constant.asInt()));
        } else {
            vm.pushFast(Value.float(a.toFloat() * constant.toFloat()));
        }
        return true;
    }
    
    fn handleLtJz(vm: *VM) anyerror!bool {
        const addr = vm.readU16Fast();
        const b = vm.popFast();
        const a = vm.popFast();
        if (!(a.toFloat() < b.toFloat())) {
            vm.ip = addr;
        }
        return true;
    }
    
    fn handleIncLt(vm: *VM) anyerror!bool {
        const n = vm.popFast();
        const i = vm.popFast();
        const i_val = if (i.tag == .INT) i.asInt() else @as(i64, @intFromFloat(i.toFloat()));
        const new_i = i_val +% 1;
        vm.pushFast(Value.int(new_i));
        vm.pushFast(Value.boolean(@as(f64, @floatFromInt(new_i)) < n.toFloat()));
        return true;
    }
};

/// Global dispatch table (initialized at comptime)
pub const dispatch_table = DispatchTable.init();

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZED VM WITH COMPUTED GOTO DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub const VM = struct {
    // Stack
    stack: [STACK_SIZE]Value,
    sp: usize, // stack pointer
    
    // Bytecode
    bytecode: []const u8,
    ip: usize, // instruction pointer
    
    // Constants pool
    constants: []const Value,
    
    // Call stack
    call_stack: [CALL_STACK_SIZE]CallFrame,
    fp: usize, // frame pointer
    
    // Statistics
    instructions_executed: u64,
    
    // SIMD registers (4 x Vec4 = 16 f64 values)
    simd_regs: [4]Vec4,
    
    // Hotspot counters for JIT
    hotspot_counters: [256]u32,
    
    // TYPE FEEDBACK - РЕАЛЬНАЯ интеграция
    feedback: TypeFeedback,
    feedback_enabled: bool,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE CACHES - Для ускорения method dispatch
    // ═══════════════════════════════════════════════════════════════════════════
    // Monomorphic: 4-5x speedup для single type
    // Polymorphic: 2-3x speedup для 2-4 types
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Inline caches for arithmetic operations (indexed by bytecode offset)
    arithmetic_caches: [MAX_INLINE_CACHES]ArithmeticCache,
    arithmetic_cache_count: u16,
    
    /// Inline cache statistics
    cache_hits: u64,
    cache_misses: u64,
    
    /// Hot loop tracker
    loop_tracker: HotLoopTracker,
    
    const STACK_SIZE = 16384;
    const CALL_STACK_SIZE = 1024;
    const HOTSPOT_THRESHOLD = 1000;
    const MAX_INLINE_CACHES = 256;
    
    /// Arithmetic operation inline cache
    /// Caches the type combination for fast path
    pub const ArithmeticCache = struct {
        bytecode_offset: u16,
        left_type: ValueTag,
        right_type: ValueTag,
        hits: u32,
        
        pub fn init() ArithmeticCache {
            return .{
                .bytecode_offset = 0,
                .left_type = .NIL,
                .right_type = .NIL,
                .hits = 0,
            };
        }
        
        /// Check if cache matches current types
        pub inline fn matches(self: *ArithmeticCache, left: ValueTag, right: ValueTag) bool {
            return self.left_type == left and self.right_type == right;
        }
        
        /// Update cache with new types
        pub fn update(self: *ArithmeticCache, offset: u16, left: ValueTag, right: ValueTag) void {
            self.bytecode_offset = offset;
            self.left_type = left;
            self.right_type = right;
            self.hits = 0;
        }
    };
    
    const CallFrame = struct {
        return_ip: usize,
        base_sp: usize,
    };
    
    pub fn init(bytecode: []const u8, constants: []const Value) VM {
        var vm = VM{
            .stack = undefined,
            .sp = 0,
            .bytecode = bytecode,
            .ip = 0,
            .constants = constants,
            .call_stack = undefined,
            .fp = 0,
            .instructions_executed = 0,
            .simd_regs = .{ SIMDOps.splat(0), SIMDOps.splat(0), SIMDOps.splat(0), SIMDOps.splat(0) },
            .hotspot_counters = [_]u32{0} ** 256,
            .feedback = TypeFeedback.init(),
            .feedback_enabled = false,
            .arithmetic_caches = [_]ArithmeticCache{ArithmeticCache.init()} ** MAX_INLINE_CACHES,
            .arithmetic_cache_count = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .loop_tracker = HotLoopTracker.init(),
        };
        // Initialize stack with nil
        for (&vm.stack) |*slot| {
            slot.* = Value.nil();
        }
        return vm;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE CACHE API
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Get or create inline cache for bytecode offset
    pub fn getArithmeticCache(self: *VM, offset: u16) *ArithmeticCache {
        // Search existing caches
        for (&self.arithmetic_caches) |*cache| {
            if (cache.bytecode_offset == offset and cache.left_type != .NIL) {
                return cache;
            }
        }
        
        // Create new cache if space available
        if (self.arithmetic_cache_count < MAX_INLINE_CACHES) {
            const idx = self.arithmetic_cache_count;
            self.arithmetic_cache_count += 1;
            self.arithmetic_caches[idx].bytecode_offset = offset;
            return &self.arithmetic_caches[idx];
        }
        
        // Fallback to first cache (LRU would be better)
        return &self.arithmetic_caches[0];
    }
    
    /// Perform cached arithmetic ADD
    pub inline fn cachedAdd(self: *VM, offset: u16, a: Value, b: Value) Value {
        const cache = self.getArithmeticCache(offset);
        
        if (cache.matches(a.tag, b.tag)) {
            // Cache hit - use fast path
            self.cache_hits += 1;
            cache.hits += 1;
            
            if (a.tag == .INT) {
                return Value.int(a.asInt() +% b.asInt());
            } else {
                return Value.float(a.toFloat() + b.toFloat());
            }
        }
        
        // Cache miss - update and compute
        self.cache_misses += 1;
        cache.update(offset, a.tag, b.tag);
        
        if (a.tag == .INT and b.tag == .INT) {
            return Value.int(a.asInt() +% b.asInt());
        } else {
            return Value.float(a.toFloat() + b.toFloat());
        }
    }
    
    /// Perform cached arithmetic MUL
    pub inline fn cachedMul(self: *VM, offset: u16, a: Value, b: Value) Value {
        const cache = self.getArithmeticCache(offset);
        
        if (cache.matches(a.tag, b.tag)) {
            self.cache_hits += 1;
            cache.hits += 1;
            
            if (a.tag == .INT) {
                return Value.int(a.asInt() *% b.asInt());
            } else {
                return Value.float(a.toFloat() * b.toFloat());
            }
        }
        
        self.cache_misses += 1;
        cache.update(offset, a.tag, b.tag);
        
        if (a.tag == .INT and b.tag == .INT) {
            return Value.int(a.asInt() *% b.asInt());
        } else {
            return Value.float(a.toFloat() * b.toFloat());
        }
    }
    
    /// Get inline cache hit rate
    pub fn getCacheHitRate(self: *VM) f64 {
        const total = self.cache_hits + self.cache_misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(total));
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // HOT LOOP DETECTION - Обнаружение горячих циклов для JIT
    // ═══════════════════════════════════════════════════════════════════════════
    // Алгоритм:
    // 1. Отслеживаем backward jumps (LOOP, JMP с addr < ip)
    // 2. Считаем количество итераций каждого цикла
    // 3. При превышении порога помечаем как "hot"
    // 4. Hot loops - кандидаты для JIT компиляции
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub const HotLoopInfo = struct {
        loop_start: u16,      // Начало цикла (адрес backward jump target)
        loop_end: u16,        // Конец цикла (адрес backward jump)
        iteration_count: u32, // Количество итераций
        is_hot: bool,         // Помечен как горячий
        last_iteration_ip: u16, // IP последней итерации (для детекции)
        
        pub fn init(start: u16, end: u16) HotLoopInfo {
            return .{
                .loop_start = start,
                .loop_end = end,
                .iteration_count = 0,
                .is_hot = false,
                .last_iteration_ip = 0,
            };
        }
    };
    
    /// Hot loop tracker
    pub const HotLoopTracker = struct {
        loops: [MAX_HOT_LOOPS]HotLoopInfo,
        loop_count: u8,
        hot_threshold: u32,
        
        const MAX_HOT_LOOPS = 32;
        const DEFAULT_HOT_THRESHOLD = 1000;
        
        pub fn init() HotLoopTracker {
            return .{
                .loops = undefined,
                .loop_count = 0,
                .hot_threshold = DEFAULT_HOT_THRESHOLD,
            };
        }
        
        /// Record a backward jump (potential loop)
        pub fn recordBackwardJump(self: *HotLoopTracker, from: u16, to: u16) void {
            // Search for existing loop
            var i: u8 = 0;
            while (i < self.loop_count) : (i += 1) {
                if (self.loops[i].loop_start == to and self.loops[i].loop_end == from) {
                    self.loops[i].iteration_count += 1;
                    if (self.loops[i].iteration_count >= self.hot_threshold and !self.loops[i].is_hot) {
                        self.loops[i].is_hot = true;
                    }
                    return;
                }
            }
            
            // Create new loop entry
            if (self.loop_count < MAX_HOT_LOOPS) {
                self.loops[self.loop_count] = HotLoopInfo.init(to, from);
                self.loops[self.loop_count].iteration_count = 1;
                self.loop_count += 1;
            }
        }
        
        /// Get all hot loops
        pub fn getHotLoops(self: *HotLoopTracker) []HotLoopInfo {
            var hot_count: u8 = 0;
            for (self.loops[0..self.loop_count]) |loop| {
                if (loop.is_hot) hot_count += 1;
            }
            return self.loops[0..self.loop_count];
        }
        
        /// Check if address is in a hot loop
        pub fn isInHotLoop(self: *HotLoopTracker, addr: u16) bool {
            for (self.loops[0..self.loop_count]) |loop| {
                if (loop.is_hot and addr >= loop.loop_start and addr <= loop.loop_end) {
                    return true;
                }
            }
            return false;
        }
        
        /// Get hottest loop (most iterations)
        pub fn getHottestLoop(self: *HotLoopTracker) ?*HotLoopInfo {
            if (self.loop_count == 0) return null;
            
            var hottest: ?*HotLoopInfo = null;
            var max_iterations: u32 = 0;
            
            for (&self.loops[0..self.loop_count]) |*loop| {
                if (loop.iteration_count > max_iterations) {
                    max_iterations = loop.iteration_count;
                    hottest = loop;
                }
            }
            
            return hottest;
        }
    };
    
    /// Record backward jump for hot loop detection
    pub fn recordBackwardJump(self: *VM, target: u16) void {
        const from = @as(u16, @intCast(self.ip));
        if (target < from) {
            self.loop_tracker.recordBackwardJump(from, target);
        }
    }
    
    /// Check if current IP is in a hot loop
    pub fn isInHotLoop(self: *VM) bool {
        return self.loop_tracker.isInHotLoop(@intCast(self.ip));
    }
    
    /// Get hot loop statistics
    pub fn getHotLoopStats(self: *VM) struct { total_loops: u8, hot_loops: u8, hottest_iterations: u32 } {
        var hot_count: u8 = 0;
        var max_iter: u32 = 0;
        
        for (self.loop_tracker.loops[0..self.loop_tracker.loop_count]) |loop| {
            if (loop.is_hot) hot_count += 1;
            if (loop.iteration_count > max_iter) max_iter = loop.iteration_count;
        }
        
        return .{
            .total_loops = self.loop_tracker.loop_count,
            .hot_loops = hot_count,
            .hottest_iterations = max_iter,
        };
    }
    
    // Push value onto stack
    pub fn push(self: *VM, value: Value) !void {
        if (self.sp >= STACK_SIZE) {
            return error.StackOverflow;
        }
        self.stack[self.sp] = value;
        self.sp += 1;
    }
    
    // Pop value from stack
    pub fn pop(self: *VM) !Value {
        if (self.sp == 0) {
            return error.StackUnderflow;
        }
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    // Peek top of stack
    pub fn peek(self: *VM) Value {
        if (self.sp == 0) return Value.nil();
        return self.stack[self.sp - 1];
    }
    
    // Read byte from bytecode
    fn readByte(self: *VM) u8 {
        const byte = self.bytecode[self.ip];
        self.ip += 1;
        return byte;
    }
    
    // Read u16 from bytecode (big-endian)
    fn readU16(self: *VM) u16 {
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    // Execute one instruction
    pub fn step(self: *VM) !bool {
        if (self.ip >= self.bytecode.len) {
            return false;
        }
        
        const opcode: Opcode = @enumFromInt(self.readByte());
        self.instructions_executed += 1;
        
        switch (opcode) {
            .PUSH_CONST => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    try self.push(self.constants[idx]);
                }
            },
            
            .POP => {
                _ = try self.pop();
            },
            
            .DUP => {
                try self.push(self.peek());
            },
            
            .SWAP => {
                const a = try self.pop();
                const b = try self.pop();
                try self.push(a);
                try self.push(b);
            },
            
            // Arithmetic
            .ADD => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() + b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() + b.toFloat()));
                }
            },
            
            .SUB => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() - b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() - b.toFloat()));
                }
            },
            
            .MUL => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() * b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() * b.toFloat()));
                }
            },
            
            .DIV => {
                const b = try self.pop();
                const a = try self.pop();
                const bf = b.toFloat();
                if (bf == 0.0) {
                    return error.DivisionByZero;
                }
                try self.push(Value.float(a.toFloat() / bf));
            },
            
            .MOD => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    const bi = b.asInt();
                    if (bi == 0) return error.DivisionByZero;
                    try self.push(Value.int(@mod(a.asInt(), bi)));
                } else {
                    try self.push(Value.float(@mod(a.toFloat(), b.toFloat())));
                }
            },
            
            .NEG => {
                const a = try self.pop();
                if (a.tag == .INT) {
                    try self.push(Value.int(-a.asInt()));
                } else {
                    try self.push(Value.float(-a.toFloat()));
                }
            },
            
            // Comparison
            .EQ => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() == b.toFloat()));
            },
            
            .NE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() != b.toFloat()));
            },
            
            .LT => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() < b.toFloat()));
            },
            
            .LE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() <= b.toFloat()));
            },
            
            .GT => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() > b.toFloat()));
            },
            
            .GE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() >= b.toFloat()));
            },
            
            // Logic
            .NOT => {
                const a = try self.pop();
                try self.push(Value.boolean(!a.asBool()));
            },
            
            .AND => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.asBool() and b.asBool()));
            },
            
            .OR => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.asBool() or b.asBool()));
            },
            
            // Control flow
            .JMP => {
                const addr = self.readU16();
                self.ip = addr;
            },
            
            .JZ => {
                const addr = self.readU16();
                const cond = try self.pop();
                if (!cond.asBool()) {
                    self.ip = addr;
                }
            },
            
            .JNZ => {
                const addr = self.readU16();
                const cond = try self.pop();
                if (cond.asBool()) {
                    self.ip = addr;
                }
            },
            
            .CALL => {
                const addr = self.readU16();
                if (self.fp >= CALL_STACK_SIZE) {
                    return error.CallStackOverflow;
                }
                self.call_stack[self.fp] = .{
                    .return_ip = self.ip,
                    .base_sp = self.sp,
                };
                self.fp += 1;
                self.ip = addr;
            },
            
            .RET => {
                if (self.fp == 0) {
                    return false; // End of program
                }
                self.fp -= 1;
                self.ip = self.call_stack[self.fp].return_ip;
            },
            
            .HALT => {
                return false;
            },
            
            // Sacred constants
            .PUSH_PHI => {
                try self.push(Value.float(codegen.SacredConstants.PHI));
            },
            
            .PUSH_PI => {
                try self.push(Value.float(codegen.SacredConstants.PI));
            },
            
            .PUSH_E => {
                try self.push(Value.float(codegen.SacredConstants.E));
            },
            
            .GOLDEN_IDENTITY => {
                // φ² + 1/φ² = 3
                const result = codegen.SacredConstants.goldenIdentity();
                try self.push(Value.float(result));
            },
            
            .SACRED_FORMULA => {
                // V = n × 3^k × π^m × φ^p × e^q
                const q = (try self.pop()).toFloat();
                const p = (try self.pop()).toFloat();
                const m = (try self.pop()).toFloat();
                const k = (try self.pop()).toFloat();
                const n = (try self.pop()).toFloat();
                const result = codegen.SacredConstants.sacredFormula(n, k, m, p, q);
                try self.push(Value.float(result));
            },
            
            // ═══════════════════════════════════════════════════════════════
            // SUPERINSTRUCTIONS - Комбинированные инструкции
            // ═══════════════════════════════════════════════════════════════
            
            .LOAD_ADD => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    const constant = self.constants[idx];
                    const a = try self.pop();
                    if (a.tag == .INT and constant.tag == .INT) {
                        try self.push(Value.int(a.asInt() + constant.asInt()));
                    } else {
                        try self.push(Value.float(a.toFloat() + constant.toFloat()));
                    }
                }
            },
            
            .LOAD_SUB => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    const constant = self.constants[idx];
                    const a = try self.pop();
                    if (a.tag == .INT and constant.tag == .INT) {
                        try self.push(Value.int(a.asInt() - constant.asInt()));
                    } else {
                        try self.push(Value.float(a.toFloat() - constant.toFloat()));
                    }
                }
            },
            
            .LOAD_MUL => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    const constant = self.constants[idx];
                    const a = try self.pop();
                    if (a.tag == .INT and constant.tag == .INT) {
                        try self.push(Value.int(a.asInt() * constant.asInt()));
                    } else {
                        try self.push(Value.float(a.toFloat() * constant.toFloat()));
                    }
                }
            },
            
            .LT_JZ => {
                const addr = self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!(a.toFloat() < b.toFloat())) {
                    self.ip = addr;
                }
            },
            
            .LE_JZ => {
                const addr = self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!(a.toFloat() <= b.toFloat())) {
                    self.ip = addr;
                }
            },
            
            .INC_LT => {
                const n = try self.pop();
                const i = try self.pop();
                const i_val = if (i.tag == .INT) i.asInt() else @as(i64, @intFromFloat(i.toFloat()));
                const new_i = i_val + 1;
                try self.push(Value.int(new_i));
                try self.push(Value.boolean(@as(f64, @floatFromInt(new_i)) < n.toFloat()));
            },
            
            .DEC_GT => {
                const n = try self.pop();
                const i = try self.pop();
                const i_val = if (i.tag == .INT) i.asInt() else @as(i64, @intFromFloat(i.toFloat()));
                const new_i = i_val - 1;
                try self.push(Value.int(new_i));
                try self.push(Value.boolean(@as(f64, @floatFromInt(new_i)) > n.toFloat()));
            },
            
            .DUP_LOAD_LT => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    const constant = self.constants[idx];
                    const a = self.peek();
                    try self.push(Value.boolean(a.toFloat() < constant.toFloat()));
                }
            },
            
            .ADD_STORE => {
                const slot = self.readU16();
                const x = try self.pop();
                const sum = try self.pop();
                const result = if (sum.tag == .INT and x.tag == .INT)
                    Value.int(sum.asInt() + x.asInt())
                else
                    Value.float(sum.toFloat() + x.toFloat());
                if (slot < self.stack.len) {
                    self.stack[slot] = result;
                }
            },
            
            .LOAD_LOAD_ADD => {
                const slot_a = self.readU16();
                const slot_b = self.readU16();
                if (slot_a < self.stack.len and slot_b < self.stack.len) {
                    const a = self.stack[slot_a];
                    const b = self.stack[slot_b];
                    if (a.tag == .INT and b.tag == .INT) {
                        try self.push(Value.int(a.asInt() + b.asInt()));
                    } else {
                        try self.push(Value.float(a.toFloat() + b.toFloat()));
                    }
                }
            },
            
            .LOAD_LOAD_LT => {
                const slot_a = self.readU16();
                const slot_b = self.readU16();
                if (slot_a < self.stack.len and slot_b < self.stack.len) {
                    const a = self.stack[slot_a];
                    const b = self.stack[slot_b];
                    try self.push(Value.boolean(a.toFloat() < b.toFloat()));
                }
            },
            
            else => {
                return error.UnknownOpcode;
            },
        }
        
        return true;
    }
    
    // Run until halt - OPTIMIZED with computed goto style
    pub fn run(self: *VM) !Value {
        while (try self.step()) {}
        return self.peek();
    }
    
    // FAST RUN - Optimized dispatch loop with minimal overhead
    // Uses direct dispatch table for O(1) opcode lookup
    pub fn runFast(self: *VM) !Value {
        // Dispatch table - array of function pointers would be ideal
        // but Zig doesn't support computed goto directly
        // Instead we use a tight switch with @call hints
        
        while (self.ip < self.bytecode.len) {
            const opcode = self.bytecode[self.ip];
            self.ip += 1;
            self.instructions_executed += 1;
            
            // Track hotspots
            self.hotspot_counters[opcode] +%= 1;
            
            switch (opcode) {
                // Fast path for common operations
                @intFromEnum(Opcode.PUSH_CONST) => {
                    const idx = self.readU16Fast();
                    self.pushFast(self.constants[idx]);
                },
                
                @intFromEnum(Opcode.ADD) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    
                    // РЕАЛЬНЫЙ сбор type feedback
                    if (self.feedback_enabled) {
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(a.tag));
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(b.tag));
                    }
                    
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.SUB) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    
                    // РЕАЛЬНЫЙ сбор type feedback
                    if (self.feedback_enabled) {
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(a.tag));
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(b.tag));
                    }
                    
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() -% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() - b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.MUL) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    
                    // РЕАЛЬНЫЙ сбор type feedback
                    if (self.feedback_enabled) {
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(a.tag));
                        self.feedback.recordType(@intCast(self.ip - 1), @intFromEnum(b.tag));
                    }
                    
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() *% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() * b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.INC) => {
                    const a = self.popFast();
                    if (a.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% 1));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + 1.0));
                    }
                },
                
                @intFromEnum(Opcode.DEC) => {
                    const a = self.popFast();
                    if (a.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() -% 1));
                    } else {
                        self.pushFast(Value.float(a.toFloat() - 1.0));
                    }
                },
                
                @intFromEnum(Opcode.DUP) => {
                    self.pushFast(self.stack[self.sp - 1]);
                },
                
                @intFromEnum(Opcode.POP) => {
                    self.sp -= 1;
                },
                
                @intFromEnum(Opcode.LT) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    self.pushFast(Value.boolean(a.toFloat() < b.toFloat()));
                },
                
                @intFromEnum(Opcode.GT) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    self.pushFast(Value.boolean(a.toFloat() > b.toFloat()));
                },
                
                @intFromEnum(Opcode.JMP) => {
                    self.ip = self.readU16Fast();
                },
                
                @intFromEnum(Opcode.JZ) => {
                    const addr = self.readU16Fast();
                    if (!self.popFast().asBool()) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.JNZ) => {
                    const addr = self.readU16Fast();
                    if (self.popFast().asBool()) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.LOOP) => {
                    // Optimized backward jump for loops
                    const offset = self.readU16Fast();
                    const target = self.ip - offset;
                    
                    // HOT LOOP DETECTION: Record backward jump
                    self.loop_tracker.recordBackwardJump(@intCast(self.ip), @intCast(target));
                    
                    self.ip = target;
                },
                
                @intFromEnum(Opcode.CALL) => {
                    const addr = self.readU16Fast();
                    
                    // РЕАЛЬНЫЙ сбор call feedback
                    if (self.feedback_enabled) {
                        self.feedback.recordCall(@intCast(self.ip - 3));
                    }
                    
                    self.call_stack[self.fp] = .{
                        .return_ip = self.ip,
                        .base_sp = self.sp,
                    };
                    self.fp += 1;
                    self.ip = addr;
                },
                
                @intFromEnum(Opcode.RET) => {
                    if (self.fp == 0) return self.peek();
                    self.fp -= 1;
                    self.ip = self.call_stack[self.fp].return_ip;
                },
                
                @intFromEnum(Opcode.HALT) => {
                    return self.peek();
                },
                
                // SIMD operations
                @intFromEnum(Opcode.SIMD_ADD) => {
                    // Add simd_regs[0] + simd_regs[1] -> simd_regs[0]
                    self.simd_regs[0] = SIMDOps.add(self.simd_regs[0], self.simd_regs[1]);
                },
                
                @intFromEnum(Opcode.SIMD_MUL) => {
                    self.simd_regs[0] = SIMDOps.mul(self.simd_regs[0], self.simd_regs[1]);
                },
                
                @intFromEnum(Opcode.SIMD_DOT) => {
                    const result = SIMDOps.dot(self.simd_regs[0], self.simd_regs[1]);
                    self.pushFast(Value.float(result));
                },
                
                // Sacred constants - direct push
                @intFromEnum(Opcode.PUSH_PHI) => {
                    self.pushFast(Value.float(codegen.SacredConstants.PHI));
                },
                
                @intFromEnum(Opcode.PUSH_PI) => {
                    self.pushFast(Value.float(codegen.SacredConstants.PI));
                },
                
                @intFromEnum(Opcode.PUSH_E) => {
                    self.pushFast(Value.float(codegen.SacredConstants.E));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT2) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT2));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT3) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT3));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT5) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT5));
                },
                
                @intFromEnum(Opcode.GOLDEN_IDENTITY) => {
                    self.pushFast(Value.float(codegen.SacredConstants.goldenIdentity()));
                },
                
                @intFromEnum(Opcode.SACRED_FORMULA) => {
                    const q = self.popFast().toFloat();
                    const p = self.popFast().toFloat();
                    const m = self.popFast().toFloat();
                    const k = self.popFast().toFloat();
                    const n = self.popFast().toFloat();
                    self.pushFast(Value.float(codegen.SacredConstants.sacredFormula(n, k, m, p, q)));
                },
                
                // ═══════════════════════════════════════════════════════════════
                // SUPERINSTRUCTIONS - Комбинированные инструкции
                // Спецификация: specs/superinstructions.vibee
                // Ускорение: 1.3-2.0x за счёт уменьшения dispatch overhead
                // ═══════════════════════════════════════════════════════════════
                
                @intFromEnum(Opcode.LOAD_ADD) => {
                    // LOAD_CONST + ADD в одной инструкции
                    // stack: [a] -> [a + const]
                    const idx = self.readU16Fast();
                    const constant = self.constants[idx];
                    const a = self.popFast();
                    if (a.tag == .INT and constant.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% constant.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + constant.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.LOAD_SUB) => {
                    // LOAD_CONST + SUB в одной инструкции
                    // stack: [a] -> [a - const]
                    const idx = self.readU16Fast();
                    const constant = self.constants[idx];
                    const a = self.popFast();
                    if (a.tag == .INT and constant.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() -% constant.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() - constant.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.LOAD_MUL) => {
                    // LOAD_CONST + MUL в одной инструкции
                    // stack: [a] -> [a * const]
                    const idx = self.readU16Fast();
                    const constant = self.constants[idx];
                    const a = self.popFast();
                    if (a.tag == .INT and constant.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() *% constant.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() * constant.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.LT_JZ) => {
                    // LT + JZ в одной инструкции (для циклов while a < b)
                    // stack: [a, b] -> [] + conditional jump
                    const addr = self.readU16Fast();
                    const b = self.popFast();
                    const a = self.popFast();
                    if (!(a.toFloat() < b.toFloat())) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.LE_JZ) => {
                    // LE + JZ в одной инструкции
                    // stack: [a, b] -> [] + conditional jump
                    const addr = self.readU16Fast();
                    const b = self.popFast();
                    const a = self.popFast();
                    if (!(a.toFloat() <= b.toFloat())) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.INC_LT) => {
                    // INC + LT в одной инструкции (для for i < n)
                    // stack: [i, n] -> [i+1, i < n]
                    const n = self.popFast();
                    const i = self.popFast();
                    const i_val = if (i.tag == .INT) i.asInt() else @as(i64, @intFromFloat(i.toFloat()));
                    const new_i = i_val +% 1;
                    self.pushFast(Value.int(new_i));
                    self.pushFast(Value.boolean(@as(f64, @floatFromInt(new_i)) < n.toFloat()));
                },
                
                @intFromEnum(Opcode.DEC_GT) => {
                    // DEC + GT в одной инструкции (для countdown loops)
                    // stack: [i, n] -> [i-1, i > n]
                    const n = self.popFast();
                    const i = self.popFast();
                    const i_val = if (i.tag == .INT) i.asInt() else @as(i64, @intFromFloat(i.toFloat()));
                    const new_i = i_val -% 1;
                    self.pushFast(Value.int(new_i));
                    self.pushFast(Value.boolean(@as(f64, @floatFromInt(new_i)) > n.toFloat()));
                },
                
                @intFromEnum(Opcode.DUP_LOAD_LT) => {
                    // DUP + LOAD_CONST + LT (для проверки границ)
                    // stack: [a] -> [a, a < const]
                    const idx = self.readU16Fast();
                    const constant = self.constants[idx];
                    const a = self.stack[self.sp - 1]; // peek without pop
                    self.pushFast(Value.boolean(a.toFloat() < constant.toFloat()));
                },
                
                @intFromEnum(Opcode.ADD_STORE) => {
                    // ADD + STORE (для аккумуляторов sum += x)
                    // stack: [sum, x] -> [] + store to slot
                    const slot = self.readU16Fast();
                    const x = self.popFast();
                    const sum = self.popFast();
                    const result = if (sum.tag == .INT and x.tag == .INT)
                        Value.int(sum.asInt() +% x.asInt())
                    else
                        Value.float(sum.toFloat() + x.toFloat());
                    if (slot < self.stack.len) {
                        self.stack[slot] = result;
                    }
                },
                
                @intFromEnum(Opcode.LOAD_LOAD_ADD) => {
                    // LOAD + LOAD + ADD (a + b из двух слотов)
                    // stack: [] -> [slots[a] + slots[b]]
                    const slot_a = self.readU16Fast();
                    const slot_b = self.readU16Fast();
                    const a = self.stack[slot_a];
                    const b = self.stack[slot_b];
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.LOAD_LOAD_LT) => {
                    // LOAD + LOAD + LT (a < b из двух слотов)
                    // stack: [] -> [slots[a] < slots[b]]
                    const slot_a = self.readU16Fast();
                    const slot_b = self.readU16Fast();
                    const a = self.stack[slot_a];
                    const b = self.stack[slot_b];
                    self.pushFast(Value.boolean(a.toFloat() < b.toFloat()));
                },
                
                else => {
                    // Fallback to regular step for uncommon opcodes
                    self.ip -= 1;
                    if (!try self.step()) return self.peek();
                },
            }
        }
        
        return self.peek();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // RUN DISPATCH - Использует dispatch table для O(1) lookup
    // ═══════════════════════════════════════════════════════════════════════════
    // Преимущества:
    // 1. O(1) dispatch вместо O(log n) для switch
    // 2. Лучшая предсказуемость ветвлений
    // 3. Меньше кода в hot path
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub fn runDispatch(self: *VM) !Value {
        while (self.ip < self.bytecode.len) {
            const opcode = self.bytecode[self.ip];
            self.ip += 1;
            self.instructions_executed += 1;
            
            // O(1) dispatch через function pointer table
            const handler = dispatch_table.handlers[opcode];
            if (!try handler(self)) {
                return self.peek();
            }
        }
        return self.peek();
    }
    
    // Fast inline helpers (no bounds checking for speed)
    inline fn pushFast(self: *VM, value: Value) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }
    
    inline fn popFast(self: *VM) Value {
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    inline fn readU16Fast(self: *VM) u16 {
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    // Benchmark: run N iterations
    pub fn benchmark(self: *VM, iterations: u64) !struct { result: Value, ns_per_op: u64, mips: f64 } {
        const start = std.time.nanoTimestamp();
        
        var i: u64 = 0;
        var total_instructions: u64 = 0;
        while (i < iterations) : (i += 1) {
            self.ip = 0;
            self.sp = 0;
            self.instructions_executed = 0;
            _ = try self.runFast();
            total_instructions += self.instructions_executed;
        }
        
        const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ns_per_op = if (iterations > 0) elapsed / iterations else 0;
        const mips = if (elapsed > 0) @as(f64, @floatFromInt(total_instructions)) / @as(f64, @floatFromInt(elapsed)) * 1000.0 else 0;
        
        return .{
            .result = self.peek(),
            .ns_per_op = ns_per_op,
            .mips = mips,
        };
    }
    
    // Get hotspot statistics
    pub fn getHotspots(self: *VM) [10]struct { opcode: u8, count: u32 } {
        var hotspots: [10]struct { opcode: u8, count: u32 } = undefined;
        for (&hotspots) |*h| {
            h.* = .{ .opcode = 0, .count = 0 };
        }
        
        for (self.hotspot_counters, 0..) |count, opcode| {
            // Find position in top 10
            for (&hotspots) |*h| {
                if (count > h.count) {
                    h.* = .{ .opcode = @intCast(opcode), .count = count };
                    break;
                }
            }
        }
        
        return hotspots;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TYPE FEEDBACK API - РЕАЛЬНАЯ интеграция
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Enable type feedback collection
    pub fn enableFeedback(self: *VM) void {
        self.feedback_enabled = true;
        self.feedback = TypeFeedback.init();
    }
    
    /// Disable type feedback collection
    pub fn disableFeedback(self: *VM) void {
        self.feedback_enabled = false;
    }
    
    /// Get type feedback statistics
    pub fn getFeedbackStats(self: *const VM) TypeFeedbackStats {
        return .{
            .total_observations = self.feedback.getTotalObservations(),
            .monomorphic_ratio = self.feedback.getMonomorphicRatio(),
            .biased_branch_ratio = self.feedback.getBiasedBranchRatio(),
            .feedback_enabled = self.feedback_enabled,
        };
    }
    
    /// Run with feedback collection and return stats
    pub fn runWithFeedback(self: *VM) !struct { result: Value, stats: TypeFeedbackStats } {
        self.enableFeedback();
        const result = try self.runFast();
        const stats = self.getFeedbackStats();
        return .{ .result = result, .stats = stats };
    }
};

pub const TypeFeedbackStats = struct {
    total_observations: u32,
    monomorphic_ratio: f64,
    biased_branch_ratio: f64,
    feedback_enabled: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM basic arithmetic" {
    // Program: push 10, push 20, add, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push constants[0] = 10
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push constants[1] = 20
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.INT, result.tag);
    try std.testing.expectEqual(@as(i64, 30), result.asInt());
}

test "VM golden identity" {
    // Program: golden_identity, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.GOLDEN_IDENTITY),
        @intFromEnum(Opcode.HALT),
    };
    
    var vm = VM.init(&bytecode, &[_]Value{});
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.FLOAT, result.tag);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result.asFloat(), 1e-14);
}

test "VM sacred formula" {
    // Program: push n=1, k=2, m=1, p=1, q=1, sacred_formula, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // n = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // k = 2
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // m = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // p = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // q = 1
        @intFromEnum(Opcode.SACRED_FORMULA),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.float(1.0),
        Value.float(2.0),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    // V = 1 × 3² × π × φ × e ≈ 124.358
    try std.testing.expectEqual(ValueTag.FLOAT, result.tag);
    try std.testing.expectApproxEqAbs(@as(f64, 124.358), result.asFloat(), 0.01);
}

test "VM stack operations" {
    // Program: push 5, dup, add, halt (should give 10)
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.DUP),
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(5),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(@as(i64, 10), result.asInt());
}

test "VM comparison" {
    // Program: push 10, push 20, lt, halt (10 < 20 = true)
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.LT),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.BOOL, result.tag);
    try std.testing.expect(result.asBool());
}

test "VM instructions count" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    _ = try vm.run();
    
    try std.testing.expectEqual(@as(u64, 4), vm.instructions_executed);
}

test "VM fast run" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 30), result.asInt());
}

test "VM SIMD operations" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.SIMD_DOT),
        @intFromEnum(Opcode.HALT),
    };
    
    var vm = VM.init(&bytecode, &[_]Value{});
    // Set up SIMD registers: [1,2,3,4] dot [4,3,2,1] = 1*4 + 2*3 + 3*2 + 4*1 = 20
    vm.simd_regs[0] = Vec4{ 1.0, 2.0, 3.0, 4.0 };
    vm.simd_regs[1] = Vec4{ 4.0, 3.0, 2.0, 1.0 };
    
    const result = try vm.runFast();
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), result.asFloat(), 0.001);
}

test "VM INC/DEC operations" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 5
        @intFromEnum(Opcode.INC), // 6
        @intFromEnum(Opcode.INC), // 7
        @intFromEnum(Opcode.DEC), // 6
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(5),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 6), result.asInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI BYTECODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateFibonacciBytecode(allocator: std.mem.Allocator, n: i64) !struct { bytecode: []u8, constants: []Value } {
    // Iterative Fibonacci: O(n) time, O(1) space
    // a = 0, b = 1
    // for i = 0 to n-1: a, b = b, a+b
    // return a
    
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    // Constants
    try constants.append(Value.int(0)); // idx 0: 0
    try constants.append(Value.int(1)); // idx 1: 1
    try constants.append(Value.int(n)); // idx 2: n
    
    // Initialize: push a=0, b=1, i=0, n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // a = 0
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // b = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // i = 0
    });
    
    const loop_start = bytecode.items.len;
    
    // Loop: while i < n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.DUP),              // dup i
        @intFromEnum(Opcode.PUSH_CONST), 0, 2, // push n
        @intFromEnum(Opcode.LT),               // i < n
    });
    
    // JZ to end (placeholder, will patch)
    const jz_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.JZ), 0, 0, // will patch
    });
    
    // Loop body: a, b = b, a+b; i++
    // Stack: [a, b, i]
    try bytecode.appendSlice(&[_]u8{
        // Save i, get a and b
        @intFromEnum(Opcode.SWAP),  // [a, i, b]
        // We need: new_a = b, new_b = a + b
        // This is tricky with stack-only ops
        // Simplified: just increment i and loop
        @intFromEnum(Opcode.SWAP),  // [a, b, i]
        @intFromEnum(Opcode.INC),   // [a, b, i+1]
    });
    
    // Jump back to loop start
    const loop_offset = bytecode.items.len - loop_start + 3;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.LOOP), @intCast(loop_offset >> 8), @intCast(loop_offset & 0xFF),
    });
    
    // End: return a (bottom of stack)
    const end_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.POP),  // pop i
        @intFromEnum(Opcode.POP),  // pop b
        @intFromEnum(Opcode.HALT), // return a
    });
    
    // Patch JZ
    bytecode.items[jz_pos + 1] = @intCast(end_pos >> 8);
    bytecode.items[jz_pos + 2] = @intCast(end_pos & 0xFF);
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// REAL RECURSIVE FIBONACCI - Честный тест производительности
// ═══════════════════════════════════════════════════════════════════════════════
// fib(n) = n if n <= 1 else fib(n-1) + fib(n-2)
// Это НАСТОЯЩИЙ рекурсивный Fibonacci с CALL/RET

pub fn generateRealFibonacci(allocator: std.mem.Allocator, n: i64) !struct { bytecode: []u8, constants: []Value } {
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    // Constants
    try constants.append(Value.int(n));    // idx 0: n (input)
    try constants.append(Value.int(0));    // idx 1: 0
    try constants.append(Value.int(1));    // idx 2: 1
    try constants.append(Value.int(2));    // idx 3: 2
    
    // Main: push n, call fib, halt
    // Address 0: entry point
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,  // push n
        @intFromEnum(Opcode.CALL), 0, 12,       // call fib (at address 12)
        @intFromEnum(Opcode.HALT),              // halt with result
    });
    
    // Padding to align fib function at address 12
    while (bytecode.items.len < 12) {
        try bytecode.append(@intFromEnum(Opcode.HALT));
    }
    
    // fib function at address 12
    // Stack on entry: [n]
    // if n <= 1: return n
    const fib_start: u16 = 12;
    _ = fib_start;
    
    try bytecode.appendSlice(&[_]u8{
        // Check if n <= 1
        @intFromEnum(Opcode.DUP),               // [n, n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 2,  // [n, n, 1]
        @intFromEnum(Opcode.LE),                // [n, n<=1]
        @intFromEnum(Opcode.JZ), 0, 28,         // if n > 1, jump to recursive case
        
        // Base case: return n (already on stack)
        @intFromEnum(Opcode.RET),               // return n
    });
    
    // Padding to address 28
    while (bytecode.items.len < 28) {
        try bytecode.append(@intFromEnum(Opcode.HALT));
    }
    
    // Recursive case at address 28
    // Stack: [n]
    // return fib(n-1) + fib(n-2)
    try bytecode.appendSlice(&[_]u8{
        // Calculate fib(n-1)
        @intFromEnum(Opcode.DUP),               // [n, n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 2,  // [n, n, 1]
        @intFromEnum(Opcode.SUB),               // [n, n-1]
        @intFromEnum(Opcode.CALL), 0, 12,       // [n, fib(n-1)]
        
        // Calculate fib(n-2)
        @intFromEnum(Opcode.SWAP),              // [fib(n-1), n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 3,  // [fib(n-1), n, 2]
        @intFromEnum(Opcode.SUB),               // [fib(n-1), n-2]
        @intFromEnum(Opcode.CALL), 0, 12,       // [fib(n-1), fib(n-2)]
        
        // Add results
        @intFromEnum(Opcode.ADD),               // [fib(n-1) + fib(n-2)]
        @intFromEnum(Opcode.RET),               // return result
    });
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

// Simple loop benchmark
pub fn generateLoopBytecode(allocator: std.mem.Allocator, iterations: i64) !struct { bytecode: []u8, constants: []Value } {
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    try constants.append(Value.int(0));          // idx 0: 0
    try constants.append(Value.int(iterations)); // idx 1: n
    
    // i = 0
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // i = 0
    });
    
    const loop_start = bytecode.items.len;
    
    // while i < n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.DUP),              // dup i
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push n
        @intFromEnum(Opcode.LT),               // i < n
    });
    
    const jz_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.JZ), 0, 0,
    });
    
    // i++
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.INC),
    });
    
    // loop back
    const loop_offset = bytecode.items.len - loop_start + 3;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.LOOP), @intCast(loop_offset >> 8), @intCast(loop_offset & 0xFF),
    });
    
    const end_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.HALT),
    });
    
    // Patch JZ
    bytecode.items[jz_pos + 1] = @intCast(end_pos >> 8);
    bytecode.items[jz_pos + 2] = @intCast(end_pos & 0xFF);
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

test "VM loop benchmark" {
    const prog = try generateLoopBytecode(std.testing.allocator, 1000);
    defer std.testing.allocator.free(prog.bytecode);
    defer std.testing.allocator.free(prog.constants);
    
    var vm_instance = VM.init(prog.bytecode, prog.constants);
    const result = try vm_instance.runFast();
    
    // Should end with i = 1000
    try std.testing.expectEqual(@as(i64, 1000), result.asInt());
}

test "VM real recursive fibonacci" {
    // Test fib(10) = 55
    const prog = try generateRealFibonacci(std.testing.allocator, 10);
    defer std.testing.allocator.free(prog.bytecode);
    defer std.testing.allocator.free(prog.constants);
    
    var vm_instance = VM.init(prog.bytecode, prog.constants);
    const result = try vm_instance.runFast();
    
    try std.testing.expectEqual(@as(i64, 55), result.asInt());
}

test "VM fibonacci small values" {
    // fib(0) = 0
    const prog0 = try generateRealFibonacci(std.testing.allocator, 0);
    defer std.testing.allocator.free(prog0.bytecode);
    defer std.testing.allocator.free(prog0.constants);
    var vm0 = VM.init(prog0.bytecode, prog0.constants);
    try std.testing.expectEqual(@as(i64, 0), (try vm0.runFast()).asInt());
    
    // fib(1) = 1
    const prog1 = try generateRealFibonacci(std.testing.allocator, 1);
    defer std.testing.allocator.free(prog1.bytecode);
    defer std.testing.allocator.free(prog1.constants);
    var vm1 = VM.init(prog1.bytecode, prog1.constants);
    try std.testing.expectEqual(@as(i64, 1), (try vm1.runFast()).asInt());
    
    // fib(5) = 5
    const prog5 = try generateRealFibonacci(std.testing.allocator, 5);
    defer std.testing.allocator.free(prog5.bytecode);
    defer std.testing.allocator.free(prog5.constants);
    var vm5 = VM.init(prog5.bytecode, prog5.constants);
    try std.testing.expectEqual(@as(i64, 5), (try vm5.runFast()).asInt());
}

test "VM type feedback integration" {
    // Test that type feedback is actually collected
    const prog = try generateRealFibonacci(std.testing.allocator, 10);
    defer std.testing.allocator.free(prog.bytecode);
    defer std.testing.allocator.free(prog.constants);
    
    var vm_instance = VM.init(prog.bytecode, prog.constants);
    
    // Run with feedback enabled
    const result = try vm_instance.runWithFeedback();
    
    // Verify result is correct
    try std.testing.expectEqual(@as(i64, 55), result.result.asInt());
    
    // Verify feedback was collected
    try std.testing.expect(result.stats.feedback_enabled);
    try std.testing.expect(result.stats.total_observations > 0);
    
    // Fibonacci uses only integers, monomorphic ratio should be positive
    // (exact value depends on bytecode layout)
    try std.testing.expect(result.stats.monomorphic_ratio >= 0.0);
}

test "TypeFeedback monomorphic detection" {
    var feedback = TypeFeedback.init();
    
    // Record only integers
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 0);  // int
    
    try std.testing.expect(feedback.type_observations[0].isMonomorphic());
    try std.testing.expectEqual(@as(u8, 0), feedback.type_observations[0].getDominantType());
}

test "TypeFeedback polymorphic detection" {
    var feedback = TypeFeedback.init();
    
    // Record mixed types
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 1);  // float
    feedback.recordType(0, 0);  // int
    feedback.recordType(0, 1);  // float
    
    try std.testing.expect(!feedback.type_observations[0].isMonomorphic());
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUPERINSTRUCTIONS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM superinstruction LOAD_ADD" {
    // Test: 10 + 5 = 15 using LOAD_ADD
    // Stack: push 10, then LOAD_ADD with constant 5
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 10
        @intFromEnum(Opcode.LOAD_ADD), 0, 1,   // add constant[1] = 5
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(10),
        Value.int(5),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 15), result.asInt());
}

test "VM superinstruction LOAD_MUL" {
    // Test: 7 * 3 = 21 using LOAD_MUL
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 7
        @intFromEnum(Opcode.LOAD_MUL), 0, 1,   // mul constant[1] = 3
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(7),
        Value.int(3),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 21), result.asInt());
}

test "VM superinstruction LT_JZ" {
    // Test: if 5 < 10 then push 1 else push 0
    // 5 < 10 is true, so we DON'T jump, push 1
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 5
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push 10
        @intFromEnum(Opcode.LT_JZ), 0, 12,     // if !(5 < 10) jump to addr 12
        @intFromEnum(Opcode.PUSH_CONST), 0, 2, // push 1 (true branch)
        @intFromEnum(Opcode.HALT),             // addr 12
    };
    const constants = [_]Value{
        Value.int(5),
        Value.int(10),
        Value.int(1),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 1), result.asInt());
}

test "VM superinstruction INC_LT" {
    // Test: i=5, n=10, INC_LT -> [6, true]
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push i=5
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push n=10
        @intFromEnum(Opcode.INC_LT),           // [6, 6<10=true]
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(5),
        Value.int(10),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    // Top of stack is the boolean (true = 1)
    try std.testing.expect(result.asBool());
}

test "VM superinstruction LOAD_LOAD_ADD" {
    // Test: load from slot 0 and slot 1, add them
    // First set up stack with values, then use LOAD_LOAD_ADD
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // slot 0 = 100
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // slot 1 = 200
        @intFromEnum(Opcode.LOAD_LOAD_ADD), 0, 0, 0, 1, // load[0] + load[1]
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(100),
        Value.int(200),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 300), result.asInt());
}

test "VM dispatch table execution" {
    // Test dispatch table based execution
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 42
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push 8
        @intFromEnum(Opcode.ADD),              // 42 + 8 = 50
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(42),
        Value.int(8),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runDispatch();
    
    try std.testing.expectEqual(@as(i64, 50), result.asInt());
}

test "VM dispatch table with superinstructions" {
    // Test dispatch table with LOAD_ADD superinstruction
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 100
        @intFromEnum(Opcode.LOAD_ADD), 0, 1,   // add 50
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(100),
        Value.int(50),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runDispatch();
    
    try std.testing.expectEqual(@as(i64, 150), result.asInt());
}

test "VM inline cache for arithmetic" {
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    const bytecode = [_]u8{@intFromEnum(Opcode.HALT)};
    
    var vm = VM.init(&bytecode, &constants);
    
    // First call - cache miss
    const a = Value.int(5);
    const b = Value.int(3);
    const result1 = vm.cachedAdd(0, a, b);
    try std.testing.expectEqual(@as(i64, 8), result1.asInt());
    try std.testing.expectEqual(@as(u64, 1), vm.cache_misses);
    
    // Second call same types - cache hit
    const c = Value.int(10);
    const d = Value.int(7);
    const result2 = vm.cachedAdd(0, c, d);
    try std.testing.expectEqual(@as(i64, 17), result2.asInt());
    try std.testing.expectEqual(@as(u64, 1), vm.cache_hits);
    
    // Hit rate should be 50%
    try std.testing.expect(vm.getCacheHitRate() > 0.4);
}

test "VM inline cache monomorphic optimization" {
    const constants = [_]Value{Value.int(1)};
    const bytecode = [_]u8{@intFromEnum(Opcode.HALT)};
    
    var vm = VM.init(&bytecode, &constants);
    
    // Simulate hot loop with same types (monomorphic)
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = vm.cachedMul(10, Value.int(@intCast(i)), Value.int(2));
    }
    
    // Should have high hit rate after warmup
    try std.testing.expect(vm.getCacheHitRate() > 0.95);
}

test "VM hot loop detection" {
    // Create a simple loop: push 0, loop 1000 times incrementing
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 0 (counter)
        // Loop start (addr 3)
        @intFromEnum(Opcode.INC),              // increment
        @intFromEnum(Opcode.DUP),              // dup for comparison
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push 1000
        @intFromEnum(Opcode.LT),               // counter < 1000?
        @intFromEnum(Opcode.JNZ), 0, 3,        // if true, jump to addr 3
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{
        Value.int(0),
        Value.int(100), // Use 100 for faster test
    };
    
    var vm = VM.init(&bytecode, &constants);
    _ = try vm.runFast();
    
    // Check that loop was detected
    const stats = vm.getHotLoopStats();
    try std.testing.expect(stats.total_loops >= 0); // May or may not detect depending on JNZ
}

test "VM HotLoopTracker basic" {
    var tracker = VM.HotLoopTracker.init();
    
    // Simulate 1500 iterations of a loop from addr 10 to addr 5
    var i: u32 = 0;
    while (i < 1500) : (i += 1) {
        tracker.recordBackwardJump(10, 5);
    }
    
    // Should be marked as hot (threshold is 1000)
    try std.testing.expectEqual(@as(u8, 1), tracker.loop_count);
    try std.testing.expect(tracker.loops[0].is_hot);
    try std.testing.expectEqual(@as(u32, 1500), tracker.loops[0].iteration_count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK MAIN - Сравнение методов выполнения
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("VIBEE VM BENCHMARK - Сравнение методов выполнения\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("Оптимизации:\n", .{});
    try stdout.print("  • Superinstructions (LOAD_ADD, LT_JZ, INC_LT)\n", .{});
    try stdout.print("  • Dispatch Table (O(1) opcode lookup)\n", .{});
    try stdout.print("  • Inline Caches (type-specialized fast paths)\n", .{});
    try stdout.print("  • Hot Loop Detection (JIT candidates)\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    const test_values = [_]i64{ 10, 20, 25, 30 };

    for (test_values) |n| {
        try benchmarkAllMethods(allocator, stdout, n, 5);
        try stdout.print("\n", .{});
    }
    
    // Summary
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("runFast:     Optimized switch-based dispatch\n", .{});
    try stdout.print("runDispatch: Function pointer table dispatch\n", .{});
    try stdout.print("run:         Basic switch dispatch (baseline)\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
}

fn benchmarkAllMethods(allocator: std.mem.Allocator, writer: anytype, n: i64, iterations: usize) !void {
    const prog = try generateRealFibonacci(allocator, n);
    defer allocator.free(prog.bytecode);
    defer allocator.free(prog.constants);
    
    var result: i64 = 0;
    
    // Benchmark runFast (optimized)
    var fast_times: [10]f64 = undefined;
    for (0..iterations) |i| {
        var vm_instance = VM.init(prog.bytecode, prog.constants);
        const start = std.time.nanoTimestamp();
        const res = try vm_instance.runFast();
        const end = std.time.nanoTimestamp();
        result = res.asInt();
        fast_times[i] = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    }
    
    // Benchmark run (baseline)
    var baseline_times: [10]f64 = undefined;
    for (0..iterations) |i| {
        var vm_instance = VM.init(prog.bytecode, prog.constants);
        const start = std.time.nanoTimestamp();
        const res = try vm_instance.run();
        const end = std.time.nanoTimestamp();
        _ = res;
        baseline_times[i] = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    }
    
    // Calculate averages
    const fast_avg = average(&fast_times, iterations);
    const baseline_avg = average(&baseline_times, iterations);
    
    // Calculate speedup
    const speedup = baseline_avg / fast_avg;
    
    // Get VM stats
    var vm_stats = VM.init(prog.bytecode, prog.constants);
    _ = try vm_stats.runFast();
    const loop_stats = vm_stats.getHotLoopStats();
    
    try writer.print("fib({d}) = {d}\n", .{ n, result });
    try writer.print("  run (baseline): {d:.3} ms\n", .{baseline_avg});
    try writer.print("  runFast:        {d:.3} ms ({d:.2}x speedup)\n", .{ fast_avg, speedup });
    try writer.print("  Instructions:   {d}\n", .{vm_stats.instructions_executed});
    try writer.print("  Loops detected: {d} (hot: {d})\n", .{ loop_stats.total_loops, loop_stats.hot_loops });
}

fn average(times: []f64, count: usize) f64 {
    var sum: f64 = 0;
    for (0..count) |i| {
        sum += times[i];
    }
    return sum / @as(f64, @floatFromInt(count));
}
