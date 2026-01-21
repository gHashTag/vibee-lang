// ═══════════════════════════════════════════════════════════════════════════════
// BROWSER_V3 WASM Build - Compiled from browser_v3 specifications
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    const enable_simd = b.option(bool, "simd", "Enable WASM SIMD128") orelse true;
    
    var wasm_query: std.Target.Query = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    };
    
    if (enable_simd) {
        wasm_query.cpu_features_add = std.Target.wasm.featureSet(&.{.simd128});
    }
    
    const wasm_target = b.resolveTargetQuery(wasm_query);
    const optimize = b.standardOptimizeOption(.{});
    const native_target = b.standardTargetOptions(.{});

    // Browser V3 modules
    const modules = [_][]const u8{
        "vibee_wasm_runtime",
        "vibee_wasm_memory", 
        "vibee_wasm_bindings",
        "vibee_wasm_compiler",
        "vibee_wasm_loader",
        "vibee_wasm_interop",
    };

    const test_step = b.step("test", "Run all tests");

    inline for (modules) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path("../output/" ++ name ++ ".zig"),
            .target = wasm_target,
            .optimize = optimize,
        });
        exe.entry = .disabled;
        exe.rdynamic = true;
        exe.stack_size = 103 * 1024;
        b.installArtifact(exe);

        const tests = b.addTest(.{
            .root_source_file = b.path("../output/" ++ name ++ ".zig"),
            .target = native_target,
            .optimize = optimize,
        });
        test_step.dependOn(&b.addRunArtifact(tests).step);
    }
}
