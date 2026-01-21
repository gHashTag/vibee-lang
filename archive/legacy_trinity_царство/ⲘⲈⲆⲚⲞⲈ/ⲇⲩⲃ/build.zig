const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "trinity",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Trinity compiler");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const zmei_tests = b.addTest(.{
        .root_source_file = b.path("zmei_gorynych.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parser_tests = b.addTest(.{
        .root_source_file = b.path("tls_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_zmei_tests = b.addRunArtifact(zmei_tests);
    const run_parser_tests = b.addRunArtifact(parser_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_zmei_tests.step);
    test_step.dependOn(&run_parser_tests.step);
}
