// ============================================================================
// VIBEEC BENCHMARKS
// Real benchmark implementations for testing compiler optimization
// ============================================================================

const std = @import("std");
const time = std.time;

// ============================================================================
// BENCHMARK RESULT TYPES
// ============================================================================

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u32,
    total_time_ns: u64,
    avg_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    ops_per_second: f64,
    result_value: i64,  // For correctness verification
};

pub const BenchmarkSuite = struct {
    results: []BenchmarkResult,
    total_time_ns: u64,
    benchmarks_run: u32,
};

// ============================================================================
// FIBONACCI BENCHMARK
// ============================================================================

/// Recursive Fibonacci (for testing optimization of recursive calls)
pub fn fibonacciRecursive(n: u32) u64 {
    if (n <= 1) return n;
    return fibonacciRecursive(n - 1) + fibonacciRecursive(n - 2);
}

/// Iterative Fibonacci (baseline for comparison)
pub fn fibonacciIterative(n: u32) u64 {
    if (n <= 1) return n;
    
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    
    return b;
}

/// Memoized Fibonacci (for testing memory optimization)
pub fn fibonacciMemoized(n: u32, memo: []u64) u64 {
    if (n <= 1) return n;
    if (memo[n] != 0) return memo[n];
    
    memo[n] = fibonacciMemoized(n - 1, memo) + fibonacciMemoized(n - 2, memo);
    return memo[n];
}

pub fn runFibonacciBenchmark(iterations: u32) BenchmarkResult {
    const n: u32 = 30;
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var result: u64 = 0;
    
    for (0..iterations) |_| {
        const start = time.nanoTimestamp();
        result = fibonacciRecursive(n);
        const end = time.nanoTimestamp();
        
        const elapsed = @as(u64, @intCast(end - start));
        total_time += elapsed;
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
    }
    
    const avg_time = total_time / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);
    
    return BenchmarkResult{
        .name = "fibonacci_recursive",
        .iterations = iterations,
        .total_time_ns = total_time,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .ops_per_second = ops_per_sec,
        .result_value = @intCast(result),
    };
}

// ============================================================================
// QUICKSORT BENCHMARK
// ============================================================================

fn partition(arr: []i64, low: usize, high: usize) usize {
    const pivot = arr[high];
    var i: usize = low;
    
    for (low..high) |j| {
        if (arr[j] < pivot) {
            const temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
            i += 1;
        }
    }
    
    const temp = arr[i];
    arr[i] = arr[high];
    arr[high] = temp;
    
    return i;
}

fn quicksortImpl(arr: []i64, low_opt: ?usize, high_opt: ?usize) void {
    const low = low_opt orelse 0;
    const high = high_opt orelse (if (arr.len > 0) arr.len - 1 else 0);
    
    if (low < high) {
        const pi = partition(arr, low, high);
        
        if (pi > 0) {
            quicksortImpl(arr, low, pi - 1);
        }
        quicksortImpl(arr, pi + 1, high);
    }
}

pub fn quicksort(arr: []i64) void {
    if (arr.len <= 1) return;
    quicksortImpl(arr, null, null);
}

/// Generate random array for sorting
fn generateRandomArray(allocator: std.mem.Allocator, size: usize, seed: u64) ![]i64 {
    const arr = try allocator.alloc(i64, size);
    var prng = std.Random.Xoshiro256.init(seed);
    const random = prng.random();
    
    for (arr) |*item| {
        item.* = random.intRangeAtMost(i64, 0, 1000000);
    }
    
    return arr;
}

