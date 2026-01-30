const std = @import("std");
const spec_validator = @import("spec_validator.zig");

pub fn main() !void {
    // Test 1: Spec without output key (should fail)
    {
        std.debug.print("Test 1: Spec WITHOUT output key...\n", .{});
        const result = try spec_validator.validateSpecFile(std.heap.page_allocator, "/tmp/test_valid.vibee");

        if (result.hasErrors()) {
            std.debug.print("  ❌ Correctly rejected (missing output:)\n", .{});
            for (result.errors.items) |err| {
                std.debug.print("     Error: {s}\n", .{err.message});
            }
        } else {
            std.debug.print("  ✅ Should have failed!\n", .{});
        }
    }

    // Test 2: Spec with output key (should pass)
    {
        std.debug.print("\nTest 2: Spec WITH output key...\n", .{});
        const result = try spec_validator.validateSpecFile(std.heap.page_allocator, "/tmp/test_valid_with_output.vibee");

        if (result.hasErrors()) {
            std.debug.print("  ❌ Should have passed!\n", .{});
            for (result.errors.items) |err| {
                std.debug.print("     Error: {s}\n", .{err.message});
            }
        } else {
            std.debug.print("  ✅ Correctly accepted\n", .{});
        }
    }

    std.debug.print("\n✅ Validator test complete!\n", .{});
}
