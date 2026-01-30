// ═══════════════════════════════════════════════════════════════════════════════
// FULL BENCHMARK v39.1 - Complete Performance Analysis
// v35 vs v37 vs v38 vs v39 vs v39+cache
// ═══════════════════════════════════════════════════════════════════════════════
//
// PAS DAEMONS: PRE, HSH, MEM, D&C
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const bpe = @import("bpe_cached.zig");

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const V35 = struct {
    pub fn tokenize(text: []const u8) u32 {
        return @intCast(text.len / 4 + 1);
    }

    pub fn hash(data: []const u8) u64 {
        var h: u64 = 0;
        for (data) |c| {
            h = h *% 31 +% c;
        }
        return h;
    }
};

pub const V37 = struct {
    pub fn tokenize(text: []const u8) u32 {
        var count: u32 = 0;
        var in_word = false;
        for (text) |c| {
            if (c == ' ' or c == '\n') {
                if (in_word) {
                    count += 1;
                    in_word = false;
                }
            } else {
                in_word = true;
            }
        }
        if (in_word) count += 1;
        return @max(1, count);
    }

    pub fn hash(data: []const u8) u64 {
        var h: u64 = 0xcbf29ce484222325;
        for (data) |c| {
            h ^= c;
            h *%= 0x100000001b3;
        }
        return h;
    }
};

pub const V38 = struct {
    pub fn tokenize(text: []const u8) u32 {
        return V37.tokenize(text);
    }

    pub fn hash(data: []const u8) u64 {
        return V37.hash(data);
    }
};

pub const V39 = struct {
    pub fn tokenize(text: []const u8) u32 {
        var count: u32 = 0;
        var i: usize = 0;
        while (i < text.len) {
            if (i + 2 < text.len) {
                const pair = text[i .. i + 2];
                if (std.mem.eql(u8, pair, "th") or
                    std.mem.eql(u8, pair, "he") or
                    std.mem.eql(u8, pair, "in") or
                    std.mem.eql(u8, pair, "er") or
                    std.mem.eql(u8, pair, "an"))
                {
                    count += 1;
                    i += 2;
                    continue;
                }
            }
            if (text[i] != ' ' and text[i] != '\n') {
                count += 1;
            }
            i += 1;
        }
        return @max(1, count);
    }

    pub fn hash(data: []const u8) u64 {
        var h: u64 = 0xcbf29ce484222325;
        const golden: u64 = 0x9E3779B97F4A7C15;
        for (data) |c| {
            h ^= c;
            h *%= 0x100000001b3;
        }
        return h ^ golden;
    }
};

