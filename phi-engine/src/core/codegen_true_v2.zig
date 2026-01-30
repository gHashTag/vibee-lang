const std = @import("std");

// TRUE COMPILER v2.0 - State Machine Approach
// Generates REAL Zig code from .vibee specifications
// NO simulation - ACTUAL IMPLEMENTATION

const Allocator = std.mem.Allocator;

// Parser States
const State = enum {
    start,
    root,
    behaviors,
    waiting_for_name,
    waiting_for_code,
    in_code_block,
    types,
    constants,
    done,
};

const ParsedBehavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    description: []const u8,
    code: []const u8,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <spec.vibee> [output.zig]\n", .{args[0]});
        std.debug.print("\n", .{});
        std.debug.print("TRUE COMPILER v2.0 (State Machine)\n", .{});
        return error.Usage;
    }

    const spec_path = args[1];
    var output_path = try std.fmt.allocPrint(allocator, "{s}.zig", .{std.fs.path.stem(spec_path)});

    if (args.len > 2) {
        allocator.free(output_path);
        output_path = try std.fmt.allocPrint(allocator, "{s}", .{args[2]});
    }

    // 1. Parse Spec (State Machine)
    const behaviors = try parse_behaviors(spec_path, allocator);
    defer {
        for (behaviors.items) |*b| {
            allocator.free(b.name);
            allocator.free(b.given);
            allocator.free(b.when);
            allocator.free(b.then);
            allocator.free(b.description);
            allocator.free(b.code);
        }
        behaviors.deinit(allocator);
    }

    // 2. Generate Zig Code
    const zig_code = try generate_zig(behaviors, allocator);
    defer allocator.free(zig_code);

    // 3. Write Zig File
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(zig_code);

    std.debug.print("✓ TRUE COMPILATION: {s}\n", .{output_path});
    std.debug.print("  Behaviors parsed: {d}\n", .{behaviors.items.len});
    std.debug.print("  Real functions: {d}\n", .{behaviors.items.len});
    std.debug.print("  Size: {d} bytes\n", .{zig_code.len});
}

fn parse_behaviors(path: []const u8, allocator: Allocator) !std.ArrayList(ParsedBehavior) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);

    var behaviors = std.ArrayList(ParsedBehavior).init(allocator);
    var state = State.start;

    var current_name: []const u8 = "";
    var current_given: []const u8 = "";
    var current_when: []const u8 = "";
    var current_then: []const u8 = "";
    var current_desc: []const u8 = "";
    var code_builder = std.ArrayList(u8).init(allocator);
    defer code_builder.deinit(allocator);

    var lines = std.mem.splitSequence(u8, content, "\n");

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // State Machine Transitions
        switch (state) {
            State.start => {
                if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
                    state = State.behaviors;
                }
            },
            State.behaviors => {
                if (std.mem.startsWith(u8, trimmed, "  - name:")) {
                    const name_val = std.mem.trim(u8, trimmed[10..], &std.ascii.whitespace);
                    current_name = try allocator.dupe(u8, name_val);
                    current_given = "";
                    current_when = "";
                    current_then = "";
                    current_desc = "";
                    code_builder.clearRetainingCapacity();
                    state = State.waiting_for_code;
                } else if (std.mem.startsWith(u8, trimmed, "types:") or std.mem.startsWith(u8, trimmed, "constants:") or std.mem.startsWith(u8, trimmed, "test_cases:")) {
                    state = State.done;
                }
            },
            State.waiting_for_code => {
                if (std.mem.startsWith(u8, trimmed, "    code: |")) {
                    state = State.in_code_block;
                } else if (std.mem.startsWith(u8, trimmed, "    given:")) {
                    const val = std.mem.trim(u8, trimmed[10..], &std.ascii.whitespace);
                    current_given = try allocator.dupe(u8, val);
                } else if (std.mem.startsWith(u8, trimmed, "    when:")) {
                    const val = std.mem.trim(u8, trimmed[9..], &std.ascii.whitespace);
                    current_when = try allocator.dupe(u8, val);
                } else if (std.mem.startsWith(u8, trimmed, "    then:")) {
                    const val = std.mem.trim(u8, trimmed[9..], &std.ascii.whitespace);
                    current_then = try allocator.dupe(u8, val);
                } else if (std.mem.startsWith(u8, trimmed, "    description:")) {
                    const val = std.mem.trim(u8, trimmed[14..], &std.ascii.whitespace);
                    current_desc = try allocator.dupe(u8, val);
                }
            },
            State.in_code_block => {
                if (std.mem.startsWith(u8, trimmed, "    ") or std.mem.startsWith(u8, trimmed, "  ") or std.mem.startsWith(u8, trimmed, " ") and trimmed.len > 2) {
                    const indented_code = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
                    try code_builder.appendSlice(allocator, indented_code);
                    try code_builder.appendSlice(allocator, "\n");
                } else {
                    // End of code block
                    state = State.behaviors;

                    // Save current behavior
                    const code_str = try allocator.dupe(u8, code_builder.items);

                    try behaviors.append(ParsedBehavior{
                        .name = current_name,
                        .given = current_given,
                        .when = current_when,
                        .then = current_then,
                        .description = current_desc,
                        .code = code_str,
                    });
                }
            },
            State.done => {},
            State.root => {},
            State.types => {},
            State.constants => {},
        }
    }

    // Save last behavior if in code block
    if (state == State.in_code_block) {
        const code_str = try allocator.dupe(u8, code_builder.items);
        try behaviors.append(ParsedBehavior{
            .name = current_name,
            .given = current_given,
            .when = current_when,
            .then = current_then,
            .description = current_desc,
            .code = code_str,
        });
    }

    return behaviors;
}

