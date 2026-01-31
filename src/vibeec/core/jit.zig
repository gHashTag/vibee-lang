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

    // TEST reg, imm8 (test bit)
    pub fn testReg(self: *Self, reg: Reg64, imm: u8) !void {
        const reg_val = @intFromEnum(reg);
        if (reg == .rax) {
            // Special encoding for rax
            try self.code.append(0xA8); // TEST al, imm8
            try self.code.append(imm);
        } else {
            try self.rex(false, false, false, reg_val >= 8);
            try self.code.append(0xF6); // TEST r/m8, imm8
            try self.modrm(3, 0, @truncate(reg_val & 0x7));
            try self.code.append(imm);
        }
    }

    // MOV reg, [base + disp32]
    pub fn movMemToReg(self: *Self, dst: Reg64, base: Reg64, disp: i32) !void {
        const dst_val = @intFromEnum(dst);
        const base_val = @intFromEnum(base);
        try self.rex(true, dst_val >= 8, false, base_val >= 8);
        try self.code.append(0x8B); // MOV r64, r/m64
        // ModR/M: mod=10 (disp32), reg=dst, rm=base
        try self.modrm(2, @truncate(dst_val & 0x7), @truncate(base_val & 0x7));
        // SIB byte needed for rsp/r12 as base
        if ((base_val & 0x7) == 4) {
            try self.code.append(0x24); // SIB: scale=0, index=rsp, base=rsp
        }
        try self.code.appendSlice(&@as([4]u8, @bitCast(disp)));
    }

    // MOV [base + disp32], reg
    pub fn movRegToMem(self: *Self, base: Reg64, disp: i32, src: Reg64) !void {
        const src_val = @intFromEnum(src);
        const base_val = @intFromEnum(base);
        try self.rex(true, src_val >= 8, false, base_val >= 8);
        try self.code.append(0x89); // MOV r/m64, r64
        try self.modrm(2, @truncate(src_val & 0x7), @truncate(base_val & 0x7));
        if ((base_val & 0x7) == 4) {
            try self.code.append(0x24);
        }
        try self.code.appendSlice(&@as([4]u8, @bitCast(disp)));
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
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
    }

    // ADDSD xmm, xmm
    pub fn addsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x58);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
    }

    // SUBSD xmm, xmm
    pub fn subsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5C);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
    }

    // MULSD xmm, xmm
    pub fn mulsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x59);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
    }

    // DIVSD xmm, xmm
    pub fn divsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x5E);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
    }

    // MOVQ xmm, r64 (move quadword from GPR to XMM)
    pub fn movqToXmm(self: *Self, dst: XmmReg, src: Reg64) !void {
        try self.code.append(0x66);
        const src_val: u8 = @intFromEnum(src);
        const dst_val: u8 = @intFromEnum(dst);
        try self.rex(true, dst_val >= 8, false, src_val >= 8);
        try self.code.append(0x0F);
        try self.code.append(0x6E); // MOVQ xmm, r/m64
        try self.code.append(0xC0 | ((dst_val & 0x7) << 3) | (src_val & 0x7));
    }

    // MOVQ r64, xmm (move quadword from XMM to GPR)
    pub fn movqFromXmm(self: *Self, dst: Reg64, src: XmmReg) !void {
        try self.code.append(0x66);
        const dst_val: u8 = @intFromEnum(dst);
        const src_val: u8 = @intFromEnum(src);
        try self.rex(true, src_val >= 8, false, dst_val >= 8);
        try self.code.append(0x0F);
        try self.code.append(0x7E); // MOVQ r/m64, xmm
        try self.code.append(0xC0 | ((src_val & 0x7) << 3) | (dst_val & 0x7));
    }

    // UCOMISD xmm, xmm (unordered compare scalar double)
    pub fn ucomisdReg(self: *Self, a: XmmReg, b: XmmReg) !void {
        try self.code.append(0x66);
        try self.code.append(0x0F);
        try self.code.append(0x2E);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(a)) << 3) | @as(u8, @intFromEnum(b)));
    }

    // SQRTSD xmm, xmm (square root)
    pub fn sqrtsdReg(self: *Self, dst: XmmReg, src: XmmReg) !void {
        try self.code.append(0xF2);
        try self.code.append(0x0F);
        try self.code.append(0x51);
        try self.code.append(0xC0 | (@as(u8, @intFromEnum(dst)) << 3) | @as(u8, @intFromEnum(src)));
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

/// Patch location for forward jumps
const JumpPatch = struct {
    code_offset: u32, // Offset in generated code where to patch
    bytecode_target: u32, // Target bytecode address
};

/// Call patch for function calls
const CallPatch = struct {
    code_offset: u32, // Offset where to patch
    bytecode_target: u32, // Target function address in bytecode
};

/// Halt patch - jump to epilogue
const HaltPatch = struct {
    code_offset: u32, // Offset where to patch JMP rel32
};

pub const JitCompiler = struct {
    encoder: X64Encoder,
    allocator: std.mem.Allocator,

    // Label tracking: bytecode address -> machine code offset
    labels: std.AutoHashMap(u32, u32),
    // Forward jump patches to resolve
    patches: std.ArrayList(JumpPatch),
    // Call patches to resolve
    call_patches: std.ArrayList(CallPatch),
    // Halt patches - jumps to epilogue
    halt_patches: std.ArrayList(HaltPatch),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .encoder = X64Encoder.init(allocator),
            .allocator = allocator,
            .labels = std.AutoHashMap(u32, u32).init(allocator),
            .patches = std.ArrayList(JumpPatch).init(allocator),
            .call_patches = std.ArrayList(CallPatch).init(allocator),
            .halt_patches = std.ArrayList(HaltPatch).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.encoder.deinit();
        self.labels.deinit();
        self.patches.deinit();
        self.call_patches.deinit();
        self.halt_patches.deinit();
    }

    fn recordLabel(self: *Self, bytecode_addr: u32) !void {
        const code_offset: u32 = @intCast(self.encoder.code.items.len);
        try self.labels.put(bytecode_addr, code_offset);
    }

    fn emitJumpPatch(self: *Self, target_bytecode: u32) !void {
        // Record patch location (current position + 1 for opcode byte)
        const patch_offset: u32 = @intCast(self.encoder.code.items.len);
        try self.patches.append(.{
            .code_offset = patch_offset,
            .bytecode_target = target_bytecode,
        });
        // Emit placeholder (will be patched later)
        try self.encoder.code.appendSlice(&[4]u8{ 0, 0, 0, 0 });
    }

    fn resolvePatches(self: *Self) !void {
        // Resolve jump patches
        for (self.patches.items) |patch| {
            if (self.labels.get(patch.bytecode_target)) |target_offset| {
                // Calculate relative offset from end of jump instruction
                const jump_end = patch.code_offset + 4;
                const rel_offset: i32 = @as(i32, @intCast(target_offset)) - @as(i32, @intCast(jump_end));
                // Patch the offset
                const bytes: [4]u8 = @bitCast(rel_offset);
                self.encoder.code.items[patch.code_offset] = bytes[0];
                self.encoder.code.items[patch.code_offset + 1] = bytes[1];
                self.encoder.code.items[patch.code_offset + 2] = bytes[2];
                self.encoder.code.items[patch.code_offset + 3] = bytes[3];
            }
        }

        // Resolve call patches (same logic as jumps)
        for (self.call_patches.items) |patch| {
            if (self.labels.get(patch.bytecode_target)) |target_offset| {
                const call_end = patch.code_offset + 4;
                const rel_offset: i32 = @as(i32, @intCast(target_offset)) - @as(i32, @intCast(call_end));
                const bytes: [4]u8 = @bitCast(rel_offset);
                self.encoder.code.items[patch.code_offset] = bytes[0];
                self.encoder.code.items[patch.code_offset + 1] = bytes[1];
                self.encoder.code.items[patch.code_offset + 2] = bytes[2];
                self.encoder.code.items[patch.code_offset + 3] = bytes[3];
            }
        }
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

    /// Float add: pop two floats, add, push result
    /// Floats are stored directly as IEEE 754, no extraction needed
    fn emitFloatAdd(self: *Self) !void {
        try self.emitVPopRbx(); // b
        try self.emitVPop(); // a
        // Move to XMM registers
        try self.encoder.movqToXmm(.xmm0, .rax);
        try self.encoder.movqToXmm(.xmm1, .rbx);
        // Add
        try self.encoder.addsdReg(.xmm0, .xmm1);
        // Move back to GPR
        try self.encoder.movqFromXmm(.rax, .xmm0);
        try self.emitVPush();
    }

    fn emitFloatSub(self: *Self) !void {
        try self.emitVPopRbx();
        try self.emitVPop();
        try self.encoder.movqToXmm(.xmm0, .rax);
        try self.encoder.movqToXmm(.xmm1, .rbx);
        try self.encoder.subsdReg(.xmm0, .xmm1);
        try self.encoder.movqFromXmm(.rax, .xmm0);
        try self.emitVPush();
    }

    fn emitFloatMul(self: *Self) !void {
        try self.emitVPopRbx();
        try self.emitVPop();
        try self.encoder.movqToXmm(.xmm0, .rax);
        try self.encoder.movqToXmm(.xmm1, .rbx);
        try self.encoder.mulsdReg(.xmm0, .xmm1);
        try self.encoder.movqFromXmm(.rax, .xmm0);
        try self.emitVPush();
    }

    fn emitFloatDiv(self: *Self) !void {
        try self.emitVPopRbx();
        try self.emitVPop();
        try self.encoder.movqToXmm(.xmm0, .rax);
        try self.encoder.movqToXmm(.xmm1, .rbx);
        try self.encoder.divsdReg(.xmm0, .xmm1);
        try self.encoder.movqFromXmm(.rax, .xmm0);
        try self.emitVPush();
    }

    /// Check if value in rax is a float (not a tagged NaN)
    /// Sets ZF if NOT float (is tagged)
    fn emitIsFloat(self: *Self) !void {
        // mov rcx, QNAN
        try self.encoder.movImm64(.rcx, QNAN);
        // and rcx, rax
        try self.encoder.andReg(.rcx, .rax);
        // cmp rcx, QNAN
        try self.encoder.movImm64(.rdx, QNAN);
        try self.encoder.cmpReg(.rcx, .rdx);
        // ZF=1 if tagged (not float), ZF=0 if float
    }

    /// Float comparison: pop two floats, compare, push NaN-boxed bool
    /// setcc_opcode: 0x92=SETB, 0x96=SETBE, 0x97=SETA, 0x93=SETAE, 0x94=SETE
    fn emitFloatCmp(self: *Self, setcc_opcode: u8) !void {
        try self.emitVPopRbx(); // b
        try self.emitVPop(); // a
        // Move to XMM
        try self.encoder.movqToXmm(.xmm0, .rax);
        try self.encoder.movqToXmm(.xmm1, .rbx);
        // UCOMISD xmm0, xmm1
        try self.encoder.ucomisdReg(.xmm0, .xmm1);
        // SETcc al
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(setcc_opcode);
        try self.encoder.code.append(0xC0); // al
        // MOVZX rax, al
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        // OR with QNAN_BOOL
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT));
        try self.encoder.orReg(.rax, .rcx);
        try self.emitVPush();
    }

    // Value stack size (number of 8-byte slots)
    const VALUE_STACK_SIZE: u32 = 1024;

    /// Push value in rax to value stack (r12-based)
    fn emitVPush(self: *Self) !void {
        // mov [r12], rax
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x89); // MOV r/m64, r64
        try self.encoder.code.append(0x04); // ModR/M: [r12]
        try self.encoder.code.append(0x24); // SIB: r12
        // add r12, 8
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x83); // ADD r/m64, imm8
        try self.encoder.code.append(0xC4); // ModR/M: r12
        try self.encoder.code.append(0x08); // imm8 = 8
    }

    /// Pop value from value stack (r12-based) into rax
    fn emitVPop(self: *Self) !void {
        // sub r12, 8
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x83); // SUB r/m64, imm8
        try self.encoder.code.append(0xEC); // ModR/M: r12
        try self.encoder.code.append(0x08); // imm8 = 8
        // mov rax, [r12]
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x8B); // MOV r64, r/m64
        try self.encoder.code.append(0x04); // ModR/M: [r12]
        try self.encoder.code.append(0x24); // SIB: r12
    }

    /// Pop value from value stack into rbx
    fn emitVPopRbx(self: *Self) !void {
        // sub r12, 8
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x83); // SUB r/m64, imm8
        try self.encoder.code.append(0xEC); // ModR/M: r12
        try self.encoder.code.append(0x08); // imm8 = 8
        // mov rbx, [r12]
        try self.encoder.code.append(0x49); // REX.WB
        try self.encoder.code.append(0x8B); // MOV r64, r/m64
        try self.encoder.code.append(0x1C); // ModR/M: rbx, [r12]
        try self.encoder.code.append(0x24); // SIB: r12
    }

    /// Compile bytecode to x86-64 machine code
    /// Uses r12 as value stack pointer (passed in rdi from caller)
    /// This allows proper CALL/RET with nested function calls
    pub fn compile(self: *Self, bytecode: []const u8, constants: []const Value) ![]const u8 {
        self.encoder.clear();
        self.labels.clearRetainingCapacity();
        self.patches.clearRetainingCapacity();
        self.call_patches.clearRetainingCapacity();
        self.halt_patches.clearRetainingCapacity();

        // Prologue - save callee-saved registers
        try self.encoder.push(.rbp);
        try self.encoder.movReg(.rbp, .rsp);
        try self.encoder.push(.r12); // Save r12
        try self.encoder.push(.rbx); // Save rbx (used in operations)

        // Align stack to 16 bytes (System V ABI requirement)
        // After 4 pushes (32 bytes), stack is aligned
        // But we need to ensure it stays aligned for CALLs

        // r12 = rdi (value stack pointer passed from caller)
        try self.encoder.movReg(.r12, .rdi);

        var ip: usize = 0;
        while (ip < bytecode.len) {
            // Record label for this bytecode address
            try self.recordLabel(@intCast(ip));

            const opcode: Opcode = @enumFromInt(bytecode[ip]);
            ip += 1;

            switch (opcode) {
                .nop => try self.encoder.nop(),

                .load_const => {
                    const idx = (@as(u16, bytecode[ip]) << 8) | @as(u16, bytecode[ip + 1]);
                    ip += 2;
                    if (idx < constants.len) {
                        try self.encoder.movImm64(.rax, constants[idx].bits);
                        try self.emitVPush();
                    }
                },

                .dup => {
                    // Duplicate top of stack
                    try self.emitVPop();
                    try self.emitVPush();
                    try self.emitVPush();
                },

                .pop => {
                    try self.emitVPop();
                },

                .add => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.addReg(.rax, .rbx);
                    try self.emitPackInt();
                    try self.emitVPush();
                },

                .sub => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.subReg(.rax, .rbx);
                    try self.emitPackInt();
                    try self.emitVPush();
                },

                .mul => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.imulReg(.rax, .rbx);
                    try self.emitPackInt();
                    try self.emitVPush();
                },

                .div => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.cqo();
                    try self.encoder.idivReg(.rbx);
                    try self.emitPackInt();
                    try self.emitVPush();
                },

                // Float arithmetic (explicit opcodes)
                .fadd => try self.emitFloatAdd(),
                .fsub => try self.emitFloatSub(),
                .fmul => try self.emitFloatMul(),
                .fdiv => try self.emitFloatDiv(),

                // Float comparison
                .flt => try self.emitFloatCmp(0x92), // SETB (below, for unordered compare)
                .fle => try self.emitFloatCmp(0x96), // SETBE
                .fgt => try self.emitFloatCmp(0x97), // SETA (above)
                .fge => try self.emitFloatCmp(0x93), // SETAE
                .feq => try self.emitFloatCmp(0x94), // SETE

                // Comparison opcodes
                .lt => {
                    try self.emitVPopRbx(); // b
                    try self.emitVPop(); // a
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.cmpReg(.rax, .rbx);
                    try self.emitSetBoolLt(); // Set rax to NaN-boxed bool based on LT
                    try self.emitVPush();
                },

                .le => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.cmpReg(.rax, .rbx);
                    try self.emitSetBoolLe();
                    try self.emitVPush();
                },

                .gt => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.cmpReg(.rax, .rbx);
                    try self.emitSetBoolGt();
                    try self.emitVPush();
                },

                .ge => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    try self.emitExtractInt();
                    try self.emitExtractIntRbx();
                    try self.encoder.cmpReg(.rax, .rbx);
                    try self.emitSetBoolGe();
                    try self.emitVPush();
                },

                .eq => {
                    try self.emitVPopRbx();
                    try self.emitVPop();
                    // For eq, compare full NaN-boxed values
                    try self.encoder.cmpReg(.rax, .rbx);
                    try self.emitSetBoolEq();
                    try self.emitVPush();
                },

                // Jump opcodes
                .jump => {
                    const target = (@as(u32, bytecode[ip]) << 24) |
                        (@as(u32, bytecode[ip + 1]) << 16) |
                        (@as(u32, bytecode[ip + 2]) << 8) |
                        @as(u32, bytecode[ip + 3]);
                    ip += 4;
                    try self.encoder.code.append(0xE9); // JMP rel32
                    try self.emitJumpPatch(target);
                },

                .jump_if => {
                    const target = (@as(u32, bytecode[ip]) << 24) |
                        (@as(u32, bytecode[ip + 1]) << 16) |
                        (@as(u32, bytecode[ip + 2]) << 8) |
                        @as(u32, bytecode[ip + 3]);
                    ip += 4;
                    // Pop condition from value stack
                    try self.emitVPop();
                    // Test if true (bit 0 for bool)
                    try self.encoder.testReg(.rax, 1);
                    // JNZ (jump if not zero = jump if true)
                    try self.encoder.code.append(0x0F);
                    try self.encoder.code.append(0x85); // JNZ rel32
                    try self.emitJumpPatch(target);
                },

                .jump_if_not => {
                    const target = (@as(u32, bytecode[ip]) << 24) |
                        (@as(u32, bytecode[ip + 1]) << 16) |
                        (@as(u32, bytecode[ip + 2]) << 8) |
                        @as(u32, bytecode[ip + 3]);
                    ip += 4;
                    // Pop condition from value stack
                    try self.emitVPop();
                    // Test if true
                    try self.encoder.testReg(.rax, 1);
                    // JZ (jump if zero = jump if false)
                    try self.encoder.code.append(0x0F);
                    try self.encoder.code.append(0x84); // JZ rel32
                    try self.emitJumpPatch(target);
                },

                .load_local => {
                    const idx = (@as(u16, bytecode[ip]) << 8) | @as(u16, bytecode[ip + 1]);
                    ip += 2;
                    // Load from value stack base + idx*8
                    // Value stack grows upward from r12 base
                    // But locals are at fixed positions from function entry
                    // For now, use rbp-based addressing for locals
                    try self.encoder.movMemToReg(.rax, .rbp, -@as(i32, @intCast((idx + 1) * 8)));
                    try self.emitVPush();
                },

                .store_local => {
                    const idx = (@as(u16, bytecode[ip]) << 8) | @as(u16, bytecode[ip + 1]);
                    ip += 2;
                    try self.emitVPop();
                    // Store to rbp-based local
                    try self.encoder.movRegToMem(.rbp, -@as(i32, @intCast((idx + 1) * 8)), .rax);
                },

                .call => {
                    const func_addr = (@as(u32, bytecode[ip]) << 24) |
                        (@as(u32, bytecode[ip + 1]) << 16) |
                        (@as(u32, bytecode[ip + 2]) << 8) |
                        @as(u32, bytecode[ip + 3]);
                    const arg_count = bytecode[ip + 4];
                    ip += 5;
                    _ = arg_count; // Args are already on value stack

                    // x86 CALL pushes return address to x86 stack (rsp)
                    // Value stack (r12) is separate
                    try self.encoder.code.append(0xE8); // CALL rel32
                    try self.call_patches.append(.{
                        .code_offset = @intCast(self.encoder.code.items.len),
                        .bytecode_target = func_addr,
                    });
                    try self.encoder.code.appendSlice(&[4]u8{ 0, 0, 0, 0 });
                    // Function leaves result on value stack, nothing to do here
                },

                .ret => {
                    // Return value is already on value stack (top)
                    // Just do x86 RET to return to caller
                    try self.encoder.ret();
                },

                .halt => {
                    // Pop result from value stack into rax
                    try self.emitVPop();
                    // Jump to epilogue (will be patched)
                    try self.encoder.code.append(0xE9); // JMP rel32
                    try self.halt_patches.append(.{
                        .code_offset = @intCast(self.encoder.code.items.len),
                    });
                    try self.encoder.code.appendSlice(&[4]u8{ 0, 0, 0, 0 });
                },

                else => {
                    // Skip unsupported opcodes
                    switch (opcode) {
                        .push, .load_global, .store_global => ip += 2,
                        .native_call => ip += 2,
                        else => {},
                    }
                },
            }
        }

        // Record final label
        try self.recordLabel(@intCast(ip));

        // Epilogue label - halt jumps here
        const epilogue_offset: u32 = @intCast(self.encoder.code.items.len);

        // Epilogue - restore callee-saved registers
        // Result is already in rax from halt
        try self.encoder.pop(.rbx);
        try self.encoder.pop(.r12);
        try self.encoder.pop(.rbp);
        try self.encoder.ret();

        // Resolve forward jumps and calls
        try self.resolvePatches();

        // Resolve halt patches (jump to epilogue)
        for (self.halt_patches.items) |patch| {
            const jump_end = patch.code_offset + 4;
            const rel_offset: i32 = @as(i32, @intCast(epilogue_offset)) - @as(i32, @intCast(jump_end));
            const bytes: [4]u8 = @bitCast(rel_offset);
            self.encoder.code.items[patch.code_offset] = bytes[0];
            self.encoder.code.items[patch.code_offset + 1] = bytes[1];
            self.encoder.code.items[patch.code_offset + 2] = bytes[2];
            self.encoder.code.items[patch.code_offset + 3] = bytes[3];
        }

        return self.encoder.getCode();
    }

    // Emit code to set rax to NaN-boxed bool based on comparison flags
    fn emitSetBoolLt(self: *Self) !void {
        // SETL al (set if less)
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0x9C);
        try self.encoder.code.append(0xC0); // SETL al
        // MOVZX rax, al
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        // OR with QNAN_BOOL to make NaN-boxed bool
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT)); // TAG_BOOL
        try self.encoder.orReg(.rax, .rcx);
    }

    fn emitSetBoolLe(self: *Self) !void {
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0x9E); // SETLE al
        try self.encoder.code.append(0xC0);
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT));
        try self.encoder.orReg(.rax, .rcx);
    }

    fn emitSetBoolGt(self: *Self) !void {
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0x9F); // SETG al
        try self.encoder.code.append(0xC0);
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT));
        try self.encoder.orReg(.rax, .rcx);
    }

    fn emitSetBoolGe(self: *Self) !void {
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0x9D); // SETGE al
        try self.encoder.code.append(0xC0);
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT));
        try self.encoder.orReg(.rax, .rcx);
    }

    fn emitSetBoolEq(self: *Self) !void {
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0x94); // SETE al
        try self.encoder.code.append(0xC0);
        try self.encoder.code.append(0x48);
        try self.encoder.code.append(0x0F);
        try self.encoder.code.append(0xB6);
        try self.encoder.code.append(0xC0);
        try self.encoder.movImm64(.rcx, QNAN | (@as(u64, 1) << TAG_SHIFT));
        try self.encoder.orReg(.rax, .rcx);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitExecutor = struct {
    compiler: JitCompiler,
    exec_mem: ?ExecutableMemory,
    value_stack: []u64, // Separate value stack
    allocator: std.mem.Allocator,

    const Self = @This();
    const VALUE_STACK_SLOTS: usize = 1024;

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .compiler = JitCompiler.init(allocator),
            .exec_mem = null,
            .value_stack = allocator.alloc(u64, VALUE_STACK_SLOTS) catch &[_]u64{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.exec_mem) |*mem| {
            mem.free();
        }
        if (self.value_stack.len > 0) {
            self.allocator.free(self.value_stack);
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
    /// Passes value stack pointer in rdi (first arg in System V ABI)
    pub fn execute(self: *Self) !i64 {
        if (self.exec_mem) |mem| {
            // Function signature: fn(value_stack: [*]u64) i64
            const FnType = *const fn ([*]u64) callconv(.C) i64;
            const func: FnType = @ptrCast(mem.ptr);
            return func(self.value_stack.ptr);
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

test "JitExecutor comparison LT" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 5 < 10 = true
    const constants = [_]Value{
        Value.int(5),
        Value.int(10),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 5
        @intFromEnum(Opcode.load_const), 0, 1, // push 10
        @intFromEnum(Opcode.lt), // 5 < 10
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isBool());
    try std.testing.expect(val.asBool() == true);
}

test "JitExecutor comparison GT" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 10 > 5 = true
    const constants = [_]Value{
        Value.int(10),
        Value.int(5),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.gt),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isBool());
    try std.testing.expect(val.asBool() == true);
}

test "JitExecutor comparison EQ" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 42 == 42 = true
    const constants = [_]Value{
        Value.int(42),
        Value.int(42),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.eq),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isBool());
    try std.testing.expect(val.asBool() == true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLOAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JitExecutor float add" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 3.14 + 2.86 = 6.0
    const constants = [_]Value{
        Value.float(3.14),
        Value.float(2.86),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.fadd),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isFloat());
    try std.testing.expectApproxEqAbs(@as(f64, 6.0), val.asFloat(), 0.0001);
}

