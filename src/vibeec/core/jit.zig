// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC UNIFIED JIT - SINGLE SOURCE OF TRUTH
// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 JIT compiler for NaN-boxed values
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const value = @import("value.zig");
const vm_mod = @import("vm.zig");

pub const Value = value.Value;
pub const Opcode = vm_mod.Opcode;

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Reg64 = enum(u4) {
    rax = 0,
    rcx = 1,
    rdx = 2,
    rbx = 3,
    rsp = 4,
    rbp = 5,
    rsi = 6,
    rdi = 7,
    r8 = 8,
    r9 = 9,
    r10 = 10,
    r11 = 11,
    r12 = 12,
    r13 = 13,
    r14 = 14,
    r15 = 15,
};

pub const XmmReg = enum(u4) {
    xmm0 = 0,
    xmm1 = 1,
    xmm2 = 2,
    xmm3 = 3,
    xmm4 = 4,
    xmm5 = 5,
    xmm6 = 6,
    xmm7 = 7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 ENCODER
// ═══════════════════════════════════════════════════════════════════════════════

pub const X64Encoder = struct {
    code: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .code = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn getCode(self: *Self) []const u8 {
        return self.code.items;
    }

    pub fn clear(self: *Self) void {
        self.code.clearRetainingCapacity();
    }

    // REX prefix
    inline fn rex(self: *Self, w: bool, r: bool, x: bool, b: bool) !void {
        const byte: u8 = 0x40 |
            (if (w) @as(u8, 0x08) else 0) |
            (if (r) @as(u8, 0x04) else 0) |
            (if (x) @as(u8, 0x02) else 0) |
            (if (b) @as(u8, 0x01) else 0);
        try self.code.append(byte);
    }

    // ModR/M byte
    inline fn modrm(self: *Self, mod: u2, reg: u3, rm: u3) !void {
        try self.code.append((@as(u8, mod) << 6) | (@as(u8, reg) << 3) | @as(u8, rm));
    }

    // MOV reg, imm64
    pub fn movImm64(self: *Self, dst: Reg64, imm: u64) !void {
        const dst_val: u8 = @intFromEnum(dst);
        try self.rex(true, false, false, dst_val >= 8);
        try self.code.append(0xB8 + (dst_val & 0x7));
        try self.code.appendSlice(&@as([8]u8, @bitCast(imm)));
    }

    // MOV reg, reg
    pub fn movReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x89);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // PUSH reg
    pub fn push(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) {
            try self.code.append(0x41);
        }
        try self.code.append(0x50 + (reg_val & 0x7));
    }

    // POP reg
    pub fn pop(self: *Self, reg: Reg64) !void {
        const reg_val: u8 = @intFromEnum(reg);
        if (reg_val >= 8) {
            try self.code.append(0x41);
        }
        try self.code.append(0x58 + (reg_val & 0x7));
    }

    // ADD reg, reg
    pub fn addReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x01);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // SUB reg, reg
    pub fn subReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x29);
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // IMUL reg, reg
    pub fn imulReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, dst_val >= 8, false, src_val >= 8);
        try self.code.append(0x0F);
        try self.code.append(0xAF);
        try self.modrm(3, @truncate(dst_val & 0x7), @truncate(src_val & 0x7));
    }

    // AND reg, reg
    pub fn andReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x21); // AND r/m64, r64
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // OR reg, reg
    pub fn orReg(self: *Self, dst: Reg64, src: Reg64) !void {
        const dst_val = @intFromEnum(dst);
        const src_val = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x09); // OR r/m64, r64
        try self.modrm(3, @truncate(src_val & 0x7), @truncate(dst_val & 0x7));
    }

    // CQO - sign extend rax into rdx:rax
    pub fn cqo(self: *Self) !void {
        try self.rex(true, false, false, false); // REX.W
        try self.code.append(0x99); // CQO
    }

    // IDIV reg - signed divide rdx:rax by reg, result in rax, remainder in rdx
    pub fn idivReg(self: *Self, src: Reg64) !void {
        const src_val = @intFromEnum(src);
        try self.rex(true, false, false, src_val >= 8);
        try self.code.append(0xF7); // IDIV r/m64
        try self.modrm(3, 7, @truncate(src_val & 0x7)); // /7 = IDIV
    }

    // CMP reg, reg
    pub fn cmpReg(self: *Self, a: Reg64, b: Reg64) !void {
        const a_val = @intFromEnum(a);
        const b_val = @intFromEnum(b);
        try self.rex(true, b_val >= 8, false, a_val >= 8);
        try self.code.append(0x39);
        try self.modrm(3, @truncate(b_val & 0x7), @truncate(a_val & 0x7));
    }

    // JMP rel32
    pub fn jmpRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE9);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JE rel32
    pub fn jeRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x84);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JNE rel32
    pub fn jneRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x85);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JL rel32
    pub fn jlRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x8C);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // JG rel32
    pub fn jgRel32(self: *Self, offset: i32) !void {
        try self.code.append(0x0F);
        try self.code.append(0x8F);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // CALL rel32
    pub fn callRel32(self: *Self, offset: i32) !void {
        try self.code.append(0xE8);
        try self.code.appendSlice(&@as([4]u8, @bitCast(offset)));
    }

    // RET
    pub fn ret(self: *Self) !void {
        try self.code.append(0xC3);
    }

    // NOP
    pub fn nop(self: *Self) !void {
        try self.code.append(0x90);
    }

    // MOVSD xmm, xmm (SSE2 double move)
    pub fn movsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x10);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // ADDSD xmm, xmm
    pub fn addsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x58);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // SUBSD xmm, xmm
    pub fn subsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5C);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // MULSD xmm, xmm
    pub fn mulsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x59);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }

    // DIVSD xmm, xmm
    pub fn divsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5E);
        try self.modrm(3, @intFromEnum(dst), @intFromEnum(src));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTABLE MEMORY ALLOCATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutableMemory = struct {
    ptr: [*]align(4096) u8,
    len: usize,

    const Self = @This();

    /// Allocate executable memory using mmap
    pub fn alloc(size: usize) !Self {
        const aligned_size = (size + 4095) & ~@as(usize, 4095); // Page align

        const result = try std.posix.mmap(
            null,
            aligned_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        return Self{
            .ptr = result.ptr,
            .len = aligned_size,
        };
    }

    /// Copy code and make executable
    pub fn copyAndProtect(self: *Self, code: []const u8) !void {
        if (code.len > self.len) return error.CodeTooLarge;

        // Copy code to executable memory
        @memcpy(self.ptr[0..code.len], code);

        // Make executable (remove write, add execute)
        std.posix.mprotect(
            @as([*]align(4096) u8, @alignCast(self.ptr))[0..self.len],
            std.posix.PROT.READ | std.posix.PROT.EXEC,
        ) catch return error.MprotectFailed;
    }

    /// Free executable memory
    pub fn free(self: *Self) void {
        std.posix.munmap(@as([*]align(4096) u8, @alignCast(self.ptr))[0..self.len]);
    }

    /// Get function pointer for execution
    pub fn getFunction(self: *Self, comptime ReturnType: type, comptime ArgsType: type) *const fn (ArgsType) ReturnType {
        return @ptrCast(self.ptr);
    }

    /// Get function pointer (no args, returns i64)
    pub fn getFunctionNoArgs(self: *const Self) *const fn () callconv(.C) i64 {
        return @ptrCast(self.ptr);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NaN-BOXING CONSTANTS FOR JIT
// ═══════════════════════════════════════════════════════════════════════════════

const QNAN: u64 = 0x7FFC_0000_0000_0000;
const TAG_SHIFT: u6 = 45;
const TAG_INT: u64 = @as(u64, 2) << TAG_SHIFT; // 0x0000_4000_0000_0000
const PAYLOAD_MASK: u64 = (@as(u64, 1) << 45) - 1; // 0x1FFF_FFFF_FFFF
const QNAN_INT: u64 = QNAN | TAG_INT; // 0x7FFC_4000_0000_0000

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitCompiler = struct {
    encoder: X64Encoder,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .encoder = X64Encoder.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.encoder.deinit();
    }

    /// Extract int payload from NaN-boxed value in rax -> rax
    /// rax = rax & PAYLOAD_MASK (45-bit signed)
    fn emitExtractInt(self: *Self) !void {
        // mov rcx, PAYLOAD_MASK
        try self.encoder.movImm64(.rcx, PAYLOAD_MASK);
        // and rax, rcx
        try self.encoder.andReg(.rax, .rcx);
    }

    /// Extract int payload from NaN-boxed value in rbx -> rbx
    fn emitExtractIntRbx(self: *Self) !void {
        // mov rcx, PAYLOAD_MASK
        try self.encoder.movImm64(.rcx, PAYLOAD_MASK);
        // and rbx, rcx
        try self.encoder.andReg(.rbx, .rcx);
    }

    /// Pack int in rax back to NaN-boxed format -> rax
    /// rax = QNAN_INT | (rax & PAYLOAD_MASK)
    fn emitPackInt(self: *Self) !void {
        // and rax, PAYLOAD_MASK (ensure only 45 bits)
        try self.encoder.movImm64(.rcx, PAYLOAD_MASK);
        try self.encoder.andReg(.rax, .rcx);
        // or rax, QNAN_INT
        try self.encoder.movImm64(.rcx, QNAN_INT);
        try self.encoder.orReg(.rax, .rcx);
    }

    /// Compile bytecode to x86-64 machine code
    pub fn compile(self: *Self, bytecode: []const u8, constants: []const Value) ![]const u8 {
        self.encoder.clear();

        // Prologue
        try self.encoder.push(.rbp);
        try self.encoder.movReg(.rbp, .rsp);

        var ip: usize = 0;
        while (ip < bytecode.len) {
            const opcode: Opcode = @enumFromInt(bytecode[ip]);
            ip += 1;

            switch (opcode) {
                .nop => try self.encoder.nop(),

                .load_const => {
                    const idx = (@as(u16, bytecode[ip]) << 8) | @as(u16, bytecode[ip + 1]);
                    ip += 2;
                    if (idx < constants.len) {
                        try self.encoder.movImm64(.rax, constants[idx].bits);
                        try self.encoder.push(.rax);
                    }
                },

                .add => {
                    // Pop operands
                    try self.encoder.pop(.rbx); // b
                    try self.encoder.pop(.rax); // a
                    // Extract int payloads
                    try self.emitExtractInt(); // rax = a.payload
                    try self.emitExtractIntRbx(); // rbx = b.payload
                    // Add
                    try self.encoder.addReg(.rax, .rbx);
                    // Pack result
                    try self.emitPackInt();
                    // Push result
                    try self.encoder.push(.rax);
                },

                .sub => {
                    try self.encoder.pop(.rbx);
                    try self.encoder.pop(.rax);
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.subReg(.rax, .rbx);
                    try self.emitPackInt();
                    try self.encoder.push(.rax);
                },

                .mul => {
                    try self.encoder.pop(.rbx);
                    try self.encoder.pop(.rax);
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.imulReg(.rax, .rbx);
                    try self.emitPackInt();
                    try self.encoder.push(.rax);
                },

                .div => {
                    try self.encoder.pop(.rbx); // divisor
                    try self.encoder.pop(.rax); // dividend
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    // Sign extend rax into rdx:rax for idiv
                    try self.encoder.cqo();
                    // idiv rbx (rax = rdx:rax / rbx)
                    try self.encoder.idivReg(.rbx);
                    try self.emitPackInt();
                    try self.encoder.push(.rax);
                },

                .halt => {
                    try self.encoder.pop(.rax);
                    break;
                },

                else => {
                    // Skip unsupported opcodes
                    switch (opcode) {
                        .push, .load_local, .store_local, .load_global, .store_global => ip += 2,
                        .jump, .jump_if, .jump_if_not => ip += 4,
                        .call => ip += 5,
                        .native_call => ip += 2,
                        else => {},
                    }
                },
            }
        }

        // Epilogue
        try self.encoder.movReg(.rsp, .rbp);
        try self.encoder.pop(.rbp);
        try self.encoder.ret();

        return self.encoder.getCode();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitExecutor = struct {
    compiler: JitCompiler,
    exec_mem: ?ExecutableMemory,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .compiler = JitCompiler.init(allocator),
            .exec_mem = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.exec_mem) |*mem| {
            mem.free();
        }
        self.compiler.deinit();
    }

    /// Compile bytecode and prepare for execution
    pub fn compile(self: *Self, bytecode: []const u8, constants: []const Value) !void {
        // Free previous executable memory if any
        if (self.exec_mem) |*mem| {
            mem.free();
            self.exec_mem = null;
        }

        // Compile to machine code
        const machine_code = try self.compiler.compile(bytecode, constants);

        // Allocate executable memory
        var exec_mem = try ExecutableMemory.alloc(machine_code.len + 64); // Extra space for safety
        errdefer exec_mem.free();

        // Copy and make executable
        try exec_mem.copyAndProtect(machine_code);

        self.exec_mem = exec_mem;
    }

    /// Execute compiled code and return result
    pub fn execute(self: *Self) !i64 {
        if (self.exec_mem) |mem| {
            const func = mem.getFunctionNoArgs();
            return func();
        }
        return error.NotCompiled;
    }

    /// Execute and return as Value
    pub fn executeValue(self: *Self) !Value {
        const result = try self.execute();
        return Value{ .bits = @bitCast(result) };
    }

    /// Compile and execute in one call
    pub fn run(self: *Self, bytecode: []const u8, constants: []const Value) !i64 {
        try self.compile(bytecode, constants);
        return self.execute();
    }

    /// Compile and execute, return Value
    pub fn runValue(self: *Self, bytecode: []const u8, constants: []const Value) !Value {
        try self.compile(bytecode, constants);
        return self.executeValue();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "X64Encoder basic" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.nop();
    try enc.ret();

    try std.testing.expectEqual(@as(usize, 2), enc.getCode().len);
    try std.testing.expectEqual(@as(u8, 0x90), enc.getCode()[0]); // NOP
    try std.testing.expectEqual(@as(u8, 0xC3), enc.getCode()[1]); // RET
}

test "X64Encoder mov imm64" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.movImm64(.rax, 0x123456789ABCDEF0);

    // REX.W + MOV rax, imm64
    try std.testing.expectEqual(@as(u8, 0x48), enc.getCode()[0]); // REX.W
    try std.testing.expectEqual(@as(u8, 0xB8), enc.getCode()[1]); // MOV rax
}

test "X64Encoder push/pop" {
    var enc = X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    try enc.push(.rax);
    try enc.pop(.rbx);

    try std.testing.expectEqual(@as(u8, 0x50), enc.getCode()[0]); // PUSH rax
    try std.testing.expectEqual(@as(u8, 0x5B), enc.getCode()[1]); // POP rbx
}

test "JitCompiler init" {
    var jit = JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    const constants = [_]Value{Value.int(42)};
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.halt),
    };

    const code = try jit.compile(&bytecode, &constants);
    try std.testing.expect(code.len > 0);
}

