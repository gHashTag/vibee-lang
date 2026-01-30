// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC BUILD SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V36 - Unified Build Configuration
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_legacy = (builtin.zig_version.minor <= 13);

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN COMPILER EXECUTABLE
    // ═══════════════════════════════════════════════════════════════════════════

    const exe = if (is_legacy)
        b.addExecutable(.{
            .name = "vibeec",
            .root_source_file = b.path("compiler.zig"),
            .target = target,
            .optimize = optimize,
        })
    else
        b.addExecutable(.{
            .name = "vibeec",
            .root_module = b.createModule(.{
                .root_source_file = b.path("compiler.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the VIBEEC compiler");
    run_step.dependOn(&run_cmd.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST SUITE
    // ═══════════════════════════════════════════════════════════════════════════

    const test_modules = [_][]const u8{
        "parser_v3.zig",
        "codegen_v4.zig",
        "type_checker.zig",
        "error_reporter.zig",
        "cli.zig",
        "compiler.zig",
        "ast.zig",
        "semantic.zig",
        "bytecode.zig",
        "optimizer.zig",
    };

    const test_step = b.step("test", "Run all VIBEEC tests");

    for (test_modules) |module| {
        const unit_tests = if (is_legacy)
            b.addTest(.{
                .root_source_file = b.path(module),
                .target = target,
                .optimize = optimize,
            })
        else
            b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(module),
                    .target = target,
                    .optimize = optimize,
                }),
            });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DOCUMENTATION
    // ═══════════════════════════════════════════════════════════════════════════

    const docs_step = b.step("docs", "Generate documentation");

    const docs = if (is_legacy)
        b.addStaticLibrary(.{
            .name = "vibeec-docs",
            .root_source_file = b.path("compiler.zig"),
            .target = target,
            .optimize = optimize,
        })
    else
        b.addLibrary(.{
            .name = "vibeec-docs",
            .root_module = b.createModule(.{
                .root_source_file = b.path("compiler.zig"),
                .target = target,
                .optimize = optimize,
            }),
            .linkage = .static,
        });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&install_docs.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // CLEAN
    // ═══════════════════════════════════════════════════════════════════════════

    const clean_step = b.step("clean", "Clean build artifacts");
    _ = clean_step;
    // Note: Manual cleanup via `rm -rf zig-out .zig-cache`
}
