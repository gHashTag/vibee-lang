// ═══════════════════════════════════════════════════════════════════════════════
// IGLA PYTHON BINDINGS (C ABI for ctypes)
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS (exported)
// ═══════════════════════════════════════════════════════════════════════════════

pub export const IGLA_PHI: f64 = 1.618033988749895;
pub export const IGLA_TRINITY: i64 = 3;
pub export const IGLA_PHOENIX: i64 = 999;
pub export const IGLA_SPEED_OF_LIGHT: i64 = 299792458;

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub export fn igla_version_major() i32 {
    return 3;
}

pub export fn igla_version_minor() i32 {
    return 0;
}

pub export fn igla_version_patch() i32 {
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI PARSER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriParseResult = extern struct {
    entries: i64,
    keys: i64,
    values: i64,
    bytes_parsed: i64,
    success: i32,
};

pub export fn igla_tri_parse(source: [*]const u8, len: usize) TriParseResult {
    const data = source[0..len];
    
    var entries: i64 = 0;
    var keys: i64 = 0;
    var values: i64 = 0;
    var pos: usize = 0;
    
    while (pos < data.len) {
        // Skip whitespace
        while (pos < data.len and (data[pos] == ' ' or data[pos] == '\t')) {
            pos += 1;
        }
        if (pos >= data.len) break;
        
        // Skip comments
        if (data[pos] == '#') {
            while (pos < data.len and data[pos] != '\n') {
                pos += 1;
            }
            if (pos < data.len) pos += 1;
            continue;
        }
        
        // Parse key
        const key_start = pos;
        while (pos < data.len and data[pos] != ':' and data[pos] != '\n') {
            pos += 1;
        }
        
        if (pos > key_start) {
            keys += 1;
        }
        
        // Skip colon and parse value
        if (pos < data.len and data[pos] == ':') {
            pos += 1;
            while (pos < data.len and (data[pos] == ' ' or data[pos] == '\t')) {
                pos += 1;
            }
            
            const value_start = pos;
            while (pos < data.len and data[pos] != '\n') {
                pos += 1;
            }
            
            if (pos > value_start) {
                values += 1;
            }
            
            entries += 1;
        }
        
        // Skip to next line
        while (pos < data.len and data[pos] != '\n') {
            pos += 1;
        }
        if (pos < data.len) pos += 1;
    }
    
    return .{
        .entries = entries,
        .keys = keys,
        .values = values,
        .bytes_parsed = @intCast(pos),
        .success = 1,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATH FUNCTIONS (optimized)
// ═══════════════════════════════════════════════════════════════════════════════

pub export fn igla_fibonacci(n: i64) i64 {
    if (n <= 1) return n;
    var a: i64 = 0;
    var b: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

pub export fn igla_factorial(n: i64) i64 {
    if (n <= 1) return 1;
    var result: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

pub export fn igla_sum_to_n(n: i64) i64 {
    // Using formula: n * (n + 1) / 2
    return @divTrunc(n * (n + 1), 2);
}

pub export fn igla_is_prime(n: i64) i32 {
    if (n <= 1) return 0;
    if (n <= 3) return 1;
    if (@mod(n, 2) == 0 or @mod(n, 3) == 0) return 0;
    
    var i: i64 = 5;
    while (i * i <= n) {
        if (@mod(n, i) == 0 or @mod(n, i + 2) == 0) return 0;
        i += 6;
    }
    return 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN RATIO FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub export fn igla_golden_identity() f64 {
    // φ² + 1/φ² = 3
    const phi_sq = IGLA_PHI * IGLA_PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    return phi_sq + inv_phi_sq;
}

pub export fn igla_phi_power(n: i32) f64 {
    var result: f64 = 1.0;
    var i: i32 = 0;
    while (i < n) : (i += 1) {
        result *= IGLA_PHI;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARRAY OPERATIONS (SIMD-friendly)
// ═══════════════════════════════════════════════════════════════════════════════

pub export fn igla_array_sum(arr: [*]const i64, len: usize) i64 {
    var sum: i64 = 0;
    for (arr[0..len]) |val| {
        sum += val;
    }
    return sum;
}

pub export fn igla_array_max(arr: [*]const i64, len: usize) i64 {
    if (len == 0) return 0;
    var max_val = arr[0];
    for (arr[1..len]) |val| {
        if (val > max_val) max_val = val;
    }
    return max_val;
}

pub export fn igla_array_min(arr: [*]const i64, len: usize) i64 {
    if (len == 0) return 0;
    var min_val = arr[0];
    for (arr[1..len]) |val| {
        if (val < min_val) min_val = val;
    }
    return min_val;
}

pub export fn igla_dot_product(a: [*]const f64, b: [*]const f64, len: usize) f64 {
    var sum: f64 = 0.0;
    for (0..len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "fibonacci" {
    try std.testing.expectEqual(@as(i64, 55), igla_fibonacci(10));
    try std.testing.expectEqual(@as(i64, 6765), igla_fibonacci(20));
}

test "factorial" {
    try std.testing.expectEqual(@as(i64, 120), igla_factorial(5));
    try std.testing.expectEqual(@as(i64, 3628800), igla_factorial(10));
}

test "golden_identity" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), igla_golden_identity(), 0.0001);
}

test "is_prime" {
    try std.testing.expectEqual(@as(i32, 1), igla_is_prime(7));
    try std.testing.expectEqual(@as(i32, 1), igla_is_prime(37));
    try std.testing.expectEqual(@as(i32, 0), igla_is_prime(4));
}
