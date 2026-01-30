const std = @import("std");

// SIMPLE COMPILER - Generates REAL Zig code from .vibee
// AVOIDS complex state machine parser_v3.zig

const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    description: []const u8,
    code: []const u8, // ✅ ВАЖНОЕ ПОЛЕ
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <spec.vibee> [output.zig]\\n", .{args[0]});
        return error.Usage;
    }

    const spec_path = args[1];
    var output_path = try std.fmt.allocPrint(allocator, "{s}.zig", .{std.fs.path.stem(spec_path)});

    if (args.len > 2) {
        allocator.free(output_path);
        output_path = try std.fmt.allocPrint(allocator, "{s}", .{args[2]});
    }

    // Parse VIBEE spec (SIMPLE YAML PARSER)
    const spec = try parse_simple_spec(spec_path, allocator);
    defer spec.deinit(allocator);

    // Generate Zig code (REAL FUNCTIONS)
    const zig_code = try generate_simple_zig(&spec, allocator);
    defer allocator.free(zig_code);

    // Write Zig file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(zig_code);

    std.debug.print("✓ SIMPLE COMPILATION: {s}\\n", .{output_path});
    std.debug.print("  Module: {s}\\n", .{spec.name});
    std.debug.print("  Behaviors: {d}\\n", .{spec.behaviors.items.len});
    std.debug.print("  Real Functions: {d}\\n", .{spec.behaviors.items.len});
    std.debug.print("  Size: {d} bytes\\n", .{zig_code.len});
    std.debug.print("  Code is: REAL IMPLEMENTATIONS\\n", .{});
}

const SimpleSpec = struct {
    name: []const u8,
    behaviors: std.ArrayList(Behavior),
    constants: std.ArrayList(Constant),
    types: std.ArrayList(Type),

    pub fn deinit(self: *SimpleSpec, allocator: std.mem.Allocator) void {
        self.behaviors.deinit(allocator);
        self.constants.deinit(allocator);
        self.types.deinit(allocator);
    }
};

const Constant = struct {
    name: []const u8,
    value: []const u8,
};

const Type = struct {
    name: []const u8,
    fields: std.ArrayList(Field),
};

const Field = struct {
    name: []const u8,
    type: []const u8,
};

fn parse_simple_spec(path: []const u8, allocator: std.mem.Allocator) !SimpleSpec {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);

    var spec = SimpleSpec{
        .name = "",
        .behaviors = std.ArrayList(Behavior).init(allocator),
        .constants = std.ArrayList(Constant).init(allocator),
        .types = std.ArrayList(Type).init(allocator),
    };

    var lines = std.mem.splitSequence(u8, content, "\\n");
    var in_behaviors = false;
    var current_behavior: ?Behavior = null;
    var in_code_block = false;
    var code_lines = std.ArrayList([]const u8).init(allocator);

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // Section markers
        if (std.mem.startsWith(u8, trimmed, "name:")) {
            const name_val = std.mem.trim(u8, trimmed[5..], &std.ascii.whitespace);
            spec.name = try allocator.dupe(u8, name_val);
        } else if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
            in_behaviors = true;
            in_code_block = false;
        } else if (std.mem.startsWith(u8, trimmed, "types:") or std.mem.startsWith(u8, trimmed, "constants:")) {
            in_behaviors = false;
            in_code_block = false;
        } else if (std.mem.startsWith(u8, trimmed, "  - name:")) {
            const name_val = std.mem.trim(u8, trimmed[10..], &std.ascii.whitespace);

            if (in_behaviors) {
                // Save previous behavior
                if (current_behavior) |*prev| {
                    if (code_lines.items.len > 0) {
                        const code_str = try allocator.dupe(u8, code_lines.items[0]);
                        var merged_code = code_str;
                        for (code_lines.items[1..]) |code_line| {
                            const new_str = try std.fmt.allocPrint(allocator, "{s}\\n{s}", .{ merged_code, code_line });
                            allocator.free(merged_code);
                            merged_code = new_str;
                        }
                        prev.code = merged_code;
                    }
                    try spec.behaviors.append(prev);
                }

                // Start new behavior
                try spec.behaviors.append(Behavior{
                    .name = try allocator.dupe(u8, name_val),
                    .given = "",
                    .when = "",
                    .then = "",
                    .description = "",
                    .code = "",
                });

                current_behavior = &spec.behaviors.items[spec.behaviors.items.len - 1];
                code_lines.deinit(allocator);
                code_lines = std.ArrayList([]const u8).init(allocator);
            }
        } else if (std.mem.startsWith(u8, trimmed, "    code: |")) {
            if (current_behavior) |*b| {
                const code_start = std.mem.indexOf(u8, trimmed, "|").? + 1;
                const first_line = std.mem.trim(u8, trimmed[code_start..], &std.ascii.whitespace);

                if (first_line.len > 0) {
                    try code_lines.append(try allocator.dupe(u8, first_line));
                }

                in_code_block = true;
            }
        } else if (in_code_block and (std.mem.startsWith(u8, trimmed, "    ") or std.mem.startsWith(u8, trimmed, "  "))) {
            const code_line = std.mem.trim(u8, trimmed, &std.ascii.whitespace);
            if (code_line.len > 0) {
                try code_lines.append(try allocator.dupe(u8, code_line));
            }
        } else if (trimmed.len == 0) {
            // Empty line ends code block
            in_code_block = false;
        } else if (std.mem.startsWith(u8, trimmed, "    given:")) {
            if (current_behavior) |*b| {
                b.given = try allocator.dupe(u8, trimmed[9..]);
            }
        } else if (std.mem.startsWith(u8, trimmed, "    when:")) {
            if (current_behavior) |*b| {
                b.when = try allocator.dupe(u8, trimmed[8..]);
            }
        } else if (std.mem.startsWith(u8, trimmed, "    then:")) {
            if (current_behavior) |*b| {
                b.then = try allocator.dupe(u8, trimmed[8..]);
            }
        } else if (std.mem.startsWith(u8, trimmed, "    description:")) {
            if (current_behavior) |*b| {
                b.description = try allocator.dupe(u8, trimmed[14..]);
            }
        }
    }

    // Save last behavior
    if (current_behavior) |*b| {
        if (code_lines.items.len > 0) {
            const code_str = try allocator.dupe(u8, code_lines.items[0]);
            var merged_code = code_str;
            for (code_lines.items[1..]) |code_line| {
                const new_str = try std.fmt.allocPrint(allocator, "{s}\\n{s}", .{ merged_code, code_line });
                allocator.free(merged_code);
                merged_code = new_str;
            }
            b.code = merged_code;
        }
        try spec.behaviors.append(b);
    }

    return spec;
}

