// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC TRACING JIT - NATIVE CODE COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V40 - Tracing JIT for φ² additional speedup
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Target: 916M × φ² = 2.4B ops/sec (beat LuaJIT!)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const HOT_THRESHOLD: u32 = 50;
pub const MAX_TRACE_LEN: usize = 1024;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE IR
// ═══════════════════════════════════════════════════════════════════════════════

pub const IROp = enum(u8) {
    CONST_INT,
    ADD,
    INC,
    DEC,
    CMP_LT,
    GUARD_LT,
    LOOP,
    EXIT,
};

pub const IRInst = struct {
    op: IROp,
    dst: u8,
    src1: u8,
    src2: u8,
    imm: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86CodeGen = struct {
    code: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .code = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    // Emit: xor eax, eax
    pub fn emitXorEaxEax(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0x31, 0xC0 });
    }

    // Emit: xor ecx, ecx
    pub fn emitXorEcxEcx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0x31, 0xC9 });
    }

    // Emit: mov ecx, imm32
    pub fn emitMovEcxImm32(self: *Self, imm: u32) !void {
        try self.code.append(0xB9);
        const bytes: [4]u8 = @bitCast(imm);
        try self.code.appendSlice(&bytes);
    }

    // Emit: mov edx, imm32
    pub fn emitMovEdxImm32(self: *Self, imm: u32) !void {
        try self.code.append(0xBA);
        const bytes: [4]u8 = @bitCast(imm);
        try self.code.appendSlice(&bytes);
    }

    // Emit: add eax, ecx
    pub fn emitAddEaxEcx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0x01, 0xC8 });
    }

    // Emit: add rax, rcx (64-bit)
    pub fn emitAddRaxRcx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0x48, 0x01, 0xC8 });
    }

    // Emit: inc ecx
    pub fn emitIncEcx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0xFF, 0xC1 });
    }

    // Emit: dec ecx
    pub fn emitDecEcx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0xFF, 0xC9 });
    }

    // Emit: cmp ecx, edx
    pub fn emitCmpEcxEdx(self: *Self) !void {
        try self.code.appendSlice(&[_]u8{ 0x39, 0xD1 });
    }

    // Emit: jl rel8
    pub fn emitJL(self: *Self, offset: i8) !void {
        try self.code.append(0x7C);
        try self.code.append(@bitCast(offset));
    }

    // Emit: jge rel8
    pub fn emitJGE(self: *Self, offset: i8) !void {
        try self.code.append(0x7D);
        try self.code.append(@bitCast(offset));
    }

    // Emit: jnz rel8
    pub fn emitJNZ(self: *Self, offset: i8) !void {
        try self.code.append(0x75);
        try self.code.append(@bitCast(offset));
    }

    // Emit: ret
    pub fn emitRet(self: *Self) !void {
        try self.code.append(0xC3);
    }

    /// Compile sum(0..N) loop to native x86-64
    /// Returns result in RAX
    pub fn compileSumLoop(self: *Self, limit: u32) ![]u8 {
        self.code.clearRetainingCapacity();

        // xor eax, eax      ; sum = 0
        try self.emitXorEaxEax();

        // xor ecx, ecx      ; i = 0
        try self.emitXorEcxEcx();

        // mov edx, limit    ; limit = N
        try self.emitMovEdxImm32(limit);

        // loop_start:
        const loop_start = self.code.items.len;

        // add eax, ecx      ; sum += i
        try self.emitAddEaxEcx();

        // inc ecx           ; i++
        try self.emitIncEcx();

        // cmp ecx, edx      ; compare i, limit
        try self.emitCmpEcxEdx();

        // jl loop_start     ; if i < limit goto loop
        const current = self.code.items.len;
        const offset: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(current)) - 2);
        try self.emitJL(offset);

        // ret               ; return sum in eax
        try self.emitRet();

        return try self.code.toOwnedSlice();
    }

    /// Compile countdown sum: sum = 0; for i = N downto 1 { sum += i }
    /// This is faster because dec+jnz is one micro-op on modern CPUs
    pub fn compileSumLoopFast(self: *Self, limit: u32) ![]u8 {
        self.code.clearRetainingCapacity();

        // xor eax, eax      ; sum = 0
        try self.emitXorEaxEax();

        // mov ecx, limit    ; i = N
        try self.emitMovEcxImm32(limit);

        // loop_start:
        const loop_start = self.code.items.len;

        // add eax, ecx      ; sum += i
        try self.emitAddEaxEcx();

        // dec ecx           ; i--
        try self.emitDecEcx();

        // jnz loop_start    ; if i != 0 goto loop
        const current = self.code.items.len;
        const offset: i8 = @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(current)) - 2);
        try self.emitJNZ(offset);

        // ret
        try self.emitRet();

        return try self.code.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITExecutor = struct {
    allocator: Allocator,
    codegen: X86CodeGen,
    executable_mem: ?[]align(4096) u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .codegen = X86CodeGen.init(allocator),
            .executable_mem = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.executable_mem) |mem| {
            // Restore write permission before freeing
            _ = std.os.linux.mprotect(
                @ptrCast(mem.ptr),
                mem.len,
                std.os.linux.PROT.READ | std.os.linux.PROT.WRITE,
            );
            self.allocator.free(mem);
        }
        self.codegen.deinit();
    }

    /// Compile and execute sum(0..N) using JIT
    pub fn executeSumLoop(self: *Self, limit: u32) !i64 {
        // Generate native code
        const code = try self.codegen.compileSumLoopFast(limit);
        defer self.allocator.free(code);

        // Allocate executable memory
        const page_size: usize = 4096;
        const aligned_size = (code.len + page_size - 1) & ~(page_size - 1);

        const mem = try self.allocator.alignedAlloc(u8, 4096, aligned_size);
        errdefer self.allocator.free(mem);

        @memcpy(mem[0..code.len], code);

        // Make executable
        const result = std.os.linux.mprotect(
            @ptrCast(mem.ptr),
            aligned_size,
            std.os.linux.PROT.READ | std.os.linux.PROT.EXEC,
        );

        if (result != 0) {
            self.allocator.free(mem);
            return error.MprotectFailed;
        }

        // Execute
        const func: *const fn () callconv(.C) i64 = @ptrCast(@alignCast(mem.ptr));
        const ret = func();

        // Cleanup
        _ = std.os.linux.mprotect(
            @ptrCast(mem.ptr),
            aligned_size,
            std.os.linux.PROT.READ | std.os.linux.PROT.WRITE,
        );
        self.allocator.free(mem);

        return ret;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "X86CodeGen basic" {
    var codegen = X86CodeGen.init(std.testing.allocator);
    defer codegen.deinit();

    try codegen.emitXorEaxEax();
    try codegen.emitRet();

    try std.testing.expectEqual(@as(usize, 3), codegen.code.items.len);
}

test "X86CodeGen sum loop generation" {
    var codegen = X86CodeGen.init(std.testing.allocator);
    defer codegen.deinit();

    const code = try codegen.compileSumLoopFast(10);
    defer std.testing.allocator.free(code);

    try std.testing.expect(code.len > 0);
    try std.testing.expect(code.len < 50); // Should be compact
}
