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
pub const CALL_STACK_SIZE: usize = 1024;
pub const MAX_LOCALS: usize = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// CALL FRAME
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallFrame = struct {
    return_addr: u32,
    base_pointer: u32,
    locals: [MAX_LOCALS]Value,
    local_count: u8,

    pub fn init(return_addr: u32, base_pointer: u32) CallFrame {
        return CallFrame{
            .return_addr = return_addr,
            .base_pointer = base_pointer,
            .locals = [_]Value{.{ .nil = {} }} ** MAX_LOCALS,
            .local_count = 0,
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

    // Stack
    stack: [STACK_SIZE]Value,
    sp: u32,

    // Call stack
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
            .call_stack = call_stack,
            .fp = 0,
            .globals = std.StringHashMap(Value).init(allocator),
            .natives = std.StringHashMap(NativeFunction).init(allocator),
            .state = .ready,
            .last_error = null,
            .instructions_executed = 0,
            .cycles = 0,
        };

        // Register built-in natives
        try vm.registerBuiltins();

        return vm;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.call_stack);
        self.globals.deinit();
        self.natives.deinit();
    }

    fn registerBuiltins(self: *Self) !void {
        try self.registerNative("print", 1, nativePrint);
        try self.registerNative("sqrt", 1, nativeSqrt);
        try self.registerNative("sin", 1, nativeSin);
        try self.registerNative("cos", 1, nativeCos);
        try self.registerNative("phi", 0, nativePhi);
        try self.registerNative("golden", 0, nativeGolden);
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
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STACK OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    fn push(self: *Self, value: Value) VMError!void {
        if (self.sp >= STACK_SIZE) return VMError.StackOverflow;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn pop(self: *Self) VMError!Value {
        if (self.sp == 0) return VMError.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    fn peek(self: *Self, distance: u32) VMError!Value {
        if (distance >= self.sp) return VMError.StackUnderflow;
        return self.stack[self.sp - 1 - distance];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BYTECODE READING
    // ═══════════════════════════════════════════════════════════════════════════

    fn readByte(self: *Self) VMError!u8 {
        if (self.ip >= self.code.len) return VMError.InvalidAddress;
        const byte = self.code[self.ip];
        self.ip += 1;
        return byte;
    }

    fn readU16(self: *Self) VMError!u16 {
        const high = try self.readByte();
        const low = try self.readByte();
        return (@as(u16, high) << 8) | low;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION LOOP - D&C PATTERN
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn run(self: *Self) VMError!Value {
        self.state = .running;

        while (self.state == .running) {
            const opcode_byte = try self.readByte();
            const opcode: Opcode = @enumFromInt(opcode_byte);

            try self.executeOpcode(opcode);
            self.instructions_executed += 1;
            self.cycles += 1;
        }

        if (self.sp > 0) {
            return self.stack[self.sp - 1];
        }
        return .{ .nil = {} };
    }

    fn executeOpcode(self: *Self, opcode: Opcode) VMError!void {
        switch (opcode) {
            // Stack Operations
            .NOP => {},

            .PUSH_CONST => {
                const idx = try self.readU16();
                if (idx >= self.constants.len) return VMError.InvalidConstant;
                try self.push(self.constants[idx]);
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
                const idx = try self.readU16();
                const frame = &self.call_stack[self.fp];
                try self.push(frame.locals[idx]);
            },

            .STORE_LOCAL => {
                const idx = try self.readU16();
                const value = try self.pop();
                self.call_stack[self.fp].locals[idx] = value;
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

            // Logic
            .NOT => {
                const value = try self.pop();
                const result = switch (value) {
                    .bool_val => |v| !v,
                    .int_val => |v| v == 0,
                    .nil => true,
                    else => false,
                };
                try self.push(.{ .bool_val = result });
            },

            .AND => {
                const b = try self.pop();
                const a = try self.pop();
                const result = self.isTruthy(a) and self.isTruthy(b);
                try self.push(.{ .bool_val = result });
            },

            .OR => {
                const b = try self.pop();
                const a = try self.pop();
                const result = self.isTruthy(a) or self.isTruthy(b);
                try self.push(.{ .bool_val = result });
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

            .RET => {
                const return_value = if (self.sp > self.call_stack[self.fp].base_pointer)
                    try self.pop()
                else
                    Value{ .nil = {} };

                self.ip = self.call_stack[self.fp].return_addr;
                self.sp = self.call_stack[self.fp].base_pointer;

                if (self.fp > 0) {
                    self.fp -= 1;
                }

                try self.push(return_value);
            },

            .HALT => {
                self.state = .halted;
            },

            .LOOP => {
                const offset = try self.readU16();
                self.ip -= offset;
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

            // Superinstructions
            .LOAD_ADD => {
                const idx = try self.readU16();
                const frame = &self.call_stack[self.fp];
                const local = frame.locals[idx];
                const top = try self.pop();
                try self.binaryOpValues(local, top, .add);
            },

            .LOAD_SUB => {
                const idx = try self.readU16();
                const frame = &self.call_stack[self.fp];
                const local = frame.locals[idx];
                const top = try self.pop();
                try self.binaryOpValues(local, top, .sub);
            },

            .LOAD_MUL => {
                const idx = try self.readU16();
                const frame = &self.call_stack[self.fp];
                const local = frame.locals[idx];
                const top = try self.pop();
                try self.binaryOpValues(local, top, .mul);
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

        const result: bool = blk: {
            // Both integers
            if (a == .int_val and b == .int_val) {
                break :blk switch (op) {
                    .eq => a.int_val == b.int_val,
                    .ne => a.int_val != b.int_val,
                    .lt => a.int_val < b.int_val,
                    .le => a.int_val <= b.int_val,
                    .gt => a.int_val > b.int_val,
                    .ge => a.int_val >= b.int_val,
                };
            }

            // Convert to float
            const fa = a.toFloat() orelse return VMError.TypeMismatch;
            const fb = b.toFloat() orelse return VMError.TypeMismatch;

            break :blk switch (op) {
                .eq => fa == fb,
                .ne => fa != fb,
                .lt => fa < fb,
                .le => fa <= fb,
                .gt => fa > fb,
                .ge => fa >= fb,
            };
        };

        try self.push(.{ .bool_val = result });
    }

    fn isTruthy(self: *Self, value: Value) bool {
        _ = self;
        return switch (value) {
            .nil => false,
            .bool_val => |v| v,
            .int_val => |v| v != 0,
            .float_val => |v| v != 0.0,
            .string_val => |v| v.len > 0,
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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM basic push and halt" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit();

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
    defer vm.deinit();

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
    defer vm.deinit();

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
    defer vm.deinit();

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
    defer vm.deinit();

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
