// ============================================================================
// VIBEEC PERFORMANCE PREDICTOR
// Predicts code performance based on genome parameters
// Mirrors the superheavy element prediction methodology
// ============================================================================

const std = @import("std");
const math = std.math;
const evolution = @import("evolution.zig");

// ============================================================================
// CREATION PATTERN FOR PERFORMANCE PREDICTION
// ============================================================================
//
// Source: CodegenGenome (parameters)
// Transformer: Performance model (like Bethe-Weizsacker formula)
// Result: Predicted metrics (runtime, size, compile time)
//
// This mirrors element property prediction:
//   Elements: (Z,N) → physics model → binding energy, half-life
//   Compiler: genome → performance model → runtime, size, memory
// ============================================================================

/// Performance prediction model coefficients
/// Analogous to Bethe-Weizsacker mass formula coefficients
pub const ModelCoefficients = struct {
    // Base performance (like volume term)
    base_runtime: f64 = 100.0,      // ms
    base_size: f64 = 1000.0,        // KB
    base_compile: f64 = 500.0,      // ms
    base_memory: f64 = 50.0,        // MB
    
    // Optimization impact (like surface term)
    opt_runtime_factor: f64 = 0.15,     // per level
    opt_size_factor: f64 = 0.05,        // per level (increases)
    opt_compile_factor: f64 = 0.10,     // per level (increases)
    
    // Inlining impact
    inline_runtime_factor: f64 = 0.002, // per threshold point
    inline_size_factor: f64 = 0.003,    // per threshold point
    
    // Loop unrolling impact
    unroll_runtime_factor: f64 = 0.03,  // per factor
    unroll_size_factor: f64 = 0.04,     // per factor
    
    // SIMD impact
    simd_runtime_bonus: f64 = 0.20,     // 20% faster
    simd_size_penalty: f64 = 0.05,      // 5% larger
    
    // Dead code elimination impact
    dce_size_factor: f64 = 0.003,       // per percentage
    
    // Register allocation impact
    regalloc_linear_penalty: f64 = 0.10,
    regalloc_graphcolor_bonus: f64 = 0.08,
    regalloc_graphcolor_compile_penalty: f64 = 0.15,
    
    // Code layout impact
    layout_hotcold_bonus: f64 = 0.05,
    layout_profile_bonus: f64 = 0.12,
};

/// Predicted performance metrics
pub const PredictedMetrics = struct {
    runtime_ms: f64,
    binary_size_kb: f64,
    compile_time_ms: f64,
    memory_mb: f64,
    confidence: f64,  // 0-1, how confident we are in prediction
};

/// Prediction result with breakdown
pub const PredictionResult = struct {
    metrics: PredictedMetrics,
    breakdown: PredictionBreakdown,
    genome: evolution.CodegenGenome,
};

/// Breakdown of how each parameter affects performance
pub const PredictionBreakdown = struct {
    // Runtime contributions
    runtime_base: f64,
    runtime_opt_effect: f64,
    runtime_inline_effect: f64,
    runtime_unroll_effect: f64,
    runtime_simd_effect: f64,
    runtime_regalloc_effect: f64,
    runtime_layout_effect: f64,
    
    // Size contributions
    size_base: f64,
    size_opt_effect: f64,
    size_inline_effect: f64,
    size_unroll_effect: f64,
    size_simd_effect: f64,
    size_dce_effect: f64,
    
    // Compile time contributions
    compile_base: f64,
    compile_opt_effect: f64,
    compile_regalloc_effect: f64,
};

// ============================================================================
// PREDICTION ENGINE
// ============================================================================