test "JitExecutor float mul" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 2.5 * 4.0 = 10.0
    const constants = [_]Value{
        Value.float(2.5),
        Value.float(4.0),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.fmul),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isFloat());
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), val.asFloat(), 0.0001);
}

test "JitExecutor float div" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 10.0 / 4.0 = 2.5
    const constants = [_]Value{
        Value.float(10.0),
        Value.float(4.0),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.fdiv),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isFloat());
    try std.testing.expectApproxEqAbs(@as(f64, 2.5), val.asFloat(), 0.0001);
}

test "JitExecutor float comparison" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // 3.14 < 4.0 = true
    const constants = [_]Value{
        Value.float(3.14),
        Value.float(4.0),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.flt),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isBool());
    try std.testing.expect(val.asBool() == true);
}

test "JitExecutor PHI calculation" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // PHI * PHI ≈ 2.618
    const phi = value.PHI;
    const constants = [_]Value{
        Value.float(phi),
        Value.float(phi),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.fmul),
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isFloat());
    try std.testing.expectApproxEqAbs(value.PHI_SQ, val.asFloat(), 0.0001);
}

// NOTE: JIT function calls are complex because x86 CALL/RET use the same stack
// as our value stack (PUSH/POP). For now, we support inline functions only.
// Full function call support would require a separate value stack pointer.

