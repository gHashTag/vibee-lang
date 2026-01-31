// TVC VSA - Vector Symbolic Architecture for Balanced Ternary
// Hyperdimensional computing operations: bind, bundle, similarity
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const tvc_hybrid = @import("tvc_hybrid.zig");

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const Vec32i8 = tvc_hybrid.Vec32i8;
pub const SIMD_WIDTH = tvc_hybrid.SIMD_WIDTH;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind operation (XOR-like for balanced ternary)
/// Creates associations between vectors
/// bind(a, b) = a * b (element-wise multiplication)
/// Properties:
/// - bind(a, a) = all +1 (self-inverse)
/// - bind(a, bind(a, b)) = b (unbind)
/// - Preserves similarity structure
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);

    // SIMD bind (32 trits at a time)
    const num_chunks = len / SIMD_WIDTH;

    for (0..num_chunks) |chunk| {
        const base = chunk * SIMD_WIDTH;

        var a_vec: Vec32i8 = undefined;
        var b_vec: Vec32i8 = undefined;

        inline for (0..SIMD_WIDTH) |i| {
            const idx = base + i;
            a_vec[i] = if (idx < a.trit_len) a.unpacked_cache[idx] else 0;
            b_vec[i] = if (idx < b.trit_len) b.unpacked_cache[idx] else 0;
        }

        // Element-wise multiplication (bind)
        const prod = simdMultiply(a_vec, b_vec);

        inline for (0..SIMD_WIDTH) |i| {
            result.unpacked_cache[base + i] = prod[i];
        }
    }

    // Remainder (scalar)
    const remainder_start = num_chunks * SIMD_WIDTH;
    for (remainder_start..len) |i| {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_trit * b_trit;
    }

    result.trit_len = len;
    return result;
}

/// Unbind operation (inverse of bind)
/// unbind(bound, key) = bind(bound, key) (same as bind for balanced ternary)
pub fn unbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return bind(bound, key);
}

/// Bundle operation (majority voting for superposition)
/// Combines multiple vectors into one that is similar to all inputs
/// For 2 vectors: majority(a, b) with tie-breaker
pub fn bundle2(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);

    for (0..len) |i| {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;

        const sum = a_trit + b_trit;

        // Majority voting with threshold
        if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            // Tie: use random or alternate (here: 0)
            result.unpacked_cache[i] = 0;
        }
    }

    result.trit_len = len;
    return result;
}

/// Bundle 3 vectors (true majority voting)
pub fn bundle3(a: *HybridBigInt, b: *HybridBigInt, c: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();
    c.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(@max(a.trit_len, b.trit_len), c.trit_len);

    for (0..len) |i| {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const c_trit: i16 = if (i < c.trit_len) c.unpacked_cache[i] else 0;

        const sum = a_trit + b_trit + c_trit;

        // Majority voting: 2 out of 3
        if (sum >= 2) {
            result.unpacked_cache[i] = 1;
        } else if (sum <= -2) {
            result.unpacked_cache[i] = -1;
        } else if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    result.trit_len = len;
    return result;
}

/// Cosine similarity between two vectors
/// Returns value in range [-1, 1]
pub fn cosineSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const norm_a = vectorNorm(a);
    const norm_b = vectorNorm(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

/// Hamming distance (number of differing trits)
pub fn hammingDistance(a: *HybridBigInt, b: *HybridBigInt) usize {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var distance: usize = 0;
    const len = @max(a.trit_len, b.trit_len);

    for (0..len) |i| {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;

        if (a_trit != b_trit) {
            distance += 1;
        }
    }

    return distance;
}

/// Normalized Hamming similarity (1 - hamming_distance / len)
pub fn hammingSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 1.0;

    const distance = hammingDistance(a, b);
    return 1.0 - @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(len));
}

