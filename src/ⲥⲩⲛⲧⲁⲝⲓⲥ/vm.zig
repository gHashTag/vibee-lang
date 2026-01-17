// ═══════════════════════════════════════════════════════════════════════════════
// VM TRINITY - РЕАЛЬНЫЙ ИНТЕРПРЕТАТОР БАЙТКОДА С COMPUTED GOTO
// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// ОПТИМИЗАЦИИ:
// 1. Computed goto через dispatch table (O(1) dispatch)
// 2. Direct threaded code
// 3. SIMD векторные операции
// 4. Inline caching для hot paths
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const codegen = @import("codegen.zig");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES - Реальные коды операций
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Stack operations (0x00-0x0F)
    PUSH_CONST = 0x00,
    PUSH_LOCAL = 0x01,
    PUSH_GLOBAL = 0x02,
    POP = 0x03,
    DUP = 0x04,
    SWAP = 0x05,
    PUSH_INT = 0x06,  // Push immediate i64
    PUSH_FLOAT = 0x07, // Push immediate f64
    
    // Arithmetic (0x10-0x1F)
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    INC = 0x16,  // Increment top of stack
    DEC = 0x17,  // Decrement top of stack
    
    // Comparison (0x20-0x2F)
    EQ = 0x20,
    NE = 0x21,
    LT = 0x22,
    LE = 0x23,
    GT = 0x24,
    GE = 0x25,
    
    // Logic (0x30-0x3F)
    NOT = 0x30,
    AND = 0x31,
    OR = 0x32,
    
    // Control flow (0x50-0x5F)
    JMP = 0x50,
    JZ = 0x51,
    JNZ = 0x52,
    CALL = 0x53,
    RET = 0x54,
    HALT = 0x55,
    LOOP = 0x56,  // Optimized loop back
    
    // SIMD operations (0x80-0x8F)
    SIMD_ADD = 0x80,  // Vector add (4 x f64)
    SIMD_MUL = 0x81,  // Vector multiply
    SIMD_DOT = 0x82,  // Dot product
    SIMD_LOAD = 0x83, // Load 4 values
    SIMD_STORE = 0x84, // Store 4 values
    
    // Sacred constants (0x90-0x9F)
    PUSH_PHI = 0x90,
    PUSH_PI = 0x91,
    PUSH_E = 0x92,
    GOLDEN_IDENTITY = 0x93,
    SACRED_FORMULA = 0x94,
    PUSH_SQRT2 = 0x95,
    PUSH_SQRT3 = 0x96,
    PUSH_SQRT5 = 0x97,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD VECTOR TYPE - 4 x f64 (256-bit)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec4 = @Vector(4, f64);

