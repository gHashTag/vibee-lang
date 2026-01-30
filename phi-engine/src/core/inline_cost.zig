//! VIBEE Φ-ENGINE - INLINE COST (Solution #8)
//!
//! Inline Cost - Phi-based Inlining Heuristics

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

pub const InlineConfig = struct {
    max_inline_cost: u32 = 100,
    call_overhead: u32 = 10,
    max_function_size: u32 = 500,
    max_inline_depth: u32 = 5,
    always_inline_threshold: u32 = 20,
    hot_call_bonus: u32 = 50,

    sacred_threshold_factor: f64 = PHI,
};

pub const FunctionInfo = struct {
    name: []const u8,
    instruction_count: u32,
    param_count: u8,
    has_side_effects: bool,
    is_recursive: bool,
    call_count: u32 = 0,
    inline_cost: u32 = 0,
    always_inline: bool = false,
    never_inline: bool = false,
};

pub fn computeCost(info: *FunctionInfo, config: *const InlineConfig) void {
    var cost: u32 = info.instruction_count;

    cost += @as(u32, info.param_count) * 2;

    if (info.has_side_effects) {
        cost += 20;
    }

    if (info.is_recursive) {
        cost += 100;
    }

    if (info.call_count > 100) {
        cost -|= config.hot_call_bonus;
    }

    info.inline_cost = cost;
}

pub fn shouldInline(info: *const FunctionInfo, config: *const InlineConfig) bool {
    if (info.never_inline) return false;
    if (info.always_inline) return true;
    if (info.is_recursive) return false;

    const threshold: f64 = @as(f64, config.max_inline_cost) * config.sacred_threshold_factor;

    return @as(f64, info.inline_cost) < threshold;
}

// ════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                               ║
// ╚═══════════════════════════════════════════════════════════════════╝

test "Inline Cost: small hot function" {
    const config = InlineConfig{};
    var info = FunctionInfo{
        .name = "test",
        .instruction_count = 10,
        .param_count = 2,
        .has_side_effects = false,
        .is_recursive = false,
        .call_count = 1000,
    };
    computeCost(&info, &config);

    try std.testing.expect(info.inline_cost == 60);
    try std.testing.expect(shouldInline(&info, &config));
}

test "Inline Cost: large function" {
    const config = InlineConfig{};
    var info = FunctionInfo{
        .name = "test",
        .instruction_count = 500,
        .param_count = 2,
        .has_side_effects = false,
        .is_recursive = false,
        .call_count = 1,
    };
    computeCost(&info, &config);

    try std.testing.expect(!shouldInline(&info, &config));
}

test "Inline Cost: recursive" {
    const config = InlineConfig{};
    var info = FunctionInfo{
        .name = "test",
        .instruction_count = 10,
        .param_count = 2,
        .has_side_effects = false,
        .is_recursive = true,
        .call_count = 1,
    };
    computeCost(&info, &config);

    try std.testing.expect(!shouldInline(&info, &config));
}

test "Inline Cost: always inline" {
    const config = InlineConfig{};
    var info = FunctionInfo{
        .name = "test",
        .instruction_count = 5,
        .param_count = 2,
        .has_side_effects = false,
        .is_recursive = false,
        .call_count = 1,
        .always_inline = true,
    };

    try std.testing.expect(shouldInline(&info, &config));
}

test "Inline Cost: never inline" {
    const config = InlineConfig{};
    var info = FunctionInfo{
        .name = "test",
        .instruction_count = 5,
        .param_count = 2,
        .has_side_effects = false,
        .is_recursive = false,
        .call_count = 1,
        .never_inline = true,
    };

    try std.testing.expect(!shouldInline(&info, &config));
}

test "Inline Cost: sacred threshold" {
    const config = InlineConfig{};
    const threshold: f64 = @as(f64, config.max_inline_cost) * config.sacred_threshold_factor;
    try std.testing.expectApproxEqAbs(@as(f64, 161.8033988749895), threshold, 0.001);
}

test "Inline Cost: golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}
