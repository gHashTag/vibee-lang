// ═══════════════════════════════════════════════════════════════════════════════
// JIT ADAPTER INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════
// Tests for executing real .999 bytecode patterns with JIT support
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const jit_adapter = @import("jit_adapter.zig");
const JITAdapter = jit_adapter.JITAdapter;
const JITMode = jit_adapter.JITMode;
const vm_runtime = @import("vm_runtime.zig");
const VM = vm_runtime.VM;
const bytecode = @import("bytecode.zig");
const Opcode = bytecode.Opcode;
const Value = bytecode.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// TEST HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn emitU16(code: *std.ArrayList(u8), val: u16) !void {
    try code.append(@intCast(val >> 8));
    try code.append(@intCast(val & 0xFF));
}

fn emitOp(code: *std.ArrayList(u8), op: Opcode) !void {
    try code.append(@intFromEnum(op));
}

fn emitOpU16(code: *std.ArrayList(u8), op: Opcode, val: u16) !void {
    try emitOp(code, op);
    try emitU16(code, val);
}

fn emitOpU8(code: *std.ArrayList(u8), op: Opcode, val: u8) !void {
    try emitOp(code, op);
    try code.append(val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BASIC EXECUTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute simple arithmetic: 2 + 3 = 5" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // PUSH_CONST 0 (2)
    // PUSH_CONST 1 (3)
    // ADD
    // HALT
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOp(&code, .ADD);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 2 },
        .{ .int_val = 3 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 5), result.value.int_val);
}

test "execute multiplication: 7 * 6 = 42" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOp(&code, .MUL);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 7 },
        .{ .int_val = 6 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 42), result.value.int_val);
}

test "execute comparison: 5 < 10 = true" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOp(&code, .LT);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 5 },
        .{ .int_val = 10 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .bool_val);
    try std.testing.expect(result.value.bool_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL VARIABLE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute local variable store and load" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // let x = 42
    // return x
    try emitOpU16(&code, .PUSH_CONST, 0); // push 42
    try emitOpU16(&code, .STORE_LOCAL, 0); // store to local 0
    try emitOpU16(&code, .LOAD_LOCAL, 0); // load from local 0
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 42 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 42), result.value.int_val);
}

test "execute local variable arithmetic" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // let a = 10
    // let b = 5
    // return a + b
    try emitOpU16(&code, .PUSH_CONST, 0); // push 10
    try emitOpU16(&code, .STORE_LOCAL, 0); // a = 10
    try emitOpU16(&code, .PUSH_CONST, 1); // push 5
    try emitOpU16(&code, .STORE_LOCAL, 1); // b = 5
    try emitOpU16(&code, .LOAD_LOCAL, 0); // load a
    try emitOpU16(&code, .LOAD_LOCAL, 1); // load b
    try emitOp(&code, .ADD); // a + b
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 10 },
        .{ .int_val = 5 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 15), result.value.int_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROL FLOW TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute conditional jump (if-else)" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // if (true) { return 1 } else { return 0 }
    try emitOpU16(&code, .PUSH_CONST, 0); // push true
    try emitOpU16(&code, .JZ, 12); // if false, jump to else
    try emitOpU16(&code, .PUSH_CONST, 1); // push 1
    try emitOpU16(&code, .JMP, 15); // jump to end
    // else:
    try emitOpU16(&code, .PUSH_CONST, 2); // push 0
    // end:
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .bool_val = true },
        .{ .int_val = 1 },
        .{ .int_val = 0 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 1), result.value.int_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute simple loop: sum 1 to 5" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // let sum = 0
    // let i = 1
    // while i <= 5:
    //   sum = sum + i
    //   i = i + 1
    // return sum

    // Initialize sum = 0
    try emitOpU16(&code, .PUSH_CONST, 0); // push 0
    try emitOpU16(&code, .STORE_LOCAL, 0); // sum = 0

    // Initialize i = 1
    try emitOpU16(&code, .PUSH_CONST, 1); // push 1
    try emitOpU16(&code, .STORE_LOCAL, 1); // i = 1

    // Loop start (offset 12)
    const loop_start: u16 = @intCast(code.items.len);

    // Check i <= 5
    try emitOpU16(&code, .LOAD_LOCAL, 1); // load i
    try emitOpU16(&code, .PUSH_CONST, 2); // push 5
    try emitOp(&code, .LE); // i <= 5
    try emitOpU16(&code, .JZ, 0); // placeholder for loop end
    const jz_patch = code.items.len - 2;

    // sum = sum + i
    try emitOpU16(&code, .LOAD_LOCAL, 0); // load sum
    try emitOpU16(&code, .LOAD_LOCAL, 1); // load i
    try emitOp(&code, .ADD); // sum + i
    try emitOpU16(&code, .STORE_LOCAL, 0); // sum = sum + i

    // i = i + 1
    try emitOpU16(&code, .LOAD_LOCAL, 1); // load i
    try emitOp(&code, .INC); // i + 1
    try emitOpU16(&code, .STORE_LOCAL, 1); // i = i + 1

    // Jump back to loop start
    try emitOpU16(&code, .JMP, loop_start);

    // Loop end
    const loop_end: u16 = @intCast(code.items.len);
    code.items[jz_patch] = @intCast(loop_end >> 8);
    code.items[jz_patch + 1] = @intCast(loop_end & 0xFF);

    // Return sum
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 0 },
        .{ .int_val = 1 },
        .{ .int_val = 5 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 15), result.value.int_val); // 1+2+3+4+5 = 15
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRYTE OPERATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute tryte addition" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // 5 +t 3 = 8
    try emitOpU16(&code, .PUSH_CONST, 0); // push tryte 5
    try emitOpU16(&code, .PUSH_CONST, 1); // push tryte 3
    try emitOp(&code, .TRYTE_ADD);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .tryte_val = 5 },
        .{ .tryte_val = 3 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .tryte_val);
    try std.testing.expectEqual(@as(i8, 8), result.value.tryte_val);
}

