const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");

// ═══════════════════════════════════════════════════════════════
// TVC VM (Trinary Virtual Machine)
// Executes TVC IR instructions
// ═══════════════════════════════════════════════════════════════

pub const Trit = i8;
pub const NEG1: Trit = -1;
pub const ZERO: Trit = 0;
pub const POS1: Trit = 1;

pub const StackValue = union(enum) {
    trit: Trit,
    i64: i64,
    f64: f64,
    pointer: *anyopaque,
};

pub const VMRegisters = struct {
    // General purpose registers (trinary)
    r0: Trit = ZERO,
    r1: Trit = ZERO,
    r2: Trit = ZERO,
    r3: Trit = ZERO,

    // Registers for extended values
    i0: i64 = 0,
    i1: i64 = 0,
    f0: f64 = 0.0,

    // Program counter
    pc: u32 = 0,

    // Stack pointer
    sp: u32 = 0,

    // Frame pointer
    fp: u32 = 0,

    // Condition codes (trinary)
    cc_zero: Trit = ZERO,
    cc_neg: Trit = ZERO,
    cc_pos: Trit = ZERO,
};

pub const VMMemory = struct {
    heap: std.ArrayList(u8),
    stack: std.ArrayList(StackValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, heap_size: usize, stack_size: usize) VMMemory {
        var heap = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
        var stack = std.ArrayList(StackValue).initCapacity(allocator, 0) catch unreachable;

        heap.resize(allocator, heap_size) catch unreachable;
        stack.resize(allocator, stack_size) catch unreachable;

        return VMMemory{
            .heap = heap,
            .stack = stack,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VMMemory) void {
        self.heap.deinit(self.allocator);
        self.stack.deinit(self.allocator);
    }

    pub fn loadU8(self: *const VMMemory, address: u32) u8 {
        if (address < self.heap.items.len) {
            return self.heap.items[address];
        }
        return 0;
    }

    pub fn storeU8(self: *VMMemory, address: u32, value: u8) void {
        if (address < self.heap.items.len) {
            self.heap.items[address] = value;
        }
    }

    pub fn loadI64(self: *const VMMemory, address: u32) i64 {
        var result: i64 = 0;
        for (0..8) |i| {
            result |= @as(i64, self.loadU8(address + @as(u32, @intCast(i)))) << @as(u6, @intCast(i * 8));
        }
        return result;
    }

    pub fn storeI64(self: *VMMemory, address: u32, value: i64) void {
        for (0..8) |i| {
            const shifted: u64 = @as(u64, @bitCast(value)) >> @as(u6, @intCast(i * 8));
            self.storeU8(address + @as(u32, @intCast(i)), @as(u8, @truncate(shifted)));
        }
    }

    pub fn pushStack(self: *VMMemory, value: StackValue) !void {
        try self.stack.append(self.allocator, value);
    }

    pub fn popStack(self: *VMMemory) StackValue {
        if (self.stack.items.len > 0) {
            const val = self.stack.items[self.stack.items.len - 1];
            _ = self.stack.pop();
            return val;
        }
        return StackValue{ .trit = ZERO };
    }
};

pub const TVCVM = struct {
    registers: VMRegisters,
    memory: VMMemory,
    current_module: ?*const tvc_ir.TVCModule,
    current_function: ?*const tvc_ir.TVCFunction,
    halted: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, heap_size: usize, stack_size: usize) TVCVM {
        return TVCVM{
            .registers = .{},
            .memory = VMMemory.init(allocator, heap_size, stack_size),
            .current_module = null,
            .current_function = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TVCVM) void {
        self.memory.deinit();
    }

    pub fn loadModule(self: *TVCVM, module: *const tvc_ir.TVCModule) !void {
        self.current_module = module;
        std.debug.print("[VM] Loaded module: {s}\n", .{module.name});
        std.debug.print("    Functions: {d}\n", .{module.functions.count()});
    }

    pub fn getFunction(self: *const TVCVM, name: []const u8) ?*const tvc_ir.TVCFunction {
        if (self.current_module) |mod| {
            const entry = mod.functions.getEntry(name) orelse return null;
            return &entry.value_ptr.*;
        }
        return null;
    }

    pub fn callFunction(self: *TVCVM, func_name: []const u8) !void {
        const func = self.getFunction(func_name) orelse return error.FunctionNotFound;
        self.current_function = func;

        std.debug.print("[VM] Calling function: {s}\n", .{func_name});
        std.debug.print("    Returns: {s}\n", .{@tagName(func.returns)});

        // Find entry block
        const entry_block_entry = func.blocks.getEntry("entry") orelse return error.EntryBlockNotFound;
        const entry_block = &entry_block_entry.value_ptr.*;

        // Execute instructions in entry block
        self.executeBlock(entry_block) catch |err| {
            std.debug.print("[VM] Error executing function {s}: {}\n", .{ func_name, err });
            return err;
        };
    }

    fn executeBlock(self: *TVCVM, block: *tvc_ir.TVCBlock) !void {
        for (block.instructions.items) |inst| {
            if (self.halted) break;

            std.debug.print("[VM] Executing: [{d}] {s}", .{ inst.location, @tagName(inst.opcode) });
            if (inst.operands.len > 0) {
                std.debug.print(" operands={any}", .{inst.operands});
            }
            std.debug.print("\n", .{});

            try self.executeInstruction(inst);
        }
    }

    fn executeInstruction(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        switch (inst.opcode) {
            .t_not => try self.executeTrinaryNot(inst),
            .t_and => try self.executeTrinaryAnd(inst),
            .t_or => try self.executeTrinaryOr(inst),
            .t_xor => try self.executeTrinaryXor(inst),
            .t_implies => try self.executeTrinaryImplies(inst),
            .add => try self.executeAdd(inst),
            .sub => try self.executeSub(inst),
            .mul => try self.executeMul(inst),
            .div => try self.executeDiv(inst),
            .mod => try self.executeMod(inst),
            .jump => try self.executeJump(inst),
            .jump_if => try self.executeJumpIf(inst),
            .jump_if_not => try self.executeJumpIfNot(inst),
            .call => try self.executeCall(inst),
            .ret => try self.executeRet(inst),
            .load => try self.executeLoad(inst),
            .store => try self.executeStore(inst),
            .alloc => try self.executeAlloc(inst),
            .free => try self.executeFree(inst),
            .push => try self.executePush(inst),
            .pop => try self.executePop(inst),
            .dup => try self.executeDup(inst),
            .swap => try self.executeSwap(inst),
            .nop => {}, // Do nothing
            .halt => self.halted = true,
        }
    }

    // Trinary Logic Operations
    fn executeTrinaryNot(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: r0 = -r0
        self.registers.r0 = trinaryNot(self.registers.r0);
        std.debug.print("    r0 = {d} (trit NOT)\n", .{self.registers.r0});
    }

    fn executeTrinaryAnd(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: r0 = r0 & r1 (min in balanced ternary)
        const result = trinaryAnd(self.registers.r0, self.registers.r1);
        std.debug.print("    r0 = r0 & r1 = {d} & {d} = {d}\n", .{ self.registers.r0, self.registers.r1, result });
        self.registers.r0 = result;
    }

    fn executeTrinaryOr(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: r0 = r0 | r1 (max in balanced ternary)
        const result = trinaryOr(self.registers.r0, self.registers.r1);
        std.debug.print("    r0 = r0 | r1 = {d} | {d} = {d}\n", .{ self.registers.r0, self.registers.r1, result });
        self.registers.r0 = result;
    }

    fn executeTrinaryXor(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: r0 = r0 ^ r1 (multiplication in balanced ternary)
        const result = trinaryXor(self.registers.r0, self.registers.r1);
        std.debug.print("    r0 = r0 ^ r1 = {d} * {d} = {d}\n", .{ self.registers.r0, self.registers.r1, result });
        self.registers.r0 = result;
    }

    fn executeTrinaryImplies(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // TVC: r0 = r0 -> r1 (implication: min(1-r0+r1, 1))
        const result = trinaryImplies(self.registers.r0, self.registers.r1);
        std.debug.print("    r0 = r0 -> r1 = {d} -> {d} = {d}\n", .{ self.registers.r0, self.registers.r1, result });
        self.registers.r0 = result;
    }

    // Arithmetic Operations
    fn executeAdd(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        self.registers.i0 += self.registers.i1;
        std.debug.print("    i0 = i0 + i1 = {d}\n", .{self.registers.i0});
    }

    fn executeSub(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        self.registers.i0 -= self.registers.i1;
        std.debug.print("    i0 = i0 - i1 = {d}\n", .{self.registers.i0});
    }

    fn executeMul(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        self.registers.i0 *= self.registers.i1;
        std.debug.print("    i0 = i0 * i1 = {d}\n", .{self.registers.i0});
    }

    fn executeDiv(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        if (self.registers.i1 == 0) return error.DivisionByZero;
        self.registers.i0 = @divTrunc(self.registers.i0, self.registers.i1);
        std.debug.print("    i0 = i0 / i1 = {d}\n", .{self.registers.i0});
    }

    fn executeMod(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        if (self.registers.i1 == 0) return error.DivisionByZero;
        self.registers.i0 = @rem(self.registers.i0, self.registers.i1);
        std.debug.print("    i0 = i0 % i1 = {d}\n", .{self.registers.i0});
    }

    // Control Flow
    fn executeJump(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = self;
        _ = inst;
        // Note: Real implementation would jump to block
        std.debug.print("    Jump (not implemented in single-block demo)\n", .{});
    }

    fn executeJumpIf(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // Note: Real implementation would jump if condition is pos1
        if (self.registers.r0 == POS1) {
            std.debug.print("    Jump if r0={d} (pos1) - true\n", .{self.registers.r0});
        } else {
            std.debug.print("    Jump if r0={d} - false\n", .{self.registers.r0});
        }
    }

    fn executeJumpIfNot(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        // Note: Real implementation would jump if condition is neg1 or zero
        if (self.registers.r0 != POS1) {
            std.debug.print("    Jump if not r0={d} - true\n", .{self.registers.r0});
        } else {
            std.debug.print("    Jump if not r0={d} - false\n", .{self.registers.r0});
        }
    }

    fn executeCall(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = self;
        _ = inst;
        std.debug.print("    Call function (not implemented in demo)\n", .{});
    }

    fn executeRet(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = self;
        _ = inst;
        std.debug.print("    Return\n", .{});
    }

    // Memory Operations
    fn executeLoad(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        if (inst.operands.len == 0) return error.InvalidOperandCount;
        const address = @as(u32, @intCast(inst.operands[0]));
        self.registers.i0 = self.memory.loadI64(address);
        std.debug.print("    i0 = load[{d}] = {d}\n", .{ address, self.registers.i0 });
    }

    fn executeStore(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        if (inst.operands.len < 2) return error.InvalidOperandCount;
        const address = @as(u32, @intCast(inst.operands[0]));
        const value = @as(i64, @intCast(inst.operands[1]));
        self.memory.storeI64(address, value);
        std.debug.print("    store[{d}] = {d}\n", .{ address, value });
    }

    fn executeAlloc(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        if (inst.operands.len == 0) return error.InvalidOperandCount;
        const size = inst.operands[0];
        _ = try self.allocator.alloc(u8, size);
        std.debug.print("    alloc({d}) bytes\n", .{size});
    }

    fn executeFree(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = self;
        _ = inst;
        std.debug.print("    free()\n", .{});
    }

    // Stack Operations
    fn executePush(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        try self.memory.pushStack(StackValue{ .i64 = self.registers.i0 });
        std.debug.print("    push i0={d}\n", .{self.registers.i0});
    }

    fn executePop(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        const val = self.memory.popStack();
        switch (val) {
            .i64 => |v| {
                self.registers.i0 = v;
                std.debug.print("    pop i0={d}\n", .{v});
            },
            else => {},
        }
    }

    fn executeDup(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        if (self.memory.stack.items.len > 0) {
            const val = self.memory.stack.items[self.memory.stack.items.len - 1];
            try self.memory.pushStack(val);
            std.debug.print("    dup\n", .{});
        }
    }

    fn executeSwap(self: *TVCVM, inst: tvc_ir.TVCInstruction) !void {
        _ = inst;
        const len = self.memory.stack.items.len;
        if (len >= 2) {
            const temp = self.memory.stack.items[len - 1];
            self.memory.stack.items[len - 1] = self.memory.stack.items[len - 2];
            self.memory.stack.items[len - 2] = temp;
            std.debug.print("    swap\n", .{});
        }
    }

    pub fn dumpState(self: *const TVCVM) void {
        std.debug.print("\n╔══════════════════════════════════════════╗\n", .{});
        std.debug.print("║            TVC VM STATE                   ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ REGISTERS:                              ║\n", .{});
        std.debug.print("║  r0={d:2d} r1={d:2d} r2={d:2d} r3={d:2d}               ║\n", .{ self.registers.r0, self.registers.r1, self.registers.r2, self.registers.r3 });
        std.debug.print("║  i0={d:20d} i1={d:20d}               ║\n", .{ self.registers.i0, self.registers.i1 });
        std.debug.print("║  f0={d:20.6}                         ║\n", .{self.registers.f0});
        std.debug.print("║  pc={d:6d} sp={d:6d} fp={d:6d}                 ║\n", .{ self.registers.pc, self.registers.sp, self.registers.fp });
        std.debug.print("║  cc_zero={d:2d} cc_neg={d:2d} cc_pos={d:2d}            ║\n", .{ self.registers.cc_zero, self.registers.cc_neg, self.registers.cc_pos });
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ MEMORY:                                 ║\n", .{});
        std.debug.print("║  heap size={d:8d} bytes               ║\n", .{self.memory.heap.items.len});
        std.debug.print("║  stack size={d:8d} items              ║\n", .{self.memory.stack.items.len});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ EXECUTION:                              ║\n", .{});
        std.debug.print("║  halted={d:6d}                           ║\n", .{@intFromBool(self.halted)});
        std.debug.print("╚══════════════════════════════════════════╝\n\n", .{});
    }
};

// Trinary Logic Helper Functions

pub fn trinaryNot(a: Trit) Trit {
    return -a;
}

pub fn trinaryAnd(a: Trit, b: Trit) Trit {
    // Balanced ternary AND = min(a, b)
    return if (a < b) a else b;
}

pub fn trinaryOr(a: Trit, b: Trit) Trit {
    // Balanced ternary OR = max(a, b)
    return if (a > b) a else b;
}

pub fn trinaryXor(a: Trit, b: Trit) Trit {
    // Balanced ternary XOR = a * b (multiplication)
    return @as(Trit, @truncate(a * b));
}

pub fn trinaryImplies(a: Trit, b: Trit) Trit {
    // Balanced ternary implication: min(1 - a + b, 1)
    const result = 1 - a + b;
    return if (result > 1) 1 else if (result < -1) -1 else result;
}

pub fn tritToString(t: Trit) []const u8 {
    return switch (t) {
        -1 => "-1",
        0 => " 0",
        1 => "+1",
        else => " ?",
    };
}
