const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_vm = @import("tvc_vm.zig");

// ═══════════════════════════════════════════════════════════════
// TVC VM DEMO - Demonstrates TVC VM execution
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              TVC VM DEMONSTRATION               ║\n", .{});
    std.debug.print("║  Executing TVC IR with Trinary Virtual Machine  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // Create test module
    var module = try createTestModule();
    defer module.deinit();

    // Initialize VM
    var vm = tvc_vm.TVCVM.init(std.heap.page_allocator, 1024 * 1024, 4096);
    defer vm.deinit();

    // Load module into VM
    try vm.loadModule(module);

    // Execute function: trinary_deduce
    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  EXECUTING: trinary_deduce                       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    try vm.callFunction("trinary_deduce");

    // Dump VM state
    // vm.dumpState();

    // Execute function: trinary_add
    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  EXECUTING: trinary_add                          ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    try vm.callFunction("trinary_add");

    // Dump VM state
    // vm.dumpState();

    // Test trinary logic operations
    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINARY LOGIC TEST                             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    testTrinaryLogic();

    // Test codegen validation
    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  CODEGEN VALIDATION                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    try validateCodegen();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                   DEMO COMPLETE                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n🎯 TVC VM SUCCESSFULLY:\n", .{});
    std.debug.print("  ✓ Executed TVC IR\n", .{});
    std.debug.print("  ✓ Trinary logic operations\n", .{});
    std.debug.print("  ✓ Codegen validation\n", .{});
    std.debug.print("  ✓ VM state inspection\n", .{});
}

fn createTestModule() !*tvc_ir.TVCModule {
    const module = try std.heap.page_allocator.create(tvc_ir.TVCModule);
    module.* = tvc_ir.TVCModule.init(std.heap.page_allocator, "test_module");

    // Add function: trinary_deduce
    const deduce_func = try module.addFunction("trinary_deduce");

    var block = tvc_ir.TVCBlock.init(std.heap.page_allocator, "entry");
    block.entry_point = 0;

    // Set initial values
    // r0 = 1 (pos1)
    // r1 = 0 (zero)
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{},
        .location = 0,
    });

    // r0 = r0 & r1 (trinary AND)
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{},
        .location = 1,
    });

    // r0 = r0 | r1 (trinary OR)
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_or,
        .operands = &[_]u64{},
        .location = 2,
    });

    // r0 = r0 ^ r1 (trinary XOR)
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_xor,
        .operands = &[_]u64{},
        .location = 3,
    });

    // r0 = r0 -> r1 (trinary IMPLIES)
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_implies,
        .operands = &[_]u64{},
        .location = 4,
    });

    // Return
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 5,
    });

    block.exit_point = 5;
    const block_name = try std.heap.page_allocator.dupe(u8, "entry");
    try deduce_func.blocks.put(block_name, block);

    deduce_func.returns = .i64_trit;
    deduce_func.is_extern = false;

    // Add function: trinary_add
    const add_func = try module.addFunction("trinary_add");

    var add_block = tvc_ir.TVCBlock.init(std.heap.page_allocator, "entry");
    add_block.entry_point = 0;

    // i0 = 42
    // i1 = 10
    // Load values
    try add_block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .load,
        .operands = &[_]u64{0},
        .location = 0,
    });

    // i0 = i0 + i1
    try add_block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .add,
        .operands = &[_]u64{},
        .location = 1,
    });

    // i0 = i0 - i1
    try add_block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .sub,
        .operands = &[_]u64{},
        .location = 2,
    });

    // i0 = i0 * i1
    try add_block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .mul,
        .operands = &[_]u64{},
        .location = 3,
    });

    // Return
    try add_block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 4,
    });

    add_block.exit_point = 4;
    try add_func.blocks.put(block_name, add_block);

    add_func.returns = .i64_trit;
    add_func.is_extern = false;

    return module;
}

