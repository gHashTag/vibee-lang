//! VIBEE ML - Zig Reference Implementation
//! =========================================
//!
//! High-performance implementations of LLM training and inference primitives.
//!
//! Modules:
//!   - core: Base types and sacred constants
//!   - attention: Flash Attention implementation
//!   - optimizers: Lion, AdamW optimizers
//!   - quantization: INT8/INT4 quantization
//!   - utils: Utility functions

const std = @import("std");

pub const core = @import("core.zig");
pub const attention = @import("attention.zig");
pub const optimizers = @import("optimizers.zig");
pub const quantization = @import("quantization.zig");

// Re-export sacred constants
pub const PHI = core.PHI;
pub const PHI_SQUARED = core.PHI_SQUARED;
pub const GOLDEN_IDENTITY = core.GOLDEN_IDENTITY;
pub const PHOENIX = core.PHOENIX;

test "all tests" {
    std.testing.refAllDecls(@This());
    _ = core;
    _ = attention;
    _ = optimizers;
    _ = quantization;
}
