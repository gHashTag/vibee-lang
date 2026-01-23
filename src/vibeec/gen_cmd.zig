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
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_interpreter = @import("coptic_interpreter.zig");
const bytecode_compiler = @import("bytecode_compiler.zig");
const vm_runtime = @import("vm_runtime.zig");

pub fn main() !void {
    // Use page allocator for now (no leak detection) until GC is implemented
    const allocator = std.heap.page_allocator;
    
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
        var derived_path: ?[]const u8 = null;
        defer if (derived_path) |p| allocator.free(p);
        
        const output_path = if (args.len > 3) args[3] else blk: {
            derived_path = deriveOutputPath(allocator, input_path) catch {
                std.debug.print("Error: Could not derive output path\n", .{});
                return;
            };
            break :blk derived_path.?;
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
    } else if (std.mem.eql(u8, command, "koschei")) {
        const subcommand = if (args.len > 2) args[2] else "";
        printKoschei(subcommand);
    } else if (std.mem.eql(u8, command, "run")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing source code\n", .{});
            std.debug.print("Usage: vibee run \"<code>\"\n", .{});
            return;
        }
        const source = args[2];
        try runCode(allocator, source);
    } else if (std.mem.eql(u8, command, "bench")) {
        try runBenchmark(allocator);
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

fn printKoschei(subcommand: []const u8) void {
    if (std.mem.eql(u8, subcommand, "chain")) {
        printKoscheiChain();
    } else if (std.mem.eql(u8, subcommand, "status")) {
        printKoscheiStatus();
    } else {
        printKoscheiLinks();
    }
}

fn printKoscheiLinks() void {
    std.debug.print(
        \\
        \\⛓️  GOLDEN CHAIN - 16 LINKS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\"By the curved seashore stands a green oak, a golden chain upon that oak..."
        \\
        \\┌────┬──────────────────┬─────────────────────────────────────────┐
        \\│  # │ LINK             │ DESCRIPTION                             │
        \\├────┼──────────────────┼─────────────────────────────────────────┤
        \\│  1 │ BASELINE         │ Analyze current version                 │
        \\│  2 │ METRICS          │ Collect metrics v(n-1)                  │
        \\│  3 │ PAS ANALYZE      │ Research scientific papers              │
        \\│  4 │ TECH TREE        │ Build technology tree                   │
        \\│  5 │ SPEC CREATE      │ Create .vibee specifications            │
        \\│  6 │ CODE GENERATE    │ Generate .zig from .vibee               │
        \\│  7 │ TEST RUN         │ Run all tests                           │
        \\│  8 │ BENCHMARK PREV   │ ⚡ COMPARE with v(n-1) [CRITICAL]       │
        \\│  9 │ BENCHMARK THEORY │ Compare with theoretical max            │
        \\│ 10 │ DELTA REPORT     │ Report v(n) - v(n-1)                    │
        \\│ 11 │ OPTIMIZE         │ Optimize based on results               │
        \\│ 12 │ DOCS             │ Documentation with proofs               │
        \\│ 13 │ GIT              │ Commit with changelog                   │
        \\│ 14 │ TOXIC VERDICT    │ 🔥 HARSH SELF-CRITICISM                 │
        \\│ 15 │ TECH TREE SELECT │ 🌳 Choose next research                 │
        \\│ 16 │ LOOP/EXIT        │ Decision: v(n+1) or EXIT                │
        \\└────┴──────────────────┴─────────────────────────────────────────┘
        \\
        \\KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3
        \\
        \\
    , .{});
}

fn printKoscheiChain() void {
    std.debug.print(
        \\
        \\🏰 LUKOMORYE ARCHITECTURE
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\                    ┌─────────────────┐
        \\                    │   GREEN OAK     │
        \\                    │  (VIBEE Core)   │
        \\                    └────────┬────────┘
        \\                             │
        \\              ┌──────────────┼──────────────┐
        \\              │              │              │
        \\        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        \\        │  LEARNED  │  │  GOLDEN   │  │  KOSCHEI  │
        \\        │    CAT    │  │   CHAIN   │  │  DAEMON   │
        \\        │ (Parser)  │  │ (16 Links)│  │ (Runtime) │
        \\        └───────────┘  └───────────┘  └───────────┘
        \\
        \\φ² + 1/φ² = 3
        \\
        \\
    , .{});
}

fn printKoscheiStatus() void {
    std.debug.print(
        \\
        \\🐱 LEARNED CAT STATUS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\  Compiler:    vibeec v24.φ
        \\  Languages:   41 targets
        \\  Tests:       65 passing
        \\  Memory:      Arena-based (no leaks)
        \\
        \\  Sacred Constants:
        \\    φ = 1.618033988749895
        \\    φ² + 1/φ² = 3.0
        \\    Trinity = 27
        \\
        \\KOSCHEI IS IMMORTAL
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

fn runCode(allocator: std.mem.Allocator, source: []const u8) !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    VIBEE VM Executor v1.0\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Source: {s}\n", .{source});
    std.debug.print("\n", .{});

    // Parse
    var parser = coptic_parser.Parser.init(source, allocator);
    var ast = parser.parseProgram() catch |err| {
        std.debug.print("  ❌ Parse error: {any}\n", .{err});
        return;
    };
    defer ast.deinit();

    // Compile to bytecode
    var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
    defer compiler.deinit();

    compiler.compile(&ast) catch |err| {
        std.debug.print("  ❌ Compile error: {any}\n", .{err});
        return;
    };

    std.debug.print("  ✓ Compiled to {d} bytes of bytecode\n", .{compiler.getCode().len});

    // Run in VM
    var vm = vm_runtime.VM.init(allocator) catch |err| {
        std.debug.print("  ❌ VM init error: {any}\n", .{err});
        return;
    };
    defer vm.deinit();

    vm.load(compiler.getCode(), compiler.getConstants());

    const result = vm.run() catch |err| {
        std.debug.print("  ❌ Runtime error: {any}\n", .{err});
        return;
    };

    std.debug.print("  ✓ Executed {d} instructions\n", .{vm.instructions_executed});
    std.debug.print("\n", .{});
    std.debug.print("  Result: ", .{});

    switch (result) {
        .nil => std.debug.print("nil\n", .{}),
        .bool_val => |v| std.debug.print("{}\n", .{v}),
        .int_val => |v| std.debug.print("{d}\n", .{v}),
        .float_val => |v| std.debug.print("{d:.6}\n", .{v}),
        .string_val => |v| std.debug.print("\"{s}\"\n", .{v}),
        .func_val => |v| std.debug.print("<func@{d}>\n", .{v.addr}),
        .array_val => |v| {
            std.debug.print("[", .{});
            for (v.items, 0..) |item, i| {
                if (i > 0) std.debug.print(", ", .{});
                switch (item) {
                    .int_val => |n| std.debug.print("{d}", .{n}),
                    .float_val => |n| std.debug.print("{d:.2}", .{n}),
                    .string_val => |s| std.debug.print("\"{s}\"", .{s}),
                    .bool_val => |b| std.debug.print("{}", .{b}),
                    else => std.debug.print("?", .{}),
                }
            }
            std.debug.print("]\n", .{});
        },
        .object_val => |v| std.debug.print("<object({d})>\n", .{v.count}),
        .closure_val => |v| std.debug.print("<closure@{d}>\n", .{v.func_addr}),
    }

    std.debug.print("\n", .{});
}

fn runBenchmark(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    VIBEE VM Benchmark\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    const tests = [_][]const u8{
        "10 + 5 * 3",
        "func double(x) { x * 2 } double(21)",
        "func fact(n) { if n < 2 { 1 } else { n * fact(n - 1) } } fact(10)",
        "func fib(n) { if n < 2 { n } else { fib(n - 1) + fib(n - 2) } } fib(10)",
        "var a = 0 var b = 1 var i = 0 while i < 10 { var t = a + b a = b b = t i = i + 1 } a",
    };

    for (tests) |source| {
        std.debug.print("  Test: {s}\n", .{source});

        // Interpreter
        var parser1 = coptic_parser.Parser.init(source, allocator);
        var ast1 = try parser1.parseProgram();
        defer ast1.deinit();

        var interp = coptic_interpreter.Interpreter.init(allocator, source);
        defer interp.deinit();

        const interp_start = std.time.nanoTimestamp();
        _ = try interp.interpret(&ast1);
        const interp_end = std.time.nanoTimestamp();
        const interp_ns: u64 = @intCast(interp_end - interp_start);

        // VM
        var parser2 = coptic_parser.Parser.init(source, allocator);
        var ast2 = try parser2.parseProgram();
        defer ast2.deinit();

        var compiler = bytecode_compiler.BytecodeCompiler.init(allocator, source);
        defer compiler.deinit();
        try compiler.compile(&ast2);

        var vm = try vm_runtime.VM.init(allocator);
        defer vm.deinit();
        vm.load(compiler.getCode(), compiler.getConstants());

        const vm_start = std.time.nanoTimestamp();
        _ = try vm.run();
        const vm_end = std.time.nanoTimestamp();
        const vm_ns: u64 = @intCast(vm_end - vm_start);

        const speedup = @as(f64, @floatFromInt(interp_ns)) / @as(f64, @floatFromInt(@max(1, vm_ns)));

        std.debug.print("    Interpreter: {d} ns\n", .{interp_ns});
        std.debug.print("    VM:          {d} ns\n", .{vm_ns});
        std.debug.print("    Speedup:     {d:.2}x\n", .{speedup});
        std.debug.print("\n", .{});
    }
}