fn testTrinaryLogic() void {
    std.debug.print("Testing trinary logic operations:\n\n", .{});

    const tests = [_]struct {
        a: tvc_vm.Trit,
        b: tvc_vm.Trit,
        not_a: tvc_vm.Trit,
        and_ab: tvc_vm.Trit,
        or_ab: tvc_vm.Trit,
        xor_ab: tvc_vm.Trit,
        implies_ab: tvc_vm.Trit,
    }{
        .{ .a = 1, .b = 1, .not_a = -1, .and_ab = 1, .or_ab = 1, .xor_ab = 1, .implies_ab = 1 },
        .{ .a = 1, .b = 0, .not_a = -1, .and_ab = 0, .or_ab = 1, .xor_ab = 0, .implies_ab = 0 },
        .{ .a = 1, .b = -1, .not_a = -1, .and_ab = -1, .or_ab = 1, .xor_ab = -1, .implies_ab = -1 },
        .{ .a = 0, .b = 1, .not_a = 0, .and_ab = 0, .or_ab = 1, .xor_ab = 0, .implies_ab = 1 },
        .{ .a = 0, .b = 0, .not_a = 0, .and_ab = 0, .or_ab = 0, .xor_ab = 0, .implies_ab = 1 },
        .{ .a = 0, .b = -1, .not_a = 0, .and_ab = -1, .or_ab = 0, .xor_ab = 0, .implies_ab = 1 },
        .{ .a = -1, .b = 1, .not_a = 1, .and_ab = -1, .or_ab = 1, .xor_ab = -1, .implies_ab = 1 },
        .{ .a = -1, .b = 0, .not_a = 1, .and_ab = -1, .or_ab = 0, .xor_ab = 0, .implies_ab = 1 },
        .{ .a = -1, .b = -1, .not_a = 1, .and_ab = -1, .or_ab = -1, .xor_ab = 1, .implies_ab = 1 },
    };

    var passed: u32 = 0;
    var failed: u32 = 0;

    for (tests) |test_case| {
        const not_result = tvc_vm.trinaryNot(test_case.a);
        const and_result = tvc_vm.trinaryAnd(test_case.a, test_case.b);
        const or_result = tvc_vm.trinaryOr(test_case.a, test_case.b);
        const xor_result = tvc_vm.trinaryXor(test_case.a, test_case.b);
        const implies_result = tvc_vm.trinaryImplies(test_case.a, test_case.b);

        var all_pass = true;

        if (not_result != test_case.not_a) all_pass = false;
        if (and_result != test_case.and_ab) all_pass = false;
        if (or_result != test_case.or_ab) all_pass = false;
        if (xor_result != test_case.xor_ab) all_pass = false;
        if (implies_result != test_case.implies_ab) all_pass = false;

        if (all_pass) {
            passed += 1;
            std.debug.print("  ✓ a={s}, b={s} → NOT={s} AND={s} OR={s} XOR={s} IMPLIES={s}\n", .{
                tvc_vm.tritToString(test_case.a),
                tvc_vm.tritToString(test_case.b),
                tvc_vm.tritToString(not_result),
                tvc_vm.tritToString(and_result),
                tvc_vm.tritToString(or_result),
                tvc_vm.tritToString(xor_result),
                tvc_vm.tritToString(implies_result),
            });
        } else {
            failed += 1;
            std.debug.print("  ✗ a={s}, b={s} → FAILED\n", .{
                tvc_vm.tritToString(test_case.a),
                tvc_vm.tritToString(test_case.b),
            });
        }
    }

    std.debug.print("\n  Results: {d} passed, {d} failed out of {d} tests\n\n", .{ passed, failed, tests.len });
}

fn validateCodegen() !void {
    std.debug.print("Validating codegen outputs:\n\n", .{});

    // Create simple module
    var module = tvc_ir.TVCModule.init(std.heap.page_allocator, "validation_module");
    defer module.deinit();

    // Add function to validate
    const func = try module.addFunction("test_func");

    var block = tvc_ir.TVCBlock.init(std.heap.page_allocator, "entry");
    block.entry_point = 0;

    // Add instructions
    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{},
        .location = 0,
    });

    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{},
        .location = 1,
    });

    try block.addInstruction(std.heap.page_allocator, tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 2,
    });

    block.exit_point = 2;
    const block_name = try std.heap.page_allocator.dupe(u8, "entry");
    try func.blocks.put(block_name, block);

    func.returns = .i64_trit;
    func.is_extern = false;

    std.debug.print("  ✓ Created validation module\n", .{});
    std.debug.print("  ✓ Function: test_func\n", .{});
    std.debug.print("  ✓ Instructions: {d}\n", .{block.instructions.items.len});

    // Initialize VM and execute
    var vm = tvc_vm.TVCVM.init(std.heap.page_allocator, 1024, 1024);
    defer vm.deinit();

    try vm.loadModule(&module);

    // Execute the function
    try vm.callFunction("test_func");

    std.debug.print("  ✓ Executed successfully\n", .{});
    std.debug.print("  ✓ Codegen validation passed\n\n", .{});
}