/// Predict performance for a given genome
/// This is analogous to predicting element properties from (Z,N)
pub fn predictPerformance(genome: *const evolution.CodegenGenome, coeffs: ModelCoefficients) PredictionResult {
    var breakdown = PredictionBreakdown{
        .runtime_base = coeffs.base_runtime,
        .runtime_opt_effect = 0,
        .runtime_inline_effect = 0,
        .runtime_unroll_effect = 0,
        .runtime_simd_effect = 0,
        .runtime_regalloc_effect = 0,
        .runtime_layout_effect = 0,
        .size_base = coeffs.base_size,
        .size_opt_effect = 0,
        .size_inline_effect = 0,
        .size_unroll_effect = 0,
        .size_simd_effect = 0,
        .size_dce_effect = 0,
        .compile_base = coeffs.base_compile,
        .compile_opt_effect = 0,
        .compile_regalloc_effect = 0,
    };
    
    // === RUNTIME PREDICTION ===
    var runtime = coeffs.base_runtime;
    
    // Optimization level reduces runtime
    const opt_reduction = @as(f64, @floatFromInt(genome.optimization_level)) * coeffs.opt_runtime_factor;
    breakdown.runtime_opt_effect = -runtime * opt_reduction;
    runtime *= (1.0 - opt_reduction);
    
    // Inlining reduces runtime (up to a point)
    const inline_reduction = @as(f64, @floatFromInt(genome.inline_threshold)) * coeffs.inline_runtime_factor;
    breakdown.runtime_inline_effect = -runtime * @min(0.15, inline_reduction);
    runtime *= (1.0 - @min(0.15, inline_reduction));
    
    // Loop unrolling reduces runtime
    const unroll_reduction = @as(f64, @floatFromInt(genome.loop_unroll_factor - 1)) * coeffs.unroll_runtime_factor;
    breakdown.runtime_unroll_effect = -runtime * unroll_reduction;
    runtime *= (1.0 - unroll_reduction);
    
    // SIMD bonus
    if (genome.use_simd) {
        breakdown.runtime_simd_effect = -runtime * coeffs.simd_runtime_bonus;
        runtime *= (1.0 - coeffs.simd_runtime_bonus);
    }
    
    // Register allocation
    const regalloc_effect = switch (genome.register_allocation) {
        .Linear => coeffs.regalloc_linear_penalty,
        .GraphColor => -coeffs.regalloc_graphcolor_bonus,
        .Hybrid => 0.0,
    };
    breakdown.runtime_regalloc_effect = runtime * regalloc_effect;
    runtime *= (1.0 + regalloc_effect);
    
    // Code layout
    const layout_effect = switch (genome.code_layout) {
        .Sequential => 0.0,
        .HotCold => -coeffs.layout_hotcold_bonus,
        .ProfileGuided => -coeffs.layout_profile_bonus,
    };
    breakdown.runtime_layout_effect = runtime * layout_effect;
    runtime *= (1.0 + layout_effect);
    
    // === SIZE PREDICTION ===
    var size = coeffs.base_size;
    
    // Optimization can increase size
    const opt_size_increase = @as(f64, @floatFromInt(genome.optimization_level)) * coeffs.opt_size_factor;
    breakdown.size_opt_effect = size * opt_size_increase;
    size *= (1.0 + opt_size_increase);
    
    // Inlining increases size
    const inline_size_increase = @as(f64, @floatFromInt(genome.inline_threshold)) * coeffs.inline_size_factor;
    breakdown.size_inline_effect = size * inline_size_increase;
    size *= (1.0 + inline_size_increase);
    
    // Loop unrolling increases size
    const unroll_size_increase = @as(f64, @floatFromInt(genome.loop_unroll_factor - 1)) * coeffs.unroll_size_factor;
    breakdown.size_unroll_effect = size * unroll_size_increase;
    size *= (1.0 + unroll_size_increase);
    
    // SIMD increases size slightly
    if (genome.use_simd) {
        breakdown.size_simd_effect = size * coeffs.simd_size_penalty;
        size *= (1.0 + coeffs.simd_size_penalty);
    }
    
    // Dead code elimination reduces size
    const dce_reduction = @as(f64, @floatFromInt(genome.dead_code_elimination)) * coeffs.dce_size_factor;
    breakdown.size_dce_effect = -size * dce_reduction;
    size *= (1.0 - dce_reduction);
    
    // === COMPILE TIME PREDICTION ===
    var compile_time = coeffs.base_compile;
    
    // Higher optimization = longer compile
    const opt_compile_increase = @as(f64, @floatFromInt(genome.optimization_level)) * coeffs.opt_compile_factor;
    breakdown.compile_opt_effect = compile_time * opt_compile_increase;
    compile_time *= (1.0 + opt_compile_increase);
    
    // Graph coloring takes longer
    const regalloc_compile_effect = switch (genome.register_allocation) {
        .Linear => 0.0,
        .GraphColor => coeffs.regalloc_graphcolor_compile_penalty,
        .Hybrid => coeffs.regalloc_graphcolor_compile_penalty * 0.5,
    };
    breakdown.compile_regalloc_effect = compile_time * regalloc_compile_effect;
    compile_time *= (1.0 + regalloc_compile_effect);
    
    // === MEMORY PREDICTION ===
    // Memory correlates with size and optimization level
    const memory = coeffs.base_memory * (size / coeffs.base_size) * 
                   (1.0 + @as(f64, @floatFromInt(genome.optimization_level)) * 0.1);
    
    // === CONFIDENCE ===
    // Higher for moderate parameters, lower for extreme values
    var confidence: f64 = 0.9;
    if (genome.optimization_level == 3) confidence -= 0.05;
    if (genome.inline_threshold > 80) confidence -= 0.05;
    if (genome.loop_unroll_factor > 6) confidence -= 0.05;
    
    return PredictionResult{
        .metrics = PredictedMetrics{
            .runtime_ms = @max(1.0, runtime),
            .binary_size_kb = @max(100.0, size),
            .compile_time_ms = @max(10.0, compile_time),
            .memory_mb = @max(5.0, memory),
            .confidence = confidence,
        },
        .breakdown = breakdown,
        .genome = genome.*,
    };
}

