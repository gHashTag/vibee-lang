// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC CORE INTEGRATION TEST
// ═══════════════════════════════════════════════════════════════════════════════
// Tests integration between core modules and existing infrastructure
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const core = @import("mod.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NanBoxedValue size is 8 bytes" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(core.NanBoxedValue));
}

test "Value arithmetic chain" {
    const a = core.Value.int(100);
    const b = core.Value.int(50);
    const c = core.Value.int(2);

    // (100 + 50) * 2 = 300
    const sum = core.Value.add(a, b);
    const result = core.Value.mul(sum, c);

    try std.testing.expectEqual(@as(i64, 300), result.asInt());
}

test "Value float operations" {
    const phi = core.Value.float(core.PHI);
    const phi_sq = core.Value.mul(phi, phi);

    // φ² ≈ 2.618
    try std.testing.expectApproxEqAbs(core.PHI_SQ, phi_sq.asFloat(), 0.0001);
}

test "Value ternary operations" {
    const t = core.Value.trit(1); // True
    const f = core.Value.trit(-1); // False
    const u = core.Value.trit(0); // Unknown

    // Ternary NOT
    try std.testing.expectEqual(@as(i8, -1), t.tritNot().asTrit());
    try std.testing.expectEqual(@as(i8, 1), f.tritNot().asTrit());
    try std.testing.expectEqual(@as(i8, 0), u.tritNot().asTrit());

    // Ternary AND (min)
    try std.testing.expectEqual(@as(i8, -1), core.Value.tritAnd(t, f).asTrit());
    try std.testing.expectEqual(@as(i8, 0), core.Value.tritAnd(t, u).asTrit());

    // Ternary OR (max)
    try std.testing.expectEqual(@as(i8, 1), core.Value.tritOr(t, f).asTrit());
    try std.testing.expectEqual(@as(i8, 1), core.Value.tritOr(t, u).asTrit());
}

// ═══════════════════════════════════════════════════════════════════════════════
// VM INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VM executes simple program" {
    var vm = try core.VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    // Program: push 10, push 20, add, halt
    const constants = [_]core.Value{
        core.Value.int(10),
        core.Value.int(20),
    };

    const code = [_]u8{
        @intFromEnum(core.Opcode.load_const), 0, 0, // push constants[0] = 10
        @intFromEnum(core.Opcode.load_const), 0, 1, // push constants[1] = 20
        @intFromEnum(core.Opcode.add), // 10 + 20 = 30
        @intFromEnum(core.Opcode.halt),
    };

    vm.load(&code, &constants);
    const result = try vm.run();

    try std.testing.expectEqual(@as(i64, 30), result.asInt());
}

test "VM executes comparison" {
    var vm = try core.VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const constants = [_]core.Value{
        core.Value.int(5),
        core.Value.int(10),
    };

    // 5 < 10 = true
    const code = [_]u8{
        @intFromEnum(core.Opcode.load_const), 0, 0,
        @intFromEnum(core.Opcode.load_const), 0, 1,
        @intFromEnum(core.Opcode.lt),
        @intFromEnum(core.Opcode.halt),
    };

    vm.load(&code, &constants);
    const result = try vm.run();

    try std.testing.expect(result.asBool());
}

test "VM print captures output" {
    var vm = try core.VM.init(std.testing.allocator, .{});
    defer vm.deinit();

    const constants = [_]core.Value{core.Value.int(42)};

    const code = [_]u8{
        @intFromEnum(core.Opcode.load_const), 0, 0,
        @intFromEnum(core.Opcode.print),
        @intFromEnum(core.Opcode.halt),
    };

    vm.load(&code, &constants);
    _ = try vm.run();

    try std.testing.expectEqualStrings("42\n", vm.getOutput());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRIDGE INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Bridge converts tagged to nan" {
    const tagged = core.TaggedValue{ .int_val = 123 };
    const nan = core.taggedToNan(tagged);

    try std.testing.expect(nan.isInt());
    try std.testing.expectEqual(@as(i64, 123), nan.asInt());
}

test "Bridge converts nan to tagged" {
    const nan = core.NanBoxedValue.boolean(true);
    const tagged = core.nanToTagged(nan);

    try std.testing.expect(tagged.toBool());
}

test "Bridge maps opcodes correctly" {
    // Legacy ADD = 0x10
    try std.testing.expectEqual(core.Opcode.add, core.mapOpcode(0x10));
    // Legacy SUB = 0x11
    try std.testing.expectEqual(core.Opcode.sub, core.mapOpcode(0x11));
    // Legacy HALT = 0x45
    try std.testing.expectEqual(core.Opcode.halt, core.mapOpcode(0x45));
    // Legacy TRIT_NOT = 0x71
    try std.testing.expectEqual(core.Opcode.trit_not, core.mapOpcode(0x71));
}

test "BytecodeTranslator translates legacy code" {
    var translator = core.BytecodeTranslator.init(std.testing.allocator);
    defer translator.deinit();

    // Legacy: ADD, SUB, HALT
    const legacy = [_]u8{ 0x10, 0x11, 0x45 };
    const translated = try translator.translate(&legacy);

    try std.testing.expectEqual(@as(usize, 3), translated.len);
    try std.testing.expectEqual(@intFromEnum(core.Opcode.add), translated[0]);
    try std.testing.expectEqual(@intFromEnum(core.Opcode.sub), translated[1]);
    try std.testing.expectEqual(@intFromEnum(core.Opcode.halt), translated[2]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JIT INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JIT encoder generates valid x86-64" {
    var enc = core.X64Encoder.init(std.testing.allocator);
    defer enc.deinit();

    // Generate: push rbp; mov rbp, rsp; pop rbp; ret
    try enc.push(.rbp);
    try enc.movReg(.rbp, .rsp);
    try enc.pop(.rbp);
    try enc.ret();

    const code = enc.getCode();
    try std.testing.expect(code.len > 0);

    // Verify PUSH RBP = 0x55
    try std.testing.expectEqual(@as(u8, 0x55), code[0]);
}

test "JitCompiler compiles bytecode" {
    var jit = core.JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    const constants = [_]core.Value{core.Value.int(42)};
    const bytecode = [_]u8{
        @intFromEnum(core.Opcode.load_const), 0, 0,
        @intFromEnum(core.Opcode.halt),
    };

    const machine_code = try jit.compile(&bytecode, &constants);
    try std.testing.expect(machine_code.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN IDENTITY TEST
// ═══════════════════════════════════════════════════════════════════════════════

test "Golden Identity: phi^2 + 1/phi^2 = 3" {
    const phi = core.PHI;
    const phi_sq = phi * phi;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;

    // φ² + 1/φ² = 3
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0000001);
}
