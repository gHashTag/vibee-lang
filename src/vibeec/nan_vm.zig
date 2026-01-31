// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC NaN-BOXED VM - ULTRA-FAST VIRTUAL MACHINE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V39 - NaN Boxing VM for φ = 1.618x speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 275M → 445M ops/sec
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const nan_value = @import("nan_value.zig");
const NanValue = nan_value.NanValue;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES (simplified for benchmark)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    NOP = 0x00,
    PUSH_INT = 0x01, // Push immediate integer
    POP = 0x02,
    DUP = 0x03,

    // Arithmetic
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    INC = 0x14, // Increment top of stack

    // Comparison
    LT = 0x20,
    LE = 0x21,
    GT = 0x22,
    GE = 0x23,
    EQ = 0x24,

    // Control flow
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    HALT = 0x4D,

    // Locals
    LOAD_LOCAL = 0x50,
    STORE_LOCAL = 0x51,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NaN-BOXED VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const STACK_SIZE: usize = 4096;
pub const MAX_LOCALS: usize = 256;

pub const NanVM = struct {
    // Stack of NaN-boxed values (8 bytes each)
    stack: [STACK_SIZE]NanValue,
    sp: u32,

    // Locals
    locals: [MAX_LOCALS]NanValue,

    // Code
    code: []const u8,
    ip: u32,

    // State
    halted: bool,

    // Metrics
    instructions_executed: u64,
    start_time: i128,
    end_time: i128,

    const Self = @This();

    pub fn init() Self {
        return .{
            .stack = [_]NanValue{NanValue.nil()} ** STACK_SIZE,
            .sp = 0,
            .locals = [_]NanValue{NanValue.nil()} ** MAX_LOCALS,
            .code = &.{},
            .ip = 0,
            .halted = false,
            .instructions_executed = 0,
            .start_time = 0,
            .end_time = 0,
        };
    }

    pub fn load(self: *Self, code: []const u8) void {
        self.code = code;
        self.ip = 0;
        self.sp = 0;
        self.halted = false;
        self.instructions_executed = 0;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    inline fn push(self: *Self, val: NanValue) void {
        self.stack[self.sp] = val;
        self.sp += 1;
    }

    inline fn pop(self: *Self) NanValue {
        self.sp -= 1;
        return self.stack[self.sp];
    }

    inline fn peek(self: *Self) NanValue {
        return self.stack[self.sp - 1];
    }

    inline fn readU16(self: *Self) u16 {
        const hi = self.code[self.ip];
        const lo = self.code[self.ip + 1];
        self.ip += 2;
        return (@as(u16, hi) << 8) | @as(u16, lo);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION LOOP - ULTRA-FAST
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn run(self: *Self) NanValue {
        self.start_time = std.time.nanoTimestamp();

        const code = self.code;
        var ip = self.ip;
        var sp = self.sp;
        const stack = &self.stack;
        const locals = &self.locals;

        while (!self.halted and ip < code.len) {
            const op = code[ip];
            ip += 1;

            // ═══════════════════════════════════════════════════════════════
            // FAST PATH DISPATCH
            // ═══════════════════════════════════════════════════════════════

            // ADD (0x10) - Most common
            if (op == 0x10) {
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                stack[sp - 1] = NanValue.add(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // PUSH_INT (0x01)
            if (op == 0x01) {
                const val: i64 = @as(i64, @as(i16, @bitCast((@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]))));
                ip += 2;
                stack[sp] = NanValue.int(val);
                sp += 1;
                self.instructions_executed += 1;
                continue;
            }

            // LOAD_LOCAL (0x50)
            if (op == 0x50) {
                const idx = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                stack[sp] = locals[idx];
                sp += 1;
                self.instructions_executed += 1;
                continue;
            }

            // STORE_LOCAL (0x51)
            if (op == 0x51) {
                const idx = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                locals[idx] = stack[sp];
                self.instructions_executed += 1;
                continue;
            }

            // SUB (0x11)
            if (op == 0x11) {
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                stack[sp - 1] = NanValue.sub(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // MUL (0x12)
            if (op == 0x12) {
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                stack[sp - 1] = NanValue.mul(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // LT (0x20)
            if (op == 0x20) {
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                stack[sp - 1] = NanValue.lt(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // LE (0x21)
            if (op == 0x21) {
                const b = stack[sp - 1];
                const a = stack[sp - 2];
                sp -= 1;
                stack[sp - 1] = NanValue.le(a, b);
                self.instructions_executed += 1;
                continue;
            }

            // INC (0x14)
            if (op == 0x14) {
                const a = stack[sp - 1];
                stack[sp - 1] = NanValue.add(a, NanValue.int(1));
                self.instructions_executed += 1;
                continue;
            }

            // JMP (0x40)
            if (op == 0x40) {
                const addr = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip = addr;
                self.instructions_executed += 1;
                continue;
            }

            // JZ (0x41)
            if (op == 0x41) {
                const addr = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                if (!stack[sp].toBool()) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JNZ (0x42)
            if (op == 0x42) {
                const addr = (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
                ip += 2;
                sp -= 1;
                if (stack[sp].toBool()) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // POP (0x02)
            if (op == 0x02) {
                sp -= 1;
                self.instructions_executed += 1;
                continue;
            }

            // DUP (0x03)
            if (op == 0x03) {
                stack[sp] = stack[sp - 1];
                sp += 1;
                self.instructions_executed += 1;
                continue;
            }

            // HALT (0x4D)
            if (op == 0x4D) {
                self.halted = true;
                self.instructions_executed += 1;
                continue;
            }

            // NOP (0x00)
            if (op == 0x00) {
                self.instructions_executed += 1;
                continue;
            }
        }

        self.ip = ip;
        self.sp = sp;
        self.end_time = std.time.nanoTimestamp();

        if (sp > 0) {
            return self.stack[sp - 1];
        }
        return NanValue.nil();
    }

    pub fn getExecutionTimeNs(self: *Self) u64 {
        return @intCast(@max(0, self.end_time - self.start_time));
    }

    pub fn getOpsPerSec(self: *Self) f64 {
        const time_ns = self.getExecutionTimeNs();
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / (@as(f64, @floatFromInt(time_ns)) / 1_000_000_000.0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NanVM simple add" {
    var vm = NanVM.init();

    // 5 + 3 = 8
    const code = [_]u8{
        0x01, 0x00, 0x05, // PUSH_INT 5
        0x01, 0x00, 0x03, // PUSH_INT 3
        0x10, // ADD
        0x4D, // HALT
    };

    vm.load(&code);
    const result = vm.run();

    try std.testing.expectEqual(@as(i64, 8), result.asInt());
}

test "NanVM loop sum" {
    var vm = NanVM.init();

    // sum = 0; for i = 0; i < 10; i++ { sum += i }
    const code = [_]u8{
        // sum = 0 (local 0)
        0x01, 0x00, 0x00, // PUSH_INT 0
        0x51, 0x00, 0x00, // STORE_LOCAL 0

        // i = 0 (local 1)
        0x01, 0x00, 0x00, // PUSH_INT 0
        0x51, 0x00, 0x01, // STORE_LOCAL 1

        // loop_start (offset 12):
        // sum += i
        0x50, 0x00, 0x00, // LOAD_LOCAL 0 (sum)
        0x50, 0x00, 0x01, // LOAD_LOCAL 1 (i)
        0x10, // ADD
        0x51, 0x00, 0x00, // STORE_LOCAL 0 (sum)

        // i++
        0x50, 0x00, 0x01, // LOAD_LOCAL 1 (i)
        0x01, 0x00, 0x01, // PUSH_INT 1
        0x10, // ADD
        0x51, 0x00, 0x01, // STORE_LOCAL 1 (i)

        // if i < 10 goto loop_start
        0x50, 0x00, 0x01, // LOAD_LOCAL 1 (i)
        0x01, 0x00, 0x0A, // PUSH_INT 10
        0x20, // LT
        0x42, 0x00, 0x0C, // JNZ 12

        // push result
        0x50, 0x00, 0x00, // LOAD_LOCAL 0 (sum)
        0x4D, // HALT
    };

    vm.load(&code);
    const result = vm.run();

    // sum(0..9) = 45
    try std.testing.expectEqual(@as(i64, 45), result.asInt());
}
