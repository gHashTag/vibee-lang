// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK UI V49 - Performance Comparison v48 vs v49
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// Compares: v48 (basic) vs v49 (double-buffered, dirty-checking)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ui = @import("pro_ui_design_v49.zig");

const DoubleBufferRenderer = ui.DoubleBufferRenderer;
const BoxRenderer = ui.BoxRenderer;
const ProgressBar = ui.ProgressBar;
const THEME_DRACULA = ui.THEME_DRACULA;
const PHI = ui.PHI;
const PHOENIX = ui.PHOENIX;

// ═══════════════════════════════════════════════════════════════════════════════
// NAIVE RENDERER (v48 baseline)
// ═══════════════════════════════════════════════════════════════════════════════

pub const NaiveRenderer = struct {
    width: u16,
    height: u16,

    const Self = @This();

    pub fn init(width: u16, height: u16) Self {
        return Self{ .width = width, .height = height };
    }

    /// Full redraw every frame (no dirty checking)
    pub fn render(self: *Self, writer: anytype) !void {
        // Clear screen
        try writer.writeAll("\x1b[2J\x1b[H");

        // Redraw everything
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                try writer.print("\x1b[{d};{d}H", .{ y + 1, x + 1 });
                try writer.writeAll("█");
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    size: []const u8,
    v48_time_us: f64,
    v49_time_us: f64,
    speedup: f64,
    v48_fps: f64,
    v49_fps: f64,
};

pub fn runBenchmark(allocator: std.mem.Allocator, width: u16, height: u16) !BenchmarkResult {
    const cells = @as(u32, width) * @as(u32, height);

    // v48: Naive full redraw
    var naive = NaiveRenderer.init(width, height);
    const null_writer = std.io.null_writer;

    const v48_start = std.time.nanoTimestamp();
    for (0..10) |_| {
        try naive.render(null_writer);
    }
    const v48_end = std.time.nanoTimestamp();
    const v48_time_us = @as(f64, @floatFromInt(v48_end - v48_start)) / 10000.0;

    // v49: Double-buffered with dirty checking
    var buffer = try DoubleBufferRenderer.init(allocator, width, height);
    defer buffer.deinit();

    // Initial fill
    for (0..height) |y| {
        for (0..width) |x| {
            buffer.setCell(@intCast(x), @intCast(y), .{ .char = '█' });
        }
    }

    const v49_start = std.time.nanoTimestamp();
    for (0..10) |_| {
        // Only 10% of cells change
        for (0..cells / 10) |i| {
            const x = @as(u16, @intCast(i % width));
            const y = @as(u16, @intCast((i / width) % height));
            buffer.setCell(x, y, .{ .char = 'X' });
        }
        try buffer.render(null_writer);
    }
    const v49_end = std.time.nanoTimestamp();
    const v49_time_us = @as(f64, @floatFromInt(v49_end - v49_start)) / 10000.0;

    var size_buf: [16]u8 = undefined;
    const size_str = std.fmt.bufPrint(&size_buf, "{d}x{d}", .{ width, height }) catch "?";
    _ = size_str;

    return BenchmarkResult{
        .name = "UI Render",
        .size = "80x24",
        .v48_time_us = v48_time_us,
        .v49_time_us = v49_time_us,
        .speedup = v48_time_us / v49_time_us,
        .v48_fps = 1_000_000.0 / v48_time_us,
        .v49_fps = 1_000_000.0 / v49_time_us,
    };
}

pub fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("\x1b[36m╔══════════════════════════════════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
    std.debug.print("\x1b[36m║\x1b[1m                    BENCHMARK: v48 (Naive) vs v49 (Double-Buffer)                     \x1b[0m\x1b[36m║\x1b[0m\n", .{});
    std.debug.print("\x1b[36m╠══════════════════════════════════════════════════════════════════════════════════════╣\x1b[0m\n", .{});
    std.debug.print("\x1b[36m║\x1b[90m Size     │ v48 (µs)    │ v49 (µs)    │ Speedup   │ v48 FPS    │ v49 FPS    │ Target  \x1b[0m\x1b[36m║\x1b[0m\n", .{});
    std.debug.print("\x1b[36m╠══════════╪═════════════╪═════════════╪═══════════╪════════════╪════════════╪═════════╣\x1b[0m\n", .{});

    for (results) |r| {
        const speedup_color = if (r.speedup > 5) "\x1b[32m" else if (r.speedup > 2) "\x1b[33m" else "\x1b[31m";
        const fps_ok = if (r.v49_fps >= 60) "✅" else "⚠️";

        std.debug.print("\x1b[36m║\x1b[0m {s: <8} │ {d: >10.1} │ {d: >10.1} │ {s}{d: >7.1}x\x1b[0m │ {d: >9.1} │ {d: >9.1} │ {s: <7} \x1b[36m║\x1b[0m\n", .{
            r.size,
            r.v48_time_us,
            r.v49_time_us,
            speedup_color,
            r.speedup,
            r.v48_fps,
            r.v49_fps,
            fps_ok,
        });
    }

    std.debug.print("\x1b[36m╚══════════════════════════════════════════════════════════════════════════════════════╝\x1b[0m\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HCI METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const HCIMetrics = struct {
    pub fn printMetrics() void {
        std.debug.print("\n", .{});
        std.debug.print("\x1b[36m╔══════════════════════════════════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[1m                           HCI SCIENTIFIC METRICS                                     \x1b[0m\x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m╠══════════════════════════════════════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m                                                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  \x1b[1mFitts' Law\x1b[0m (1954): T = a + b × log₂(D/W + 1)                                       \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  → Target acquisition time depends on distance and width                             \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  → Larger buttons = faster clicks                                                    \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m                                                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  \x1b[1mHick's Law\x1b[0m (1952): T = b × log₂(n + 1)                                              \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  → Choice reaction time increases with options                                       \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  → Fewer menu items = faster decisions                                               \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m                                                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  \x1b[1mMiller's Law\x1b[0m (1956): Working memory = 7 ± 2 chunks                                 \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  → Group information into 5-9 items max                                              \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m                                                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  \x1b[1mNielsen's 10 Heuristics\x1b[0m (1994):                                                    \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  1. Visibility of system status                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  2. Match between system and real world                                              \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  3. User control and freedom                                                         \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  4. Consistency and standards                                                        \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m  5. Error prevention                                                                 \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m║\x1b[0m                                                                                      \x1b[36m║\x1b[0m\n", .{});
        std.debug.print("\x1b[36m╚══════════════════════════════════════════════════════════════════════════════════════╝\x1b[0m\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Benchmark: 80x24" {
    const allocator = std.testing.allocator;
    var result = try runBenchmark(allocator, 80, 24);
    result.size = "80x24";

    try std.testing.expect(result.speedup > 1.0);

    printResults(&[_]BenchmarkResult{result});
    HCIMetrics.printMetrics();
}

test "Benchmark: comparison table" {
    const allocator = std.testing.allocator;

    var results: [3]BenchmarkResult = undefined;
    results[0] = try runBenchmark(allocator, 80, 24);
    results[0].size = "80x24";
    results[1] = try runBenchmark(allocator, 120, 40);
    results[1].size = "120x40";
    results[2] = try runBenchmark(allocator, 200, 60);
    results[2].size = "200x60";

    printResults(&results);

    // v49 should be faster
    try std.testing.expect(results[0].speedup > 1.0);
}

test "Golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// ═══════════════════════════════════════════════════════════════════════════════