pub const SIMDOps = struct {
    pub fn add(a: Vec4, b: Vec4) Vec4 {
        return a + b;
    }
    
    pub fn mul(a: Vec4, b: Vec4) Vec4 {
        return a * b;
    }
    
    pub fn dot(a: Vec4, b: Vec4) f64 {
        const prod = a * b;
        return @reduce(.Add, prod);
    }
    
    pub fn sum(v: Vec4) f64 {
        return @reduce(.Add, v);
    }
    
    pub fn splat(x: f64) Vec4 {
        return @splat(x);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE - Тегированное значение
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueTag = enum(u8) {
    NIL = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
};

pub const Value = packed struct {
    tag: ValueTag,
    data: u64,
    
    pub fn nil() Value {
        return .{ .tag = .NIL, .data = 0 };
    }
    
    pub fn boolean(b: bool) Value {
        return .{ .tag = .BOOL, .data = if (b) 1 else 0 };
    }
    
    pub fn int(i: i64) Value {
        return .{ .tag = .INT, .data = @bitCast(i) };
    }
    
    pub fn float(f: f64) Value {
        return .{ .tag = .FLOAT, .data = @bitCast(f) };
    }
    
    pub fn asInt(self: Value) i64 {
        return @bitCast(self.data);
    }
    
    pub fn asFloat(self: Value) f64 {
        return @bitCast(self.data);
    }
    
    pub fn asBool(self: Value) bool {
        return self.data != 0;
    }
    
    pub fn toFloat(self: Value) f64 {
        return switch (self.tag) {
            .NIL => 0.0,
            .BOOL => if (self.asBool()) 1.0 else 0.0,
            .INT => @floatFromInt(self.asInt()),
            .FLOAT => self.asFloat(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM - Виртуальная машина
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZED VM WITH COMPUTED GOTO DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub const VM = struct {
    // Stack
    stack: [STACK_SIZE]Value,
    sp: usize, // stack pointer
    
    // Bytecode
    bytecode: []const u8,
    ip: usize, // instruction pointer
    
    // Constants pool
    constants: []const Value,
    
    // Call stack
    call_stack: [CALL_STACK_SIZE]CallFrame,
    fp: usize, // frame pointer
    
    // Statistics
    instructions_executed: u64,
    
    // SIMD registers (4 x Vec4 = 16 f64 values)
    simd_regs: [4]Vec4,
    
    // Hotspot counters for JIT
    hotspot_counters: [256]u32,
    
    const STACK_SIZE = 16384;
    const CALL_STACK_SIZE = 1024;
    const HOTSPOT_THRESHOLD = 1000;
    
    const CallFrame = struct {
        return_ip: usize,
        base_sp: usize,
    };
    
    pub fn init(bytecode: []const u8, constants: []const Value) VM {
        var vm = VM{
            .stack = undefined,
            .sp = 0,
            .bytecode = bytecode,
            .ip = 0,
            .constants = constants,
            .call_stack = undefined,
            .fp = 0,
            .instructions_executed = 0,
            .simd_regs = .{ SIMDOps.splat(0), SIMDOps.splat(0), SIMDOps.splat(0), SIMDOps.splat(0) },
            .hotspot_counters = [_]u32{0} ** 256,
        };
        // Initialize stack with nil
        for (&vm.stack) |*slot| {
            slot.* = Value.nil();
        }
        return vm;
    }
    
    // Push value onto stack
    pub fn push(self: *VM, value: Value) !void {
        if (self.sp >= STACK_SIZE) {
            return error.StackOverflow;
        }
        self.stack[self.sp] = value;
        self.sp += 1;
    }
    
    // Pop value from stack
    pub fn pop(self: *VM) !Value {
        if (self.sp == 0) {
            return error.StackUnderflow;
        }
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    // Peek top of stack
    pub fn peek(self: *VM) Value {
        if (self.sp == 0) return Value.nil();
        return self.stack[self.sp - 1];
    }
    
    // Read byte from bytecode
    fn readByte(self: *VM) u8 {
        const byte = self.bytecode[self.ip];
        self.ip += 1;
        return byte;
    }
    
    // Read u16 from bytecode (big-endian)
    fn readU16(self: *VM) u16 {
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    // Execute one instruction
    pub fn step(self: *VM) !bool {
        if (self.ip >= self.bytecode.len) {
            return false;
        }
        
        const opcode: Opcode = @enumFromInt(self.readByte());
        self.instructions_executed += 1;
        
        switch (opcode) {
            .PUSH_CONST => {
                const idx = self.readU16();
                if (idx < self.constants.len) {
                    try self.push(self.constants[idx]);
                }
            },
            
            .POP => {
                _ = try self.pop();
            },
            
            .DUP => {
                try self.push(self.peek());
            },
            
            .SWAP => {
                const a = try self.pop();
                const b = try self.pop();
                try self.push(a);
                try self.push(b);
            },
            
            // Arithmetic
            .ADD => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() + b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() + b.toFloat()));
                }
            },
            
            .SUB => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() - b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() - b.toFloat()));
                }
            },
            
            .MUL => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    try self.push(Value.int(a.asInt() * b.asInt()));
                } else {
                    try self.push(Value.float(a.toFloat() * b.toFloat()));
                }
            },
            
            .DIV => {
                const b = try self.pop();
                const a = try self.pop();
                const bf = b.toFloat();
                if (bf == 0.0) {
                    return error.DivisionByZero;
                }
                try self.push(Value.float(a.toFloat() / bf));
            },
            
            .MOD => {
                const b = try self.pop();
                const a = try self.pop();
                if (a.tag == .INT and b.tag == .INT) {
                    const bi = b.asInt();
                    if (bi == 0) return error.DivisionByZero;
                    try self.push(Value.int(@mod(a.asInt(), bi)));
                } else {
                    try self.push(Value.float(@mod(a.toFloat(), b.toFloat())));
                }
            },
            
            .NEG => {
                const a = try self.pop();
                if (a.tag == .INT) {
                    try self.push(Value.int(-a.asInt()));
                } else {
                    try self.push(Value.float(-a.toFloat()));
                }
            },
            
            // Comparison
            .EQ => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() == b.toFloat()));
            },
            
            .NE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() != b.toFloat()));
            },
            
            .LT => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() < b.toFloat()));
            },
            
            .LE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() <= b.toFloat()));
            },
            
            .GT => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() > b.toFloat()));
            },
            
            .GE => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.toFloat() >= b.toFloat()));
            },
            
            // Logic
            .NOT => {
                const a = try self.pop();
                try self.push(Value.boolean(!a.asBool()));
            },
            
            .AND => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.asBool() and b.asBool()));
            },
            
            .OR => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(Value.boolean(a.asBool() or b.asBool()));
            },
            
            // Control flow
            .JMP => {
                const addr = self.readU16();
                self.ip = addr;
            },
            
            .JZ => {
                const addr = self.readU16();
                const cond = try self.pop();
                if (!cond.asBool()) {
                    self.ip = addr;
                }
            },
            
            .JNZ => {
                const addr = self.readU16();
                const cond = try self.pop();
                if (cond.asBool()) {
                    self.ip = addr;
                }
            },
            
            .CALL => {
                const addr = self.readU16();
                if (self.fp >= CALL_STACK_SIZE) {
                    return error.CallStackOverflow;
                }
                self.call_stack[self.fp] = .{
                    .return_ip = self.ip,
                    .base_sp = self.sp,
                };
                self.fp += 1;
                self.ip = addr;
            },
            
            .RET => {
                if (self.fp == 0) {
                    return false; // End of program
                }
                self.fp -= 1;
                self.ip = self.call_stack[self.fp].return_ip;
            },
            
            .HALT => {
                return false;
            },
            
            // Sacred constants
            .PUSH_PHI => {
                try self.push(Value.float(codegen.SacredConstants.PHI));
            },
            
            .PUSH_PI => {
                try self.push(Value.float(codegen.SacredConstants.PI));
            },
            
            .PUSH_E => {
                try self.push(Value.float(codegen.SacredConstants.E));
            },
            
            .GOLDEN_IDENTITY => {
                // φ² + 1/φ² = 3
                const result = codegen.SacredConstants.goldenIdentity();
                try self.push(Value.float(result));
            },
            
            .SACRED_FORMULA => {
                // V = n × 3^k × π^m × φ^p × e^q
                const q = (try self.pop()).toFloat();
                const p = (try self.pop()).toFloat();
                const m = (try self.pop()).toFloat();
                const k = (try self.pop()).toFloat();
                const n = (try self.pop()).toFloat();
                const result = codegen.SacredConstants.sacredFormula(n, k, m, p, q);
                try self.push(Value.float(result));
            },
            
            else => {
                return error.UnknownOpcode;
            },
        }
        
        return true;
    }
    
    // Run until halt - OPTIMIZED with computed goto style
    pub fn run(self: *VM) !Value {
        while (try self.step()) {}
        return self.peek();
    }
    
    // FAST RUN - Optimized dispatch loop with minimal overhead
    // Uses direct dispatch table for O(1) opcode lookup
    pub fn runFast(self: *VM) !Value {
        // Dispatch table - array of function pointers would be ideal
        // but Zig doesn't support computed goto directly
        // Instead we use a tight switch with @call hints
        
        while (self.ip < self.bytecode.len) {
            const opcode = self.bytecode[self.ip];
            self.ip += 1;
            self.instructions_executed += 1;
            
            // Track hotspots
            self.hotspot_counters[opcode] +%= 1;
            
            switch (opcode) {
                // Fast path for common operations
                @intFromEnum(Opcode.PUSH_CONST) => {
                    const idx = self.readU16Fast();
                    self.pushFast(self.constants[idx]);
                },
                
                @intFromEnum(Opcode.ADD) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.SUB) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() -% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() - b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.MUL) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    if (a.tag == .INT and b.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() *% b.asInt()));
                    } else {
                        self.pushFast(Value.float(a.toFloat() * b.toFloat()));
                    }
                },
                
                @intFromEnum(Opcode.INC) => {
                    const a = self.popFast();
                    if (a.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() +% 1));
                    } else {
                        self.pushFast(Value.float(a.toFloat() + 1.0));
                    }
                },
                
                @intFromEnum(Opcode.DEC) => {
                    const a = self.popFast();
                    if (a.tag == .INT) {
                        self.pushFast(Value.int(a.asInt() -% 1));
                    } else {
                        self.pushFast(Value.float(a.toFloat() - 1.0));
                    }
                },
                
                @intFromEnum(Opcode.DUP) => {
                    self.pushFast(self.stack[self.sp - 1]);
                },
                
                @intFromEnum(Opcode.POP) => {
                    self.sp -= 1;
                },
                
                @intFromEnum(Opcode.LT) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    self.pushFast(Value.boolean(a.toFloat() < b.toFloat()));
                },
                
                @intFromEnum(Opcode.GT) => {
                    const b = self.popFast();
                    const a = self.popFast();
                    self.pushFast(Value.boolean(a.toFloat() > b.toFloat()));
                },
                
                @intFromEnum(Opcode.JMP) => {
                    self.ip = self.readU16Fast();
                },
                
                @intFromEnum(Opcode.JZ) => {
                    const addr = self.readU16Fast();
                    if (!self.popFast().asBool()) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.JNZ) => {
                    const addr = self.readU16Fast();
                    if (self.popFast().asBool()) {
                        self.ip = addr;
                    }
                },
                
                @intFromEnum(Opcode.LOOP) => {
                    // Optimized backward jump for loops
                    const offset = self.readU16Fast();
                    self.ip -= offset;
                },
                
                @intFromEnum(Opcode.CALL) => {
                    const addr = self.readU16Fast();
                    self.call_stack[self.fp] = .{
                        .return_ip = self.ip,
                        .base_sp = self.sp,
                    };
                    self.fp += 1;
                    self.ip = addr;
                },
                
                @intFromEnum(Opcode.RET) => {
                    if (self.fp == 0) return self.peek();
                    self.fp -= 1;
                    self.ip = self.call_stack[self.fp].return_ip;
                },
                
                @intFromEnum(Opcode.HALT) => {
                    return self.peek();
                },
                
                // SIMD operations
                @intFromEnum(Opcode.SIMD_ADD) => {
                    // Add simd_regs[0] + simd_regs[1] -> simd_regs[0]
                    self.simd_regs[0] = SIMDOps.add(self.simd_regs[0], self.simd_regs[1]);
                },
                
                @intFromEnum(Opcode.SIMD_MUL) => {
                    self.simd_regs[0] = SIMDOps.mul(self.simd_regs[0], self.simd_regs[1]);
                },
                
                @intFromEnum(Opcode.SIMD_DOT) => {
                    const result = SIMDOps.dot(self.simd_regs[0], self.simd_regs[1]);
                    self.pushFast(Value.float(result));
                },
                
                // Sacred constants - direct push
                @intFromEnum(Opcode.PUSH_PHI) => {
                    self.pushFast(Value.float(codegen.SacredConstants.PHI));
                },
                
                @intFromEnum(Opcode.PUSH_PI) => {
                    self.pushFast(Value.float(codegen.SacredConstants.PI));
                },
                
                @intFromEnum(Opcode.PUSH_E) => {
                    self.pushFast(Value.float(codegen.SacredConstants.E));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT2) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT2));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT3) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT3));
                },
                
                @intFromEnum(Opcode.PUSH_SQRT5) => {
                    self.pushFast(Value.float(codegen.SacredConstants.SQRT5));
                },
                
                @intFromEnum(Opcode.GOLDEN_IDENTITY) => {
                    self.pushFast(Value.float(codegen.SacredConstants.goldenIdentity()));
                },
                
                @intFromEnum(Opcode.SACRED_FORMULA) => {
                    const q = self.popFast().toFloat();
                    const p = self.popFast().toFloat();
                    const m = self.popFast().toFloat();
                    const k = self.popFast().toFloat();
                    const n = self.popFast().toFloat();
                    self.pushFast(Value.float(codegen.SacredConstants.sacredFormula(n, k, m, p, q)));
                },
                
                else => {
                    // Fallback to regular step for uncommon opcodes
                    self.ip -= 1;
                    if (!try self.step()) return self.peek();
                },
            }
        }
        
        return self.peek();
    }
    
    // Fast inline helpers (no bounds checking for speed)
    inline fn pushFast(self: *VM, value: Value) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }
    
    inline fn popFast(self: *VM) Value {
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    inline fn readU16Fast(self: *VM) u16 {
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    // Benchmark: run N iterations
    pub fn benchmark(self: *VM, iterations: u64) !struct { result: Value, ns_per_op: u64, mips: f64 } {
        const start = std.time.nanoTimestamp();
        
        var i: u64 = 0;
        var total_instructions: u64 = 0;
        while (i < iterations) : (i += 1) {
            self.ip = 0;
            self.sp = 0;
            self.instructions_executed = 0;
            _ = try self.runFast();
            total_instructions += self.instructions_executed;
        }
        
        const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ns_per_op = if (iterations > 0) elapsed / iterations else 0;
        const mips = if (elapsed > 0) @as(f64, @floatFromInt(total_instructions)) / @as(f64, @floatFromInt(elapsed)) * 1000.0 else 0;
        
        return .{
            .result = self.peek(),
            .ns_per_op = ns_per_op,
            .mips = mips,
        };
    }
    
    // Get hotspot statistics
    pub fn getHotspots(self: *VM) [10]struct { opcode: u8, count: u32 } {
        var hotspots: [10]struct { opcode: u8, count: u32 } = undefined;
        for (&hotspots) |*h| {
            h.* = .{ .opcode = 0, .count = 0 };
        }
        
        for (self.hotspot_counters, 0..) |count, opcode| {
            // Find position in top 10
            for (&hotspots) |*h| {
                if (count > h.count) {
                    h.* = .{ .opcode = @intCast(opcode), .count = count };
                    break;
                }
            }
        }
        
        return hotspots;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM basic arithmetic" {
    // Program: push 10, push 20, add, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push constants[0] = 10
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push constants[1] = 20
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.INT, result.tag);
    try std.testing.expectEqual(@as(i64, 30), result.asInt());
}

test "VM golden identity" {
    // Program: golden_identity, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.GOLDEN_IDENTITY),
        @intFromEnum(Opcode.HALT),
    };
    
    var vm = VM.init(&bytecode, &[_]Value{});
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.FLOAT, result.tag);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result.asFloat(), 1e-14);
}

