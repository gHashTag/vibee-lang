// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE ⲦⲢⲒⲚⲒⲦⲨ Build System - Generated Coptic Modules
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
//
// This build file compiles all 42 coptic_*.zig modules
//
// Commands:
//   zig build              - Build library
//   zig build test         - Run all tests
//   zig build -Doptimize=ReleaseFast - Optimized build
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// All coptic modules (42 total)
const coptic_modules = [_][]const u8{
    "coptic_api_facade",
    "coptic_ast",
    "coptic_benchmark",
    "coptic_build_system",
    "coptic_bytecode_emitter",
    "coptic_cli_integration",
    "coptic_codegen",
    "coptic_compiler",
    "coptic_compiler_pipeline",
    "coptic_docs_readme",
    "coptic_docs_syntax",
    "coptic_docs_vibee_format",
    "coptic_error_handler",
    "coptic_file_reader",
    "coptic_gen_dispatcher",
    "coptic_golden_ratio",
    "coptic_integration",
    "coptic_jit_compiler",
    "coptic_jit_optimizer",
    "coptic_lexer",
    "coptic_lexer_impl",
    "coptic_lexer_real",
    "coptic_main",
    "coptic_math_real",
    "coptic_module_registry",
    "coptic_parser",
    "coptic_repl",
    "coptic_repl_commands",
    "coptic_runtime",
    "coptic_sacred_math",
    "coptic_sacred_numbers",
    "coptic_scanner",
    "coptic_simd_trit",
    "coptic_simd_vec27",
    "coptic_stdlib_collections",
    "coptic_stdlib_core",
    "coptic_stdlib_math",
    "coptic_token_stream",
    "coptic_tokens",
    "coptic_trinity_types",
    "coptic_unicode",
    "coptic_vm_integration",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // WASM target
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST STEP - Run all module tests
    // ═══════════════════════════════════════════════════════════════════════════
    const test_step = b.step("test", "Run all ⲦⲢⲒⲚⲒⲦⲨ module tests");

    inline for (coptic_modules) |module_name| {
        const source_path = module_name ++ ".zig";
        const module_tests = b.addTest(.{
            .root_source_file = b.path(source_path),
            .target = target,
            .optimize = optimize,
        });
        const run_tests = b.addRunArtifact(module_tests);
        test_step.dependOn(&run_tests.step);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WASM STEP - Build WASM modules
    // ═══════════════════════════════════════════════════════════════════════════
    const wasm_step = b.step("wasm", "Build WASM modules");
    
    // Build coptic_sacred_math as WASM example
    const wasm_sacred = b.addExecutable(.{
        .name = "coptic_sacred_math",
        .root_source_file = b.path("coptic_sacred_math.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm_sacred.entry = .disabled;
    wasm_sacred.rdynamic = true;
    
    const wasm_install = b.addInstallArtifact(wasm_sacred, .{});
    wasm_step.dependOn(&wasm_install.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // INFO STEP - Show module count
    // ═══════════════════════════════════════════════════════════════════════════
    const info_step = b.step("info", "Show ⲦⲢⲒⲚⲒⲦⲨ build info");
    const info_cmd = b.addSystemCommand(&.{
        "echo",
        "VIBEE ⲦⲢⲒⲚⲒⲦⲨ: 42 coptic modules | φ² + 1/φ² = 3 | WASM ready",
    });
    info_step.dependOn(&info_cmd.step);
}