test "JitExecutor inline function (no call)" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Test inline computation without CALL
    // Equivalent to: func(10, 20) where func adds args

    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };

    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 10
        @intFromEnum(Opcode.load_const), 0, 1, // push 20
        @intFromEnum(Opcode.add), // add -> 30
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 30), val.asInt());
}

test "JitExecutor inline double" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Test: double a value using dup + add
    // 5 -> dup -> (5, 5) -> add -> 10

    const constants = [_]Value{
        Value.int(5),
    };

    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 5
        @intFromEnum(Opcode.dup), // dup (5, 5)
        @intFromEnum(Opcode.add), // add (10)
        @intFromEnum(Opcode.halt),
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 10), val.asInt());
}

test "JitExecutor function call returns constant" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Bytecode layout:
    // 0: CALL func (at offset 9)
    // 6: HALT
    // 9: func: LOAD_CONST 0 (42)
    // 12: RET

    const constants = [_]Value{
        Value.int(42),
    };

    const bytecode = [_]u8{
        // Main: call func at offset 8, 0 args
        @intFromEnum(Opcode.call), 0, 0, 0, 8, 0, // call offset 8, 0 args (6 bytes, offset 0-5)
        @intFromEnum(Opcode.halt), // halt (offset 6)
        @intFromEnum(Opcode.nop), // padding (offset 7)
        // Func at offset 8:
        @intFromEnum(Opcode.load_const), 0, 0, // push 42 (offset 8-10)
        @intFromEnum(Opcode.ret), // return (offset 11)
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 42), val.asInt());
}

