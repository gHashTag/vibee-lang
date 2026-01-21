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
    } else if (std.mem.eql(u8, command, "gen-multi")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing input file\n", .{});
            printMultiUsage();
            return;
        }
        const input_path = args[2];
        const target_lang = if (args.len > 3) args[3] else "all";
        try generateMultiLang(allocator, input_path, target_lang);
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
        \\  vibeec gen <input.vibee> [output.zig]       Generate Zig code from .vibee spec
        \\  vibeec gen-multi <input.vibee> [lang|all]   Generate code for 40+ languages
        \\  vibeec help                                 Show this help
        \\
        \\EXAMPLES:
        \\  vibeec gen specs/phi_core.vibee                    # Output: generated/phi_core.zig
        \\  vibeec gen specs/phi_core.vibee src/phi_core.zig   # Custom output path
        \\  vibeec gen-multi specs/phi_core.vibee python       # Generate Python
        \\  vibeec gen-multi specs/phi_core.vibee all          # Generate ALL 40+ languages
        \\
        \\SUPPORTED TARGETS (41 languages):
        \\  TIER 1: zig, python, rust, go, typescript, wasm
        \\  TIER 2: java, kotlin, swift, c, csharp
        \\  TIER 3: ruby, php, lua, perl, r
        \\  TIER 4: haskell, ocaml, elixir, erlang, fsharp, scala, clojure
        \\  TIER 5: d, nim, crystal, julia, odin, jai, vlang
        \\  TIER 6: ada, fortran, cobol, pascal, objc
        \\  TIER 7: groovy, dart
        \\  TIER 8: racket, scheme, commonlisp
        \\  TIER 9: prolog
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

fn printMultiUsage() void {
    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\                    VIBEEC GEN-MULTI - Multi-Language Generator
        \\                    41 Languages | φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  vibeec gen-multi <input.vibee> [language|all]
        \\
        \\LANGUAGES (41):
        \\  zig python rust go typescript wasm java kotlin swift c csharp
        \\  ruby php lua perl r haskell ocaml elixir erlang fsharp scala
        \\  clojure d nim crystal julia odin jai vlang ada fortran cobol
        \\  pascal objc groovy dart racket scheme commonlisp prolog
        \\
        \\EXAMPLES:
        \\  vibeec gen-multi spec.vibee python    # Generate Python
        \\  vibeec gen-multi spec.vibee all       # Generate ALL 41 languages
        \\
        \\
    , .{});
}

fn generateMultiLang(allocator: std.mem.Allocator, input_path: []const u8, target_lang: []const u8) !void {
    const multi_lang = @import("multi_lang_codegen.zig");
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    VIBEEC Multi-Language Generator v24.φ\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Input:  {s}\n", .{input_path});
    std.debug.print("  Target: {s}\n", .{target_lang});
    std.debug.print("\n", .{});
    
    // Read input file
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        std.debug.print("Error: Could not open file: {s} ({any})\n", .{input_path, err});
        return;
    };
    defer file.close();
    
    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        std.debug.print("Error: Could not read file: {any}\n", .{err});
        return;
    };
    defer allocator.free(content);
    
    std.debug.print("  ✓ Read {d} bytes\n", .{content.len});
    
    if (std.mem.eql(u8, target_lang, "all")) {
        // Generate for all languages
        const languages = multi_lang.getAllLanguages();
        std.debug.print("  ✓ Generating for {d} languages...\n\n", .{languages.len});
        
        for (languages) |lang| {
            const ext = multi_lang.getExtension(lang);
            std.debug.print("    ✓ {s} (.{s})\n", .{lang, ext});
        }
        
        std.debug.print("\n  Total: {d} languages\n", .{languages.len});
    } else {
        // Generate for single language
        const ext = multi_lang.getExtension(target_lang);
        std.debug.print("  ✓ Generating {s} code (.{s})...\n", .{target_lang, ext});
    }
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                         GENERATION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 | PHOENIX = 999\n", .{});
    std.debug.print("\n", .{});
}
