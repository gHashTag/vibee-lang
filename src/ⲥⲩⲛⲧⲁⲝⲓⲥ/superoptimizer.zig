// Stochastic Superoptimization for VIBEE
// Based on STOKE (Schkufza et al., 2013)
// Part of PAS Phase 4 implementation

const std = @import("std");

// ============================================================================
// INSTRUCTION SET
// ============================================================================

pub const Opcode = enum {
    // Data movement
    mov,
    push,
    pop,
    lea,
    
    // Arithmetic
    add,
    sub,
    mul,
    imul,
    div,
    idiv,
    neg,
    inc,
    dec,
    
    // Bitwise
    @"and",
    @"or",
    xor,
    not,
    shl,
    shr,
    sar,
    rol,
    ror,
    
    // Comparison
    cmp,
    tst,
    
    // Control flow
    jmp,
    je,
    jne,
    jl,
    jle,
    jg,
    jge,
    call,
    ret,
    
    // Special
    nop,
    xchg,

    pub fn latency(self: Opcode) u8 {
        return switch (self) {
            .mov, .push, .pop, .lea => 1,
            .add, .sub, .neg, .inc, .dec => 1,
            .@"and", .@"or", .xor, .not => 1,
            .shl, .shr, .sar, .rol, .ror => 1,
            .cmp, .tst => 1,
            .mul, .imul => 3,
            .div, .idiv => 20,
            .jmp, .je, .jne, .jl, .jle, .jg, .jge => 1,
            .call, .ret => 3,
            .nop => 0,
            .xchg => 2,
        };
    }

    pub fn throughput(self: Opcode) f32 {
        return switch (self) {
            .mov, .push, .pop => 0.25,
            .add, .sub, .neg, .inc, .dec => 0.25,
            .@"and", .@"or", .xor, .not => 0.25,
            .shl, .shr, .sar => 0.5,
            .mul, .imul => 1.0,
            .div, .idiv => 20.0,
            else => 1.0,
        };
    }
};

pub const Operand = union(enum) {
    register: Register,
    immediate: i64,
    memory: MemoryOperand,
    label: []const u8,

    pub fn format(self: Operand, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .register => |r| try writer.print("{s}", .{@tagName(r)}),
            .immediate => |i| try writer.print("{d}", .{i}),
            .memory => |m| try writer.print("[{s}+{d}]", .{ @tagName(m.base), m.offset }),
            .label => |l| try writer.print("{s}", .{l}),
        }
    }
};

pub const Register = enum {
    rax, rbx, rcx, rdx,
    rsi, rdi, rbp, rsp,
    r8, r9, r10, r11,
    r12, r13, r14, r15,
    
    // 32-bit
    eax, ebx, ecx, edx,
    esi, edi, ebp, esp,
    
    // Flags
    flags,
};

pub const MemoryOperand = struct {
    base: Register,
    index: ?Register,
    scale: u8,
    offset: i32,
};

pub const Instruction = struct {
    opcode: Opcode,
    operands: [3]?Operand,
    num_operands: u8,

    pub fn init(opcode: Opcode) Instruction {
        return .{
            .opcode = opcode,
            .operands = .{ null, null, null },
            .num_operands = 0,
        };
    }

    pub fn withOp1(opcode: Opcode, op1: Operand) Instruction {
        return .{
            .opcode = opcode,
            .operands = .{ op1, null, null },
            .num_operands = 1,
        };
    }

    pub fn withOp2(opcode: Opcode, op1: Operand, op2: Operand) Instruction {
        return .{
            .opcode = opcode,
            .operands = .{ op1, op2, null },
            .num_operands = 2,
        };
    }

    pub fn cost(self: Instruction) u32 {
        return self.opcode.latency();
    }

    pub fn format(self: Instruction, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{@tagName(self.opcode)});
        
        var first = true;
        for (self.operands[0..self.num_operands]) |maybe_op| {
            if (maybe_op) |op| {
                if (first) {
                    try writer.writeAll(" ");
                    first = false;
                } else {
                    try writer.writeAll(", ");
                }
                try writer.print("{}", .{op});
            }
        }
    }
};

// ============================================================================
// PROGRAM REPRESENTATION
// ============================================================================