test "JitExecutor function call with args" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Bytecode layout:
    // Main: push 10, push 20, call add_func, halt
    // add_func: add (args already on stack), ret

    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };

    const bytecode = [_]u8{
        // Main:
        @intFromEnum(Opcode.load_const), 0, 0, // push 10 (offset 0-2)
        @intFromEnum(Opcode.load_const), 0, 1, // push 20 (offset 3-5)
        @intFromEnum(Opcode.call), 0, 0, 0, 14, 2, // call offset 14, 2 args (offset 6-11)
        @intFromEnum(Opcode.halt), // halt (offset 12)
        @intFromEnum(Opcode.nop), // padding (offset 13)
        // add_func at offset 14:
        @intFromEnum(Opcode.add), // add args (offset 14)
        @intFromEnum(Opcode.ret), // return (offset 15)
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 30), val.asInt());
}

test "JitExecutor nested function calls" {
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    // Bytecode layout:
    // Main: call outer, halt
    // outer: push 5, call double, ret (returns 10)
    // double: dup, add, ret

    const constants = [_]Value{
        Value.int(5),
    };

    const bytecode = [_]u8{
        // Main (offset 0):
        @intFromEnum(Opcode.call), 0, 0, 0, 8, 0, // call outer at 8 (offset 0-5)
        @intFromEnum(Opcode.halt), // halt (offset 6)
        @intFromEnum(Opcode.nop), // padding (offset 7)
        // outer at offset 8:
        @intFromEnum(Opcode.load_const), 0, 0, // push 5 (offset 8-10)
        @intFromEnum(Opcode.call), 0, 0, 0, 19, 1, // call double at 19 (offset 11-16)
        @intFromEnum(Opcode.ret), // return (offset 17)
        @intFromEnum(Opcode.nop), // padding (offset 18)
        // double at offset 19:
        @intFromEnum(Opcode.dup), // dup (offset 19)
        @intFromEnum(Opcode.add), // add (offset 20)
        @intFromEnum(Opcode.ret), // return (offset 21)
    };

    const result = try executor.run(&bytecode, &constants);
    const val = Value{ .bits = @bitCast(result) };

    try std.testing.expect(val.isInt());
    try std.testing.expectEqual(@as(i64, 10), val.asInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: VM vs JIT
// ═══════════════════════════════════════════════════════════════════════════════

test "Benchmark VM vs JIT simple" {
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
    std.debug.print("\n=== BENCHMARK: Simple Add ===\n", .{});
    std.debug.print("Iterations: {}\n", .{iterations});
    std.debug.print("VM:  {} ns total, {} ns/iter\n", .{ vm_ns, vm_ns / iterations });
    std.debug.print("JIT: {} ns total, {} ns/iter\n", .{ jit_ns, jit_ns / iterations });
    std.debug.print("Speedup: {d:.2}x\n", .{speedup});
    std.debug.print("VM result: {}, JIT result: {}\n", .{ vm_result, jit_result });

    // Verify correctness
    try std.testing.expectEqual(@as(i64, 3), vm_result);
    try std.testing.expectEqual(@as(i64, 3), jit_result);
    try std.testing.expect(speedup > 1.0);
}

test "Benchmark VM vs JIT float" {
    const vm_mod_local = @import("vm.zig");
    const iterations: u32 = 10000;

    // Float: PHI * PHI
    const constants = [_]Value{
        Value.float(value.PHI),
        Value.float(value.PHI),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0,
        @intFromEnum(Opcode.load_const), 0, 1,
        @intFromEnum(Opcode.fmul),
        @intFromEnum(Opcode.halt),
    };

    // Benchmark VM
    var vm = try vm_mod_local.VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const vm_start = std.time.nanoTimestamp();
    var vm_result: f64 = 0;
    for (0..iterations) |_| {
        vm.load(&bytecode, &constants);
        const r = try vm.run();
        vm_result = r.asFloat();
        vm.reset();
    }
    const vm_end = std.time.nanoTimestamp();
    const vm_ns = @as(u64, @intCast(vm_end - vm_start));

    // Benchmark JIT
    var executor = JitExecutor.init(std.testing.allocator);
    defer executor.deinit();

    try executor.compile(&bytecode, &constants);

    const jit_start = std.time.nanoTimestamp();
    var jit_result_raw: i64 = 0;
    for (0..iterations) |_| {
        jit_result_raw = try executor.execute();
    }
    const jit_end = std.time.nanoTimestamp();
    const jit_ns = @as(u64, @intCast(jit_end - jit_start));

    const jit_val = Value{ .bits = @bitCast(jit_result_raw) };
    const jit_result = jit_val.asFloat();

    const speedup = @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns));

    std.debug.print("\n=== BENCHMARK: Float (PHI * PHI) ===\n", .{});
    std.debug.print("VM:  {} ns/iter | JIT: {} ns/iter | Speedup: {d:.2}x\n", .{ vm_ns / iterations, jit_ns / iterations, speedup });
    std.debug.print("VM result: {d:.6}, JIT result: {d:.6}\n", .{ vm_result, jit_result });

    try std.testing.expectApproxEqAbs(value.PHI_SQ, vm_result, 0.0001);
    try std.testing.expectApproxEqAbs(value.PHI_SQ, jit_result, 0.0001);
    try std.testing.expect(speedup > 1.0);
}

