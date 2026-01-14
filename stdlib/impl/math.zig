// ============================================================================
// VIBEE STDLIB - MATH MODULE
// Mathematical functions, constants, and utilities
// Generated from stdlib/math.vibee specification
// ============================================================================

const std = @import("std");
const math = std.math;

// ============================================================================
// CONSTANTS
// ============================================================================

/// Pi (π)
pub const PI: f64 = 3.141592653589793;

/// Tau (τ = 2π)
pub const TAU: f64 = 6.283185307179586;

/// Euler's number (e)
pub const E: f64 = 2.718281828459045;

/// Golden ratio (φ)
pub const PHI: f64 = 1.618033988749895;

/// Inverse golden ratio (1/φ = φ - 1)
pub const PHI_INV: f64 = 0.618033988749895;

/// Creation Pattern asymmetry coefficient
pub const CREATION_ASYMMETRY: f64 = 0.5;

/// Square root of 2
pub const SQRT2: f64 = 1.4142135623730951;

/// Square root of 3
pub const SQRT3: f64 = 1.7320508075688772;

/// Natural log of 2
pub const LN2: f64 = 0.6931471805599453;

/// Natural log of 10
pub const LN10: f64 = 2.302585092994046;

/// Log base 2 of e
pub const LOG2E: f64 = 1.4426950408889634;

/// Log base 10 of e
pub const LOG10E: f64 = 0.4342944819032518;

/// Positive infinity
pub const INFINITY: f64 = math.inf(f64);

/// Negative infinity
pub const NEG_INFINITY: f64 = -math.inf(f64);

/// Not a Number
pub const NAN: f64 = math.nan(f64);

/// Machine epsilon
pub const EPSILON: f64 = 2.220446049250313e-16;

/// Maximum float value
pub const MAX_FLOAT: f64 = math.floatMax(f64);

/// Minimum positive float value
pub const MIN_POSITIVE: f64 = math.floatMin(f64);

// ============================================================================
// BASIC FUNCTIONS
// ============================================================================

/// Absolute value (float)
pub fn abs(x: f64) f64 {
    return @abs(x);
}

/// Absolute value (int)
pub fn absInt(x: i64) i64 {
    return if (x < 0) -x else x;
}

/// Sign of number (-1, 0, or 1)
pub fn sign(x: f64) i32 {
    if (x > 0.0) return 1;
    if (x < 0.0) return -1;
    return 0;
}

/// Copy sign from y to x
pub fn copysign(x: f64, y: f64) f64 {
    return math.copysign(x, y);
}

/// Minimum of two values
pub fn min(a: f64, b: f64) f64 {
    return @min(a, b);
}

/// Maximum of two values
pub fn max(a: f64, b: f64) f64 {
    return @max(a, b);
}

/// Clamp value to range
pub fn clamp(x: f64, lo: f64, hi: f64) f64 {
    return @max(lo, @min(hi, x));
}

// ============================================================================
// ROUNDING FUNCTIONS
// ============================================================================

/// Floor - largest integer <= x
pub fn floor(x: f64) f64 {
    return @floor(x);
}

/// Ceiling - smallest integer >= x
pub fn ceil(x: f64) f64 {
    return @ceil(x);
}

/// Round to nearest integer
pub fn round(x: f64) f64 {
    return @round(x);
}

/// Truncate toward zero
pub fn trunc(x: f64) f64 {
    return @trunc(x);
}

/// Fractional part
pub fn fract(x: f64) f64 {
    return x - @trunc(x);
}

// ============================================================================
// POWER AND ROOT FUNCTIONS
// ============================================================================

/// Square root
pub fn sqrt(x: f64) f64 {
    return @sqrt(x);
}

/// Cube root
pub fn cbrt(x: f64) f64 {
    return math.cbrt(x);
}

/// Power function
pub fn pow(base: f64, exponent: f64) f64 {
    return math.pow(f64, base, exponent);
}

/// Square
pub fn square(x: f64) f64 {
    return x * x;
}

/// Cube
pub fn cube(x: f64) f64 {
    return x * x * x;
}

/// Hypotenuse (sqrt(x² + y²))
pub fn hypot(x: f64, y: f64) f64 {
    return math.hypot(x, y);
}

// ============================================================================
// EXPONENTIAL AND LOGARITHMIC FUNCTIONS
// ============================================================================

/// Natural exponential (e^x)
pub fn exp(x: f64) f64 {
    return @exp(x);
}

/// Base-2 exponential (2^x)
pub fn exp2(x: f64) f64 {
    return @exp2(x);
}

/// Natural logarithm
pub fn ln(x: f64) f64 {
    return @log(x);
}

/// Base-2 logarithm
pub fn log2(x: f64) f64 {
    return @log2(x);
}

/// Base-10 logarithm
pub fn log10(x: f64) f64 {
    return @log10(x);
}

/// Logarithm with arbitrary base
pub fn log(x: f64, base: f64) f64 {
    return @log(x) / @log(base);
}

// ============================================================================
// TRIGONOMETRIC FUNCTIONS
// ============================================================================

/// Sine
pub fn sin(x: f64) f64 {
    return @sin(x);
}

/// Cosine
pub fn cos(x: f64) f64 {
    return @cos(x);
}

/// Tangent
pub fn tan(x: f64) f64 {
    return @tan(x);
}

/// Arcsine
pub fn asin(x: f64) f64 {
    return math.asin(x);
}

/// Arccosine
pub fn acos(x: f64) f64 {
    return math.acos(x);
}

/// Arctangent
pub fn atan(x: f64) f64 {
    return math.atan(x);
}

/// Two-argument arctangent
pub fn atan2(y: f64, x: f64) f64 {
    return math.atan2(y, x);
}

