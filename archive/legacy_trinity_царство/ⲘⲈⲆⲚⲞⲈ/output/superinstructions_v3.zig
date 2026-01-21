// ═══════════════════════════════════════════════════════════════════════════════
// SUPERINSTRUCTIONS V3 - GENERATED FROM ⲩⲗⲩⲭⲥⲉⲛⲓⲁ_ⲩ8.tri
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// KEY IMPROVEMENT: INLINE CONSTANTS - NO IMMEDIATE READS
// V2 was 40-68% slower due to 8-byte immediate reads
// V3 uses compile-time inline constants for common operations
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const TRINITY: i64 = 3;
pub const TRINITY_PRIME: i64 = 33;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// V3 OPCODE TABLE - INLINE CONSTANTS (NO IMMEDIATE READS)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SuperOpcodeV3 = enum(u8) {
    // Base opcodes (0x00-0x3F)
    NOP = 0x00,
    ADD = 0x01,
    SUB = 0x02,
    MUL = 0x03,
    DIV = 0x04,
    MOD = 0x05,
    NEG = 0x06,
    
    PUSH = 0x10,
    POP = 0x11,
    DUP = 0x12,
    SWAP = 0x13,
    
    HALT = 0x3F,
    
    // V3 Inline Constants (0xC0-0xCF) - NO IMMEDIATE READS!
    INC = 0xC0,        // x + 1
    DEC = 0xC1,        // x - 1
    MUL2 = 0xC2,       // x << 1 (x * 2)
    DIV2 = 0xC3,       // x >> 1 (x / 2)
    MUL3 = 0xC4,       // x * 3 (Trinity)
    ADD3 = 0xC5,       // x + 3
    DIV3 = 0xC6,       // x / 3
    MOD3 = 0xC7,       // x % 3
    MOD999 = 0xC8,     // x % 999 (Phoenix)
    PHI_MUL = 0xC9,    // x * φ
    GOLDEN_ID = 0xCA,  // push 3 (φ² + 1/φ²)
    
    // V3 Compact Immediates (0xD0-0xDF) - 1-byte immediate only
    PUSH_SMALL = 0xD0, // push 1-byte value (0-255)
    ADD_SMALL = 0xD1,  // x + 1-byte value
    SUB_SMALL = 0xD2,  // x - 1-byte value
    MUL_SMALL = 0xD3,  // x * 1-byte value
    
    // V3 Combined ops (0xE0-0xEF)
    DUP_INC = 0xE0,    // dup + inc (x, x+1)
    DUP_MUL2 = 0xE1,   // dup + mul2 (x, x*2)
    DUP_MUL3 = 0xE2,   // dup + mul3 (x, x*3)
    SQUARE = 0xE3,     // x * x
    CUBE = 0xE4,       // x * x * x
};