test "Benchmark VM vs JIT inline double" {
    const vm_mod_local = @import("vm.zig");
    const iterations: u32 = 10000;

    // Inline double: x -> dup -> add -> 2x
    const constants = [_]Value{
        Value.int(21),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // push 21
        @intFromEnum(Opcode.dup), // dup
        @intFromEnum(Opcode.add), // add -> 42
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

    try executor.compile(&bytecode, &constants);

    const jit_start = std.time.nanoTimestamp();
    var jit_result_raw: i64 = 0;
    for (0..iterations) |_| {
        jit_result_raw = try executor.execute();
    }
    const jit_end = std.time.nanoTimestamp();
    const jit_ns = @as(u64, @intCast(jit_end - jit_start));

    const jit_val = Value{ .bits = @bitCast(jit_result_raw) };
    const jit_result = jit_val.asInt();

    const speedup = @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns));

    std.debug.print("\n=== BENCHMARK: Inline Double (dup+add) ===\n", .{});
    std.debug.print("VM:  {} ns/iter | JIT: {} ns/iter | Speedup: {d:.2}x\n", .{ vm_ns / iterations, jit_ns / iterations, speedup });
    std.debug.print("VM result: {}, JIT result: {}\n", .{ vm_result, jit_result });

    try std.testing.expectEqual(@as(i64, 42), vm_result);
    try std.testing.expectEqual(@as(i64, 42), jit_result);
    try std.testing.expect(speedup > 1.0);
}

