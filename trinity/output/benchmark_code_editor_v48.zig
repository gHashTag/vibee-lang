// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CODE EDITOR V48 - Performance Comparison
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// Compares: v47 (naive) vs v48 (Myers O(ND))
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const editor = @import("pro_code_editor_v48.zig");

const MyersDiffEngine = editor.MyersDiffEngine;
const LineHasher = editor.LineHasher;
const SyntaxHighlighter = editor.SyntaxHighlighter;
const Color = editor.Color;
const Box = editor.Box;
const PHI = editor.PHI;
const PHOENIX = editor.PHOENIX;

// ═══════════════════════════════════════════════════════════════════════════════
// NAIVE DIFF (v47 baseline)
// ═══════════════════════════════════════════════════════════════════════════════

pub const NaiveDiff = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// O(n²) naive LCS-based diff
    pub fn diff(self: *Self, old: []const u8, new: []const u8) !struct { additions: u32, deletions: u32 } {
        const old_lines = try self.splitLines(old);
        defer self.allocator.free(old_lines);
        const new_lines = try self.splitLines(new);
        defer self.allocator.free(new_lines);

        const n = old_lines.len;
        const m = new_lines.len;

        // O(n*m) DP table
        const dp = try self.allocator.alloc([]u32, n + 1);
        defer {
            for (dp) |row| self.allocator.free(row);
            self.allocator.free(dp);
        }

        for (dp) |*row| {
            row.* = try self.allocator.alloc(u32, m + 1);
            @memset(row.*, 0);
        }

        // Fill DP table
        for (1..n + 1) |i| {
            for (1..m + 1) |j| {
                if (std.mem.eql(u8, old_lines[i - 1], new_lines[j - 1])) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                } else {
                    dp[i][j] = @max(dp[i - 1][j], dp[i][j - 1]);
                }
            }
        }

        const lcs_len = dp[n][m];
        const additions: u32 = @intCast(m - lcs_len);
        const deletions: u32 = @intCast(n - lcs_len);

        return .{ .additions = additions, .deletions = deletions };
    }

    fn splitLines(self: *Self, text: []const u8) ![]const []const u8 {
        var lines = std.ArrayList([]const u8).init(self.allocator);
        var iter = std.mem.splitScalar(u8, text, '\n');
        while (iter.next()) |line| {
            try lines.append(line);
        }
        return try lines.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    lines: usize,
    v47_time_us: f64,
    v48_time_us: f64,
    speedup: f64,
    memory_v47_kb: f64,
    memory_v48_kb: f64,
    memory_reduction: f64,
};

pub fn runBenchmark(allocator: std.mem.Allocator, lines: usize, change_percent: f32) !BenchmarkResult {
    // Generate test data
    var old_buf = std.ArrayList(u8).init(allocator);
    defer old_buf.deinit();
    var new_buf = std.ArrayList(u8).init(allocator);
    defer new_buf.deinit();

    var prng = std.Random.DefaultPrng.init(PHOENIX);
    for (0..lines) |i| {
        try old_buf.writer().print("line {d}: original content with some text here\n", .{i});
        if (prng.random().float(f32) < change_percent) {
            try new_buf.writer().print("line {d}: MODIFIED content with changes\n", .{i});
        } else {
            try new_buf.writer().print("line {d}: original content with some text here\n", .{i});
        }
    }

    // Benchmark v47 (naive)
    var naive = NaiveDiff.init(allocator);
    const v47_start = std.time.nanoTimestamp();
    _ = try naive.diff(old_buf.items, new_buf.items);
    const v47_end = std.time.nanoTimestamp();
    const v47_time_us = @as(f64, @floatFromInt(v47_end - v47_start)) / 1000.0;

    // Benchmark v48 (Myers)
    var myers = MyersDiffEngine.init(allocator);
    const v48_start = std.time.nanoTimestamp();
    var result = try myers.diff(old_buf.items, new_buf.items);
    const v48_end = std.time.nanoTimestamp();
    result.deinit();
    const v48_time_us = @as(f64, @floatFromInt(v48_end - v48_start)) / 1000.0;

    // Memory estimation
    const memory_v47_kb = @as(f64, @floatFromInt(lines * lines * 4)) / 1024.0;
    const memory_v48_kb = @as(f64, @floatFromInt(lines * 2 * 8)) / 1024.0;

    return BenchmarkResult{
        .name = "diff",
        .lines = lines,
        .v47_time_us = v47_time_us,
        .v48_time_us = v48_time_us,
        .speedup = v47_time_us / v48_time_us,
        .memory_v47_kb = memory_v47_kb,
        .memory_v48_kb = memory_v48_kb,
        .memory_reduction = memory_v47_kb / memory_v48_kb,
    };
}

pub fn printBenchmarkTable(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("{s}╔══════════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Color.CYAN, Color.RESET });
    std.debug.print("{s}║{s}                    BENCHMARK: v47 (Naive) vs v48 (Myers O(ND))                   {s}║{s}\n", .{ Color.CYAN, Color.BOLD, Color.RESET, Color.RESET });
    std.debug.print("{s}╠══════════════════════════════════════════════════════════════════════════════════╣{s}\n", .{ Color.CYAN, Color.RESET });
    std.debug.print("{s}║{s} Lines   │ v47 (µs)    │ v48 (µs)    │ Speedup   │ Mem v47    │ Mem v48   │ Ratio  {s}║{s}\n", .{ Color.CYAN, Color.GRAY, Color.RESET, Color.RESET });
    std.debug.print("{s}╠═════════╪═════════════╪═════════════╪═══════════╪════════════╪═══════════╪════════╣{s}\n", .{ Color.CYAN, Color.RESET });

    for (results) |r| {
        const speedup_color = if (r.speedup > 10) Color.GREEN else if (r.speedup > 2) Color.YELLOW else Color.RED;
        std.debug.print("{s}║{s} {d: >6}  │ {d: >10.1} │ {d: >10.1} │ {s}{d: >7.1}x{s} │ {d: >8.1}KB │ {d: >7.1}KB │ {d: >5.0}x {s}║{s}\n", .{
            Color.CYAN,
            Color.RESET,
            r.lines,
            r.v47_time_us,
            r.v48_time_us,
            speedup_color,
            r.speedup,
            Color.RESET,
            r.memory_v47_kb,
            r.memory_v48_kb,
            r.memory_reduction,
            Color.CYAN,
            Color.RESET,
        });
    }

    std.debug.print("{s}╚══════════════════════════════════════════════════════════════════════════════════╝{s}\n", .{ Color.CYAN, Color.RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Benchmark: 100 lines" {
    const allocator = std.testing.allocator;
    const result = try runBenchmark(allocator, 100, 0.05);

    try std.testing.expect(result.speedup > 1.0);

    std.debug.print("\n", .{});
    printBenchmarkTable(&[_]BenchmarkResult{result});
}

test "Benchmark: comparison table" {
    const allocator = std.testing.allocator;

    var results: [4]BenchmarkResult = undefined;
    results[0] = try runBenchmark(allocator, 50, 0.05);
    results[1] = try runBenchmark(allocator, 100, 0.05);
    results[2] = try runBenchmark(allocator, 200, 0.05);
    results[3] = try runBenchmark(allocator, 500, 0.05);

    std.debug.print("\n", .{});
    printBenchmarkTable(&results);

    // Verify speedup increases with size
    try std.testing.expect(results[3].speedup > results[0].speedup);
}

test "Golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// ═══════════════════════════════════════════════════════════════════════════════