// ============================================================================
// HYPERBOLIC FUNCTIONS
// ============================================================================

/// Hyperbolic sine
pub fn sinh(x: f64) f64 {
    return math.sinh(x);
}

/// Hyperbolic cosine
pub fn cosh(x: f64) f64 {
    return math.cosh(x);
}

/// Hyperbolic tangent
pub fn tanh(x: f64) f64 {
    return math.tanh(x);
}

/// Inverse hyperbolic sine
pub fn asinh(x: f64) f64 {
    return math.asinh(x);
}

/// Inverse hyperbolic cosine
pub fn acosh(x: f64) f64 {
    return math.acosh(x);
}

/// Inverse hyperbolic tangent
pub fn atanh(x: f64) f64 {
    return math.atanh(x);
}

// ============================================================================
// ANGLE CONVERSION
// ============================================================================

/// Convert degrees to radians
pub fn toRadians(degrees: f64) f64 {
    return degrees * PI / 180.0;
}

/// Convert radians to degrees
pub fn toDegrees(radians: f64) f64 {
    return radians * 180.0 / PI;
}

// ============================================================================
// SPECIAL FUNCTIONS
// ============================================================================

/// Factorial
pub fn factorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

/// Greatest common divisor
pub fn gcd(a: i64, b: i64) i64 {
    var x = absInt(a);
    var y = absInt(b);
    while (y != 0) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    return x;
}

/// Least common multiple
pub fn lcm(a: i64, b: i64) i64 {
    if (a == 0 or b == 0) return 0;
    return @divExact(absInt(a), gcd(a, b)) * absInt(b);
}

/// Check if number is prime
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

/// Fibonacci number
pub fn fibonacci(n: u32) u64 {
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

// ============================================================================
// FLOATING POINT UTILITIES
// ============================================================================

/// Check if value is NaN
pub fn isNan(x: f64) bool {
    return math.isNan(x);
}

/// Check if value is infinite
pub fn isInf(x: f64) bool {
    return math.isInf(x);
}

/// Check if value is finite
pub fn isFinite(x: f64) bool {
    return !math.isNan(x) and !math.isInf(x);
}

/// Check if two floats are approximately equal
pub fn approxEqual(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) <= tolerance;
}

// ============================================================================
// LINEAR INTERPOLATION
// ============================================================================

/// Linear interpolation between a and b
pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * t;
}

/// Inverse linear interpolation
pub fn inverseLerp(a: f64, b: f64, value: f64) f64 {
    return (value - a) / (b - a);
}

/// Remap value from one range to another
pub fn remap(value: f64, from_min: f64, from_max: f64, to_min: f64, to_max: f64) f64 {
    const t = inverseLerp(from_min, from_max, value);
    return lerp(to_min, to_max, t);
}

// ============================================================================
// TESTS
// ============================================================================

test "constants" {
    try std.testing.expect(PI > 3.14 and PI < 3.15);
    try std.testing.expect(E > 2.71 and E < 2.72);
    try std.testing.expect(PHI > 1.61 and PHI < 1.62);
}

test "abs" {
    try std.testing.expectEqual(@as(f64, 5.0), abs(-5.0));
    try std.testing.expectEqual(@as(f64, 5.0), abs(5.0));
    try std.testing.expectEqual(@as(i64, 5), absInt(-5));
}

test "sign" {
    try std.testing.expectEqual(@as(i32, 1), sign(5.0));
    try std.testing.expectEqual(@as(i32, -1), sign(-5.0));
    try std.testing.expectEqual(@as(i32, 0), sign(0.0));
}

test "min max clamp" {
    try std.testing.expectEqual(@as(f64, 3.0), min(3.0, 5.0));
    try std.testing.expectEqual(@as(f64, 5.0), max(3.0, 5.0));
    try std.testing.expectEqual(@as(f64, 5.0), clamp(3.0, 5.0, 10.0));
    try std.testing.expectEqual(@as(f64, 10.0), clamp(15.0, 5.0, 10.0));
}

test "rounding" {
    try std.testing.expectEqual(@as(f64, 3.0), floor(3.7));
    try std.testing.expectEqual(@as(f64, 4.0), ceil(3.2));
    try std.testing.expectEqual(@as(f64, 4.0), round(3.5));
}

test "power functions" {
    try std.testing.expect(approxEqual(sqrt(4.0), 2.0, EPSILON));
    try std.testing.expect(approxEqual(pow(2.0, 3.0), 8.0, EPSILON));
    try std.testing.expectEqual(@as(f64, 9.0), square(3.0));
}

test "trigonometry" {
    try std.testing.expect(approxEqual(sin(0.0), 0.0, EPSILON));
    try std.testing.expect(approxEqual(cos(0.0), 1.0, EPSILON));
    try std.testing.expect(approxEqual(sin(PI / 2.0), 1.0, EPSILON));
}

test "angle conversion" {
    try std.testing.expect(approxEqual(toRadians(180.0), PI, EPSILON));
    try std.testing.expect(approxEqual(toDegrees(PI), 180.0, EPSILON));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
    try std.testing.expectEqual(@as(u64, 1), factorial(1));
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
}

test "gcd lcm" {
    try std.testing.expectEqual(@as(i64, 6), gcd(12, 18));
    try std.testing.expectEqual(@as(i64, 36), lcm(12, 18));
}

test "isPrime" {
    try std.testing.expect(!isPrime(1));
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(17));
    try std.testing.expect(!isPrime(18));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "lerp" {
    try std.testing.expectEqual(@as(f64, 5.0), lerp(0.0, 10.0, 0.5));
    try std.testing.expectEqual(@as(f64, 0.5), inverseLerp(0.0, 10.0, 5.0));
}
