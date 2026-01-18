//! VIBEE Intermediate Representation - PAS DAEMON V39
//! Паттерны: HSH (O(1) value lookup), D&C (SSA construction), PRE (dominator tree)
//! Священная формула: V = n × 3^k × π^m × φ^p × e^q
//! Золотая идентичность: φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// IR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const IRType = enum(u8) {
    void_ir,
    i1,
    i8,
    i16,
    i32,
    i64,
    f32,
    f64,
    ptr,
    phi_ir,    // Sacred phi type
    array,
    struct_ir,
    func,
    
    pub fn size(self: IRType) u32 {
        return switch (self) {
            .void_ir => 0,
            .i1 => 1,
            .i8 => 1,
            .i16 => 2,
            .i32, .f32 => 4,
            .i64, .f64, .ptr, .phi_ir => 8,
            .array, .struct_ir, .func => 8,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR VALUE - SSA value representation
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueKind = enum(u8) {
    // Constants
    const_int,
    const_float,
    const_bool,
    const_null,
    const_phi,     // Sacred constant φ
    
    // Instructions
    instruction,
    
    // Parameters
    parameter,
    
    // Global
    global,
    
    // Undefined
    undef,
};

pub const Value = struct {
    id: u32,
    kind: ValueKind,
    ir_type: IRType,
    name: ?[]const u8 = null,
    
    // For constants
    const_data: ConstData = .{ .int = 0 },
    
    // For instructions
    def_inst: ?*Instruction = null,
    
    // Use-def chain
    uses: std.ArrayList(*Instruction),
    
    pub fn init(allocator: Allocator, id: u32, kind: ValueKind, ir_type: IRType) Value {
        return .{
            .id = id,
            .kind = kind,
            .ir_type = ir_type,
            .uses = std.ArrayList(*Instruction).init(allocator),
        };
    }
    
    pub fn deinit(self: *Value) void {
        self.uses.deinit();
    }
    
    pub fn isConstant(self: *const Value) bool {
        return @intFromEnum(self.kind) <= @intFromEnum(ValueKind.const_phi);
    }
    
    pub fn addUse(self: *Value, inst: *Instruction) !void {
        try self.uses.append(inst);
    }
};

pub const ConstData = union {
    int: i64,
    float: f64,
    boolean: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR INSTRUCTION - SSA instruction
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Arithmetic
    add,
    sub,
    mul,
    div,
    mod,
    neg,
    
    // Floating point
    fadd,
    fsub,
    fmul,
    fdiv,
    
    // Bitwise
    band,
    bor,
    bxor,
    bnot,
    shl,
    shr,
    
    // Comparison
    eq,
    ne,
    lt,
    le,
    gt,
    ge,
    
    // Memory
    load,
    store,
    alloca,
    gep,      // GetElementPtr
    
    // Control flow
    br,
    br_cond,
    ret,
    call,
    
    // Type conversion
    trunc,
    zext,
    sext,
    fptrunc,
    fpext,
    fptosi,
    sitofp,
    ptrtoint,
    inttoptr,
    bitcast,
    
    // SSA
    phi,
    
    // Sacred operations
    sacred_mul,   // Multiply by φ
    sacred_pow,   // Power with sacred base
};

pub const Instruction = struct {
    id: u32,
    opcode: Opcode,
    result: ?*Value,
    operands: [4]?*Value = .{ null, null, null, null },
    operand_count: u8 = 0,
    
    // For phi nodes
    phi_incoming: ?std.ArrayList(PhiIncoming) = null,
    
    // For branches
    true_block: ?*BasicBlock = null,
    false_block: ?*BasicBlock = null,
    
    // For calls
    callee: ?*Value = null,
    
    // Parent block
    parent: ?*BasicBlock = null,
    
    pub fn init(id: u32, opcode: Opcode) Instruction {
        return .{
            .id = id,
            .opcode = opcode,
            .result = null,
        };
    }
    
    pub fn addOperand(self: *Instruction, val: *Value) !void {
        if (self.operand_count >= 4) return error.TooManyOperands;
        self.operands[self.operand_count] = val;
        self.operand_count += 1;
        try val.addUse(self);
    }
    
    pub fn getOperand(self: *const Instruction, idx: usize) ?*Value {
        if (idx >= self.operand_count) return null;
        return self.operands[idx];
    }
    
    pub fn isTerminator(self: *const Instruction) bool {
        return self.opcode == .br or self.opcode == .br_cond or self.opcode == .ret;
    }
    
    pub fn hasSideEffects(self: *const Instruction) bool {
        return self.opcode == .store or self.opcode == .call or self.isTerminator();
    }
};

pub const PhiIncoming = struct {
    value: *Value,
    block: *BasicBlock,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BASIC BLOCK - CFG node
// ═══════════════════════════════════════════════════════════════════════════════

pub const BasicBlock = struct {
    id: u32,
    name: ?[]const u8 = null,
    instructions: std.ArrayList(*Instruction),
    
    // CFG edges
    predecessors: std.ArrayList(*BasicBlock),
    successors: std.ArrayList(*BasicBlock),
    
    // Dominator tree (PRE pattern)
    idom: ?*BasicBlock = null,        // Immediate dominator
    dom_children: std.ArrayList(*BasicBlock),
    dom_frontier: std.ArrayList(*BasicBlock),
    
    // Parent function
    parent: ?*Function = null,
    
    pub fn init(allocator: Allocator, id: u32) BasicBlock {
        return .{
            .id = id,
            .instructions = std.ArrayList(*Instruction).init(allocator),
            .predecessors = std.ArrayList(*BasicBlock).init(allocator),
            .successors = std.ArrayList(*BasicBlock).init(allocator),
            .dom_children = std.ArrayList(*BasicBlock).init(allocator),
            .dom_frontier = std.ArrayList(*BasicBlock).init(allocator),
        };
    }
    
    pub fn deinit(self: *BasicBlock) void {
        self.instructions.deinit();
        self.predecessors.deinit();
        self.successors.deinit();
        self.dom_children.deinit();
        self.dom_frontier.deinit();
    }
    
    pub fn append(self: *BasicBlock, inst: *Instruction) !void {
        inst.parent = self;
        try self.instructions.append(inst);
    }
    
    pub fn getTerminator(self: *const BasicBlock) ?*Instruction {
        if (self.instructions.items.len == 0) return null;
        const last = self.instructions.items[self.instructions.items.len - 1];
        return if (last.isTerminator()) last else null;
    }
    
    pub fn addSuccessor(self: *BasicBlock, succ: *BasicBlock) !void {
        try self.successors.append(succ);
        try succ.predecessors.append(self);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION - IR function
// ═══════════════════════════════════════════════════════════════════════════════

pub const Function = struct {
    id: u32,
    name: []const u8,
    return_type: IRType,
    params: std.ArrayList(*Value),
    blocks: std.ArrayList(*BasicBlock),
    entry_block: ?*BasicBlock = null,
    
    // Value numbering (HSH pattern)
    value_map: std.AutoHashMap(u32, *Value),
    
    // Track all instructions for cleanup
    all_instructions: std.ArrayList(*Instruction),
    
    // Counters
    next_value_id: u32 = 0,
    next_inst_id: u32 = 0,
    next_block_id: u32 = 0,
    
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, id: u32, name: []const u8, ret_type: IRType) Function {
        return .{
            .id = id,
            .name = name,
            .return_type = ret_type,
            .params = std.ArrayList(*Value).init(allocator),
            .blocks = std.ArrayList(*BasicBlock).init(allocator),
            .value_map = std.AutoHashMap(u32, *Value).init(allocator),
            .all_instructions = std.ArrayList(*Instruction).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Function) void {
        for (self.blocks.items) |block| {
            block.deinit();
            self.allocator.destroy(block);
        }
        self.blocks.deinit();
        
        for (self.all_instructions.items) |inst| {
            if (inst.phi_incoming) |*incoming| {
                incoming.deinit();
            }
            self.allocator.destroy(inst);
        }
        self.all_instructions.deinit();
        
        var val_iter = self.value_map.valueIterator();
        while (val_iter.next()) |val| {
            val.*.deinit();
            self.allocator.destroy(val.*);
        }
        self.value_map.deinit();
        self.params.deinit();
    }
    
    /// Create new basic block
    pub fn createBlock(self: *Function, name: ?[]const u8) !*BasicBlock {
        const block = try self.allocator.create(BasicBlock);
        block.* = BasicBlock.init(self.allocator, self.next_block_id);
        block.name = name;
        block.parent = self;
        self.next_block_id += 1;
        try self.blocks.append(block);
        
        if (self.entry_block == null) {
            self.entry_block = block;
        }
        
        return block;
    }
    
    /// Create new value
    pub fn createValue(self: *Function, kind: ValueKind, ir_type: IRType) !*Value {
        const val = try self.allocator.create(Value);
        val.* = Value.init(self.allocator, self.next_value_id, kind, ir_type);
        try self.value_map.put(self.next_value_id, val);
        self.next_value_id += 1;
        return val;
    }
    
    /// Create constant integer
    pub fn constInt(self: *Function, ir_type: IRType, value: i64) !*Value {
        const val = try self.createValue(.const_int, ir_type);
        val.const_data = .{ .int = value };
        return val;
    }
    
    /// Create constant float
    pub fn constFloat(self: *Function, ir_type: IRType, value: f64) !*Value {
        const val = try self.createValue(.const_float, ir_type);
        val.const_data = .{ .float = value };
        return val;
    }
    
    /// Create sacred phi constant
    pub fn constPhi(self: *Function) !*Value {
        const val = try self.createValue(.const_phi, .phi_ir);
        val.const_data = .{ .float = PHI };
        return val;
    }
    
    /// Create instruction
    pub fn createInst(self: *Function, opcode: Opcode) !*Instruction {
        const inst = try self.allocator.create(Instruction);
        inst.* = Instruction.init(self.next_inst_id, opcode);
        self.next_inst_id += 1;
        try self.all_instructions.append(inst);
        return inst;
    }
    
    /// Build binary operation
    pub fn buildBinOp(self: *Function, block: *BasicBlock, opcode: Opcode, lhs: *Value, rhs: *Value, result_type: IRType) !*Value {
        const inst = try self.createInst(opcode);
        try inst.addOperand(lhs);
        try inst.addOperand(rhs);
        
        const result = try self.createValue(.instruction, result_type);
        result.def_inst = inst;
        inst.result = result;
        
        try block.append(inst);
        return result;
    }
    
    /// Build return
    pub fn buildRet(self: *Function, block: *BasicBlock, val: ?*Value) !void {
        const inst = try self.createInst(.ret);
        if (val) |v| {
            try inst.addOperand(v);
        }
        try block.append(inst);
    }
    
    /// Build unconditional branch
    pub fn buildBr(self: *Function, block: *BasicBlock, target: *BasicBlock) !void {
        const inst = try self.createInst(.br);
        inst.true_block = target;
        try block.append(inst);
        try block.addSuccessor(target);
    }
    
    /// Build conditional branch
    pub fn buildCondBr(self: *Function, block: *BasicBlock, cond: *Value, true_bb: *BasicBlock, false_bb: *BasicBlock) !void {
        const inst = try self.createInst(.br_cond);
        try inst.addOperand(cond);
        inst.true_block = true_bb;
        inst.false_block = false_bb;
        try block.append(inst);
        try block.addSuccessor(true_bb);
        try block.addSuccessor(false_bb);
    }
    
    /// Build phi node
    pub fn buildPhi(self: *Function, block: *BasicBlock, ir_type: IRType) !*Instruction {
        const inst = try self.createInst(.phi);
        inst.phi_incoming = std.ArrayList(PhiIncoming).init(self.allocator);
        
        const result = try self.createValue(.instruction, ir_type);
        result.def_inst = inst;
        inst.result = result;
        
        try block.append(inst);
        return inst;
    }
    
    /// Add phi incoming
    pub fn addPhiIncoming(self: *Function, phi: *Instruction, val: *Value, from_block: *BasicBlock) !void {
        _ = self;
        if (phi.phi_incoming) |*incoming| {
            try incoming.append(.{ .value = val, .block = from_block });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR MODULE - Top-level container
// ═══════════════════════════════════════════════════════════════════════════════

pub const Module = struct {
    allocator: Allocator,
    name: []const u8,
    functions: std.StringHashMap(*Function),
    globals: std.StringHashMap(*Value),
    next_func_id: u32 = 0,
    
    pub fn init(allocator: Allocator, name: []const u8) Module {
        return .{
            .allocator = allocator,
            .name = name,
            .functions = std.StringHashMap(*Function).init(allocator),
            .globals = std.StringHashMap(*Value).init(allocator),
        };
    }
    
    pub fn deinit(self: *Module) void {
        var func_iter = self.functions.valueIterator();
        while (func_iter.next()) |func| {
            func.*.deinit();
            self.allocator.destroy(func.*);
        }
        self.functions.deinit();
        self.globals.deinit();
    }
    
    /// Create function
    pub fn createFunction(self: *Module, name: []const u8, ret_type: IRType) !*Function {
        const func = try self.allocator.create(Function);
        func.* = Function.init(self.allocator, self.next_func_id, name, ret_type);
        self.next_func_id += 1;
        try self.functions.put(name, func);
        return func;
    }
    
    /// Lookup function - O(1)
    pub fn getFunction(self: *const Module, name: []const u8) ?*Function {
        return self.functions.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR PRINTER - Debug output
// ═══════════════════════════════════════════════════════════════════════════════

pub const IRPrinter = struct {
    pub fn printModule(module: *const Module, writer: anytype) !void {
        try writer.print("; Module: {s}\n", .{module.name});
        
        var func_iter = module.functions.valueIterator();
        while (func_iter.next()) |func| {
            try printFunction(func.*, writer);
        }
    }
    
    pub fn printFunction(func: *const Function, writer: anytype) !void {
        try writer.print("\ndefine {s} @{s}() {{\n", .{ @tagName(func.return_type), func.name });
        
        for (func.blocks.items) |block| {
            try printBlock(block, writer);
        }
        
        try writer.print("}}\n", .{});
    }
    
    pub fn printBlock(block: *const BasicBlock, writer: anytype) !void {
        if (block.name) |name| {
            try writer.print("{s}:\n", .{name});
        } else {
            try writer.print("bb{d}:\n", .{block.id});
        }
        
        for (block.instructions.items) |inst| {
            try writer.print("  ", .{});
            try printInstruction(inst, writer);
            try writer.print("\n", .{});
        }
    }
    
    pub fn printInstruction(inst: *const Instruction, writer: anytype) !void {
        if (inst.result) |result| {
            try writer.print("%{d} = ", .{result.id});
        }
        
        try writer.print("{s}", .{@tagName(inst.opcode)});
        
        for (0..inst.operand_count) |i| {
            if (inst.operands[i]) |op| {
                try writer.print(" %{d}", .{op.id});
            }
        }
        
        if (inst.true_block) |bb| {
            try writer.print(" bb{d}", .{bb.id});
        }
        if (inst.false_block) |bb| {
            try writer.print(", bb{d}", .{bb.id});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Module and Function creation" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test_module");
    defer module.deinit();
    
    const func = try module.createFunction("main", .i32);
    try std.testing.expectEqualStrings("main", func.name);
    try std.testing.expectEqual(IRType.i32, func.return_type);
}

test "BasicBlock and Instructions" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test");
    defer module.deinit();
    
    const func = try module.createFunction("test_func", .i32);
    const entry = try func.createBlock("entry");
    
    const c1 = try func.constInt(.i32, 10);
    const c2 = try func.constInt(.i32, 20);
    
    const result = try func.buildBinOp(entry, .add, c1, c2, .i32);
    try func.buildRet(entry, result);
    
    try std.testing.expectEqual(@as(usize, 2), entry.instructions.items.len);
    try std.testing.expect(entry.getTerminator() != null);
}

test "Control flow" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test");
    defer module.deinit();
    
    const func = try module.createFunction("test_cf", .void_ir);
    const entry = try func.createBlock("entry");
    const then_bb = try func.createBlock("then");
    const else_bb = try func.createBlock("else");
    
    const cond = try func.constInt(.i1, 1);
    try func.buildCondBr(entry, cond, then_bb, else_bb);
    
    try std.testing.expectEqual(@as(usize, 2), entry.successors.items.len);
    try std.testing.expectEqual(@as(usize, 1), then_bb.predecessors.items.len);
}

test "Phi node" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test");
    defer module.deinit();
    
    const func = try module.createFunction("test_phi", .i32);
    const entry = try func.createBlock("entry");
    const merge = try func.createBlock("merge");
    
    const phi = try func.buildPhi(merge, .i32);
    const v1 = try func.constInt(.i32, 1);
    try func.addPhiIncoming(phi, v1, entry);
    
    try std.testing.expectEqual(Opcode.phi, phi.opcode);
    try std.testing.expect(phi.phi_incoming != null);
}

test "Sacred phi constant" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test");
    defer module.deinit();
    
    const func = try module.createFunction("sacred", .phi_ir);
    const phi_val = try func.constPhi();
    
    try std.testing.expectEqual(ValueKind.const_phi, phi_val.kind);
    try std.testing.expect(@abs(phi_val.const_data.float - PHI) < 0.0001);
}

test "Value use-def chain" {
    const allocator = std.testing.allocator;
    var module = Module.init(allocator, "test");
    defer module.deinit();
    
    const func = try module.createFunction("test_use", .i32);
    const entry = try func.createBlock("entry");
    
    const c1 = try func.constInt(.i32, 5);
    _ = try func.buildBinOp(entry, .add, c1, c1, .i32);
    
    // c1 should have 2 uses (both operands of add)
    try std.testing.expectEqual(@as(usize, 2), c1.uses.items.len);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
