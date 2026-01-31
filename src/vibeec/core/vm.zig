// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC UNIFIED VM - SINGLE SOURCE OF TRUTH
// ═══════════════════════════════════════════════════════════════════════════════
// Replaces: bytecode_vm.zig, coptic_interpreter.zig, etc.
// Supports: Stack-based and Register-based execution modes
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const value = @import("value.zig");

pub const Value = value.Value;
pub const PHI = value.PHI;
pub const PI = value.PI;
pub const E = value.E;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Stack
    nop = 0x00,
    push = 0x01,
    pop = 0x02,
    dup = 0x03,
    swap = 0x04,

    // Load/Store
    load_const = 0x10,
    load_local = 0x11,
    store_local = 0x12,
    load_global = 0x13,
    store_global = 0x14,

    // Arithmetic
    add = 0x20,
    sub = 0x21,
    mul = 0x22,
    div = 0x23,
    mod = 0x24,
    neg = 0x25,

    // Float Arithmetic (explicit)
    fadd = 0x26,
    fsub = 0x27,
    fmul = 0x28,
    fdiv = 0x29,

    // Float Comparison
    flt = 0x2A,
    fle = 0x2B,
    fgt = 0x2C,
    fge = 0x2D,
    feq = 0x2E,

    // Comparison
    eq = 0x30,
    ne = 0x31,
    lt = 0x32,
    le = 0x33,
    gt = 0x34,
    ge = 0x35,

    // Logic
    @"and" = 0x40,
    @"or" = 0x41,
    not = 0x42,

    // Ternary
    trit_not = 0x48,
    trit_and = 0x49,
    trit_or = 0x4A,

    // Control
    jump = 0x50,
    jump_if = 0x51,
    jump_if_not = 0x52,
    call = 0x53,
    ret = 0x54,

    // Native
    native_call = 0x60,
    print = 0x61,

    // Special
    halt = 0xFF,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL FRAME
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallFrame = struct {
    return_ip: u32,
    base_ptr: u32,
    func_id: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VMConfig = struct {
    stack_size: u32 = 1024,
    max_frames: u32 = 256,
    max_globals: u32 = 256,
    trace_execution: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const VM = struct {
    // Memory
    stack: []Value,
    frames: []CallFrame,
    globals: []Value,
    constants: []const Value,

    // Registers
    ip: u32, // Instruction pointer
    sp: u32, // Stack pointer
    fp: u32, // Frame pointer

    // Bytecode
    code: []const u8,

    // Config
    config: VMConfig,
    allocator: std.mem.Allocator,

    // Output
    output: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: VMConfig) !Self {
        return Self{
            .stack = try allocator.alloc(Value, config.stack_size),
            .frames = try allocator.alloc(CallFrame, config.max_frames),
            .globals = try allocator.alloc(Value, config.max_globals),
            .constants = &[_]Value{},
            .ip = 0,
            .sp = 0,
            .fp = 0,
            .code = &[_]u8{},
            .config = config,
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.stack);
        self.allocator.free(self.frames);
        self.allocator.free(self.globals);
        self.output.deinit();
    }

    pub fn load(self: *Self, code: []const u8, constants: []const Value) void {
        self.code = code;
        self.constants = constants;
        self.ip = 0;
        self.sp = 0;
        self.fp = 0;
    }

    pub fn reset(self: *Self) void {
        self.ip = 0;
        self.sp = 0;
        self.fp = 0;
        self.output.clearRetainingCapacity();
    }

    // Stack operations
    inline fn push(self: *Self, v: Value) !void {
        if (self.sp >= self.stack.len) return error.StackOverflow;
        self.stack[self.sp] = v;
        self.sp += 1;
    }

    inline fn pop(self: *Self) !Value {
        if (self.sp == 0) return error.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    inline fn peek(self: *Self, offset: u32) !Value {
        if (offset >= self.sp) return error.StackUnderflow;
        return self.stack[self.sp - 1 - offset];
    }

    // Bytecode reading
    inline fn readByte(self: *Self) !u8 {
        if (self.ip >= self.code.len) return error.EndOfCode;
        const b = self.code[self.ip];
        self.ip += 1;
        return b;
    }

    inline fn readU16(self: *Self) !u16 {
        const hi = try self.readByte();
        const lo = try self.readByte();
        return (@as(u16, hi) << 8) | @as(u16, lo);
    }

    inline fn readU32(self: *Self) !u32 {
        const b0 = try self.readByte();
        const b1 = try self.readByte();
        const b2 = try self.readByte();
        const b3 = try self.readByte();
        return (@as(u32, b0) << 24) | (@as(u32, b1) << 16) | (@as(u32, b2) << 8) | @as(u32, b3);
    }

    // Main execution loop
    pub fn run(self: *Self) !Value {
        while (true) {
            const opcode_byte = try self.readByte();
            const opcode: Opcode = @enumFromInt(opcode_byte);

            switch (opcode) {
                .nop => {},

                .push => {
                    const idx = try self.readU16();
                    if (idx >= self.constants.len) return error.InvalidConstant;
                    try self.push(self.constants[idx]);
                },

                .pop => {
                    _ = try self.pop();
                },

                .dup => {
                    const v = try self.peek(0);
                    try self.push(v);
                },

                .swap => {
                    const a = try self.pop();
                    const b = try self.pop();
                    try self.push(a);
                    try self.push(b);
                },

                .load_const => {
                    const idx = try self.readU16();
                    if (idx >= self.constants.len) return error.InvalidConstant;
                    try self.push(self.constants[idx]);
                },

                .load_local => {
                    const idx = try self.readU16();
                    const addr = self.fp + idx;
                    if (addr >= self.sp) return error.InvalidLocal;
                    try self.push(self.stack[addr]);
                },

                .store_local => {
                    const idx = try self.readU16();
                    const addr = self.fp + idx;
                    if (addr >= self.stack.len) return error.InvalidLocal;
                    self.stack[addr] = try self.pop();
                },

                .load_global => {
                    const idx = try self.readU16();
                    if (idx >= self.globals.len) return error.InvalidGlobal;
                    try self.push(self.globals[idx]);
                },

                .store_global => {
                    const idx = try self.readU16();
                    if (idx >= self.globals.len) return error.InvalidGlobal;
                    self.globals[idx] = try self.pop();
                },

                .add => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.add(a, b));
                },

                .sub => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.sub(a, b));
                },

                .mul => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.mul(a, b));
                },

                .div => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.div(a, b));
                },

                // Float arithmetic (explicit)
                .fadd => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.float(a.asFloat() + b.asFloat()));
                },

                .fsub => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.float(a.asFloat() - b.asFloat()));
                },

                .fmul => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.float(a.asFloat() * b.asFloat()));
                },

                .fdiv => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.float(a.asFloat() / b.asFloat()));
                },

                .flt => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.asFloat() < b.asFloat()));
                },

                .fle => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.asFloat() <= b.asFloat()));
                },

                .fgt => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.asFloat() > b.asFloat()));
                },

                .fge => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.asFloat() >= b.asFloat()));
                },

                .feq => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.asFloat() == b.asFloat()));
                },

                .mod => {
                    const b = try self.pop();
                    const a = try self.pop();
                    if (a.isInt() and b.isInt()) {
                        const bv = b.asInt();
                        if (bv == 0) return error.DivisionByZero;
                        try self.push(Value.int(@mod(a.asInt(), bv)));
                    } else {
                        try self.push(Value.float(@mod(a.toFloat(), b.toFloat())));
                    }
                },

                .neg => {
                    const a = try self.pop();
                    if (a.isInt()) {
                        try self.push(Value.int(-a.asInt()));
                    } else {
                        try self.push(Value.float(-a.toFloat()));
                    }
                },

                .eq => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.eq(a, b));
                },

                .ne => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(!Value.eq(a, b).asBool()));
                },

                .lt => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.lt(a, b));
                },

                .le => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.le(a, b));
                },

                .gt => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.gt(a, b));
                },

                .ge => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.ge(a, b));
                },

                .@"and" => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.toBool() and b.toBool()));
                },

                .@"or" => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.boolean(a.toBool() or b.toBool()));
                },

                .not => {
                    const a = try self.pop();
                    try self.push(Value.boolean(!a.toBool()));
                },

                .trit_not => {
                    const a = try self.pop();
                    try self.push(a.tritNot());
                },

                .trit_and => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.tritAnd(a, b));
                },

                .trit_or => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(Value.tritOr(a, b));
                },

                .jump => {
                    self.ip = try self.readU32();
                },

                .jump_if => {
                    const target = try self.readU32();
                    const cond = try self.pop();
                    if (cond.toBool()) {
                        self.ip = target;
                    }
                },

                .jump_if_not => {
                    const target = try self.readU32();
                    const cond = try self.pop();
                    if (!cond.toBool()) {
                        self.ip = target;
                    }
                },

                .call => {
                    const func_addr = try self.readU32();
                    const arg_count = try self.readByte();

                    if (self.fp >= self.frames.len) return error.CallStackOverflow;

                    self.frames[self.fp] = CallFrame{
                        .return_ip = self.ip,
                        .base_ptr = self.sp - arg_count,
                        .func_id = func_addr,
                    };
                    self.fp += 1;
                    self.ip = func_addr;
                },

                .ret => {
                    if (self.fp == 0) {
                        if (self.sp > 0) {
                            return self.stack[self.sp - 1];
                        }
                        return Value.nil();
                    }

                    self.fp -= 1;
                    const frame = self.frames[self.fp];
                    const result = if (self.sp > frame.base_ptr) self.stack[self.sp - 1] else Value.nil();
                    self.sp = frame.base_ptr;
                    self.ip = frame.return_ip;
                    try self.push(result);
                },

                .native_call => {
                    const native_id = try self.readU16();
                    try self.executeNative(native_id);
                },

                .print => {
                    const v = try self.pop();
                    var buf: [64]u8 = undefined;
                    const str = std.fmt.bufPrint(&buf, "{}", .{v}) catch "?";
                    try self.output.appendSlice(str);
                    try self.output.append('\n');
                },

                .halt => {
                    if (self.sp > 0) {
                        return self.stack[self.sp - 1];
                    }
                    return Value.nil();
                },
            }
        }
    }

    fn executeNative(self: *Self, id: u16) !void {
        switch (id) {
            0 => { // print
                const v = try self.pop();
                var buf: [64]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{}", .{v}) catch "?";
                try self.output.appendSlice(str);
                try self.output.append('\n');
            },
            1 => { // phi
                try self.push(Value.float(PHI));
            },
            2 => { // pi
                try self.push(Value.float(PI));
            },
            3 => { // e
                try self.push(Value.float(E));
            },
            4 => { // len (placeholder)
                _ = try self.pop();
                try self.push(Value.int(0));
            },
            else => return error.UnknownNative,
        }
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.output.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM init/deinit" {
    var vm = try VM.init(std.testing.allocator, .{});
    defer vm.deinit();
    try std.testing.expectEqual(@as(u32, 0), vm.sp);
}

test "VM arithmetic" {
    var vm = try VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const constants = [_]Value{
        Value.int(10),
        Value.int(3),
    };

    // push 0, push 1, add, halt
    const code = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.add),
        @intFromEnum(Opcode.halt),
    };

    vm.load(&code, &constants);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 13), result.asInt());
}

test "VM comparison" {
    var vm = try VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const constants = [_]Value{
        Value.int(5),
        Value.int(10),
    };

    // push 5, push 10, lt, halt
    const code = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.lt),
        @intFromEnum(Opcode.halt),
    };

    vm.load(&code, &constants);
    const result = try vm.run();
    try std.testing.expect(result.asBool());
}

test "VM print" {
    var vm = try VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const constants = [_]Value{Value.int(42)};

    const code = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.print),
        @intFromEnum(Opcode.halt),
    };

    vm.load(&code, &constants);
    _ = try vm.run();
    try std.testing.expectEqualStrings("42\n", vm.getOutput());
}