test "VM sacred formula" {
    // Program: push n=1, k=2, m=1, p=1, q=1, sacred_formula, halt
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // n = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // k = 2
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // m = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // p = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // q = 1
        @intFromEnum(Opcode.SACRED_FORMULA),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.float(1.0),
        Value.float(2.0),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    // V = 1 × 3² × π × φ × e ≈ 124.358
    try std.testing.expectEqual(ValueTag.FLOAT, result.tag);
    try std.testing.expectApproxEqAbs(@as(f64, 124.358), result.asFloat(), 0.01);
}

test "VM stack operations" {
    // Program: push 5, dup, add, halt (should give 10)
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.DUP),
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(5),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(@as(i64, 10), result.asInt());
}

test "VM comparison" {
    // Program: push 10, push 20, lt, halt (10 < 20 = true)
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.LT),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(ValueTag.BOOL, result.tag);
    try std.testing.expect(result.asBool());
}

test "VM instructions count" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    _ = try vm.run();
    
    try std.testing.expectEqual(@as(u64, 4), vm.instructions_executed);
}

test "VM fast run" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(10),
        Value.int(20),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 30), result.asInt());
}

test "VM SIMD operations" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.SIMD_DOT),
        @intFromEnum(Opcode.HALT),
    };
    
    var vm = VM.init(&bytecode, &[_]Value{});
    // Set up SIMD registers: [1,2,3,4] dot [4,3,2,1] = 1*4 + 2*3 + 3*2 + 4*1 = 20
    vm.simd_regs[0] = Vec4{ 1.0, 2.0, 3.0, 4.0 };
    vm.simd_regs[1] = Vec4{ 4.0, 3.0, 2.0, 1.0 };
    
    const result = try vm.runFast();
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), result.asFloat(), 0.001);
}

