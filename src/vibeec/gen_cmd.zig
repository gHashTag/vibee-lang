// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC GEN COMMAND - CLI для генерации Zig из .vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// Использование: vibeec gen <input.vibee> [output.zig]
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        printUsage();
        return;
    }
    
    const command = args[1];
    
    if (std.mem.eql(u8, command, "gen")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing input file\n", .{});
            printUsage();
            return;
        }
        
        const input_path = args[2];
        const output_path = if (args.len > 3) args[3] else deriveOutputPath(allocator, input_path) catch {
            std.debug.print("Error: Could not derive output path\n", .{});
            return;
        };
        
        try generateCode(allocator, input_path, output_path);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\                    VIBEEC - VIBEE Compiler v24.φ
        \\                    φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  vibeec gen <input.vibee> [output.zig]    Generate Zig code from .vibee spec
        \\  vibeec help                              Show this help
        \\
        \\EXAMPLES:
        \\  vibeec gen specs/phi_core.vibee                    # Output: generated/phi_core.zig
        \\  vibeec gen specs/phi_core.vibee src/phi_core.zig   # Custom output path
        \\
        \\SUPPORTED TARGETS:
        \\  - zig (default)
        \\  - rust (planned)
        \\  - gleam (planned)
        \\
        \\
    , .{});
}

fn deriveOutputPath(allocator: std.mem.Allocator, input_path: []const u8) ![]const u8 {
    // specs/phi_core.vibee -> generated/phi_core.zig
    const basename = std.fs.path.basename(input_path);
    const stem = std.fs.path.stem(basename);
    
    return try std.fmt.allocPrint(allocator, "generated/{s}.zig", .{stem});
}

fn generateCode(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    VIBEEC Code Generator v24.φ\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Input:  {s}\n", .{input_path});
    std.debug.print("  Output: {s}\n", .{output_path});
    std.debug.print("\n", .{});
    
    // Читаем .vibee файл
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        std.debug.print("  ❌ Error opening file: {}\n", .{err});
        return err;
    };
    defer file.close();
    
    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);
    
    std.debug.print("  ✓ Read {d} bytes\n", .{source.len});
    
    // Парсим
    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();
    
    std.debug.print("  ✓ Parsed specification: {s} v{s}\n", .{ spec.name, spec.version });
    std.debug.print("    - Constants: {d}\n", .{spec.constants.items.len});
    std.debug.print("    - Types: {d}\n", .{spec.types.items.len});
    std.debug.print("    - Patterns: {d}\n", .{spec.creation_patterns.items.len});
    std.debug.print("    - Behaviors: {d}\n", .{spec.behaviors.items.len});
    
    // Генерируем Zig код
    var codegen = zig_codegen.ZigCodeGen.init(allocator);
    defer codegen.deinit();
    
    const output = try codegen.generate(&spec);
    
    std.debug.print("  ✓ Generated {d} bytes of Zig code\n", .{output.len});
    
    // Создаём директорию если нужно
    const dir_path = std.fs.path.dirname(output_path) orelse ".";
    std.fs.cwd().makePath(dir_path) catch {};
    
    // Записываем в файл
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    
    try out_file.writeAll(output);
    
    std.debug.print("  ✓ Written to {s}\n", .{output_path});
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                         GENERATION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  1. Review generated code: {s}\n", .{output_path});
    std.debug.print("  2. Build WASM: cd trinity/wasm && zig build\n", .{});
    std.debug.print("  3. Run tests: zig build test\n", .{});
    std.debug.print("\n", .{});
}