/// Compare predicted vs actual metrics (for model calibration)
pub const CalibrationResult = struct {
    runtime_error_percent: f64,
    size_error_percent: f64,
    compile_error_percent: f64,
    memory_error_percent: f64,
    avg_error_percent: f64,
};

pub fn calibrate(predicted: PredictedMetrics, actual: PredictedMetrics) CalibrationResult {
    const runtime_error = @abs(predicted.runtime_ms - actual.runtime_ms) / actual.runtime_ms * 100.0;
    const size_error = @abs(predicted.binary_size_kb - actual.binary_size_kb) / actual.binary_size_kb * 100.0;
    const compile_error = @abs(predicted.compile_time_ms - actual.compile_time_ms) / actual.compile_time_ms * 100.0;
    const memory_error = @abs(predicted.memory_mb - actual.memory_mb) / actual.memory_mb * 100.0;
    
    return CalibrationResult{
        .runtime_error_percent = runtime_error,
        .size_error_percent = size_error,
        .compile_error_percent = compile_error,
        .memory_error_percent = memory_error,
        .avg_error_percent = (runtime_error + size_error + compile_error + memory_error) / 4.0,
    };
}

// ============================================================================
// OPTIMIZATION RECOMMENDATIONS
// ============================================================================

pub const Recommendation = struct {
    parameter: []const u8,
    current_value: []const u8,
    suggested_value: []const u8,
    expected_improvement: []const u8,
    trade_off: []const u8,
};