/// Dot similarity (normalized dot product)
pub fn dotSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / @as(f64, @floatFromInt(len));
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD element-wise multiplication
fn simdMultiply(a: Vec32i8, b: Vec32i8) Vec32i8 {
    // For balanced ternary: result is always in {-1, 0, 1}
    // -1 * -1 = 1, -1 * 0 = 0, -1 * 1 = -1
    // 0 * x = 0
    // 1 * -1 = -1, 1 * 0 = 0, 1 * 1 = 1
    const a_wide: @Vector(32, i16) = a;
    const b_wide: @Vector(32, i16) = b;
    const prod = a_wide * b_wide;

    var result: Vec32i8 = undefined;
    inline for (0..32) |i| {
        result[i] = @intCast(prod[i]);
    }
    return result;
}

/// Vector L2 norm (sqrt of sum of squares)
fn vectorNorm(v: *HybridBigInt) f64 {
    v.ensureUnpacked();

    var sum_sq: i64 = 0;
    for (0..v.trit_len) |i| {
        const trit: i64 = v.unpacked_cache[i];
        sum_sq += trit * trit;
    }

    return @sqrt(@as(f64, @floatFromInt(sum_sq)));
}

/// Count non-zero trits
pub fn countNonZero(v: *HybridBigInt) usize {
    v.ensureUnpacked();

    var count: usize = 0;
    for (0..v.trit_len) |i| {
        if (v.unpacked_cache[i] != 0) {
            count += 1;
        }
    }
    return count;
}