fn generate_zig(behaviors: std.ArrayList(ParsedBehavior), allocator: Allocator) ![]const u8 {
    var zig_code = std.ArrayList(u8).init(allocator);
    defer zig_code.deinit(allocator);

    // Header
    try zig_code.appendSlice(allocator, "// ═══════════════════════════════════════════════════════════════════════\n");
    try zig_code.appendSlice(allocator, "// TRUE COMPILATION - REAL FUNCTIONS\n");
    try zig_code.appendSlice(allocator, "// Generated by State Machine Parser\n");
    try zig_code.appendSlice(allocator, "// ═════════════════════════════════════════════════════════════════════════\n");
    try zig_code.appendSlice(allocator, "\n");

    try zig_code.appendSlice(allocator, "const std = @import(\"std\");\n\n");

    // Generate REAL Functions
    if (behaviors.items.len > 0) {
        try zig_code.appendSlice(allocator, "// ═════════════════════════════════════════════════════════════════════════\n");
        try zig_code.appendSlice(allocator, "// REAL FUNCTIONS FROM IMPLEMENTATIONS\n");
        try zig_code.appendSlice(allocator, "// ═════════════════════════════════════════════════════════════════════════\n");
        try zig_code.appendSlice(allocator, "\n");

        for (behaviors.items) |behavior| {
            if (behavior.code.len > 0) {
                // Generate REAL function with implementation
                try zig_code.appendSlice(allocator, "pub fn ");
                try zig_code.appendSlice(allocator, behavior.name);
                try zig_code.appendSlice(allocator, "() ");
                try zig_code.appendSlice(allocator, behavior.then);
                try zig_code.appendSlice(allocator, " !void {\n");

                try zig_code.appendSlice(allocator, "    // ");
                try zig_code.appendSlice(allocator, behavior.description);
                try zig_code.appendSlice(allocator, "\n");
                try zig_code.appendSlice(allocator, "    // Given: ");
                try zig_code.appendSlice(allocator, behavior.given);
                try zig_code.appendSlice(allocator, "\n");
                try zig_code.appendSlice(allocator, "    // When: ");
                try zig_code.appendSlice(allocator, behavior.when);
                try zig_code.appendSlice(allocator, "\n");
                try zig_code.appendSlice(allocator, "    // Then: ");
                try zig_code.appendSlice(allocator, behavior.then);
                try zig_code.appendSlice(allocator, "\n");
                try zig_code.appendSlice(allocator, "\n");
                try zig_code.appendSlice(allocator, "    // === REAL CODE ===\n");
                try zig_code.appendSlice(allocator, "    ");
                try zig_code.appendSlice(allocator, behavior.code);
                try zig_code.appendSlice(allocator, "\n");

                try zig_code.appendSlice(allocator, "}\n\n");
            }
        }
    }

    return allocator.dupe(u8, zig_code.items);
}