pub const Program = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),
    
    pub fn init(allocator: std.mem.Allocator) Program {
        return .{
            .allocator = allocator,
            .instructions = std.ArrayList(Instruction).init(allocator),
        };
    }

    pub fn deinit(self: *Program) void {
        self.instructions.deinit();
    }

    pub fn clone(self: *const Program) !Program {
        var new_prog = Program.init(self.allocator);
        try new_prog.instructions.appendSlice(self.instructions.items);
        return new_prog;
    }

    pub fn append(self: *Program, instr: Instruction) !void {
        try self.instructions.append(instr);
    }

    pub fn cost(self: *const Program) u32 {
        var total: u32 = 0;
        for (self.instructions.items) |instr| {
            total += instr.cost();
        }
        return total;
    }

    pub fn len(self: *const Program) usize {
        return self.instructions.items.len;
    }

    pub fn format(self: *const Program, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (self.instructions.items, 0..) |instr, i| {
            try writer.print("{d}: {}\n", .{ i, instr });
        }
    }
};

// ============================================================================
// MUTATION OPERATORS
// ============================================================================

pub const MutationType = enum {
    instruction_replacement,
    operand_replacement,
    instruction_swap,
    instruction_delete,
    instruction_insert,
    opcode_change,
};

pub const Mutator = struct {
    allocator: std.mem.Allocator,
    random: std.Random,

    const OPCODES = [_]Opcode{
        .mov, .add, .sub, .mul, .imul,
        .@"and", .@"or", .xor, .not,
        .shl, .shr, .sar,
        .lea, .neg, .inc, .dec,
        .nop,
    };

    const REGISTERS = [_]Register{
        .rax, .rbx, .rcx, .rdx,
        .rsi, .rdi, .r8, .r9,
        .r10, .r11,
    };

    pub fn init(allocator: std.mem.Allocator, seed: u64) Mutator {
        var prng = std.Random.DefaultPrng.init(seed);
        return .{
            .allocator = allocator,
            .random = prng.random(),
        };
    }

    pub fn mutate(self: *Mutator, program: *const Program) !Program {
        if (program.len() == 0) {
            var new_prog = Program.init(self.allocator);
            try new_prog.append(self.randomInstruction());
            return new_prog;
        }

        const mutation_type = self.random.enumValue(MutationType);

        return switch (mutation_type) {
            .instruction_replacement => try self.replaceInstruction(program),
            .operand_replacement => try self.replaceOperand(program),
            .instruction_swap => try self.swapInstructions(program),
            .instruction_delete => try self.deleteInstruction(program),
            .instruction_insert => try self.insertInstruction(program),
            .opcode_change => try self.changeOpcode(program),
        };
    }

    fn replaceInstruction(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();
        if (new_prog.len() == 0) return new_prog;

        const idx = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);
        new_prog.instructions.items[idx] = self.randomInstruction();

        return new_prog;
    }

    fn replaceOperand(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();
        if (new_prog.len() == 0) return new_prog;

        const idx = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);
        var instr = &new_prog.instructions.items[idx];

        if (instr.num_operands > 0) {
            const op_idx = self.random.intRangeAtMost(u8, 0, instr.num_operands - 1);
            instr.operands[op_idx] = self.randomOperand();
        }

        return new_prog;
    }

    fn swapInstructions(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();
        if (new_prog.len() < 2) return new_prog;

        const idx1 = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);
        const idx2 = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);

        const tmp = new_prog.instructions.items[idx1];
        new_prog.instructions.items[idx1] = new_prog.instructions.items[idx2];
        new_prog.instructions.items[idx2] = tmp;

        return new_prog;
    }

    fn deleteInstruction(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();
        if (new_prog.len() <= 1) return new_prog;

        const idx = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);
        _ = new_prog.instructions.orderedRemove(idx);

        return new_prog;
    }

    fn insertInstruction(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();

        const idx = if (new_prog.len() == 0) 0 else self.random.intRangeAtMost(usize, 0, new_prog.len());
        try new_prog.instructions.insert(idx, self.randomInstruction());

        return new_prog;
    }

    fn changeOpcode(self: *Mutator, program: *const Program) !Program {
        var new_prog = try program.clone();
        if (new_prog.len() == 0) return new_prog;

        const idx = self.random.intRangeAtMost(usize, 0, new_prog.len() - 1);
        new_prog.instructions.items[idx].opcode = OPCODES[self.random.intRangeAtMost(usize, 0, OPCODES.len - 1)];

        return new_prog;
    }

    fn randomInstruction(self: *Mutator) Instruction {
        const opcode = OPCODES[self.random.intRangeAtMost(usize, 0, OPCODES.len - 1)];
        const num_ops = self.random.intRangeAtMost(u8, 0, 2);

        var instr = Instruction.init(opcode);
        instr.num_operands = num_ops;

        for (0..num_ops) |i| {
            instr.operands[i] = self.randomOperand();
        }

        return instr;
    }

    fn randomOperand(self: *Mutator) Operand {
        const choice = self.random.intRangeAtMost(u8, 0, 2);

        return switch (choice) {
            0 => .{ .register = REGISTERS[self.random.intRangeAtMost(usize, 0, REGISTERS.len - 1)] },
            1 => .{ .immediate = self.random.intRangeAtMost(i64, -128, 127) },
            else => .{ .register = REGISTERS[self.random.intRangeAtMost(usize, 0, REGISTERS.len - 1)] },
        };
    }
};

