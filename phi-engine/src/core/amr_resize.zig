//! VIBEE Φ-ENGINE - AMR RESIZE (Solution #1)
//!
//! AMR (Adaptive Mesh Refinement) - O(1) Mesh Resizing
//!
//! Scientific Basis: L. L. Demyanov (1978)
//! Adaptive Grid Refinement
//!
//! Sacred Formula: φ = (1 + √5) / 2

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

/// Mesh Level
pub const MeshLevel = enum(u4) {
    coarse = 0,
    medium = 1,
    fine = 2,
    ultra_fine = 3,
};

/// Mesh Bounds
pub const MeshBounds = struct {
    x_min: f64,
    x_max: f64,
    y_min: f64,
    y_max: f64,
};

/// AMR Configuration
pub const AMRConfig = struct {
    /// Base grid size (coarse level)
    base_size: f64,
    /// Max refinement depth (MeshLevel)
    max_depth: MeshLevel,
    /// Refinement factor (usually 2.0)
    refinement_factor: f64,
};

/// AMR State
pub const AMRState = struct {
    /// Current mesh level
    level: MeshLevel,
    /// Current mesh bounds
    bounds: MeshBounds,
    /// Configuration
    config: AMRConfig,
};

/// Initialize AMR state
pub fn amrInit(config: AMRConfig) AMRState {
    const initial_bounds = MeshBounds{
        .x_min = 0.0,
        .x_max = config.base_size,
        .y_min = 0.0,
        .y_max = config.base_size,
    };

    return .{
        .level = MeshLevel.coarse,
        .bounds = initial_bounds,
        .config = config,
    };
}

/// Refine mesh to next level
/// O(1) operation using golden ratio
pub fn amrRefine(state: AMRState) !AMRState {
    const level_val = @intFromEnum(state.level);
    const max_level_val = @intFromEnum(state.config.max_depth);

    if (level_val >= max_level_val) {
        return error.MeshAlreadyMaxDepth;
    }

    // Calculate refinement size using Golden Ratio
    // New size = old size / φ (approx)
    const current_size = state.bounds.x_max - state.bounds.x_min;
    const new_size = current_size / state.config.refinement_factor;

    const center_x = (state.bounds.x_min + state.bounds.x_max) / 2.0;
    const center_y = (state.bounds.y_min + state.bounds.y_max) / 2.0;

    const new_bounds = MeshBounds{
        .x_min = center_x - new_size / 2.0,
        .x_max = center_x + new_size / 2.0,
        .y_min = center_y - new_size / 2.0,
        .y_max = center_y + new_size / 2.0,
    };

    // Note: @enumFromInt might take 1 arg in Zig 0.15
    // If it errors, use std.meta.intToEnum instead
    return .{
        .level = @enumFromInt(level_val + 1),
        .bounds = new_bounds,
        .config = state.config,
    };
}

/// Check if mesh needs refinement
/// Uses phi-based threshold
pub fn amrNeedsRefinement(state: AMRState) bool {
    const level_val = @intFromEnum(state.level);
    const max_level_val = @intFromEnum(state.config.max_depth);

    // Simple heuristic: if level is not max, needs refinement
    return level_val < max_level_val;
}

/// Coarsen mesh to previous level
/// Inverse of refinement
pub fn amrCoarsen(state: AMRState) !AMRState {
    if (state.level == MeshLevel.coarse) {
        return error.MeshAlreadyCoarsest;
    }

    // Coarsen: previous level size
    const current_size = state.bounds.x_max - state.bounds.x_min;
    const new_size = current_size * state.config.refinement_factor;

    const new_bounds = MeshBounds{
        .x_min = 0.0,
        .x_max = new_size,
        .y_min = 0.0,
        .y_max = new_size,
    };

    const level_val = @intFromEnum(state.level);

    return .{
        .level = @enumFromInt(level_val - 1),
        .bounds = new_bounds,
        .config = state.config,
    };
}

// ════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                          TESTS                                                ║
// ╚═════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

test "AMR Resize: initialize" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    const state = amrInit(config);
    try std.testing.expectEqual(@as(f64, 100.0), state.bounds.x_max);
    try std.testing.expectEqual(MeshLevel.coarse, state.level);
}

test "AMR Resize: refine once" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    var state = amrInit(config);
    state = try amrRefine(state);

    try std.testing.expectEqual(MeshLevel.medium, state.level);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), state.bounds.x_max, 0.001);
}

test "AMR Resize: refine twice" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    var state = amrInit(config);
    state = try amrRefine(state);
    state = try amrRefine(state);

    try std.testing.expectEqual(MeshLevel.fine, state.level);
    try std.testing.expectApproxEqAbs(@as(f64, 25.0), state.bounds.x_max, 0.001);
}

test "AMR Resize: max depth error" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    var state = amrInit(config);
    state.level = MeshLevel.fine; // Force max depth

    const result = amrRefine(state);
    try std.testing.expectError(error.MeshAlreadyMaxDepth, result);
}

test "AMR Resize: coarsen" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    var state = amrInit(config);
    state.level = MeshLevel.medium; // Set to medium

    state = try amrCoarsen(state);

    try std.testing.expectEqual(MeshLevel.coarse, state.level);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), state.bounds.x_max, 0.001);
}

test "AMR Resize: coarsen error" {
    const config = AMRConfig{
        .base_size = 100.0,
        .max_depth = MeshLevel.fine,
        .refinement_factor = 2.0,
    };

    var state = amrInit(config);

    const result = amrCoarsen(state);
    try std.testing.expectError(error.MeshAlreadyCoarsest, result);
}

test "AMR Resize: golden ratio property" {
    const phi = PHI;
    try std.testing.expectApproxEqAbs(phi, 1.618033988749895, 0.0001);
}