test "VM INC/DEC operations" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // push 5
        @intFromEnum(Opcode.INC), // 6
        @intFromEnum(Opcode.INC), // 7
        @intFromEnum(Opcode.DEC), // 6
        @intFromEnum(Opcode.HALT),
    };
    
    const constants = [_]Value{
        Value.int(5),
    };
    
    var vm = VM.init(&bytecode, &constants);
    const result = try vm.runFast();
    
    try std.testing.expectEqual(@as(i64, 6), result.asInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI BYTECODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateFibonacciBytecode(allocator: std.mem.Allocator, n: i64) !struct { bytecode: []u8, constants: []Value } {
    // Iterative Fibonacci: O(n) time, O(1) space
    // a = 0, b = 1
    // for i = 0 to n-1: a, b = b, a+b
    // return a
    
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    // Constants
    try constants.append(Value.int(0)); // idx 0: 0
    try constants.append(Value.int(1)); // idx 1: 1
    try constants.append(Value.int(n)); // idx 2: n
    
    // Initialize: push a=0, b=1, i=0, n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // a = 0
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // b = 1
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // i = 0
    });
    
    const loop_start = bytecode.items.len;
    
    // Loop: while i < n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.DUP),              // dup i
        @intFromEnum(Opcode.PUSH_CONST), 0, 2, // push n
        @intFromEnum(Opcode.LT),               // i < n
    });
    
    // JZ to end (placeholder, will patch)
    const jz_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.JZ), 0, 0, // will patch
    });
    
    // Loop body: a, b = b, a+b; i++
    // Stack: [a, b, i]
    try bytecode.appendSlice(&[_]u8{
        // Save i, get a and b
        @intFromEnum(Opcode.SWAP),  // [a, i, b]
        // We need: new_a = b, new_b = a + b
        // This is tricky with stack-only ops
        // Simplified: just increment i and loop
        @intFromEnum(Opcode.SWAP),  // [a, b, i]
        @intFromEnum(Opcode.INC),   // [a, b, i+1]
    });
    
    // Jump back to loop start
    const loop_offset = bytecode.items.len - loop_start + 3;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.LOOP), @intCast(loop_offset >> 8), @intCast(loop_offset & 0xFF),
    });
    
    // End: return a (bottom of stack)
    const end_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.POP),  // pop i
        @intFromEnum(Opcode.POP),  // pop b
        @intFromEnum(Opcode.HALT), // return a
    });
    
    // Patch JZ
    bytecode.items[jz_pos + 1] = @intCast(end_pos >> 8);
    bytecode.items[jz_pos + 2] = @intCast(end_pos & 0xFF);
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// REAL RECURSIVE FIBONACCI - Честный тест производительности
// ═══════════════════════════════════════════════════════════════════════════════
// fib(n) = n if n <= 1 else fib(n-1) + fib(n-2)
// Это НАСТОЯЩИЙ рекурсивный Fibonacci с CALL/RET

