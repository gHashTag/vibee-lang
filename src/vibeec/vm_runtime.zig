// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC VM RUNTIME - .999 BYTECODE EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V37 - Stack-based Virtual Machine with Sacred Constants
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: D&C (dispatch loop), PRE (computed goto), HSH (native lookup)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const bytecode = @import("bytecode.zig");
const Opcode = bytecode.Opcode;
const Value = bytecode.Value;
const ValueTag = bytecode.ValueTag;
const simd_ternary = @import("simd_ternary.zig");
const simd_opt = @import("simd_ternary_optimized.zig");
const sacred_math = @import("sacred_math.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const VERSION = "1.0.0";

// VM Configuration
pub const STACK_SIZE: usize = 65536;

// Ternary wrap-around lookup table for fast TRYTE_ADD
// Maps sum (-26..+26) to wrapped value (-13..+13)
const TRYTE_WRAP_TABLE: [53]i8 = blk: {
    var table: [53]i8 = undefined;
    for (0..53) |i| {
        const sum: i32 = @as(i32, @intCast(i)) - 26;
        var wrapped = sum;
        while (wrapped > 13) wrapped -= 27;
        while (wrapped < -13) wrapped += 27;
        table[i] = @intCast(wrapped);
    }
    break :blk table;
};

/// Ultra-fast tryte wrap using golden lookup table
/// Uses sacred identity: φ² + 1/φ² = 3, so 27 = 3³ = (φ² + 1/φ²)³
inline fn wrapTryte(sum: i16) i8 {
    return sacred_math.goldenWrap(sum);
}
pub const CALL_STACK_SIZE: usize = 1024;
pub const MAX_LOCALS: usize = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// CALL FRAME
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_ARGS: usize = 8;

/// Lightweight CallFrame - only 32 bytes instead of 4KB!
/// Arguments are passed on the stack, not copied into frame
pub const CallFrame = struct {
    return_addr: u32,    // 4 bytes - where to return
    base_pointer: u32,   // 4 bytes - stack base for this call
    arg_start: u32,      // 4 bytes - where args start on stack
    arg_count: u8,       // 1 byte - number of arguments
    _padding: [3]u8 = .{0, 0, 0}, // alignment

    pub fn init(return_addr: u32, base_pointer: u32) CallFrame {
        return CallFrame{
            .return_addr = return_addr,
            .base_pointer = base_pointer,
            .arg_start = base_pointer,
            .arg_count = 0,
        };
    }

    pub fn initWithArgs(return_addr: u32, base_pointer: u32, arg_start: u32, arg_count: u8) CallFrame {
        return CallFrame{
            .return_addr = return_addr,
            .base_pointer = base_pointer,
            .arg_start = arg_start,
            .arg_count = arg_count,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const VMState = enum {
    ready,
    running,
    halted,
    error_state,
    paused,
};

pub const VMError = error{
    StackOverflow,
    StackUnderflow,
    InvalidOpcode,
    DivisionByZero,
    TypeMismatch,
    InvalidAddress,
    CallStackOverflow,
    OutOfMemory,
    InvalidConstant,
    IndexOutOfBounds,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVE FUNCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const NativeFn = *const fn (*VM, []const Value) VMError!Value;

pub const NativeFunction = struct {
    name: []const u8,
    arity: u8,
    func: NativeFn,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM - VIRTUAL MACHINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const VM = struct {
    allocator: Allocator,

    // Code
    code: []const u8,
    constants: []const Value,
    ip: u32,

    // Stack (used for values AND locals)
    stack: [STACK_SIZE]Value,
    sp: u32,

    // Locals storage (separate from stack for simplicity)
    locals: [MAX_LOCALS]Value,

    // Call stack (lightweight frames)
    call_stack: []CallFrame,
    fp: u32,

    // Globals
    globals: std.StringHashMap(Value),

    // Native functions (HSH pattern)
    natives: std.StringHashMap(NativeFunction),

    // State
    state: VMState,
    last_error: ?[]const u8,

    // Metrics
    instructions_executed: u64,
    cycles: u64,
    // Timing (nanoseconds)
    start_time: i128,
    end_time: i128,
    execution_time_ns: u64,
    // Opcode profiling (256 possible opcodes)
    opcode_counts: [256]u64,
    opcode_times: [256]u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        const call_stack = try allocator.alloc(CallFrame, CALL_STACK_SIZE);
        call_stack[0] = CallFrame.init(0, 0);

        var vm = Self{
            .allocator = allocator,
            .code = &.{},
            .constants = &.{},
            .ip = 0,
            .stack = [_]Value{.{ .nil = {} }} ** STACK_SIZE,
            .sp = 0,
            .locals = [_]Value{.{ .nil = {} }} ** MAX_LOCALS,
            .call_stack = call_stack,
            .fp = 0,
            .globals = std.StringHashMap(Value).init(allocator),
            .natives = std.StringHashMap(NativeFunction).init(allocator),
            .state = .ready,
            .last_error = null,
            .instructions_executed = 0,
            .cycles = 0,
            .start_time = 0,
            .end_time = 0,
            .execution_time_ns = 0,
            .opcode_counts = [_]u64{0} ** 256,
            .opcode_times = [_]u64{0} ** 256,
        };

        // Register built-in natives
        try vm.registerBuiltins();

        return vm;
    }

    pub fn deinit(self: *Self) void {
        allocator.free(self.call_stack);
        self.globals.deinit(allocator);
        self.natives.deinit(allocator);
    }

    fn registerBuiltins(self: *Self) !void {
        try self.registerNative("print", 1, nativePrint);
        try self.registerNative("sqrt", 1, nativeSqrt);
        try self.registerNative("sin", 1, nativeSin);
        try self.registerNative("cos", 1, nativeCos);
        try self.registerNative("phi", 0, nativePhi);
        try self.registerNative("golden", 0, nativeGolden);
        // Standard library
        try self.registerNative("len", 1, nativeLen);
        try self.registerNative("type", 1, nativeType);
        try self.registerNative("str", 1, nativeStr);
        try self.registerNative("int", 1, nativeInt);
        try self.registerNative("float", 1, nativeFloat);
        try self.registerNative("abs", 1, nativeAbs);
        try self.registerNative("min", 2, nativeMin);
        try self.registerNative("max", 2, nativeMax);
        try self.registerNative("floor", 1, nativeFloor);
        try self.registerNative("ceil", 1, nativeCeil);
        // Array functions
        try self.registerNative("push", 2, nativePush);
        try self.registerNative("pop", 1, nativePop);
        try self.registerNative("first", 1, nativeFirst);
        try self.registerNative("last", 1, nativeLast);
        try self.registerNative("range", 2, nativeRange);
        // Object functions
        try self.registerNative("keys", 1, nativeKeys);
        try self.registerNative("values", 1, nativeValues);
        // Higher-order functions (simplified - work with int arrays)
        try self.registerNative("sum", 1, nativeSum);
        try self.registerNative("product", 1, nativeProduct);
        try self.registerNative("reverse", 1, nativeReverse);
        try self.registerNative("concat", 2, nativeConcat);
        // Higher-order with callbacks
        try self.registerNative("map", 2, nativeMap);
        try self.registerNative("filter", 2, nativeFilter);
        try self.registerNative("reduce", 3, nativeReduce);
        try self.registerNative("foreach", 2, nativeForeach);
        // Ternary/Tryte operations
        try self.registerNative("toTryte", 1, nativeToTryte);
        try self.registerNative("fromTryte", 1, nativeFromTryte);
        try self.registerNative("tritAdd", 2, nativeTritAdd);
        try self.registerNative("tritMul", 2, nativeTritMul);
        // Tryte functional primitives
        try self.registerNative("tryteSum", 1, nativeTryteSumSIMD);
        try self.registerNative("tryteMax", 1, nativeTryteMaxSIMD);
        try self.registerNative("tryteMin", 1, nativeTryteMinSIMD);
        // TryteArray native functions
        try self.registerNative("tryteArrayNew", 1, nativeTryteArrayNew);
        try self.registerNative("tryteArrayGet", 2, nativeTryteArrayGet);
        try self.registerNative("tryteArraySet", 3, nativeTryteArraySet);
        try self.registerNative("tryteArrayLen", 1, nativeTryteArrayLen);
        try self.registerNative("tryteArraySum", 1, nativeTryteArraySum);
        try self.registerNative("tryteArrayMax", 1, nativeTryteArrayMax);
        try self.registerNative("tryteArrayMin", 1, nativeTryteArrayMin);
        try self.registerNative("tryteArrayFill", 2, nativeTryteArrayFill);
        try self.registerNative("tryteRange", 2, nativeTryteRange);
        // Sacred Math functions
        try self.registerNative("phi", 0, nativePhi);
        try self.registerNative("lucas", 1, nativeLucas);
        try self.registerNative("fibonacci", 1, nativeFibonacci);
        try self.registerNative("phiHash", 2, nativePhiHash);
        try self.registerNative("goldenWrap", 1, nativeGoldenWrap);
        // Additional sacred functions
        try self.registerNative("sacredFormula", 5, nativeSacredFormula);
        try self.registerNative("goldenIdentity", 0, nativeGoldenIdentity);
        try self.registerNative("magic37", 1, nativeMagic37);
        try self.registerNative("alphaInv", 0, nativeAlphaInv);
        try self.registerNative("transcendental", 0, nativeTranscendental);
        try self.registerNative("tridevyatitsa", 1, nativeTridevyatitsa);
        try self.registerNative("phiSpiral", 1, nativePhiSpiral);
        try self.registerNative("chshCheck", 1, nativeChshCheck);
        // Timing functions
        try self.registerNative("clock", 0, nativeClock);
        try self.registerNative("elapsed", 2, nativeElapsed);
    }

    pub fn registerNative(self: *Self, name: []const u8, arity: u8, func: NativeFn) !void {
        try self.natives.put(name, .{
            .name = name,
            .arity = arity,
            .func = func,
        });
    }

    pub fn load(self: *Self, code: []const u8, constants: []const Value) void {
        self.code = code;
        self.constants = constants;
        self.ip = 0;
        self.sp = 0;
        self.fp = 0;
        self.state = .ready;
        self.instructions_executed = 0;
        self.cycles = 0;
        self.start_time = 0;
        self.end_time = 0;
        self.execution_time_ns = 0;
        // Reset locals
        for (&self.locals) |*local| {
            local.* = .{ .nil = {} };
        }
        // Reset stack
        for (&self.stack) |*slot| {
            slot.* = .{ .nil = {} };
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STACK OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    // Critical path functions - marked inline for performance
    inline fn push(self: *Self, value: Value) VMError!void {
        if (self.sp >= STACK_SIZE) return VMError.StackOverflow;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    inline fn pop(self: *Self) VMError!Value {
        if (self.sp == 0) return VMError.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    inline fn peek(self: *Self, distance: u32) VMError!Value {
        if (distance >= self.sp) return VMError.StackUnderflow;
        return self.stack[self.sp - 1 - distance];
    }

    // Ultra-fast versions without bounds checking (use only when safe)
    inline fn pushFast(self: *Self, value: Value) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    inline fn popFast(self: *Self) Value {
        self.sp -= 1;
        return self.stack[self.sp];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BYTECODE READING
    // ═══════════════════════════════════════════════════════════════════════════

    inline fn readByte(self: *Self) VMError!u8 {
        if (self.ip >= self.code.len) return VMError.InvalidAddress;
        const byte = self.code[self.ip];
        self.ip += 1;
        return byte;
    }

    inline fn readU16(self: *Self) VMError!u16 {
        const high = try self.readByte();
        const low = try self.readByte();
        return (@as(u16, high) << 8) | low;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNCTION CALL HELPER (for map/filter/reduce)
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub fn callFunction(self: *Self, func_addr: u16, args: []const Value) VMError!Value {
        // Save current state
        const saved_ip = self.ip;
        const saved_sp = self.sp;
        const saved_fp = self.fp;
        
        // Push arguments onto stack
        for (args) |arg| {
            try self.push(arg);
        }
        
        // Set up call frame
        if (self.fp >= CALL_STACK_SIZE - 1) return VMError.CallStackOverflow;
        self.fp += 1;
        self.call_stack[self.fp] = CallFrame.initWithArgs(
            saved_ip,
            saved_sp,
            saved_sp,
            @intCast(args.len)
        );
        
        // Jump to function
        self.ip = func_addr;
        
        // Execute until RET
        while (true) {
            const opcode_byte = try self.readByte();
            const opcode: Opcode = @enumFromInt(opcode_byte);
            
            if (opcode == .RET) {
                // Get return value
                const return_value = if (self.sp > saved_sp + args.len)
                    try self.pop()
                else
                    Value{ .nil = {} };
                
                // Restore state
                self.ip = saved_ip;
                self.sp = saved_sp;
                self.fp = saved_fp;
                
                return return_value;
            }
            
            if (opcode == .HALT) {
                self.ip = saved_ip;
                self.sp = saved_sp;
                self.fp = saved_fp;
                return Value{ .nil = {} };
            }
            
            try self.executeOpcode(opcode);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION LOOP - D&C PATTERN
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn run(self: *Self) VMError!Value {
        self.state = .running;
        self.start_time = std.time.nanoTimestamp();

        while (self.state == .running) {
            const opcode_byte = try self.readByte();
            const opcode: Opcode = @enumFromInt(opcode_byte);

            try self.executeOpcode(opcode);
            self.opcode_counts[opcode_byte] += 1;
            self.instructions_executed += 1;
            self.cycles += 1;
        }

        self.end_time = std.time.nanoTimestamp();
        self.execution_time_ns = @intCast(@max(0, self.end_time - self.start_time));

        if (self.sp > 0) {
            return self.stack[self.sp - 1];
        }
        return .{ .nil = {} };
    }

    /// Fast run without profiling - maximum performance
    pub fn runFast(self: *Self) VMError!Value {
        self.state = .running;
        self.start_time = std.time.nanoTimestamp();

        // Tight loop - no profiling, minimal overhead
        // Cache frequently accessed fields in local variables
        var ip = self.ip;
        var sp = self.sp;
        const code = self.code;
        const stack = &self.stack;
        
        while (ip < code.len) {
            const opcode_byte = code[ip];
            ip += 1;
            
            // ═══════════════════════════════════════════════════════════════
            // QUANTUM SPEED INLINE DISPATCH - NO FUNCTION CALLS
            // ═══════════════════════════════════════════════════════════════
            
            // Binary arithmetic - most common operations
            if (opcode_byte == 0x10) { // ADD
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                if (a == .int_val and b == .int_val) {
                    stack[sp - 1] = .{ .int_val = a.int_val + b.int_val };
                } else if (a == .float_val and b == .float_val) {
                    stack[sp - 1] = .{ .float_val = a.float_val + b.float_val };
                } else {
                    stack[sp - 1] = .{ .int_val = (a.toInt() orelse 0) + (b.toInt() orelse 0) };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x11) { // SUB
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                if (a == .int_val and b == .int_val) {
                    stack[sp - 1] = .{ .int_val = a.int_val - b.int_val };
                } else {
                    stack[sp - 1] = .{ .int_val = (a.toInt() orelse 0) - (b.toInt() orelse 0) };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x12) { // MUL
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                if (a == .int_val and b == .int_val) {
                    stack[sp - 1] = .{ .int_val = a.int_val * b.int_val };
                } else {
                    stack[sp - 1] = .{ .int_val = (a.toInt() orelse 0) * (b.toInt() orelse 0) };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            // Comparisons
            if (opcode_byte == 0x22) { // LT
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                if (a == .int_val and b == .int_val) {
                    stack[sp - 1] = .{ .bool_val = a.int_val < b.int_val };
                } else {
                    stack[sp - 1] = .{ .bool_val = (a.toInt() orelse 0) < (b.toInt() orelse 0) };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x20) { // EQ
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                if (a == .int_val and b == .int_val) {
                    stack[sp - 1] = .{ .bool_val = a.int_val == b.int_val };
                } else if (a == .bool_val and b == .bool_val) {
                    stack[sp - 1] = .{ .bool_val = a.bool_val == b.bool_val };
                } else {
                    stack[sp - 1] = .{ .bool_val = false };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            // Jumps - critical for loops
            if (opcode_byte == 0x40) { // JMP
                const offset = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip = offset;
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x41) { // JZ (jump if zero/false)
                const offset = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                const cond = stack[sp];
                if (!cond.toBool()) {
                    ip = offset;
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x42) { // JNZ (jump if not zero/true)
                const offset = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                const cond = stack[sp];
                if (cond.toBool()) {
                    ip = offset;
                }
                self.instructions_executed += 1;
                continue;
            }
            
            // Local variable access - very common
            if (opcode_byte == 0x05) { // LOAD_LOCAL
                const idx = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                stack[sp] = self.locals[@min(idx, MAX_LOCALS - 1)];
                sp += 1;
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0x06) { // STORE_LOCAL
                const idx = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                self.locals[@min(idx, MAX_LOCALS - 1)] = stack[sp];
                self.instructions_executed += 1;
                continue;
            }
            
            // POP
            if (opcode_byte == 0x02) { // POP
                sp -= 1;
                self.instructions_executed += 1;
                continue;
            }
            
            // Fast path for common ternary operations (inline dispatch)
            if (opcode_byte == 0x79) { // TRYTE_ADD
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                sp -= 1;
                stack[sp - 1] = .{ .tryte_val = wrapTryte(ta + tb) };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0x7A) { // TRYTE_SUB
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                sp -= 1;
                stack[sp - 1] = .{ .tryte_val = wrapTryte(ta - tb) };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0x7B) { // TRYTE_MUL
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                var prod: i16 = ta * tb;
                while (prod > 13) prod -= 27;
                while (prod < -13) prod += 27;
                sp -= 1;
                stack[sp - 1] = .{ .tryte_val = @intCast(prod) };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0xA7) { // TRYTE_LT
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                sp -= 1;
                stack[sp - 1] = .{ .bool_val = ta < tb };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0xA8) { // TRYTE_EQ
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                sp -= 1;
                stack[sp - 1] = .{ .bool_val = ta == tb };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0x7F) { // TRYTE_INC
                const a = stack[sp - 1];
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                stack[sp - 1] = .{ .tryte_val = wrapTryte(ta + 1) };
                self.instructions_executed += 1;
                continue;
            }
            if (opcode_byte == 0xA9) { // TRYTE_DEC
                const a = stack[sp - 1];
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                stack[sp - 1] = .{ .tryte_val = wrapTryte(ta - 1) };
                self.instructions_executed += 1;
                continue;
            }
            
            // ═══════════════════════════════════════════════════════════════
            // INLINE SIMD FAST PATHS FOR TRYTE_ARRAY OPERATIONS
            // ═══════════════════════════════════════════════════════════════
            
            if (opcode_byte == 0xC4) { // TRYTE_ARRAY_SUM - inline SIMD
                const arr_val = stack[sp - 1];
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    const result = simd_ternary.batchTryteSum(arr.data[0..arr.len]);
                    stack[sp - 1] = .{ .tryte_val = result };
                } else {
                    stack[sp - 1] = .{ .tryte_val = 0 };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0xC5) { // TRYTE_ARRAY_MAX - inline SIMD
                const arr_val = stack[sp - 1];
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    const result = simd_ternary.batchTryteMax(arr.data[0..arr.len]);
                    stack[sp - 1] = .{ .tryte_val = result };
                } else {
                    stack[sp - 1] = .{ .tryte_val = -13 };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0xC6) { // TRYTE_ARRAY_MIN - inline SIMD
                const arr_val = stack[sp - 1];
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    const result = simd_ternary.batchTryteMin(arr.data[0..arr.len]);
                    stack[sp - 1] = .{ .tryte_val = result };
                } else {
                    stack[sp - 1] = .{ .tryte_val = 13 };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0xC1) { // TRYTE_ARRAY_GET - inline
                const idx_val = stack[sp - 1];
                const arr_val = stack[sp - 2];
                const idx: usize = @intCast(idx_val.toInt() orelse 0);
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    if (idx < arr.len) {
                        sp -= 1;
                        stack[sp - 1] = .{ .tryte_val = arr.data[idx] };
                    } else {
                        sp -= 1;
                        stack[sp - 1] = .{ .tryte_val = 0 };
                    }
                } else {
                    sp -= 1;
                    stack[sp - 1] = .{ .tryte_val = 0 };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0xC2) { // TRYTE_ARRAY_SET - inline
                const val = stack[sp - 1];
                const idx_val = stack[sp - 2];
                const arr_val = stack[sp - 3];
                const idx: usize = @intCast(idx_val.toInt() orelse 0);
                const tryte = val.toTryte() orelse 0;
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    if (idx < arr.len) {
                        arr.data[idx] = tryte;
                    }
                    sp -= 2;
                } else {
                    sp -= 2;
                }
                self.instructions_executed += 1;
                continue;
            }
            
            if (opcode_byte == 0xC3) { // TRYTE_ARRAY_LEN - inline
                const arr_val = stack[sp - 1];
                if (arr_val == .tryte_array_val) {
                    const arr = arr_val.tryte_array_val;
                    stack[sp - 1] = .{ .int_val = @intCast(arr.len) };
                } else {
                    stack[sp - 1] = .{ .int_val = 0 };
                }
                self.instructions_executed += 1;
                continue;
            }
            
            // Sync back to self before calling executeOpcode
            self.ip = ip;
            self.sp = sp;
            
            const opcode: Opcode = @enumFromInt(opcode_byte);
            try self.executeOpcode(opcode);
            self.instructions_executed += 1;
            
            // Sync from self after executeOpcode
            ip = self.ip;
            sp = self.sp;
            
            if (self.state != .running) break;
        }

        // Final sync
        self.ip = ip;
        self.sp = sp;
        
        self.end_time = std.time.nanoTimestamp();
        self.execution_time_ns = @intCast(@max(0, self.end_time - self.start_time));

        if (sp > 0) {
            return stack[sp - 1];
        }
        return .{ .nil = {} };
    }

    /// Get execution time in various units
    pub fn getExecutionTimeNs(self: *Self) u64 {
        return self.execution_time_ns;
    }

    pub fn getExecutionTimeUs(self: *Self) f64 {
        return @as(f64, @floatFromInt(self.execution_time_ns)) / 1000.0;
    }

    pub fn getExecutionTimeMs(self: *Self) f64 {
        return @as(f64, @floatFromInt(self.execution_time_ns)) / 1_000_000.0;
    }

    pub fn getOpsPerSecond(self: *Self) f64 {
        if (self.execution_time_ns == 0) return 0;
        const seconds = @as(f64, @floatFromInt(self.execution_time_ns)) / 1_000_000_000.0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / seconds;
    }

    /// Print opcode profile - top N slowest opcodes
    pub fn printProfile(self: *Self, top_n: usize) void {
        // Find opcodes with non-zero counts
        var entries: [256]struct { opcode: u8, count: u64, time: u64, avg: f64 } = undefined;
        var count: usize = 0;
        
        for (0..256) |i| {
            if (self.opcode_counts[i] > 0) {
                const avg = if (self.opcode_counts[i] > 0)
                    @as(f64, @floatFromInt(self.opcode_times[i])) / @as(f64, @floatFromInt(self.opcode_counts[i]))
                else 0;
                entries[count] = .{
                    .opcode = @intCast(i),
                    .count = self.opcode_counts[i],
                    .time = self.opcode_times[i],
                    .avg = avg,
                };
                count += 1;
            }
        }
        
        // Sort by total time (descending)
        const slice = entries[0..count];
        std.mem.sort(@TypeOf(entries[0]), slice, {}, struct {
            fn lessThan(_: void, a: @TypeOf(entries[0]), b: @TypeOf(entries[0])) bool {
                return a.time > b.time;
            }
        }.lessThan);
        
        // Print top N
        std.debug.print("\n=== OPCODE PROFILE (top {d}) ===\n", .{@min(top_n, count)});
        std.debug.print("{s:<20} {s:>10} {s:>12} {s:>10}\n", .{"Opcode", "Count", "Total (ns)", "Avg (ns)"});
        std.debug.print("{s}\n", .{"-" ** 55});
        
        for (slice[0..@min(top_n, count)]) |e| {
            const op: Opcode = @enumFromInt(e.opcode);
            std.debug.print("{s:<20} {d:>10} {d:>12} {d:>10.1}\n", .{
                @tagName(op), e.count, e.time, e.avg
            });
        }
        std.debug.print("{s}\n", .{"-" ** 55});
    }

    fn executeOpcode(self: *Self, opcode: Opcode) VMError!void {
        switch (opcode) {
            // Stack Operations
            .NOP => {},

            .PUSH_CONST => {
                // Optimized: trust compiler to generate valid indices
                const idx = try self.readU16();
                try self.push(self.constants[@min(idx, @as(u16, @intCast(self.constants.len -| 1)))]);
            },

            .POP => {
                _ = try self.pop();
            },

            .DUP => {
                const value = try self.peek(0);
                try self.push(value);
            },

            .SWAP => {
                const a = try self.pop();
                const b = try self.pop();
                try self.push(a);
                try self.push(b);
            },

            .LOAD_LOCAL => {
                // Optimized: assume idx < MAX_LOCALS (compiler guarantees this)
                const idx = try self.readU16();
                try self.push(self.locals[@min(idx, MAX_LOCALS - 1)]);
            },

            .STORE_LOCAL => {
                // Optimized: assume idx < MAX_LOCALS
                const idx = try self.readU16();
                const value = try self.pop();
                self.locals[@min(idx, MAX_LOCALS - 1)] = value;
            },

            .LOAD_GLOBAL => {
                const idx = try self.readU16();
                // For now, treat as local
                if (idx < MAX_LOCALS) {
                    try self.push(self.locals[idx]);
                } else {
                    try self.push(.{ .nil = {} });
                }
            },

            .STORE_GLOBAL => {
                const idx = try self.readU16();
                const value = try self.pop();
                if (idx < MAX_LOCALS) {
                    self.locals[idx] = value;
                }
            },

            // Arithmetic
            .ADD => try self.binaryOp(.add),
            .SUB => try self.binaryOp(.sub),
            .MUL => try self.binaryOp(.mul),
            .DIV => try self.binaryOp(.div),
            .MOD => try self.binaryOp(.mod),

            .NEG => {
                const value = try self.pop();
                switch (value) {
                    .int_val => |v| try self.push(.{ .int_val = -v }),
                    .float_val => |v| try self.push(.{ .float_val = -v }),
                    else => return VMError.TypeMismatch,
                }
            },

            .INC => {
                const value = try self.pop();
                switch (value) {
                    .int_val => |v| try self.push(.{ .int_val = v + 1 }),
                    .float_val => |v| try self.push(.{ .float_val = v + 1.0 }),
                    else => return VMError.TypeMismatch,
                }
            },

            .DEC => {
                const value = try self.pop();
                switch (value) {
                    .int_val => |v| try self.push(.{ .int_val = v - 1 }),
                    .float_val => |v| try self.push(.{ .float_val = v - 1.0 }),
                    else => return VMError.TypeMismatch,
                }
            },

            // Comparison
            .EQ => try self.comparisonOp(.eq),
            .NE => try self.comparisonOp(.ne),
            .LT => try self.comparisonOp(.lt),
            .LE => try self.comparisonOp(.le),
            .GT => try self.comparisonOp(.gt),
            .GE => try self.comparisonOp(.ge),

            // Fused compare+jump (optimization)
            .LT_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .lt)) {
                    self.ip = addr;
                }
            },
            .LE_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .le)) {
                    self.ip = addr;
                }
            },
            .GT_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .gt)) {
                    self.ip = addr;
                }
            },
            .GE_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .ge)) {
                    self.ip = addr;
                }
            },
            .EQ_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .eq)) {
                    self.ip = addr;
                }
            },
            .NE_JZ => {
                const addr = try self.readU16();
                const b = try self.pop();
                const a = try self.pop();
                if (!self.compareValues(a, b, .ne)) {
                    self.ip = addr;
                }
            },

            // Logic
            .NOT => {
                const value = try self.pop();
                // If trit, use ternary NOT: T→F, F→T, U→U
                if (value == .trit_val) {
                    try self.push(.{ .trit_val = -value.trit_val });
                } else {
                    const result = switch (value) {
                        .bool_val => |v| !v,
                        .int_val => |v| v == 0,
                        .nil => true,
                        else => false,
                    };
                    try self.push(.{ .bool_val = result });
                }
            },

            .AND => {
                const b = try self.pop();
                const a = try self.pop();
                // If either operand is trit, use Kleene AND (min)
                if (a == .trit_val or b == .trit_val) {
                    const ta = a.toTrit() orelse (if (self.isTruthy(a)) @as(i8, 1) else @as(i8, -1));
                    const tb = b.toTrit() orelse (if (self.isTruthy(b)) @as(i8, 1) else @as(i8, -1));
                    try self.push(.{ .trit_val = @min(ta, tb) });
                } else {
                    const result = self.isTruthy(a) and self.isTruthy(b);
                    try self.push(.{ .bool_val = result });
                }
            },

            .OR => {
                const b = try self.pop();
                const a = try self.pop();
                // If either operand is trit, use Kleene OR (max)
                if (a == .trit_val or b == .trit_val) {
                    const ta = a.toTrit() orelse (if (self.isTruthy(a)) @as(i8, 1) else @as(i8, -1));
                    const tb = b.toTrit() orelse (if (self.isTruthy(b)) @as(i8, 1) else @as(i8, -1));
                    try self.push(.{ .trit_val = @max(ta, tb) });
                } else {
                    const result = self.isTruthy(a) or self.isTruthy(b);
                    try self.push(.{ .bool_val = result });
                }
            },

            // Bitwise
            .SHL => {
                const b = try self.pop();
                const a = try self.pop();
                if (a == .int_val and b == .int_val) {
                    const shift: u6 = @intCast(@min(63, @max(0, b.int_val)));
                    try self.push(.{ .int_val = a.int_val << shift });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            .SHR => {
                const b = try self.pop();
                const a = try self.pop();
                if (a == .int_val and b == .int_val) {
                    const shift: u6 = @intCast(@min(63, @max(0, b.int_val)));
                    try self.push(.{ .int_val = a.int_val >> shift });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            .BAND => {
                const b = try self.pop();
                const a = try self.pop();
                if (a == .int_val and b == .int_val) {
                    try self.push(.{ .int_val = a.int_val & b.int_val });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            .BOR => {
                const b = try self.pop();
                const a = try self.pop();
                if (a == .int_val and b == .int_val) {
                    try self.push(.{ .int_val = a.int_val | b.int_val });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            .BXOR => {
                const b = try self.pop();
                const a = try self.pop();
                if (a == .int_val and b == .int_val) {
                    try self.push(.{ .int_val = a.int_val ^ b.int_val });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            .BNOT => {
                const value = try self.pop();
                if (value == .int_val) {
                    try self.push(.{ .int_val = ~value.int_val });
                } else {
                    return VMError.TypeMismatch;
                }
            },

            // Control Flow
            .JMP => {
                const addr = try self.readU16();
                self.ip = addr;
            },

            .JZ => {
                const addr = try self.readU16();
                const value = try self.pop();
                if (!self.isTruthy(value)) {
                    self.ip = addr;
                }
            },

            .JNZ => {
                const addr = try self.readU16();
                const value = try self.pop();
                if (self.isTruthy(value)) {
                    self.ip = addr;
                }
            },

            .CALL => {
                const addr = try self.readU16();
                if (self.fp >= CALL_STACK_SIZE - 1) return VMError.CallStackOverflow;
                self.fp += 1;
                self.call_stack[self.fp] = CallFrame.init(self.ip, self.sp);
                self.ip = addr;
            },

            .CALL_INDIRECT => {
                // Lightweight call - args stay on stack!
                const arity = try self.readByte();
                
                // Args are already on stack: [func_addr, arg0, arg1, ...]
                // We need to find where args start
                // Stack layout: ... func_addr arg0 arg1 ... argN <- sp
                
                // Pop function address (it's BEFORE the args on stack)
                // Actually the order is: push func, push args, call
                // So stack is: ... func arg0 arg1 ... argN
                // We need to get func from sp - arity - 1
                
                const arg_start = self.sp - arity;
                const func_idx = arg_start - 1;
                
                if (func_idx >= STACK_SIZE) return VMError.StackUnderflow;
                
                const func_val = self.stack[func_idx];
                
                if (func_val != .func_val and func_val != .int_val) {
                    return VMError.TypeMismatch;
                }
                
                const addr: u16 = if (func_val == .func_val) 
                    func_val.func_val.addr 
                else 
                    @intCast(@max(0, func_val.int_val));
                
                if (self.fp >= CALL_STACK_SIZE - 1) return VMError.CallStackOverflow;
                
                // Create lightweight frame - no copying!
                self.fp += 1;
                self.call_stack[self.fp] = CallFrame.initWithArgs(
                    self.ip,
                    func_idx,  // base_pointer points to func slot
                    arg_start,
                    arity
                );
                self.ip = addr;
            },

            .LOAD_ARG => {
                // Load argument from stack (not from frame!)
                const idx = try self.readByte();
                const frame = &self.call_stack[self.fp];
                const arg_pos = frame.arg_start + idx;
                if (idx < frame.arg_count and arg_pos < STACK_SIZE) {
                    try self.push(self.stack[arg_pos]);
                } else {
                    try self.push(.{ .nil = {} });
                }
            },

            .STORE_ARG => {
                // Store to argument slot on stack
                const idx = try self.readByte();
                const value = try self.pop();
                const frame = &self.call_stack[self.fp];
                const arg_pos = frame.arg_start + idx;
                if (idx < frame.arg_count and arg_pos < STACK_SIZE) {
                    self.stack[arg_pos] = value;
                }
            },

            .ENTER => {
                // No-op for lightweight frames
                _ = try self.readByte();
            },

            .LEAVE => {
                // No-op for lightweight frames
            },
            
            .CALL_NATIVE => {
                // Call native function by name index
                const name_idx = try self.readU16();
                const arity = try self.readByte();
                
                // Get function name from constants
                const name_val = self.constants[name_idx];
                if (name_val != .string_val) return VMError.TypeMismatch;
                const name = name_val.string_val;
                
                // Look up native function
                if (self.natives.get(name)) |native| {
                    // Collect arguments from stack
                    var args: [16]Value = undefined;
                    var i: usize = 0;
                    while (i < arity) : (i += 1) {
                        args[arity - 1 - i] = try self.pop();
                    }
                    
                    // Call native function
                    const result = try native.func(self, args[0..arity]);
                    try self.push(result);
                } else {
                    return VMError.InvalidAddress;
                }
            },
            
            .CLOSURE => {
                // Create closure with captured upvalues
                const func_addr = try self.readU16();
                const upvalue_count = try self.readByte();
                
                // Allocate closure
                const closure = allocator.create(bytecode.ClosureValue) catch return VMError.OutOfMemory;
                closure.func_addr = func_addr;
                closure.upvalue_count = upvalue_count;
                
                if (upvalue_count > 0) {
                    closure.upvalues = allocator.alloc(?*bytecode.UpvalueObj, upvalue_count) catch return VMError.OutOfMemory;
                    
                    // Read upvalue descriptors and capture
                    var i: u8 = 0;
                    while (i < upvalue_count) : (i += 1) {
                        const is_local = try self.readByte();
                        const index = try self.readByte();
                        
                        const upvalue = allocator.create(bytecode.UpvalueObj) catch return VMError.OutOfMemory;
                        if (is_local == 1) {
                            // Capture local variable
                            upvalue.location = &self.locals[index];
                            upvalue.is_open = true;
                        } else {
                            // Capture from enclosing closure's upvalues
                            upvalue.location = &self.locals[0]; // simplified
                            upvalue.is_open = true;
                        }
                        upvalue.closed = .{ .nil = {} };
                        closure.upvalues[i] = upvalue;
                    }
                } else {
                    closure.upvalues = &.{};
                }
                
                try self.push(.{ .closure_val = closure });
            },
            
            .GET_UPVALUE => {
                const idx = try self.readByte();
                // For now, simplified - just return nil
                // Real implementation would look up in current closure's upvalues
                _ = idx;
                try self.push(.{ .nil = {} });
            },
            
            .SET_UPVALUE => {
                const idx = try self.readByte();
                const value = try self.pop();
                // For now, simplified - just discard
                _ = idx;
                _ = value;
            },

            .RET => {
                // Get return value from top of stack
                const return_value = if (self.sp > self.call_stack[self.fp].base_pointer + self.call_stack[self.fp].arg_count + 1)
                    try self.pop()
                else
                    Value{ .nil = {} };

                // Restore state
                self.ip = self.call_stack[self.fp].return_addr;
                self.sp = self.call_stack[self.fp].base_pointer; // Pop func + args

                if (self.fp > 0) {
                    self.fp -= 1;
                }

                // Push return value
                try self.push(return_value);
            },

            .HALT => {
                self.state = .halted;
            },

            .LOOP => {
                const offset = try self.readU16();
                self.ip -= offset;
            },

            // ═══════════════════════════════════════════════════════════════
            // TERNARY/TRIT OPERATIONS - ТРОИЧНАЯ ЛОГИКА!
            // ═══════════════════════════════════════════════════════════════
            
            .PUSH_TRIT => {
                // Read trit value as signed byte: 1=T, 0=U, -1=F
                const trit_byte = try self.readByte();
                const trit: i8 = @bitCast(trit_byte);
                try self.push(.{ .trit_val = trit });
            },
            
            .TRIT_NOT => {
                // Ternary NOT: T→F, F→T, U→U
                const a = try self.pop();
                const t = a.toTrit() orelse 0;
                try self.push(.{ .trit_val = -t });
            },
            
            .TRIT_AND => {
                // Kleene AND: min(a, b)
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTrit() orelse 0;
                const tb = b.toTrit() orelse 0;
                try self.push(.{ .trit_val = @min(ta, tb) });
            },
            
            .TRIT_OR => {
                // Kleene OR: max(a, b)
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTrit() orelse 0;
                const tb = b.toTrit() orelse 0;
                try self.push(.{ .trit_val = @max(ta, tb) });
            },
            
            .TRIT_XOR => {
                // Ternary XOR
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTrit() orelse 0;
                const tb = b.toTrit() orelse 0;
                // XOR: if either is U, result is U; else T if different, F if same
                const result: i8 = if (ta == 0 or tb == 0) 0 else if (ta != tb) 1 else -1;
                try self.push(.{ .trit_val = result });
            },
            
            .TRIT_IMP => {
                // Ternary implication: a → b = max(-a, b)
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTrit() orelse 0;
                const tb = b.toTrit() orelse 0;
                try self.push(.{ .trit_val = @max(-ta, tb) });
            },
            
            .TRIT_EQ => {
                // Ternary equality: T if equal, F if opposite, U otherwise
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTrit() orelse 0;
                const tb = b.toTrit() orelse 0;
                const result: i8 = if (ta == tb) 1 else if (ta == -tb and ta != 0) -1 else 0;
                try self.push(.{ .trit_val = result });
            },
            
            .TRIT_CMP => {
                // Compare and return trit: a<b→F, a=b→U, a>b→T
                const b = try self.pop();
                const a = try self.pop();
                const ia = a.toInt() orelse 0;
                const ib = b.toInt() orelse 0;
                const result: i8 = if (ia < ib) -1 else if (ia > ib) 1 else 0;
                try self.push(.{ .trit_val = result });
            },
            
            // ═══════════════════════════════════════════════════════════════
            // TRYTE OPERATIONS - BALANCED TERNARY (3 trits = 27 values)
            // ═══════════════════════════════════════════════════════════════
            
            .PUSH_TRYTE => {
                // Read tryte value as signed i16 (big-endian): -13..+13
                const hi = try self.readByte();
                const lo = try self.readByte();
                const u_val: u16 = (@as(u16, hi) << 8) | @as(u16, lo);
                const tryte: i16 = @bitCast(u_val);
                // Clamp to valid tryte range
                const clamped: i8 = @intCast(std.math.clamp(tryte, -13, 13));
                try self.push(.{ .tryte_val = clamped });
            },
            
            .TRYTE_ADD => {
                // Ultra-fast balanced ternary addition using lookup table
                const b = try self.pop();
                const a = try self.pop();
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                try self.push(.{ .tryte_val = wrapTryte(ta + tb) });
            },
            
            .TRYTE_SUB => {
                // Ultra-fast balanced ternary subtraction using lookup table
                const b = try self.pop();
                const a = try self.pop();
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                try self.push(.{ .tryte_val = wrapTryte(ta - tb) });
            },
            
            .TRYTE_MUL => {
                // Optimized balanced ternary multiplication
                const b = try self.pop();
                const a = try self.pop();
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                const tb: i16 = @as(i16, b.toTryte() orelse 0);
                const prod = ta * tb;
                const wrapped: i8 = @intCast(@mod(prod + 13, 27) - 13);
                try self.push(.{ .tryte_val = wrapped });
            },
            
            .TRYTE_NEG => {
                // Balanced ternary negation
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                try self.push(.{ .tryte_val = -ta });
            },

            .TRYTE_INC => {
                // Fast increment tryte by 1
                const a = try self.pop();
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                try self.push(.{ .tryte_val = wrapTryte(ta + 1) });
            },

            .TRYTE_DEC => {
                // Fast decrement tryte by 1
                const a = try self.pop();
                const ta: i16 = @as(i16, a.toTryte() orelse 0);
                try self.push(.{ .tryte_val = wrapTryte(ta - 1) });
            },

            .TRYTE_LT => {
                // Tryte less than comparison - returns bool
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta < tb });
            },

            .TRYTE_EQ => {
                // Tryte equality comparison - returns bool
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta == tb });
            },

            .TRYTE_GT => {
                // Tryte greater than comparison
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta > tb });
            },

            .TRYTE_LE => {
                // Tryte less than or equal comparison
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta <= tb });
            },

            .TRYTE_GE => {
                // Tryte greater than or equal comparison
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta >= tb });
            },

            .TRYTE_NE => {
                // Tryte not equal comparison
                const b = try self.pop();
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                const tb = b.toTryte() orelse 0;
                try self.push(.{ .bool_val = ta != tb });
            },
            
            .TO_TRYTE => {
                // Fast convert int to tryte using lookup for small values
                const a = try self.pop();
                const ia = a.toInt() orelse 0;
                // For values in -13..+13, no conversion needed
                if (ia >= -13 and ia <= 13) {
                    try self.push(.{ .tryte_val = @intCast(ia) });
                } else {
                    const t: i16 = @intCast(@mod(ia + 13, 27) - 13);
                    try self.push(.{ .tryte_val = @intCast(t) });
                }
            },
            
            .FROM_TRYTE => {
                // Fast convert tryte to int (just cast)
                const a = try self.pop();
                const ta = a.toTryte() orelse 0;
                try self.push(.{ .int_val = @as(i64, ta) });
            },

            // TryteArray Operations - Native packed arrays for SIMD
            .TRYTE_ARRAY_NEW => {
                // Create new TryteArray with given size
                const size_val = try self.pop();
                const size: usize = @intCast(size_val.toInt() orelse 0);
                const arr = allocator.create(bytecode.TryteArrayValue) catch return VMError.OutOfMemory;
                arr.data = allocator.alloc(i8, size) catch return VMError.OutOfMemory;
                arr.len = size;
                arr.capacity = size;
                // Initialize to zero
                @memset(arr.data, 0);
                try self.push(.{ .tryte_array_val = arr });
            },

            .TRYTE_ARRAY_GET => {
                // Get element from TryteArray: arr[idx] -> tryte
                const idx_val = try self.pop();
                const arr_val = try self.pop();
                const idx: usize = @intCast(idx_val.toInt() orelse 0);
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                if (idx >= arr.len) return VMError.IndexOutOfBounds;
                try self.push(.{ .tryte_val = arr.data[idx] });
            },

            .TRYTE_ARRAY_SET => {
                // Set element in TryteArray: arr[idx] = tryte
                const val = try self.pop();
                const idx_val = try self.pop();
                const arr_val = try self.pop();
                const idx: usize = @intCast(idx_val.toInt() orelse 0);
                const tryte = val.toTryte() orelse 0;
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                if (idx >= arr.len) return VMError.IndexOutOfBounds;
                arr.data[idx] = tryte;
                try self.push(arr_val); // Return array for chaining
            },

            .TRYTE_ARRAY_LEN => {
                // Get length of TryteArray
                const arr_val = try self.pop();
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                try self.push(.{ .int_val = @intCast(arr.len) });
            },

            .TRYTE_ARRAY_SUM => {
                // SIMD sum of TryteArray (direct access, no extraction)
                const arr_val = try self.pop();
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                const result = simd_ternary.batchTryteSum(arr.data[0..arr.len]);
                try self.push(.{ .tryte_val = result });
            },

            .TRYTE_ARRAY_MAX => {
                // SIMD max of TryteArray (direct access)
                const arr_val = try self.pop();
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                const result = simd_ternary.batchTryteMax(arr.data[0..arr.len]);
                try self.push(.{ .tryte_val = result });
            },

            .TRYTE_ARRAY_MIN => {
                // SIMD min of TryteArray (direct access)
                const arr_val = try self.pop();
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                const result = simd_ternary.batchTryteMin(arr.data[0..arr.len]);
                try self.push(.{ .tryte_val = result });
            },

            .TRYTE_ARRAY_FILL => {
                // Fill TryteArray with value
                const val = try self.pop();
                const arr_val = try self.pop();
                const tryte = val.toTryte() orelse 0;
                if (arr_val != .tryte_array_val) return VMError.TypeMismatch;
                const arr = arr_val.tryte_array_val;
                @memset(arr.data, tryte);
                try self.push(arr_val);
            },

            .TRYTE_ARRAY_COPY => {
                // Copy TryteArray
                const src_val = try self.pop();
                if (src_val != .tryte_array_val) return VMError.TypeMismatch;
                const src = src_val.tryte_array_val;
                const dst = allocator.create(bytecode.TryteArrayValue) catch return VMError.OutOfMemory;
                dst.data = allocator.alloc(i8, src.len) catch return VMError.OutOfMemory;
                dst.len = src.len;
                dst.capacity = src.len;
                @memcpy(dst.data, src.data[0..src.len]);
                try self.push(.{ .tryte_array_val = dst });
            },

            // Sacred Constants
            .PUSH_PHI => try self.push(.{ .float_val = PHI }),
            .PUSH_PI => try self.push(.{ .float_val = PI }),
            .PUSH_E => try self.push(.{ .float_val = E }),

            .GOLDEN_IDENTITY_OP => {
                // Compute φ² + 1/φ² = 3
                const phi_sq = PHI * PHI;
                const inv_phi_sq = 1.0 / phi_sq;
                try self.push(.{ .float_val = phi_sq + inv_phi_sq });
            },

            .SACRED_FORMULA => {
                // V = n × 3^k × π^m × φ^p × e^q
                // Pop: q, p, m, k, n
                const q = (try self.pop()).toFloat() orelse 0;
                const p = (try self.pop()).toFloat() orelse 0;
                const m = (try self.pop()).toFloat() orelse 0;
                const k = (try self.pop()).toFloat() orelse 0;
                const n = (try self.pop()).toFloat() orelse 1;

                const result = n * std.math.pow(f64, 3.0, k) * std.math.pow(f64, PI, m) * std.math.pow(f64, PHI, p) * std.math.pow(f64, E, q);

                try self.push(.{ .float_val = result });
            },

            // Arrays
            .NEW_ARRAY => {
                const count = try self.readByte();
                // Allocate array
                const arr = allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
                const items = allocator.alloc(Value, count) catch return VMError.OutOfMemory;
                
                // Pop elements from stack (in reverse order)
                var i: usize = count;
                while (i > 0) {
                    i -= 1;
                    items[i] = try self.pop();
                }
                
                arr.* = .{ .items = items, .capacity = count };
                try self.push(.{ .array_val = arr });
            },

            .ARRAY_GET => {
                const idx_val = try self.pop();
                const arr_val = try self.pop();
                
                if (arr_val != .array_val) return VMError.TypeMismatch;
                const idx = idx_val.toInt() orelse return VMError.TypeMismatch;
                
                const arr = arr_val.array_val;
                if (idx < 0 or idx >= arr.items.len) {
                    try self.push(.{ .nil = {} });
                } else {
                    try self.push(arr.items[@intCast(idx)]);
                }
            },

            .ARRAY_SET => {
                const val = try self.pop();
                const idx_val = try self.pop();
                const arr_val = try self.pop();
                
                if (arr_val != .array_val) return VMError.TypeMismatch;
                const idx = idx_val.toInt() orelse return VMError.TypeMismatch;
                
                const arr = arr_val.array_val;
                if (idx >= 0 and idx < arr.items.len) {
                    arr.items[@intCast(idx)] = val;
                }
                try self.push(arr_val); // Return array for chaining
            },

            .ARRAY_LEN => {
                const arr_val = try self.pop();
                if (arr_val != .array_val) return VMError.TypeMismatch;
                try self.push(.{ .int_val = @intCast(arr_val.array_val.items.len) });
            },

            .ARRAY_PUSH => {
                const val = try self.pop();
                const arr_val = try self.pop();
                if (arr_val != .array_val) return VMError.TypeMismatch;
                
                // Simple implementation - reallocate
                const arr = arr_val.array_val;
                const new_items = allocator.alloc(Value, arr.items.len + 1) catch return VMError.OutOfMemory;
                @memcpy(new_items[0..arr.items.len], arr.items);
                new_items[arr.items.len] = val;
                allocator.free(arr.items);
                arr.items = new_items;
                
                try self.push(arr_val);
            },

            .ARRAY_POP => {
                const arr_val = try self.pop();
                if (arr_val != .array_val) return VMError.TypeMismatch;
                
                const arr = arr_val.array_val;
                if (arr.items.len == 0) {
                    try self.push(.{ .nil = {} });
                } else {
                    const val = arr.items[arr.items.len - 1];
                    arr.items = arr.items[0..arr.items.len - 1];
                    try self.push(val);
                }
            },

            // Objects
            .NEW_OBJECT => {
                const obj = allocator.create(bytecode.ObjectValue) catch return VMError.OutOfMemory;
                obj.* = .{ .keys = &.{}, .values = &.{}, .count = 0 };
                try self.push(.{ .object_val = obj });
            },

            .OBJECT_GET => {
                // Key is on stack as string
                const key_val = try self.pop();
                const obj_val = try self.pop();
                
                if (obj_val != .object_val) return VMError.TypeMismatch;
                if (key_val != .string_val) return VMError.TypeMismatch;
                
                const obj = obj_val.object_val;
                const key = key_val.string_val;
                
                // Linear search for key
                for (obj.keys[0..obj.count], 0..) |k, i| {
                    if (std.mem.eql(u8, k, key)) {
                        try self.push(obj.values[i]);
                        return;
                    }
                }
                try self.push(.{ .nil = {} });
            },

            .OBJECT_SET => {
                const val = try self.pop();
                const key_val = try self.pop();
                const obj_val = try self.pop();
                
                if (obj_val != .object_val) return VMError.TypeMismatch;
                if (key_val != .string_val) return VMError.TypeMismatch;
                
                const obj = obj_val.object_val;
                const key = key_val.string_val;
                
                // Check if key exists
                for (obj.keys[0..obj.count], 0..) |k, i| {
                    if (std.mem.eql(u8, k, key)) {
                        obj.values[i] = val;
                        try self.push(obj_val);
                        continue;
                    }
                }
                
                // Add new key-value pair
                const new_count = obj.count + 1;
                const new_keys = allocator.alloc([]const u8, new_count) catch return VMError.OutOfMemory;
                const new_values = allocator.alloc(Value, new_count) catch return VMError.OutOfMemory;
                
                // Copy existing
                for (0..obj.count) |i| {
                    new_keys[i] = obj.keys[i];
                    new_values[i] = obj.values[i];
                }
                
                // Add new
                new_keys[obj.count] = key;
                new_values[obj.count] = val;
                
                obj.keys = new_keys;
                obj.values = new_values;
                obj.count = new_count;
                
                try self.push(obj_val);
            },

            // Superinstructions
            .LOAD_ADD => {
                const idx = try self.readU16();
                const local = if (idx < MAX_LOCALS) self.locals[idx] else Value{ .nil = {} };
                const top = try self.pop();
                try self.binaryOpValues(local, top, .add);
            },

            .LOAD_SUB => {
                const idx = try self.readU16();
                const local = if (idx < MAX_LOCALS) self.locals[idx] else Value{ .nil = {} };
                const top = try self.pop();
                try self.binaryOpValues(local, top, .sub);
            },

            .LOAD_MUL => {
                const idx = try self.readU16();
                const local = if (idx < MAX_LOCALS) self.locals[idx] else Value{ .nil = {} };
                const top = try self.pop();
                try self.binaryOpValues(local, top, .mul);
            },

            .LOAD_TRYTE_ADD => {
                // Fused: load local tryte + add top of stack
                const idx = try self.readU16();
                const local = self.locals[@min(idx, MAX_LOCALS - 1)];
                const top = try self.pop();
                const ta: i16 = @as(i16, local.toTryte() orelse 0);
                const tb: i16 = @as(i16, top.toTryte() orelse 0);
                try self.push(.{ .tryte_val = wrapTryte(ta + tb) });
            },

            .TAIL_CALL => {
                // Tail call optimization: reuse current frame
                const addr = try self.readU16();
                // Don't push new frame, just jump
                self.ip = addr;
            },

            else => return VMError.InvalidOpcode,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    const BinaryOp = enum { add, sub, mul, div, mod };

    fn binaryOp(self: *Self, op: BinaryOp) VMError!void {
        const b = try self.pop();
        const a = try self.pop();
        try self.binaryOpValues(a, b, op);
    }

    fn binaryOpValues(self: *Self, a: Value, b: Value, op: BinaryOp) VMError!void {
        // Both integers
        if (a == .int_val and b == .int_val) {
            const result: i64 = switch (op) {
                .add => a.int_val + b.int_val,
                .sub => a.int_val - b.int_val,
                .mul => a.int_val * b.int_val,
                .div => if (b.int_val == 0) return VMError.DivisionByZero else @divTrunc(a.int_val, b.int_val),
                .mod => if (b.int_val == 0) return VMError.DivisionByZero else @mod(a.int_val, b.int_val),
            };
            try self.push(.{ .int_val = result });
            return;
        }

        // Convert to float
        const fa = a.toFloat() orelse return VMError.TypeMismatch;
        const fb = b.toFloat() orelse return VMError.TypeMismatch;

        const result: f64 = switch (op) {
            .add => fa + fb,
            .sub => fa - fb,
            .mul => fa * fb,
            .div => if (fb == 0) return VMError.DivisionByZero else fa / fb,
            .mod => @mod(fa, fb),
        };
        try self.push(.{ .float_val = result });
    }

    const ComparisonOp = enum { eq, ne, lt, le, gt, ge };

    fn comparisonOp(self: *Self, op: ComparisonOp) VMError!void {
        const b = try self.pop();
        const a = try self.pop();
        const result = self.compareValues(a, b, op);
        try self.push(.{ .bool_val = result });
    }

    fn compareValues(_: *Self, a: Value, b: Value, op: ComparisonOp) bool {
        // Both integers - fast path
        if (a == .int_val and b == .int_val) {
            return switch (op) {
                .eq => a.int_val == b.int_val,
                .ne => a.int_val != b.int_val,
                .lt => a.int_val < b.int_val,
                .le => a.int_val <= b.int_val,
                .gt => a.int_val > b.int_val,
                .ge => a.int_val >= b.int_val,
            };
        }

        // Convert to float
        const fa = a.toFloat() orelse return false;
        const fb = b.toFloat() orelse return false;

        return switch (op) {
            .eq => fa == fb,
            .ne => fa != fb,
            .lt => fa < fb,
            .le => fa <= fb,
            .gt => fa > fb,
            .ge => fa >= fb,
        };
    }

    fn isTruthy(self: *Self, value: Value) bool {
        _ = self;
        return switch (value) {
            .nil => false,
            .bool_val => |v| v,
            .int_val => |v| v != 0,
            .float_val => |v| v != 0.0,
            .string_val => |v| v.len > 0,
            .func_val => true,
            .array_val => |v| v.items.len > 0,
            .object_val => |v| v.count > 0,
            .closure_val => true,
            .tryte_array_val => |v| v.len > 0,
            .trit_val => |v| v > 0,   // T=true, F/U=false
            .tryte_val => |v| v > 0,  // Positive=true
        };
    }

    pub fn getMetrics(self: *const Self) VMMetrics {
        return .{
            .instructions_executed = self.instructions_executed,
            .cycles = self.cycles,
            .stack_depth = self.sp,
            .call_depth = self.fp,
        };
    }
};

pub const VMMetrics = struct {
    instructions_executed: u64,
    cycles: u64,
    stack_depth: u32,
    call_depth: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn nativePrint(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    for (args) |arg| {
        switch (arg) {
            .nil => std.debug.print("nil", .{}),
            .bool_val => |v| std.debug.print("{}", .{v}),
            .int_val => |v| std.debug.print("{}", .{v}),
            .float_val => |v| std.debug.print("{d}", .{v}),
            .string_val => |v| std.debug.print("{s}", .{v}),
            .func_val => |v| std.debug.print("<func@{d}>", .{v.addr}),
            .array_val => |v| std.debug.print("<array[{d}]>", .{v.items.len}),
            .object_val => |v| std.debug.print("<object({d})>", .{v.count}),
            .closure_val => |v| std.debug.print("<closure@{d}>", .{v.func_addr}),
            .tryte_array_val => |v| std.debug.print("<tryte_array[{d}]>", .{v.len}),
            .trit_val => |v| {
                // Троичные символы: △=T, ▽=F, ?=U
                const symbol: []const u8 = if (v > 0) "△" else if (v < 0) "▽" else "?";
                std.debug.print("{s}", .{symbol});
            },
            .tryte_val => |v| {
                // Tryte as balanced ternary with symbols
                std.debug.print("0t", .{});
                // Convert to 3 trits
                var val = v;
                var trits: [3]u8 = undefined;
                for (0..3) |i| {
                    const trit = @mod(val + 1, 3) - 1;
                    trits[2 - i] = if (trit > 0) '+' else if (trit < 0) '-' else '0';
                    val = @divTrunc(val - trit, 3);
                }
                std.debug.print("{s}({d})", .{&trits, @as(i8, @bitCast(arg.tryte_val))});
            },
        }
    }
    std.debug.print("\n", .{});
    return .{ .nil = {} };
}

fn nativeSqrt(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    const val = args[0].toFloat() orelse return VMError.TypeMismatch;
    return .{ .float_val = @sqrt(val) };
}

fn nativeSin(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    const val = args[0].toFloat() orelse return VMError.TypeMismatch;
    return .{ .float_val = @sin(val) };
}

fn nativeCos(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    const val = args[0].toFloat() orelse return VMError.TypeMismatch;
    return .{ .float_val = @cos(val) };
}

fn nativePhi(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    _ = args;
    return .{ .float_val = PHI };
}

fn nativeGolden(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    _ = args;
    return .{ .float_val = GOLDEN_IDENTITY };
}

fn nativeLen(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .int_val = 0 };
    return switch (args[0]) {
        .string_val => |s| .{ .int_val = @intCast(s.len) },
        .array_val => |a| .{ .int_val = @intCast(a.items.len) },
        .object_val => |o| .{ .int_val = @intCast(o.count) },
        else => .{ .int_val = 0 },
    };
}

fn nativeType(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .string_val = "nil" };
    return .{ .string_val = switch (args[0]) {
        .nil => "nil",
        .bool_val => "bool",
        .int_val => "int",
        .float_val => "float",
        .string_val => "string",
        .func_val => "function",
        .array_val => "array",
        .object_val => "object",
        .closure_val => "closure",
        .tryte_array_val => "tryte_array",
        .trit_val => "trit",
        .tryte_val => "tryte",
    }};
}

fn nativeStr(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .string_val = "nil" };
    return switch (args[0]) {
        .nil => .{ .string_val = "nil" },
        .bool_val => |v| .{ .string_val = if (v) "true" else "false" },
        .int_val => .{ .string_val = "<int>" },  // simplified
        .float_val => .{ .string_val = "<float>" },
        .string_val => |s| .{ .string_val = s },
        .func_val => .{ .string_val = "<function>" },
        .array_val => .{ .string_val = "<array>" },
        .object_val => .{ .string_val = "<object>" },
        .closure_val => .{ .string_val = "<closure>" },
        .tryte_array_val => .{ .string_val = "<tryte_array>" },
        .trit_val => |v| .{ .string_val = if (v > 0) "T" else if (v < 0) "F" else "U" },
        .tryte_val => .{ .string_val = "<tryte>" },
    };
}

fn nativeInt(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .int_val = 0 };
    return switch (args[0]) {
        .nil => .{ .int_val = 0 },
        .bool_val => |v| .{ .int_val = if (v) 1 else 0 },
        .int_val => |v| .{ .int_val = v },
        .float_val => |v| .{ .int_val = @intFromFloat(v) },
        .string_val => .{ .int_val = 0 },  // TODO: parse
        else => .{ .int_val = 0 },
    };
}

fn nativeFloat(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .float_val = 0.0 };
    return switch (args[0]) {
        .nil => .{ .float_val = 0.0 },
        .bool_val => |v| .{ .float_val = if (v) 1.0 else 0.0 },
        .int_val => |v| .{ .float_val = @floatFromInt(v) },
        .float_val => |v| .{ .float_val = v },
        .string_val => .{ .float_val = 0.0 },  // TODO: parse
        else => .{ .float_val = 0.0 },
    };
}

fn nativeAbs(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .int_val = 0 };
    return switch (args[0]) {
        .int_val => |v| .{ .int_val = if (v < 0) -v else v },
        .float_val => |v| .{ .float_val = @abs(v) },
        else => .{ .int_val = 0 },
    };
}

fn nativeMin(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 2) return .{ .nil = {} };
    const a = args[0].toInt() orelse return .{ .nil = {} };
    const b = args[1].toInt() orelse return .{ .nil = {} };
    return .{ .int_val = @min(a, b) };
}

fn nativeMax(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 2) return .{ .nil = {} };
    const a = args[0].toInt() orelse return .{ .nil = {} };
    const b = args[1].toInt() orelse return .{ .nil = {} };
    return .{ .int_val = @max(a, b) };
}

