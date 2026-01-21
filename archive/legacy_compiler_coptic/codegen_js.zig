// ═══════════════════════════════════════════════════════════════════════════
// VIBEEC JavaScript Module Generator
// ═══════════════════════════════════════════════════════════════════════════
// Generates JavaScript modules for core.js from .vibee specifications
// Scientific basis:
//   - BuildIt DSL System (arXiv:2601.02653) - Staged compilation
//   - BRIDGE (arXiv:2511.21104) - Specification-driven synthesis
//   - LaaC (arXiv:2511.04132) - LLM as Compiler paradigm
// PAS Patterns: PRE (templates), D&C (modular), ALG (transformations)
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");

/// Generate JavaScript module code from .vibee specification
pub fn generateJSModule(allocator: std.mem.Allocator, spec: parser.Spec, module_index: u32) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    const writer = result.writer();

    // Header
    try writer.print(
        \\// ═══════════════════════════════════════════════════════════════════════════
        \\// MODULE {d}: {s} - {s}
        \\// Source: {s}
        \\// PAS: {s}
        \\// Benefit: {s}
        \\// ═══════════════════════════════════════════════════════════════════════════
        \\
    , .{
        module_index,
        spec.name,
        if (spec.description.len > 0) spec.description else "No description",
        spec.source orelse "N/A",
        spec.pas_patterns orelse "N/A",
        spec.benefit orelse "N/A",
    });

    // Module object start
    try writer.print("var {s} = {{\n", .{spec.name});

    // State variables
    if (spec.state) |state| {
        for (state) |s| {
            try writer.print("  {s}: {s},\n", .{ s.name, if (s.default_value.len > 0) s.default_value else "null" });
        }
    }

    // Init method
    try writer.writeAll("\n  init: function(config) {\n");
    if (spec.init_body) |body| {
        try writer.print("    {s}\n", .{body});
    }
    try writer.print("    console.log('{s} {s} initialized');\n", .{
        spec.emoji orelse "📦",
        spec.name,
    });
    try writer.writeAll("    return this;\n  },\n");

    // Methods
    if (spec.methods) |methods| {
        for (methods) |m| {
            try writer.print("\n  {s}: function({s}) {{\n", .{
                m.name,
                m.params,
            });
            if (m.body.len > 0) {
                try writer.print("    {s}\n", .{m.body});
            }
            try writer.writeAll("  },\n");
        }
    }

    // Close module
    try writer.writeAll("};\n\n");

    // Initialize
    try writer.print("// Initialize {s}\n", .{spec.name});
    try writer.print("{s}.init();\n", .{spec.name});

    // Keyboard handler
    if (spec.keyboard_shortcut) |key| {
        try writer.print(
            \\
            \\// Keyboard handler for {s}
            \\document.addEventListener('keydown', function(e) {{
            \\  if (e.key === '{s}') {{
            \\    console.log('{s} {s}:', {s}.getStats ? {s}.getStats() : 'active');
            \\  }}
            \\}});
            \\
        , .{
            spec.name,
            key,
            spec.emoji orelse "📦",
            spec.name,
            spec.name,
            spec.name,
        });
    }

    return result.toOwnedSlice();
}

/// Integrate generated JS module into core.js
pub fn integrateIntoCore(allocator: std.mem.Allocator, module_code: []const u8, core_path: []const u8) !void {
    // Read existing core.js
    const file = try std.fs.cwd().openFile(core_path, .{ .mode = .read_write });
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    // Find insertion point (before final console.log block)
    const marker = "console.log('╔═══";
    var insertion_point: usize = 0;

    // Find last occurrence of marker
    var i: usize = content.len;
    while (i > marker.len) {
        i -= 1;
        if (std.mem.startsWith(u8, content[i..], marker)) {
            insertion_point = i;
            break;
        }
    }

    if (insertion_point == 0) {
        std.debug.print("Warning: Could not find insertion point in core.js\n", .{});
        return;
    }

    // Create new content
    var new_content = std.ArrayList(u8).init(allocator);
    defer new_content.deinit();

    try new_content.appendSlice(content[0..insertion_point]);
    try new_content.appendSlice("\n");
    try new_content.appendSlice(module_code);
    try new_content.appendSlice("\n\n");
    try new_content.appendSlice(content[insertion_point..]);

    // Write back
    try file.seekTo(0);
    try file.writeAll(new_content.items);
    try file.setEndPos(new_content.items.len);
}

/// Count existing modules in core.js to determine next index
pub fn countModules(allocator: std.mem.Allocator, core_path: []const u8) !u32 {
    const file = try std.fs.cwd().openFile(core_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var count: u32 = 0;
    var i: usize = 0;

    while (i < content.len) {
        if (std.mem.startsWith(u8, content[i..], "// MODULE ")) {
            count += 1;
        }
        i += 1;
    }

    return count;
}

test "generate simple module" {
    const allocator = std.testing.allocator;

    const spec = parser.Spec{
        .name = "TestModule",
        .description = "Test module",
        .source = "arXiv:0000.00000",
        .pas_patterns = "PRE",
        .benefit = "Testing",
        .emoji = "🧪",
        .keyboard_shortcut = "t",
        .state = null,
        .methods = null,
        .init_body = null,
    };

    const code = try generateJSModule(allocator, spec, 99);
    defer allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "var TestModule") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "MODULE 99") != null);
}