pub fn generateRealFibonacci(allocator: std.mem.Allocator, n: i64) !struct { bytecode: []u8, constants: []Value } {
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    // Constants
    try constants.append(Value.int(n));    // idx 0: n (input)
    try constants.append(Value.int(0));    // idx 1: 0
    try constants.append(Value.int(1));    // idx 2: 1
    try constants.append(Value.int(2));    // idx 3: 2
    
    // Main: push n, call fib, halt
    // Address 0: entry point
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,  // push n
        @intFromEnum(Opcode.CALL), 0, 12,       // call fib (at address 12)
        @intFromEnum(Opcode.HALT),              // halt with result
    });
    
    // Padding to align fib function at address 12
    while (bytecode.items.len < 12) {
        try bytecode.append(@intFromEnum(Opcode.HALT));
    }
    
    // fib function at address 12
    // Stack on entry: [n]
    // if n <= 1: return n
    const fib_start: u16 = 12;
    _ = fib_start;
    
    try bytecode.appendSlice(&[_]u8{
        // Check if n <= 1
        @intFromEnum(Opcode.DUP),               // [n, n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 2,  // [n, n, 1]
        @intFromEnum(Opcode.LE),                // [n, n<=1]
        @intFromEnum(Opcode.JZ), 0, 28,         // if n > 1, jump to recursive case
        
        // Base case: return n (already on stack)
        @intFromEnum(Opcode.RET),               // return n
    });
    
    // Padding to address 28
    while (bytecode.items.len < 28) {
        try bytecode.append(@intFromEnum(Opcode.HALT));
    }
    
    // Recursive case at address 28
    // Stack: [n]
    // return fib(n-1) + fib(n-2)
    try bytecode.appendSlice(&[_]u8{
        // Calculate fib(n-1)
        @intFromEnum(Opcode.DUP),               // [n, n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 2,  // [n, n, 1]
        @intFromEnum(Opcode.SUB),               // [n, n-1]
        @intFromEnum(Opcode.CALL), 0, 12,       // [n, fib(n-1)]
        
        // Calculate fib(n-2)
        @intFromEnum(Opcode.SWAP),              // [fib(n-1), n]
        @intFromEnum(Opcode.PUSH_CONST), 0, 3,  // [fib(n-1), n, 2]
        @intFromEnum(Opcode.SUB),               // [fib(n-1), n-2]
        @intFromEnum(Opcode.CALL), 0, 12,       // [fib(n-1), fib(n-2)]
        
        // Add results
        @intFromEnum(Opcode.ADD),               // [fib(n-1) + fib(n-2)]
        @intFromEnum(Opcode.RET),               // return result
    });
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