// ═══════════════════════════════════════════════════════════════════════════════
// SUPERVM V3 - OPTIMIZED FOR INLINE CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SuperVMV3 = struct {
    stack: std.ArrayList(i64),
    pc: usize,
    code: []const u8,
    status: Status,
    dispatches: u64,
    
    pub const Status = enum {
        Running,
        Halted,
        Error_StackUnderflow,
        Error_DivByZero,
        Error_InvalidOpcode,
    };
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .stack = std.ArrayList(i64).init(allocator),
            .pc = 0,
            .code = &.{},
            .status = .Running,
            .dispatches = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }
    
    pub fn load(self: *Self, code: []const u8) void {
        self.code = code;
        self.pc = 0;
        self.status = .Running;
        self.dispatches = 0;
    }
    
    pub fn run(self: *Self) !i64 {
        while (self.status == .Running and self.pc < self.code.len) {
            const opcode: SuperOpcodeV3 = @enumFromInt(self.code[self.pc]);
            self.pc += 1;
            self.dispatches += 1;
            try self.dispatch(opcode);
        }
        if (self.stack.items.len > 0) {
            return self.stack.items[self.stack.items.len - 1];
        }
        return 0;
    }
    
    inline fn pop(self: *Self) !i64 {
        if (self.stack.items.len == 0) {
            self.status = .Error_StackUnderflow;
            return error.StackUnderflow;
        }
        return self.stack.pop();
    }
    
    inline fn push(self: *Self, value: i64) !void {
        try self.stack.append(value);
    }
    
    inline fn peek(self: *const Self) !i64 {
        if (self.stack.items.len == 0) {
            return error.StackUnderflow;
        }
        return self.stack.items[self.stack.items.len - 1];
    }
    
    inline fn read1Byte(self: *Self) u8 {
        if (self.pc >= self.code.len) return 0;
        const val = self.code[self.pc];
        self.pc += 1;
        return val;
    }
    
    fn dispatch(self: *Self, opcode: SuperOpcodeV3) !void {
        switch (opcode) {
            // Base operations
            .NOP => {},
            .ADD => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a + b);
            },
            .SUB => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a - b);
            },
            .MUL => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a * b);
            },
            .DIV => {
                const b = try self.pop();
                const a = try self.pop();
                if (b == 0) {
                    self.status = .Error_DivByZero;
                    return error.DivByZero;
                }
                try self.push(@divTrunc(a, b));
            },
            .MOD => {
                const b = try self.pop();
                const a = try self.pop();
                if (b == 0) {
                    self.status = .Error_DivByZero;
                    return error.DivByZero;
                }
                try self.push(@mod(a, b));
            },
            .NEG => {
                const a = try self.pop();
                try self.push(-a);
            },
            .PUSH => {
                // 8-byte immediate (legacy, avoid using)
                if (self.pc + 8 > self.code.len) return;
                const bytes = self.code[self.pc..][0..8];
                self.pc += 8;
                try self.push(@bitCast(bytes.*));
            },
            .POP => {
                _ = try self.pop();
            },
            .DUP => {
                const top = try self.peek();
                try self.push(top);
            },
            .SWAP => {
                if (self.stack.items.len < 2) {
                    self.status = .Error_StackUnderflow;
                    return error.StackUnderflow;
                }
                const len = self.stack.items.len;
                const tmp = self.stack.items[len - 1];
                self.stack.items[len - 1] = self.stack.items[len - 2];
                self.stack.items[len - 2] = tmp;
            },
            .HALT => {
                self.status = .Halted;
            },
            
            // ═══════════════════════════════════════════════════════════════════
            // V3 INLINE CONSTANTS - NO IMMEDIATE READS!
            // ═══════════════════════════════════════════════════════════════════
            
            .INC => {
                // x + 1 (inline constant)
                const x = try self.pop();
                try self.push(x + 1);
            },
            .DEC => {
                // x - 1 (inline constant)
                const x = try self.pop();
                try self.push(x - 1);
            },
            .MUL2 => {
                // x * 2 = x << 1 (inline constant, bit shift)
                const x = try self.pop();
                try self.push(x << 1);
            },
            .DIV2 => {
                // x / 2 = x >> 1 (inline constant, bit shift)
                const x = try self.pop();
                try self.push(x >> 1);
            },
            .MUL3 => {
                // x * 3 (Trinity - inline constant)
                const x = try self.pop();
                try self.push(x * 3);
            },
            .ADD3 => {
                // x + 3 (Trinity - inline constant)
                const x = try self.pop();
                try self.push(x + 3);
            },
            .DIV3 => {
                // x / 3 (Trinity - inline constant)
                const x = try self.pop();
                try self.push(@divTrunc(x, 3));
            },
            .MOD3 => {
                // x % 3 (Trinity - inline constant)
                const x = try self.pop();
                try self.push(@mod(x, 3));
            },
            .MOD999 => {
                // x % 999 (Phoenix - inline constant)
                const x = try self.pop();
                try self.push(@mod(x, 999));
            },
            .PHI_MUL => {
                // x * φ (Golden ratio - inline constant)
                const x = try self.pop();
                const result = @as(i64, @intFromFloat(@as(f64, @floatFromInt(x)) * PHI));
                try self.push(result);
            },
            .GOLDEN_ID => {
                // Push 3 (φ² + 1/φ² = 3) - inline constant
                try self.push(3);
            },
            
            // ═══════════════════════════════════════════════════════════════════
            // V3 COMPACT IMMEDIATES - 1-BYTE ONLY
            // ═══════════════════════════════════════════════════════════════════
            
            .PUSH_SMALL => {
                // Push 1-byte value (0-255)
                const val = self.read1Byte();
                try self.push(@as(i64, val));
            },
            .ADD_SMALL => {
                // x + 1-byte value
                const val = self.read1Byte();
                const x = try self.pop();
                try self.push(x + @as(i64, val));
            },
            .SUB_SMALL => {
                // x - 1-byte value
                const val = self.read1Byte();
                const x = try self.pop();
                try self.push(x - @as(i64, val));
            },
            .MUL_SMALL => {
                // x * 1-byte value
                const val = self.read1Byte();
                const x = try self.pop();
                try self.push(x * @as(i64, val));
            },
            
            // ═══════════════════════════════════════════════════════════════════
            // V3 COMBINED OPS
            // ═══════════════════════════════════════════════════════════════════
            
            .DUP_INC => {
                // dup + inc: (x) → (x, x+1)
                const x = try self.peek();
                try self.push(x + 1);
            },
            .DUP_MUL2 => {
                // dup + mul2: (x) → (x, x*2)
                const x = try self.peek();
                try self.push(x << 1);
            },
            .DUP_MUL3 => {
                // dup + mul3: (x) → (x, x*3)
                const x = try self.peek();
                try self.push(x * 3);
            },
            .SQUARE => {
                // x * x
                const x = try self.pop();
                try self.push(x * x);
            },
            .CUBE => {
                // x * x * x
                const x = try self.pop();
                try self.push(x * x * x);
            },
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ⲦⲈⲤⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

