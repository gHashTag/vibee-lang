// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC REGISTER VM - .999 REGISTER-BASED EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V38 - Register-based Virtual Machine for 30-50% speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Architecture: 16 general-purpose registers (R0-R15)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const reg_bytecode = @import("reg_bytecode.zig");
const RegOpcode = reg_bytecode.RegOpcode;
const unpackRegs = reg_bytecode.unpackRegs;
const unpackU16 = reg_bytecode.unpackU16;
const bytecode = @import("bytecode.zig");
const Value = bytecode.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;

// ═══════════════════════════════════════════════════════════════════════════════
// VM CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const NUM_REGISTERS: usize = 16;
pub const MAX_LOCALS: usize = 256;
pub const CALL_STACK_SIZE: usize = 1024;

// ═══════════════════════════════════════════════════════════════════════════════
// FLAGS REGISTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Flags = packed struct {
    lt: bool = false, // Less than
    eq: bool = false, // Equal
    gt: bool = false, // Greater than
    _padding: u5 = 0,

    pub fn fromCmp(a: i64, b: i64) Flags {
        return .{
            .lt = a < b,
            .eq = a == b,
            .gt = a > b,
        };
    }

    pub fn le(self: Flags) bool {
        return self.lt or self.eq;
    }

    pub fn ge(self: Flags) bool {
        return self.gt or self.eq;
    }

    pub fn ne(self: Flags) bool {
        return !self.eq;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALL FRAME
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegCallFrame = struct {
    return_addr: u32,
    saved_regs: [NUM_REGISTERS]Value, // Save all registers on call
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const VMError = error{
    InvalidOpcode,
    DivisionByZero,
    TypeMismatch,
    InvalidAddress,
    CallStackOverflow,
    OutOfMemory,
    IndexOutOfBounds,
    UnknownNative,
};

// Native function IDs
pub const NativeId = enum(u16) {
    print = 0,
    len = 1,
    range = 2,
    sqrt = 3,
    sin = 4,
    cos = 5,
};

pub const RegVM = struct {
    allocator: Allocator,

    // Code and constants
    code: []const u8,
    constants: []const Value,

    // 16 general-purpose registers
    regs: [NUM_REGISTERS]Value,

    // Flags register (set by CMP)
    flags: Flags,

    // Locals storage
    locals: [MAX_LOCALS]Value,

    // Call stack
    call_stack: []RegCallFrame,
    fp: u32, // Frame pointer

    // Instruction pointer
    ip: u32,

    // State
    halted: bool,

    // Metrics
    instructions_executed: u64,
    start_time: i128,
    end_time: i128,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        const call_stack = try allocator.alloc(RegCallFrame, CALL_STACK_SIZE);

        const vm = Self{
            .allocator = allocator,
            .code = &.{},
            .constants = &.{},
            .regs = [_]Value{.{ .nil = {} }} ** NUM_REGISTERS,
            .flags = .{},
            .locals = [_]Value{.{ .nil = {} }} ** MAX_LOCALS,
            .call_stack = call_stack,
            .fp = 0,
            .ip = 0,
            .halted = false,
            .instructions_executed = 0,
            .start_time = 0,
            .end_time = 0,
        };

        return vm;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.call_stack);
    }

    pub fn load(self: *Self, code: []const u8, constants: []const Value) void {
        self.code = code;
        self.constants = constants;
        self.ip = 0;
        self.halted = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    inline fn readByte(self: *Self) u8 {
        const b = self.code[self.ip];
        self.ip += 1;
        return b;
    }

    inline fn readU16(self: *Self) u16 {
        const lo = self.code[self.ip];
        const hi = self.code[self.ip + 1];
        self.ip += 2;
        return unpackU16(lo, hi);
    }

    inline fn getInt(val: Value) i64 {
        return switch (val) {
            .int_val => |v| v,
            .float_val => |v| @intFromFloat(v),
            .bool_val => |v| if (v) @as(i64, 1) else @as(i64, 0),
            else => 0,
        };
    }

    inline fn getFloat(val: Value) f64 {
        return switch (val) {
            .float_val => |v| v,
            .int_val => |v| @floatFromInt(v),
            else => 0.0,
        };
    }

    inline fn getBool(val: Value) bool {
        return switch (val) {
            .bool_val => |v| v,
            .int_val => |v| v != 0,
            .nil => false,
            else => true,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION LOOP - ULTRA-FAST REGISTER DISPATCH
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn run(self: *Self) VMError!Value {
        self.start_time = std.time.nanoTimestamp();
        self.halted = false;

        // Cache frequently accessed fields
        const code = self.code;
        var ip = self.ip;
        const regs = &self.regs;
        const flags = &self.flags;
        const constants = self.constants;
        const locals = &self.locals;

        while (!self.halted and ip < code.len) {
            const op_byte = code[ip];
            ip += 1;

            // ═══════════════════════════════════════════════════════════════
            // FAST PATH - MOST COMMON OPCODES INLINED
            // ═══════════════════════════════════════════════════════════════

            // ADD_RRR (0x10) - Most common arithmetic
            if (op_byte == 0x10) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const a = getInt(regs[r.r1]);
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .int_val = b + c };
                _ = a;
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_LOCAL (0x04) - Very common
            if (op_byte == 0x04) {
                const rd = unpackRegs(code[ip]).r1;
                const idx = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                regs[rd] = locals[@min(idx, MAX_LOCALS - 1)];
                self.instructions_executed += 1;
                continue;
            }

            // STORE_LOCAL (0x05)
            if (op_byte == 0x05) {
                const rs = unpackRegs(code[ip]).r1;
                const idx = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                locals[@min(idx, MAX_LOCALS - 1)] = regs[rs];
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_CONST (0x03)
            if (op_byte == 0x03) {
                const rd = unpackRegs(code[ip]).r1;
                const idx = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                regs[rd] = constants[@min(idx, constants.len - 1)];
                self.instructions_executed += 1;
                continue;
            }

            // MOV_RR (0x01)
            if (op_byte == 0x01) {
                const r = unpackRegs(code[ip]);
                ip += 1;
                regs[r.r1] = regs[r.r2];
                self.instructions_executed += 1;
                continue;
            }

            // INC_R (0x1E) - Loop counter increment
            if (op_byte == 0x1E) {
                const rd = unpackRegs(code[ip]).r1;
                ip += 1;
                const val = getInt(regs[rd]);
                regs[rd] = .{ .int_val = val + 1 };
                self.instructions_executed += 1;
                continue;
            }

            // DEC_R (0x1F)
            if (op_byte == 0x1F) {
                const rd = unpackRegs(code[ip]).r1;
                ip += 1;
                const val = getInt(regs[rd]);
                regs[rd] = .{ .int_val = val - 1 };
                self.instructions_executed += 1;
                continue;
            }

            // CMP_RR (0x20) - Comparison
            if (op_byte == 0x20) {
                const r = unpackRegs(code[ip]);
                ip += 1;
                const a = getInt(regs[r.r1]);
                const b = getInt(regs[r.r2]);
                flags.* = Flags.fromCmp(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // JLT (0x43) - Jump if less than
            if (op_byte == 0x43) {
                const addr = unpackU16(code[ip], code[ip + 1]);
                ip += 2;
                if (flags.lt) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JLE (0x44)
            if (op_byte == 0x44) {
                const addr = unpackU16(code[ip], code[ip + 1]);
                ip += 2;
                if (flags.le()) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JMP (0x40)
            if (op_byte == 0x40) {
                const addr = unpackU16(code[ip], code[ip + 1]);
                ip = addr;
                self.instructions_executed += 1;
                continue;
            }

            // JZ_R (0x41)
            if (op_byte == 0x41) {
                const rs = unpackRegs(code[ip]).r1;
                const addr = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                if (!getBool(regs[rs])) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JNZ_R (0x42)
            if (op_byte == 0x42) {
                const rs = unpackRegs(code[ip]).r1;
                const addr = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                if (getBool(regs[rs])) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // SUB_RRR (0x11)
            if (op_byte == 0x11) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .int_val = b - c };
                self.instructions_executed += 1;
                continue;
            }

            // MUL_RRR (0x12)
            if (op_byte == 0x12) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .int_val = b * c };
                self.instructions_executed += 1;
                continue;
            }

            // DIV_RRR (0x13)
            if (op_byte == 0x13) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                if (c == 0) return VMError.DivisionByZero;
                regs[r.r1] = .{ .int_val = @divTrunc(b, c) };
                self.instructions_executed += 1;
                continue;
            }

            // LT_RRR (0x22)
            if (op_byte == 0x22) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .bool_val = b < c };
                self.instructions_executed += 1;
                continue;
            }

            // LE_RRR (0x23)
            if (op_byte == 0x23) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .bool_val = b <= c };
                self.instructions_executed += 1;
                continue;
            }

            // GT_RRR (0x24)
            if (op_byte == 0x24) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .bool_val = b > c };
                self.instructions_executed += 1;
                continue;
            }

            // GE_RRR (0x25)
            if (op_byte == 0x25) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .bool_val = b >= c };
                self.instructions_executed += 1;
                continue;
            }

            // EQ_RRR (0x26)
            if (op_byte == 0x26) {
                const r = unpackRegs(code[ip]);
                const rs2 = unpackRegs(code[ip + 1]).r1;
                ip += 2;
                const b = getInt(regs[r.r2]);
                const c = getInt(regs[rs2]);
                regs[r.r1] = .{ .bool_val = b == c };
                self.instructions_executed += 1;
                continue;
            }

            // MOV_RI (0x02) - Load immediate
            if (op_byte == 0x02) {
                const rd = unpackRegs(code[ip]).r1;
                const imm = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                regs[rd] = .{ .int_val = @as(i64, imm) };
                self.instructions_executed += 1;
                continue;
            }

            // ADD_RRI (0x18)
            if (op_byte == 0x18) {
                const r = unpackRegs(code[ip]);
                const imm = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                const val = getInt(regs[r.r2]);
                regs[r.r1] = .{ .int_val = val + @as(i64, imm) };
                self.instructions_executed += 1;
                continue;
            }

            // INC_CMP_JLT (0xA0) - Superinstruction for loops
            if (op_byte == 0xA0) {
                const r = unpackRegs(code[ip]);
                const addr = unpackU16(code[ip + 1], code[ip + 2]);
                ip += 3;
                // Increment Rd
                const rd_val = getInt(regs[r.r1]) + 1;
                regs[r.r1] = .{ .int_val = rd_val };
                // Compare with Rs and jump if less
                const rs_val = getInt(regs[r.r2]);
                if (rd_val < rs_val) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_PHI (0x90)
            if (op_byte == 0x90) {
                const rd = unpackRegs(code[ip]).r1;
                ip += 1;
                regs[rd] = .{ .float_val = PHI };
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_PI (0x91)
            if (op_byte == 0x91) {
                const rd = unpackRegs(code[ip]).r1;
                ip += 1;
                regs[rd] = .{ .float_val = PI };
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_E (0x92)
            if (op_byte == 0x92) {
                const rd = unpackRegs(code[ip]).r1;
                ip += 1;
                regs[rd] = .{ .float_val = E };
                self.instructions_executed += 1;
                continue;
            }

            // NOP (0x00)
            if (op_byte == 0x00) {
                self.instructions_executed += 1;
                continue;
            }

            // RET (0x4B)
            if (op_byte == 0x4B) {
                if (self.fp == 0) {
                    self.halted = true;
                } else {
                    self.fp -= 1;
                    const frame = self.call_stack[self.fp];
                    ip = frame.return_addr;
                    // Restore registers except R0 (return value)
                    const ret_val = regs[0];
                    regs.* = frame.saved_regs;
                    regs[0] = ret_val;
                }
                self.instructions_executed += 1;
                continue;
            }

            // HALT (0x4D)
            if (op_byte == 0x4D) {
                self.halted = true;
                self.instructions_executed += 1;
                continue;
            }

            // CALL (0x49)
            if (op_byte == 0x49) {
                const addr = unpackU16(code[ip], code[ip + 1]);
                ip += 2;
                if (self.fp >= CALL_STACK_SIZE) return VMError.CallStackOverflow;
                self.call_stack[self.fp] = .{
                    .return_addr = ip,
                    .saved_regs = regs.*,
                };
                self.fp += 1;
                ip = addr;
                self.instructions_executed += 1;
                continue;
            }

            // CALL_NATIVE (0x4E)
            if (op_byte == 0x4E) {
                const native_id = unpackU16(code[ip], code[ip + 1]);
                ip += 2;
                // R0 contains the argument, result goes to R0
                const arg = regs[0];
                regs[0] = try self.callNative(native_id, arg);
                self.instructions_executed += 1;
                continue;
            }

            // Unknown opcode
            return VMError.InvalidOpcode;
        }

        self.ip = ip;
        self.end_time = std.time.nanoTimestamp();

        // Return R0 as result
        return self.regs[0];
    }

    /// Get execution time in nanoseconds
    pub fn getExecutionTimeNs(self: *Self) u64 {
        return @intCast(@max(0, self.end_time - self.start_time));
    }

    /// Get instructions per second
    pub fn getIPS(self: *Self) f64 {
        const time_ns = self.getExecutionTimeNs();
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / (@as(f64, @floatFromInt(time_ns)) / 1_000_000_000.0);
    }

    /// Call native function by ID
    fn callNative(self: *Self, native_id: u16, arg: Value) VMError!Value {
        _ = self;
        return switch (native_id) {
            @intFromEnum(NativeId.print) => {
                // Print the argument
                switch (arg) {
                    .nil => std.debug.print("nil\n", .{}),
                    .bool_val => |v| std.debug.print("{}\n", .{v}),
                    .int_val => |v| std.debug.print("{}\n", .{v}),
                    .float_val => |v| std.debug.print("{d}\n", .{v}),
                    .string_val => |v| std.debug.print("{s}\n", .{v}),
                    .trit_val => |v| {
                        const symbol: []const u8 = if (v > 0) "T" else if (v < 0) "F" else "U";
                        std.debug.print("{s}\n", .{symbol});
                    },
                    .tryte_val => |v| std.debug.print("0t{d}\n", .{v}),
                    else => std.debug.print("<value>\n", .{}),
                }
                return .{ .nil = {} };
            },
            @intFromEnum(NativeId.len) => {
                return switch (arg) {
                    .string_val => |v| .{ .int_val = @intCast(v.len) },
                    .array_val => |v| .{ .int_val = @intCast(v.items.len) },
                    else => .{ .int_val = 0 },
                };
            },
            @intFromEnum(NativeId.sqrt) => {
                const val = getFloat(arg);
                return .{ .float_val = @sqrt(val) };
            },
            @intFromEnum(NativeId.sin) => {
                const val = getFloat(arg);
                return .{ .float_val = @sin(val) };
            },
            @intFromEnum(NativeId.cos) => {
                const val = getFloat(arg);
                return .{ .float_val = @cos(val) };
            },
            else => VMError.UnknownNative,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RegVM init" {
    var vm = try RegVM.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expect(!vm.halted);
    try std.testing.expectEqual(@as(u32, 0), vm.ip);
}

test "RegVM simple add" {
    var vm = try RegVM.init(std.testing.allocator);
    defer vm.deinit();

    // Program: R0 = 5, R1 = 3, R2 = R0 + R1, HALT
    const code = [_]u8{
        0x02, 0x00, 0x05, 0x00, // MOV_RI R0, 5
        0x02, 0x10, 0x03, 0x00, // MOV_RI R1, 3
        0x10, 0x20, 0x10, // ADD_RRR R2, R0, R1
        0x01, 0x02, // MOV_RR R0, R2 (result to R0)
        0x4D, // HALT
    };

    const constants = [_]Value{};
    vm.load(&code, &constants);

    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 8), result.int_val);
}

