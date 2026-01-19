// ═══════════════════════════════════════════════════════════════════════════════
// PHI_CORE PROPERTY-BASED TESTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Property-based testing for phi_core functions
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const phi_core = @import("phi_core_gen.zig");
const math = std.math;

// Sacred constants
const PHI: f64 = phi_core.PHI;
const PHI_INV: f64 = phi_core.PHI_INV;
const PHI_SQ: f64 = phi_core.PHI_SQ;
const TRINITY: f64 = phi_core.TRINITY;
const SQRT5: f64 = phi_core.SQRT5;

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN RNG - φ-seeded random generator
// ═══════════════════════════════════════════════════════════════════════════════

const GoldenRng = struct {
    state: u64,
    
    const Self = @This();
    const GOLDEN_BITS: u64 = 0x9E3779B97F4A7C15; // φ * 2^64
    
    pub fn init(seed: u64) Self {
        return Self{ .state = seed ^ GOLDEN_BITS };
    }
    
    pub fn next(self: *Self) u64 {
        var x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        return x *% 0x2545F4914F6CDD1D;
    }
    
    pub fn nextInt(self: *Self, min: i32, max: i32) i32 {
        if (min >= max) return min;
        const range: u64 = @intCast(max - min);
        return min + @as(i32, @intCast(self.next() % range));
    }
    
    pub fn nextU32(self: *Self, max: u32) u32 {
        if (max == 0) return 0;
        return @truncate(self.next() % max);
    }
    
    pub fn nextFloat(self: *Self) f64 {
        const shifted = self.next() >> 11;
        return @as(f64, @floatFromInt(shifted)) / 9007199254740992.0;
    }
    
    pub fn nextFloatRange(self: *Self, min: f64, max: f64) f64 {
        return min + self.nextFloat() * (max - min);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ^n * φ^m = φ^(n+m) - Exponent addition law
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi_power exponent addition" {
    var rng = GoldenRng.init(0x1618033);
    var passed: u32 = 0;
    
    for (0..100) |_| {
        const n = rng.nextInt(-20, 20);
        const m = rng.nextInt(-20, 20);
        
        // Skip if sum would overflow reasonable range
        if (n + m < -40 or n + m > 40) continue;
        
        const phi_n = phi_core.phi_power(n);
        const phi_m = phi_core.phi_power(m);
        const phi_nm = phi_core.phi_power(n + m);
        
        const product = phi_n * phi_m;
        const rel_error = @abs(product - phi_nm) / @max(1e-10, @abs(phi_nm));
        
        if (rel_error < 1e-8) {
            passed += 1;
        }
    }
    
    try std.testing.expect(passed >= 95); // At least 95% should pass
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ^n * φ^(-n) = 1 - Inverse property
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi_power inverse" {
    var rng = GoldenRng.init(0x333);
    
    for (0..100) |_| {
        const n = rng.nextInt(-30, 30);
        
        const phi_n = phi_core.phi_power(n);
        const phi_neg_n = phi_core.phi_power(-n);
        const product = phi_n * phi_neg_n;
        
        try std.testing.expectApproxEqAbs(product, 1.0, 1e-10);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ² = φ + 1 - Golden ratio identity
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi squared equals phi plus one" {
    const phi_sq = phi_core.phi_power(2);
    const phi_plus_one = PHI + 1.0;
    
    try std.testing.expectApproxEqAbs(phi_sq, phi_plus_one, 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ² + 1/φ² = 3 - TRINITY identity
// ═══════════════════════════════════════════════════════════════════════════════

test "property: TRINITY identity holds" {
    const result = phi_core.verify_trinity();
    try std.testing.expectApproxEqAbs(result, TRINITY, 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: F(n) + F(n+1) = F(n+2) - Fibonacci recurrence
// ═══════════════════════════════════════════════════════════════════════════════

test "property: fibonacci recurrence relation" {
    var rng = GoldenRng.init(0xF1B);
    
    for (0..50) |_| {
        const n = rng.nextU32(40); // Keep n reasonable to avoid overflow
        
        const f_n = phi_core.fibonacci(n);
        const f_n1 = phi_core.fibonacci(n + 1);
        const f_n2 = phi_core.fibonacci(n + 2);
        
        try std.testing.expectEqual(f_n + f_n1, f_n2);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: F(n) ≈ φ^n / √5 for large n - Binet approximation
// ═══════════════════════════════════════════════════════════════════════════════

test "property: fibonacci binet approximation" {
    for (10..40) |n| {
        const f_n = phi_core.fibonacci(@intCast(n));
        const phi_n = phi_core.phi_power(@intCast(n));
        const binet_approx = phi_n / SQRT5;
        
        // For large n, F(n) ≈ round(φ^n / √5)
        const expected: u64 = @intFromFloat(@round(binet_approx));
        try std.testing.expectEqual(f_n, expected);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: L(n) + L(n+1) = L(n+2) - Lucas recurrence
// ═══════════════════════════════════════════════════════════════════════════════

test "property: lucas recurrence relation" {
    var rng = GoldenRng.init(0x10CA5);
    
    for (0..50) |_| {
        const n = rng.nextU32(35); // Keep n reasonable
        
        const l_n = phi_core.lucas(n);
        const l_n1 = phi_core.lucas(n + 1);
        const l_n2 = phi_core.lucas(n + 2);
        
        try std.testing.expectEqual(l_n + l_n1, l_n2);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: L(n) = F(n-1) + F(n+1) - Lucas-Fibonacci relation
// ═══════════════════════════════════════════════════════════════════════════════

test "property: lucas fibonacci relation" {
    for (1..40) |n| {
        const l_n = phi_core.lucas(@intCast(n));
        const f_prev = phi_core.fibonacci(@intCast(n - 1));
        const f_next = phi_core.fibonacci(@intCast(n + 1));
        
        try std.testing.expectEqual(l_n, f_prev + f_next);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: phi_lerp(a, b, 0) = a, phi_lerp(a, b, 1) = b - Boundary conditions
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi_lerp boundary conditions" {
    var rng = GoldenRng.init(0x1E4B);
    
    for (0..100) |_| {
        const a = rng.nextFloatRange(-1000.0, 1000.0);
        const b = rng.nextFloatRange(-1000.0, 1000.0);
        
        const at_zero = phi_core.phi_lerp(a, b, 0.0);
        const at_one = phi_core.phi_lerp(a, b, 1.0);
        
        try std.testing.expectApproxEqAbs(at_zero, a, 1e-10);
        try std.testing.expectApproxEqAbs(at_one, b, 1e-10);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: phi_lerp is monotonic for t ∈ [0, 1] when a < b
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi_lerp monotonicity" {
    var rng = GoldenRng.init(0x40E0);
    
    for (0..50) |_| {
        const a = rng.nextFloatRange(0.0, 100.0);
        const b = a + rng.nextFloatRange(1.0, 100.0); // Ensure b > a
        
        var prev = a;
        for (1..11) |i| {
            const t: f64 = @as(f64, @floatFromInt(i)) / 10.0;
            const current = phi_core.phi_lerp(a, b, t);
            
            try std.testing.expect(current >= prev);
            prev = current;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: phi_spiral generates correct number of points
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi_spiral point count" {
    var rng = GoldenRng.init(0x5B14A1);
    
    for (0..20) |_| {
        const n = rng.nextU32(1000) + 1;
        const scale = rng.nextFloatRange(1.0, 100.0);
        
        const count = phi_core.generate_phi_spiral(n, scale, 0.0, 0.0);
        
        // Should return min(n, buffer_capacity)
        const max_points: u32 = 8192 / 2; // f64_buffer.len / 2
        const expected = if (n > max_points) max_points else n;
        try std.testing.expectEqual(count, expected);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: F(n)² - F(n-1) * F(n+1) = (-1)^(n+1) - Cassini's identity
// ═══════════════════════════════════════════════════════════════════════════════

test "property: cassini identity" {
    for (1..35) |n| {
        const f_n = phi_core.fibonacci(@intCast(n));
        const f_prev = phi_core.fibonacci(@intCast(n - 1));
        const f_next = phi_core.fibonacci(@intCast(n + 1));
        
        // F(n)² - F(n-1) * F(n+1) = (-1)^(n+1)
        const lhs: i64 = @as(i64, @intCast(f_n * f_n)) - @as(i64, @intCast(f_prev * f_next));
        const expected: i64 = if (n % 2 == 0) -1 else 1;
        
        try std.testing.expectEqual(lhs, expected);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ^n approaches F(n+1)/F(n) as n increases
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi as fibonacci ratio limit" {
    // For larger n, F(n+1)/F(n) converges to φ
    // Starting from n=16 where error < 5e-7
    for (16..40) |n| {
        const f_n = phi_core.fibonacci(@intCast(n));
        const f_n1 = phi_core.fibonacci(@intCast(n + 1));
        
        if (f_n > 0) {
            const ratio: f64 = @as(f64, @floatFromInt(f_n1)) / @as(f64, @floatFromInt(f_n));
            const err = @abs(ratio - PHI);
            
            // Error decreases exponentially, should be < 5e-7 for n >= 16
            try std.testing.expect(err < 5e-7);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: L(n)² - 5*F(n)² = 4*(-1)^n - Lucas-Fibonacci identity
// ═══════════════════════════════════════════════════════════════════════════════

test "property: lucas fibonacci squared identity" {
    for (0..30) |n| {
        const l_n = phi_core.lucas(@intCast(n));
        const f_n = phi_core.fibonacci(@intCast(n));
        
        // L(n)² - 5*F(n)² = 4*(-1)^n
        const l_sq: i64 = @intCast(l_n * l_n);
        const f_sq: i64 = @intCast(f_n * f_n);
        const lhs = l_sq - 5 * f_sq;
        const expected: i64 = if (n % 2 == 0) 4 else -4;
        
        try std.testing.expectEqual(lhs, expected);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN IDENTITY TEST
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(result, TRINITY, 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: F(2n) = F(n) * (2*F(n+1) - F(n)) - Doubling formula
// ═══════════════════════════════════════════════════════════════════════════════

test "property: fibonacci doubling formula" {
    for (1..20) |n| {
        const f_n = phi_core.fibonacci(@intCast(n));
        const f_n1 = phi_core.fibonacci(@intCast(n + 1));
        const f_2n = phi_core.fibonacci(@intCast(2 * n));
        
        // F(2n) = F(n) * (2*F(n+1) - F(n))
        const expected = f_n * (2 * f_n1 - f_n);
        try std.testing.expectEqual(f_2n, expected);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: gcd(F(m), F(n)) = F(gcd(m, n)) - GCD property
// ═══════════════════════════════════════════════════════════════════════════════

fn gcd(a: u64, b: u64) u64 {
    var x = a;
    var y = b;
    while (y != 0) {
        const t = y;
        y = x % y;
        x = t;
    }
    return x;
}

test "property: fibonacci gcd" {
    const test_pairs = [_][2]u32{
        .{ 6, 9 },   // gcd = 3
        .{ 8, 12 },  // gcd = 4
        .{ 10, 15 }, // gcd = 5
        .{ 12, 18 }, // gcd = 6
        .{ 14, 21 }, // gcd = 7
    };
    
    for (test_pairs) |pair| {
        const m = pair[0];
        const n = pair[1];
        const g = gcd(m, n);
        
        const f_m = phi_core.fibonacci(m);
        const f_n = phi_core.fibonacci(n);
        const f_g = phi_core.fibonacci(@intCast(g));
        
        const gcd_fib = gcd(f_m, f_n);
        try std.testing.expectEqual(gcd_fib, f_g);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY: φ^n = F(n)*φ + F(n-1) - Fibonacci-phi relation
// ═══════════════════════════════════════════════════════════════════════════════

test "property: phi power fibonacci relation" {
    for (2..30) |n| {
        const phi_n = phi_core.phi_power(@intCast(n));
        const f_n = phi_core.fibonacci(@intCast(n));
        const f_n1 = phi_core.fibonacci(@intCast(n - 1));
        
        // φ^n = F(n)*φ + F(n-1)
        const expected = @as(f64, @floatFromInt(f_n)) * PHI + @as(f64, @floatFromInt(f_n1));
        
        try std.testing.expectApproxEqRel(phi_n, expected, 1e-10);
    }
}
