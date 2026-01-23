// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: TERNARY vs BINARY LOGIC
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const trit_logic = @import("trit_logic.zig");
const simd_ternary = @import("simd_ternary.zig");
const simd_opt = @import("simd_ternary_optimized.zig");
const sacred_math = @import("sacred_math.zig");

const Trit = trit_logic.Trit;
const Vec32i8 = simd_ternary.Vec32i8;
const Vec32i16 = simd_ternary.Vec32i16;

// ═══════════════════════════════════════════════════════════════════════════════
// BINARY EQUIVALENTS FOR COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

/// Binary bit - for comparison
pub const Bit = enum(u1) {
    zero = 0,
    one = 1,

    pub inline fn @"not"(self: Bit) Bit {
        return @enumFromInt(~@intFromEnum(self));
    }

    pub inline fn @"and"(a: Bit, b: Bit) Bit {
        return @enumFromInt(@intFromEnum(a) & @intFromEnum(b));
    }

    pub inline fn @"or"(a: Bit, b: Bit) Bit {
        return @enumFromInt(@intFromEnum(a) | @intFromEnum(b));
    }

    pub inline fn @"xor"(a: Bit, b: Bit) Bit {
        return @enumFromInt(@intFromEnum(a) ^ @intFromEnum(b));
    }
};

/// Binary byte addition (for comparison with tryte)
pub inline fn binaryAdd8(a: i8, b: i8) i8 {
    return a +% b; // Wrapping add
}