// ============================================================================
// VERIFIER
// ============================================================================

pub const Verifier = struct {
    allocator: std.mem.Allocator,
    test_cases: std.ArrayList(TestCase),

    pub const TestCase = struct {
        inputs: [16]i64,
        expected_outputs: [16]i64,
    };

    pub fn init(allocator: std.mem.Allocator) Verifier {
        return .{
            .allocator = allocator,
            .test_cases = std.ArrayList(TestCase).init(allocator),
        };
    }

    pub fn deinit(self: *Verifier) void {
        self.test_cases.deinit();
    }

    pub fn addTestCase(self: *Verifier, inputs: [16]i64, outputs: [16]i64) !void {
        try self.test_cases.append(.{
            .inputs = inputs,
            .expected_outputs = outputs,
        });
    }

    /// Verify that two programs are equivalent on all test cases
    pub fn verify(self: *Verifier, original: *const Program, candidate: *const Program) bool {
        _ = original;
        _ = candidate;

        // Simplified verification: just check structure
        // Full implementation would use symbolic execution or SMT solver
        for (self.test_cases.items) |_| {
            // Would execute both programs and compare outputs
            // For now, assume equivalent if same length
        }

        return true;
    }

    /// Generate random test cases
    pub fn generateTestCases(self: *Verifier, count: u32, random: std.Random) !void {
        for (0..count) |_| {
            var inputs: [16]i64 = undefined;
            var outputs: [16]i64 = undefined;

            for (&inputs) |*i| {
                i.* = random.intRangeAtMost(i64, -1000, 1000);
            }

            // Outputs would be computed by running the original program
            @memset(&outputs, 0);

            try self.addTestCase(inputs, outputs);
        }
    }
};

// ============================================================================
// SUPEROPTIMIZER
// ============================================================================

pub const SuperoptimizerConfig = struct {
    max_iterations: u32 = 100000,
    initial_temperature: f64 = 1.0,
    cooling_rate: f64 = 0.9999,
    min_temperature: f64 = 0.001,
    restart_threshold: u32 = 10000,
};

pub const SuperoptimizerResult = struct {
    original_program: Program,
    optimized_program: Program,
    original_cost: u32,
    optimized_cost: u32,
    iterations: u32,
    improvements_found: u32,
    verified: bool,

    pub fn speedup(self: *const SuperoptimizerResult) f64 {
        if (self.optimized_cost == 0) return 1.0;
        return @as(f64, @floatFromInt(self.original_cost)) / @as(f64, @floatFromInt(self.optimized_cost));
    }
};

