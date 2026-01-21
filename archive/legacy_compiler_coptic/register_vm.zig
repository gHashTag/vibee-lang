// ═══════════════════════════════════════════════════════════════
// REGISTER-BASED VM for Language 999
// Based on: "The Implementation of Lua 5.0" (Ierusalimschy et al., 2005)
// Expected speedup: 1.5-2x vs stack-based VM
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const MAX_REGISTERS = 256;
pub const MAX_CONSTANTS = 65536;
pub const MAX_UPVALUES = 256;

// ═══════════════════════════════════════════════════════════════
// TERNARY TYPE (from interpreter999)
// ═══════════════════════════════════════════════════════════════

pub const Trit = enum(u8) {
    True = 2,
    Unknown = 1,
    False = 0,

    pub fn tritAnd(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn tritOr(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn tritNot(a: Trit) Trit {
        return switch (a) {
            .True => .False,
            .Unknown => .Unknown,
            .False => .True,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// VALUE TYPE
// ═══════════════════════════════════════════════════════════════

pub const ValueType = enum(u8) {
    nil,
    trit,
    int,
    float,
    string,
    function,
    closure,
};

pub const Value = struct {
    vtype: ValueType,
    data: ValueData,

    pub const ValueData = union {
        nil: void,
        trit: Trit,
        int: i64,
        float: f64,
        string: []const u8,
        function: *Function,
        closure: *Closure,
    };

    pub fn nil() Value {
        return .{ .vtype = .nil, .data = .{ .nil = {} } };
    }

    pub fn fromTrit(t: Trit) Value {
        return .{ .vtype = .trit, .data = .{ .trit = t } };
    }

    pub fn fromInt(i: i64) Value {
        return .{ .vtype = .int, .data = .{ .int = i } };
    }

    pub fn fromFloat(f: f64) Value {
        return .{ .vtype = .float, .data = .{ .float = f } };
    }

    pub fn isTruthy(self: Value) Trit {
        return switch (self.vtype) {
            .nil => .False,
            .trit => self.data.trit,
            .int => if (self.data.int != 0) .True else .False,
            .float => if (self.data.float > 0.66) .True else if (self.data.float > 0.33) .Unknown else .False,
            else => .Unknown,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// BYTECODE INSTRUCTIONS
// Register-based: OP A B C or OP A Bx or OP A sBx
// ═══════════════════════════════════════════════════════════════

pub const OpCode = enum(u8) {
    // Load/Store
    MOVE,       // R(A) := R(B)
    LOADK,      // R(A) := K(Bx)
    LOADNIL,    // R(A) := nil
    LOADTRIT,   // R(A) := Trit(B)  (0=False, 1=Unknown, 2=True)
    
    // Arithmetic (register-based = fewer instructions)
    ADD,        // R(A) := R(B) + R(C)
    SUB,        // R(A) := R(B) - R(C)
    MUL,        // R(A) := R(B) * R(C)
    DIV,        // R(A) := R(B) / R(C)
    MOD,        // R(A) := R(B) % R(C)
    NEG,        // R(A) := -R(B)
    
    // Ternary Logic
    TAND,       // R(A) := R(B) trit_and R(C)
    TOR,        // R(A) := R(B) trit_or R(C)
    TNOT,       // R(A) := trit_not R(B)
    TCONSENSUS, // R(A) := consensus(R(B), R(C))
    
    // Comparison
    EQ,         // R(A) := R(B) == R(C)
    LT,         // R(A) := R(B) < R(C)
    LE,         // R(A) := R(B) <= R(C)
    
    // Control Flow
    JMP,        // PC += sBx
    JMPTRUE,    // if R(A) == True then PC += sBx
    JMPFALSE,   // if R(A) == False then PC += sBx
    JMPUNK,     // if R(A) == Unknown then PC += sBx
    
    // Functions
    CALL,       // R(A), ..., R(A+C-1) := R(A)(R(A+1), ..., R(A+B))
    RETURN,     // return R(A), ..., R(A+B-1)
    CLOSURE,    // R(A) := closure(KPROTO[Bx])
    
    // Tables/Objects
    GETTABLE,   // R(A) := R(B)[R(C)]
    SETTABLE,   // R(A)[R(B)] := R(C)
    NEWTABLE,   // R(A) := {}
    
    // Upvalues
    GETUPVAL,   // R(A) := UpValue[B]
    SETUPVAL,   // UpValue[B] := R(A)
};

// ═══════════════════════════════════════════════════════════════
// INSTRUCTION ENCODING
// 32-bit instruction: [OP:8][A:8][B:8][C:8] or [OP:8][A:8][Bx:16]
// ═══════════════════════════════════════════════════════════════

pub const Instruction = packed struct {
    op: OpCode,
    a: u8,
    b: u8,
    c: u8,

    pub fn create(op: OpCode, a: u8, b: u8, c: u8) Instruction {
        return .{ .op = op, .a = a, .b = b, .c = c };
    }

    pub fn createABx(op: OpCode, a: u8, bx: u16) Instruction {
        return .{
            .op = op,
            .a = a,
            .b = @truncate(bx >> 8),
            .c = @truncate(bx & 0xFF),
        };
    }

    pub fn getBx(self: Instruction) u16 {
        return (@as(u16, self.b) << 8) | self.c;
    }

    pub fn getsBx(self: Instruction) i16 {
        return @bitCast(self.getBx());
    }
};

// ═══════════════════════════════════════════════════════════════
// FUNCTION PROTOTYPE
// ═══════════════════════════════════════════════════════════════

pub const Function = struct {
    code: []Instruction,
    constants: []Value,
    num_params: u8,
    num_registers: u8,
    upvalues: []UpvalueDesc,
    protos: []*Function,  // nested functions
    name: []const u8,
};

pub const UpvalueDesc = struct {
    in_stack: bool,
    index: u8,
};

pub const Closure = struct {
    func: *Function,
    upvalues: []?*Upvalue,
};

pub const Upvalue = struct {
    value: *Value,
    closed: Value,
    is_open: bool,
};

// ═══════════════════════════════════════════════════════════════
// CALL FRAME
// ═══════════════════════════════════════════════════════════════

pub const CallFrame = struct {
    closure: *Closure,
    ip: usize,
    base: usize,  // base register index
};

// ═══════════════════════════════════════════════════════════════
// REGISTER VM
// ═══════════════════════════════════════════════════════════════

pub const RegisterVM = struct {
    allocator: Allocator,
    registers: [MAX_REGISTERS]Value,
    frames: std.ArrayList(CallFrame),
    open_upvalues: std.ArrayList(*Upvalue),
    
    // Performance counters
    instructions_executed: u64,
    
    pub fn init(allocator: Allocator) RegisterVM {
        var vm = RegisterVM{
            .allocator = allocator,
            .registers = undefined,
            .frames = std.ArrayList(CallFrame).init(allocator),
            .open_upvalues = std.ArrayList(*Upvalue).init(allocator),
            .instructions_executed = 0,
        };
        
        // Initialize registers to nil
        for (&vm.registers) |*r| {
            r.* = Value.nil();
        }
        
        return vm;
    }

    pub fn deinit(self: *RegisterVM) void {
        self.frames.deinit();
        self.open_upvalues.deinit();
    }

    /// Execute bytecode - main VM loop
    pub fn execute(self: *RegisterVM, closure: *Closure) !Value {
        try self.frames.append(.{
            .closure = closure,
            .ip = 0,
            .base = 0,
        });

        while (self.frames.items.len > 0) {
            var frame = &self.frames.items[self.frames.items.len - 1];
            const func = frame.closure.func;
            
            if (frame.ip >= func.code.len) {
                _ = self.frames.pop();
                continue;
            }

            const inst = func.code[frame.ip];
            frame.ip += 1;
            self.instructions_executed += 1;

            const base = frame.base;
            
            switch (inst.op) {
                .MOVE => {
                    self.registers[base + inst.a] = self.registers[base + inst.b];
                },
                
                .LOADK => {
                    const idx = inst.getBx();
                    self.registers[base + inst.a] = func.constants[idx];
                },
                
                .LOADNIL => {
                    self.registers[base + inst.a] = Value.nil();
                },
                
                .LOADTRIT => {
                    const t: Trit = @enumFromInt(inst.b);
                    self.registers[base + inst.a] = Value.fromTrit(t);
                },
                
                .ADD => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    if (b.vtype == .int and c.vtype == .int) {
                        self.registers[base + inst.a] = Value.fromInt(b.data.int + c.data.int);
                    } else if (b.vtype == .float or c.vtype == .float) {
                        const bf = if (b.vtype == .float) b.data.float else @as(f64, @floatFromInt(b.data.int));
                        const cf = if (c.vtype == .float) c.data.float else @as(f64, @floatFromInt(c.data.int));
                        self.registers[base + inst.a] = Value.fromFloat(bf + cf);
                    }
                },
                
                .SUB => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    if (b.vtype == .int and c.vtype == .int) {
                        self.registers[base + inst.a] = Value.fromInt(b.data.int - c.data.int);
                    }
                },
                
                .MUL => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    if (b.vtype == .int and c.vtype == .int) {
                        self.registers[base + inst.a] = Value.fromInt(b.data.int * c.data.int);
                    }
                },
                
                .DIV => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    if (b.vtype == .int and c.vtype == .int and c.data.int != 0) {
                        self.registers[base + inst.a] = Value.fromInt(@divTrunc(b.data.int, c.data.int));
                    }
                },
                
                .MOD => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    if (b.vtype == .int and c.vtype == .int and c.data.int != 0) {
                        self.registers[base + inst.a] = Value.fromInt(@mod(b.data.int, c.data.int));
                    }
                },
                
                .NEG => {
                    const b = self.registers[base + inst.b];
                    if (b.vtype == .int) {
                        self.registers[base + inst.a] = Value.fromInt(-b.data.int);
                    } else if (b.vtype == .float) {
                        self.registers[base + inst.a] = Value.fromFloat(-b.data.float);
                    }
                },
                
                // Ternary Logic Operations
                .TAND => {
                    const b = self.registers[base + inst.b].isTruthy();
                    const c = self.registers[base + inst.c].isTruthy();
                    self.registers[base + inst.a] = Value.fromTrit(Trit.tritAnd(b, c));
                },
                
                .TOR => {
                    const b = self.registers[base + inst.b].isTruthy();
                    const c = self.registers[base + inst.c].isTruthy();
                    self.registers[base + inst.a] = Value.fromTrit(Trit.tritOr(b, c));
                },
                
                .TNOT => {
                    const b = self.registers[base + inst.b].isTruthy();
                    self.registers[base + inst.a] = Value.fromTrit(Trit.tritNot(b));
                },
                
                .TCONSENSUS => {
                    const b = self.registers[base + inst.b].isTruthy();
                    const c = self.registers[base + inst.c].isTruthy();
                    const result = if (b == c) b else Trit.Unknown;
                    self.registers[base + inst.a] = Value.fromTrit(result);
                },
                
                // Comparison
                .EQ => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    var result = Trit.False;
                    if (b.vtype == c.vtype) {
                        if (b.vtype == .int and b.data.int == c.data.int) result = .True;
                        if (b.vtype == .trit and b.data.trit == c.data.trit) result = .True;
                        if (b.vtype == .nil) result = .True;
                    }
                    self.registers[base + inst.a] = Value.fromTrit(result);
                },
                
                .LT => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    var result = Trit.False;
                    if (b.vtype == .int and c.vtype == .int) {
                        result = if (b.data.int < c.data.int) .True else .False;
                    }
                    self.registers[base + inst.a] = Value.fromTrit(result);
                },
                
                .LE => {
                    const b = self.registers[base + inst.b];
                    const c = self.registers[base + inst.c];
                    var result = Trit.False;
                    if (b.vtype == .int and c.vtype == .int) {
                        result = if (b.data.int <= c.data.int) .True else .False;
                    }
                    self.registers[base + inst.a] = Value.fromTrit(result);
                },
                
                // Control Flow
                .JMP => {
                    const offset = inst.getsBx();
                    if (offset >= 0) {
                        frame.ip += @intCast(offset);
                    } else {
                        frame.ip -= @intCast(-offset);
                    }
                },
                
                .JMPTRUE => {
                    const a = self.registers[base + inst.a].isTruthy();
                    if (a == .True) {
                        const offset = inst.getsBx();
                        if (offset >= 0) {
                            frame.ip += @intCast(offset);
                        } else {
                            frame.ip -= @intCast(-offset);
                        }
                    }
                },
                
                .JMPFALSE => {
                    const a = self.registers[base + inst.a].isTruthy();
                    if (a == .False) {
                        const offset = inst.getsBx();
                        if (offset >= 0) {
                            frame.ip += @intCast(offset);
                        } else {
                            frame.ip -= @intCast(-offset);
                        }
                    }
                },
                
                .JMPUNK => {
                    const a = self.registers[base + inst.a].isTruthy();
                    if (a == .Unknown) {
                        const offset = inst.getsBx();
                        if (offset >= 0) {
                            frame.ip += @intCast(offset);
                        } else {
                            frame.ip -= @intCast(-offset);
                        }
                    }
                },
                
                .RETURN => {
                    const result = self.registers[base + inst.a];
                    _ = self.frames.pop();
                    if (self.frames.items.len == 0) {
                        return result;
                    }
                },
                
                else => {},
            }
        }

        return Value.nil();
    }

    /// Compile a simple expression to bytecode (for testing)
    pub fn compileFibonacci(self: *RegisterVM) !*Closure {
        // Fibonacci in register-based bytecode:
        // R0 = n (parameter)
        // R1 = 0 (a)
        // R2 = 1 (b)
        // R3 = temp
        // R4 = comparison result
        
        var code = std.ArrayList(Instruction).init(self.allocator);
        var constants = std.ArrayList(Value).init(self.allocator);
        
        // Constants
        try constants.append(Value.fromInt(0));  // K0 = 0
        try constants.append(Value.fromInt(1));  // K1 = 1
        try constants.append(Value.fromInt(2));  // K2 = 2
        
        // R1 = 0 (a)
        try code.append(Instruction.createABx(.LOADK, 1, 0));
        // R2 = 1 (b)
        try code.append(Instruction.createABx(.LOADK, 2, 1));
        
        // Loop start (index 2)
        // R4 = R0 < 2
        try code.append(Instruction.create(.LT, 4, 0, 5)); // R5 will have constant 2
        try code.append(Instruction.createABx(.LOADK, 5, 2)); // Load 2 into R5
        try code.append(Instruction.create(.LT, 4, 0, 5));
        // if R4 == True, jump to return
        try code.append(Instruction.createABx(.JMPTRUE, 4, 6)); // Jump forward 6
        
        // R3 = R1 + R2 (temp = a + b)
        try code.append(Instruction.create(.ADD, 3, 1, 2));
        // R1 = R2 (a = b)
        try code.append(Instruction.create(.MOVE, 1, 2, 0));
        // R2 = R3 (b = temp)
        try code.append(Instruction.create(.MOVE, 2, 3, 0));
        // R0 = R0 - 1
        try code.append(Instruction.createABx(.LOADK, 6, 1)); // Load 1 into R6
        try code.append(Instruction.create(.SUB, 0, 0, 6));
        // Jump back to loop start
        try code.append(Instruction.createABx(.JMP, 0, @bitCast(@as(i16, -9))));
        
        // Return R1
        try code.append(Instruction.create(.RETURN, 1, 1, 0));
        
        const func = try self.allocator.create(Function);
        func.* = .{
            .code = try code.toOwnedSlice(),
            .constants = try constants.toOwnedSlice(),
            .num_params = 1,
            .num_registers = 8,
            .upvalues = &[_]UpvalueDesc{},
            .protos = &[_]*Function{},
            .name = "fibonacci",
        };
        
        const closure = try self.allocator.create(Closure);
        closure.* = .{
            .func = func,
            .upvalues = &[_]?*Upvalue{},
        };
        
        return closure;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "register vm initialization" {
    var vm = RegisterVM.init(std.testing.allocator);
    defer vm.deinit();
    
    try std.testing.expectEqual(Value.nil().vtype, vm.registers[0].vtype);
}

test "instruction encoding" {
    const inst = Instruction.create(.ADD, 1, 2, 3);
    try std.testing.expectEqual(OpCode.ADD, inst.op);
    try std.testing.expectEqual(@as(u8, 1), inst.a);
    try std.testing.expectEqual(@as(u8, 2), inst.b);
    try std.testing.expectEqual(@as(u8, 3), inst.c);
}

test "instruction Bx encoding" {
    const inst = Instruction.createABx(.LOADK, 5, 1000);
    try std.testing.expectEqual(OpCode.LOADK, inst.op);
    try std.testing.expectEqual(@as(u8, 5), inst.a);
    try std.testing.expectEqual(@as(u16, 1000), inst.getBx());
}

test "ternary operations" {
    try std.testing.expectEqual(Trit.False, Trit.tritAnd(.True, .False));
    try std.testing.expectEqual(Trit.True, Trit.tritOr(.True, .False));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritAnd(.True, .Unknown));
    try std.testing.expectEqual(Trit.False, Trit.tritNot(.True));
}

test "value operations" {
    const v1 = Value.fromInt(42);
    try std.testing.expectEqual(ValueType.int, v1.vtype);
    try std.testing.expectEqual(@as(i64, 42), v1.data.int);
    
    const v2 = Value.fromTrit(.True);
    try std.testing.expectEqual(Trit.True, v2.isTruthy());
}