test "ExecutableMemory alloc/free" {
    var mem = try ExecutableMemory.alloc(4096);
    defer mem.free();

    try std.testing.expect(mem.len >= 4096);
}

test "JitExecutor simple constant" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Program: push 42, halt -> returns 42
    const constants = [_]Value{Value.int(42)};
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);

    // Result is NaN-boxed, extract the int
    const val = Value{ .bits = @bitCast(result) };
    try std.testing.expectEqual(@as(i64, 42), val.asInt());
}

test "JitExecutor addition correctness" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Program: push 10, push 20, add, halt -> returns 30
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 10
        @intFromEnum(Opcode.load_const), 0, 1, // push 20
        @intFromEnum(Opcode.add), // 10 + 20
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    // Verify correct NaN-boxed result
    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 30), val.asInt());
}

test "JitExecutor subtraction correctness" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    const constants = [_]Value{
        Value.int(100),
        Value.int(30),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.sub),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 70), val.asInt());
}

test "JitExecutor multiplication correctness" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    const constants = [_]Value{
        Value.int(7),
        Value.int(6),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.mul),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 42), val.asInt());
}

test "JitExecutor division correctness" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    const constants = [_]Value{
        Value.int(100),
        Value.int(5),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.div),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 20), val.asInt());
}

test "JitExecutor complex expression" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // (10 + 5) * 2 = 30
    const constants = [_]Value{
        Value.int(10),
        Value.int(5),
        Value.int(2),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 10
        @intFromEnum(Opcode.load_const), 0, 1, // push 5
        @intFromEnum(Opcode.add), // 10 + 5 = 15
        @intFromEnum(Opcode.load_const), 0, 2, // push 2
        @intFromEnum(Opcode.mul), // 15 * 2 = 30
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 30), val.asInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: VM vs JIT
// ═══════════════════════════════════════════════════════════════════════════════

