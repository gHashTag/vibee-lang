//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE BUILD SYSTEM V2 - GENERATED FROM specs/vibee_production.vibee
//! ═══════════════════════════════════════════════════════════════════════════════
//! φ² + 1/φ² = 3
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ═══════════════════════════════════════════════════════════════════════════
    // VIBEEC V2 - New CLI with file output and watch mode
    // ═══════════════════════════════════════════════════════════════════════════

    const vibeec_v2 = b.addExecutable(.{
        .name = "vibeec",
        .root_source_file = b.path("vibeec_cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(vibeec_v2);

    const run_cmd = b.addRunArtifact(vibeec_v2);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run vibeec V2");
    run_step.dependOn(&run_cmd.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS V2
    // ═══════════════════════════════════════════════════════════════════════════

    // Parser V2 tests
    const parser_v2_tests = b.addTest(.{
        .root_source_file = b.path("parser_v2.zig"),
        .target = target,
        .optimize = optimize,
    });

    const codegen_tests = b.addTest(.{
        .root_source_file = b.path("codegen.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pas_tests = b.addTest(.{
        .root_source_file = b.path("pas.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const evolution_tests = b.addTest(.{
        .root_source_file = b.path("evolution.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(parser_tests).step);
    test_step.dependOn(&b.addRunArtifact(codegen_tests).step);
    test_step.dependOn(&b.addRunArtifact(pas_tests).step);
    test_step.dependOn(&b.addRunArtifact(evolution_tests).step);
    
    // Evolution runner
    const evolution_exe = b.addExecutable(.{
        .name = "evolution",
        .root_source_file = b.path("evolution.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    b.installArtifact(evolution_exe);
    
    const evolution_run = b.addRunArtifact(evolution_exe);
    const evolution_step = b.step("evolve", "Run evolutionary optimizer");
    evolution_step.dependOn(&evolution_run.step);
}
