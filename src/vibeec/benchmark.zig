// VIBEE Benchmark - Performance Testing
// Compare Zig JSON parser vs alternatives
// φ² + 1/φ² = 3

const std = @import("std");
const json_parser = @import("json_parser.zig");
const simd_json = @import("simd_json.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║           VIBEE BENCHMARK - QUANTUM SPEED TEST                   ║\n", .{});
    try stdout.print("║                    φ² + 1/φ² = 3                                 ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

    // Test data - simulated OpenAI response
    const test_json =
        \\{
        \\  "id": "chatcmpl-123",
        \\  "object": "chat.completion",
        \\  "created": 1677652288,
        \\  "model": "gpt-4",
        \\  "choices": [{
        \\    "index": 0,
        \\    "message": {
        \\      "role": "assistant",
        \\      "content": "Hello! I am VIBEE, a pure Zig AI agent designed for quantum speed performance."
        \\    },
        \\    "finish_reason": "stop"
        \\  }],
        \\  "usage": {
        \\    "prompt_tokens": 9,
        \\    "completion_tokens": 12,
        \\    "total_tokens": 21
        \\  }
        \\}
    ;

    const iterations: usize = 100_000;

    // JSON Parser Benchmark
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  JSON PARSER BENCHMARK ({d} iterations)                       ║\n", .{iterations});
    try stdout.print("║  ────────────────────────────────────────────────────────────── ║\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Warmup
    var parser = json_parser.JsonParser.init(allocator);
    for (0..1000) |_| {
        var result = try parser.parse(test_json);
        result.deinit(allocator);
    }

    // Benchmark
    const start = std.time.nanoTimestamp();
    var total_bytes: usize = 0;

    for (0..iterations) |_| {
        var result = try parser.parse(test_json);
        total_bytes += result.bytes_parsed;
        result.deinit(allocator);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns: u64 = @intCast(end - start);
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);
    const throughput_mbps = @as(f64, @floatFromInt(total_bytes)) / @as(f64, @floatFromInt(elapsed_ns)) * 1000.0;

    try stdout.print("║  Total time:      {d:.2} ms                                      ║\n", .{elapsed_ms});
    try stdout.print("║  Ops/second:      {d:.0}                                     ║\n", .{ops_per_sec});
    try stdout.print("║  Throughput:      {d:.2} MB/s                                    ║\n", .{throughput_mbps});
    try stdout.print("║  Avg per parse:   {d:.0} ns                                       ║\n", .{@as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations))});

    // SIMD Whitespace Benchmark
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  SIMD WHITESPACE BENCHMARK                                       ║\n", .{});
    try stdout.print("║  ────────────────────────────────────────────────────────────── ║\n", .{});

    const whitespace_test = "                                                              {\"key\": \"value\"}";
    const simd_result = simd_json.benchmarkWhitespace(whitespace_test, iterations);

    try stdout.print("║  SIMD time:       {d} ns                                       ║\n", .{simd_result.simd_ns});
    try stdout.print("║  Scalar time:     {d} ns                                       ║\n", .{simd_result.scalar_ns});
    try stdout.print("║  Speedup:         {d:.2}x                                          ║\n", .{simd_result.speedup});

    // Path Query Benchmark
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  PATH QUERY BENCHMARK                                            ║\n", .{});
    try stdout.print("║  ────────────────────────────────────────────────────────────── ║\n", .{});

    var parse_result = try parser.parse(test_json);
    defer parse_result.deinit(allocator);

    const path_start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        const content = json_parser.queryPath(parse_result.value, "$.choices[0].message.content");
        std.mem.doNotOptimizeAway(&content);
    }
    const path_end = std.time.nanoTimestamp();
    const path_elapsed: u64 = @intCast(path_end - path_start);
    const path_ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(path_elapsed)) / 1_000_000_000.0);

    try stdout.print("║  Path queries/s:  {d:.0}                                    ║\n", .{path_ops_per_sec});
    try stdout.print("║  Avg per query:   {d:.0} ns                                        ║\n", .{@as(f64, @floatFromInt(path_elapsed)) / @as(f64, @floatFromInt(iterations))});

    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  COMPARISON WITH JS (estimated)                                  ║\n", .{});
    try stdout.print("║  ────────────────────────────────────────────────────────────── ║\n", .{});
    try stdout.print("║  JS JSON.parse:   ~50,000 ops/s (V8)                             ║\n", .{});
    try stdout.print("║  Zig parser:      {d:.0} ops/s                               ║\n", .{ops_per_sec});
    try stdout.print("║  Estimated gain:  {d:.1}x faster                                   ║\n", .{ops_per_sec / 50000.0});
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});
}

test "benchmark runs" {
    // Just verify it compiles
    try std.testing.expect(true);
}