/// Create random vector (for testing)
pub fn randomVector(len: usize, seed: u64) HybridBigInt {
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = @min(len, MAX_TRITS);

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (0..result.trit_len) |i| {
        const r = random.intRangeAtMost(i8, -1, 1);
        result.unpacked_cache[i] = r;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMUTE OPERATIONS (для кодирования последовательностей)
// ═══════════════════════════════════════════════════════════════════════════════

/// Permute (циклический сдвиг вправо на k позиций)
/// Используется для кодирования последовательностей:
/// sequence(a, b, c) = a + permute(b, 1) + permute(c, 2)
pub fn permute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    if (v.trit_len == 0) return result;

    const shift = k % v.trit_len;

    // Циклический сдвиг вправо: новая позиция = (старая + shift) % len
    for (0..v.trit_len) |i| {
        const new_pos = (i + shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }

    return result;
}

/// Inverse permute (циклический сдвиг влево на k позиций)
/// inverse_permute(permute(v, k), k) = v
pub fn inversePermute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    if (v.trit_len == 0) return result;

    const shift = k % v.trit_len;

    // Циклический сдвиг влево: новая позиция = (старая - shift + len) % len
    for (0..v.trit_len) |i| {
        const new_pos = (i + v.trit_len - shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }

    return result;
}

/// Encode sequence using permute
/// sequence(items) = items[0] + permute(items[1], 1) + permute(items[2], 2) + ...
pub fn encodeSequence(items: []HybridBigInt) HybridBigInt {
    if (items.len == 0) return HybridBigInt.zero();

    var result = items[0];

    for (1..items.len) |i| {
        var permuted = permute(&items[i], i);
        result = result.add(&permuted);
    }

    return result;
}

/// Decode element from sequence at position
/// Проверяет similarity с permuted версией кандидата
pub fn probeSequence(sequence: *HybridBigInt, candidate: *HybridBigInt, position: usize) f64 {
    var permuted = permute(candidate, position);
    return cosineSimilarity(sequence, &permuted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "permute/inverse_permute roundtrip" {
    var v = randomVector(100, 99999);

    // permute then inverse_permute should return original
    var permuted = permute(&v, 7);
    const recovered = inversePermute(&permuted, 7);

    for (0..v.trit_len) |i| {
        try std.testing.expectEqual(v.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "permute shift correctness" {
    var v = HybridBigInt.zero();
    v.mode = .unpacked_mode;
    v.trit_len = 5;

    // v = [1, -1, 0, 1, -1]
    v.unpacked_cache[0] = 1;
    v.unpacked_cache[1] = -1;
    v.unpacked_cache[2] = 0;
    v.unpacked_cache[3] = 1;
    v.unpacked_cache[4] = -1;

    // permute by 2: [1, -1, 0, 1, -1] -> [1, -1, 1, -1, 0]
    // (shift right, so element at 0 goes to 2, element at 3 goes to 0)
    const p = permute(&v, 2);

    // After shift right by 2:
    // old[0]=1 -> new[2]=1
    // old[1]=-1 -> new[3]=-1
    // old[2]=0 -> new[4]=0
    // old[3]=1 -> new[0]=1
    // old[4]=-1 -> new[1]=-1
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[0]); // from old[3]
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[1]); // from old[4]
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[2]); // from old[0]
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[3]); // from old[1]
    try std.testing.expectEqual(@as(Trit, 0), p.unpacked_cache[4]); // from old[2]
}

test "permute orthogonality" {
    var v = randomVector(256, 77777);

    // permute(v, k) should be nearly orthogonal to v for k > 0
    var p1 = permute(&v, 1);
    var p10 = permute(&v, 10);

    const sim1 = cosineSimilarity(&v, &p1);
    const sim10 = cosineSimilarity(&v, &p10);

    // Random vectors permuted should have low similarity
    try std.testing.expect(sim1 < 0.3);
    try std.testing.expect(sim10 < 0.3);
}

test "sequence encoding" {
    // Тест encodeSequence - просто проверяем что функция работает без ошибок
    const a = randomVector(100, 11111);
    const b = randomVector(100, 22222);

    var items = [_]HybridBigInt{ a, b };
    const seq = encodeSequence(&items);

    // Sequence должна иметь ту же длину
    try std.testing.expectEqual(a.trit_len, seq.trit_len);
}

test "bind self-inverse" {
    var a = randomVector(100, 12345);
    const bound = bind(&a, &a);

    // bind(a, a) should be all +1 for non-zero elements
    for (0..a.trit_len) |i| {
        const a_trit = a.unpacked_cache[i];
        const bound_trit = bound.unpacked_cache[i];

        if (a_trit != 0) {
            try std.testing.expectEqual(@as(Trit, 1), bound_trit);
        } else {
            try std.testing.expectEqual(@as(Trit, 0), bound_trit);
        }
    }
}

test "bind/unbind roundtrip" {
    // For balanced ternary bind: a * b
    // unbind(bind(a,b), b) = a * b * b
    // Since b * b = |b| (absolute value, 0 or 1), this only works for non-zero b
    // Test with vectors that have no zeros
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;

    // Set non-zero values only
    for (0..10) |i| {
        a.unpacked_cache[i] = if (i % 2 == 0) 1 else -1;
        b.unpacked_cache[i] = if (i % 3 == 0) 1 else -1;
    }

    var bound = bind(&a, &b);
    const recovered = unbind(&bound, &b);

    // For non-zero b: recovered = a * b * b = a * 1 = a
    for (0..a.trit_len) |i| {
        try std.testing.expectEqual(a.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "bundle2 similarity" {
    var a = randomVector(100, 33333);
    var b = randomVector(100, 44444);

    var bundled = bundle2(&a, &b);

    // Bundled should be similar to both inputs
    const sim_a = cosineSimilarity(&bundled, &a);
    const sim_b = cosineSimilarity(&bundled, &b);

    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "bundle3 majority" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();
    var c = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    c.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;
    c.trit_len = 10;

    // Set up: a=[1,1,1,...], b=[1,1,-1,...], c=[-1,1,1,...]
    for (0..10) |i| {
        a.unpacked_cache[i] = 1;
        b.unpacked_cache[i] = if (i < 5) 1 else -1;
        c.unpacked_cache[i] = if (i < 3) -1 else 1;
    }

    const bundled = bundle3(&a, &b, &c);

    // Position 0: 1+1-1 = 1 -> 1
    try std.testing.expectEqual(@as(Trit, 1), bundled.unpacked_cache[0]);
    // Position 5: 1-1+1 = 1 -> 1
    try std.testing.expectEqual(@as(Trit, 1), bundled.unpacked_cache[5]);
}

test "cosine similarity identical" {
    var a = randomVector(100, 55555);
    var b = a;

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expect(sim > 0.99);
}

test "hamming distance" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;

    // a = [1, 1, 1, 0, 0, 0, -1, -1, -1, 0]
    // b = [1, 0, -1, 0, 1, -1, -1, 0, 1, 0]
    a.unpacked_cache[0] = 1;
    a.unpacked_cache[1] = 1;
    a.unpacked_cache[2] = 1;
    a.unpacked_cache[6] = -1;
    a.unpacked_cache[7] = -1;
    a.unpacked_cache[8] = -1;

    b.unpacked_cache[0] = 1;
    b.unpacked_cache[2] = -1;
    b.unpacked_cache[4] = 1;
    b.unpacked_cache[5] = -1;
    b.unpacked_cache[6] = -1;
    b.unpacked_cache[8] = 1;

    const dist = hammingDistance(&a, &b);
    // Differences at positions: 1, 2, 4, 5, 7, 8 = 6
    try std.testing.expectEqual(@as(usize, 6), dist);
}

test "random vector distribution" {
    const v = randomVector(256, 66666); // Use MAX_TRITS

    var pos: usize = 0;
    var neg: usize = 0;
    var zero: usize = 0;

    for (0..v.trit_len) |i| {
        const t = v.unpacked_cache[i];
        if (t > 0) pos += 1 else if (t < 0) neg += 1 else zero += 1;
    }

    // Should have some of each (relaxed test)
    try std.testing.expect(pos > 0);
    try std.testing.expect(neg > 0);
    try std.testing.expect(zero > 0);
    try std.testing.expectEqual(@as(usize, 256), pos + neg + zero);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    const iterations: u64 = 10000;
    const vec_size: usize = 256;

    std.debug.print("\nVSA Operations Benchmarks ({}D vectors)\n", .{vec_size});
    std.debug.print("==========================================\n\n", .{});

    var a = randomVector(vec_size, 111);
    var b = randomVector(vec_size, 222);
    var c = randomVector(vec_size, 333);

    // Bind benchmark
    const bind_start = std.time.nanoTimestamp();
    var bind_result = HybridBigInt.zero();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        bind_result = bind(&a, &b);
    }
    const bind_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bind_result);
    const bind_ns = @as(u64, @intCast(bind_end - bind_start));

    std.debug.print("Bind x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bind_ns, bind_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bind_ns)) * 1000.0,
    });

    // Bundle benchmark
    const bundle_start = std.time.nanoTimestamp();
    var bundle_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        bundle_result = bundle3(&a, &b, &c);
    }
    const bundle_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bundle_result);
    const bundle_ns = @as(u64, @intCast(bundle_end - bundle_start));

    std.debug.print("Bundle3 x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bundle_ns, bundle_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bundle_ns)) * 1000.0,
    });

    // Similarity benchmark
    const sim_start = std.time.nanoTimestamp();
    var sim_result: f64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        sim_result = cosineSimilarity(&a, &b);
    }
    const sim_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(sim_result);
    const sim_ns = @as(u64, @intCast(sim_end - sim_start));

    std.debug.print("Cosine Similarity x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ sim_ns, sim_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(sim_ns)) * 1000.0,
    });

    // Dot product benchmark (using HybridBigInt method)
    const dot_start = std.time.nanoTimestamp();
    var dot_result: i32 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        dot_result = a.dotProduct(&b);
    }
    const dot_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(dot_result);
    const dot_ns = @as(u64, @intCast(dot_end - dot_start));

    std.debug.print("Dot Product x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ dot_ns, dot_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(dot_ns)) * 1000.0,
    });

    // Permute benchmark
    const perm_start = std.time.nanoTimestamp();
    var perm_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        perm_result = permute(&a, 7);
    }
    const perm_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(perm_result);
    const perm_ns = @as(u64, @intCast(perm_end - perm_start));

    std.debug.print("Permute x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ perm_ns, perm_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(perm_ns)) * 1000.0,
    });

    std.debug.print("Summary:\n", .{});
    std.debug.print("  Bind:       {} ns/op\n", .{bind_ns / iterations});
    std.debug.print("  Bundle3:    {} ns/op\n", .{bundle_ns / iterations});
    std.debug.print("  Similarity: {} ns/op\n", .{sim_ns / iterations});
    std.debug.print("  Dot:        {} ns/op\n", .{dot_ns / iterations});
    std.debug.print("  Permute:    {} ns/op\n", .{perm_ns / iterations});
}

pub fn main() !void {
    runBenchmarks();
}