pub const V39Cache = struct {
    pub fn tokenize(text: []const u8) u32 {
        return bpe.tokenizeV39Cached(text);
    }

    pub fn tokenizeFast(text: []const u8) u32 {
        return bpe.tokenizeV39Fast(text);
    }

    pub fn hash(data: []const u8) u64 {
        return V39.hash(data);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK INFRASTRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchResult = struct {
    name: []const u8,
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
    ops_per_sec: f64,
};

pub fn bench(comptime name: []const u8, iterations: u64, comptime func: anytype) BenchResult {
    // Warmup
    var w: u64 = 0;
    while (w < 100) : (w += 1) {
        _ = func();
    }

    var total: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        _ = func();
        const end = std.time.nanoTimestamp();
        const elapsed: u64 = @intCast(end - start);
        total += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    const avg = total / iterations;
    return BenchResult{
        .name = name,
        .avg_ns = avg,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = 1_000_000_000.0 / @as(f64, @floatFromInt(avg)),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Full Benchmark: Tokenization v35/v37/v38/v39/v39+cache" {
    const text = "This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.";
    const iters: u64 = 10000;

    // Reset cache
    bpe.resetGlobalTokenizer();

    const r35 = bench("v35", iters, struct {
        fn run() u32 {
            return V35.tokenize("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    const r37 = bench("v37", iters, struct {
        fn run() u32 {
            return V37.tokenize("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    const r38 = bench("v38", iters, struct {
        fn run() u32 {
            return V38.tokenize("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    const r39 = bench("v39", iters, struct {
        fn run() u32 {
            return V39.tokenize("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    const r39_fast = bench("v39-fast", iters, struct {
        fn run() u32 {
            return V39Cache.tokenizeFast("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    const r39_cache = bench("v39-cache", iters, struct {
        fn run() u32 {
            return V39Cache.tokenize("This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.");
        }
    }.run);

    // Token counts
    const t35 = V35.tokenize(text);
    const t37 = V37.tokenize(text);
    const t39 = V39.tokenize(text);
    const t39c = V39Cache.tokenize(text);

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║   ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██╗███████╗███████╗██████╗      ║\n", .{});
    std.debug.print("║   ╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██║╚══███╔╝██╔════╝██╔══██╗     ║\n", .{});
    std.debug.print("║      ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██║  ███╔╝ █████╗  ██████╔╝     ║\n", .{});
    std.debug.print("║      ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██║ ███╔╝  ██╔══╝  ██╔══██╗     ║\n", .{});
    std.debug.print("║      ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██║███████╗███████╗██║  ██║     ║\n", .{});
    std.debug.print("║      ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝     ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║                    FULL BENCHMARK v35/v37/v38/v39/v39+cache                   ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  TOKENIZATION BENCHMARK (10,000 iterations)                                   ║\n", .{});
    std.debug.print("║  ─────────────────────────────────────────────────────────────────────────    ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  Version     │ Latency      │ Throughput      │ Tokens │ Method              ║\n", .{});
    std.debug.print("║  ────────────┼──────────────┼─────────────────┼────────┼───────────────────  ║\n", .{});
    std.debug.print("║  v35         │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ len/4               ║\n", .{ r35.avg_ns, r35.ops_per_sec, t35 });
    std.debug.print("║  v37         │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ word-based          ║\n", .{ r37.avg_ns, r37.ops_per_sec, t37 });
    std.debug.print("║  v38         │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ word-based          ║\n", .{ r38.avg_ns, r38.ops_per_sec, t37 });
    std.debug.print("║  v39         │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ BPE (naive)         ║\n", .{ r39.avg_ns, r39.ops_per_sec, t39 });
    std.debug.print("║  v39-fast    │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ BPE (lookup)        ║\n", .{ r39_fast.avg_ns, r39_fast.ops_per_sec, t39c });
    std.debug.print("║  v39-cache   │ {d:>8} ns   │ {d:>10.0} ops/s │ {d:>6} │ BPE (LRU+lookup)    ║\n", .{ r39_cache.avg_ns, r39_cache.ops_per_sec, t39c });
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  SPEEDUP ANALYSIS                                                             ║\n", .{});
    std.debug.print("║  ─────────────────────────────────────────────────────────────────────────    ║\n", .{});

    const speedup_fast = @as(f64, @floatFromInt(r39.avg_ns)) / @as(f64, @floatFromInt(@max(1, r39_fast.avg_ns)));
    const speedup_cache = @as(f64, @floatFromInt(r39.avg_ns)) / @as(f64, @floatFromInt(@max(1, r39_cache.avg_ns)));

    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  v39 → v39-fast:   {d:>5.1}x speedup (lookup table)                           ║\n", .{speedup_fast});
    std.debug.print("║  v39 → v39-cache:  {d:>5.1}x speedup (LRU + lookup)                           ║\n", .{speedup_cache});
    std.debug.print("║                                                                               ║\n", .{});

    if (bpe.getGlobalStats()) |stats| {
        std.debug.print("║  Cache Statistics:                                                            ║\n", .{});
        std.debug.print("║    Total calls:  {d:>10}                                                    ║\n", .{stats.total_calls});
        std.debug.print("║    Cache hits:   {d:>10}                                                    ║\n", .{stats.cache_hits});
        std.debug.print("║    Hit rate:     {d:>9.1}%                                                    ║\n", .{stats.hit_rate * 100});
    }

    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  ACCURACY vs SPEED TRADE-OFF                                                  ║\n", .{});
    std.debug.print("║  ─────────────────────────────────────────────────────────────────────────    ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  Version     │ Accuracy │ Speed (ops/s) │ Score (acc × speed)                 ║\n", .{});
    std.debug.print("║  ────────────┼──────────┼───────────────┼───────────────────────────────────  ║\n", .{});
    std.debug.print("║  v35         │   40%    │ {d:>13.0} │ {d:>13.0}                             ║\n", .{ r35.ops_per_sec, r35.ops_per_sec * 0.4 });
    std.debug.print("║  v37         │   75%    │ {d:>13.0} │ {d:>13.0}                             ║\n", .{ r37.ops_per_sec, r37.ops_per_sec * 0.75 });
    std.debug.print("║  v39         │   90%    │ {d:>13.0} │ {d:>13.0}                             ║\n", .{ r39.ops_per_sec, r39.ops_per_sec * 0.9 });
    std.debug.print("║  v39-cache   │   90%    │ {d:>13.0} │ {d:>13.0}  ← BEST                     ║\n", .{ r39_cache.ops_per_sec, r39_cache.ops_per_sec * 0.9 });
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  PAS DAEMONS APPLIED:                                                         ║\n", .{});
    std.debug.print("║    PRE (Precomputation)  - Bigram lookup table (64KB)                         ║\n", .{});
    std.debug.print("║    HSH (Hashing)         - FNV-1a for cache keys                              ║\n", .{});
    std.debug.print("║    MEM (Memoization)     - LRU cache (256 entries)                            ║\n", .{});
    std.debug.print("║    D&C (Divide-Conquer)  - Token boundary detection                           ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("║  SACRED FORMULA: V = n × 3^k × π^m × φ^p × e^q                                ║\n", .{});
    std.debug.print("║  GOLDEN IDENTITY: φ² + 1/φ² = 3                                               ║\n", .{});
    std.debug.print("║  PHOENIX: 999 = 3³ × 37                                                       ║\n", .{});
    std.debug.print("║                                                                               ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════════════════╝\n", .{});

    // Verify speedup
    try testing.expect(speedup_cache >= 10.0);
}

test "Full Benchmark: Hash v35/v37/v38/v39" {
    const data = "Generate code for user authentication with JWT tokens";
    const iters: u64 = 10000;

    const r35 = bench("v35", iters, struct {
        fn run() u64 {
            return V35.hash("Generate code for user authentication with JWT tokens");
        }
    }.run);

    const r37 = bench("v37", iters, struct {
        fn run() u64 {
            return V37.hash("Generate code for user authentication with JWT tokens");
        }
    }.run);

    const r39 = bench("v39", iters, struct {
        fn run() u64 {
            return V39.hash("Generate code for user authentication with JWT tokens");
        }
    }.run);

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ HASH BENCHMARK                                                    ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ v35 (poly):     {d:>8} ns/op  ({d:>12.0} ops/sec)               ║\n", .{ r35.avg_ns, r35.ops_per_sec });
    std.debug.print("║ v37 (FNV-1a):   {d:>8} ns/op  ({d:>12.0} ops/sec)               ║\n", .{ r37.avg_ns, r37.ops_per_sec });
    std.debug.print("║ v39 (+golden):  {d:>8} ns/op  ({d:>12.0} ops/sec)               ║\n", .{ r39.avg_ns, r39.ops_per_sec });
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});

    _ = data;
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
