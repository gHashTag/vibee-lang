// TVC BigInt - Balanced Ternary Arbitrary Precision Arithmetic
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3
//
// Balanced Ternary representation:
// - Each trit has value {-1, 0, +1}
// - Number = Σ(trit[i] × 3^i) for i = 0..n-1
// - No separate sign bit needed (inherent in representation)
// - Rounding is simpler (truncation = rounding to nearest)

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum trits for BigInt (supports numbers up to 3^256 ≈ 10^122)
pub const MAX_TRITS = 256;

/// Trit type: -1, 0, or +1
pub const Trit = i8;
pub const NEG: Trit = -1;
pub const ZERO: Trit = 0;
pub const POS: Trit = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD TYPES AND OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD vector for 32 trits (256 bits = AVX2)
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);

/// Number of SIMD chunks in BigInt (256 / 32 = 8)
pub const SIMD_CHUNKS = MAX_TRITS / 32;

/// SIMD add without carry (parallel addition of 32 trits)
/// Returns sum and overflow mask
pub fn simdAddTrits(a: Vec32i8, b: Vec32i8) struct { sum: Vec32i8, overflow: Vec32i8 } {
    // Widen to i16 for overflow detection
    const a_wide: Vec32i16 = a;
    const b_wide: Vec32i16 = b;
    
    // Add
    const sum_wide = a_wide + b_wide;
    
    // Detect overflow (values outside -1..+1)
    // overflow = (sum > 1) - (sum < -1)
    const ones: Vec32i16 = @splat(1);
    const neg_ones: Vec32i16 = @splat(-1);
    const threes: Vec32i16 = @splat(3);
    
    // Normalize: bring values back to -1..+1 range
    var normalized = sum_wide;
    
    // If sum > 1, subtract 3 and carry +1
    // If sum < -1, add 3 and carry -1
    const high_mask = sum_wide > ones;
    const low_mask = sum_wide < neg_ones;
    
    // Apply normalization
    normalized = @select(i16, high_mask, sum_wide - threes, normalized);
    normalized = @select(i16, low_mask, sum_wide + threes, normalized);
    
    // Calculate carry: +1 for high overflow, -1 for low overflow
    var carry: Vec32i16 = @splat(0);
    carry = @select(i16, high_mask, ones, carry);
    carry = @select(i16, low_mask, neg_ones, carry);
    
    // Truncate back to i8
    var sum_result: Vec32i8 = undefined;
    var carry_result: Vec32i8 = undefined;
    
    inline for (0..32) |i| {
        sum_result[i] = @intCast(normalized[i]);
        carry_result[i] = @intCast(carry[i]);
    }
    
    return .{ .sum = sum_result, .overflow = carry_result };
}

/// SIMD compare (returns -1 if a < b, 0 if equal, +1 if a > b for each element)
pub fn simdCompareTrits(a: Vec32i8, b: Vec32i8) Vec32i8 {
    const gt_mask = a > b;
    const lt_mask = a < b;
    
    var result: Vec32i8 = @splat(0);
    result = @select(i8, gt_mask, @as(Vec32i8, @splat(1)), result);
    result = @select(i8, lt_mask, @as(Vec32i8, @splat(-1)), result);
    
    return result;
}

/// Check if SIMD vector is all zeros
pub fn simdIsZero(v: Vec32i8) bool {
    return @reduce(.Or, v != @as(Vec32i8, @splat(0))) == false;
}

/// SIMD horizontal sum (reduce)
pub fn simdSum(v: Vec32i8) i32 {
    var sum: i32 = 0;
    inline for (0..32) |i| {
        sum += v[i];
    }
    return sum;
}

/// SIMD normalize: bring all values to -1..+1 range
/// Returns normalized vector and carry vector
pub fn simdNormalize(v: Vec32i8) struct { normalized: Vec32i8, carry: Vec32i8 } {
    var result: Vec32i8 = undefined;
    var carry: Vec32i8 = @splat(0);
    
    inline for (0..32) |i| {
        var val: i16 = v[i];
        var c: i8 = 0;
        
        while (val > 1) {
            val -= 3;
            c += 1;
        }
        while (val < -1) {
            val += 3;
            c -= 1;
        }
        
        result[i] = @intCast(val);
        carry[i] = c;
    }
    
    return .{ .normalized = result, .carry = carry };
}