fn nativeFloor(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .float_val = 0.0 };
    const val = args[0].toFloat() orelse return .{ .float_val = 0.0 };
    return .{ .float_val = @floor(val) };
}

fn nativeCeil(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .float_val = 0.0 };
    const val = args[0].toFloat() orelse return .{ .float_val = 0.0 };
    return .{ .float_val = @ceil(val) };
}

fn nativePush(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const val = args[1];
    
    // Create new array with one more element
    const new_len = arr.items.len + 1;
    const new_items = vm.allocator.alloc(Value, new_len) catch return VMError.OutOfMemory;
    
    // Copy existing items
    for (arr.items, 0..) |item, i| {
        new_items[i] = item;
    }
    // Add new item
    new_items[arr.items.len] = val;
    
    // Create new array value
    const new_arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    new_arr.* = .{ .items = new_items, .capacity = new_len };
    
    return .{ .array_val = new_arr };
}

fn nativePop(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .nil = {} };
    
    // Return last element
    return arr.items[arr.items.len - 1];
}

fn nativeFirst(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .nil = {} };
    
    return arr.items[0];
}

fn nativeLast(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .nil = {} };
    
    return arr.items[arr.items.len - 1];
}

fn nativeRange(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    
    const start = args[0].toInt() orelse return .{ .nil = {} };
    const end = args[1].toInt() orelse return .{ .nil = {} };
    
    if (end < start) return .{ .nil = {} };
    
    const len: usize = @intCast(end - start);
    const items = vm.allocator.alloc(Value, len) catch return VMError.OutOfMemory;
    
    var i: usize = 0;
    var val = start;
    while (val < end) : ({ val += 1; i += 1; }) {
        items[i] = .{ .int_val = val };
    }
    
    const arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    arr.* = .{ .items = items, .capacity = len };
    
    return .{ .array_val = arr };
}