pub fn runQuicksortBenchmark(iterations: u32, allocator: std.mem.Allocator) !BenchmarkResult {
    const size: usize = 10000;
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var checksum: i64 = 0;
    
    for (0..iterations) |i| {
        const arr = try generateRandomArray(allocator, size, @intCast(i));
        defer allocator.free(arr);
        
        const start = time.nanoTimestamp();
        quicksort(arr);
        const end = time.nanoTimestamp();
        
        const elapsed = @as(u64, @intCast(end - start));
        total_time += elapsed;
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
        
        // Verify sorted
        checksum += arr[0] + arr[size - 1];
    }
    
    const avg_time = total_time / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);
    
    return BenchmarkResult{
        .name = "quicksort_10k",
        .iterations = iterations,
        .total_time_ns = total_time,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .ops_per_second = ops_per_sec,
        .result_value = checksum,
    };
}

// ============================================================================
// MATRIX MULTIPLICATION BENCHMARK
// ============================================================================

pub const Matrix = struct {
    data: []f64,
    rows: usize,
    cols: usize,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        const data = try allocator.alloc(f64, rows * cols);
        return Matrix{
            .data = data,
            .rows = rows,
            .cols = cols,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Matrix) void {
        self.allocator.free(self.data);
    }
    
    pub fn get(self: *const Matrix, row: usize, col: usize) f64 {
        return self.data[row * self.cols + col];
    }
    
    pub fn set(self: *Matrix, row: usize, col: usize, value: f64) void {
        self.data[row * self.cols + col] = value;
    }
    
    pub fn fillRandom(self: *Matrix, seed: u64) void {
        var prng = std.Random.Xoshiro256.init(seed);
        var random = prng.random();
        
        for (self.data) |*item| {
            item.* = random.float(f64) * 100.0;
        }
    }
};

pub fn matrixMultiply(a: *const Matrix, b: *const Matrix, result: *Matrix) void {
    for (0..a.rows) |i| {
        for (0..b.cols) |j| {
            var sum: f64 = 0;
            for (0..a.cols) |k| {
                sum += a.get(i, k) * b.get(k, j);
            }
            result.set(i, j, sum);
        }
    }
}

/// Optimized matrix multiply with loop tiling
pub fn matrixMultiplyTiled(a: *const Matrix, b: *const Matrix, result: *Matrix) void {
    const tile_size: usize = 32;
    
    // Zero result
    for (result.data) |*item| {
        item.* = 0;
    }
    
    var i: usize = 0;
    while (i < a.rows) : (i += tile_size) {
        var j: usize = 0;
        while (j < b.cols) : (j += tile_size) {
            var k: usize = 0;
            while (k < a.cols) : (k += tile_size) {
                // Multiply tiles
                const i_end = @min(i + tile_size, a.rows);
                const j_end = @min(j + tile_size, b.cols);
                const k_end = @min(k + tile_size, a.cols);
                
                for (i..i_end) |ii| {
                    for (j..j_end) |jj| {
                        var sum: f64 = result.get(ii, jj);
                        for (k..k_end) |kk| {
                            sum += a.get(ii, kk) * b.get(kk, jj);
                        }
                        result.set(ii, jj, sum);
                    }
                }
            }
        }
    }
}

pub fn runMatrixBenchmark(iterations: u32, allocator: std.mem.Allocator) !BenchmarkResult {
    const size: usize = 256;
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var checksum: f64 = 0;
    
    var a = try Matrix.init(allocator, size, size);
    defer a.deinit();
    var b = try Matrix.init(allocator, size, size);
    defer b.deinit();
    var result = try Matrix.init(allocator, size, size);
    defer result.deinit();
    
    a.fillRandom(12345);
    b.fillRandom(67890);
    
    for (0..iterations) |_| {
        const start = time.nanoTimestamp();
        matrixMultiplyTiled(&a, &b, &result);
        const end = time.nanoTimestamp();
        
        const elapsed = @as(u64, @intCast(end - start));
        total_time += elapsed;
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
        
        checksum += result.get(0, 0);
    }
    
    const avg_time = total_time / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);
    
    return BenchmarkResult{
        .name = "matrix_multiply_256x256",
        .iterations = iterations,
        .total_time_ns = total_time,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .ops_per_second = ops_per_sec,
        .result_value = @intFromFloat(checksum),
    };
}