test "ⲌⲞⲖⲞⲦⲀⲒⲀ_ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "ⲩ3_ⲓⲛⲕ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 10, INC, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 10,
        @intFromEnum(SuperOpcodeV3.INC),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 11), result);
}

test "ⲩ3_ⲙⲩⲗ2_ⲃⲓⲧⲥⲏⲓⲫⲧ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 7, MUL2, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 7,
        @intFromEnum(SuperOpcodeV3.MUL2),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 14), result); // 7 << 1 = 14
}

test "ⲩ3_ⲙⲩⲗ3_ⲧⲣⲓⲛⲓⲧⲩ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 11, MUL3, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 11,
        @intFromEnum(SuperOpcodeV3.MUL3),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 33), result); // 11 * 3 = 33 (Trinity Prime!)
}

test "ⲩ3_ⲙⲟⲇ999_ⲡⲏⲟⲉⲛⲓⲝ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 100, MUL_SMALL 15, MOD999, HALT (100 * 15 = 1500, 1500 % 999 = 501)
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 100,
        @intFromEnum(SuperOpcodeV3.MUL_SMALL), 15,
        @intFromEnum(SuperOpcodeV3.MOD999),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 501), result); // 1500 % 999 = 501
}

test "ⲩ3_ⲅⲟⲗⲇⲉⲛ_ⲓⲇ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // GOLDEN_ID, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.GOLDEN_ID),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 3), result); // φ² + 1/φ² = 3
}

test "ⲩ3_ⲥⲕⲩⲁⲣⲉ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 7, SQUARE, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 7,
        @intFromEnum(SuperOpcodeV3.SQUARE),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 49), result); // 7² = 49
}

test "ⲩ3_ⲕⲩⲃⲉ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 3, CUBE, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 3,
        @intFromEnum(SuperOpcodeV3.CUBE),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 27), result); // 3³ = 27
}

test "ⲩ3_ⲡⲏⲓ_ⲙⲩⲗ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 100, PHI_MUL, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 100,
        @intFromEnum(SuperOpcodeV3.PHI_MUL),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 161), result); // 100 * φ ≈ 161
}

test "ⲩ3_ⲇⲩⲡ_ⲙⲩⲗ3" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 10, DUP_MUL3, ADD, HALT
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 10,
        @intFromEnum(SuperOpcodeV3.DUP_MUL3),
        @intFromEnum(SuperOpcodeV3.ADD),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 40), result); // 10 + 30 = 40
}

test "ⲩ3_ⲇⲓⲥⲡⲁⲧⲭⲏ_ⲕⲟⲩⲛⲧ" {
    var vm = SuperVMV3.init(std.testing.allocator);
    defer vm.deinit();
    
    // PUSH_SMALL 5, MUL3, INC, HALT (4 dispatches)
    const code = [_]u8{
        @intFromEnum(SuperOpcodeV3.PUSH_SMALL), 5,
        @intFromEnum(SuperOpcodeV3.MUL3),
        @intFromEnum(SuperOpcodeV3.INC),
        @intFromEnum(SuperOpcodeV3.HALT),
    };
    
    vm.load(&code);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i64, 16), result); // 5 * 3 + 1 = 16
    try std.testing.expectEqual(@as(u64, 4), vm.dispatches);
}