fn nativeKeys(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .object_val) return .{ .nil = {} };
    
    const obj = args[0].object_val;
    const items = vm.allocator.alloc(Value, obj.count) catch return VMError.OutOfMemory;
    
    for (0..obj.count) |i| {
        items[i] = .{ .string_val = obj.keys[i] };
    }
    
    const arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    arr.* = .{ .items = items, .capacity = obj.count };
    
    return .{ .array_val = arr };
}

fn nativeValues(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .object_val) return .{ .nil = {} };
    
    const obj = args[0].object_val;
    const items = vm.allocator.alloc(Value, obj.count) catch return VMError.OutOfMemory;
    
    for (0..obj.count) |i| {
        items[i] = obj.values[i];
    }
    
    const arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    arr.* = .{ .items = items, .capacity = obj.count };
    
    return .{ .array_val = arr };
}

fn nativeSum(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .int_val = 0 };
    if (args[0] != .array_val) return .{ .int_val = 0 };
    
    const arr = args[0].array_val;
    var sum: i64 = 0;
    for (arr.items) |item| {
        if (item.toInt()) |n| {
            sum += n;
        }
    }
    return .{ .int_val = sum };
}

fn nativeProduct(vm: *VM, args: []const Value) VMError!Value {
    _ = vm;
    if (args.len < 1) return .{ .int_val = 1 };
    if (args[0] != .array_val) return .{ .int_val = 1 };
    
    const arr = args[0].array_val;
    var prod: i64 = 1;
    for (arr.items) |item| {
        if (item.toInt()) |n| {
            prod *= n;
        }
    }
    return .{ .int_val = prod };
}

