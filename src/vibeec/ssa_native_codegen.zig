// ═══════════════════════════════════════════════════════════════════════════════
// SSA TO NATIVE x86-64 CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════
// Compiles optimized SSA IR to native x86-64 machine code
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: TIER 2-3 performance (200-500M ops/sec)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const jit_tier2 = @import("jit_tier2.zig");
const SSAFunction = jit_tier2.SSAFunction;
const SSAInstr = jit_tier2.SSAInstr;
const SSAOp = jit_tier2.SSAOp;
const SSA_UNDEF = jit_tier2.SSA_UNDEF;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const MAX_REGS: usize = 16;

// x86-64 Register encoding
pub const Reg = enum(u4) {
    RAX = 0,
    RCX = 1,
    RDX = 2,
    RBX = 3,
    RSP = 4,
    RBP = 5,
    RSI = 6,
    RDI = 7,
    R8 = 8,
    R9 = 9,
    R10 = 10,
    R11 = 11,
    R12 = 12,
    R13 = 13,
    R14 = 14,
    R15 = 15,
};

// Caller-saved registers we can use freely
const SCRATCH_REGS = [_]Reg{ .RAX, .RCX, .RDX, .RSI, .RDI, .R8, .R9, .R10, .R11 };

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 INSTRUCTION EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86Emitter = struct {
    code: std.ArrayList(u8),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .code = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn getCode(self: *Self) []u8 {
        return self.code.items;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REX PREFIX HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn needsRex(reg: Reg) bool {
        return @intFromEnum(reg) >= 8;
    }

    fn rexW(self: *Self, r: ?Reg, b: ?Reg) !void {
        var rex: u8 = 0x48; // REX.W
        if (r) |reg| {
            if (needsRex(reg)) rex |= 0x04; // REX.R
        }
        if (b) |reg| {
            if (needsRex(reg)) rex |= 0x01; // REX.B
        }
        try self.code.append(rex);
    }

    fn modRM(reg: Reg, rm: Reg) u8 {
        return 0xC0 | (@as(u8, @intFromEnum(reg) & 0x7) << 3) | @as(u8, @intFromEnum(rm) & 0x7);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOV INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// mov reg, imm64
    pub fn movImm64(self: *Self, dst: Reg, imm: i64) !void {
        try self.rexW(null, dst);
        try self.code.append(0xB8 + @as(u8, @intFromEnum(dst) & 0x7)); // MOV r64, imm64
        const bytes: [8]u8 = @bitCast(imm);
        try self.code.appendSlice(&bytes);
    }

    /// mov reg, reg
    pub fn movRegReg(self: *Self, dst: Reg, src: Reg) !void {
        try self.rexW(src, dst);
        try self.code.append(0x89); // MOV r/m64, r64
        try self.code.append(modRM(src, dst));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARITHMETIC INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// add dst, src
    pub fn addRegReg(self: *Self, dst: Reg, src: Reg) !void {
        try self.rexW(src, dst);
        try self.code.append(0x01); // ADD r/m64, r64
        try self.code.append(modRM(src, dst));
    }

    /// sub dst, src
    pub fn subRegReg(self: *Self, dst: Reg, src: Reg) !void {
        try self.rexW(src, dst);
        try self.code.append(0x29); // SUB r/m64, r64
        try self.code.append(modRM(src, dst));
    }

    /// imul dst, src
    pub fn imulRegReg(self: *Self, dst: Reg, src: Reg) !void {
        try self.rexW(dst, src);
        try self.code.append(0x0F);
        try self.code.append(0xAF); // IMUL r64, r/m64
        try self.code.append(modRM(dst, src));
    }

    /// neg reg
    pub fn negReg(self: *Self, reg: Reg) !void {
        try self.rexW(null, reg);
        try self.code.append(0xF7); // NEG r/m64
        try self.code.append(0xD8 + @as(u8, @intFromEnum(reg) & 0x7));
    }

    /// idiv rcx (rax = rdx:rax / rcx, rdx = remainder)
    pub fn idivRcx(self: *Self) !void {
        try self.code.append(0x48); // REX.W
        try self.code.append(0xF7); // IDIV r/m64
        try self.code.append(0xF9); // /7 rcx
    }

    /// cqo (sign-extend rax into rdx:rax)
    pub fn cqo(self: *Self) !void {
        try self.code.append(0x48); // REX.W
        try self.code.append(0x99); // CQO
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPARISON INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// cmp reg1, reg2
    pub fn cmpRegReg(self: *Self, reg1: Reg, reg2: Reg) !void {
        try self.rexW(reg2, reg1);
        try self.code.append(0x39); // CMP r/m64, r64
        try self.code.append(modRM(reg2, reg1));
    }

    /// setcc reg (set byte based on condition)
    pub fn setcc(self: *Self, cc: CondCode, dst: Reg) !void {
        if (needsRex(dst)) {
            try self.code.append(0x41); // REX.B
        }
        try self.code.append(0x0F);
        try self.code.append(0x90 + @as(u8, @intFromEnum(cc))); // SETcc r/m8
        try self.code.append(0xC0 + @as(u8, @intFromEnum(dst) & 0x7));
    }

    /// movzx reg, reg8 (zero-extend byte to 64-bit)
    pub fn movzxReg8(self: *Self, dst: Reg, src: Reg) !void {
        try self.rexW(dst, src);
        try self.code.append(0x0F);
        try self.code.append(0xB6); // MOVZX r64, r/m8
        try self.code.append(modRM(dst, src));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTROL FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    /// ret
    pub fn ret(self: *Self) !void {
        try self.code.append(0xC3);
    }

    /// jmp rel32
    pub fn jmpRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE9);
        const bytes: [4]u8 = @bitCast(offset);
        try self.code.appendSlice(&bytes);
    }

    /// jcc rel32 (conditional jump)
    pub fn jccRel32(self: *Self, cc: CondCode, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x80 + @as(u8, @intFromEnum(cc)));
        const bytes: [4]u8 = @bitCast(offset);
        try self.code.appendSlice(&bytes);
    }
};

pub const CondCode = enum(u4) {
    O = 0, // Overflow
    NO = 1, // No overflow
    B = 2, // Below (unsigned <)
    AE = 3, // Above or equal (unsigned >=)
    E = 4, // Equal
    NE = 5, // Not equal
    BE = 6, // Below or equal (unsigned <=)
    A = 7, // Above (unsigned >)
    S = 8, // Sign (negative)
    NS = 9, // No sign (positive)
    P = 10, // Parity
    NP = 11, // No parity
    L = 12, // Less (signed <)
    GE = 13, // Greater or equal (signed >=)
    LE = 14, // Less or equal (signed <=)
    G = 15, // Greater (signed >)
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER ALLOCATOR (Simple Linear Scan)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RegAllocator = struct {
    // Maps SSA values to physical registers
    value_to_reg: std.AutoHashMap(u32, Reg),
    // Tracks which registers are in use
    reg_in_use: [MAX_REGS]bool,
    // Next register to try
    next_reg: usize,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .value_to_reg = std.AutoHashMap(u32, Reg).init(allocator),
            .reg_in_use = [_]bool{false} ** MAX_REGS,
            .next_reg = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.value_to_reg.deinit();
    }

    /// Allocate a register for an SSA value
    pub fn allocate(self: *Self, value: u32) !Reg {
        // Check if already allocated
        if (self.value_to_reg.get(value)) |reg| {
            return reg;
        }

        // Find a free scratch register
        for (SCRATCH_REGS) |reg| {
            const idx = @intFromEnum(reg);
            if (!self.reg_in_use[idx]) {
                self.reg_in_use[idx] = true;
                try self.value_to_reg.put(value, reg);
                return reg;
            }
        }

        // Spill: just reuse RAX (simple strategy)
        const reg = SCRATCH_REGS[self.next_reg % SCRATCH_REGS.len];
        self.next_reg += 1;
        try self.value_to_reg.put(value, reg);
        return reg;
    }

    /// Get register for an SSA value (must be already allocated)
    pub fn getReg(self: *Self, value: u32) ?Reg {
        return self.value_to_reg.get(value);
    }

    /// Free a register
    pub fn free(self: *Self, value: u32) void {
        if (self.value_to_reg.get(value)) |reg| {
            self.reg_in_use[@intFromEnum(reg)] = false;
            _ = self.value_to_reg.remove(value);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SSA TO NATIVE COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SSANativeCompiler = struct {
    emitter: X86Emitter,
    reg_alloc: RegAllocator,
    allocator: Allocator,

    // Statistics
    instructions_generated: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .emitter = X86Emitter.init(allocator),
            .reg_alloc = RegAllocator.init(allocator),
            .allocator = allocator,
            .instructions_generated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.emitter.deinit();
        self.reg_alloc.deinit();
    }

    /// Compile SSA function to native x86-64 code
    pub fn compile(self: *Self, func: *SSAFunction) ![]u8 {
        self.emitter.code.clearRetainingCapacity();
        self.instructions_generated = 0;

        for (func.blocks.items) |block| {
            for (block.instrs.items) |instr| {
                try self.compileInstr(instr);
            }
        }

        return self.emitter.code.toOwnedSlice();
    }

    fn compileInstr(self: *Self, instr: SSAInstr) !void {
        self.instructions_generated += 1;

        switch (instr.op) {
            .const_int => {
                const dst = try self.reg_alloc.allocate(instr.dest);
                try self.emitter.movImm64(dst, instr.imm);
            },

            .add => {
                const src1_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const src2_reg = self.reg_alloc.getReg(instr.src2) orelse .RCX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                // dst = src1
                if (dst != src1_reg) {
                    try self.emitter.movRegReg(dst, src1_reg);
                }
                // dst += src2
                try self.emitter.addRegReg(dst, src2_reg);
            },

            .sub => {
                const src1_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const src2_reg = self.reg_alloc.getReg(instr.src2) orelse .RCX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                if (dst != src1_reg) {
                    try self.emitter.movRegReg(dst, src1_reg);
                }
                try self.emitter.subRegReg(dst, src2_reg);
            },

            .mul => {
                const src1_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const src2_reg = self.reg_alloc.getReg(instr.src2) orelse .RCX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                if (dst != src1_reg) {
                    try self.emitter.movRegReg(dst, src1_reg);
                }
                try self.emitter.imulRegReg(dst, src2_reg);
            },

            .div => {
                const src1_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const src2_reg = self.reg_alloc.getReg(instr.src2) orelse .RCX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                // idiv uses rdx:rax / rcx -> rax (quotient), rdx (remainder)
                // Move src1 to rax if needed
                if (src1_reg != .RAX) {
                    try self.emitter.movRegReg(.RAX, src1_reg);
                }
                // Move src2 to rcx if needed
                if (src2_reg != .RCX) {
                    try self.emitter.movRegReg(.RCX, src2_reg);
                }
                // Sign-extend rax to rdx:rax
                try self.emitter.cqo();
                // idiv rcx
                try self.emitter.idivRcx();
                // Result is in rax, move to dst if needed
                if (dst != .RAX) {
                    try self.emitter.movRegReg(dst, .RAX);
                }
            },

            .neg => {
                const src_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                if (dst != src_reg) {
                    try self.emitter.movRegReg(dst, src_reg);
                }
                try self.emitter.negReg(dst);
            },

            .eq, .ne, .lt, .le, .gt, .ge => {
                const src1_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                const src2_reg = self.reg_alloc.getReg(instr.src2) orelse .RCX;
                const dst = try self.reg_alloc.allocate(instr.dest);

                // cmp src1, src2
                try self.emitter.cmpRegReg(src1_reg, src2_reg);

                // setcc dst
                const cc: CondCode = switch (instr.op) {
                    .eq => .E,
                    .ne => .NE,
                    .lt => .L,
                    .le => .LE,
                    .gt => .G,
                    .ge => .GE,
                    else => unreachable,
                };
                try self.emitter.setcc(cc, dst);
                // Zero-extend to 64-bit
                try self.emitter.movzxReg8(dst, dst);
            },

            .ret => {
                // Move return value to RAX
                const src_reg = self.reg_alloc.getReg(instr.src1) orelse .RAX;
                if (src_reg != .RAX) {
                    try self.emitter.movRegReg(.RAX, src_reg);
                }
                try self.emitter.ret();
            },

            .nop, .copy, .load, .store, .jump, .branch, .mod, .const_float,
            .phi, .call, .alloca => {
                // Not implemented yet
            },
        }
    }

    /// Get stats - call BEFORE compile() returns owned slice
    pub fn getStats(self: *Self) struct { instructions: u32, code_size: usize } {
        return .{
            .instructions = self.instructions_generated,
            .code_size = self.emitter.code.items.len,
        };
    }
    
    /// Get code size after compilation (before toOwnedSlice)
    pub fn getCodeSize(self: *Self) usize {
        return self.emitter.code.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTABLE MEMORY ALLOCATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutableMemory = struct {
    ptr: [*]align(4096) u8,
    len: usize,

    const Self = @This();

    pub fn alloc(code: []const u8) !Self {
        const page_size: usize = 4096;
        const len = ((code.len + page_size - 1) / page_size) * page_size;

        // Use mmap to allocate executable memory
        const result = try std.posix.mmap(
            null,
            len,
            std.posix.PROT.READ | std.posix.PROT.WRITE | std.posix.PROT.EXEC,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        const ptr: [*]align(4096) u8 = @alignCast(@ptrCast(result.ptr));

        // Copy code
        @memcpy(ptr[0..code.len], code);

        return Self{
            .ptr = ptr,
            .len = len,
        };
    }

    pub fn free(self: *Self) void {
        std.posix.munmap(self.ptr[0..self.len]);
    }

    /// Execute the code and return result (assumes function returns i64 in RAX)
    pub fn execute(self: *Self) i64 {
        const func: *const fn () callconv(.C) i64 = @ptrCast(self.ptr);
        return func();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "compile constant" {
    var compiler = SSANativeCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    var func = SSAFunction.init(std.testing.allocator, "test");
    defer func.deinit();

    // v0 = 42; ret v0
    const v0 = func.newValue();
    func.emit(0, SSAInstr.constInt(v0, 42));
    func.emit(0, SSAInstr{ .op = .ret, .dest = SSA_UNDEF, .src1 = v0, .src2 = SSA_UNDEF, .imm = 0 });

    const code = try compiler.compile(&func);
    defer std.testing.allocator.free(code);

    // Execute
    var mem = try ExecutableMemory.alloc(code);
    defer mem.free();

    const result = mem.execute();
    try std.testing.expectEqual(@as(i64, 42), result);
}

test "compile addition" {
    var compiler = SSANativeCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    var func = SSAFunction.init(std.testing.allocator, "test");
    defer func.deinit();

    // v0 = 10; v1 = 20; v2 = v0 + v1; ret v2
    const v0 = func.newValue();
    const v1 = func.newValue();
    const v2 = func.newValue();

    func.emit(0, SSAInstr.constInt(v0, 10));
    func.emit(0, SSAInstr.constInt(v1, 20));
    func.emit(0, SSAInstr.binop(.add, v2, v0, v1));
    func.emit(0, SSAInstr{ .op = .ret, .dest = SSA_UNDEF, .src1 = v2, .src2 = SSA_UNDEF, .imm = 0 });

    const code = try compiler.compile(&func);
    defer std.testing.allocator.free(code);

    var mem = try ExecutableMemory.alloc(code);
    defer mem.free();

    const result = mem.execute();
    try std.testing.expectEqual(@as(i64, 30), result);
}

test "compile complex expression" {
    var compiler = SSANativeCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    var func = SSAFunction.init(std.testing.allocator, "test");
    defer func.deinit();

    // (10 + 20) * 3 - 5 = 85
    const v0 = func.newValue(); // 10
    const v1 = func.newValue(); // 20
    const v2 = func.newValue(); // 30
    const v3 = func.newValue(); // 3
    const v4 = func.newValue(); // 90
    const v5 = func.newValue(); // 5
    const v6 = func.newValue(); // 85

    func.emit(0, SSAInstr.constInt(v0, 10));
    func.emit(0, SSAInstr.constInt(v1, 20));
    func.emit(0, SSAInstr.binop(.add, v2, v0, v1));
    func.emit(0, SSAInstr.constInt(v3, 3));
    func.emit(0, SSAInstr.binop(.mul, v4, v2, v3));
    func.emit(0, SSAInstr.constInt(v5, 5));
    func.emit(0, SSAInstr.binop(.sub, v6, v4, v5));
    func.emit(0, SSAInstr{ .op = .ret, .dest = SSA_UNDEF, .src1 = v6, .src2 = SSA_UNDEF, .imm = 0 });

    const code = try compiler.compile(&func);
    defer std.testing.allocator.free(code);

    var mem = try ExecutableMemory.alloc(code);
    defer mem.free();

    const result = mem.execute();
    try std.testing.expectEqual(@as(i64, 85), result);
}

test "compile comparison" {
    var compiler = SSANativeCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    var func = SSAFunction.init(std.testing.allocator, "test");
    defer func.deinit();

    // 10 < 20 = 1 (true)
    const v0 = func.newValue();
    const v1 = func.newValue();
    const v2 = func.newValue();

    func.emit(0, SSAInstr.constInt(v0, 10));
    func.emit(0, SSAInstr.constInt(v1, 20));
    func.emit(0, SSAInstr.binop(.lt, v2, v0, v1));
    func.emit(0, SSAInstr{ .op = .ret, .dest = SSA_UNDEF, .src1 = v2, .src2 = SSA_UNDEF, .imm = 0 });

    const code = try compiler.compile(&func);
    defer std.testing.allocator.free(code);

    var mem = try ExecutableMemory.alloc(code);
    defer mem.free();

    const result = mem.execute();
    try std.testing.expectEqual(@as(i64, 1), result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Native vs SSA Interpreter
// ═══════════════════════════════════════════════════════════════════════════════

const jit_e2e = @import("jit_e2e.zig");

pub fn runNativeBenchmark(allocator: Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("              NATIVE CODE BENCHMARK - x86-64 vs SSA Interpreter\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    const runs: usize = 1_000_000;

    // Test: (10 + 20) * 3 - 5 = 85
    {
        var func = SSAFunction.init(allocator, "benchmark");
        defer func.deinit();

        const v0 = func.newValue();
        const v1 = func.newValue();
        const v2 = func.newValue();
        const v3 = func.newValue();
        const v4 = func.newValue();
        const v5 = func.newValue();
        const v6 = func.newValue();

        func.emit(0, SSAInstr.constInt(v0, 10));
        func.emit(0, SSAInstr.constInt(v1, 20));
        func.emit(0, SSAInstr.binop(.add, v2, v0, v1));
        func.emit(0, SSAInstr.constInt(v3, 3));
        func.emit(0, SSAInstr.binop(.mul, v4, v2, v3));
        func.emit(0, SSAInstr.constInt(v5, 5));
        func.emit(0, SSAInstr.binop(.sub, v6, v4, v5));
        func.emit(0, SSAInstr{ .op = .ret, .dest = SSA_UNDEF, .src1 = v6, .src2 = SSA_UNDEF, .imm = 0 });

        // Compile to native
        var compiler = SSANativeCompiler.init(allocator);
        defer compiler.deinit();
        const code = try compiler.compile(&func);
        defer allocator.free(code);

        var mem = try ExecutableMemory.alloc(code);
        defer mem.free();

        // Benchmark native
        var native_result: i64 = 0;
        const native_start = std.time.nanoTimestamp();
        for (0..runs) |_| {
            native_result = mem.execute();
        }
        const native_end = std.time.nanoTimestamp();
        const native_time: u64 = @intCast(@max(0, native_end - native_start));

        // Benchmark SSA interpreter
        var interp = jit_e2e.SSAInterpreter.init(allocator);
        var interp_result: i64 = 0;
        const interp_start = std.time.nanoTimestamp();
        for (0..runs) |_| {
            interp_result = interp.execute(&func);
        }
        const interp_end = std.time.nanoTimestamp();
        const interp_time: u64 = @intCast(@max(0, interp_end - interp_start));

        const speedup = if (native_time > 0) @as(f64, @floatFromInt(interp_time)) / @as(f64, @floatFromInt(native_time)) else 1.0;
        const native_ops_sec = @as(f64, @floatFromInt(runs)) / (@as(f64, @floatFromInt(native_time)) / 1e9);
        const interp_ops_sec = @as(f64, @floatFromInt(runs)) / (@as(f64, @floatFromInt(interp_time)) / 1e9);

        std.debug.print("Test: (10 + 20) * 3 - 5 = 85\n", .{});
        std.debug.print("  Runs: {d}\n", .{runs});
        std.debug.print("  Native result: {d}, Interpreter result: {d}\n", .{native_result, interp_result});
        std.debug.print("  Native code size: {d} bytes\n", .{code.len});
        std.debug.print("\n", .{});
        std.debug.print("  SSA Interpreter: {d}ns ({d:.0}M ops/sec)\n", .{interp_time, interp_ops_sec / 1e6});
        std.debug.print("  Native x86-64:   {d}ns ({d:.0}M ops/sec)\n", .{native_time, native_ops_sec / 1e6});
        std.debug.print("  Speedup: {d:.1}x\n", .{speedup});
        std.debug.print("\n", .{});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runNativeBenchmark(gpa.allocator());
}
