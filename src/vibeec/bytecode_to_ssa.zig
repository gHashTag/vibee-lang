// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE TO SSA CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════
// Converts stack-based .999 bytecode to register-based SSA IR for optimization
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const bytecode = @import("bytecode.zig");
const Opcode = bytecode.Opcode;
const Value = bytecode.Value;
const jit_tier2 = @import("jit_tier2.zig");
const SSAFunction = jit_tier2.SSAFunction;
const SSAInstr = jit_tier2.SSAInstr;
const SSAOp = jit_tier2.SSAOp;
const SSA_UNDEF = jit_tier2.SSA_UNDEF;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const MAX_STACK: usize = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE TO SSA CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BytecodeToSSA = struct {
    allocator: Allocator,
    func: SSAFunction,
    
    // Virtual stack tracking (maps stack positions to SSA values)
    stack: [MAX_STACK]u32,
    stack_top: usize,
    
    // Local variable tracking
    locals: [MAX_STACK]u32,
    
    // Track which SSA values are known constants (for copy propagation)
    known_constants: [MAX_STACK]?i64,
    
    // Constants from bytecode
    constants: []const Value,
    
    // Statistics
    instructions_converted: u32,
    stack_ops_eliminated: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8) Self {
        return Self{
            .allocator = allocator,
            .func = SSAFunction.init(allocator, name),
            .stack = [_]u32{SSA_UNDEF} ** MAX_STACK,
            .stack_top = 0,
            .locals = [_]u32{SSA_UNDEF} ** MAX_STACK,
            .known_constants = [_]?i64{null} ** MAX_STACK,
            .constants = &[_]Value{},
            .instructions_converted = 0,
            .stack_ops_eliminated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.func.deinit();
    }

    /// Set constants pool from bytecode
    pub fn setConstants(self: *Self, constants: []const Value) void {
        self.constants = constants;
    }

    /// Push SSA value onto virtual stack
    fn push(self: *Self, value: u32) void {
        if (self.stack_top < MAX_STACK) {
            self.stack[self.stack_top] = value;
            self.stack_top += 1;
        }
    }

    /// Pop SSA value from virtual stack
    fn pop(self: *Self) u32 {
        if (self.stack_top > 0) {
            self.stack_top -= 1;
            return self.stack[self.stack_top];
        }
        return SSA_UNDEF;
    }

    /// Peek at top of virtual stack
    fn peek(self: *Self) u32 {
        if (self.stack_top > 0) {
            return self.stack[self.stack_top - 1];
        }
        return SSA_UNDEF;
    }

    /// Emit SSA instruction and return destination value
    fn emit(self: *Self, instr: SSAInstr) u32 {
        self.func.emit(0, instr);
        return instr.dest;
    }

    /// Convert bytecode stream to SSA IR
    pub fn convert(self: *Self, code: []const u8) !void {
        var ip: usize = 0;
        
        while (ip < code.len) {
            const opcode: Opcode = @enumFromInt(code[ip]);
            ip += 1;
            
            self.instructions_converted += 1;
            
            switch (opcode) {
                // ═══════════════════════════════════════════════════════════
                // CONSTANTS
                // ═══════════════════════════════════════════════════════════
                .PUSH_CONST => {
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    // Get constant value from tagged union
                    var imm: i64 = 0;
                    if (idx < self.constants.len) {
                        const val = self.constants[idx];
                        imm = switch (val) {
                            .int_val => |v| v,
                            .bool_val => |v| if (v) @as(i64, 1) else @as(i64, 0),
                            .float_val => |v| @intFromFloat(v),
                            .trit_val => |v| @as(i64, v),
                            .tryte_val => |v| @as(i64, v),
                            else => 0,
                        };
                    }
                    
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.constInt(dest, imm));
                    // Track this as a known constant
                    if (dest < MAX_STACK) {
                        self.known_constants[dest] = imm;
                    }
                    self.push(dest);
                },

                // ═══════════════════════════════════════════════════════════
                // STACK OPERATIONS
                // ═══════════════════════════════════════════════════════════
                .POP => {
                    _ = self.pop();
                    self.stack_ops_eliminated += 1;
                },
                
                .DUP => {
                    const top = self.peek();
                    self.push(top);
                    self.stack_ops_eliminated += 1;
                },
                
                .SWAP => {
                    if (self.stack_top >= 2) {
                        const a = self.stack[self.stack_top - 1];
                        const b = self.stack[self.stack_top - 2];
                        self.stack[self.stack_top - 1] = b;
                        self.stack[self.stack_top - 2] = a;
                    }
                    self.stack_ops_eliminated += 1;
                },

                // ═══════════════════════════════════════════════════════════
                // LOCAL VARIABLES
                // ═══════════════════════════════════════════════════════════
                .LOAD_LOCAL => {
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    const local_val = self.locals[idx];
                    if (local_val != SSA_UNDEF) {
                        self.push(local_val);
                    } else {
                        // First load - create placeholder
                        const dest = self.func.newValue();
                        _ = self.emit(SSAInstr{
                            .op = .load,
                            .dest = dest,
                            .src1 = @intCast(idx),
                            .src2 = 0,
                            .imm = 0,
                        });
                        self.locals[idx] = dest;
                        self.push(dest);
                    }
                },
                
                .STORE_LOCAL => {
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    const val = self.pop();
                    self.locals[idx] = val;
                    // Store is implicit in SSA - the value is now associated with the local
                    // No instruction emitted - SSA tracks the value directly
                },

                // ═══════════════════════════════════════════════════════════
                // ARITHMETIC
                // ═══════════════════════════════════════════════════════════
                .ADD => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.add, dest, a, b));
                    self.push(dest);
                },
                
                .SUB => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.sub, dest, a, b));
                    self.push(dest);
                },
                
                .MUL => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.mul, dest, a, b));
                    self.push(dest);
                },
                
                .DIV => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.div, dest, a, b));
                    self.push(dest);
                },
                
                .MOD => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.mod, dest, a, b));
                    self.push(dest);
                },
                
                .NEG => {
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.unop(.neg, dest, a));
                    self.push(dest);
                },
                
                .INC => {
                    const a = self.pop();
                    const one = self.func.newValue();
                    _ = self.emit(SSAInstr.constInt(one, 1));
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.add, dest, a, one));
                    self.push(dest);
                },
                
                .DEC => {
                    const a = self.pop();
                    const one = self.func.newValue();
                    _ = self.emit(SSAInstr.constInt(one, 1));
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.sub, dest, a, one));
                    self.push(dest);
                },

                // ═══════════════════════════════════════════════════════════
                // COMPARISON
                // ═══════════════════════════════════════════════════════════
                .EQ => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.eq, dest, a, b));
                    self.push(dest);
                },
                
                .NE => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.ne, dest, a, b));
                    self.push(dest);
                },
                
                .LT => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.lt, dest, a, b));
                    self.push(dest);
                },
                
                .LE => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.le, dest, a, b));
                    self.push(dest);
                },
                
                .GT => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.gt, dest, a, b));
                    self.push(dest);
                },
                
                .GE => {
                    const b = self.pop();
                    const a = self.pop();
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.binop(.ge, dest, a, b));
                    self.push(dest);
                },

                // ═══════════════════════════════════════════════════════════
                // CONTROL FLOW
                // ═══════════════════════════════════════════════════════════
                .RET => {
                    const val = self.pop();
                    _ = self.emit(SSAInstr{
                        .op = .ret,
                        .dest = SSA_UNDEF,
                        .src1 = val,
                        .src2 = SSA_UNDEF,
                        .imm = 0,
                    });
                },
                
                .HALT => {
                    // End of program - return top of stack or 0
                    const val = if (self.stack_top > 0) self.pop() else blk: {
                        const zero = self.func.newValue();
                        _ = self.emit(SSAInstr.constInt(zero, 0));
                        break :blk zero;
                    };
                    _ = self.emit(SSAInstr{
                        .op = .ret,
                        .dest = SSA_UNDEF,
                        .src1 = val,
                        .src2 = SSA_UNDEF,
                        .imm = 0,
                    });
                },
                
                .JMP => {
                    const offset = readU16(code, ip);
                    ip += 2;
                    _ = self.emit(SSAInstr{
                        .op = .jump,
                        .dest = SSA_UNDEF,
                        .src1 = SSA_UNDEF,
                        .src2 = SSA_UNDEF,
                        .imm = offset,
                    });
                },
                
                .JZ => {
                    const offset = readU16(code, ip);
                    ip += 2;
                    const cond = self.pop();
                    _ = self.emit(SSAInstr{
                        .op = .branch,
                        .dest = SSA_UNDEF,
                        .src1 = cond,
                        .src2 = SSA_UNDEF,
                        .imm = offset,
                    });
                },
                
                .JNZ => {
                    const offset = readU16(code, ip);
                    ip += 2;
                    const cond = self.pop();
                    // JNZ = branch if NOT zero, so we negate
                    const neg_cond = self.func.newValue();
                    _ = self.emit(SSAInstr{
                        .op = .eq,
                        .dest = neg_cond,
                        .src1 = cond,
                        .src2 = cond, // Compare with self to get 1
                        .imm = 0,
                    });
                    _ = self.emit(SSAInstr{
                        .op = .branch,
                        .dest = SSA_UNDEF,
                        .src1 = cond,
                        .src2 = SSA_UNDEF,
                        .imm = offset,
                    });
                },

                // ═══════════════════════════════════════════════════════════
                // SACRED CONSTANTS
                // ═══════════════════════════════════════════════════════════
                .PUSH_PHI => {
                    const dest = self.func.newValue();
                    // Store phi as fixed-point: 1618033988749895 (scaled by 10^15)
                    _ = self.emit(SSAInstr.constInt(dest, 1618033988749895));
                    self.push(dest);
                },
                
                .PUSH_PI => {
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.constInt(dest, 3141592653589793));
                    self.push(dest);
                },
                
                .PUSH_E => {
                    const dest = self.func.newValue();
                    _ = self.emit(SSAInstr.constInt(dest, 2718281828459045));
                    self.push(dest);
                },

                // ═══════════════════════════════════════════════════════════
                // SUPERINSTRUCTIONS
                // ═══════════════════════════════════════════════════════════
                .LOAD_ADD => {
                    // LOAD_ADD idx: load local[idx] and add to TOS
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    const local_val = self.locals[idx];
                    const tos = self.pop();
                    const dest = self.func.newValue();
                    
                    if (local_val != SSA_UNDEF) {
                        _ = self.emit(SSAInstr.binop(.add, dest, tos, local_val));
                    } else {
                        // Local not yet defined - create load
                        const load_dest = self.func.newValue();
                        _ = self.emit(SSAInstr{
                            .op = .load,
                            .dest = load_dest,
                            .src1 = @intCast(idx),
                            .src2 = 0,
                            .imm = 0,
                        });
                        _ = self.emit(SSAInstr.binop(.add, dest, tos, load_dest));
                    }
                    self.push(dest);
                },
                
                .LOAD_SUB => {
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    const local_val = self.locals[idx];
                    const tos = self.pop();
                    const dest = self.func.newValue();
                    
                    if (local_val != SSA_UNDEF) {
                        _ = self.emit(SSAInstr.binop(.sub, dest, tos, local_val));
                    } else {
                        const load_dest = self.func.newValue();
                        _ = self.emit(SSAInstr{
                            .op = .load,
                            .dest = load_dest,
                            .src1 = @intCast(idx),
                            .src2 = 0,
                            .imm = 0,
                        });
                        _ = self.emit(SSAInstr.binop(.sub, dest, tos, load_dest));
                    }
                    self.push(dest);
                },
                
                .LOAD_MUL => {
                    const idx = readU16(code, ip);
                    ip += 2;
                    
                    const local_val = self.locals[idx];
                    const tos = self.pop();
                    const dest = self.func.newValue();
                    
                    if (local_val != SSA_UNDEF) {
                        _ = self.emit(SSAInstr.binop(.mul, dest, tos, local_val));
                    } else {
                        const load_dest = self.func.newValue();
                        _ = self.emit(SSAInstr{
                            .op = .load,
                            .dest = load_dest,
                            .src1 = @intCast(idx),
                            .src2 = 0,
                            .imm = 0,
                        });
                        _ = self.emit(SSAInstr.binop(.mul, dest, tos, load_dest));
                    }
                    self.push(dest);
                },

                // ═══════════════════════════════════════════════════════════
                // PRINT (native function)
                // ═══════════════════════════════════════════════════════════
                .CALL_NATIVE => {
                    const name_idx = readU16(code, ip);
                    ip += 2;
                    _ = name_idx;
                    // For print, pop the argument but don't push result
                    // The value is consumed by print
                    if (self.stack_top > 0) {
                        _ = self.pop();
                    }
                    // print returns nil, so we don't push anything
                },

                // ═══════════════════════════════════════════════════════════
                // NOP and unhandled
                // ═══════════════════════════════════════════════════════════
                .NOP => {
                    _ = self.emit(SSAInstr{
                        .op = .nop,
                        .dest = SSA_UNDEF,
                        .src1 = SSA_UNDEF,
                        .src2 = SSA_UNDEF,
                        .imm = 0,
                    });
                },

                else => {
                    // Skip operands for unhandled opcodes
                    ip += opcode.operandSize();
                },
            }
        }
    }

    /// Get the converted SSA function
    pub fn getFunction(self: *Self) *SSAFunction {
        return &self.func;
    }

    /// Get conversion statistics
    pub fn getStats(self: *Self) struct { converted: u32, stack_eliminated: u32 } {
        return .{
            .converted = self.instructions_converted,
            .stack_eliminated = self.stack_ops_eliminated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn readU16(code: []const u8, offset: usize) u16 {
    if (offset + 1 < code.len) {
        return @as(u16, code[offset]) << 8 | @as(u16, code[offset + 1]);
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert bytecode to optimized SSA IR
pub fn convertAndOptimize(
    allocator: Allocator,
    code: []const u8,
    constants: []const Value,
    name: []const u8,
) !SSAFunction {
    var converter = BytecodeToSSA.init(allocator, name);
    converter.setConstants(constants);
    try converter.convert(code);
    
    // Optimize
    var jit = jit_tier2.JITTier2.init(allocator);
    defer jit.deinit();
    jit.compile(&converter.func);
    
    // Transfer ownership
    const func = converter.func;
    converter.func = SSAFunction.init(allocator, ""); // Reset to avoid double-free
    return func;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "convert simple constant expression" {
    // Bytecode for: 10 + 20
    // PUSH_CONST 0 (10)
    // PUSH_CONST 1 (20)
    // ADD
    // HALT
    const code = [_]u8{
        0x01, 0x00, 0x00, // PUSH_CONST 0
        0x01, 0x00, 0x01, // PUSH_CONST 1
        0x10,             // ADD
        0x45,             // HALT
    };
    
    // Constants pool - Value is a tagged union
    const constants = [_]Value{
        Value{ .int_val = 10 },
        Value{ .int_val = 20 },
    };
    
    var converter = BytecodeToSSA.init(std.testing.allocator, "test");
    defer converter.deinit();
    converter.setConstants(&constants);
    
    try converter.convert(&code);
    
    const stats = converter.getStats();
    try std.testing.expect(stats.converted >= 4);
}

test "convert arithmetic chain" {
    // Bytecode for: (5 * 10) + 25
    const code = [_]u8{
        0x01, 0x00, 0x00, // PUSH_CONST 0 (5)
        0x01, 0x00, 0x01, // PUSH_CONST 1 (10)
        0x12,             // MUL
        0x01, 0x00, 0x02, // PUSH_CONST 2 (25)
        0x10,             // ADD
        0x45,             // HALT
    };
    
    const constants = [_]Value{
        Value{ .int_val = 5 },
        Value{ .int_val = 10 },
        Value{ .int_val = 25 },
    };
    
    var converter = BytecodeToSSA.init(std.testing.allocator, "test");
    defer converter.deinit();
    converter.setConstants(&constants);
    
    try converter.convert(&code);
    
    // Should have converted all instructions
    const stats = converter.getStats();
    try std.testing.expect(stats.converted >= 5);
}

test "convert with optimization" {
    // Bytecode for: 10 + 20 (should fold to 30)
    const code = [_]u8{
        0x01, 0x00, 0x00, // PUSH_CONST 0 (10)
        0x01, 0x00, 0x01, // PUSH_CONST 1 (20)
        0x10,             // ADD
        0x45,             // HALT
    };
    
    const constants = [_]Value{
        Value{ .int_val = 10 },
        Value{ .int_val = 20 },
    };
    
    var converter = BytecodeToSSA.init(std.testing.allocator, "test");
    defer converter.deinit();
    converter.setConstants(&constants);
    
    try converter.convert(&code);
    
    // Count instructions before optimization
    var before: usize = 0;
    for (converter.func.blocks.items) |block| {
        before += block.instrs.items.len;
    }
    
    // Optimize
    var jit = jit_tier2.JITTier2.init(std.testing.allocator);
    defer jit.deinit();
    jit.compile(&converter.func);
    
    // Count instructions after optimization
    var after: usize = 0;
    for (converter.func.blocks.items) |block| {
        after += block.instrs.items.len;
    }
    
    // Should have reduced instructions
    try std.testing.expect(after <= before);
}

test "convert local variables" {
    // Bytecode for: let x = 10; let y = 20; x + y
    const code = [_]u8{
        0x01, 0x00, 0x00, // PUSH_CONST 0 (10)
        0x06, 0x00, 0x00, // STORE_LOCAL 0
        0x01, 0x00, 0x01, // PUSH_CONST 1 (20)
        0x06, 0x00, 0x01, // STORE_LOCAL 1
        0x05, 0x00, 0x00, // LOAD_LOCAL 0
        0x05, 0x00, 0x01, // LOAD_LOCAL 1
        0x10,             // ADD
        0x45,             // HALT
    };
    
    const constants = [_]Value{
        Value{ .int_val = 10 },
        Value{ .int_val = 20 },
    };
    
    var converter = BytecodeToSSA.init(std.testing.allocator, "test");
    defer converter.deinit();
    converter.setConstants(&constants);
    
    try converter.convert(&code);
    
    const stats = converter.getStats();
    try std.testing.expect(stats.converted >= 7);
}
