// VIBEE BOGATYR - Common types and interfaces
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");

pub const BogatyrVerdict = enum {
    Pass,
    Fail,
    Warning,
    Skip,
};

pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    severity: BogatyrVerdict,
    line: usize,
    column: usize,
};

pub const BogatyrMetrics = struct {
    duration_ns: i64,
    checks_performed: usize,
};

pub const BogatyrPlugin = struct {
    name: []const u8,
    version: []const u8,
    category: []const u8,
    priority: u32,
    validate: *const fn (*const ValidationContext) anyerror!BogatyrResult,
};

pub const BogatyrResult = struct {
    verdict: BogatyrVerdict,
    errors: []const ValidationError,
    metrics: BogatyrMetrics,
};

pub const ValidationContext = struct {
    allocator: std.mem.Allocator,
    spec_path: []const u8,
    source: []const u8,
    config: ValidatorConfig,
    ast: ?*const anyopaque,
    symbol_table: ?*const anyopaque,
};

pub const ValidatorConfig = struct {
    strict_mode: bool = false,
    warning_as_error: bool = false,
    cache_enabled: bool = true,
    parallel_enabled: bool = true,
    timeout_ms: u32 = 30000,
};

pub fn createError(allocator: std.mem.Allocator, code: []const u8, message: []const u8, line: usize, column: usize) !ValidationError {
    return ValidationError{
        .code = try allocator.dupe(u8, code),
        .message = try allocator.dupe(u8, message),
        .severity = .Fail,
        .line = line,
        .column = column,
    };
}
