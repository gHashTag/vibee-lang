const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "vibeec",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run vibeec");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const parser_tests = b.addTest(.{
        .root_source_file = b.path("parser.zig"),
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

    const simd_parser_tests = b.addTest(.{
        .root_source_file = b.path("simd_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    const egraph_tests = b.addTest(.{
        .root_source_file = b.path("egraph.zig"),
        .target = target,
        .optimize = optimize,
    });

    const property_testing_tests = b.addTest(.{
        .root_source_file = b.path("property_testing.zig"),
        .target = target,
        .optimize = optimize,
    });

    const incremental_types_tests = b.addTest(.{
        .root_source_file = b.path("incremental_types.zig"),
        .target = target,
        .optimize = optimize,
    });

    const coverage_fuzzer_tests = b.addTest(.{
        .root_source_file = b.path("coverage_fuzzer.zig"),
        .target = target,
        .optimize = optimize,
    });

    const integration_tests = b.addTest(.{
        .root_source_file = b.path("integration_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(parser_tests).step);
    test_step.dependOn(&b.addRunArtifact(codegen_tests).step);
    test_step.dependOn(&b.addRunArtifact(pas_tests).step);
    test_step.dependOn(&b.addRunArtifact(simd_parser_tests).step);
    test_step.dependOn(&b.addRunArtifact(egraph_tests).step);
    test_step.dependOn(&b.addRunArtifact(property_testing_tests).step);
    test_step.dependOn(&b.addRunArtifact(incremental_types_tests).step);
    test_step.dependOn(&b.addRunArtifact(coverage_fuzzer_tests).step);

    // Integration tests (separate step)
    const integration_step = b.step("integration", "Run integration tests");
    integration_step.dependOn(&b.addRunArtifact(integration_tests).step);

    // Superoptimizer tests
    const superopt_tests = b.addTest(.{
        .root_source_file = b.path("superoptimizer.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(superopt_tests).step);

    // ML templates tests
    const ml_tests = b.addTest(.{
        .root_source_file = b.path("ml_templates.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(ml_tests).step);

    // Benchmarks (separate step)
    const bench_exe = b.addExecutable(.{
        .name = "vibeec-bench",
        .root_source_file = b.path("benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    b.installArtifact(bench_exe);

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&b.addRunArtifact(bench_exe).step);

    // Demo (separate step)
    const demo_exe = b.addExecutable(.{
        .name = "vibeec-demo",
        .root_source_file = b.path("demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(demo_exe);

    const demo_step = b.step("demo", "Run PAS demo");
    demo_step.dependOn(&b.addRunArtifact(demo_exe).step);
}