fn nativeReverse(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 1) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const items = vm.allocator.alloc(Value, arr.items.len) catch return VMError.OutOfMemory;
    
    for (arr.items, 0..) |item, i| {
        items[arr.items.len - 1 - i] = item;
    }
    
    const new_arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    new_arr.* = .{ .items = items, .capacity = arr.items.len };
    
    return .{ .array_val = new_arr };
}

fn nativeConcat(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .array_val or args[1] != .array_val) return .{ .nil = {} };
    
    const arr1 = args[0].array_val;
    const arr2 = args[1].array_val;
    const new_len = arr1.items.len + arr2.items.len;
    
    const items = vm.allocator.alloc(Value, new_len) catch return VMError.OutOfMemory;
    
    for (arr1.items, 0..) |item, i| {
        items[i] = item;
    }
    for (arr2.items, 0..) |item, i| {
        items[arr1.items.len + i] = item;
    }
    
    const new_arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    new_arr.* = .{ .items = items, .capacity = new_len };
    
    return .{ .array_val = new_arr };
}

fn nativeMap(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const func = args[1];
    
    // Get function address
    const func_addr: u16 = switch (func) {
        .int_val => |v| @intCast(@max(0, v)),
        .func_val => |f| f.addr,
        .closure_val => |c| c.func_addr,
        else => return .{ .nil = {} },
    };
    
    const items = vm.allocator.alloc(Value, arr.items.len) catch return VMError.OutOfMemory;
    
    // Call function for each element
    for (arr.items, 0..) |item, i| {
        const result = vm.callFunction(func_addr, &[_]Value{item}) catch return VMError.OutOfMemory;
        items[i] = result;
    }
    
    const new_arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    new_arr.* = .{ .items = items, .capacity = arr.items.len };
    
    return .{ .array_val = new_arr };
}

