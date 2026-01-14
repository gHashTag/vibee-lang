const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{.root_source_file = b.path("main.zig")});
    exe_mod.target = target;
    exe_mod.optimize = optimize;
    const exe = b.addExecutable(.{
        .name = "vibeec",
        .root_module = exe_mod,
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
    const parser_mod = b.createModule(.{.root_source_file = b.path("parser.zig")});
    parser_mod.target = target;
    parser_mod.optimize = optimize;
    const parser_tests = b.addTest(.{
        .root_module = parser_mod,
    });

    const codegen_mod = b.createModule(.{.root_source_file = b.path("codegen.zig")});
    codegen_mod.target = target;
    codegen_mod.optimize = optimize;
    const codegen_tests = b.addTest(.{
        .root_module = codegen_mod,
    });

    const pas_mod = b.createModule(.{.root_source_file = b.path("pas.zig")});
    pas_mod.target = target;
    pas_mod.optimize = optimize;
    const pas_tests = b.addTest(.{
        .root_module = pas_mod,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(parser_tests).step);
    test_step.dependOn(&b.addRunArtifact(codegen_tests).step);
    test_step.dependOn(&b.addRunArtifact(pas_tests).step);
}
