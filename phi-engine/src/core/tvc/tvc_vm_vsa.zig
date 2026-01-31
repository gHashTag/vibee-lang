// TVC VM with VSA Support - Ternary Virtual Machine for Hyperdimensional Computing
// Integrates HybridBigInt for memory-efficient vector operations
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const tvc_hybrid = @import("tvc_hybrid.zig");
const tvc_vsa = @import("tvc_vsa.zig");

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAOpcode = enum(u8) {
    // Vector operations
    v_load,      // Load vector from memory
    v_store,     // Store vector to memory
    v_const,     // Load constant vector
    v_random,    // Generate random vector

    // VSA operations
    v_bind,      // Bind two vectors (XOR-like)
    v_unbind,    // Unbind (same as bind)
    v_bundle2,   // Bundle 2 vectors
    v_bundle3,   // Bundle 3 vectors

    // Similarity operations
    v_dot,       // Dot product
    v_cosine,    // Cosine similarity
    v_hamming,   // Hamming distance

    // Arithmetic
    v_add,       // Vector addition
    v_neg,       // Vector negation
    v_mul,       // Element-wise multiplication

    // Control
    v_mov,       // Move between vector registers
    v_pack,      // Pack vector (save memory)
    v_unpack,    // Unpack vector (for computation)

    // Comparison
    v_cmp,       // Compare vectors (sets condition codes)

    // Permute operations (для кодирования последовательностей)
    v_permute,   // Циклический сдвиг вправо
    v_ipermute,  // Обратный сдвиг (влево)
    v_seq,       // Encode sequence

    nop,
    halt,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSARegisters = struct {
    // Vector registers (HybridBigInt for memory efficiency)
    v0: HybridBigInt = HybridBigInt.zero(),
    v1: HybridBigInt = HybridBigInt.zero(),
    v2: HybridBigInt = HybridBigInt.zero(),
    v3: HybridBigInt = HybridBigInt.zero(),

    // Scalar registers
    s0: i64 = 0,  // For dot product results
    s1: i64 = 0,
    f0: f64 = 0.0, // For similarity results
    f1: f64 = 0.0,

    // Program counter
    pc: u32 = 0,

    // Condition codes
    cc_zero: bool = false,
    cc_neg: bool = false,
    cc_pos: bool = false,

    // Memory usage tracking
    total_packed_bytes: usize = 0,

    pub fn updateMemoryUsage(self: *VSARegisters) void {
        self.v0.pack();
        self.v1.pack();
        self.v2.pack();
        self.v3.pack();
        self.total_packed_bytes = self.v0.memoryUsage() +
            self.v1.memoryUsage() +
            self.v2.memoryUsage() +
            self.v3.memoryUsage();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA INSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAInstruction = struct {
    opcode: VSAOpcode,
    dst: u8 = 0,    // Destination register (0-3 for v0-v3)
    src1: u8 = 0,   // Source register 1
    src2: u8 = 0,   // Source register 2
    imm: i64 = 0,   // Immediate value
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAVM = struct {
    registers: VSARegisters,
    program: std.ArrayList(VSAInstruction),
    halted: bool = false,
    allocator: std.mem.Allocator,
    cycle_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) VSAVM {
        return VSAVM{
            .registers = .{},
            .program = std.ArrayList(VSAInstruction).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VSAVM) void {
        self.program.deinit();
    }

    pub fn loadProgram(self: *VSAVM, instructions: []const VSAInstruction) !void {
        self.program.clearRetainingCapacity();
        try self.program.appendSlice(instructions);
        self.registers.pc = 0;
        self.halted = false;
        self.cycle_count = 0;
    }

    pub fn step(self: *VSAVM) !bool {
        if (self.halted or self.registers.pc >= self.program.items.len) {
            return false;
        }

        const inst = self.program.items[self.registers.pc];
        try self.execute(inst);
        self.registers.pc += 1;
        self.cycle_count += 1;

        return !self.halted;
    }

    pub fn run(self: *VSAVM) !void {
        while (try self.step()) {}
    }

    fn execute(self: *VSAVM, inst: VSAInstruction) !void {
        switch (inst.opcode) {
            .v_load => self.execVLoad(inst),
            .v_store => self.execVStore(inst),
            .v_const => self.execVConst(inst),
            .v_random => self.execVRandom(inst),

            .v_bind => self.execVBind(inst),
            .v_unbind => self.execVUnbind(inst),
            .v_bundle2 => self.execVBundle2(inst),
            .v_bundle3 => self.execVBundle3(inst),

            .v_dot => self.execVDot(inst),
            .v_cosine => self.execVCosine(inst),
            .v_hamming => self.execVHamming(inst),

            .v_add => self.execVAdd(inst),
            .v_neg => self.execVNeg(inst),
            .v_mul => self.execVMul(inst),

            .v_mov => self.execVMov(inst),
            .v_pack => self.execVPack(inst),
            .v_unpack => self.execVUnpack(inst),

            .v_cmp => self.execVCmp(inst),

            .v_permute => self.execVPermute(inst),
            .v_ipermute => self.execVIPermute(inst),
            .v_seq => self.execVSeq(inst),

            .nop => {},
            .halt => self.halted = true,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INSTRUCTION IMPLEMENTATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    fn getVReg(self: *VSAVM, idx: u8) *HybridBigInt {
        return switch (idx) {
            0 => &self.registers.v0,
            1 => &self.registers.v1,
            2 => &self.registers.v2,
            3 => &self.registers.v3,
            else => &self.registers.v0,
        };
    }

    fn execVLoad(self: *VSAVM, inst: VSAInstruction) void {
        // Load from scalar to vector
        const dst = self.getVReg(inst.dst);
        dst.* = HybridBigInt.fromI64(inst.imm);
    }

    fn execVStore(self: *VSAVM, inst: VSAInstruction) void {
        // Store vector to scalar
        const src = self.getVReg(inst.src1);
        self.registers.s0 = src.toI64();
    }

    fn execVConst(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        dst.* = HybridBigInt.fromI64(inst.imm);
    }

    fn execVRandom(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const seed: u64 = @bitCast(inst.imm);
        dst.* = tvc_vsa.randomVector(MAX_TRITS, seed);
    }

    fn execVBind(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = tvc_vsa.bind(&src1, &src2);
    }

    fn execVUnbind(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = tvc_vsa.unbind(&src1, &src2);
    }

    fn execVBundle2(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = tvc_vsa.bundle2(&src1, &src2);
    }

    fn execVBundle3(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        var src3 = self.getVReg(inst.dst).*; // Use dst as third source
        dst.* = tvc_vsa.bundle3(&src1, &src2, &src3);
    }

    fn execVDot(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        self.registers.s0 = src1.dotProduct(&src2);
    }

    fn execVCosine(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        self.registers.f0 = tvc_vsa.cosineSimilarity(&src1, &src2);
    }

    fn execVHamming(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        self.registers.s0 = @intCast(tvc_vsa.hammingDistance(&src1, &src2));
    }

    fn execVAdd(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = src1.add(&src2);
    }

    fn execVNeg(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const src = self.getVReg(inst.src1);
        dst.* = src.negate();
    }

    fn execVMul(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = src1.mul(&src2);
    }

    fn execVMov(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const src = self.getVReg(inst.src1);
        dst.* = src.*;
    }

    fn execVPack(self: *VSAVM, inst: VSAInstruction) void {
        const reg = self.getVReg(inst.dst);
        reg.pack();
    }

    fn execVUnpack(self: *VSAVM, inst: VSAInstruction) void {
        const reg = self.getVReg(inst.dst);
        reg.ensureUnpacked();
    }

    fn execVCmp(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        const sim = tvc_vsa.cosineSimilarity(&src1, &src2);

        self.registers.cc_zero = sim > -0.1 and sim < 0.1;
        self.registers.cc_neg = sim < -0.1;
        self.registers.cc_pos = sim > 0.1;
        self.registers.f0 = sim;
    }

    fn execVPermute(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src = self.getVReg(inst.src1).*;
        const shift: usize = @intCast(inst.imm);
        dst.* = tvc_vsa.permute(&src, shift);
    }

    fn execVIPermute(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src = self.getVReg(inst.src1).*;
        const shift: usize = @intCast(inst.imm);
        dst.* = tvc_vsa.inversePermute(&src, shift);
    }

    fn execVSeq(self: *VSAVM, inst: VSAInstruction) void {
        // Encode sequence from v0, v1 into dst
        // v_seq dst, src1, src2 -> dst = src1 + permute(src2, 1)
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        var permuted = tvc_vsa.permute(&src2, 1);
        dst.* = src1.add(&permuted);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEBUG
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn printState(self: *VSAVM) void {
        self.registers.updateMemoryUsage();

        std.debug.print("\n╔══════════════════════════════════════════╗\n", .{});
        std.debug.print("║           VSA VM STATE                   ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ VECTOR REGISTERS:                        ║\n", .{});
        std.debug.print("║  v0: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v0.trit_len, self.registers.v0.memoryUsage() });
        std.debug.print("║  v1: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v1.trit_len, self.registers.v1.memoryUsage() });
        std.debug.print("║  v2: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v2.trit_len, self.registers.v2.memoryUsage() });
        std.debug.print("║  v3: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v3.trit_len, self.registers.v3.memoryUsage() });
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ SCALAR REGISTERS:                        ║\n", .{});
        std.debug.print("║  s0: {}                                  ║\n", .{self.registers.s0});
        std.debug.print("║  f0: {d:.6}                              ║\n", .{self.registers.f0});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ EXECUTION:                               ║\n", .{});
        std.debug.print("║  pc: {}, cycles: {}                      ║\n", .{ self.registers.pc, self.cycle_count });
        std.debug.print("║  halted: {}                              ║\n", .{self.halted});
        std.debug.print("║  total memory: {} bytes                  ║\n", .{self.registers.total_packed_bytes});
        std.debug.print("╚══════════════════════════════════════════╝\n\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VSA VM basic operations" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 },
        .{ .opcode = .v_const, .dst = 1, .imm = 67890 },
        .{ .opcode = .v_add, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .v_store, .src1 = 2 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    try std.testing.expectEqual(@as(i64, 12345 + 67890), vm.registers.s0);
}

test "VSA VM bind/unbind" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    // Test bind self-inverse property: bind(a, a) = all +1 for non-zero
    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 111 },
        .{ .opcode = .v_bind, .dst = 1, .src1 = 0, .src2 = 0 }, // bind(v0, v0)
        .{ .opcode = .v_dot, .src1 = 1, .src2 = 1 }, // dot(v1, v1) should be high
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // bind(a, a) produces vector with many +1s, dot product should be positive
    try std.testing.expect(vm.registers.s0 > 0);
}

test "VSA VM bundle similarity" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 333 },
        .{ .opcode = .v_random, .dst = 1, .imm = 444 },
        .{ .opcode = .v_bundle2, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Bundle should be similar to inputs
    try std.testing.expect(vm.registers.f0 > 0.3);
}

test "VSA VM permute" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 999 },
        .{ .opcode = .v_permute, .dst = 1, .src1 = 0, .imm = 5 }, // permute by 5
        .{ .opcode = .v_ipermute, .dst = 2, .src1 = 1, .imm = 5 }, // inverse permute
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 }, // should be identical
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // After permute then inverse_permute, should be identical (similarity ~1.0)
    try std.testing.expect(vm.registers.f0 > 0.99);
}

test "VSA VM memory efficiency" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 555 },
        .{ .opcode = .v_random, .dst = 1, .imm = 666 },
        .{ .opcode = .v_random, .dst = 2, .imm = 777 },
        .{ .opcode = .v_random, .dst = 3, .imm = 888 },
        .{ .opcode = .v_pack, .dst = 0 },
        .{ .opcode = .v_pack, .dst = 1 },
        .{ .opcode = .v_pack, .dst = 2 },
        .{ .opcode = .v_pack, .dst = 3 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    vm.registers.updateMemoryUsage();

    // 4 vectors * 256 trits / 5 trits per byte = ~205 bytes
    // vs 4 * 256 = 1024 bytes unpacked
    try std.testing.expect(vm.registers.total_packed_bytes < 250);
}

test "VSA VM dot product" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 },
        .{ .opcode = .v_mov, .dst = 1, .src1 = 0 },
        .{ .opcode = .v_dot, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Dot product of identical vectors should be positive
    try std.testing.expect(vm.registers.s0 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = VSAVM.init(allocator);
    defer vm.deinit();

    const iterations: u64 = 10000;

    std.debug.print("\nVSA VM Benchmarks\n", .{});
    std.debug.print("=================\n\n", .{});

    // Benchmark: Bind operation
    const bind_program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 111 },
        .{ .opcode = .v_random, .dst = 1, .imm = 222 },
        .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    vm.loadProgram(&bind_program) catch unreachable;

    const bind_start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        vm.registers.pc = 2; // Skip random generation
        vm.halted = false;
        vm.run() catch unreachable;
    }
    const bind_end = std.time.nanoTimestamp();
    const bind_ns = @as(u64, @intCast(bind_end - bind_start));

    std.debug.print("Bind x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n\n", .{ bind_ns, bind_ns / iterations });

    // Benchmark: Similarity
    const sim_program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 333 },
        .{ .opcode = .v_random, .dst = 1, .imm = 444 },
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    vm.loadProgram(&sim_program) catch unreachable;

    const sim_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        vm.registers.pc = 2;
        vm.halted = false;
        vm.run() catch unreachable;
    }
    const sim_end = std.time.nanoTimestamp();
    const sim_ns = @as(u64, @intCast(sim_end - sim_start));

    std.debug.print("Cosine Similarity x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n\n", .{ sim_ns, sim_ns / iterations });

    // Memory usage
    vm.registers.updateMemoryUsage();
    std.debug.print("Memory Usage:\n", .{});
    std.debug.print("  4 vectors packed: {} bytes\n", .{vm.registers.total_packed_bytes});
    std.debug.print("  4 vectors unpacked: {} bytes\n", .{4 * MAX_TRITS});
    std.debug.print("  Savings: {d:.1}x\n", .{@as(f64, @floatFromInt(4 * MAX_TRITS)) / @as(f64, @floatFromInt(vm.registers.total_packed_bytes))});
}

pub fn main() !void {
    runBenchmarks();
}