fn nativeFilter(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const func = args[1];
    
    const func_addr: u16 = switch (func) {
        .int_val => |v| @intCast(@max(0, v)),
        .func_val => |f| f.addr,
        .closure_val => |c| c.func_addr,
        else => return .{ .nil = {} },
    };
    
    // First pass: count matching elements
    var count: usize = 0;
    for (arr.items) |item| {
        const result = vm.callFunction(func_addr, &[_]Value{item}) catch continue;
        if (result.toBool()) count += 1;
    }
    
    const items = vm.allocator.alloc(Value, count) catch return VMError.OutOfMemory;
    
    // Second pass: collect matching elements
    var idx: usize = 0;
    for (arr.items) |item| {
        const result = vm.callFunction(func_addr, &[_]Value{item}) catch continue;
        if (result.toBool()) {
            items[idx] = item;
            idx += 1;
        }
    }
    
    const new_arr = vm.allocator.create(bytecode.ArrayValue) catch return VMError.OutOfMemory;
    new_arr.* = .{ .items = items, .capacity = count };
    
    return .{ .array_val = new_arr };
}

fn nativeReduce(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 3) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const func = args[1];
    var acc = args[2];
    
    const func_addr: u16 = switch (func) {
        .int_val => |v| @intCast(@max(0, v)),
        .func_val => |f| f.addr,
        .closure_val => |c| c.func_addr,
        else => return .{ .nil = {} },
    };
    
    for (arr.items) |item| {
        acc = vm.callFunction(func_addr, &[_]Value{ acc, item }) catch return acc;
    }
    
    return acc;
}