test "RegVM loop" {
    var vm = try RegVM.init(std.testing.allocator);
    defer vm.deinit();

    // Program: sum = 0; for i = 0; i < 10; i++ { sum += i }
    // R0 = sum, R1 = i, R2 = limit (10)
    const code = [_]u8{
        0x02, 0x00, 0x00, 0x00, // MOV_RI R0, 0 (sum)
        0x02, 0x10, 0x00, 0x00, // MOV_RI R1, 0 (i)
        0x02, 0x20, 0x0A, 0x00, // MOV_RI R2, 10 (limit)
        // loop_start (offset 12):
        0x10, 0x00, 0x10, // ADD_RRR R0, R0, R1 (sum += i)
        0x1E, 0x10, // INC_R R1 (i++)
        0x20, 0x12, // CMP_RR R1, R2
        0x43, 0x0C, 0x00, // JLT loop_start (12)
        0x4D, // HALT
    };

    const constants = [_]Value{};
    vm.load(&code, &constants);

    const result = try vm.run();
    // sum of 0..9 = 45
    try std.testing.expectEqual(@as(i64, 45), result.int_val);
}

test "RegVM flags" {
    var vm = try RegVM.init(std.testing.allocator);
    defer vm.deinit();

    // Test CMP and flags
    vm.regs[0] = .{ .int_val = 5 };
    vm.regs[1] = .{ .int_val = 10 };

    const flags = Flags.fromCmp(5, 10);
    try std.testing.expect(flags.lt);
    try std.testing.expect(!flags.eq);
    try std.testing.expect(!flags.gt);
    try std.testing.expect(flags.le());
    try std.testing.expect(!flags.ge());
}
