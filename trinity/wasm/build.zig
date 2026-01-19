// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY WASM Build - Generated from .vibee specifications
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 (TRINITY Identity)
//
// Modules:
//   phi_core.wasm       - Core φ-computations (Fibonacci, Lucas, spirals)
//   phi_structures.wasm - φ-Tree, Fibonacci Heap, φ-Graph
//   phi_layout.wasm     - Force-directed, hierarchical, radial layouts
//   phi_crypto.wasm     - SHA-256, Merkle Tree, verification
//
// Commands:
//   zig build                        - Build all WASM modules
//   zig build test                   - Run all tests
//   zig build -Doptimize=ReleaseSmall - Optimized build
//   zig build -Dsimd=true            - Enable SIMD128 optimizations
//
// SIMD Optimizations:
//   - WASM SIMD128 for vector operations (4x f32 or 2x f64)
//   - Accelerated spiral generation, layout calculations
//   - SHA-256 parallel rounds
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn build(b: *std.Build) void {
    // SIMD option
    const enable_simd = b.option(bool, "simd", "Enable WASM SIMD128 optimizations") orelse true;
    
    // WASM target with optional SIMD
    var wasm_query: std.Target.Query = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    };
    
    // Enable SIMD128 feature if requested
    if (enable_simd) {
        wasm_query.cpu_features_add = std.Target.wasm.featureSet(&.{.simd128});
    }
    
    const wasm_target = b.resolveTargetQuery(wasm_query);

    const optimize = b.standardOptimizeOption(.{});
    const native_target = b.standardTargetOptions(.{});

    // ═══════════════════════════════════════════════════════════════════════════
    // WASM MODULES
    // ═══════════════════════════════════════════════════════════════════════════

    // φ-core module (from phi_core.vibee)
    const phi_core = b.addExecutable(.{
        .name = "phi_core",
        .root_source_file = b.path("src/phi_core.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    phi_core.entry = .disabled;
    phi_core.rdynamic = true;
    phi_core.stack_size = 103 * 1024; // φ × 64KB
    b.installArtifact(phi_core);

    // φ-structures module (from phi_structures.vibee)
    const phi_structures = b.addExecutable(.{
        .name = "phi_structures",
        .root_source_file = b.path("src/phi_structures.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    phi_structures.entry = .disabled;
    phi_structures.rdynamic = true;
    phi_structures.stack_size = 103 * 1024;
    b.installArtifact(phi_structures);

    // φ-layout module (from phi_layout.vibee)
    const phi_layout = b.addExecutable(.{
        .name = "phi_layout",
        .root_source_file = b.path("src/phi_layout.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    phi_layout.entry = .disabled;
    phi_layout.rdynamic = true;
    phi_layout.stack_size = 103 * 1024;
    b.installArtifact(phi_layout);

    // φ-crypto module (from phi_crypto.vibee)
    const phi_crypto = b.addExecutable(.{
        .name = "phi_crypto",
        .root_source_file = b.path("src/phi_crypto.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    phi_crypto.entry = .disabled;
    phi_crypto.rdynamic = true;
    phi_crypto.stack_size = 103 * 1024;
    b.installArtifact(phi_crypto);

    // Legacy phi_compute (for compatibility)
    const phi_compute = b.addExecutable(.{
        .name = "phi_compute",
        .root_source_file = b.path("phi_compute.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    phi_compute.entry = .disabled;
    phi_compute.rdynamic = true;
    b.installArtifact(phi_compute);

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    const test_step = b.step("test", "Run all φ-module tests");

    // phi_core tests
    const core_tests = b.addTest(.{
        .root_source_file = b.path("src/phi_core.zig"),
        .target = native_target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(core_tests).step);

    // phi_structures tests
    const struct_tests = b.addTest(.{
        .root_source_file = b.path("src/phi_structures.zig"),
        .target = native_target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(struct_tests).step);

    // phi_layout tests
    const layout_tests = b.addTest(.{
        .root_source_file = b.path("src/phi_layout.zig"),
        .target = native_target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(layout_tests).step);

    // phi_crypto tests
    const crypto_tests = b.addTest(.{
        .root_source_file = b.path("src/phi_crypto.zig"),
        .target = native_target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(crypto_tests).step);
}
