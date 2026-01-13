const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "physics_evolution",
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

    const run_step = b.step("run", "Run the physics evolution engine");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_genome = b.addTest(.{
        .root_source_file = b.path("genome.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_heuristics = b.addTest(.{
        .root_source_file = b.path("heuristics.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_fitness = b.addTest(.{
        .root_source_file = b.path("fitness.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_mutator = b.addTest(.{
        .root_source_file = b.path("mutator.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_meta = b.addTest(.{
        .root_source_file = b.path("meta_evolution.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.step("test", "Run unit tests");
    run_tests.dependOn(&b.addRunArtifact(test_genome).step);
    run_tests.dependOn(&b.addRunArtifact(test_heuristics).step);
    run_tests.dependOn(&b.addRunArtifact(test_fitness).step);
    run_tests.dependOn(&b.addRunArtifact(test_mutator).step);
    run_tests.dependOn(&b.addRunArtifact(test_meta).step);
}