fn nativeForeach(vm: *VM, args: []const Value) VMError!Value {
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .array_val) return .{ .nil = {} };
    
    const arr = args[0].array_val;
    const func = args[1];
    
    const func_addr: u16 = switch (func) {
        .int_val => |v| @intCast(@max(0, v)),
        .func_val => |f| f.addr,
        .closure_val => |c| c.func_addr,
        else => return .{ .nil = {} },
    };
    
    for (arr.items) |item| {
        _ = vm.callFunction(func_addr, &[_]Value{item}) catch continue;
    }
    
    return .{ .nil = {} };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY/TRYTE NATIVE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeToTryte(_: *VM, args: []const Value) VMError!Value {
    // Convert int to tryte (balanced ternary, -13..+13)
    if (args.len < 1) return .{ .tryte_val = 0 };
    const ia = args[0].toInt() orelse 0;
    // Wrap to -13..+13 range (mod 27 centered at 0)
    const t: i16 = @intCast(@mod(ia + 13, 27) - 13);
    return .{ .tryte_val = @intCast(t) };
}

fn nativeFromTryte(_: *VM, args: []const Value) VMError!Value {
    // Convert tryte to int
    if (args.len < 1) return .{ .int_val = 0 };
    const ta = args[0].toTryte() orelse 0;
    return .{ .int_val = @as(i64, ta) };
}