/// Generate optimization recommendations based on prediction
pub fn generateRecommendations(result: *const PredictionResult, allocator: std.mem.Allocator) ![]Recommendation {
    var recommendations = std.ArrayList(Recommendation).init(allocator);
    
    const genome = &result.genome;
    
    // Check optimization level
    if (genome.optimization_level < 2 and result.metrics.runtime_ms > 50) {
        try recommendations.append(Recommendation{
            .parameter = "optimization_level",
            .current_value = switch (genome.optimization_level) {
                0 => "0",
                1 => "1",
                else => "2",
            },
            .suggested_value = "3",
            .expected_improvement = "15-25% faster runtime",
            .trade_off = "10-20% longer compile time",
        });
    }
    
    // Check SIMD
    if (!genome.use_simd and result.metrics.runtime_ms > 40) {
        try recommendations.append(Recommendation{
            .parameter = "use_simd",
            .current_value = "false",
            .suggested_value = "true",
            .expected_improvement = "20% faster runtime",
            .trade_off = "5% larger binary",
        });
    }
    
    // Check register allocation
    if (genome.register_allocation == .Linear and result.metrics.runtime_ms > 60) {
        try recommendations.append(Recommendation{
            .parameter = "register_allocation",
            .current_value = "Linear",
            .suggested_value = "GraphColor",
            .expected_improvement = "8% faster runtime",
            .trade_off = "15% longer compile time",
        });
    }
    
    // Check code layout
    if (genome.code_layout == .Sequential and result.metrics.runtime_ms > 50) {
        try recommendations.append(Recommendation{
            .parameter = "code_layout",
            .current_value = "Sequential",
            .suggested_value = "ProfileGuided",
            .expected_improvement = "12% faster runtime",
            .trade_off = "Requires profiling data",
        });
    }
    
    // Check dead code elimination for size
    if (genome.dead_code_elimination < 50 and result.metrics.binary_size_kb > 1500) {
        try recommendations.append(Recommendation{
            .parameter = "dead_code_elimination",
            .current_value = "low",
            .suggested_value = "80+",
            .expected_improvement = "15-20% smaller binary",
            .trade_off = "Minimal",
        });
    }
    
    return recommendations.toOwnedSlice();
}