test "execute tryte wrap around" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // 13 +t 1 = -13 (wrap around in balanced ternary)
    try emitOpU16(&code, .PUSH_CONST, 0); // push tryte 13
    try emitOpU16(&code, .PUSH_CONST, 1); // push tryte 1
    try emitOp(&code, .TRYTE_ADD);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .tryte_val = 13 },
        .{ .tryte_val = 1 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .tryte_val);
    try std.testing.expectEqual(@as(i8, -13), result.value.tryte_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute sacred constants" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // Push PHI
    try emitOp(&code, .PUSH_PHI);
    try emitOp(&code, .HALT);

    const result = try adapter.execute(code.items, &[_]Value{});

    try std.testing.expect(result.value == .float_val);
    try std.testing.expectApproxEqAbs(1.618033988749895, result.value.float_val, 0.0001);
}

test "execute golden identity" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // φ² + 1/φ² = 3
    try emitOp(&code, .GOLDEN_IDENTITY_OP);
    try emitOp(&code, .HALT);

    const result = try adapter.execute(code.items, &[_]Value{});

    try std.testing.expect(result.value == .float_val);
    try std.testing.expectApproxEqAbs(3.0, result.value.float_val, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JIT MODE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "execute in mixed mode" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Mixed);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOp(&code, .ADD);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 100 },
        .{ .int_val = 200 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 300), result.value.int_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "verify execution metrics" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOp(&code, .HALT);

    const constants = [_]Value{.{ .int_val = 1 }};

    _ = try adapter.execute(code.items, &constants);

    const metrics = adapter.getMetrics();
    try std.testing.expect(metrics.interpreter_instructions > 0);
    try std.testing.expectEqual(@as(u64, 0), metrics.jit_instructions);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI TEST (Complex Program)
// ═══════════════════════════════════════════════════════════════════════════════

test "execute fibonacci(10) = 55" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Interpreter);

    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    // Fibonacci iterative:
    // let a = 0, b = 1, n = 10
    // while n > 0:
    //   temp = a + b
    //   a = b
    //   b = temp
    //   n = n - 1
    // return a

    // a = 0 (local 0)
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // b = 1 (local 1)
    try emitOpU16(&code, .PUSH_CONST, 1);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // n = 10 (local 2)
    try emitOpU16(&code, .PUSH_CONST, 2);
    try emitOpU16(&code, .STORE_LOCAL, 2);

    // Loop start
    const loop_start: u16 = @intCast(code.items.len);

    // Check n > 0
    try emitOpU16(&code, .LOAD_LOCAL, 2);
    try emitOpU16(&code, .PUSH_CONST, 0);
    try emitOp(&code, .GT);
    try emitOpU16(&code, .JZ, 0); // placeholder
    const jz_patch = code.items.len - 2;

    // temp = a + b (local 3)
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOp(&code, .ADD);
    try emitOpU16(&code, .STORE_LOCAL, 3);

    // a = b
    try emitOpU16(&code, .LOAD_LOCAL, 1);
    try emitOpU16(&code, .STORE_LOCAL, 0);

    // b = temp
    try emitOpU16(&code, .LOAD_LOCAL, 3);
    try emitOpU16(&code, .STORE_LOCAL, 1);

    // n = n - 1
    try emitOpU16(&code, .LOAD_LOCAL, 2);
    try emitOp(&code, .DEC);
    try emitOpU16(&code, .STORE_LOCAL, 2);

    // Jump back
    try emitOpU16(&code, .JMP, loop_start);

    // Loop end
    const loop_end: u16 = @intCast(code.items.len);
    code.items[jz_patch] = @intCast(loop_end >> 8);
    code.items[jz_patch + 1] = @intCast(loop_end & 0xFF);

    // Return a
    try emitOpU16(&code, .LOAD_LOCAL, 0);
    try emitOp(&code, .HALT);

    const constants = [_]Value{
        .{ .int_val = 0 },
        .{ .int_val = 1 },
        .{ .int_val = 10 },
    };

    const result = try adapter.execute(code.items, &constants);

    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 55), result.value.int_val);
}
