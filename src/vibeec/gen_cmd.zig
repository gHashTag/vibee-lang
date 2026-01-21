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
    const lang_gen = @import("lang_generators.zig");
    
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
    
    // Parse spec - extract name and version from content
    const basename = std.fs.path.basename(input_path);
    var spec_name: []const u8 = std.fs.path.stem(basename);
    var spec_version: []const u8 = "1.0.0";
    
    // Simple parsing for name: and version:
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 5 and std.mem.eql(u8, trimmed[0..5], "name:")) {
            const value = std.mem.trim(u8, trimmed[5..], " \t\"");
            if (value.len > 0 and !std.mem.eql(u8, value, "String")) spec_name = value;
        } else if (trimmed.len > 8 and std.mem.eql(u8, trimmed[0..8], "version:")) {
            const value = std.mem.trim(u8, trimmed[8..], " \t\"");
            if (value.len > 0) spec_version = value;
        }
    }
    
    const spec = lang_gen.ParsedSpec{
        .name = spec_name,
        .version = spec_version,
        .types = &[_]lang_gen.TypeDef{},
        .behaviors = &[_]lang_gen.Behavior{},
    };
    
    std.debug.print("  ✓ Parsed: {s} v{s}\n", .{spec.name, spec.version});
    
    // Create output directory
    const output_dir = "generated/multi";
    std.fs.cwd().makePath(output_dir) catch {};
    
    if (std.mem.eql(u8, target_lang, "all")) {
        // Generate for all languages
        const languages = multi_lang.getAllLanguages();
        std.debug.print("  ✓ Generating for {d} languages...\n\n", .{languages.len});
        
        var generated: usize = 0;
        for (languages) |lang| {
            const ext = multi_lang.getExtension(lang);
            
            // Generate code
            const code = lang_gen.generateForLanguage(allocator, spec, lang) catch |err| {
                std.debug.print("    ❌ {s} - error: {any}\n", .{lang, err});
                continue;
            };
            defer allocator.free(code);
            
            // Write to file
            var path_buf: [256]u8 = undefined;
            const output_path = std.fmt.bufPrint(&path_buf, "{s}/{s}.{s}", .{output_dir, spec_name, ext}) catch continue;
            
            const out_file = std.fs.cwd().createFile(output_path, .{}) catch |err| {
                std.debug.print("    ❌ {s} - write error: {any}\n", .{lang, err});
                continue;
            };
            defer out_file.close();
            out_file.writeAll(code) catch continue;
            
            std.debug.print("    ✓ {s} -> {s}\n", .{lang, output_path});
            generated += 1;
        }
        
        std.debug.print("\n  Generated: {d}/{d} files\n", .{generated, languages.len});
        std.debug.print("  Output: {s}/\n", .{output_dir});
    } else {
        // Generate for single language
        const ext = multi_lang.getExtension(target_lang);
        
        const code = lang_gen.generateForLanguage(allocator, spec, target_lang) catch |err| {
            std.debug.print("  ❌ Error generating {s}: {any}\n", .{target_lang, err});
            return;
        };
        defer allocator.free(code);
        
        var path_buf: [256]u8 = undefined;
        const output_path = std.fmt.bufPrint(&path_buf, "{s}/{s}.{s}", .{output_dir, spec_name, ext}) catch {
            std.debug.print("  ❌ Path error\n", .{});
            return;
        };
        
        const out_file = std.fs.cwd().createFile(output_path, .{}) catch |err| {
            std.debug.print("  ❌ Could not create file: {any}\n", .{err});
            return;
        };
        defer out_file.close();
        out_file.writeAll(code) catch |err| {
            std.debug.print("  ❌ Write error: {any}\n", .{err});
            return;
        };
        
        std.debug.print("  ✓ Generated {s} -> {s}\n", .{target_lang, output_path});
        std.debug.print("  ✓ {d} bytes written\n", .{code.len});
    }
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                         GENERATION COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 | PHOENIX = 999\n", .{});
    std.debug.print("\n", .{});
}
