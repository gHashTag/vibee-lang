// ═══════════════════════════════════════════════════════════════════════════════
// VARLOG BATCH GENERATOR - Массовая генерация Verilog из .vibee specs
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Verilog для всех .vibee спецификаций с language: varlog
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const varlog_codegen = @import("varlog_codegen.zig");

const VarlogCodeGen = varlog_codegen.VarlogCodeGen;
const ModuleType = varlog_codegen.ModuleType;
const detectModuleType = varlog_codegen.detectModuleType;

pub const BatchStats = struct {
    total_specs: u32,
    varlog_specs: u32,
    generated: u32,
    failed: u32,
    skipped: u32,
};

/// Parse .vibee file and extract name and language
fn parseVibeeSpec(content: []const u8) ?struct { name: []const u8, language: []const u8 } {
    var name: ?[]const u8 = null;
    var language: ?[]const u8 = null;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed, "name:")) {
            const value = std.mem.trim(u8, trimmed[5..], " \t\"");
            name = value;
        } else if (std.mem.startsWith(u8, trimmed, "language:")) {
            const value = std.mem.trim(u8, trimmed[9..], " \t\"");
            language = value;
        }

        if (name != null and language != null) break;
    }

    if (name != null and language != null) {
        return .{ .name = name.?, .language = language.? };
    }
    return null;
}

/// Generate single .varlog file from .vibee spec
pub fn generateSingleVarlog(allocator: Allocator, spec_path: []const u8, output_dir: []const u8) !bool {
    // Read spec file
    const file = fs.cwd().openFile(spec_path, .{}) catch return false;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch return false;
    defer allocator.free(content);

    // Parse spec
    const spec = parseVibeeSpec(content) orelse return false;

    // Check if language is varlog
    if (!std.mem.eql(u8, spec.language, "varlog")) {
        return false; // Skip non-varlog specs
    }

    // Generate Verilog
    var gen = VarlogCodeGen.init(allocator);
    defer gen.deinit();

    const module_type = detectModuleType(spec.name);
    const verilog = gen.generateModule(spec.name, module_type) catch return false;

    // Create output path
    const output_filename = std.fmt.allocPrint(allocator, "{s}/{s}.v", .{ output_dir, spec.name }) catch return false;
    defer allocator.free(output_filename);

    // Write output file
    const out_file = fs.cwd().createFile(output_filename, .{}) catch return false;
    defer out_file.close();

    out_file.writeAll(verilog) catch return false;

    return true;
}

/// Batch generate all .varlog files from specs directory
pub fn batchGenerate(allocator: Allocator, specs_dir: []const u8, output_dir: []const u8) !BatchStats {
    var stats = BatchStats{
        .total_specs = 0,
        .varlog_specs = 0,
        .generated = 0,
        .failed = 0,
        .skipped = 0,
    };

    // Ensure output directory exists
    fs.cwd().makePath(output_dir) catch {};

    // Walk specs directory
    var dir = fs.cwd().openDir(specs_dir, .{ .iterate = true }) catch {
        return stats;
    };
    defer dir.close();

    var walker = dir.walk(allocator) catch return stats;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;

        // Check if .vibee file
        if (!std.mem.endsWith(u8, entry.basename, ".vibee")) continue;

        stats.total_specs += 1;

        // Build full path
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ specs_dir, entry.path }) catch continue;
        defer allocator.free(full_path);

        // Try to generate
        if (generateSingleVarlog(allocator, full_path, output_dir) catch false) {
            stats.varlog_specs += 1;
            stats.generated += 1;
        } else {
            // Check if it was a varlog spec that failed
            const file = fs.cwd().openFile(full_path, .{}) catch continue;
            defer file.close();

            const content = file.readToEndAlloc(allocator, 1024 * 1024) catch continue;
            defer allocator.free(content);

            if (std.mem.indexOf(u8, content, "language: varlog") != null) {
                stats.varlog_specs += 1;
                stats.failed += 1;
            } else {
                stats.skipped += 1;
            }
        }
    }

    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

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
        \\║           VARLOG BATCH GENERATOR - TRINITY FPGA                  ║
        \\║                    φ² + 1/φ² = 3                                  ║
        \\╚══════════════════════════════════════════════════════════════════╝
        \\
        \\Specs directory: {s}
        \\Output directory: {s}
        \\
        \\Generating...
        \\
    , .{ specs_dir, output_dir });

    const stats = try batchGenerate(allocator, specs_dir, output_dir);

    try stdout.print(
        \\
        \\╔══════════════════════════════════════════════════════════════════╗
        \\║                      GENERATION COMPLETE                         ║
        \\╠══════════════════════════════════════════════════════════════════╣
        \\║  Total .vibee specs:    {d:>8}                                   ║
        \\║  Varlog specs found:    {d:>8}                                   ║
        \\║  Successfully generated:{d:>8}                                   ║
        \\║  Failed:                {d:>8}                                   ║
        \\║  Skipped (non-varlog):  {d:>8}                                   ║
        \\╚══════════════════════════════════════════════════════════════════╝
        \\
    , .{ stats.total_specs, stats.varlog_specs, stats.generated, stats.failed, stats.skipped });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse vibee spec" {
    const content =
        \\name: phi_sha256
        \\version: "2.0.0"
        \\language: varlog
        \\module: test
    ;

    const result = parseVibeeSpec(content);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("phi_sha256", result.?.name);
    try std.testing.expectEqualStrings("varlog", result.?.language);
}

test "parse non-varlog spec" {
    const content =
        \\name: some_module
        \\version: "1.0.0"
        \\language: zig
        \\module: test
    ;

    const result = parseVibeeSpec(content);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("zig", result.?.language);
}