// ============================================================================
// MAIN - Demonstrate prediction system
// ============================================================================

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              VIBEEC PERFORMANCE PREDICTOR                                   ║\n", .{});
    try stdout.print("║              Predicting Code Performance from Genome Parameters             ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Create test genomes
    const genomes = [_]evolution.CodegenGenome{
        // Low optimization genome
        evolution.CodegenGenome{
            .id = 1,
            .generation = 0,
            .optimization_level = 0,
            .inline_threshold = 20,
            .loop_unroll_factor = 1,
            .use_simd = false,
            .dead_code_elimination = 30,
            .constant_folding_depth = 2,
            .register_allocation = .Linear,
            .code_layout = .Sequential,
            .fitness = 0,
            .runtime_score = 0,
            .size_score = 0,
            .compile_score = 0,
            .correctness = 1,
        },
        // Medium optimization genome
        evolution.CodegenGenome{
            .id = 2,
            .generation = 0,
            .optimization_level = 2,
            .inline_threshold = 50,
            .loop_unroll_factor = 4,
            .use_simd = true,
            .dead_code_elimination = 60,
            .constant_folding_depth = 5,
            .register_allocation = .Hybrid,
            .code_layout = .HotCold,
            .fitness = 0,
            .runtime_score = 0,
            .size_score = 0,
            .compile_score = 0,
            .correctness = 1,
        },
        // High optimization genome (from best_genome.json)
        evolution.CodegenGenome{
            .id = 3,
            .generation = 1,
            .optimization_level = 3,
            .inline_threshold = 65,
            .loop_unroll_factor = 3,
            .use_simd = true,
            .dead_code_elimination = 64,
            .constant_folding_depth = 5,
            .register_allocation = .GraphColor,
            .code_layout = .ProfileGuided,
            .fitness = 0.95,
            .runtime_score = 0,
            .size_score = 0,
            .compile_score = 0,
            .correctness = 1,
        },
    };

    const coeffs = ModelCoefficients{};

    for (genomes, 0..) |genome, i| {
        try stdout.print("═══ GENOME {d} ═══\n\n", .{i + 1});
        
        const result = predictPerformance(&genome, coeffs);
        
        try stdout.print("Parameters:\n", .{});
        try stdout.print("  optimization_level: {d}\n", .{genome.optimization_level});
        try stdout.print("  inline_threshold: {d}\n", .{genome.inline_threshold});
        try stdout.print("  loop_unroll_factor: {d}\n", .{genome.loop_unroll_factor});
        try stdout.print("  use_simd: {s}\n", .{if (genome.use_simd) "true" else "false"});
        try stdout.print("  dead_code_elimination: {d}\n", .{genome.dead_code_elimination});
        try stdout.print("  register_allocation: {s}\n", .{@tagName(genome.register_allocation)});
        try stdout.print("  code_layout: {s}\n\n", .{@tagName(genome.code_layout)});

        try stdout.print("Predicted Performance:\n", .{});
        try stdout.print("  Runtime: {d:.1} ms\n", .{result.metrics.runtime_ms});
        try stdout.print("  Binary size: {d:.1} KB\n", .{result.metrics.binary_size_kb});
        try stdout.print("  Compile time: {d:.1} ms\n", .{result.metrics.compile_time_ms});
        try stdout.print("  Memory: {d:.1} MB\n", .{result.metrics.memory_mb});
        try stdout.print("  Confidence: {d:.0}%\n\n", .{result.metrics.confidence * 100});

        try stdout.print("Runtime Breakdown:\n", .{});
        try stdout.print("  Base: {d:.1} ms\n", .{result.breakdown.runtime_base});
        try stdout.print("  Optimization effect: {d:.1} ms\n", .{result.breakdown.runtime_opt_effect});
        try stdout.print("  Inline effect: {d:.1} ms\n", .{result.breakdown.runtime_inline_effect});
        try stdout.print("  Unroll effect: {d:.1} ms\n", .{result.breakdown.runtime_unroll_effect});
        try stdout.print("  SIMD effect: {d:.1} ms\n", .{result.breakdown.runtime_simd_effect});
        try stdout.print("  Register alloc effect: {d:.1} ms\n", .{result.breakdown.runtime_regalloc_effect});
        try stdout.print("  Layout effect: {d:.1} ms\n\n", .{result.breakdown.runtime_layout_effect});

        // Generate recommendations
        const recommendations = try generateRecommendations(&result, allocator);
        defer allocator.free(recommendations);
        
        if (recommendations.len > 0) {
            try stdout.print("Recommendations:\n", .{});
            for (recommendations) |rec| {
                try stdout.print("  - {s}: {s} -> {s}\n", .{rec.parameter, rec.current_value, rec.suggested_value});
                try stdout.print("    Expected: {s}\n", .{rec.expected_improvement});
                try stdout.print("    Trade-off: {s}\n", .{rec.trade_off});
            }
            try stdout.print("\n", .{});
        } else {
            try stdout.print("No recommendations - genome is well optimized\n\n", .{});
        }
    }

    // Compare genomes
    try stdout.print("═══ COMPARISON ═══\n\n", .{});
    
    const low_result = predictPerformance(&genomes[0], coeffs);
    const high_result = predictPerformance(&genomes[2], coeffs);
    
    const runtime_improvement = (low_result.metrics.runtime_ms - high_result.metrics.runtime_ms) / low_result.metrics.runtime_ms * 100;
    const size_change = (high_result.metrics.binary_size_kb - low_result.metrics.binary_size_kb) / low_result.metrics.binary_size_kb * 100;
    
    try stdout.print("Low vs High Optimization:\n", .{});
    try stdout.print("  Runtime improvement: {d:.1}%\n", .{runtime_improvement});
    try stdout.print("  Size increase: {d:.1}%\n", .{size_change});
    try stdout.print("  Trade-off ratio: {d:.2} (runtime gain per size cost)\n\n", .{runtime_improvement / @max(1, size_change)});

    try stdout.print("✅ Performance prediction complete\n", .{});
}