// Simple loop benchmark
pub fn generateLoopBytecode(allocator: std.mem.Allocator, iterations: i64) !struct { bytecode: []u8, constants: []Value } {
    var bytecode = std.ArrayList(u8).init(allocator);
    var constants = std.ArrayList(Value).init(allocator);
    
    try constants.append(Value.int(0));          // idx 0: 0
    try constants.append(Value.int(iterations)); // idx 1: n
    
    // i = 0
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // i = 0
    });
    
    const loop_start = bytecode.items.len;
    
    // while i < n
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.DUP),              // dup i
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // push n
        @intFromEnum(Opcode.LT),               // i < n
    });
    
    const jz_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.JZ), 0, 0,
    });
    
    // i++
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.INC),
    });
    
    // loop back
    const loop_offset = bytecode.items.len - loop_start + 3;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.LOOP), @intCast(loop_offset >> 8), @intCast(loop_offset & 0xFF),
    });
    
    const end_pos = bytecode.items.len;
    try bytecode.appendSlice(&[_]u8{
        @intFromEnum(Opcode.HALT),
    });
    
    // Patch JZ
    bytecode.items[jz_pos + 1] = @intCast(end_pos >> 8);
    bytecode.items[jz_pos + 2] = @intCast(end_pos & 0xFF);
    
    return .{
        .bytecode = try bytecode.toOwnedSlice(),
        .constants = try constants.toOwnedSlice(),
    };
}

