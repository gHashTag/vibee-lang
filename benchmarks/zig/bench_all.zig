const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK IMPLEMENTATIONS (identical to VIBEE)
// ═══════════════════════════════════════════════════════════════════════════════

fn fibIter(n: i64) i64 {
    if (n < 2) return n;
    var a: i64 = 0;
    var b: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        const t = a + b;
        a = b;
        b = t;
        std.mem.doNotOptimizeAway(&b);
    }
    return b;
}

fn factorial(n: i64) i64 {
    var result: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
        std.mem.doNotOptimizeAway(&result);
    }
    return result;
}

fn sumTo(n: i64) i64 {
    var total: i64 = 0;
    var i: i64 = 1;
    while (i <= n) : (i += 1) {
        total += i;
        std.mem.doNotOptimizeAway(&total);
    }
    return total;
}

fn isPrime(n: i64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (@mod(n, 2) == 0) return false;
    var i: i64 = 3;
    while (i * i <= n) : (i += 2) {
        if (@mod(n, i) == 0) return false;
    }
    return true;
}

fn countPrimes(limit: i64) i64 {
    var count: i64 = 0;
    var n: i64 = 2;
    while (n <= limit) : (n += 1) {
        if (isPrime(n)) count += 1;
    }
    return count;
}

fn ternarySum(n: i64) i64 {
    var total: i8 = 0;
    var i: i64 = 0;
    while (i < n) : (i += 1) {
        const t: i8 = @intCast(@mod(@mod(i, 27) + 13, 27) - 13);
        var sum: i16 = @as(i16, total) + @as(i16, t);
        while (sum > 13) sum -= 27;
        while (sum < -13) sum += 27;
        total = @intCast(sum);
    }
    return @as(i64, total);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

fn benchmark(comptime name: []const u8, comptime func: anytype, arg: i64, iterations: u32) void {
    // Warmup
    var warmup: u32 = 0;
    var sink: i64 = 0;
    while (warmup < 10) : (warmup += 1) {
        sink +%= func(arg);
    }
    std.mem.doNotOptimizeAway(&sink);

    // Measure
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    var result: i64 = 0;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        result = func(arg);
        std.mem.doNotOptimizeAway(&result);
        const end = std.time.nanoTimestamp();
        const elapsed: u64 = @intCast(@max(0, end - start));
        total_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const min_us = @as(f64, @floatFromInt(min_ns)) / 1000.0;
    const max_us = @as(f64, @floatFromInt(max_ns)) / 1000.0;

    std.debug.print("{s:<20} {d:>12.3} µs  (min: {d:.3}, max: {d:.3})  result: {d}\n", .{
        name, avg_us, min_us, max_us, result
    });
}

// Runtime values to prevent compile-time evaluation
var runtime_30: i64 = 30;
var runtime_20: i64 = 20;
var runtime_10000: i64 = 10000;
var runtime_1000: i64 = 1000;

pub fn main() !void {
    const iterations: u32 = 10000;

    // Touch runtime values
    std.mem.doNotOptimizeAway(&runtime_30);
    std.mem.doNotOptimizeAway(&runtime_20);
    std.mem.doNotOptimizeAway(&runtime_10000);
    std.mem.doNotOptimizeAway(&runtime_1000);

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                    ZIG NATIVE BENCHMARK\n", .{});
    std.debug.print("                    (Release mode, {d} iterations)\n", .{iterations});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{s:<20} {s:>15}  {s}\n", .{"Benchmark", "Avg time", "Result"});
    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});

    benchmark("fib(30)", fibIter, runtime_30, iterations);
    benchmark("factorial(20)", factorial, runtime_20, iterations);
    benchmark("sum(10000)", sumTo, runtime_10000, iterations);
    benchmark("primes(1000)", countPrimes, runtime_1000, iterations);
    benchmark("ternary(1000)", ternarySum, runtime_1000, iterations);

    std.debug.print("───────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("\n", .{});
}