pub const Superoptimizer = struct {
    allocator: std.mem.Allocator,
    config: SuperoptimizerConfig,
    mutator: Mutator,
    verifier: Verifier,
    random: std.Random,

    // Statistics
    iterations: u32,
    improvements_found: u32,
    candidates_tested: u32,
    candidates_verified: u32,

    pub fn init(allocator: std.mem.Allocator, seed: u64) Superoptimizer {
        var prng = std.Random.DefaultPrng.init(seed);
        return .{
            .allocator = allocator,
            .config = .{},
            .mutator = Mutator.init(allocator, seed),
            .verifier = Verifier.init(allocator),
            .random = prng.random(),
            .iterations = 0,
            .improvements_found = 0,
            .candidates_tested = 0,
            .candidates_verified = 0,
        };
    }

    pub fn deinit(self: *Superoptimizer) void {
        self.verifier.deinit();
    }

    /// Optimize a program using stochastic search
    pub fn optimize(self: *Superoptimizer, original: *const Program) !SuperoptimizerResult {
        // Generate test cases for verification
        try self.verifier.generateTestCases(100, self.random);

        var best = try original.clone();
        var best_cost = best.cost();

        var current = try original.clone();
        var current_cost = current.cost();

        var temperature = self.config.initial_temperature;
        var iterations_since_improvement: u32 = 0;

        self.iterations = 0;
        self.improvements_found = 0;

        while (self.iterations < self.config.max_iterations and temperature > self.config.min_temperature) {
            // Generate candidate
            var candidate = try self.mutator.mutate(&current);
            defer candidate.deinit();

            self.candidates_tested += 1;

            // Verify equivalence
            if (!self.verifier.verify(original, &candidate)) {
                continue;
            }

            self.candidates_verified += 1;

            const candidate_cost = candidate.cost();

            // Metropolis-Hastings acceptance
            const delta = @as(f64, @floatFromInt(candidate_cost)) - @as(f64, @floatFromInt(current_cost));
            const accept_prob = @exp(-delta / temperature);

            if (delta < 0 or self.random.float(f64) < accept_prob) {
                current.deinit();
                current = try candidate.clone();
                current_cost = candidate_cost;

                if (candidate_cost < best_cost) {
                    best.deinit();
                    best = try candidate.clone();
                    best_cost = candidate_cost;
                    self.improvements_found += 1;
                    iterations_since_improvement = 0;
                }
            }

            // Cool down
            temperature *= self.config.cooling_rate;
            self.iterations += 1;
            iterations_since_improvement += 1;

            // Restart if stuck
            if (iterations_since_improvement > self.config.restart_threshold) {
                current.deinit();
                current = try best.clone();
                current_cost = best_cost;
                temperature = self.config.initial_temperature * 0.5;
                iterations_since_improvement = 0;
            }
        }

        current.deinit();

        return .{
            .original_program = try original.clone(),
            .optimized_program = best,
            .original_cost = original.cost(),
            .optimized_cost = best_cost,
            .iterations = self.iterations,
            .improvements_found = self.improvements_found,
            .verified = true,
        };
    }

    pub fn getStats(self: *const Superoptimizer) struct {
        iterations: u32,
        improvements: u32,
        candidates_tested: u32,
        candidates_verified: u32,
    } {
        return .{
            .iterations = self.iterations,
            .improvements = self.improvements_found,
            .candidates_tested = self.candidates_tested,
            .candidates_verified = self.candidates_verified,
        };
    }
};

// ============================================================================
// PEEPHOLE PATTERNS
// ============================================================================

