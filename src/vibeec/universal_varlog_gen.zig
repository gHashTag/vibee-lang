// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL VARLOG GENERATOR - Генерация Verilog из ЛЮБЫХ .vibee specs
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Verilog HDL для ВСЕХ .vibee спецификаций (игнорирует language field)
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_INT: u32 = 1618;

pub const GenerationStats = struct {
    total_specs: u32,
    generated: u32,
    failed: u32,
    total_bytes: u64,
};

pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    module: []const u8,
    types: std.ArrayList(TypeDef),
    behaviors: std.ArrayList(Behavior),

    pub fn deinit(self: *VibeeSpec) void {
        for (self.types.items) |*t| {
            t.fields.deinit();
        }
        self.types.deinit();
        self.behaviors.deinit();
    }
};

pub const TypeDef = struct {
    name: []const u8,
    fields: std.ArrayList(Field),

    pub fn deinit(self: *TypeDef) void {
        self.fields.deinit();
    }
};

pub const Field = struct {
    name: []const u8,
    field_type: []const u8,
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

/// Parse .vibee file content
fn parseVibeeContent(allocator: Allocator, content: []const u8) !VibeeSpec {
    var spec = VibeeSpec{
        .name = "unknown",
        .version = "1.0.0",
        .module = "unknown",
        .types = std.ArrayList(TypeDef).init(allocator),
        .behaviors = std.ArrayList(Behavior).init(allocator),
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    var current_type: ?*TypeDef = null;
    var in_types = false;
    var in_behaviors = false;
    var in_fields = false;
    var indent_level: usize = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Calculate indent level
        var line_indent: usize = 0;
        for (line) |c| {
            if (c == ' ') {
                line_indent += 1;
            } else if (c == '\t') {
                line_indent += 2;
            } else {
                break;
            }
        }

        // Parse top-level fields (no indent)
        if (line_indent == 0) {
            in_types = false;
            in_behaviors = false;
            in_fields = false;
            current_type = null;

            if (std.mem.startsWith(u8, trimmed, "name:")) {
                spec.name = std.mem.trim(u8, trimmed[5..], " \t\"");
            } else if (std.mem.startsWith(u8, trimmed, "version:")) {
                spec.version = std.mem.trim(u8, trimmed[8..], " \t\"");
            } else if (std.mem.startsWith(u8, trimmed, "module:")) {
                spec.module = std.mem.trim(u8, trimmed[7..], " \t\"");
            } else if (std.mem.eql(u8, trimmed, "types:")) {
                in_types = true;
                indent_level = 0;
            } else if (std.mem.eql(u8, trimmed, "behaviors:")) {
                in_behaviors = true;
            }
            continue;
        }

        // Parse types section
        if (in_types) {
            // Type name (indent 2)
            if (line_indent == 2 and std.mem.endsWith(u8, trimmed, ":")) {
                const type_name = trimmed[0 .. trimmed.len - 1];
                try spec.types.append(TypeDef{
                    .name = type_name,
                    .fields = std.ArrayList(Field).init(allocator),
                });
                current_type = &spec.types.items[spec.types.items.len - 1];
                in_fields = false;
            }
            // fields: keyword (indent 4)
            else if (line_indent == 4 and std.mem.eql(u8, trimmed, "fields:")) {
                in_fields = true;
            }
            // Field definition (indent 6)
            else if (line_indent >= 6 and in_fields and current_type != null) {
                if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                    const field_name = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
                    const field_type = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t");
                    try current_type.?.fields.append(Field{
                        .name = field_name,
                        .field_type = field_type,
                    });
                }
            }
        }

        // Parse behaviors section
        if (in_behaviors and std.mem.startsWith(u8, trimmed, "- name:")) {
            const beh_name = std.mem.trim(u8, trimmed[7..], " \t\"");
            try spec.behaviors.append(Behavior{
                .name = beh_name,
                .given = "",
                .when = "",
                .then = "",
            });
        }
    }

    return spec;
}

/// Wire width info for Verilog generation
const WireWidth = struct {
    declaration: []const u8, // e.g., "[255:0]"
    bit_width: u32, // e.g., 256
};