// ============================================================================
// TESTS
// ============================================================================

test "prediction produces valid metrics" {
    const genome = evolution.CodegenGenome{
        .id = 0,
        .generation = 0,
        .optimization_level = 2,
        .inline_threshold = 50,
        .loop_unroll_factor = 4,
        .use_simd = true,
        .dead_code_elimination = 60,
        .constant_folding_depth = 5,
        .register_allocation = .Hybrid,
        .code_layout = .HotCold,
        .fitness = 0,
        .runtime_score = 0,
        .size_score = 0,
        .compile_score = 0,
        .correctness = 1,
    };
    
    const result = predictPerformance(&genome, ModelCoefficients{});
    
    try std.testing.expect(result.metrics.runtime_ms > 0);
    try std.testing.expect(result.metrics.binary_size_kb > 0);
    try std.testing.expect(result.metrics.compile_time_ms > 0);
    try std.testing.expect(result.metrics.confidence > 0 and result.metrics.confidence <= 1);
}

test "higher optimization reduces runtime" {
    const low_opt = evolution.CodegenGenome{
        .id = 0,
        .generation = 0,
        .optimization_level = 0,
        .inline_threshold = 50,
        .loop_unroll_factor = 1,
        .use_simd = false,
        .dead_code_elimination = 50,
        .constant_folding_depth = 5,
        .register_allocation = .Linear,
        .code_layout = .Sequential,
        .fitness = 0,
        .runtime_score = 0,
        .size_score = 0,
        .compile_score = 0,
        .correctness = 1,
    };
    
    var high_opt = low_opt;
    high_opt.optimization_level = 3;
    high_opt.use_simd = true;
    high_opt.register_allocation = .GraphColor;
    
    const low_result = predictPerformance(&low_opt, ModelCoefficients{});
    const high_result = predictPerformance(&high_opt, ModelCoefficients{});
    
    try std.testing.expect(high_result.metrics.runtime_ms < low_result.metrics.runtime_ms);
}

test "SIMD improves runtime" {
    var no_simd = evolution.CodegenGenome{
        .id = 0,
        .generation = 0,
        .optimization_level = 2,
        .inline_threshold = 50,
        .loop_unroll_factor = 4,
        .use_simd = false,
        .dead_code_elimination = 50,
        .constant_folding_depth = 5,
        .register_allocation = .Hybrid,
        .code_layout = .Sequential,
        .fitness = 0,
        .runtime_score = 0,
        .size_score = 0,
        .compile_score = 0,
        .correctness = 1,
    };
    
    var with_simd = no_simd;
    with_simd.use_simd = true;
    
    const no_simd_result = predictPerformance(&no_simd, ModelCoefficients{});
    const with_simd_result = predictPerformance(&with_simd, ModelCoefficients{});
    
    try std.testing.expect(with_simd_result.metrics.runtime_ms < no_simd_result.metrics.runtime_ms);
}

test "dead code elimination reduces size" {
    var low_dce = evolution.CodegenGenome{
        .id = 0,
        .generation = 0,
        .optimization_level = 2,
        .inline_threshold = 50,
        .loop_unroll_factor = 4,
        .use_simd = false,
        .dead_code_elimination = 10,
        .constant_folding_depth = 5,
        .register_allocation = .Hybrid,
        .code_layout = .Sequential,
        .fitness = 0,
        .runtime_score = 0,
        .size_score = 0,
        .compile_score = 0,
        .correctness = 1,
    };
    
    var high_dce = low_dce;
    high_dce.dead_code_elimination = 90;
    
    const low_dce_result = predictPerformance(&low_dce, ModelCoefficients{});
    const high_dce_result = predictPerformance(&high_dce, ModelCoefficients{});
    
    try std.testing.expect(high_dce_result.metrics.binary_size_kb < low_dce_result.metrics.binary_size_kb);
}
