// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE SPEC VALIDATOR - Standalone Binary
// φ² + 1/φ² = 3 | GOLDEN KEY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const validator = @import("validate_cmd.zig");

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    return validator.runValidation(args);
}