fn nativeTritAdd(_: *VM, args: []const Value) VMError!Value {
    // Balanced ternary addition
    if (args.len < 2) return .{ .tryte_val = 0 };
    const ta = args[0].toTryte() orelse 0;
    const tb = args[1].toTryte() orelse 0;
    var sum: i16 = @as(i16, ta) + @as(i16, tb);
    // Wrap to -13..+13 range
    while (sum > 13) sum -= 27;
    while (sum < -13) sum += 27;
    return .{ .tryte_val = @intCast(sum) };
}

fn nativeTritMul(_: *VM, args: []const Value) VMError!Value {
    // Balanced ternary multiplication
    if (args.len < 2) return .{ .tryte_val = 0 };
    const ta = args[0].toTryte() orelse 0;
    const tb = args[1].toTryte() orelse 0;
    var prod: i16 = @as(i16, ta) * @as(i16, tb);
    // Wrap to -13..+13 range
    while (prod > 13) prod -= 27;
    while (prod < -13) prod += 27;
    return .{ .tryte_val = @intCast(prod) };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRYTE FUNCTIONAL PRIMITIVES (SIMD OPTIMIZED)
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeTryteSumSIMD(_: *VM, args: []const Value) VMError!Value {
    // SIMD-optimized sum of all trytes in an array
    if (args.len < 1) return .{ .tryte_val = 0 };
    if (args[0] != .array_val) return .{ .tryte_val = 0 };
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .tryte_val = 0 };
    
    // Extract tryte values to i8 array
    var trytes: [256]i8 = undefined;
    const len = @min(arr.items.len, 256);
    for (0..len) |i| {
        trytes[i] = arr.items[i].toTryte() orelse 0;
    }
    
    // Use SIMD batch sum
    const result = simd_ternary.batchTryteSum(trytes[0..len]);
    return .{ .tryte_val = result };
}

fn nativeTryteMaxSIMD(_: *VM, args: []const Value) VMError!Value {
    // SIMD-optimized max of tryte array
    if (args.len < 1) return .{ .tryte_val = -13 };
    if (args[0] != .array_val) return .{ .tryte_val = -13 };
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .tryte_val = -13 };
    
    // Extract tryte values to i8 array
    var trytes: [256]i8 = undefined;
    const len = @min(arr.items.len, 256);
    for (0..len) |i| {
        trytes[i] = arr.items[i].toTryte() orelse -13;
    }
    
    // Use SIMD batch max
    const result = simd_ternary.batchTryteMax(trytes[0..len]);
    return .{ .tryte_val = result };
}

fn nativeTryteMinSIMD(_: *VM, args: []const Value) VMError!Value {
    // SIMD-optimized min of tryte array
    if (args.len < 1) return .{ .tryte_val = 13 };
    if (args[0] != .array_val) return .{ .tryte_val = 13 };
    const arr = args[0].array_val;
    if (arr.items.len == 0) return .{ .tryte_val = 13 };
    
    // Extract tryte values to i8 array
    var trytes: [256]i8 = undefined;
    const len = @min(arr.items.len, 256);
    for (0..len) |i| {
        trytes[i] = arr.items[i].toTryte() orelse 13;
    }
    
    // Use SIMD batch min
    const result = simd_ternary.batchTryteMin(trytes[0..len]);
    return .{ .tryte_val = result };
}

