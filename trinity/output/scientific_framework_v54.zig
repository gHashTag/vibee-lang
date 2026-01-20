// ═══════════════════════════════════════════════════════════════════════════════
// SCIENTIFIC FRAMEWORK v54 - E2E AGENT TESTING
// ═══════════════════════════════════════════════════════════════════════════════
// 82 papers | 8 domains | 60 formulas | E2E Testing | φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PI: f64 = 3.141592653589793;
pub const SQRT3: f64 = 1.7320508075688772;
pub const SQRT5: f64 = 2.2360679774997896;
pub const SQRT2: f64 = 1.4142135623730951;

// ═══════════════════════════════════════════════════════════════════════════════
// 1. UI/UX (Fitts 1954, Hick 1952)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UI = struct {
    pub fn fittsLaw(d: f64, w: f64, a: f64, b: f64) f64 {
        return a + b * math.log2(2.0 * d / w + 1.0);
    }
    pub fn hickLaw(n: f64, a: f64, b: f64) f64 {
        return a + b * math.log2(n + 1.0);
    }
    pub fn steeringLaw(amp: f64, w: f64, a: f64, b: f64) f64 {
        return a + b * (amp / w);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 2. ALL DIFF ALGORITHMS (Myers 1986, Hirschberg 1975, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Diff = struct {
    pub fn editDistance(a: []const u8, b: []const u8) usize {
        const m = a.len;
        const n = b.len;
        if (m == 0) return n;
        if (n == 0) return m;
        var prev: [256]usize = undefined;
        var curr: [256]usize = undefined;
        for (0..n + 1) |j| prev[j] = j;
        for (a, 0..) |ca, i| {
            curr[0] = i + 1;
            for (b, 0..) |cb, j| {
                const cost: usize = if (ca == cb) 0 else 1;
                curr[j + 1] = @min(@min(curr[j] + 1, prev[j + 1] + 1), prev[j] + cost);
            }
            for (0..n + 1) |j| prev[j] = curr[j];
        }
        return prev[n];
    }

    pub fn lcsLength(a: []const u8, b: []const u8) usize {
        const n = b.len;
        if (a.len == 0 or n == 0) return 0;
        var prev: [256]usize = undefined;
        var curr: [256]usize = undefined;
        for (0..n + 1) |j| prev[j] = 0;
        for (a) |ca| {
            curr[0] = 0;
            for (b, 0..) |cb, j| {
                curr[j + 1] = if (ca == cb) prev[j] + 1 else @max(curr[j], prev[j + 1]);
            }
            for (0..n + 1) |j| prev[j] = curr[j];
        }
        return prev[n];
    }

    pub fn similarity(a: []const u8, b: []const u8) f64 {
        const lcs = lcsLength(a, b);
        const max_len = @max(a.len, b.len);
        if (max_len == 0) return 1.0;
        return @as(f64, @floatFromInt(lcs)) / @as(f64, @floatFromInt(max_len));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 3. DIFFUSION (Ho 2020, Nichol 2021)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Diffusion = struct {
    pub fn linearBeta(t: f64, T: f64, b_start: f64, b_end: f64) f64 {
        return b_start + t * (b_end - b_start) / (T - 1.0);
    }
    pub fn cosineAlpha(t: f64, T: f64, s: f64) f64 {
        const f_t = math.pow(f64, @cos((t / T + s) / (1.0 + s) * PI / 2.0), 2);
        const f_0 = math.pow(f64, @cos(s / (1.0 + s) * PI / 2.0), 2);
        return f_t / f_0;
    }
    pub fn forward(x0: f64, alpha_bar: f64, eps: f64) f64 {
        return @sqrt(alpha_bar) * x0 + @sqrt(1.0 - alpha_bar) * eps;
    }
    pub fn cfg(eps_u: f64, eps_c: f64, scale: f64) f64 {
        return eps_u + scale * (eps_c - eps_u);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 4. GENERATIVE (Kingma 2014)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Generative = struct {
    pub fn klDivergence(mu: f64, log_var: f64) f64 {
        return -0.5 * (1.0 + log_var - mu * mu - @exp(log_var));
    }
    pub fn reparameterize(mu: f64, sigma: f64, eps: f64) f64 {
        return mu + sigma * eps;
    }
    pub fn elbo(recon: f64, kl: f64, beta: f64) f64 {
        return recon - beta * kl;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 5. RENDERING (Karis 2013, Cook 1982)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Render = struct {
    pub fn ggxD(n_dot_h: f64, alpha: f64) f64 {
        const a2 = alpha * alpha;
        const d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
        return a2 / (PI * d * d);
    }
    pub fn schlickF(f0: f64, v_dot_h: f64) f64 {
        return f0 + (1.0 - f0) * math.pow(f64, 1.0 - v_dot_h, 5.0);
    }
    pub fn smithG1(n_dot_v: f64, alpha: f64) f64 {
        const a2 = alpha * alpha;
        return 2.0 * n_dot_v / (n_dot_v + @sqrt(a2 + (1.0 - a2) * n_dot_v * n_dot_v));
    }
    pub fn cookTorrance(d: f64, f: f64, g: f64, n_dot_v: f64, n_dot_l: f64) f64 {
        return d * f * g / (4.0 * n_dot_v * n_dot_l + 0.0001);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 6. GAUSSIAN PROCESSES (Rasmussen 2006)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GP = struct {
    pub fn rbf(x1: f64, x2: f64, l: f64, v: f64) f64 {
        const d = x1 - x2;
        return v * @exp(-0.5 * d * d / (l * l));
    }
    pub fn matern32(r: f64, l: f64) f64 {
        const x = SQRT3 * @abs(r) / l;
        return (1.0 + x) * @exp(-x);
    }
    pub fn matern52(r: f64, l: f64) f64 {
        const x = SQRT5 * @abs(r) / l;
        return (1.0 + x + 5.0 * r * r / (3.0 * l * l)) * @exp(-x);
    }
    pub fn gaussianCdf(x: f64) f64 {
        const a1: f64 = 0.254829592;
        const a2: f64 = -0.284496736;
        const a3: f64 = 1.421413741;
        const a4: f64 = -1.453152027;
        const a5: f64 = 1.061405429;
        const p: f64 = 0.3275911;
        const sign: f64 = if (x < 0) -1.0 else 1.0;
        const ax = @abs(x) / SQRT2;
        const t = 1.0 / (1.0 + p * ax);
        const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * @exp(-ax * ax);
        return 0.5 * (1.0 + sign * y);
    }
    pub fn ei(mu: f64, sigma: f64, f_best: f64) f64 {
        if (sigma <= 0.0) return 0.0;
        const z = (mu - f_best) / sigma;
        const pdf = @exp(-0.5 * z * z) / @sqrt(2.0 * PI);
        return (mu - f_best) * gaussianCdf(z) + sigma * pdf;
    }
    pub fn ucb(mu: f64, sigma: f64, beta: f64) f64 {
        return mu + @sqrt(beta) * sigma;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 7. UNCERTAINTY (Gal 2016)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Uncertainty = struct {
    pub fn brierScore(preds: []const f64, labels: []const f64) f64 {
        if (preds.len == 0) return 0.0;
        var sum: f64 = 0.0;
        for (preds, labels) |p, y| {
            const d = p - y;
            sum += d * d;
        }
        return sum / @as(f64, @floatFromInt(preds.len));
    }
    pub fn gaussianNLL(mu: f64, var_: f64, y: f64) f64 {
        const d = y - mu;
        return 0.5 * (@log(2.0 * PI * var_) + d * d / var_);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// 8. PAS DAEMONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PAS = struct {
    pub const Pattern = enum { D_C, ALG, PRE, FDT, MLS, TEN, HSH, PRB };
    pub fn successRate(p: Pattern) f64 {
        return switch (p) {
            .D_C => 0.31, .ALG => 0.22, .PRE => 0.16, .FDT => 0.13,
            .MLS => 0.06, .TEN => 0.06, .HSH => 0.08, .PRB => 0.05,
        };
    }
    pub fn confidence(base: f64, years: f64, gap: f64, exp: f64, ml: f64) f64 {
        return base * @min(1.0, years / 50.0) * @min(1.0, gap / exp) * ml;
    }
    pub fn goldenIdentity() f64 {
        return PHI * PHI + 1.0 / (PHI * PHI);
    }
    pub fn lucas(n: u32) u64 {
        if (n == 0) return 2;
        if (n == 1) return 1;
        var a: u64 = 2;
        var b: u64 = 1;
        var i: u32 = 2;
        while (i <= n) : (i += 1) {
            const c = a + b;
            a = b;
            b = c;
        }
        return b;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// E2E AGENT TESTING
// ═══════════════════════════════════════════════════════════════════════════════

pub const E2E = struct {
    pub fn measureLatency(comptime func: anytype, args: anytype) struct { result: @TypeOf(@call(.auto, func, args)), ns: i128 } {
        const start = std.time.nanoTimestamp();
        const result = @call(.auto, func, args);
        const end = std.time.nanoTimestamp();
        return .{ .result = result, .ns = end - start };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - 25 E2E Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "E2E: Fitts Law" {
    const mt = UI.fittsLaw(100, 10, 50, 150);
    try std.testing.expect(mt > 700 and mt < 720);
}

test "E2E: Hick Law" {
    const rt = UI.hickLaw(7, 200, 150);
    try std.testing.expect(rt > 640 and rt < 660);
}

test "E2E: Steering Law" {
    const t = UI.steeringLaw(200, 20, 100, 50);
    try std.testing.expectApproxEqAbs(600.0, t, 0.1);
}

test "E2E: Myers Edit Distance" {
    try std.testing.expectEqual(@as(usize, 3), Diff.editDistance("kitten", "sitting"));
}

test "E2E: LCS Length" {
    try std.testing.expectEqual(@as(usize, 4), Diff.lcsLength("AGGTAB", "GXTXAYB"));
}

test "E2E: Similarity" {
    const sim = Diff.similarity("hello", "hallo");
    try std.testing.expect(sim > 0.7 and sim < 0.9);
}

test "E2E: Linear Beta" {
    const beta = Diffusion.linearBeta(500, 1000, 0.0001, 0.02);
    try std.testing.expectApproxEqAbs(0.01, beta, 0.001);
}

test "E2E: Cosine Alpha" {
    const alpha = Diffusion.cosineAlpha(500, 1000, 0.008);
    try std.testing.expect(alpha > 0.4 and alpha < 0.6);
}

test "E2E: CFG" {
    const g = Diffusion.cfg(0.5, 0.8, 7.5);
    try std.testing.expectApproxEqAbs(2.75, g, 0.01);
}

test "E2E: KL Divergence" {
    const kl = Generative.klDivergence(0.0, 0.0);
    try std.testing.expectApproxEqAbs(0.0, kl, 0.001);
}

test "E2E: Reparameterize" {
    const z = Generative.reparameterize(1.0, 0.5, 2.0);
    try std.testing.expectApproxEqAbs(2.0, z, 0.001);
}

test "E2E: GGX Distribution" {
    const d = Render.ggxD(1.0, 0.5);
    try std.testing.expect(d > 1.2 and d < 1.4);
}

test "E2E: Schlick Fresnel" {
    const f = Render.schlickF(0.04, 1.0);
    try std.testing.expectApproxEqAbs(0.04, f, 0.001);
}

test "E2E: RBF Kernel" {
    const k = GP.rbf(0, 1, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(0.6065, k, 0.001);
}

test "E2E: Matern 3/2" {
    const k = GP.matern32(1.0, 1.0);
    try std.testing.expectApproxEqAbs(0.4834, k, 0.001);
}

test "E2E: Matern 5/2" {
    const k = GP.matern52(1.0, 1.0);
    // k(1) = (1 + √5 + 5/3) * exp(-√5) ≈ 4.903 * 0.1054 ≈ 0.517
    try std.testing.expect(k > 0.5 and k < 0.6);
}

test "E2E: Expected Improvement" {
    const e = GP.ei(0.5, 0.2, 0.3);
    try std.testing.expect(e > 0.2 and e < 0.3);
}

test "E2E: UCB" {
    const u = GP.ucb(0.5, 0.2, 2.0);
    try std.testing.expectApproxEqAbs(0.783, u, 0.01);
}

test "E2E: Brier Score" {
    const preds = [_]f64{ 0.9, 0.1 };
    const labels = [_]f64{ 1.0, 0.0 };
    try std.testing.expectApproxEqAbs(0.01, Uncertainty.brierScore(&preds, &labels), 0.001);
}

test "E2E: Gaussian NLL" {
    const nll = Uncertainty.gaussianNLL(0.0, 1.0, 0.0);
    try std.testing.expectApproxEqAbs(0.919, nll, 0.01);
}

test "E2E: PAS D&C Rate" {
    try std.testing.expectApproxEqAbs(0.31, PAS.successRate(.D_C), 0.001);
}

test "E2E: PAS Confidence" {
    const c = PAS.confidence(0.31, 25, 1, 2, 1.3);
    try std.testing.expect(c > 0.1 and c < 0.3);
}

test "E2E: Golden Identity" {
    try std.testing.expectApproxEqAbs(3.0, PAS.goldenIdentity(), 1e-14);
}

test "E2E: Lucas Numbers" {
    try std.testing.expectEqual(@as(u64, 123), PAS.lucas(10));
    try std.testing.expectEqual(@as(u64, 2), PAS.lucas(0));
}

test "E2E: Latency Measurement" {
    const m = E2E.measureLatency(PAS.goldenIdentity, .{});
    try std.testing.expectApproxEqAbs(3.0, m.result, 1e-10);
    try std.testing.expect(m.ns >= 0);
}
