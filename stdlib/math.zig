// VIBEE Standard Library - Math Module
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37

const std = @import("std");

// Sacred Constants
pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_INVERSE: f64 = 0.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PHOENIX: i64 = 999;
pub const TRINITY: i64 = 3;

pub const PI: f64 = std.math.pi;
pub const E: f64 = std.math.e;
pub const TAU: f64 = std.math.tau;

// Fibonacci sequence
pub fn fibonacci(n: u64) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// Lucas numbers (related to Fibonacci)
pub fn lucas(n: u64) u64 {
    if (n == 0) return 2;
    if (n == 1) return 1;
    var a: u64 = 2;
    var b: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// Golden ratio approximation via Fibonacci
pub fn goldenApprox(n: u32) f64 {
    if (n < 2) return 1.0;
    const fn1 = fibonacci(n);
    const fn2 = fibonacci(n - 1);
    return @as(f64, @floatFromInt(fn1)) / @as(f64, @floatFromInt(fn2));
}

// Verify golden identity: φ² + 1/φ² = 3
pub fn verifyGoldenIdentity() bool {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    return @abs(phi_sq + inv_phi_sq - GOLDEN_IDENTITY) < 0.0000001;
}

// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
pub fn sacredFormula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {
    return n * std.math.pow(f64, 3.0, k) * 
           std.math.pow(f64, PI, m) * 
           std.math.pow(f64, PHI, p) * 
           std.math.pow(f64, E, q);
}

// Primality test
pub fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    
    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

// Greatest common divisor
pub fn gcd(a: u64, b: u64) u64 {
    var x = a;
    var y = b;
    while (y != 0) {
        const t = y;
        y = x % y;
        x = t;
    }
    return x;
}

// Least common multiple
pub fn lcm(a: u64, b: u64) u64 {
    if (a == 0 or b == 0) return 0;
    return (a / gcd(a, b)) * b;
}

// Factorial
pub fn factorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

// Binomial coefficient
pub fn binomial(n: u64, k: u64) u64 {
    if (k > n) return 0;
    if (k == 0 or k == n) return 1;
    
    var result: u64 = 1;
    var i: u64 = 0;
    while (i < k) : (i += 1) {
        result = result * (n - i) / (i + 1);
    }
    return result;
}

// Power function for integers
pub fn pow(base: i64, exp: u32) i64 {
    if (exp == 0) return 1;
    var result: i64 = 1;
    var b = base;
    var e = exp;
    while (e > 0) {
        if (e & 1 == 1) result *= b;
        b *= b;
        e >>= 1;
    }
    return result;
}

// Absolute value
pub fn abs(x: i64) u64 {
    return if (x < 0) @intCast(-x) else @intCast(x);
}

// Sign function (returns -1, 0, or 1)
pub fn sign(x: i64) i64 {
    if (x < 0) return -1;
    if (x > 0) return 1;
    return 0;
}

// Clamp value to range
pub fn clamp(x: i64, min_val: i64, max_val: i64) i64 {
    if (x < min_val) return min_val;
    if (x > max_val) return max_val;
    return x;
}

// Linear interpolation
pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * t;
}

// Tests
test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
    try std.testing.expectEqual(@as(u64, 6765), fibonacci(20));
}

test "lucas" {
    try std.testing.expectEqual(@as(u64, 2), lucas(0));
    try std.testing.expectEqual(@as(u64, 1), lucas(1));
    try std.testing.expectEqual(@as(u64, 123), lucas(10));
}

test "golden approximation" {
    const approx = goldenApprox(30);
    try std.testing.expectApproxEqAbs(PHI, approx, 0.0001);
}

test "golden identity" {
    try std.testing.expect(verifyGoldenIdentity());
}

test "sacred formula" {
    // V = 1 × 3^1 × π^0 × φ^0 × e^0 = 3
    const result = sacredFormula(1, 1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "isPrime" {
    try std.testing.expect(!isPrime(0));
    try std.testing.expect(!isPrime(1));
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(17));
    try std.testing.expect(!isPrime(18));
    try std.testing.expect(isPrime(999983));
}

test "gcd and lcm" {
    try std.testing.expectEqual(@as(u64, 6), gcd(12, 18));
    try std.testing.expectEqual(@as(u64, 36), lcm(12, 18));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
    try std.testing.expectEqual(@as(u64, 1), factorial(1));
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
    try std.testing.expectEqual(@as(u64, 3628800), factorial(10));
}

test "binomial" {
    try std.testing.expectEqual(@as(u64, 1), binomial(5, 0));
    try std.testing.expectEqual(@as(u64, 10), binomial(5, 2));
    try std.testing.expectEqual(@as(u64, 1), binomial(5, 5));
}

test "pow" {
    try std.testing.expectEqual(@as(i64, 1), pow(2, 0));
    try std.testing.expectEqual(@as(i64, 8), pow(2, 3));
    try std.testing.expectEqual(@as(i64, 27), pow(3, 3));
}
