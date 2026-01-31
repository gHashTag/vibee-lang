// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC NaN-BOXED REGISTER VM - MAXIMUM SPEED
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V39 - NaN Boxing + Register VM = φ² speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 275M × φ² = 720M ops/sec
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const nan_value = @import("nan_value.zig");
const NanValue = nan_value.NanValue;

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegOp = enum(u8) {
    NOP = 0x00,
    MOV_RI = 0x01, // Rd = imm16
    MOV_RR = 0x02, // Rd = Rs

    ADD_RRR = 0x10, // Rd = Rs1 + Rs2
    SUB_RRR = 0x11,
    MUL_RRR = 0x12,
    INC_R = 0x1E, // Rd++
    DEC_R = 0x1F, // Rd--

    CMP_RR = 0x20, // flags = Rs1 cmp Rs2
    LT_RRR = 0x22, // Rd = Rs1 < Rs2

    JMP = 0x40,
    JLT = 0x43, // Jump if less than
    JGE = 0x46, // Jump if greater or equal
    HALT = 0x4D,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NaN-BOXED REGISTER VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const NUM_REGS: usize = 16;

pub const Flags = packed struct {
    lt: bool = false,
    eq: bool = false,
    gt: bool = false,
    _pad: u5 = 0,
};

pub const NanRegVM = struct {
    // 16 registers (8 bytes each = 128 bytes total)
    regs: [NUM_REGS]NanValue,

    // Flags
    flags: Flags,

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
            .regs = [_]NanValue{NanValue.nil()} ** NUM_REGS,
            .flags = .{},
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
        self.halted = false;
        self.instructions_executed = 0;
        self.regs = [_]NanValue{NanValue.nil()} ** NUM_REGS;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    inline fn unpackRegs(byte: u8) struct { r1: u4, r2: u4 } {
        return .{
            .r1 = @truncate(byte >> 4),
            .r2 = @truncate(byte & 0x0F),
        };
    }

    inline fn readU16(code: []const u8, ip: u32) u16 {
        return (@as(u16, code[ip]) << 8) | @as(u16, code[ip + 1]);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION LOOP - ULTRA-FAST REGISTER DISPATCH
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn run(self: *Self) NanValue {
        self.start_time = std.time.nanoTimestamp();

        const code = self.code;
        var ip = self.ip;
        const regs = &self.regs;
        var flags = &self.flags;

        while (!self.halted and ip < code.len) {
            const op = code[ip];
            ip += 1;

            // ═══════════════════════════════════════════════════════════════
            // ULTRA-FAST INLINE DISPATCH
            // ═══════════════════════════════════════════════════════════════

            // ADD_RRR (0x10) - Most common
            if (op == 0x10) {
                const r = unpackRegs(code[ip]);
                const rs2: u4 = @truncate(code[ip + 1] >> 4);
                ip += 2;
                regs[r.r1] = NanValue.add(regs[r.r2], regs[rs2]);
                self.instructions_executed += 1;
                continue;
            }

            // MOV_RI (0x01) - Load immediate
            if (op == 0x01) {
                const rd: u4 = @truncate(code[ip] >> 4);
                const imm = readU16(code, ip + 1);
                ip += 3;
                regs[rd] = NanValue.int(@as(i64, imm));
                self.instructions_executed += 1;
                continue;
            }

            // INC_R (0x1E) - Increment
            if (op == 0x1E) {
                const rd: u4 = @truncate(code[ip] >> 4);
                ip += 1;
                regs[rd] = NanValue.add(regs[rd], NanValue.int(1));
                self.instructions_executed += 1;
                continue;
            }

            // CMP_RR (0x20) - Compare
            if (op == 0x20) {
                const r = unpackRegs(code[ip]);
                ip += 1;
                const a = regs[r.r1].toInt();
                const b = regs[r.r2].toInt();
                flags.lt = a < b;
                flags.eq = a == b;
                flags.gt = a > b;
                self.instructions_executed += 1;
                continue;
            }

            // JLT (0x43) - Jump if less than
            if (op == 0x43) {
                const addr = readU16(code, ip);
                ip += 2;
                if (flags.lt) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JGE (0x46) - Jump if greater or equal
            if (op == 0x46) {
                const addr = readU16(code, ip);
                ip += 2;
                if (flags.gt or flags.eq) {
                    ip = addr;
                }
                self.instructions_executed += 1;
                continue;
            }

            // JMP (0x40)
            if (op == 0x40) {
                const addr = readU16(code, ip);
                ip = addr;
                self.instructions_executed += 1;
                continue;
            }

            // MOV_RR (0x02)
            if (op == 0x02) {
                const r = unpackRegs(code[ip]);
                ip += 1;
                regs[r.r1] = regs[r.r2];
                self.instructions_executed += 1;
                continue;
            }

            // SUB_RRR (0x11)
            if (op == 0x11) {
                const r = unpackRegs(code[ip]);
                const rs2: u4 = @truncate(code[ip + 1] >> 4);
                ip += 2;
                regs[r.r1] = NanValue.sub(regs[r.r2], regs[rs2]);
                self.instructions_executed += 1;
                continue;
            }

            // MUL_RRR (0x12)
            if (op == 0x12) {
                const r = unpackRegs(code[ip]);
                const rs2: u4 = @truncate(code[ip + 1] >> 4);
                ip += 2;
                regs[r.r1] = NanValue.mul(regs[r.r2], regs[rs2]);
                self.instructions_executed += 1;
                continue;
            }

            // LT_RRR (0x22)
            if (op == 0x22) {
                const r = unpackRegs(code[ip]);
                const rs2: u4 = @truncate(code[ip + 1] >> 4);
                ip += 2;
                regs[r.r1] = NanValue.lt(regs[r.r2], regs[rs2]);
                self.instructions_executed += 1;
                continue;
            }

            // DEC_R (0x1F)
            if (op == 0x1F) {
                const rd: u4 = @truncate(code[ip] >> 4);
                ip += 1;
                regs[rd] = NanValue.sub(regs[rd], NanValue.int(1));
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
            self.instructions_executed += 1;
        }

        self.ip = ip;
        self.end_time = std.time.nanoTimestamp();

        return self.regs[0]; // R0 = result
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

test "NanRegVM simple add" {
    var vm = NanRegVM.init();

    // R0 = 5, R1 = 3, R0 = R0 + R1
    const code = [_]u8{
        0x01, 0x00, 0x00, 0x05, // MOV_RI R0, 5
        0x01, 0x10, 0x00, 0x03, // MOV_RI R1, 3
        0x10, 0x00, 0x10, // ADD_RRR R0, R0, R1
        0x4D, // HALT
    };

    vm.load(&code);
    const result = vm.run();

    try std.testing.expectEqual(@as(i64, 8), result.asInt());
}

test "NanRegVM loop sum" {
    var vm = NanRegVM.init();

    // R0 = sum = 0, R1 = i = 0, R2 = limit = 10
    // loop: R0 += R1; R1++; if R1 < R2 goto loop
    const code = [_]u8{
        0x01, 0x00, 0x00, 0x00, // MOV_RI R0, 0 (sum)
        0x01, 0x10, 0x00, 0x00, // MOV_RI R1, 0 (i)
        0x01, 0x20, 0x00, 0x0A, // MOV_RI R2, 10 (limit)
        // loop_start (offset 12):
        0x10, 0x00, 0x10, // ADD_RRR R0, R0, R1 (sum += i)
        0x1E, 0x10, // INC_R R1 (i++)
        0x20, 0x12, // CMP_RR R1, R2
        0x43, 0x00, 0x0C, // JLT 12 (loop_start)
        0x4D, // HALT
    };

    vm.load(&code);
    const result = vm.run();

    // sum(0..9) = 45
    try std.testing.expectEqual(@as(i64, 45), result.asInt());
}