test "Benchmark VM vs JIT" {
    const vm_mod_local = @import("vm.zig");
    const iterations: u32 = 10000;

    // Simple program: push 1, push 2, add, halt
    const constants = [_]Value{
        Value.int(1),
        Value.int(2),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.add),
        @intFromEnum(Opcode.halt),
    };

    // Benchmark VM
    var vm = try vm_mod_local.VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const vm_start = std.time.nanoTimestamp();
    var vm_result: i64 = 0;
    for (0..iterations) |_| {
        vm.load(&bytecode, &constants);
        const r = try vm.run();
        vm_result = r.asInt();
        vm.reset();
    }
    const vm_end = std.time.nanoTimestamp();
    const vm_ns = @as(u64, @intCast(vm_end - vm_start));

    // Benchmark JIT
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Compile once
    try executor.compile(&bytecode, &constants);

    const jit_start = std.time.nanoTimestamp();
    var jit_result_raw: i64 = 0;
    for (0..iterations) |_| {
        jit_result_raw = try executor.execute();
    }
    const jit_end = std.time.nanoTimestamp();
    const jit_ns = @as(u64, @intCast(jit_end - jit_start));

    // Extract JIT result
    const jit_val = Value{ .bits = @bitCast(jit_result_raw) };
    const jit_result = jit_val.asInt();

    // Calculate speedup
    const speedup = @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns));

    // Print results
    std.debug.print("\n=== BENCHMARK RESULTS ===\n", .{});
    std.debug.print("Iterations: {}\n", .{iterations});
    std.debug.print("VM:  {} ns total, {} ns/iter\n", .{ vm_ns, vm_ns / iterations });
    std.debug.print("JIT: {} ns total, {} ns/iter\n", .{ jit_ns, jit_ns / iterations });
    std.debug.print("Speedup: {d:.2}x\n", .{speedup});
    std.debug.print("VM result: {}, JIT result: {}\n", .{ vm_result, jit_result });

    // Verify correctness: both should return 3 (1 + 2)
    try std.testing.expectEqual(@as(i64, 3), vm_result);
    try std.testing.expectEqual(@as(i64, 3), jit_result);

    // JIT should be faster
    try std.testing.expect(speedup > 1.0);
}
