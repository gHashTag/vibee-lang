const std = @import("std");
const UroborosDecoder = @import("uroboros_decoder").UroborosDecoder;

pub const ConsumptionContext = UroborosDecoder.ConsumptionContext;
pub const FossilAnalysis = UroborosDecoder.FossilAnalysis;
pub const FossilResult = UroborosDecoder.FossilResult;

pub fn consume_code_file(file_path: []const u8) !FossilResult {
    var decoder = UroborosDecoder.init(std.heap.page_allocator);
    defer decoder.deinit();

    var context = ConsumptionContext{
        .input_path = std.mem.allocCopy(std.heap.page_allocator, u8, file_path),
        .output_path = try std.fmt.allocPrint(std.heap.page_allocator, "raw_fossil_{s}.tri", .{std.fs.path.basename(file_path)}),
        .metadata = std.StringHashMap([]const u8).init(std.heap.page_allocator),
        .errors = std.ArrayList([]const u8).init(std.heap.page_allocator),
        .warnings = std.ArrayList([]const u8).init(std.heap.page_allocator),
    };
    defer {
        context.metadata.deinit();
        context.errors.deinit();
        context.warnings.deinit();
        std.heap.page_allocator.free(context.input_path);
        std.heap.page_allocator.free(context.output_path);
    }

    // Read file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_content = try file.readToAllocEnd(std.heap.page_allocator, 1024 * 1024);

    // Create analysis
    var analysis = try FossilAnalysis.init(std.heap.page_allocator);
    defer analysis.deinit();

    try analysis.analyze(file_content);

    // Generate raw fossil
    const raw_fossil = try decoder.generate_raw_fossil(file_content, analysis);

    // Canonize
    const canonized_spec = try decoder.canonize_spec(raw_fossil, analysis);

    return FossilResult{
        .raw_fossil = raw_fossil,
        .canonized_spec = canonized_spec,
        .analysis = analysis,
        .quality_metrics = try decoder.calculate_metrics(analysis),
        .warnings = try context.warnings.toOwnedSlice(std.heap.page_allocator),
        .errors = try context.errors.toOwnedSlice(std.heap.page_allocator),
    };
}

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.debug.print("Usage: {s} <file.zig>\n", .{std.os.argv[0]});
        return error.InvalidArguments;
    }

    const file_path = std.os.argv[1];

    std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║            UROBOROS DECODER v2.0 - CODE CONSUMPTION              ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("Consuming: {s}\n\n", .{file_path});

    const result = try consume_code_file(file_path);

    // Write raw fossil
    try std.fs.cwd().writeFile("raw_fossil.tri", result.raw_fossil);
    std.debug.print("✓ Raw fossil written to: raw_fossil.tri\n", .{});

    // Write canonized spec
    try std.fs.cwd().writeFile("canonized_spec.tri", result.canonized_spec);
    std.debug.print("✓ Canonized spec written to: canonized_spec.tri\n", .{});

    // Print analysis
    std.debug.print("\n═══ FOSSIL ANALYSIS ═══\n", .{});
    std.debug.print("File: {s}\n", .{result.analysis.file_path});
    std.debug.print("Functions: {d}\n", .{result.analysis.functions.items.len});
    std.debug.print("Structs: {d}\n", .{result.analysis.struct_definitions.items.len});
    std.debug.print("Imports: {d}\n", .{result.analysis.imports.items.len});
    std.debug.print("Complexity Score: {d:.4}\n", .{result.quality_metrics.get("complexity_score").?});
    std.debug.print("Magic Numbers: {d}\n", .{result.analysis.magic_numbers.items.len});

    // Print warnings
    if (result.warnings.len > 0) {
        std.debug.print("\n═══ WARNINGS ({d}) ═══\n", .{result.warnings.len});
        for (result.warnings) |warning| {
            std.debug.print("  • {s}\n", .{warning});
        }
    }

    // Print magic numbers
    if (result.analysis.magic_numbers.items.len > 0) {
        std.debug.print("\n═══ MAGIC NUMBERS DETECTED ═══\n", .{});
        for (result.analysis.magic_numbers) |magic| {
            std.debug.print("  {s}\n", .{magic});
        }
    }
}