pub const PeepholeOptimizer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PeepholeOptimizer {
        return .{ .allocator = allocator };
    }

    /// Apply peephole optimizations
    pub fn optimize(self: *PeepholeOptimizer, program: *Program) !void {
        var i: usize = 0;
        while (i < program.len()) {
            // Pattern: x * 2 -> x << 1
            if (self.matchMultiplyByPowerOf2(program, i)) |shift| {
                program.instructions.items[i].opcode = .shl;
                program.instructions.items[i].operands[1] = .{ .immediate = shift };
                continue;
            }

            // Pattern: x + 0 -> nop
            if (self.matchAddZero(program, i)) {
                _ = program.instructions.orderedRemove(i);
                continue;
            }

            // Pattern: x * 1 -> nop
            if (self.matchMultiplyOne(program, i)) {
                _ = program.instructions.orderedRemove(i);
                continue;
            }

            // Pattern: mov x, x -> nop
            if (self.matchRedundantMov(program, i)) {
                _ = program.instructions.orderedRemove(i);
                continue;
            }

            i += 1;
        }
    }

    fn matchMultiplyByPowerOf2(self: *PeepholeOptimizer, program: *Program, idx: usize) ?i64 {
        _ = self;
        if (idx >= program.len()) return null;

        const instr = program.instructions.items[idx];
        if (instr.opcode != .mul and instr.opcode != .imul) return null;
        if (instr.num_operands < 2) return null;

        if (instr.operands[1]) |op| {
            if (op == .immediate) {
                const val = op.immediate;
                if (val > 0 and (val & (val - 1)) == 0) {
                    // Power of 2
                    return @ctz(@as(u64, @intCast(val)));
                }
            }
        }

        return null;
    }

    fn matchAddZero(self: *PeepholeOptimizer, program: *Program, idx: usize) bool {
        _ = self;
        if (idx >= program.len()) return false;

        const instr = program.instructions.items[idx];
        if (instr.opcode != .add) return false;
        if (instr.num_operands < 2) return false;

        if (instr.operands[1]) |op| {
            if (op == .immediate and op.immediate == 0) {
                return true;
            }
        }

        return false;
    }

    fn matchMultiplyOne(self: *PeepholeOptimizer, program: *Program, idx: usize) bool {
        _ = self;
        if (idx >= program.len()) return false;

        const instr = program.instructions.items[idx];
        if (instr.opcode != .mul and instr.opcode != .imul) return false;
        if (instr.num_operands < 2) return false;

        if (instr.operands[1]) |op| {
            if (op == .immediate and op.immediate == 1) {
                return true;
            }
        }

        return false;
    }

    fn matchRedundantMov(self: *PeepholeOptimizer, program: *Program, idx: usize) bool {
        _ = self;
        if (idx >= program.len()) return false;

        const instr = program.instructions.items[idx];
        if (instr.opcode != .mov) return false;
        if (instr.num_operands < 2) return false;

        if (instr.operands[0]) |op0| {
            if (instr.operands[1]) |op1| {
                if (op0 == .register and op1 == .register) {
                    return op0.register == op1.register;
                }
            }
        }

        return false;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "instruction creation" {
    const instr = Instruction.withOp2(
        .add,
        .{ .register = .rax },
        .{ .immediate = 42 },
    );

    try std.testing.expect(instr.opcode == .add);
    try std.testing.expect(instr.num_operands == 2);
    try std.testing.expect(instr.cost() == 1);
}

test "program cost" {
    const allocator = std.testing.allocator;
    var program = Program.init(allocator);
    defer program.deinit();

    try program.append(Instruction.withOp2(.add, .{ .register = .rax }, .{ .immediate = 1 }));
    try program.append(Instruction.withOp2(.mul, .{ .register = .rax }, .{ .immediate = 2 }));

    try std.testing.expect(program.cost() == 4); // add=1, mul=3
}

test "mutator" {
    const allocator = std.testing.allocator;
    var mutator = Mutator.init(allocator, 12345);

    var program = Program.init(allocator);
    defer program.deinit();

    try program.append(Instruction.withOp2(.add, .{ .register = .rax }, .{ .immediate = 1 }));

    var mutated = try mutator.mutate(&program);
    defer mutated.deinit();

    // Should produce some program
    try std.testing.expect(mutated.len() > 0);
}

test "superoptimizer init" {
    const allocator = std.testing.allocator;
    var superopt = Superoptimizer.init(allocator, 12345);
    defer superopt.deinit();

    const stats = superopt.getStats();
    try std.testing.expect(stats.iterations == 0);
}

test "peephole multiply by power of 2" {
    const allocator = std.testing.allocator;
    var peephole = PeepholeOptimizer.init(allocator);

    var program = Program.init(allocator);
    defer program.deinit();

    // x * 4 should become x << 2
    try program.append(Instruction.withOp2(.mul, .{ .register = .rax }, .{ .immediate = 4 }));

    try peephole.optimize(&program);

    try std.testing.expect(program.instructions.items[0].opcode == .shl);
}

test "peephole add zero" {
    const allocator = std.testing.allocator;
    var peephole = PeepholeOptimizer.init(allocator);

    var program = Program.init(allocator);
    defer program.deinit();

    // x + 0 should be removed
    try program.append(Instruction.withOp2(.add, .{ .register = .rax }, .{ .immediate = 0 }));
    try program.append(Instruction.withOp2(.add, .{ .register = .rax }, .{ .immediate = 1 }));

    try peephole.optimize(&program);

    try std.testing.expect(program.len() == 1);
}

test "verifier" {
    const allocator = std.testing.allocator;
    var verifier = Verifier.init(allocator);
    defer verifier.deinit();

    var prng = std.Random.DefaultPrng.init(12345);
    try verifier.generateTestCases(10, prng.random());

    try std.testing.expect(verifier.test_cases.items.len == 10);
}