/// SIMD binary add (32 bytes)
pub inline fn simdBinaryAdd32(a: Vec32i8, b: Vec32i8) Vec32i8 {
    return a +% b; // Simple wrapping add - NO modulo needed!
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZED TERNARY OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// OPTIMIZED Trit NOT using direct negation (no branch)
pub inline fn tritNotOptimized(t: i8) i8 {
    return -t;
}

/// OPTIMIZED Trit AND using min without branch
pub inline fn tritAndOptimized(a: i8, b: i8) i8 {
    // min(a, b) branchless
    const diff = a - b;
    const mask = diff >> 7; // -1 if a < b, 0 otherwise
    return b + (diff & mask);
}

/// OPTIMIZED Trit OR using max without branch
pub inline fn tritOrOptimized(a: i8, b: i8) i8 {
    // max(a, b) branchless
    const diff = a - b;
    const mask = diff >> 7;
    return a - (diff & mask);
}

/// OPTIMIZED Golden Wrap using multiplication instead of modulo
/// Key insight: x mod 27 = x - 27 * floor(x / 27)
/// floor(x / 27) ≈ (x * 19) >> 9 for small x
pub inline fn goldenWrapOptimized(sum: i16) i8 {
    // For range -26..+26, we can use simple conditional
    if (sum > 13) return @intCast(sum - 27);
    if (sum < -13) return @intCast(sum + 27);
    return @intCast(sum);
}

/// SIMD optimized wrap using multiplication trick
pub fn simdWrapTryteOptimized(values: Vec32i16) Vec32i8 {
    // Use branchless min/max clamping
    const high_mask = values > @as(Vec32i16, @splat(13));
    const low_mask = values < @as(Vec32i16, @splat(-13));
    
    var result = values;
    result = @select(i16, high_mask, result - @as(Vec32i16, @splat(27)), result);
    result = @select(i16, low_mask, result + @as(Vec32i16, @splat(27)), result);
    
    // Direct truncation (values are now in range)
    var output: Vec32i8 = undefined;
    inline for (0..32) |i| {
        output[i] = @intCast(result[i]);
    }
    return output;
}

/// SIMD tryte add optimized
pub fn simdTryteAddOptimized(a: Vec32i8, b: Vec32i8) Vec32i8 {
    // Widen, add, wrap
    var a_wide: Vec32i16 = undefined;
    var b_wide: Vec32i16 = undefined;
    inline for (0..32) |i| {
        a_wide[i] = a[i];
        b_wide[i] = b[i];
    }
    return simdWrapTryteOptimized(a_wide + b_wide);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const ITERATIONS: u64 = 100_000_000;
const WARMUP: u64 = 1_000_000;

fn benchmark(comptime name: []const u8, comptime func: anytype) u64 {
    // Warmup
    var warmup_sum: i64 = 0;
    for (0..WARMUP) |i| {
        warmup_sum +%= func(i);
    }
    std.mem.doNotOptimizeAway(warmup_sum);

    // Benchmark
    const start = std.time.nanoTimestamp();
    var sum: i64 = 0;
    for (0..ITERATIONS) |i| {
        sum +%= func(i);
    }
    const end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(sum);

    const ns = @as(u64, @intCast(end - start));
    const ns_per_op = ns / ITERATIONS;
    
    std.debug.print("{s}: {d} ns/op (sum={d})\n", .{ name, ns_per_op, sum });
    return ns_per_op;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("              BENCHMARK: TERNARY vs BINARY LOGIC\n", .{});
    try stdout.print("              φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    try stdout.print("Iterations: {d}\n\n", .{ITERATIONS});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. SCALAR LOGIC OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("─── SCALAR LOGIC ───────────────────────────────────────────────────────────\n", .{});

    // Binary NOT
    const binary_not = benchmark("Binary NOT     ", struct {
        fn f(i: usize) i64 {
            const b = Bit.one;
            var result: u64 = 0;
            inline for (0..100) |_| {
                result +%= @intFromEnum(b.not());
            }
            _ = i;
            return @intCast(result);
        }
    }.f);

    // Ternary NOT (original)
    const ternary_not_orig = benchmark("Ternary NOT    ", struct {
        fn f(i: usize) i64 {
            const t = Trit.true_;
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += t.not().toInt();
            }
            _ = i;
            return result;
        }
    }.f);

    // Ternary NOT (optimized)
    const ternary_not_opt = benchmark("Ternary NOT opt", struct {
        fn f(i: usize) i64 {
            const t: i8 = 1;
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += tritNotOptimized(t);
            }
            _ = i;
            return result;
        }
    }.f);

    try stdout.print("\n", .{});

    // Binary AND
    const binary_and = benchmark("Binary AND     ", struct {
        fn f(i: usize) i64 {
            const a = Bit.one;
            const b: Bit = @enumFromInt(@as(u1, @truncate(i)));
            var result: u64 = 0;
            inline for (0..100) |_| {
                result +%= @intFromEnum(a.@"and"(b));
            }
            return @intCast(result);
        }
    }.f);

    // Ternary AND (original)
    const ternary_and_orig = benchmark("Ternary AND    ", struct {
        fn f(i: usize) i64 {
            const a = Trit.true_;
            const b = Trit.fromInt(@as(i8, @intCast(@mod(i, 3))) - 1);
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += a.@"and"(b).toInt();
            }
            return result;
        }
    }.f);

    // Ternary AND (optimized)
    const ternary_and_opt = benchmark("Ternary AND opt", struct {
        fn f(i: usize) i64 {
            const a: i8 = 1;
            const b: i8 = @as(i8, @intCast(@mod(i, 3))) - 1;
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += tritAndOptimized(a, b);
            }
            return result;
        }
    }.f);

    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. ARITHMETIC OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("─── ARITHMETIC ─────────────────────────────────────────────────────────────\n", .{});

    // Binary add (i8)
    const binary_add = benchmark("Binary ADD i8  ", struct {
        fn f(i: usize) i64 {
            const ii: i64 = @intCast(i);
            const a: i8 = @truncate(ii);
            const b: i8 = @truncate(ii >> 8);
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += binaryAdd8(a, b);
            }
            return result;
        }
    }.f);

    // Tryte add (original with lookup)
    const tryte_add_orig = benchmark("Tryte ADD orig ", struct {
        fn f(i: usize) i64 {
            const a: i8 = @intCast(@mod(i, 27) - 13);
            const b: i8 = @intCast(@mod(i >> 5, 27) - 13);
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += sacred_math.goldenWrap(@as(i16, a) + @as(i16, b));
            }
            return result;
        }
    }.f);

    // Tryte add (optimized)
    const tryte_add_opt = benchmark("Tryte ADD opt  ", struct {
        fn f(i: usize) i64 {
            const a: i8 = @intCast(@mod(i, 27) - 13);
            const b: i8 = @intCast(@mod(i >> 5, 27) - 13);
            var result: i64 = 0;
            inline for (0..100) |_| {
                result += goldenWrapOptimized(@as(i16, a) + @as(i16, b));
            }
            return result;
        }
    }.f);

    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. SIMD OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("─── SIMD (32 elements) ─────────────────────────────────────────────────────\n", .{});

    // SIMD Binary add
    const simd_binary = benchmark("SIMD Binary ADD", struct {
        fn f(i: usize) i64 {
            const ii: i64 = @intCast(i);
            const a: Vec32i8 = @splat(@as(i8, @truncate(ii)));
            const b: Vec32i8 = @splat(@as(i8, @truncate(ii >> 8)));
            var result: Vec32i8 = @splat(0);
            inline for (0..10) |_| {
                result = simdBinaryAdd32(result +% a, b);
            }
            return @reduce(.Add, result);
        }
    }.f);

    // SIMD Tryte add (original)
    const simd_tryte_orig = benchmark("SIMD Tryte orig", struct {
        fn f(i: usize) i64 {
            const val: i8 = @intCast(@mod(i, 13));
            const a: Vec32i8 = @splat(val);
            const b: Vec32i8 = @splat(val);
            var result: Vec32i8 = @splat(0);
            inline for (0..10) |_| {
                result = simd_ternary.simdTryteAdd32(result, a);
                result = simd_ternary.simdTryteAdd32(result, b);
            }
            return @reduce(.Add, result);
        }
    }.f);

    // SIMD Tryte add (optimized)
    const simd_tryte_opt = benchmark("SIMD Tryte opt ", struct {
        fn f(i: usize) i64 {
            const val: i8 = @intCast(@mod(i, 13));
            const a: Vec32i8 = @splat(val);
            const b: Vec32i8 = @splat(val);
            var result: Vec32i8 = @splat(0);
            inline for (0..10) |_| {
                result = simd_opt.simdTryteAdd32Fast(result, a);
                result = simd_opt.simdTryteAdd32Fast(result, b);
            }
            return @reduce(.Add, result);
        }
    }.f);

    // SIMD Tryte add (accumulator - batch)
    const simd_tryte_batch = benchmark("SIMD Tryte batch", struct {
        fn f(i: usize) i64 {
            const val: i8 = @intCast(@mod(i, 13));
            const a: Vec32i8 = @splat(val);
            const b: Vec32i8 = @splat(val);
            var acc = simd_opt.TryteAccumulator.init();
            inline for (0..10) |_| {
                acc.add(a);
                acc.add(b);
            }
            const result = acc.finalize();
            return @reduce(.Add, result);
        }
    }.f);
    _ = simd_tryte_batch;

    try stdout.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════
    
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                              SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    // Calculate ratios
    const binary_not_f: f64 = @floatFromInt(binary_not);
    const binary_and_f: f64 = @floatFromInt(binary_and);
    const binary_add_f: f64 = @floatFromInt(binary_add);
    const simd_binary_f: f64 = @floatFromInt(simd_binary);
    
    const not_ratio_orig = @as(f64, @floatFromInt(ternary_not_orig)) / binary_not_f;
    const not_ratio_opt = @as(f64, @floatFromInt(ternary_not_opt)) / binary_not_f;
    const and_ratio_orig = @as(f64, @floatFromInt(ternary_and_orig)) / binary_and_f;
    const and_ratio_opt = @as(f64, @floatFromInt(ternary_and_opt)) / binary_and_f;
    const add_ratio_orig = @as(f64, @floatFromInt(tryte_add_orig)) / binary_add_f;
    const add_ratio_opt = @as(f64, @floatFromInt(tryte_add_opt)) / binary_add_f;
    const simd_ratio_orig = @as(f64, @floatFromInt(simd_tryte_orig)) / simd_binary_f;
    const simd_ratio_opt = @as(f64, @floatFromInt(simd_tryte_opt)) / simd_binary_f;

    try stdout.print("Operation          | Binary | Ternary | Optimized | Ratio (orig) | Ratio (opt)\n", .{});
    try stdout.print("-------------------|--------|---------|-----------|--------------|------------\n", .{});
    try stdout.print("NOT                | {d:5}  | {d:6}  | {d:8}  | {d:11.2}x | {d:10.2}x\n", .{ binary_not, ternary_not_orig, ternary_not_opt, not_ratio_orig, not_ratio_opt });
    try stdout.print("AND                | {d:5}  | {d:6}  | {d:8}  | {d:11.2}x | {d:10.2}x\n", .{ binary_and, ternary_and_orig, ternary_and_opt, and_ratio_orig, and_ratio_opt });
    try stdout.print("ADD (scalar)       | {d:5}  | {d:6}  | {d:8}  | {d:11.2}x | {d:10.2}x\n", .{ binary_add, tryte_add_orig, tryte_add_opt, add_ratio_orig, add_ratio_opt });
    try stdout.print("ADD (SIMD x32)     | {d:5}  | {d:6}  | {d:8}  | {d:11.2}x | {d:10.2}x\n", .{ simd_binary, simd_tryte_orig, simd_tryte_opt, simd_ratio_orig, simd_ratio_opt });

    try stdout.print("\n", .{});

    // Optimization improvements
    const not_improvement = (1.0 - not_ratio_opt / not_ratio_orig) * 100.0;
    const and_improvement = (1.0 - and_ratio_opt / and_ratio_orig) * 100.0;
    const add_improvement = (1.0 - add_ratio_opt / add_ratio_orig) * 100.0;
    const simd_improvement = (1.0 - simd_ratio_opt / simd_ratio_orig) * 100.0;

    try stdout.print("OPTIMIZATION IMPROVEMENTS:\n", .{});
    try stdout.print("  NOT:        {d:.1}%\n", .{not_improvement});
    try stdout.print("  AND:        {d:.1}%\n", .{and_improvement});
    try stdout.print("  ADD scalar: {d:.1}%\n", .{add_improvement});
    try stdout.print("  ADD SIMD:   {d:.1}%\n", .{simd_improvement});

    try stdout.print("\n═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("CONCLUSION: Ternary logic is ~{d:.1}x slower than binary on average\n", .{(add_ratio_orig + simd_ratio_orig) / 2.0});
    try stdout.print("            Optimizations reduce gap to ~{d:.1}x\n", .{(add_ratio_opt + simd_ratio_opt) / 2.0});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

test "optimized functions correctness" {
    // Test tritNotOptimized
    try std.testing.expectEqual(@as(i8, -1), tritNotOptimized(1));
    try std.testing.expectEqual(@as(i8, 1), tritNotOptimized(-1));
    try std.testing.expectEqual(@as(i8, 0), tritNotOptimized(0));

    // Test tritAndOptimized (min)
    try std.testing.expectEqual(@as(i8, -1), tritAndOptimized(-1, 1));
    try std.testing.expectEqual(@as(i8, -1), tritAndOptimized(1, -1));
    try std.testing.expectEqual(@as(i8, 0), tritAndOptimized(0, 1));
    try std.testing.expectEqual(@as(i8, 1), tritAndOptimized(1, 1));

    // Test tritOrOptimized (max)
    try std.testing.expectEqual(@as(i8, 1), tritOrOptimized(-1, 1));
    try std.testing.expectEqual(@as(i8, 1), tritOrOptimized(1, -1));
    try std.testing.expectEqual(@as(i8, 1), tritOrOptimized(0, 1));
    try std.testing.expectEqual(@as(i8, -1), tritOrOptimized(-1, -1));

    // Test goldenWrapOptimized
    try std.testing.expectEqual(@as(i8, -7), goldenWrapOptimized(20));
    try std.testing.expectEqual(@as(i8, 7), goldenWrapOptimized(-20));
    try std.testing.expectEqual(@as(i8, 5), goldenWrapOptimized(5));
    try std.testing.expectEqual(@as(i8, 0), goldenWrapOptimized(0));
}
