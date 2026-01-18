// ═══════════════════════════════════════════════════════════════════════════════
// REAL BENCHMARK - TRI PARSER PERFORMANCE
// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// NO FAKE NUMBERS - REAL MEASUREMENTS ONLY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_parser = @import("tri_parser.zig");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// Prevent compiler from optimizing away results
fn doNotOptimize(ptr: anytype) void {
    const T = @TypeOf(ptr);
    const addr = @intFromPtr(ptr);
    _ = @as(*volatile T, @ptrFromInt(addr)).*;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try stdout.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════════════════════╗
        \\║  REAL BENCHMARK - TRI PARSER PERFORMANCE                                      ║
        \\╠═══════════════════════════════════════════════════════════════════════════════╣
        \\║  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q                                ║
        \\║  Golden Identity: φ² + 1/φ² = 3                                               ║
        \\║  NO FAKE NUMBERS - REAL MEASUREMENTS ONLY                                     ║
        \\╚═══════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Generate test data of various sizes
    const sizes = [_]usize{ 1024, 10 * 1024, 100 * 1024 };
    const size_names = [_][]const u8{ "1KB", "10KB", "100KB" };

    for (sizes, size_names) |target_size, size_name| {
        // Generate test data
        var test_data = std.ArrayList(u8).init(gpa.allocator());
        defer test_data.deinit();

        const template =
            \\name: "test_document"
            \\version: "1.0.0"
            \\config: {host: "localhost", port: 8080}
            \\items: [1, 2, 3, 4, 5]
            \\
        ;

        while (test_data.items.len < target_size) {
            try test_data.appendSlice(template);
        }

        const input = test_data.items;
        const actual_size = input.len;

        // Warmup
        {
            var arena = std.heap.ArenaAllocator.init(gpa.allocator());
            defer arena.deinit();
            var parser = tri_parser.Parser.init(arena.allocator(), input);
            const doc = parser.parse() catch unreachable;
            doNotOptimize(&doc);
        }

        // Benchmark
        const iterations: u32 = if (target_size < 10000) 10000 else if (target_size < 100000) 1000 else 100;

        var total_ns: u64 = 0;
        var total_entries: usize = 0;

        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            var arena = std.heap.ArenaAllocator.init(gpa.allocator());
            defer arena.deinit();

            const start = std.time.nanoTimestamp();
            var parser = tri_parser.Parser.init(arena.allocator(), input);
            const doc = parser.parse() catch continue;
            const end = std.time.nanoTimestamp();

            doNotOptimize(&doc);
            total_ns += @intCast(end - start);
            total_entries += doc.root.entries.items.len;
        }

        const avg_ns = total_ns / iterations;
        const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
        const mb_per_sec = @as(f64, @floatFromInt(actual_size)) / @as(f64, @floatFromInt(avg_ns)) * 1000.0;

        try stdout.print(
            \\
            \\  [{s}] Size: {d} bytes, Iterations: {d}
            \\    Avg time: {d:.2} µs
            \\    Speed: {d:.2} MB/s
            \\    Entries parsed: {d}
            \\
        , .{ size_name, actual_size, iterations, avg_us, mb_per_sec, total_entries / iterations });
    }

    // Compare with industry standards
    try stdout.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════════════════════╗
        \\║  COMPARISON WITH INDUSTRY STANDARDS                                           ║
        \\╠═══════════════════════════════════════════════════════════════════════════════╣
        \\║                                                                               ║
        \\║  PARSER              SPEED (MB/s)    NOTES                                    ║
        \\║  ─────────────────────────────────────────────────────────────────────────────║
        \\║  simdjson            ~4000           JSON, SIMD-optimized                     ║
        \\║  rapidjson           ~500            JSON, C++                                ║
        \\║  serde_yaml (Rust)   ~150            YAML, Rust                               ║
        \\║  libyaml             ~100            YAML, C                                  ║
        \\║  PyYAML              ~10             YAML, Python                             ║
        \\║  ─────────────────────────────────────────────────────────────────────────────║
        \\║  TRI Parser (Zig)    SEE ABOVE       .tri format, zero-copy                   ║
        \\║  TRI Parser (Python) ~1.77           .tri format, pure Python                 ║
        \\║                                                                               ║
        \\╚═══════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Golden Identity verification
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const golden_result = phi_sq + inv_phi_sq;
    const golden_verified = @abs(golden_result - GOLDEN_IDENTITY) < 0.0001;

    try stdout.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════════════════════╗
        \\║  GOLDEN IDENTITY: φ² + 1/φ² = {d:.10} ≈ 3.0  {s}                        ║
        \\╚═══════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{ golden_result, if (golden_verified) "✓" else "✗" });
}

test "benchmark_correctness" {
    const allocator = std.testing.allocator;
    const input = "name: \"test\"\nversion: \"1.0\"";

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var parser = tri_parser.Parser.init(arena.allocator(), input);
    const doc = try parser.parse();

    try std.testing.expectEqual(@as(usize, 2), doc.root.entries.items.len);
}