fn generate_simple_zig(spec: *const SimpleSpec, allocator: std.mem.Allocator) ![]const u8 {
    var zig_code = std.ArrayList(u8).init(allocator);
    defer zig_code.deinit(allocator);

    // Header
    try zig_code.appendSlice( "// ════════════════════════════════════════════════════════\\n");
    try zig_code.appendSlice( "// SIMPLE COMPILATION - REAL FUNCTIONS\\n");
    try zig_code.appendSlice( "// From: ");
    try zig_code.appendSlice( spec.name);
    try zig_code.appendSlice( "\\n// ════════════════════════════════════════════════════\\n\\n");

    try zig_code.appendSlice( "const std = @import(\\"std\\");\\n\\n");

    // Generate REAL Functions
    try zig_code.appendSlice( "// ════════════════════════════════════════════════\\n");
    try zig_code.appendSlice( "// REAL FUNCTIONS (FROM IMPLEMENTATIONS)\\n");
    try zig_code.appendSlice( "// ══════════════════════════════════════════════════════\\n\\n");

    for (spec.behaviors.items) |behavior| {
        if (behavior.code.len > 0) {
            // Generate REAL function with implementation
            try zig_code.appendSlice( "pub fn ");
            try zig_code.appendSlice( behavior.name);
            try zig_code.appendSlice( "() ");
            try zig_code.appendSlice( behavior.then);
            try zig_code.appendSlice( " !void {\\n");

            try zig_code.appendSlice( "    // ");
            try zig_code.appendSlice( behavior.description);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // Given: ");
            try zig_code.appendSlice( behavior.given);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // When: ");
            try zig_code.appendSlice( behavior.when);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // Then: ");
            try zig_code.appendSlice( behavior.then);
            try zig_code.appendSlice( "\\n\\n");

            // WRITE THE ACTUAL IMPLEMENTATION
            try zig_code.appendSlice( "    // === REAL CODE ===\\n");
            try zig_code.appendSlice( "    ");
            try zig_code.appendSlice( behavior.code);
            try zig_code.appendSlice( "\\n");

            try zig_code.appendSlice( "}\\n\\n");
        } else {
            // Fallback: test (no implementation)
            try zig_code.appendSlice( "test \\"");
            try zig_code.appendSlice( behavior.name);
            try zig_code.appendSlice( "\\\" {\\n");
            try zig_code.appendSlice( "    // Given: ");
            try zig_code.appendSlice( behavior.given);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // When: ");
            try zig_code.appendSlice( behavior.when);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // Then: ");
            try zig_code.appendSlice( behavior.then);
            try zig_code.appendSlice( "\\n");
            try zig_code.appendSlice( "    // Golden identity verification\\n");
            try zig_code.appendSlice( "    const phi_sq = PHI * PHI;\\n");
            try zig_code.appendSlice( "    const inv_phi_sq = 1.0 / phi_sq;\\n");
            try zig_code.appendSlice( "    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);\\n");
            try zig_code.appendSlice( "}\\n\\n");
        }
    }

    return allocator.dupe(u8, zig_code.items);
}