test "Benchmark VM vs JIT arithmetic chain" {
    const vm_mod_local = @import("vm.zig");
    const iterations: u32 = 10000;

    // More complex: (10 + 5) * 3 - 2 = 43
    const constants = [_]Value{
        Value.int(10),
        Value.int(5),
        Value.int(3),
        Value.int(2),
    };
    const bytecode = [_]u8{
        @intFromEnum(Opcode.load_const), 0, 0, // 10
        @intFromEnum(Opcode.load_const), 0, 1, // 5
        @intFromEnum(Opcode.add), // 15
        @intFromEnum(Opcode.load_const), 0, 2, // 3
        @intFromEnum(Opcode.mul), // 45
        @intFromEnum(Opcode.load_const), 0, 3, // 2
        @intFromEnum(Opcode.sub), // 43
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

    try executor.compile(&bytecode, &constants);

    const jit_start = std.time.nanoTimestamp();
    var jit_result_raw: i64 = 0;
    for (0..iterations) |_| {
        jit_result_raw = try executor.execute();
    }
    const jit_end = std.time.nanoTimestamp();
    const jit_ns = @as(u64, @intCast(jit_end - jit_start));

    const jit_val = Value{ .bits = @bitCast(jit_result_raw) };
    const jit_result = jit_val.asInt();

    const speedup = @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns));

    std.debug.print("\n=== BENCHMARK: Arithmetic Chain ===\n", .{});
    std.debug.print("Expression: (10 + 5) * 3 - 2 = 43\n", .{});
    std.debug.print("VM:  {} ns/iter | JIT: {} ns/iter | Speedup: {d:.2}x\n", .{ vm_ns / iterations, jit_ns / iterations, speedup });
    std.debug.print("VM result: {}, JIT result: {}\n", .{ vm_result, jit_result });

    try std.testing.expectEqual(@as(i64, 43), vm_result);
    try std.testing.expectEqual(@as(i64, 43), jit_result);
    try std.testing.expect(speedup > 1.0);
}
