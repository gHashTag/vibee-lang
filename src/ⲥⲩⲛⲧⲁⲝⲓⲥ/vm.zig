// ═══════════════════════════════════════════════════════════════════════════════
// VM TRINITY - РЕАЛЬНЫЙ ИНТЕРПРЕТАТОР БАЙТКОДА
// ═══════════════════════════════════════════════════════════════════════════════
// СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m × φ^p × e^q
// ЗОЛОТАЯ ИДЕНТИЧНОСТЬ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════
// ЧЕСТНАЯ РЕАЛИЗАЦИЯ: Это реальный интерпретатор, не симуляция
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const codegen = @import("codegen.zig");

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
    
    // Arithmetic (0x10-0x1F)
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    
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
    
    // Sacred constants (0x90-0x9F)
    PUSH_PHI = 0x90,
    PUSH_PI = 0x91,
    PUSH_E = 0x92,
    GOLDEN_IDENTITY = 0x93,
    SACRED_FORMULA = 0x94,
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
    
    const STACK_SIZE = 16384;
    const CALL_STACK_SIZE = 1024;
    
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
    
    // Run until halt
    pub fn run(self: *VM) !Value {
        while (try self.step()) {}
        return self.peek();
    }
    
    // Benchmark: run N iterations
    pub fn benchmark(self: *VM, iterations: u64) !struct { result: Value, ns_per_op: u64 } {
        const start = std.time.nanoTimestamp();
        
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            self.ip = 0;
            self.sp = 0;
            _ = try self.run();
        }
        
        const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ns_per_op = elapsed / iterations;
        
        return .{
            .result = self.peek(),
            .ns_per_op = ns_per_op,
        };
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