/// SIMD negate: flip all signs
pub fn simdNegate(v: Vec32i8) Vec32i8 {
    const zeros: Vec32i8 = @splat(0);
    return zeros - v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TVC BIGINT STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

/// Balanced Ternary BigInt
/// Stores number as array of trits (least significant first)
pub const TVCBigInt = struct {
    /// Trits array (LST first)
    trits: [MAX_TRITS]Trit,
    /// Number of significant trits
    len: usize,
    
    const Self = @This();
    
    /// Create zero
    pub fn zero() Self {
        return Self{
            .trits = [_]Trit{0} ** MAX_TRITS,
            .len = 1,
        };
    }
    
    /// Create from i64
    pub fn fromI64(value: i64) Self {
        var result = Self.zero();
        if (value == 0) return result;
        
        var v = value;
        var i: usize = 0;
        
        while (v != 0 and i < MAX_TRITS) {
            // Get remainder in range -1..1
            var rem = @mod(v, @as(i64, 3));
            if (rem == 2) rem = -1;
            
            result.trits[i] = @intCast(rem);
            
            // Adjust v for next iteration
            v = @divFloor(v - rem, 3);
            i += 1;
        }
        
        result.len = if (i == 0) 1 else i;
        result.normalize();
        return result;
    }
    
    /// Convert to i64 (may overflow for large numbers)
    pub fn toI64(self: *const Self) i64 {
        var result: i64 = 0;
        var power: i64 = 1;
        
        for (0..self.len) |i| {
            result += @as(i64, self.trits[i]) * power;
            power *= 3;
        }
        
        return result;
    }
    
    /// Normalize: remove leading zeros
    fn normalize(self: *Self) void {
        while (self.len > 1 and self.trits[self.len - 1] == 0) {
            self.len -= 1;
        }
    }
    
    /// Check if zero
    pub fn isZero(self: *const Self) bool {
        return self.len == 1 and self.trits[0] == 0;
    }
    
    /// Check if negative
    pub fn isNegative(self: *const Self) bool {
        // In balanced ternary, sign is determined by most significant trit
        return self.trits[self.len - 1] < 0;
    }
    
    /// Negate (flip all trits)
    pub fn negate(self: *const Self) Self {
        var result = self.*;
        for (0..result.len) |i| {
            result.trits[i] = -result.trits[i];
        }
        return result;
    }
    
    /// Absolute value
    pub fn abs(self: *const Self) Self {
        if (self.isNegative()) {
            return self.negate();
        }
        return self.*;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // ADDITION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Add two BigInts (scalar version)
    pub fn addScalar(a: *const Self, b: *const Self) Self {
        var result = Self.zero();
        var carry: Trit = 0;
        
        const max_len = @max(a.len, b.len);
        
        for (0..max_len + 1) |i| {
            if (i >= MAX_TRITS) break;
            
            const a_trit: i16 = if (i < a.len) a.trits[i] else 0;
            const b_trit: i16 = if (i < b.len) b.trits[i] else 0;
            
            var sum: i16 = a_trit + b_trit + carry;
            carry = 0;
            
            // Normalize to balanced ternary
            while (sum > 1) {
                sum -= 3;
                carry += 1;
            }
            while (sum < -1) {
                sum += 3;
                carry -= 1;
            }
            
            result.trits[i] = @intCast(sum);
            result.len = i + 1;
        }
        
        result.normalize();
        return result;
    }
    
    /// Add two BigInts using SIMD (32 trits at a time)
    /// Optimized version: batch load/store, minimal carry propagation
    pub fn addSIMD(a: *const Self, b: *const Self) Self {
        var result = Self.zero();
        const max_len = @max(a.len, b.len);
        const num_chunks = (max_len + 31) / 32;
        
        // First pass: parallel add without carry propagation
        for (0..num_chunks) |chunk| {
            const offset = chunk * 32;
            
            // Load 32 trits using pointer arithmetic
            var a_vec: Vec32i8 = undefined;
            var b_vec: Vec32i8 = undefined;
            
            inline for (0..32) |i| {
                a_vec[i] = if (offset + i < a.len) a.trits[offset + i] else 0;
                b_vec[i] = if (offset + i < b.len) b.trits[offset + i] else 0;
            }
            
            // Simple vector add (may produce values outside -1..+1)
            const sum_vec = a_vec + b_vec;
            
            // Store intermediate result
            inline for (0..32) |i| {
                if (offset + i < MAX_TRITS) {
                    result.trits[offset + i] = sum_vec[i];
                }
            }
        }
        
        // Second pass: sequential carry propagation (unavoidable for correctness)
        var carry: i8 = 0;
        for (0..max_len + 1) |i| {
            if (i >= MAX_TRITS) break;
            
            var val: i16 = @as(i16, result.trits[i]) + carry;
            carry = 0;
            
            while (val > 1) {
                val -= 3;
                carry += 1;
            }
            while (val < -1) {
                val += 3;
                carry -= 1;
            }
            
            result.trits[i] = @intCast(val);
        }
        
        result.len = max_len + 1;
        result.normalize();
        return result;
    }
    
    /// Add two BigInts (uses SIMD for large numbers)
    pub fn add(a: *const Self, b: *const Self) Self {
        // Use SIMD for larger numbers (threshold: 64 trits)
        if (a.len >= 64 or b.len >= 64) {
            return a.addSIMD(b);
        }
        return a.addScalar(b);
    }
    
    /// Subtract: a - b = a + (-b)
    pub fn sub(a: *const Self, b: *const Self) Self {
        const neg_b = b.negate();
        return a.add(&neg_b);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MULTIPLICATION (Karatsuba Algorithm)
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Simple multiplication (grade school algorithm)
    /// Used for small numbers or as base case for Karatsuba
    pub fn mulSimple(a: *const Self, b: *const Self) Self {
        var result = Self.zero();
        
        for (0..a.len) |i| {
            if (a.trits[i] == 0) continue;
            
            var partial = Self.zero();
            var carry: Trit = 0;
            
            for (0..b.len) |j| {
                if (i + j >= MAX_TRITS) break;
                
                var prod: i16 = @as(i16, a.trits[i]) * @as(i16, b.trits[j]) + carry;
                carry = 0;
                
                // Normalize
                while (prod > 1) {
                    prod -= 3;
                    carry += 1;
                }
                while (prod < -1) {
                    prod += 3;
                    carry -= 1;
                }
                
                partial.trits[i + j] = @intCast(prod);
                partial.len = @max(partial.len, i + j + 1);
            }
            
            // Handle final carry
            if (carry != 0 and i + b.len < MAX_TRITS) {
                partial.trits[i + b.len] = carry;
                partial.len = @max(partial.len, i + b.len + 1);
            }
            
            result = result.add(&partial);
        }
        
        result.normalize();
        return result;
    }
    
    /// Karatsuba multiplication for large numbers
    /// Complexity: O(n^1.585) vs O(n^2) for simple multiplication
    pub fn mulKaratsuba(a: *const Self, b: *const Self) Self {
        // Base case: use simple multiplication for small numbers
        const threshold = 32;
        if (a.len <= threshold or b.len <= threshold) {
            return a.mulSimple(b);
        }
        
        // Split numbers at midpoint
        const m = @max(a.len, b.len) / 2;
        
        // a = a1 * 3^m + a0
        // b = b1 * 3^m + b0
        var a0 = Self.zero();
        var a1 = Self.zero();
        var b0 = Self.zero();
        var b1 = Self.zero();
        
        // Split a
        for (0..@min(m, a.len)) |i| {
            a0.trits[i] = a.trits[i];
        }
        a0.len = @min(m, a.len);
        a0.normalize();
        
        if (a.len > m) {
            for (m..a.len) |i| {
                a1.trits[i - m] = a.trits[i];
            }
            a1.len = a.len - m;
            a1.normalize();
        }
        
        // Split b
        for (0..@min(m, b.len)) |i| {
            b0.trits[i] = b.trits[i];
        }
        b0.len = @min(m, b.len);
        b0.normalize();
        
        if (b.len > m) {
            for (m..b.len) |i| {
                b1.trits[i - m] = b.trits[i];
            }
            b1.len = b.len - m;
            b1.normalize();
        }
        
        // Karatsuba: 3 multiplications instead of 4
        // z0 = a0 * b0
        // z2 = a1 * b1
        // z1 = (a0 + a1) * (b0 + b1) - z0 - z2
        const z0 = a0.mulKaratsuba(&b0);
        const z2 = a1.mulKaratsuba(&b1);
        
        const a_sum = a0.add(&a1);
        const b_sum = b0.add(&b1);
        var z1 = a_sum.mulKaratsuba(&b_sum);
        z1 = z1.sub(&z0);
        z1 = z1.sub(&z2);
        
        // Result = z0 + z1 * 3^m + z2 * 3^(2m)
        var result = z0;
        
        // Add z1 * 3^m (shift left by m trits)
        var z1_shifted = Self.zero();
        for (0..z1.len) |i| {
            if (i + m < MAX_TRITS) {
                z1_shifted.trits[i + m] = z1.trits[i];
            }
        }
        z1_shifted.len = @min(z1.len + m, MAX_TRITS);
        result = result.add(&z1_shifted);
        
        // Add z2 * 3^(2m) (shift left by 2m trits)
        var z2_shifted = Self.zero();
        for (0..z2.len) |i| {
            if (i + 2 * m < MAX_TRITS) {
                z2_shifted.trits[i + 2 * m] = z2.trits[i];
            }
        }
        z2_shifted.len = @min(z2.len + 2 * m, MAX_TRITS);
        result = result.add(&z2_shifted);
        
        result.normalize();
        return result;
    }
    
    /// Multiply (uses Karatsuba for large numbers)
    pub fn mul(a: *const Self, b: *const Self) Self {
        return a.mulKaratsuba(b);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DIVISION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Compare absolute values (scalar version)
    /// Returns: -1 if |a| < |b|, 0 if |a| == |b|, 1 if |a| > |b|
    fn compareAbsScalar(a: *const Self, b: *const Self) i8 {
        const a_abs = a.abs();
        const b_abs = b.abs();
        
        if (a_abs.len != b_abs.len) {
            return if (a_abs.len < b_abs.len) -1 else 1;
        }
        
        // Compare from most significant trit
        var i = a_abs.len;
        while (i > 0) {
            i -= 1;
            if (a_abs.trits[i] != b_abs.trits[i]) {
                return if (a_abs.trits[i] < b_abs.trits[i]) -1 else 1;
            }
        }
        
        return 0;
    }
    
    /// Compare absolute values using SIMD
    /// Returns: -1 if |a| < |b|, 0 if |a| == |b|, 1 if |a| > |b|
    fn compareAbsSIMD(a: *const Self, b: *const Self) i8 {
        const a_abs = a.abs();
        const b_abs = b.abs();
        
        // Quick length check
        if (a_abs.len != b_abs.len) {
            return if (a_abs.len < b_abs.len) -1 else 1;
        }
        
        // Compare chunks from most significant to least
        var chunk: usize = SIMD_CHUNKS;
        while (chunk > 0) {
            chunk -= 1;
            const offset: usize = chunk * 32;
            
            // Skip chunks beyond actual length
            if (offset >= a_abs.len) continue;
            
            // Load 32 trits
            var a_vec: Vec32i8 = undefined;
            var b_vec: Vec32i8 = undefined;
            
            inline for (0..32) |i| {
                a_vec[i] = if (offset + i < a_abs.len) a_abs.trits[offset + i] else 0;
                b_vec[i] = if (offset + i < b_abs.len) b_abs.trits[offset + i] else 0;
            }
            
            // SIMD compare
            const cmp = simdCompareTrits(a_vec, b_vec);
            
            // Check from most significant position in chunk
            var pos: usize = 32;
            while (pos > 0) {
                pos -= 1;
                if (cmp[pos] != 0) {
                    return cmp[pos];
                }
            }
        }
        
        return 0;
    }
    
    /// Compare absolute values (uses SIMD for large numbers)
    pub fn compareAbs(a: *const Self, b: *const Self) i8 {
        if (a.len >= 64 or b.len >= 64) {
            return a.compareAbsSIMD(b);
        }
        return a.compareAbsScalar(b);
    }
    
    /// Result type for division
    pub const DivResult = struct { q: Self, r: Self };
    
    /// Division with remainder using simple repeated subtraction
    /// Returns (quotient, remainder) such that a = quotient * b + remainder
    /// For balanced ternary, we use a simpler approach: convert to i64, divide, convert back
    /// This works for numbers that fit in i64. For larger numbers, use divRemLarge.
    pub fn divRem(a: *const Self, b: *const Self) DivResult {
        // Handle division by zero
        if (b.isZero()) {
            return .{ .q = Self.zero(), .r = Self.zero() };
        }
        
        // For numbers that fit in i64, use native division
        if (a.len <= 40 and b.len <= 40) {
            const a_val = a.toI64();
            const b_val = b.toI64();
            
            if (b_val == 0) {
                return .{ .q = Self.zero(), .r = Self.zero() };
            }
            
            const q_val = @divTrunc(a_val, b_val);
            const r_val = @rem(a_val, b_val);
            
            return .{ 
                .q = Self.fromI64(q_val), 
                .r = Self.fromI64(r_val) 
            };
        }
        
        // For larger numbers, use long division
        return a.divRemLarge(b);
    }
    
    /// Long division for large numbers (beyond i64 range)
    fn divRemLarge(a: *const Self, b: *const Self) DivResult {
        // Handle a < b
        const cmp = a.abs().compareAbs(&b.abs());
        if (cmp < 0) {
            return .{ .q = Self.zero(), .r = a.* };
        }
        if (cmp == 0) {
            // a == b or a == -b
            if (a.isNegative() == b.isNegative()) {
                return .{ .q = Self.fromI64(1), .r = Self.zero() };
            } else {
                return .{ .q = Self.fromI64(-1), .r = Self.zero() };
            }
        }
        
        // Determine signs
        const a_neg = a.isNegative();
        const b_neg = b.isNegative();
        const result_neg = a_neg != b_neg;
        
        // Work with absolute values
        var remainder = a.abs();
        const divisor = b.abs();
        var quotient = Self.zero();
        
        // Find the scale: how many positions to shift divisor
        // to align with dividend's most significant trit
        var scale: usize = 0;
        if (remainder.len > divisor.len) {
            scale = remainder.len - divisor.len;
        }
        
        // Shift divisor left by scale positions
        var shifted_divisor = Self.zero();
        for (0..divisor.len) |i| {
            if (i + scale < MAX_TRITS) {
                shifted_divisor.trits[i + scale] = divisor.trits[i];
            }
        }
        shifted_divisor.len = @min(divisor.len + scale, MAX_TRITS);
        
        // Long division: for each position from scale down to 0
        var pos: usize = scale + 1;
        while (pos > 0) {
            pos -= 1;
            
            // Shift divisor to current position
            shifted_divisor = Self.zero();
            for (0..divisor.len) |i| {
                if (i + pos < MAX_TRITS) {
                    shifted_divisor.trits[i + pos] = divisor.trits[i];
                }
            }
            shifted_divisor.len = @min(divisor.len + pos, MAX_TRITS);
            shifted_divisor.normalize();
            
            // Find quotient trit at this position
            // In balanced ternary, try +1, 0, -1
            var q_trit: Trit = 0;
            
            // Try +1: if remainder >= shifted_divisor
            if (!remainder.isNegative() and remainder.compareAbs(&shifted_divisor) >= 0) {
                const test_sub = remainder.sub(&shifted_divisor);
                // Check if subtraction brings us closer to zero
                if (test_sub.abs().compareAbs(&remainder.abs()) <= 0) {
                    q_trit = 1;
                    remainder = test_sub;
                }
            }
            
            // Try -1: if remainder is negative or if -1 brings us closer
            if (q_trit == 0 and remainder.isNegative()) {
                const test_add = remainder.add(&shifted_divisor);
                if (test_add.abs().compareAbs(&remainder.abs()) < 0) {
                    q_trit = -1;
                    remainder = test_add;
                }
            }
            
            // Set quotient trit
            quotient.trits[pos] = q_trit;
            if (pos >= quotient.len and q_trit != 0) {
                quotient.len = pos + 1;
            }
        }
        
        quotient.normalize();
        remainder.normalize();
        
        // Adjust signs
        if (result_neg) {
            quotient = quotient.negate();
        }
        if (a_neg and !remainder.isZero()) {
            remainder = remainder.negate();
        }
        
        return .{ .q = quotient, .r = remainder };
    }
    
    /// Division (quotient only)
    pub fn div(a: *const Self, b: *const Self) Self {
        return a.divRem(b).q;
    }
    
    /// Modulo (remainder only)
    pub fn mod(a: *const Self, b: *const Self) Self {
        return a.divRem(b).r;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // NEWTON-RAPHSON DIVISION (for very large numbers)
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Shift left by n trits (multiply by 3^n)
    pub fn shiftLeft(self: *const Self, n: usize) Self {
        if (n == 0) return self.*;
        
        var result = Self.zero();
        for (0..self.len) |i| {
            if (i + n < MAX_TRITS) {
                result.trits[i + n] = self.trits[i];
            }
        }
        result.len = @min(self.len + n, MAX_TRITS);
        result.normalize();
        return result;
    }
    
    /// Shift right by n trits (divide by 3^n, truncate)
    pub fn shiftRight(self: *const Self, n: usize) Self {
        if (n >= self.len) return Self.zero();
        
        var result = Self.zero();
        for (n..self.len) |i| {
            result.trits[i - n] = self.trits[i];
        }
        result.len = self.len - n;
        result.normalize();
        return result;
    }
    
    /// Newton-Raphson reciprocal approximation
    /// Computes an approximation of 3^precision / b
    /// Uses iteration: x_{n+1} = x_n * (2 - b * x_n / 3^precision)
    pub fn newtonReciprocal(b: *const Self, precision: usize) Self {
        if (b.isZero()) return Self.zero();
        
        const b_abs = b.abs();
        
        // Initial guess: 3^(precision - b.len + 1)
        var x = Self.zero();
        const initial_pos = if (precision > b_abs.len) precision - b_abs.len + 1 else 1;
        if (initial_pos < MAX_TRITS) {
            x.trits[initial_pos] = 1;
            x.len = initial_pos + 1;
        } else {
            x.trits[0] = 1;
            x.len = 1;
        }
        
        // Newton-Raphson iterations
        // x = x * (2 - b * x / 3^precision)
        // Simplified: x = (2 * x * 3^precision - b * x * x) / 3^precision
        const two = Self.fromI64(2);
        const max_iterations: usize = 10;
        
        var iter: usize = 0;
        while (iter < max_iterations) : (iter += 1) {
            // Compute b * x
            const bx = b_abs.mul(&x);
            
            // Compute 2 * 3^precision
            var two_scaled = two.shiftLeft(precision);
            
            // Compute 2 * 3^precision - b * x
            const diff = two_scaled.sub(&bx);
            
            // Compute x * diff / 3^precision
            const x_new = x.mul(&diff).shiftRight(precision);
            
            // Check convergence
            if (x_new.compareAbs(&x) == 0) break;
            
            x = x_new;
        }
        
        // Adjust sign
        if (b.isNegative()) {
            return x.negate();
        }
        return x;
    }
    
    /// Fast division using Newton-Raphson for very large numbers
    /// Computes a / b using reciprocal approximation
    pub fn divNewton(a: *const Self, b: *const Self) DivResult {
        if (b.isZero()) {
            return .{ .q = Self.zero(), .r = Self.zero() };
        }
        
        // For small numbers, use regular division
        if (a.len <= 40 and b.len <= 40) {
            return a.divRem(b);
        }
        
        // Compute precision needed
        const precision = @max(a.len, b.len) + 10;
        
        // Get reciprocal of b
        const recip = newtonReciprocal(b, precision);
        
        // Compute a * recip / 3^precision
        const product = a.mul(&recip);
        var quotient = product.shiftRight(precision);
        
        // Compute remainder: r = a - q * b
        const qb = quotient.mul(b);
        var remainder = a.sub(&qb);
        
        // Adjust if remainder is out of range
        while (!remainder.isZero() and remainder.abs().compareAbs(&b.abs()) >= 0) {
            if (remainder.isNegative() == b.isNegative()) {
                // remainder and b have same sign, subtract b
                remainder = remainder.sub(b);
                quotient = quotient.add(&Self.fromI64(1));
            } else {
                // opposite signs, add b
                remainder = remainder.add(b);
                quotient = quotient.sub(&Self.fromI64(1));
            }
        }
        
        return .{ .q = quotient, .r = remainder };
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // UTILITY
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Format as string (balanced ternary representation)
    pub fn format(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        var buf = try allocator.alloc(u8, self.len + 1);
        
        for (0..self.len) |i| {
            const idx = self.len - 1 - i;
            buf[i] = switch (self.trits[idx]) {
                -1 => 'T', // T for -1 (traditional notation)
                0 => '0',
                1 => '1',
                else => '?',
            };
        }
        buf[self.len] = 0;
        
        return buf[0..self.len];
    }
    
    /// Format as decimal string
    pub fn formatDecimal(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        // For small numbers, use i64
        if (self.len <= 40) { // 3^40 ≈ 10^19 < 2^63
            const val = self.toI64();
            return std.fmt.allocPrint(allocator, "{}", .{val});
        }
        
        // For large numbers, use repeated division by 10
        // (simplified - just return ternary for now)
        return self.format(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BigInt fromI64 and toI64" {
    const cases = [_]i64{ 0, 1, -1, 2, -2, 3, -3, 10, -10, 100, -100, 1000, -1000, 12345, -12345 };
    
    for (cases) |val| {
        const big = TVCBigInt.fromI64(val);
        const back = big.toI64();
        try std.testing.expectEqual(val, back);
    }
}

test "BigInt addition" {
    const a = TVCBigInt.fromI64(123);
    const b = TVCBigInt.fromI64(456);
    const sum = a.add(&b);
    try std.testing.expectEqual(@as(i64, 579), sum.toI64());
    
    const c = TVCBigInt.fromI64(-100);
    const d = TVCBigInt.fromI64(50);
    const diff = c.add(&d);
    try std.testing.expectEqual(@as(i64, -50), diff.toI64());
}

test "BigInt subtraction" {
    const a = TVCBigInt.fromI64(1000);
    const b = TVCBigInt.fromI64(300);
    const diff = a.sub(&b);
    try std.testing.expectEqual(@as(i64, 700), diff.toI64());
}

test "BigInt multiplication simple" {
    const a = TVCBigInt.fromI64(12);
    const b = TVCBigInt.fromI64(34);
    const prod = a.mulSimple(&b);
    try std.testing.expectEqual(@as(i64, 408), prod.toI64());
    
    const c = TVCBigInt.fromI64(-7);
    const d = TVCBigInt.fromI64(8);
    const prod2 = c.mulSimple(&d);
    try std.testing.expectEqual(@as(i64, -56), prod2.toI64());
}

test "BigInt multiplication Karatsuba" {
    const a = TVCBigInt.fromI64(12345);
    const b = TVCBigInt.fromI64(67890);
    const prod = a.mulKaratsuba(&b);
    try std.testing.expectEqual(@as(i64, 838102050), prod.toI64());
}

test "BigInt division" {
    // Simple division test
    const a = TVCBigInt.fromI64(81);
    const b = TVCBigInt.fromI64(9);
    const result = a.divRem(&b);
    try std.testing.expectEqual(@as(i64, 9), result.q.toI64());
    try std.testing.expectEqual(@as(i64, 0), result.r.toI64());
    
    // Division with remainder
    const c = TVCBigInt.fromI64(10);
    const d = TVCBigInt.fromI64(3);
    const result2 = c.divRem(&d);
    // 10 / 3 = 3 remainder 1
    try std.testing.expectEqual(@as(i64, 3), result2.q.toI64());
    try std.testing.expectEqual(@as(i64, 1), result2.r.toI64());
    
    // The problematic case: 100 / 7 = 14 remainder 2
    const e = TVCBigInt.fromI64(100);
    const f = TVCBigInt.fromI64(7);
    const result3 = e.divRem(&f);
    try std.testing.expectEqual(@as(i64, 14), result3.q.toI64());
    try std.testing.expectEqual(@as(i64, 2), result3.r.toI64());
    
    // Negative division: -100 / 7 = -14 remainder -2
    const g = TVCBigInt.fromI64(-100);
    const result4 = g.divRem(&f);
    try std.testing.expectEqual(@as(i64, -14), result4.q.toI64());
    try std.testing.expectEqual(@as(i64, -2), result4.r.toI64());
    
    // Division by negative: 100 / -7 = -14 remainder 2
    const h = TVCBigInt.fromI64(-7);
    const result5 = e.divRem(&h);
    try std.testing.expectEqual(@as(i64, -14), result5.q.toI64());
    try std.testing.expectEqual(@as(i64, 2), result5.r.toI64());
    
    // Large division
    const i_val = TVCBigInt.fromI64(1000000);
    const j_val = TVCBigInt.fromI64(1234);
    const result6 = i_val.divRem(&j_val);
    // 1000000 / 1234 = 810 remainder 460
    try std.testing.expectEqual(@as(i64, 810), result6.q.toI64());
    try std.testing.expectEqual(@as(i64, 460), result6.r.toI64());
}

test "BigInt shift operations" {
    const a = TVCBigInt.fromI64(10);
    
    // Shift left by 2 = multiply by 9
    const shifted_left = a.shiftLeft(2);
    try std.testing.expectEqual(@as(i64, 90), shifted_left.toI64());
    
    // Shift right by 1 = divide by 3 (truncate)
    const b = TVCBigInt.fromI64(27);
    const shifted_right = b.shiftRight(1);
    try std.testing.expectEqual(@as(i64, 9), shifted_right.toI64());
}

test "BigInt Newton-Raphson division" {
    // Test Newton-Raphson division
    const a = TVCBigInt.fromI64(1000000);
    const b = TVCBigInt.fromI64(1234);
    const result = a.divNewton(&b);
    // Should give same result as regular division
    try std.testing.expectEqual(@as(i64, 810), result.q.toI64());
    try std.testing.expectEqual(@as(i64, 460), result.r.toI64());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    const iterations: u64 = 100000;
    
    std.debug.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TVC BigInt BENCHMARKS                                ║\n", .{});
    std.debug.print("║  Balanced Ternary vs Native i64                                ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
    
    // Test values
    const val_a: i64 = 12345;
    const val_b: i64 = 6789;
    
    const big_a = TVCBigInt.fromI64(val_a);
    const big_b = TVCBigInt.fromI64(val_b);
    
    // === Addition Benchmark ===
    std.debug.print("Addition ({} + {}) x {} iterations:\n", .{val_a, val_b, iterations});
    
    // Native i64
    var native_start = std.time.nanoTimestamp();
    var native_sum: i64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        native_sum +%= val_a +% val_b;
    }
    var native_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(native_sum);
    const native_add_ns = @as(u64, @intCast(native_end - native_start));
    
    // BigInt
    var bigint_start = std.time.nanoTimestamp();
    var bigint_sum = TVCBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        bigint_sum = big_a.add(&big_b);
    }
    var bigint_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bigint_sum);
    const bigint_add_ns = @as(u64, @intCast(bigint_end - bigint_start));
    
    std.debug.print("  Native i64: {} ns ({} ns/op)\n", .{native_add_ns, native_add_ns / iterations});
    std.debug.print("  BigInt:     {} ns ({} ns/op)\n", .{bigint_add_ns, bigint_add_ns / iterations});
    std.debug.print("  Ratio:      {d:.1}x slower\n\n", .{@as(f64, @floatFromInt(bigint_add_ns)) / @as(f64, @floatFromInt(native_add_ns))});
    
    // === Multiplication Benchmark ===
    std.debug.print("Multiplication ({} * {}) x {} iterations:\n", .{val_a, val_b, iterations / 10});
    
    // Native i64
    native_start = std.time.nanoTimestamp();
    var native_prod: i64 = 0;
    i = 0;
    while (i < iterations / 10) : (i += 1) {
        native_prod +%= val_a *% val_b;
    }
    native_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(native_prod);
    const native_mul_ns = @as(u64, @intCast(native_end - native_start));
    
    // BigInt (simple)
    bigint_start = std.time.nanoTimestamp();
    var bigint_prod = TVCBigInt.zero();
    i = 0;
    while (i < iterations / 10) : (i += 1) {
        bigint_prod = big_a.mulSimple(&big_b);
    }
    bigint_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bigint_prod);
    const bigint_mul_ns = @as(u64, @intCast(bigint_end - bigint_start));
    
    std.debug.print("  Native i64: {} ns ({} ns/op)\n", .{native_mul_ns, native_mul_ns / (iterations / 10)});
    std.debug.print("  BigInt:     {} ns ({} ns/op)\n", .{bigint_mul_ns, bigint_mul_ns / (iterations / 10)});
    std.debug.print("  Ratio:      {d:.1}x slower\n\n", .{@as(f64, @floatFromInt(bigint_mul_ns)) / @as(f64, @floatFromInt(native_mul_ns))});
    
    // === Division Benchmark ===
    std.debug.print("Division ({} / {}) x {} iterations:\n", .{val_a, val_b, iterations / 100});
    
    // Native i64
    native_start = std.time.nanoTimestamp();
    var native_div: i64 = 0;
    i = 0;
    while (i < iterations / 100) : (i += 1) {
        native_div +%= @divTrunc(val_a, val_b);
    }
    native_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(native_div);
    const native_div_ns = @as(u64, @intCast(native_end - native_start));
    
    // BigInt division
    bigint_start = std.time.nanoTimestamp();
    var bigint_div = TVCBigInt.zero();
    i = 0;
    while (i < iterations / 100) : (i += 1) {
        bigint_div = big_a.div(&big_b);
    }
    bigint_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bigint_div);
    const bigint_div_ns = @as(u64, @intCast(bigint_end - bigint_start));
    
    std.debug.print("  Native i64: {} ns ({} ns/op)\n", .{native_div_ns, native_div_ns / (iterations / 100)});
    std.debug.print("  BigInt:     {} ns ({} ns/op)\n", .{bigint_div_ns, bigint_div_ns / (iterations / 100)});
    std.debug.print("  Ratio:      {d:.1}x slower\n\n", .{@as(f64, @floatFromInt(bigint_div_ns)) / @as(f64, @floatFromInt(native_div_ns))});
    
    // === Large Number Test ===
    std.debug.print("Large number test (beyond i64 range):\n", .{});
    
    // Create large numbers by repeated multiplication
    const large_a = TVCBigInt.fromI64(1000000);
    const large_b = TVCBigInt.fromI64(1000000);
    
    // 10^6 * 10^6 = 10^12
    const large_prod = large_a.mul(&large_b);
    std.debug.print("  10^6 * 10^6 = {} (trits: {})\n", .{large_prod.toI64(), large_prod.len});
    
    // 10^12 * 10^6 = 10^18
    const very_large = large_prod.mul(&large_b);
    std.debug.print("  10^12 * 10^6 = {} (trits: {})\n", .{very_large.toI64(), very_large.len});
    
    // Verify correctness
    const expected: i64 = 1000000000000000000;
    std.debug.print("  Expected:    {}\n", .{expected});
    std.debug.print("  Match: {}\n\n", .{very_large.toI64() == expected});
    
    // === Division of large numbers ===
    std.debug.print("Large division test:\n", .{});
    const div_result = very_large.divRem(&large_a);
    std.debug.print("  10^18 / 10^6 = {} (expected: 10^12 = {})\n", .{div_result.q.toI64(), large_prod.toI64()});
    std.debug.print("  Remainder: {}\n\n", .{div_result.r.toI64()});
    
    // === SIMD vs Scalar Benchmark ===
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           SIMD vs SCALAR BENCHMARK                             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
    
    // Create large numbers (100+ trits) to trigger SIMD path
    const simd_iterations: u64 = 10000;
    
    // Build a large number by repeated multiplication
    var big_num = TVCBigInt.fromI64(999999999);
    big_num = big_num.mul(&big_num); // ~60 trits
    big_num = big_num.mul(&TVCBigInt.fromI64(1000)); // ~70 trits
    
    var big_num2 = TVCBigInt.fromI64(888888888);
    big_num2 = big_num2.mul(&big_num2);
    big_num2 = big_num2.mul(&TVCBigInt.fromI64(1000));
    
    std.debug.print("Large number addition (trits: {} + {}) x {} iterations:\n", .{big_num.len, big_num2.len, simd_iterations});
    
    // Scalar addition (force scalar path)
    const scalar_start = std.time.nanoTimestamp();
    var scalar_result = TVCBigInt.zero();
    i = 0;
    while (i < simd_iterations) : (i += 1) {
        scalar_result = big_num.addScalar(&big_num2);
    }
    const scalar_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(scalar_result);
    const scalar_ns = @as(u64, @intCast(scalar_end - scalar_start));
    
    // SIMD addition
    const simd_start = std.time.nanoTimestamp();
    var simd_result = TVCBigInt.zero();
    i = 0;
    while (i < simd_iterations) : (i += 1) {
        simd_result = big_num.addSIMD(&big_num2);
    }
    const simd_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(simd_result);
    const simd_ns = @as(u64, @intCast(simd_end - simd_start));
    
    const scalar_ns_per_op = scalar_ns / simd_iterations;
    const simd_ns_per_op = simd_ns / simd_iterations;
    const simd_speedup: f64 = @as(f64, @floatFromInt(scalar_ns)) / @as(f64, @floatFromInt(simd_ns));
    
    std.debug.print("  Scalar: {} ns ({} ns/op)\n", .{scalar_ns, scalar_ns_per_op});
    std.debug.print("  SIMD:   {} ns ({} ns/op)\n", .{simd_ns, simd_ns_per_op});
    std.debug.print("  Speedup: {d:.2}x\n", .{simd_speedup});
    std.debug.print("  Results match: {}\n\n", .{scalar_result.toI64() == simd_result.toI64()});
    
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    BENCHMARK SUMMARY                           ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ BigInt is slower than native i64 (expected for arbitrary       ║\n", .{});
    std.debug.print("║ precision), but enables numbers beyond 2^63 limit.             ║\n", .{});
    std.debug.print("║                                                                ║\n", .{});
    std.debug.print("║ SIMD optimization:                                             ║\n", .{});
    std.debug.print("║ - Processes 32 trits in parallel using AVX2                    ║\n", .{});
    std.debug.print("║ - Speedup depends on number size and carry propagation         ║\n", .{});
    std.debug.print("║                                                                ║\n", .{});
    std.debug.print("║ Balanced Ternary advantages:                                   ║\n", .{});
    std.debug.print("║ - No separate sign bit (inherent in representation)            ║\n", .{});
    std.debug.print("║ - Simpler rounding (truncation = round to nearest)             ║\n", .{});
    std.debug.print("║ - Symmetric range (-3^n/2 to +3^n/2)                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
}

pub fn main() !void {
    runBenchmarks();
}
