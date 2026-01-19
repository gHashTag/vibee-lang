// benchmark.zig - Performance Benchmarks for Crush Modules
// Generated from: VIBEE Transpilation Pipeline
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const ansiext = @import("ansiext.zig");
const stringext = @import("stringext.zig");
const home = @import("home.zig");
const filepathext = @import("filepathext.zig");
const version = @import("version.zig");
const diff = @import("diff.zig");
const csync = @import("csync.zig");

const ITERATIONS = 10000;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║           CRUSH ZIG BENCHMARK RESULTS                         ║\n", .{});
    try stdout.print("║           Iterations: {d}                                   ║\n", .{ITERATIONS});
    try stdout.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});

    // Benchmark ansiext.escape
    {
        const input = "Hello\x00World\x01Test\x02Data\x7f";
        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |_| {
            const result = try ansiext.escape(allocator, input);
            allocator.free(result);
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / ITERATIONS;
        try stdout.print("║  ansiext.escape:        {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark stringext.capitalize
    {
        const input = "hello world this is a test string";
        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |_| {
            const result = try stringext.capitalize(allocator, input);
            allocator.free(result);
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / ITERATIONS;
        try stdout.print("║  stringext.capitalize:  {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark stringext.containsAny
    {
        const input = "hello world this is a test string for searching";
        const patterns = [_][]const u8{ "foo", "bar", "test", "baz" };
        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |_| {
            _ = stringext.containsAny(input, &patterns);
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / ITERATIONS;
        try stdout.print("║  stringext.containsAny: {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark home.short
    {
        if (home.dir()) |homedir| {
            var path_buf: [512]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buf, "{s}/documents/projects/test.txt", .{homedir});

            var timer = try std.time.Timer.start();

            for (0..ITERATIONS) |_| {
                const result = try home.short(allocator, path);
                allocator.free(result);
            }

            const elapsed = timer.read();
            const ns_per_op = elapsed / ITERATIONS;
            try stdout.print("║  home.short:            {d:>8} ns/op                       ║\n", .{ns_per_op});
        }
    }

    // Benchmark filepathext.smartIsAbs
    {
        const paths = [_][]const u8{
            "/absolute/path/to/file.txt",
            "relative/path/to/file.txt",
            "/another/absolute/path",
            "another/relative/path",
        };

        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |_| {
            for (paths) |p| {
                _ = filepathext.smartIsAbs(p);
            }
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / (ITERATIONS * paths.len);
        try stdout.print("║  filepathext.smartIsAbs:{d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark version.parseSemVer
    {
        const versions = [_][]const u8{
            "1.2.3",
            "v2.0.0-beta.1",
            "10.20.30+build.123",
            "0.0.1-alpha",
        };

        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |_| {
            for (versions) |v| {
                _ = version.parseSemVer(v) catch {};
            }
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / (ITERATIONS * versions.len);
        try stdout.print("║  version.parseSemVer:   {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark diff.generateDiff (small)
    {
        const before = "line1\nline2\nline3";
        const after = "line1\nmodified\nline3\nline4";

        var timer = try std.time.Timer.start();

        for (0..ITERATIONS / 10) |_| {
            const result = try diff.generateDiff(allocator, before, after, "test.txt");
            if (result.unified.len > 0) allocator.free(result.unified);
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / (ITERATIONS / 10);
        try stdout.print("║  diff.generateDiff:     {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark csync.Map operations
    {
        var map = csync.Map(u32, u32).init(allocator);
        defer map.deinit();

        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |i| {
            try map.set(@intCast(i % 100), @intCast(i));
            _ = map.get(@intCast(i % 100));
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / (ITERATIONS * 2);
        try stdout.print("║  csync.Map set/get:     {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    // Benchmark csync.Slice operations
    {
        var slice = csync.Slice(u32).init(allocator);
        defer slice.deinit();

        var timer = try std.time.Timer.start();

        for (0..ITERATIONS) |i| {
            try slice.append(@intCast(i % 1000));
        }

        const elapsed = timer.read();
        const ns_per_op = elapsed / ITERATIONS;
        try stdout.print("║  csync.Slice append:    {d:>8} ns/op                       ║\n", .{ns_per_op});
    }

    try stdout.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║                                                               ║\n", .{});
    try stdout.print("║  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q                ║\n", .{});
    try stdout.print("║  Golden Identity: φ² + 1/φ² = 3                               ║\n", .{});
    try stdout.print("║  PHOENIX = 999                                                ║\n", .{});
    try stdout.print("║                                                               ║\n", .{});
    try stdout.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
}

// Test that benchmark compiles
test "benchmark_compiles" {
    // Just verify the benchmark code compiles
    try std.testing.expect(true);
}