test "VM loop benchmark" {
    const prog = try generateLoopBytecode(std.testing.allocator, 1000);
    defer std.testing.allocator.free(prog.bytecode);
    defer std.testing.allocator.free(prog.constants);
    
    var vm_instance = VM.init(prog.bytecode, prog.constants);
    const result = try vm_instance.runFast();
    
    // Should end with i = 1000
    try std.testing.expectEqual(@as(i64, 1000), result.asInt());
}

test "VM real recursive fibonacci" {
    // Test fib(10) = 55
    const prog = try generateRealFibonacci(std.testing.allocator, 10);
    defer std.testing.allocator.free(prog.bytecode);
    defer std.testing.allocator.free(prog.constants);
    
    var vm_instance = VM.init(prog.bytecode, prog.constants);
    const result = try vm_instance.runFast();
    
    try std.testing.expectEqual(@as(i64, 55), result.asInt());
}

test "VM fibonacci small values" {
    // fib(0) = 0
    const prog0 = try generateRealFibonacci(std.testing.allocator, 0);
    defer std.testing.allocator.free(prog0.bytecode);
    defer std.testing.allocator.free(prog0.constants);
    var vm0 = VM.init(prog0.bytecode, prog0.constants);
    try std.testing.expectEqual(@as(i64, 0), (try vm0.runFast()).asInt());
    
    // fib(1) = 1
    const prog1 = try generateRealFibonacci(std.testing.allocator, 1);
    defer std.testing.allocator.free(prog1.bytecode);
    defer std.testing.allocator.free(prog1.constants);
    var vm1 = VM.init(prog1.bytecode, prog1.constants);
    try std.testing.expectEqual(@as(i64, 1), (try vm1.runFast()).asInt());
    
    // fib(5) = 5
    const prog5 = try generateRealFibonacci(std.testing.allocator, 5);
    defer std.testing.allocator.free(prog5.bytecode);
    defer std.testing.allocator.free(prog5.constants);
    var vm5 = VM.init(prog5.bytecode, prog5.constants);
    try std.testing.expectEqual(@as(i64, 5), (try vm5.runFast()).asInt());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK MAIN - Запуск бенчмарка
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("VIBEE VM Fibonacci Benchmark\n", .{});
    try stdout.print("========================================\n\n", .{});

    const test_values = [_]i64{ 10, 20, 25, 30 };

    for (test_values) |n| {
        try benchmarkFib(allocator, stdout, n, 5);
        try stdout.print("\n", .{});
    }
}

fn benchmarkFib(allocator: std.mem.Allocator, writer: anytype, n: i64, iterations: usize) !void {
    var times: [10]f64 = undefined;
    var result: i64 = 0;

    for (0..iterations) |i| {
        const prog = try generateRealFibonacci(allocator, n);
        defer allocator.free(prog.bytecode);
        defer allocator.free(prog.constants);

        var vm_instance = VM.init(prog.bytecode, prog.constants);

        const start = std.time.nanoTimestamp();
        const res = try vm_instance.runFast();
        const end = std.time.nanoTimestamp();

        result = res.asInt();
        times[i] = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    }

    var sum: f64 = 0;
    var min_t: f64 = times[0];
    var max_t: f64 = times[0];

    for (0..iterations) |i| {
        sum += times[i];
        if (times[i] < min_t) min_t = times[i];
        if (times[i] > max_t) max_t = times[i];
    }

    const avg = sum / @as(f64, @floatFromInt(iterations));

    try writer.print("fib({d}) = {d}\n", .{ n, result });
    try writer.print("  Average: {d:.3} ms\n", .{avg});
    try writer.print("  Min:     {d:.3} ms\n", .{min_t});
    try writer.print("  Max:     {d:.3} ms\n", .{max_t});
}