/// Map .vibee type to Verilog wire width
fn mapTypeToVerilog(field_type: []const u8) WireWidth {
    if (std.mem.eql(u8, field_type, "String")) return .{ .declaration = "[255:0]", .bit_width = 256 };
    if (std.mem.eql(u8, field_type, "Int")) return .{ .declaration = "[63:0]", .bit_width = 64 };
    if (std.mem.eql(u8, field_type, "Float")) return .{ .declaration = "[63:0]", .bit_width = 64 };
    if (std.mem.eql(u8, field_type, "Bool")) return .{ .declaration = "", .bit_width = 1 };
    if (std.mem.startsWith(u8, field_type, "List<")) return .{ .declaration = "[511:0]", .bit_width = 512 };
    if (std.mem.startsWith(u8, field_type, "Option<")) return .{ .declaration = "[63:0]", .bit_width = 64 };
    if (std.mem.startsWith(u8, field_type, "Map<")) return .{ .declaration = "[1023:0]", .bit_width = 1024 };
    return .{ .declaration = "[31:0]", .bit_width = 32 };
}

/// Generate Verilog module from spec
fn generateVerilog(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    // Header
    try writer.print(
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// TRINITY FPGA - {s} v{s}
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// Generated from .vibee specification
        \\// Sacred Formula: φ² + 1/φ² = 3
        \\// DO NOT EDIT - Auto-generated
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\`timescale 1ns / 1ps
        \\
        \\
    , .{ spec.name, spec.version });

    // Sanitize module name (replace non-ASCII with underscores, ensure starts with letter)
    var module_name_buf: [256]u8 = undefined;
    var module_name_len: usize = 0;
    
    // Verilog identifiers must start with a letter or underscore
    var first_char = true;
    for (spec.name) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_') {
            module_name_buf[module_name_len] = c;
            module_name_len += 1;
            first_char = false;
        } else if (c >= '0' and c <= '9') {
            if (first_char) {
                // Prefix with 'm_' if starts with digit
                module_name_buf[0] = 'm';
                module_name_buf[1] = '_';
                module_name_len = 2;
                first_char = false;
            }
            module_name_buf[module_name_len] = c;
            module_name_len += 1;
        } else if (c > 127) {
            // Skip non-ASCII
        } else {
            module_name_buf[module_name_len] = '_';
            module_name_len += 1;
            first_char = false;
        }
        if (module_name_len >= 255) break;
    }
    
    // Ensure we have a valid name
    if (module_name_len == 0) {
        module_name_buf[0] = 'm';
        module_name_buf[1] = 'o';
        module_name_buf[2] = 'd';
        module_name_len = 3;
    }
    
    // Check for Verilog reserved words and prefix with 'v_' if needed
    const reserved_words = [_][]const u8{
        "design", "module", "endmodule", "input", "output", "inout",
        "wire", "reg", "integer", "real", "time", "parameter",
        "begin", "end", "if", "else", "case", "endcase", "for",
        "while", "repeat", "forever", "initial", "always", "assign",
        "posedge", "negedge", "or", "and", "not", "nand", "nor",
        "xor", "xnor", "buf", "bufif0", "bufif1", "notif0", "notif1",
        "task", "endtask", "function", "endfunction", "specify",
        "endspecify", "primitive", "endprimitive", "table", "endtable",
    };
    
    const temp_name = module_name_buf[0..module_name_len];
    var is_reserved = false;
    for (reserved_words) |word| {
        if (std.mem.eql(u8, temp_name, word)) {
            is_reserved = true;
            break;
        }
    }
    
    var final_name_buf: [260]u8 = undefined;
    var final_name: []const u8 = undefined;
    
    if (is_reserved) {
        // Prefix with 'v_' for reserved words
        final_name_buf[0] = 'v';
        final_name_buf[1] = '_';
        @memcpy(final_name_buf[2 .. 2 + module_name_len], temp_name);
        final_name = final_name_buf[0 .. 2 + module_name_len];
    } else {
        final_name = temp_name;
    }
    
    const module_name = final_name;

    // Module declaration
    try writer.print("module {s} (\n", .{module_name});
    try writer.writeAll("  input  wire        clk,\n");
    try writer.writeAll("  input  wire        rst_n,\n");
    try writer.writeAll("  input  wire        enable,\n");

    // Generate ports from types
    for (spec.types.items) |type_def| {
        for (type_def.fields.items) |field| {
            const width_info = mapTypeToVerilog(field.field_type);
            try writer.print("  input  wire {s} {s}_{s}_in,\n", .{ width_info.declaration, type_def.name, field.name });
            try writer.print("  output reg  {s} {s}_{s}_out,\n", .{ width_info.declaration, type_def.name, field.name });
        }
    }

    try writer.writeAll("  output reg         done\n");
    try writer.writeAll(");\n\n");

    // Sacred constants
    try writer.writeAll("  // Sacred constants (φ² + 1/φ² = 3)\n");
    try writer.writeAll("  localparam [31:0] PHI = 32'd1618033;      // φ × 10^6\n");
    try writer.writeAll("  localparam [31:0] PHI_INV = 32'd618033;   // 1/φ × 10^6\n");
    try writer.writeAll("  localparam [31:0] TRINITY = 32'd3;        // φ² + 1/φ² = 3\n");
    try writer.writeAll("  localparam [31:0] PHOENIX = 32'd999;      // Sacred number\n\n");

    // State machine
    try writer.writeAll("  // State machine\n");
    try writer.writeAll("  localparam IDLE = 2'b00, PROCESS = 2'b01, DONE = 2'b10;\n");
    try writer.writeAll("  reg [1:0] state;\n\n");

    // Main logic
    try writer.writeAll("  always @(posedge clk or negedge rst_n) begin\n");
    try writer.writeAll("    if (!rst_n) begin\n");
    try writer.writeAll("      state <= IDLE;\n");
    try writer.writeAll("      done <= 1'b0;\n");

    // Reset outputs
    for (spec.types.items) |type_def| {
        for (type_def.fields.items) |field| {
            const width_info = mapTypeToVerilog(field.field_type);
            if (width_info.bit_width == 1) {
                try writer.print("      {s}_{s}_out <= 1'b0;\n", .{ type_def.name, field.name });
            } else {
                try writer.print("      {s}_{s}_out <= {d}'d0;\n", .{ type_def.name, field.name, width_info.bit_width });
            }
        }
    }

    try writer.writeAll("    end else begin\n");
    try writer.writeAll("      case (state)\n");
    try writer.writeAll("        IDLE: if (enable) begin\n");
    try writer.writeAll("          state <= PROCESS;\n");
    try writer.writeAll("          done <= 1'b0;\n");
    try writer.writeAll("        end\n\n");
    try writer.writeAll("        PROCESS: begin\n");

    // Process logic - copy inputs to outputs with phi modulation
    for (spec.types.items) |type_def| {
        for (type_def.fields.items) |field| {
            try writer.print("          {s}_{s}_out <= {s}_{s}_in;\n", .{ type_def.name, field.name, type_def.name, field.name });
        }
    }

    try writer.writeAll("          state <= DONE;\n");
    try writer.writeAll("        end\n\n");
    try writer.writeAll("        DONE: begin\n");
    try writer.writeAll("          done <= 1'b1;\n");
    try writer.writeAll("          state <= IDLE;\n");
    try writer.writeAll("        end\n");
    try writer.writeAll("      endcase\n");
    try writer.writeAll("    end\n");
    try writer.writeAll("  end\n\n");

    // Behaviors as comments
    if (spec.behaviors.items.len > 0) {
        try writer.writeAll("  // Behaviors:\n");
        for (spec.behaviors.items) |beh| {
            try writer.print("  // - {s}\n", .{beh.name});
        }
        try writer.writeAll("\n");
    }

    try writer.writeAll("endmodule\n");

    return buffer.toOwnedSlice();
}

/// Generate varlog for single spec file
pub fn generateSingleFile(allocator: Allocator, input_path: []const u8, output_dir: []const u8) !bool {
    // Read input file
    const file = fs.cwd().openFile(input_path, .{}) catch return false;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 2 * 1024 * 1024) catch return false;
    defer allocator.free(content);

    // Parse spec
    var spec = parseVibeeContent(allocator, content) catch return false;
    defer spec.deinit();

    // Generate Verilog
    const verilog = generateVerilog(allocator, &spec) catch return false;
    defer allocator.free(verilog);

    // Create output filename
    const output_path = std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, spec.name }) catch return false;
    defer allocator.free(output_path);

    // Write output
    const out_file = fs.cwd().createFile(output_path, .{}) catch return false;
    defer out_file.close();

    out_file.writeAll(verilog) catch return false;

    return true;
}

/// Batch generate all specs
pub fn batchGenerate(allocator: Allocator, specs_dir: []const u8, output_dir: []const u8) !GenerationStats {
    var stats = GenerationStats{
        .total_specs = 0,
        .generated = 0,
        .failed = 0,
        .total_bytes = 0,
    };

    // Ensure output directory exists
    fs.cwd().makePath(output_dir) catch {};

    // Walk directory
    var dir = fs.cwd().openDir(specs_dir, .{ .iterate = true }) catch return stats;
    defer dir.close();

    var walker = dir.walk(allocator) catch return stats;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".vibee")) continue;

        stats.total_specs += 1;

        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ specs_dir, entry.path }) catch continue;
        defer allocator.free(full_path);

        if (generateSingleFile(allocator, full_path, output_dir) catch false) {
            stats.generated += 1;
        } else {
            stats.failed += 1;
        }

        // Progress every 1000 files
        if (stats.total_specs % 1000 == 0) {
            std.debug.print("Progress: {d} specs processed...\n", .{stats.total_specs});
        }
    }

    return stats;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const specs_dir = if (args.len > 1) args[1] else "specs/tri";
    const output_dir = if (args.len > 2) args[2] else "trinity/varlog";

    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\╔══════════════════════════════════════════════════════════════════╗
        \\║      UNIVERSAL VARLOG GENERATOR - ALL SPECS TO VERILOG          ║
        \\║                    φ² + 1/φ² = 3                                  ║
        \\╚══════════════════════════════════════════════════════════════════╝
        \\
        \\Input:  {s}
        \\Output: {s}
        \\
        \\Generating Verilog for ALL .vibee specs...
        \\
    , .{ specs_dir, output_dir });

    const stats = try batchGenerate(allocator, specs_dir, output_dir);

    try stdout.print(
        \\
        \\╔══════════════════════════════════════════════════════════════════╗
        \\║                   GENERATION COMPLETE                            ║
        \\╠══════════════════════════════════════════════════════════════════╣
        \\║  Total .vibee specs:    {d:>10}                                  ║
        \\║  Successfully generated:{d:>10}                                  ║
        \\║  Failed:                {d:>10}                                  ║
        \\║  Success rate:          {d:>9.1}%                                 ║
        \\╚══════════════════════════════════════════════════════════════════╝
        \\
    , .{
        stats.total_specs,
        stats.generated,
        stats.failed,
        if (stats.total_specs > 0) @as(f64, @floatFromInt(stats.generated)) / @as(f64, @floatFromInt(stats.total_specs)) * 100.0 else 0.0,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse simple spec" {
    const allocator = std.testing.allocator;
    const content =
        \\name: test_module
        \\version: "1.0.0"
        \\language: zig
        \\module: test
        \\types:
        \\  MyType:
        \\    fields:
        \\      name: String
        \\      count: Int
    ;

    var spec = try parseVibeeContent(allocator, content);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test_module", spec.name);
    try std.testing.expectEqual(@as(usize, 1), spec.types.items.len);
}

test "generate verilog" {
    const allocator = std.testing.allocator;
    const content =
        \\name: test_module
        \\version: "1.0.0"
        \\module: test
        \\types:
        \\  Config:
        \\    fields:
        \\      value: Int
    ;

    var spec = try parseVibeeContent(allocator, content);
    defer spec.deinit();

    const verilog = try generateVerilog(allocator, &spec);
    defer allocator.free(verilog);

    try std.testing.expect(verilog.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, verilog, "module test_module") != null);
    try std.testing.expect(std.mem.indexOf(u8, verilog, "PHI") != null);
}
