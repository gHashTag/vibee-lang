// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER v29 - REAL x86-64 STENCILS
// ═══════════════════════════════════════════════════════════════════════════════
// v28: Stencil structures only
// v29: Real x86-64 machine code, executable emission
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION: u32 = 29;
pub const PAGE_SIZE: usize = 4096;

// ═══════════════════════════════════════════════════════════════════════════════
// x86-64 OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86Opcode = enum(u8) {
    ADD = 0,
    SUB = 1,
    MUL = 2,
    MOV_IMM = 3,
    RET = 4,
    NOP = 5,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REAL x86-64 STENCILS
// ═══════════════════════════════════════════════════════════════════════════════

pub const RealStencil = struct {
    code: [64]u8 = [_]u8{0} ** 64,
    size: usize = 0,
    holes: [4]Hole = undefined,
    hole_count: usize = 0,

    const Self = @This();

    pub const Hole = struct {
        offset: usize,
        size: usize, // 4 for i32, 8 for i64
    };

    /// Emit patched code to buffer
    pub fn emit(self: *const Self, buffer: []u8, values: []const u64) usize {
        if (buffer.len < self.size) return 0;

        // Copy base code
        @memcpy(buffer[0..self.size], self.code[0..self.size]);

        // Patch holes
        for (0..self.hole_count) |i| {
            if (i >= values.len) break;
            const hole = self.holes[i];
            const value = values[i];

            if (hole.size == 8 and hole.offset + 8 <= buffer.len) {
                const bytes = @as([8]u8, @bitCast(value));
                @memcpy(buffer[hole.offset..][0..8], &bytes);
            } else if (hole.size == 4 and hole.offset + 4 <= buffer.len) {
                const val32: u32 = @truncate(value);
                const bytes = @as([4]u8, @bitCast(val32));
                @memcpy(buffer[hole.offset..][0..4], &bytes);
            }
        }

        return self.size;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STENCIL LIBRARY
// ═══════════════════════════════════════════════════════════════════════════════

pub const StencilLibrary = struct {
    stencils: std.AutoHashMap(X86Opcode, RealStencil),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var lib = Self{
            .stencils = std.AutoHashMap(X86Opcode, RealStencil).init(allocator),
        };

        // ADD: add rax, rdi (48 01 F8)
        var add_stencil = RealStencil{};
        add_stencil.code[0] = 0x48; // REX.W
        add_stencil.code[1] = 0x01; // ADD r/m64, r64
        add_stencil.code[2] = 0xF8; // rax, rdi
        add_stencil.size = 3;
        try lib.stencils.put(.ADD, add_stencil);

        // SUB: sub rax, rdi (48 29 F8)
        var sub_stencil = RealStencil{};
        sub_stencil.code[0] = 0x48;
        sub_stencil.code[1] = 0x29;
        sub_stencil.code[2] = 0xF8;
        sub_stencil.size = 3;
        try lib.stencils.put(.SUB, sub_stencil);

        // MUL: imul rax, rdi (48 0F AF C7)
        var mul_stencil = RealStencil{};
        mul_stencil.code[0] = 0x48;
        mul_stencil.code[1] = 0x0F;
        mul_stencil.code[2] = 0xAF;
        mul_stencil.code[3] = 0xC7;
        mul_stencil.size = 4;
        try lib.stencils.put(.MUL, mul_stencil);

        // MOV_IMM: movabs rax, imm64 (48 B8 + 8 bytes)
        var mov_stencil = RealStencil{};
        mov_stencil.code[0] = 0x48;
        mov_stencil.code[1] = 0xB8;
        mov_stencil.size = 10;
        mov_stencil.holes[0] = .{ .offset = 2, .size = 8 };
        mov_stencil.hole_count = 1;
        try lib.stencils.put(.MOV_IMM, mov_stencil);

        // RET: ret (C3)
        var ret_stencil = RealStencil{};
        ret_stencil.code[0] = 0xC3;
        ret_stencil.size = 1;
        try lib.stencils.put(.RET, ret_stencil);

        // NOP: nop (90)
        var nop_stencil = RealStencil{};
        nop_stencil.code[0] = 0x90;
        nop_stencil.size = 1;
        try lib.stencils.put(.NOP, nop_stencil);

        return lib;
    }

    pub fn deinit(self: *Self) void {
        self.stencils.deinit();
    }

    pub fn get(self: *Self, opcode: X86Opcode) ?*const RealStencil {
        return self.stencils.getPtr(opcode);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUFFER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuffer = struct {
    buffer: []u8,
    offset: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
        const buffer = try allocator.alloc(u8, size);
        @memset(buffer, 0x90); // Fill with NOPs
        return Self{
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn write(self: *Self, code: []const u8) bool {
        if (self.offset + code.len > self.buffer.len) return false;
        @memcpy(self.buffer[self.offset..][0..code.len], code);
        self.offset += code.len;
        return true;
    }

    pub fn writeByte(self: *Self, byte: u8) bool {
        if (self.offset >= self.buffer.len) return false;
        self.buffer[self.offset] = byte;
        self.offset += 1;
        return true;
    }

    pub fn getCode(self: *Self) []const u8 {
        return self.buffer[0..self.offset];
    }

    pub fn reset(self: *Self) void {
        self.offset = 0;
        @memset(self.buffer, 0x90);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeEmitter = struct {
    buffer: *CodeBuffer,
    library: *StencilLibrary,

    const Self = @This();

    pub fn init(buffer: *CodeBuffer, library: *StencilLibrary) Self {
        return Self{
            .buffer = buffer,
            .library = library,
        };
    }

    pub fn emitAdd(self: *Self) bool {
        if (self.library.get(.ADD)) |stencil| {
            var temp: [64]u8 = undefined;
            const size = stencil.emit(&temp, &[_]u64{});
            return self.buffer.write(temp[0..size]);
        }
        return false;
    }

    pub fn emitSub(self: *Self) bool {
        if (self.library.get(.SUB)) |stencil| {
            var temp: [64]u8 = undefined;
            const size = stencil.emit(&temp, &[_]u64{});
            return self.buffer.write(temp[0..size]);
        }
        return false;
    }

    pub fn emitMul(self: *Self) bool {
        if (self.library.get(.MUL)) |stencil| {
            var temp: [64]u8 = undefined;
            const size = stencil.emit(&temp, &[_]u64{});
            return self.buffer.write(temp[0..size]);
        }
        return false;
    }

    pub fn emitImmediate(self: *Self, value: i64) bool {
        if (self.library.get(.MOV_IMM)) |stencil| {
            var temp: [64]u8 = undefined;
            const size = stencil.emit(&temp, &[_]u64{@bitCast(value)});
            return self.buffer.write(temp[0..size]);
        }
        return false;
    }

    pub fn emitReturn(self: *Self) bool {
        if (self.library.get(.RET)) |stencil| {
            var temp: [64]u8 = undefined;
            const size = stencil.emit(&temp, &[_]u64{});
            return self.buffer.write(temp[0..size]);
        }
        return false;
    }

    /// Emit function that returns a constant
    pub fn emitConstantFunction(self: *Self, value: i64) bool {
        return self.emitImmediate(value) and self.emitReturn();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER v29
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITCompilerV29 = struct {
    library: StencilLibrary,
    buffer: CodeBuffer,
    emitter: CodeEmitter,
    version: u32 = VERSION,
    functions_compiled: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var library = try StencilLibrary.init(allocator);
        var buffer = try CodeBuffer.init(allocator, PAGE_SIZE);

        return Self{
            .library = library,
            .buffer = buffer,
            .emitter = CodeEmitter.init(&buffer, &library),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
        self.library.deinit();
    }

    pub fn compileConstant(self: *Self, value: i64) bool {
        self.buffer.reset();
        self.emitter = CodeEmitter.init(&self.buffer, &self.library);
        const result = self.emitter.emitConstantFunction(value);
        if (result) self.functions_compiled += 1;
        return result;
    }

    pub fn getCompiledCode(self: *Self) []const u8 {
        return self.buffer.getCode();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "stencil_add_bytes" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    const stencil = lib.get(.ADD).?;
    try std.testing.expectEqual(@as(usize, 3), stencil.size);
    try std.testing.expectEqual(@as(u8, 0x48), stencil.code[0]);
    try std.testing.expectEqual(@as(u8, 0x01), stencil.code[1]);
    try std.testing.expectEqual(@as(u8, 0xF8), stencil.code[2]);
}

test "stencil_sub_bytes" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    const stencil = lib.get(.SUB).?;
    try std.testing.expectEqual(@as(usize, 3), stencil.size);
    try std.testing.expectEqual(@as(u8, 0x48), stencil.code[0]);
    try std.testing.expectEqual(@as(u8, 0x29), stencil.code[1]);
}

test "stencil_mul_bytes" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    const stencil = lib.get(.MUL).?;
    try std.testing.expectEqual(@as(usize, 4), stencil.size);
}

test "stencil_mov_imm_patch" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    const stencil = lib.get(.MOV_IMM).?;
    var buffer: [64]u8 = undefined;

    const size = stencil.emit(&buffer, &[_]u64{42});
    try std.testing.expectEqual(@as(usize, 10), size);

    // Check immediate value is patched
    const patched_value = std.mem.readInt(u64, buffer[2..10], .little);
    try std.testing.expectEqual(@as(u64, 42), patched_value);
}

test "stencil_ret_bytes" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    const stencil = lib.get(.RET).?;
    try std.testing.expectEqual(@as(usize, 1), stencil.size);
    try std.testing.expectEqual(@as(u8, 0xC3), stencil.code[0]);
}

test "code_buffer_write" {
    var buffer = try CodeBuffer.init(std.testing.allocator, 64);
    defer buffer.deinit();

    const result = buffer.write(&[_]u8{ 0x48, 0x01, 0xF8 });
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(usize, 3), buffer.offset);
}

test "code_emitter_constant_function" {
    var lib = try StencilLibrary.init(std.testing.allocator);
    defer lib.deinit();

    var buffer = try CodeBuffer.init(std.testing.allocator, 64);
    defer buffer.deinit();

    var emitter = CodeEmitter.init(&buffer, &lib);
    const result = emitter.emitConstantFunction(42);

    try std.testing.expect(result);
    try std.testing.expectEqual(@as(usize, 11), buffer.offset); // 10 + 1
}

test "jit_compiler_compile_constant" {
    var jit = try JITCompilerV29.init(std.testing.allocator);
    defer jit.deinit();

    const result = jit.compileConstant(42);
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(usize, 1), jit.functions_compiled);
}

test "jit_compiler_get_code" {
    var jit = try JITCompilerV29.init(std.testing.allocator);
    defer jit.deinit();

    _ = jit.compileConstant(42);
    const code = jit.getCompiledCode();

    try std.testing.expectEqual(@as(usize, 11), code.len);
}

test "golden_identity" {
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    const result = phi_squared + inv_phi_squared;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "version_check" {
    var jit = try JITCompilerV29.init(std.testing.allocator);
    defer jit.deinit();
    try std.testing.expectEqual(@as(u32, 29), jit.version);
}