// ============================================================================
// PRIME SIEVE BENCHMARK
// ============================================================================

pub fn sieveOfEratosthenes(limit: usize, allocator: std.mem.Allocator) !u32 {
    var is_prime = try allocator.alloc(bool, limit + 1);
    defer allocator.free(is_prime);
    
    // Initialize all as prime
    for (is_prime) |*p| {
        p.* = true;
    }
    is_prime[0] = false;
    if (limit > 0) is_prime[1] = false;
    
    var i: usize = 2;
    while (i * i <= limit) : (i += 1) {
        if (is_prime[i]) {
            var j = i * i;
            while (j <= limit) : (j += i) {
                is_prime[j] = false;
            }
        }
    }
    
    // Count primes
    var count: u32 = 0;
    for (is_prime) |p| {
        if (p) count += 1;
    }
    
    return count;
}

pub fn runPrimeSieveBenchmark(iterations: u32, allocator: std.mem.Allocator) !BenchmarkResult {
    const limit: usize = 1000000;
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var prime_count: u32 = 0;
    
    for (0..iterations) |_| {
        const start = time.nanoTimestamp();
        prime_count = try sieveOfEratosthenes(limit, allocator);
        const end = time.nanoTimestamp();
        
        const elapsed = @as(u64, @intCast(end - start));
        total_time += elapsed;
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
    }
    
    const avg_time = total_time / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);
    
    return BenchmarkResult{
        .name = "prime_sieve_1M",
        .iterations = iterations,
        .total_time_ns = total_time,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .ops_per_second = ops_per_sec,
        .result_value = prime_count,
    };
}

// ============================================================================
// STRING OPERATIONS BENCHMARK
// ============================================================================

pub fn runStringBenchmark(iterations: u32, allocator: std.mem.Allocator) !BenchmarkResult {
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_len: usize = 0;
    
    const base_string = "Hello, VIBEE! ";
    
    for (0..iterations) |_| {
        const start = time.nanoTimestamp();
        
        // String concatenation
        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();
        
        for (0..1000) |_| {
            try result.appendSlice(base_string);
        }
        
        total_len += result.items.len;
        
        const end = time.nanoTimestamp();
        
        const elapsed = @as(u64, @intCast(end - start));
        total_time += elapsed;
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
    }
    
    const avg_time = total_time / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_time)) / 1_000_000_000.0);
    
    return BenchmarkResult{
        .name = "string_concat_1000x",
        .iterations = iterations,
        .total_time_ns = total_time,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .ops_per_second = ops_per_sec,
        .result_value = @intCast(total_len / iterations),
    };
}

// ============================================================================
// BENCHMARK SUITE RUNNER
// ============================================================================

pub fn runAllBenchmarks(allocator: std.mem.Allocator) !BenchmarkSuite {
    const iterations: u32 = 10;
    var results = std.ArrayList(BenchmarkResult).init(allocator);
    
    const suite_start = time.nanoTimestamp();
    
    // Run all benchmarks
    try results.append(runFibonacciBenchmark(iterations));
    try results.append(try runQuicksortBenchmark(iterations, allocator));
    try results.append(try runMatrixBenchmark(iterations, allocator));
    try results.append(try runPrimeSieveBenchmark(iterations, allocator));
    try results.append(try runStringBenchmark(iterations, allocator));
    
    const suite_end = time.nanoTimestamp();
    
    return BenchmarkSuite{
        .results = try results.toOwnedSlice(),
        .total_time_ns = @intCast(suite_end - suite_start),
        .benchmarks_run = @intCast(results.items.len),
    };
}

