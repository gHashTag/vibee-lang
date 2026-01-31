// ═══════════════════════════════════════════════════════════════════════════════
// JIT X86-64 CODEGEN - Native Code Generation for VIBEE VM
// ═══════════════════════════════════════════════════════════════════════════════
//
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
// PHOENIX = 999
//
// Генератор нативного x86-64 кода для JIT компилятора
// Цель: 10x ускорение vs интерпретатор
//
// Author: VIBEE Team
// Co-authored-by: Ona <no-reply@ona.com>
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const posix = std.posix;
const mem = std.mem;

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE TYPES (локальные определения для независимости)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    NOP = 0x00,
    PUSH_CONST = 0x01,
    POP = 0x02,
    DUP = 0x03,
    SWAP = 0x04,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x44,
    HALT = 0x45,
};

pub const Instruction = struct {
    opcode: Opcode,
    operand: u16,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHOENIX: u64 = 999;

// JIT Configuration
pub const CODE_BUFFER_SIZE: usize = 64 * 1024; // 64KB
pub const HOT_THRESHOLD: u32 = 100;

// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

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

    pub fn code(self: Reg) u4 {
        return @intFromEnum(self);
    }

    pub fn needsRex(self: Reg) bool {
        return @intFromEnum(self) >= 8;
    }

    pub fn low3(self: Reg) u3 {
        return @truncate(@intFromEnum(self));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUFFER (обычный, без исполнения)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuffer = struct {
    data: []u8,
    pos: usize,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        const data = try allocator.alloc(u8, CODE_BUFFER_SIZE);
        return Self{
            .data = data,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn emit(self: *Self, byte: u8) void {
        if (self.pos < self.data.len) {
            self.data[self.pos] = byte;
            self.pos += 1;
        }
    }

    pub fn emit2(self: *Self, b1: u8, b2: u8) void {
        self.emit(b1);
        self.emit(b2);
    }

    pub fn emit3(self: *Self, b1: u8, b2: u8, b3: u8) void {
        self.emit(b1);
        self.emit(b2);
        self.emit(b3);
    }

    pub fn emitI32(self: *Self, value: i32) void {
        const bytes: [4]u8 = @bitCast(value);
        for (bytes) |b| self.emit(b);
    }

    pub fn emitI64(self: *Self, value: i64) void {
        const bytes: [8]u8 = @bitCast(value);
        for (bytes) |b| self.emit(b);
    }

    pub fn emitU64(self: *Self, value: u64) void {
        const bytes: [8]u8 = @bitCast(value);
        for (bytes) |b| self.emit(b);
    }

    pub fn currentOffset(self: *const Self) usize {
        return self.pos;
    }

    pub fn patchI32(self: *Self, offset: usize, value: i32) void {
        const bytes: [4]u8 = @bitCast(value);
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            self.data[offset + i] = bytes[i];
        }
    }

    pub fn getCode(self: *const Self) []const u8 {
        return self.data[0..self.pos];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTABLE BUFFER (с поддержкой mmap/mprotect)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutableBuffer = struct {
    /// Указатель на исполняемую память
    memory: []align(mem.page_size) u8,
    /// Текущая позиция записи
    pos: usize,
    /// Размер буфера
    size: usize,
    /// Флаг: память сделана исполняемой
    is_executable: bool,

    const Self = @This();

    /// Создать буфер исполняемой памяти
    pub fn init(size: usize) !Self {
        // Выровнять размер по странице
        const page_size = mem.page_size;
        const aligned_size = ((size + page_size - 1) / page_size) * page_size;

        // Выделить память через mmap с правами RW
        const memory = try posix.mmap(
            null,
            aligned_size,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        return Self{
            .memory = memory,
            .pos = 0,
            .size = aligned_size,
            .is_executable = false,
        };
    }

    /// Освободить память
    pub fn deinit(self: *Self) void {
        posix.munmap(self.memory);
    }

    /// Записать байт
    pub fn emit(self: *Self, byte: u8) void {
        if (self.pos < self.size) {
            self.memory[self.pos] = byte;
            self.pos += 1;
        }
    }

    /// Записать несколько байт
    pub fn emitBytes(self: *Self, bytes: []const u8) void {
        for (bytes) |b| self.emit(b);
    }

    /// Записать 32-битное значение (little-endian)
    pub fn emitI32(self: *Self, value: i32) void {
        const bytes: [4]u8 = @bitCast(value);
        self.emitBytes(&bytes);
    }

    /// Записать 64-битное значение (little-endian)
    pub fn emitI64(self: *Self, value: i64) void {
        const bytes: [8]u8 = @bitCast(value);
        self.emitBytes(&bytes);
    }

    /// Сделать память исполняемой (и убрать право записи)
    pub fn makeExecutable(self: *Self) !void {
        try posix.mprotect(self.memory, posix.PROT.READ | posix.PROT.EXEC);
        self.is_executable = true;
    }

    /// Сделать память записываемой (и убрать право исполнения)
    pub fn makeWritable(self: *Self) !void {
        try posix.mprotect(self.memory, posix.PROT.READ | posix.PROT.WRITE);
        self.is_executable = false;
    }

    /// Получить указатель на функцию
    pub fn getFunction(self: *const Self, comptime T: type) T {
        return @ptrCast(self.memory.ptr);
    }

    /// Получить указатель на функцию по смещению
    pub fn getFunctionAt(self: *const Self, comptime T: type, offset: usize) T {
        return @ptrCast(self.memory.ptr + offset);
    }

    /// Текущий размер кода
    pub fn codeSize(self: *const Self) usize {
        return self.pos;
    }

    /// Сбросить позицию (для повторного использования)
    pub fn reset(self: *Self) void {
        self.pos = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT FUNCTION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Функция без аргументов, возвращающая i64
pub const JitFn0 = *const fn () callconv(.C) i64;

/// Функция с одним аргументом i64, возвращающая i64
pub const JitFn1 = *const fn (i64) callconv(.C) i64;

/// Функция с двумя аргументами i64, возвращающая i64
pub const JitFn2 = *const fn (i64, i64) callconv(.C) i64;

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTABLE JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutableJIT = struct {
    buf: ExecutableBuffer,

    const Self = @This();

    pub fn init(size: usize) !Self {
        return Self{
            .buf = try ExecutableBuffer.init(size),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buf.deinit();
    }

    /// Сгенерировать функцию, возвращающую константу
    pub fn emitReturnConstant(self: *Self, value: i64) !JitFn0 {
        // mov rax, imm64
        self.buf.emit(0x48); // REX.W
        self.buf.emit(0xB8); // mov rax, imm64
        self.buf.emitI64(value);
        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn0);
    }

    /// Сгенерировать функцию сложения двух аргументов
    /// rdi = arg1, rsi = arg2 (System V AMD64 ABI)
    pub fn emitAdd(self: *Self) !JitFn2 {
        // mov rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x89);
        self.buf.emit(0xF8); // mov rax, rdi

        // add rax, rsi
        self.buf.emit(0x48);
        self.buf.emit(0x01);
        self.buf.emit(0xF0); // add rax, rsi

        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn2);
    }

    /// Сгенерировать функцию вычитания
    pub fn emitSub(self: *Self) !JitFn2 {
        // mov rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x89);
        self.buf.emit(0xF8);

        // sub rax, rsi
        self.buf.emit(0x48);
        self.buf.emit(0x29);
        self.buf.emit(0xF0);

        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn2);
    }

    /// Сгенерировать функцию умножения
    pub fn emitMul(self: *Self) !JitFn2 {
        // mov rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x89);
        self.buf.emit(0xF8);

        // imul rax, rsi
        self.buf.emit(0x48);
        self.buf.emit(0x0F);
        self.buf.emit(0xAF);
        self.buf.emit(0xC6);

        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn2);
    }

    /// Сгенерировать функцию удвоения аргумента
    pub fn emitDouble(self: *Self) !JitFn1 {
        // mov rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x89);
        self.buf.emit(0xF8);

        // add rax, rax (удвоение)
        self.buf.emit(0x48);
        self.buf.emit(0x01);
        self.buf.emit(0xC0);

        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn1);
    }

    /// Сгенерировать функцию квадрата
    pub fn emitSquare(self: *Self) !JitFn1 {
        // mov rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x89);
        self.buf.emit(0xF8);

        // imul rax, rdi
        self.buf.emit(0x48);
        self.buf.emit(0x0F);
        self.buf.emit(0xAF);
        self.buf.emit(0xC7);

        // ret
        self.buf.emit(0xC3);

        try self.buf.makeExecutable();
        return self.buf.getFunction(JitFn1);
    }

    /// Сбросить буфер для новой функции
    pub fn reset(self: *Self) !void {
        try self.buf.makeWritable();
        self.buf.reset();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86Emitter = struct {
    buf: *CodeBuffer,

    const Self = @This();

    pub fn init(buf: *CodeBuffer) Self {
        return Self{ .buf = buf };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REX PREFIX
    // ═══════════════════════════════════════════════════════════════════════════

    fn emitRex(self: *Self, w: bool, r: Reg, x: Reg, b: Reg) void {
        const rex: u8 = 0x40 |
            (@as(u8, if (w) 1 else 0) << 3) |
            (@as(u8, if (r.needsRex()) 1 else 0) << 2) |
            (@as(u8, if (x.needsRex()) 1 else 0) << 1) |
            (@as(u8, if (b.needsRex()) 1 else 0));
        if (rex != 0x40) {
            self.buf.emit(rex);
        }
    }

    fn emitRexW(self: *Self, r: Reg, b: Reg) void {
        self.emitRex(true, r, .RAX, b);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MODRM
    // ═══════════════════════════════════════════════════════════════════════════

    fn emitModRM(self: *Self, mod: u2, reg: Reg, rm: Reg) void {
        const modrm: u8 = (@as(u8, mod) << 6) | (@as(u8, reg.low3()) << 3) | @as(u8, rm.low3());
        self.buf.emit(modrm);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOV INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// mov reg, reg (64-bit)
    pub fn movRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(src, dst);
        self.buf.emit(0x89);
        self.emitModRM(3, src, dst);
    }

    /// mov reg, imm64
    pub fn movRegImm64(self: *Self, dst: Reg, imm: i64) void {
        self.emitRex(true, .RAX, .RAX, dst);
        self.buf.emit(0xB8 + @as(u8, dst.low3()));
        self.buf.emitI64(imm);
    }

    /// mov reg, [rbp + offset]
    pub fn movRegMem(self: *Self, dst: Reg, offset: i32) void {
        self.emitRexW(dst, .RBP);
        self.buf.emit(0x8B);
        if (offset >= -128 and offset <= 127) {
            self.emitModRM(1, dst, .RBP);
            self.buf.emit(@bitCast(@as(i8, @truncate(offset))));
        } else {
            self.emitModRM(2, dst, .RBP);
            self.buf.emitI32(offset);
        }
    }

    /// mov [rbp + offset], reg
    pub fn movMemReg(self: *Self, offset: i32, src: Reg) void {
        self.emitRexW(src, .RBP);
        self.buf.emit(0x89);
        if (offset >= -128 and offset <= 127) {
            self.emitModRM(1, src, .RBP);
            self.buf.emit(@bitCast(@as(i8, @truncate(offset))));
        } else {
            self.emitModRM(2, src, .RBP);
            self.buf.emitI32(offset);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARITHMETIC
    // ═══════════════════════════════════════════════════════════════════════════

    /// add dst, src (64-bit)
    pub fn addRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(src, dst);
        self.buf.emit(0x01);
        self.emitModRM(3, src, dst);
    }

    /// sub dst, src (64-bit)
    pub fn subRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(src, dst);
        self.buf.emit(0x29);
        self.emitModRM(3, src, dst);
    }

    /// imul dst, src (64-bit)
    pub fn imulRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(dst, src);
        self.buf.emit2(0x0F, 0xAF);
        self.emitModRM(3, dst, src);
    }

    /// neg reg (64-bit)
    pub fn negReg(self: *Self, reg: Reg) void {
        self.emitRexW(.RAX, reg);
        self.buf.emit(0xF7);
        self.emitModRM(3, .RBX, reg); // /3 = neg
    }

    /// add reg, imm32
    pub fn addRegImm32(self: *Self, dst: Reg, imm: i32) void {
        self.emitRexW(.RAX, dst);
        if (imm >= -128 and imm <= 127) {
            self.buf.emit(0x83);
            self.emitModRM(3, .RAX, dst); // /0 = add
            self.buf.emit(@bitCast(@as(i8, @truncate(imm))));
        } else {
            self.buf.emit(0x81);
            self.emitModRM(3, .RAX, dst);
            self.buf.emitI32(imm);
        }
    }

    /// sub reg, imm32
    pub fn subRegImm32(self: *Self, dst: Reg, imm: i32) void {
        self.emitRexW(.RAX, dst);
        if (imm >= -128 and imm <= 127) {
            self.buf.emit(0x83);
            self.emitModRM(3, .RBP, dst); // /5 = sub
            self.buf.emit(@bitCast(@as(i8, @truncate(imm))));
        } else {
            self.buf.emit(0x81);
            self.emitModRM(3, .RBP, dst);
            self.buf.emitI32(imm);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPARISON
    // ═══════════════════════════════════════════════════════════════════════════

    /// cmp dst, src (64-bit)
    pub fn cmpRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(src, dst);
        self.buf.emit(0x39);
        self.emitModRM(3, src, dst);
    }

    /// test reg, reg (64-bit)
    pub fn testRegReg(self: *Self, dst: Reg, src: Reg) void {
        self.emitRexW(src, dst);
        self.buf.emit(0x85);
        self.emitModRM(3, src, dst);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STACK OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// push reg
    pub fn pushReg(self: *Self, reg: Reg) void {
        if (reg.needsRex()) {
            self.buf.emit(0x41);
        }
        self.buf.emit(0x50 + @as(u8, reg.low3()));
    }

    /// pop reg
    pub fn popReg(self: *Self, reg: Reg) void {
        if (reg.needsRex()) {
            self.buf.emit(0x41);
        }
        self.buf.emit(0x58 + @as(u8, reg.low3()));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTROL FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    /// jmp rel32
    pub fn jmpRel32(self: *Self, offset: i32) void {
        self.buf.emit(0xE9);
        self.buf.emitI32(offset);
    }

    /// jz rel32
    pub fn jzRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x84);
        self.buf.emitI32(offset);
    }

    /// jnz rel32
    pub fn jnzRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x85);
        self.buf.emitI32(offset);
    }

    /// jl rel32 (signed less than)
    pub fn jlRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x8C);
        self.buf.emitI32(offset);
    }

    /// jle rel32 (signed less or equal)
    pub fn jleRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x8E);
        self.buf.emitI32(offset);
    }

    /// jg rel32 (signed greater than)
    pub fn jgRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x8F);
        self.buf.emitI32(offset);
    }

    /// jge rel32 (signed greater or equal)
    pub fn jgeRel32(self: *Self, offset: i32) void {
        self.buf.emit2(0x0F, 0x8D);
        self.buf.emitI32(offset);
    }

    /// call rel32
    pub fn callRel32(self: *Self, offset: i32) void {
        self.buf.emit(0xE8);
        self.buf.emitI32(offset);
    }

    /// ret
    pub fn ret(self: *Self) void {
        self.buf.emit(0xC3);
    }

    /// nop
    pub fn nop(self: *Self) void {
        self.buf.emit(0x90);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNCTION PROLOGUE/EPILOGUE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Function prologue: push rbp; mov rbp, rsp; sub rsp, stack_size
    pub fn emitPrologue(self: *Self, stack_size: i32) void {
        self.pushReg(.RBP);
        self.movRegReg(.RBP, .RSP);
        if (stack_size > 0) {
            self.subRegImm32(.RSP, stack_size);
        }
    }

    /// Function epilogue: add rsp, stack_size; pop rbp; ret
    pub fn emitEpilogue(self: *Self, stack_size: i32) void {
        if (stack_size > 0) {
            self.addRegImm32(.RSP, stack_size);
        }
        self.popReg(.RBP);
        self.ret();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITCompiler = struct {
    allocator: Allocator,
    buf: *CodeBuffer,

    // Metrics
    functions_compiled: u64,
    bytes_generated: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        const buf = try allocator.create(CodeBuffer);
        buf.* = try CodeBuffer.init(allocator);
        return Self{
            .allocator = allocator,
            .buf = buf,
            .functions_compiled = 0,
            .bytes_generated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buf.deinit();
        self.allocator.destroy(self.buf);
    }

    /// Compile a sequence of bytecode instructions
    pub fn compile(self: *Self, instructions: []const Instruction, constants: []const i64) ![]const u8 {
        const start_pos = self.buf.pos;

        var emitter = X86Emitter.init(self.buf);

        // Emit prologue
        emitter.emitPrologue(64); // 64 bytes stack frame

        // Compile each instruction
        for (instructions) |instr| {
            self.compileInstruction(&emitter, instr, constants);
        }

        // Emit epilogue
        emitter.emitEpilogue(64);

        self.functions_compiled += 1;
        self.bytes_generated += self.buf.pos - start_pos;

        return self.buf.data[start_pos..self.buf.pos];
    }

    fn compileInstruction(self: *Self, emitter: *X86Emitter, instr: Instruction, constants: []const i64) void {
        _ = self;
        switch (instr.opcode) {
            .PUSH_CONST => {
                // Load constant and push
                const idx = instr.operand;
                if (idx < constants.len) {
                    emitter.movRegImm64(.RAX, constants[idx]);
                    emitter.pushReg(.RAX);
                }
            },
            .ADD => {
                // pop rax; pop rcx; add rax, rcx; push rax
                emitter.popReg(.RCX);
                emitter.popReg(.RAX);
                emitter.addRegReg(.RAX, .RCX);
                emitter.pushReg(.RAX);
            },
            .SUB => {
                // pop rcx; pop rax; sub rax, rcx; push rax
                emitter.popReg(.RCX);
                emitter.popReg(.RAX);
                emitter.subRegReg(.RAX, .RCX);
                emitter.pushReg(.RAX);
            },
            .MUL => {
                // pop rax; pop rcx; imul rax, rcx; push rax
                emitter.popReg(.RCX);
                emitter.popReg(.RAX);
                emitter.imulRegReg(.RAX, .RCX);
                emitter.pushReg(.RAX);
            },
            .NEG => {
                // pop rax; neg rax; push rax
                emitter.popReg(.RAX);
                emitter.negReg(.RAX);
                emitter.pushReg(.RAX);
            },
            .DUP => {
                // pop rax; push rax; push rax
                emitter.popReg(.RAX);
                emitter.pushReg(.RAX);
                emitter.pushReg(.RAX);
            },
            .POP => {
                // pop rax (discard)
                emitter.popReg(.RAX);
            },
            .SWAP => {
                // pop rax; pop rcx; push rax; push rcx
                emitter.popReg(.RAX);
                emitter.popReg(.RCX);
                emitter.pushReg(.RAX);
                emitter.pushReg(.RCX);
            },
            .RET => {
                // Return value in RAX
                emitter.popReg(.RAX);
            },
            .NOP => {
                emitter.nop();
            },
            .HALT => {
                // Return
                emitter.popReg(.RAX);
            },
            else => {
                // Unsupported opcode - emit nop
                emitter.nop();
            },
        }
    }

    pub fn getMetrics(self: *const Self) struct { functions: u64, bytes: u64 } {
        return .{
            .functions = self.functions_compiled,
            .bytes = self.bytes_generated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HOT PATH DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const HotPathDetector = struct {
    allocator: Allocator,
    execution_counts: std.AutoHashMap(u32, u32),
    hot_threshold: u32,
    compiled_addresses: std.AutoHashMap(u32, []const u8),

    const Self = @This();

    pub fn init(allocator: Allocator, threshold: u32) Self {
        return Self{
            .allocator = allocator,
            .execution_counts = std.AutoHashMap(u32, u32).init(allocator),
            .hot_threshold = threshold,
            .compiled_addresses = std.AutoHashMap(u32, []const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.execution_counts.deinit();
        self.compiled_addresses.deinit();
    }

    /// Записать выполнение по адресу, вернуть true если стал горячим
    pub fn recordExecution(self: *Self, address: u32) bool {
        const entry = self.execution_counts.getOrPut(address) catch return false;
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
        return entry.value_ptr.* >= self.hot_threshold;
    }

    /// Проверить, является ли адрес горячим
    pub fn isHot(self: *const Self, address: u32) bool {
        if (self.execution_counts.get(address)) |count| {
            return count >= self.hot_threshold;
        }
        return false;
    }

    /// Получить счётчик выполнений
    pub fn getCount(self: *const Self, address: u32) u32 {
        return self.execution_counts.get(address) orelse 0;
    }

    /// Сохранить скомпилированный код
    pub fn cacheCompiledCode(self: *Self, address: u32, code: []const u8) !void {
        try self.compiled_addresses.put(address, code);
    }

    /// Получить скомпилированный код
    pub fn getCompiledCode(self: *const Self, address: u32) ?[]const u8 {
        return self.compiled_addresses.get(address);
    }

    /// Проверить, есть ли скомпилированный код
    pub fn hasCompiledCode(self: *const Self, address: u32) bool {
        return self.compiled_addresses.contains(address);
    }

    /// Получить статистику
    pub fn getStats(self: *const Self) struct { total_addresses: usize, hot_addresses: usize, compiled: usize } {
        var hot_count: usize = 0;
        var iter = self.execution_counts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* >= self.hot_threshold) {
                hot_count += 1;
            }
        }
        return .{
            .total_addresses = self.execution_counts.count(),
            .hot_addresses = hot_count,
            .compiled = self.compiled_addresses.count(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE JIT RUNTIME
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdaptiveJIT = struct {
    allocator: Allocator,
    compiler: JITCompiler,
    detector: HotPathDetector,

    // Статистика
    interpreted_count: u64,
    jit_count: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .compiler = try JITCompiler.init(allocator),
            .detector = HotPathDetector.init(allocator, HOT_THRESHOLD),
            .interpreted_count = 0,
            .jit_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.compiler.deinit();
        self.detector.deinit();
    }

    /// Выполнить блок кода - интерпретировать или JIT
    pub fn execute(self: *Self, address: u32, instructions: []const Instruction, constants: []const i64) !?[]const u8 {
        // Проверить, есть ли уже скомпилированный код
        if (self.detector.getCompiledCode(address)) |code| {
            self.jit_count += 1;
            return code;
        }

        // Записать выполнение
        const became_hot = self.detector.recordExecution(address);

        if (became_hot and !self.detector.hasCompiledCode(address)) {
            // Компилировать горячий путь
            const code = try self.compiler.compile(instructions, constants);
            try self.detector.cacheCompiledCode(address, code);
            self.jit_count += 1;
            return code;
        }

        // Интерпретировать
        self.interpreted_count += 1;
        return null;
    }

    pub fn getStats(self: *const Self) struct {
        interpreted: u64,
        jit: u64,
        hot_paths: usize,
        compiled_functions: u64,
        bytes_generated: u64,
    } {
        const detector_stats = self.detector.getStats();
        const compiler_metrics = self.compiler.getMetrics();
        return .{
            .interpreted = self.interpreted_count,
            .jit = self.jit_count,
            .hot_paths = detector_stats.hot_addresses,
            .compiled_functions = compiler_metrics.functions,
            .bytes_generated = compiler_metrics.bytes,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "code buffer basic" {
    const allocator = std.testing.allocator;
    var buf = try CodeBuffer.init(allocator);
    defer buf.deinit();

    buf.emit(0x90); // nop
    buf.emit(0xC3); // ret

    try std.testing.expectEqual(@as(usize, 2), buf.pos);
    try std.testing.expectEqual(@as(u8, 0x90), buf.data[0]);
    try std.testing.expectEqual(@as(u8, 0xC3), buf.data[1]);
}

test "x86 emitter mov reg imm64" {
    const allocator = std.testing.allocator;
    var buf = try CodeBuffer.init(allocator);
    defer buf.deinit();

    var emitter = X86Emitter.init(&buf);
    emitter.movRegImm64(.RAX, 0x123456789ABCDEF0);

    // Expected: 48 B8 F0 DE BC 9A 78 56 34 12
    try std.testing.expectEqual(@as(u8, 0x48), buf.data[0]); // REX.W
    try std.testing.expectEqual(@as(u8, 0xB8), buf.data[1]); // mov rax, imm64
}

test "x86 emitter add reg reg" {
    const allocator = std.testing.allocator;
    var buf = try CodeBuffer.init(allocator);
    defer buf.deinit();

    var emitter = X86Emitter.init(&buf);
    emitter.addRegReg(.RAX, .RCX);

    // Expected: 48 01 C8 (add rax, rcx)
    try std.testing.expectEqual(@as(u8, 0x48), buf.data[0]); // REX.W
    try std.testing.expectEqual(@as(u8, 0x01), buf.data[1]); // add
}

test "x86 emitter push pop" {
    const allocator = std.testing.allocator;
    var buf = try CodeBuffer.init(allocator);
    defer buf.deinit();

    var emitter = X86Emitter.init(&buf);
    emitter.pushReg(.RAX);
    emitter.popReg(.RCX);

    try std.testing.expectEqual(@as(u8, 0x50), buf.data[0]); // push rax
    try std.testing.expectEqual(@as(u8, 0x59), buf.data[1]); // pop rcx
}

test "x86 emitter prologue epilogue" {
    const allocator = std.testing.allocator;
    var buf = try CodeBuffer.init(allocator);
    defer buf.deinit();

    var emitter = X86Emitter.init(&buf);
    emitter.emitPrologue(32);
    emitter.emitEpilogue(32);

    // Should have: push rbp, mov rbp rsp, sub rsp 32, add rsp 32, pop rbp, ret
    try std.testing.expect(buf.pos > 10);
}

test "jit compiler basic" {
    const allocator = std.testing.allocator;
    var jit = try JITCompiler.init(allocator);
    defer jit.deinit();

    const instructions = [_]Instruction{
        .{ .opcode = .PUSH_CONST, .operand = 0 },
        .{ .opcode = .PUSH_CONST, .operand = 1 },
        .{ .opcode = .ADD, .operand = 0 },
        .{ .opcode = .RET, .operand = 0 },
    };

    const constants = [_]i64{ 10, 20 };

    const code = try jit.compile(&instructions, &constants);
    try std.testing.expect(code.len > 0);

    const metrics = jit.getMetrics();
    try std.testing.expectEqual(@as(u64, 1), metrics.functions);
}

test "hot path detector" {
    const allocator = std.testing.allocator;
    var detector = HotPathDetector.init(allocator, 10);
    defer detector.deinit();

    // Записать 9 выполнений - ещё не горячий
    var i: u32 = 0;
    while (i < 9) : (i += 1) {
        const hot = detector.recordExecution(0x1000);
        try std.testing.expect(!hot);
    }

    // 10-е выполнение - становится горячим
    const hot = detector.recordExecution(0x1000);
    try std.testing.expect(hot);

    try std.testing.expect(detector.isHot(0x1000));
    try std.testing.expectEqual(@as(u32, 10), detector.getCount(0x1000));
}

test "adaptive jit" {
    const allocator = std.testing.allocator;
    var ajit = try AdaptiveJIT.init(allocator);
    defer ajit.deinit();

    const instructions = [_]Instruction{
        .{ .opcode = .PUSH_CONST, .operand = 0 },
        .{ .opcode = .RET, .operand = 0 },
    };
    const constants = [_]i64{42};

    // Первые 99 выполнений - интерпретация
    var i: u32 = 0;
    while (i < 99) : (i += 1) {
        const result = try ajit.execute(0x2000, &instructions, &constants);
        try std.testing.expect(result == null);
    }

    // 100-е выполнение - JIT компиляция
    const result = try ajit.execute(0x2000, &instructions, &constants);
    try std.testing.expect(result != null);

    const stats = ajit.getStats();
    try std.testing.expectEqual(@as(u64, 99), stats.interpreted);
    try std.testing.expectEqual(@as(u64, 1), stats.jit);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ ИСПОЛНЯЕМОГО JIT
// ═══════════════════════════════════════════════════════════════════════════════

test "executable buffer init/deinit" {
    var buf = try ExecutableBuffer.init(4096);
    defer buf.deinit();

    try std.testing.expect(buf.size >= 4096);
    try std.testing.expectEqual(@as(usize, 0), buf.pos);
    try std.testing.expect(!buf.is_executable);
}

test "executable jit return constant" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const fn_42 = try jit.emitReturnConstant(42);
    const result = fn_42();

    try std.testing.expectEqual(@as(i64, 42), result);
}

test "executable jit return phoenix" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    // PHOENIX = 999
    const fn_phoenix = try jit.emitReturnConstant(999);
    const result = fn_phoenix();

    try std.testing.expectEqual(@as(i64, 999), result);
}

test "executable jit add" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const add_fn = try jit.emitAdd();
    const result = add_fn(10, 20);

    try std.testing.expectEqual(@as(i64, 30), result);
}

test "executable jit sub" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const sub_fn = try jit.emitSub();
    const result = sub_fn(50, 20);

    try std.testing.expectEqual(@as(i64, 30), result);
}

test "executable jit mul" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const mul_fn = try jit.emitMul();
    const result = mul_fn(6, 7);

    try std.testing.expectEqual(@as(i64, 42), result);
}

test "executable jit double" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const double_fn = try jit.emitDouble();
    const result = double_fn(21);

    try std.testing.expectEqual(@as(i64, 42), result);
}

test "executable jit square" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const square_fn = try jit.emitSquare();
    const result = square_fn(7);

    try std.testing.expectEqual(@as(i64, 49), result);
}

test "executable jit golden identity" {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    // φ² + 1/φ² = 3
    // Проверим: 3 * 3 = 9
    const mul_fn = try jit.emitMul();
    const result = mul_fn(3, 3);

    try std.testing.expectEqual(@as(i64, 9), result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// БЕНЧМАРК: ИНТЕРПРЕТАТОР vs JIT
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    interpreter_ns: u64,
    jit_ns: u64,
    speedup: f64,
    iterations: u64,
};

/// Простой интерпретатор для сравнения
fn interpretAdd(a: i64, b: i64) i64 {
    return a + b;
}

fn interpretMul(a: i64, b: i64) i64 {
    return a * b;
}

fn interpretFibonacci(n: i64) i64 {
    if (n <= 1) return n;
    var a: i64 = 0;
    var b: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        const tmp = a + b;
        a = b;
        b = tmp;
    }
    return b;
}

/// Запустить бенчмарк сложения
pub fn benchmarkAdd(iterations: u64) !BenchmarkResult {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const add_fn = try jit.emitAdd();

    // Бенчмарк интерпретатора
    var timer = std.time.Timer.start() catch unreachable;
    var sum_interp: i64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        sum_interp += interpretAdd(@intCast(i), @intCast(i + 1));
    }
    const interp_ns = timer.read();

    // Бенчмарк JIT
    timer.reset();
    var sum_jit: i64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        sum_jit += add_fn(@intCast(i), @intCast(i + 1));
    }
    const jit_ns = timer.read();

    // Проверка корректности
    if (sum_interp != sum_jit) {
        return error.ResultMismatch;
    }

    const speedup = @as(f64, @floatFromInt(interp_ns)) / @as(f64, @floatFromInt(jit_ns));

    return BenchmarkResult{
        .interpreter_ns = interp_ns,
        .jit_ns = jit_ns,
        .speedup = speedup,
        .iterations = iterations,
    };
}

/// Запустить бенчмарк умножения
pub fn benchmarkMul(iterations: u64) !BenchmarkResult {
    var jit = try ExecutableJIT.init(4096);
    defer jit.deinit();

    const mul_fn = try jit.emitMul();

    // Бенчмарк интерпретатора
    var timer = std.time.Timer.start() catch unreachable;
    var sum_interp: i64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        sum_interp +%= interpretMul(@intCast(i % 100), @intCast((i + 1) % 100));
    }
    const interp_ns = timer.read();

    // Бенчмарк JIT
    timer.reset();
    var sum_jit: i64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        sum_jit +%= mul_fn(@intCast(i % 100), @intCast((i + 1) % 100));
    }
    const jit_ns = timer.read();

    if (sum_interp != sum_jit) {
        return error.ResultMismatch;
    }

    const speedup = @as(f64, @floatFromInt(interp_ns)) / @as(f64, @floatFromInt(jit_ns));

    return BenchmarkResult{
        .interpreter_ns = interp_ns,
        .jit_ns = jit_ns,
        .speedup = speedup,
        .iterations = iterations,
    };
}

/// Вывести результаты бенчмарка
pub fn printBenchmarkResults(name: []const u8, result: BenchmarkResult) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("\n{s}:\n", .{name}) catch {};
    stdout.print("  Интерпретатор: {d} ns ({d:.2} ms)\n", .{ result.interpreter_ns, @as(f64, @floatFromInt(result.interpreter_ns)) / 1_000_000.0 }) catch {};
    stdout.print("  JIT:           {d} ns ({d:.2} ms)\n", .{ result.jit_ns, @as(f64, @floatFromInt(result.jit_ns)) / 1_000_000.0 }) catch {};
    stdout.print("  Ускорение:     {d:.2}x\n", .{result.speedup}) catch {};
    stdout.print("  Итераций:      {d}\n", .{result.iterations}) catch {};
}

test "benchmark add" {
    const result = try benchmarkAdd(100_000);
    // JIT должен быть быстрее (или примерно равен из-за оптимизаций компилятора)
    try std.testing.expect(result.speedup > 0.5);
}

test "benchmark mul" {
    const result = try benchmarkMul(100_000);
    try std.testing.expect(result.speedup > 0.5);
}