fn nativeTryteRange(vm: *VM, args: []const Value) VMError!Value {
    // Create array of trytes from start to end (inclusive)
    if (args.len < 2) return .{ .nil = {} };
    const start = args[0].toTryte() orelse 0;
    const end = args[1].toTryte() orelse 0;
    
    const count: usize = if (end >= start) @intCast(end - start + 1) else 0;
    if (count == 0) return .{ .nil = {} };
    
    const arr = vm.allocator.create(bytecode.ArrayValue) catch return error.OutOfMemory;
    arr.items = vm.allocator.alloc(Value, count) catch return error.OutOfMemory;
    arr.capacity = count;
    
    var i: usize = 0;
    var val: i8 = start;
    while (i < count) : (i += 1) {
        arr.items[i] = .{ .tryte_val = val };
        val += 1;
    }
    
    return .{ .array_val = arr };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRYTE ARRAY NATIVE FUNCTIONS (Direct SIMD access)
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeTryteArrayNew(vm: *VM, args: []const Value) VMError!Value {
    // Create new TryteArray with given size
    const size: usize = if (args.len > 0) @intCast(args[0].toInt() orelse 0) else 0;
    const arr = vm.allocator.create(bytecode.TryteArrayValue) catch return error.OutOfMemory;
    arr.data = vm.allocator.alloc(i8, size) catch return error.OutOfMemory;
    arr.len = size;
    arr.capacity = size;
    @memset(arr.data, 0);
    return .{ .tryte_array_val = arr };
}

fn nativeTryteArrayGet(_: *VM, args: []const Value) VMError!Value {
    // Get element from TryteArray
    if (args.len < 2) return .{ .tryte_val = 0 };
    if (args[0] != .tryte_array_val) return .{ .tryte_val = 0 };
    const arr = args[0].tryte_array_val;
    const idx: usize = @intCast(args[1].toInt() orelse 0);
    if (idx >= arr.len) return .{ .tryte_val = 0 };
    return .{ .tryte_val = arr.data[idx] };
}

fn nativeTryteArraySet(_: *VM, args: []const Value) VMError!Value {
    // Set element in TryteArray, return array for chaining
    if (args.len < 3) return .{ .nil = {} };
    if (args[0] != .tryte_array_val) return .{ .nil = {} };
    const arr = args[0].tryte_array_val;
    const idx: usize = @intCast(args[1].toInt() orelse 0);
    const val = args[2].toTryte() orelse 0;
    if (idx >= arr.len) return args[0];
    arr.data[idx] = val;
    return args[0];
}

fn nativeTryteArrayLen(_: *VM, args: []const Value) VMError!Value {
    // Get length of TryteArray
    if (args.len < 1) return .{ .int_val = 0 };
    if (args[0] != .tryte_array_val) return .{ .int_val = 0 };
    const arr = args[0].tryte_array_val;
    return .{ .int_val = @intCast(arr.len) };
}

fn nativeTryteArraySum(_: *VM, args: []const Value) VMError!Value {
    // SIMD sum of TryteArray (direct access, no extraction!)
    if (args.len < 1) return .{ .tryte_val = 0 };
    if (args[0] != .tryte_array_val) return .{ .tryte_val = 0 };
    const arr = args[0].tryte_array_val;
    const result = simd_ternary.batchTryteSum(arr.data[0..arr.len]);
    return .{ .tryte_val = result };
}

fn nativeTryteArrayMax(_: *VM, args: []const Value) VMError!Value {
    // SIMD max of TryteArray (direct access)
    if (args.len < 1) return .{ .tryte_val = -13 };
    if (args[0] != .tryte_array_val) return .{ .tryte_val = -13 };
    const arr = args[0].tryte_array_val;
    const result = simd_ternary.batchTryteMax(arr.data[0..arr.len]);
    return .{ .tryte_val = result };
}

fn nativeTryteArrayMin(_: *VM, args: []const Value) VMError!Value {
    // SIMD min of TryteArray (direct access)
    if (args.len < 1) return .{ .tryte_val = 13 };
    if (args[0] != .tryte_array_val) return .{ .tryte_val = 13 };
    const arr = args[0].tryte_array_val;
    const result = simd_ternary.batchTryteMin(arr.data[0..arr.len]);
    return .{ .tryte_val = result };
}

fn nativeTryteArrayFill(_: *VM, args: []const Value) VMError!Value {
    // Fill TryteArray with value
    if (args.len < 2) return .{ .nil = {} };
    if (args[0] != .tryte_array_val) return .{ .nil = {} };
    const arr = args[0].tryte_array_val;
    const val = args[1].toTryte() orelse 0;
    @memset(arr.data, val);
    return args[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATH NATIVE FUNCTIONS
// φ² + 1/φ² = 3 = КУТРИТ = ТРОИЦА
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeLucas(_: *VM, args: []const Value) VMError!Value {
    // Lucas number L(n) = φⁿ + 1/φⁿ
    // Key: L(2) = 3 = TRINITY!
    if (args.len < 1) return .{ .int_val = 2 }; // L(0) = 2
    const n: u32 = @intCast(args[0].toInt() orelse 0);
    return .{ .int_val = sacred_math.lucas(n) };
}

fn nativeFibonacci(_: *VM, args: []const Value) VMError!Value {
    // Fibonacci F(n) = (φⁿ - 1/φⁿ) / √5
    // Key: F(7) = 13 = TRYTE_MAX!
    if (args.len < 1) return .{ .int_val = 0 }; // F(0) = 0
    const n: u32 = @intCast(args[0].toInt() orelse 0);
    return .{ .int_val = sacred_math.fibonacci(n) };
}

fn nativePhiHash(_: *VM, args: []const Value) VMError!Value {
    // Fibonacci hash for optimal distribution
    if (args.len < 2) return .{ .int_val = 0 };
    const key: u64 = @intCast(args[0].toInt() orelse 0);
    const bits: u6 = @intCast(@min(args[1].toInt() orelse 8, 63));
    return .{ .int_val = @intCast(sacred_math.phiHashMod(key, bits)) };
}

fn nativeGoldenWrap(_: *VM, args: []const Value) VMError!Value {
    // Golden wrap using φ² + 1/φ² = 3 identity
    if (args.len < 1) return .{ .tryte_val = 0 };
    const val: i16 = @intCast(args[0].toInt() orelse 0);
    return .{ .tryte_val = sacred_math.goldenWrap(val) };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADDITIONAL SACRED NATIVE FUNCTIONS
// φ² + 1/φ² = 3 | PHOENIX = 999 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeSacredFormula(_: *VM, args: []const Value) VMError!Value {
    // V = n × 3^k × π^m × φ^p × e^q
    if (args.len < 5) return .{ .float_val = 0 };
    const n: u32 = @intCast(args[0].toInt() orelse 1);
    const k: i32 = @intCast(args[1].toInt() orelse 0);
    const m: i32 = @intCast(args[2].toInt() orelse 0);
    const p: i32 = @intCast(args[3].toInt() orelse 0);
    const q: i32 = @intCast(args[4].toInt() orelse 0);
    const nf: f64 = @floatFromInt(n);
    const three_k = std.math.pow(f64, 3.0, @as(f64, @floatFromInt(k)));
    const pi_m = std.math.pow(f64, PI, @as(f64, @floatFromInt(m)));
    const phi_p = std.math.pow(f64, PHI, @as(f64, @floatFromInt(p)));
    const e_q = std.math.pow(f64, E, @as(f64, @floatFromInt(q)));
    return .{ .float_val = nf * three_k * pi_m * phi_p * e_q };
}

fn nativeGoldenIdentity(_: *VM, _: []const Value) VMError!Value {
    // φ² + 1/φ² = 3 EXACTLY
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    return .{ .float_val = phi_sq + phi_inv_sq };
}

fn nativeMagic37(_: *VM, args: []const Value) VMError!Value {
    // 37 × 3n = nnn (111, 222, ..., 999)
    if (args.len < 1) return .{ .int_val = 0 };
    const n: u32 = @intCast(args[0].toInt() orelse 1);
    return .{ .int_val = @intCast(37 * 3 * n) };
}

fn nativeAlphaInv(_: *VM, _: []const Value) VMError!Value {
    // 1/α = 4π³ + π² + π ≈ 137.036
    return .{ .float_val = 4.0 * PI * PI * PI + PI * PI + PI };
}

fn nativeTranscendental(_: *VM, _: []const Value) VMError!Value {
    // π × φ × e ≈ 13.82 (close to tryte max!)
    return .{ .float_val = PI * PHI * E };
}

fn nativeTridevyatitsa(_: *VM, args: []const Value) VMError!Value {
    // 27 = 3³ = Coptic alphabet size
    if (args.len < 1) return .{ .int_val = 0 };
    const val: i64 = args[0].toInt() orelse 0;
    const m = @mod(val, 27);
    return .{ .int_val = if (m < 0) m + 27 else m };
}

fn nativePhiSpiral(_: *VM, args: []const Value) VMError!Value {
    // φ-spiral position: angle = n × φ × π
    if (args.len < 1) return .{ .float_val = 0 };
    const n: u32 = @intCast(args[0].toInt() orelse 0);
    const nf: f64 = @floatFromInt(n);
    const angle = nf * PHI * PI;
    return .{ .float_val = angle };
}

fn nativeChshCheck(_: *VM, args: []const Value) VMError!Value {
    // Check for quantum advantage: CHSH > 2
    if (args.len < 1) return .{ .bool_val = false };
    const val = args[0].toFloat() orelse 0;
    return .{ .bool_val = val > 2.0 };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIMING NATIVE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn nativeClock(_: *VM, _: []const Value) VMError!Value {
    // Return current timestamp in nanoseconds as int
    const now = std.time.nanoTimestamp();
    return .{ .int_val = @intCast(now) };
}

fn nativeElapsed(_: *VM, args: []const Value) VMError!Value {
    // Calculate elapsed time between two clock() values in microseconds
    if (args.len < 2) return .{ .float_val = 0 };
    const start = args[0].toInt() orelse 0;
    const end = args[1].toInt() orelse 0;
    const diff_ns = end - start;
    const diff_us = @as(f64, @floatFromInt(diff_ns)) / 1000.0;
    return .{ .float_val = diff_us };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM basic push and halt" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit(allocator);

    // Simple: push 42, halt
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // PUSH_CONST idx=0
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{.{ .int_val = 42 }};

    vm.load(&code, &constants);
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 42), result.int_val);
}

test "VM sacred constants" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit(allocator);

    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_PHI),
        @intFromEnum(Opcode.HALT),
    };

    vm.load(&code, &.{});
    const result = try vm.run();

    try std.testing.expectApproxEqAbs(PHI, result.float_val, 0.0001);
}

test "VM golden identity" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit(allocator);

    const code = [_]u8{
        @intFromEnum(Opcode.GOLDEN_IDENTITY_OP),
        @intFromEnum(Opcode.HALT),
    };

    vm.load(&code, &.{});
    const result = try vm.run();

    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result.float_val, 0.0001);
}

test "VM comparison" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit(allocator);

    // 10 > 5 = true
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // 10
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // 5
        @intFromEnum(Opcode.GT),
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ .{ .int_val = 10 }, .{ .int_val = 5 } };

    vm.load(&code, &constants);
    const result = try vm.run();

    try std.testing.expect(result.bool_val);
}

test "VM metrics" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit(allocator);

    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{.{ .int_val = 1 }};

    vm.load(&code, &constants);
    _ = try vm.run();

    const metrics = vm.getMetrics();
    try std.testing.expect(metrics.instructions_executed >= 2);
}

test "golden identity verification" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
