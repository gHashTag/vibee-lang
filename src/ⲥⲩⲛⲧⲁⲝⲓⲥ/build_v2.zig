//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE BUILD SYSTEM V2 - GENERATED FROM specs/vibee_production.vibee
//! ═══════════════════════════════════════════════════════════════════════════════
//! Build system for VIBEE Compiler V2
//! Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
//! Golden Identity: φ² + 1/φ² = 3
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTABLE: vibeec
    // ═══════════════════════════════════════════════════════════════════════════

    const vibeec = b.addExecutable(.{
        .name = "vibeec",
        .root_source_file = b.path("vibeec_cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(vibeec);

    // Run step
    const run_cmd = b.addRunArtifact(vibeec);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the VIBEE compiler");
    run_step.dependOn(&run_cmd.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    // Parser V2 tests
    const parser_tests = b.addTest(.{
        .root_source_file = b.path("parser_v2.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Codegen V3 tests
    const codegen_tests = b.addTest(.{
        .root_source_file = b.path("codegen_v3.zig"),
        .target = target,
        .optimize = optimize,
    });

    // PAS Engine V2 tests
    const pas_tests = b.addTest(.{
        .root_source_file = b.path("pas_engine_v2.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unified Compiler tests
    const unified_tests = b.addTest(.{
        .root_source_file = b.path("unified_compiler.zig"),
        .target = target,
        .optimize = optimize,
    });

    // CLI tests
    const cli_tests = b.addTest(.{
        .root_source_file = b.path("vibeec_cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test step
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(parser_tests).step);
    test_step.dependOn(&b.addRunArtifact(codegen_tests).step);
    test_step.dependOn(&b.addRunArtifact(pas_tests).step);
    test_step.dependOn(&b.addRunArtifact(unified_tests).step);
    test_step.dependOn(&b.addRunArtifact(cli_tests).step);

    // ═══════════════════════════════════════════════════════════════════════════
    // INDIVIDUAL TEST STEPS
    // ═══════════════════════════════════════════════════════════════════════════

    const test_parser_step = b.step("test-parser", "Run parser tests");
    test_parser_step.dependOn(&b.addRunArtifact(parser_tests).step);

    const test_codegen_step = b.step("test-codegen", "Run codegen tests");
    test_codegen_step.dependOn(&b.addRunArtifact(codegen_tests).step);

    const test_pas_step = b.step("test-pas", "Run PAS engine tests");
    test_pas_step.dependOn(&b.addRunArtifact(pas_tests).step);

    const test_unified_step = b.step("test-unified", "Run unified compiler tests");
    test_unified_step.dependOn(&b.addRunArtifact(unified_tests).step);

    // ═══════════════════════════════════════════════════════════════════════════
    // RELEASE BUILD
    // ═══════════════════════════════════════════════════════════════════════════

    const release = b.addExecutable(.{
        .name = "vibeec",
        .root_source_file = b.path("vibeec_cli.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const release_step = b.step("release", "Build release version");
    release_step.dependOn(&b.addInstallArtifact(release).step);

    // ═══════════════════════════════════════════════════════════════════════════
    // CLEAN
    // ═══════════════════════════════════════════════════════════════════════════

    const clean_step = b.step("clean", "Clean build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
}
