// ═══════════════════════════════════════════════════════════════
// v6734: SLIDING WINDOW ATTENTION
// Local attention with global receptive field
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;

pub const SlidingWindowConfig = struct {
    window_size: usize = 256,
    num_layers: usize = 6,
    use_global_tokens: bool = true,
};

pub fn createWindowMask(seq_len: usize, window_size: usize, mask: []bool) void {
    const half_window = window_size / 2;

    for (0..seq_len) |i| {
        for (0..seq_len) |j| {
            const idx = i * seq_len + j;
            if (idx < mask.len) {
                const dist = if (i > j) i - j else j - i;
                mask[idx] = dist <= half_window;
            }
        }
    }
}

pub fn effectiveContextLength(window_size: usize, num_layers: usize) usize {
    return window_size * num_layers;
}

pub fn phiWindowSize(seq_len: usize) usize {
    // window = round(seq_len / φ²)
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(seq_len)) / PHI_SQ)));
}

pub fn computeSparsity(seq_len: usize, window_size: usize) f32 {
    if (seq_len == 0) return 0;
    const full_attention = seq_len * seq_len;
    const window_attention = seq_len * @min(window_size, seq_len);
    return 1.0 - @as(f32, @floatFromInt(window_attention)) / @as(f32, @floatFromInt(full_attention));
}

pub fn addGlobalTokens(mask: []bool, seq_len: usize, global_indices: []const usize) void {
    for (global_indices) |g| {
        if (g >= seq_len) continue;
        // Global token attends to all
        for (0..seq_len) |j| {
            const idx1 = g * seq_len + j;
            const idx2 = j * seq_len + g;
            if (idx1 < mask.len) mask[idx1] = true;
            if (idx2 < mask.len) mask[idx2] = true;
        }
    }
}

pub fn slidingWindowForward(q: []const f32, k: []const f32, v: []const f32, output: []f32, window_size: usize, head_dim: usize) void {
    const seq_len = q.len / head_dim;
    const half_window = window_size / 2;

    for (0..seq_len) |i| {
        const start = if (i > half_window) i - half_window else 0;
        const end = @min(i + half_window + 1, seq_len);

        for (0..head_dim) |d| {
            var acc: f32 = 0;
            var weight_sum: f32 = 0;

            for (start..end) |j| {
                var dot: f32 = 0;
                for (0..head_dim) |dd| {
                    const q_idx = i * head_dim + dd;
                    const k_idx = j * head_dim + dd;
                    if (q_idx < q.len and k_idx < k.len) {
                        dot += q[q_idx] * k[k_idx];
                    }
                }
                const weight = @exp(dot / @sqrt(@as(f32, @floatFromInt(head_dim))));
                weight_sum += weight;

                const v_idx = j * head_dim + d;
                if (v_idx < v.len) {
                    acc += weight * v[v_idx];
                }
            }

            const out_idx = i * head_dim + d;
            if (out_idx < output.len and weight_sum > 0) {
                output[out_idx] = acc / weight_sum;
            }
        }
    }
}

// Tests
test "window mask" {
    var mask: [64]bool = undefined;
    createWindowMask(8, 4, &mask);
    const sparsity = computeSparsity(8, 4);
    try testing.expect(sparsity > 0.3);
}

test "effective context" {
    const effective = effectiveContextLength(32, 6);
    try testing.expect(effective == 192);
}

test "phi window" {
    const window = phiWindowSize(512);
    // 512 / 2.618 ≈ 196
    try testing.expect(window >= 195 and window <= 196);
}

test "complexity" {
    const sparsity = computeSparsity(1024, 128);
    try testing.expect(sparsity > 0.8);
}

test "global tokens" {
    var mask: [16]bool = undefined;
    @memset(&mask, false);
    const globals = [_]usize{0};
    addGlobalTokens(&mask, 4, &globals);
    // Token 0 should attend to all
    try testing.expect(mask[0]); // 0 -> 0
    try testing.expect(mask[1]); // 0 -> 1
}

test "sliding forward" {
    const q = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const k = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const v = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;

    slidingWindowForward(&q, &k, &v, &output, 2, 2);
    try testing.expect(!math.isNan(output[0]));
}