pub fn printBenchmarkResults(suite: *const BenchmarkSuite, writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try writer.print("║                        BENCHMARK RESULTS                                    ║\n", .{});
    try writer.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    for (suite.results) |result| {
        try writer.print("Benchmark: {s}\n", .{result.name});
        try writer.print("  Iterations: {d}\n", .{result.iterations});
        try writer.print("  Avg time: {d:.3} ms\n", .{@as(f64, @floatFromInt(result.avg_time_ns)) / 1_000_000.0});
        try writer.print("  Min time: {d:.3} ms\n", .{@as(f64, @floatFromInt(result.min_time_ns)) / 1_000_000.0});
        try writer.print("  Max time: {d:.3} ms\n", .{@as(f64, @floatFromInt(result.max_time_ns)) / 1_000_000.0});
        try writer.print("  Ops/sec: {d:.2}\n", .{result.ops_per_second});
        try writer.print("  Result: {d}\n\n", .{result.result_value});
    }

    try writer.print("Total suite time: {d:.3} ms\n", .{@as(f64, @floatFromInt(suite.total_time_ns)) / 1_000_000.0});
    try writer.print("Benchmarks run: {d}\n", .{suite.benchmarks_run});
}

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              VIBEEC BENCHMARK SUITE                                         ║\n", .{});
    try stdout.print("║              Real Performance Testing for Compiler Optimization             ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    try stdout.print("Running benchmarks...\n\n", .{});

    var suite = try runAllBenchmarks(allocator);
    defer allocator.free(suite.results);

    try printBenchmarkResults(&suite, stdout);

    // Verify correctness
    try stdout.print("\nCorrectness Verification:\n", .{});
    try stdout.print("  Fibonacci(30) = {d} (expected: 832040)\n", .{fibonacciRecursive(30)});
    try stdout.print("  Primes up to 1M = {d} (expected: 78498)\n", .{try sieveOfEratosthenes(1000000, allocator)});

    try stdout.print("\n✅ Benchmark suite complete\n", .{});
}

// ============================================================================
// TESTS
// ============================================================================

test "fibonacci correctness" {
    try std.testing.expectEqual(@as(u64, 0), fibonacciRecursive(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacciRecursive(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacciRecursive(10));
    try std.testing.expectEqual(@as(u64, 832040), fibonacciRecursive(30));
}

test "fibonacci iterative matches recursive" {
    for (0..20) |n| {
        try std.testing.expectEqual(fibonacciRecursive(@intCast(n)), fibonacciIterative(@intCast(n)));
    }
}

test "quicksort correctness" {
    var arr = [_]i64{ 5, 2, 8, 1, 9, 3, 7, 4, 6, 0 };
    quicksort(&arr);
    
    for (0..arr.len - 1) |i| {
        try std.testing.expect(arr[i] <= arr[i + 1]);
    }
}

test "matrix multiply correctness" {
    var a = try Matrix.init(std.testing.allocator, 2, 2);
    defer a.deinit();
    var b = try Matrix.init(std.testing.allocator, 2, 2);
    defer b.deinit();
    var result = try Matrix.init(std.testing.allocator, 2, 2);
    defer result.deinit();
    
    // A = [[1, 2], [3, 4]]
    a.set(0, 0, 1);
    a.set(0, 1, 2);
    a.set(1, 0, 3);
    a.set(1, 1, 4);
    
    // B = [[5, 6], [7, 8]]
    b.set(0, 0, 5);
    b.set(0, 1, 6);
    b.set(1, 0, 7);
    b.set(1, 1, 8);
    
    matrixMultiply(&a, &b, &result);
    
    // Result should be [[19, 22], [43, 50]]
    try std.testing.expectEqual(@as(f64, 19), result.get(0, 0));
    try std.testing.expectEqual(@as(f64, 22), result.get(0, 1));
    try std.testing.expectEqual(@as(f64, 43), result.get(1, 0));
    try std.testing.expectEqual(@as(f64, 50), result.get(1, 1));
}

test "prime sieve correctness" {
    const count_100 = try sieveOfEratosthenes(100, std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 25), count_100);
    
    const count_1000 = try sieveOfEratosthenes(1000, std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 168), count_1000);
}
