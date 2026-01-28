// VIBEE Real E2E Test - Chrome CDP Connection
// Test using existing WebSocket + CDP clients
// φ² + 1/φ² = 3

const std = @import("std");
const cdp_client = @import("cdp_client.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== REAL E2E TEST - Chrome CDP ===\n", .{});

    // Step 1: Discover Chrome CDP targets
    std.debug.print("Step 1: Discovering Chrome CDP targets...\n", .{});

    var client = try cdp_client.CDPClient.init(allocator, "localhost", 9223);
    defer client.deinit();

    const targets = try client.discoverTargets();
    defer allocator.free(targets);

    std.debug.print("Found {d} CDP targets:\n", .{targets.len});
    for (targets) |t| {
        std.debug.print("  - [{s}] {s} - {s}\n", .{ t.target_type, t.id, t.title });
    }

    std.debug.print("\n✅ SUCCESS: Real CDP connection works!\n", .{});
    std.debug.print("Chrome is ready for DevTools commands!\n", .{});

    std.debug.print("\n=== REAL E2E TEST COMPLETE ===\n", .{});
}
