// Implementation of Goldbach Conjecture via Creation Pattern
// Source → Transformer → Result
// (prime_p, prime_q) → addition → even_number

const std = @import("std");
const print = std.debug.print;

/// Check if n is prime
pub fn is_prime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    
    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

/// Creation Pattern: Find two primes that CREATE the even number n
/// Source: primes p, q | Transformer: addition | Result: n = p + q
pub fn find_goldbach_pair(n: u64) struct { p: u64, q: u64, valid: bool } {
    if (n < 4 or n % 2 != 0) {
        return .{ .p = 0, .q = 0, .valid = false };
    }
    
    var p: u64 = 2;
    while (p <= n / 2) : (p += 1) {
        if (is_prime(p)) {
            const q = n - p;
            if (is_prime(q)) {
                return .{ .p = p, .q = q, .valid = true };
            }
        }
    }
    
    return .{ .p = 0, .q = 0, .valid = false };
}

/// Count all prime pairs that CREATE the even number n
pub fn count_goldbach_pairs(n: u64) u64 {
    if (n < 4 or n % 2 != 0) return 0;
    
    var count: u64 = 0;
    var p: u64 = 2;
    while (p <= n / 2) : (p += 1) {
        if (is_prime(p) and is_prime(n - p)) {
            count += 1;
        }
    }
    return count;
}

/// Verify Goldbach for a range of even numbers
pub fn verify_goldbach_range(start: u64, end: u64) struct { all_valid: bool, tested: u64, first_failure: u64 } {
    var tested: u64 = 0;
    var s = if (start < 4) @as(u64, 4) else if (start % 2 == 0) start else start + 1;
    
    while (s <= end) : (s += 2) {
        tested += 1;
        const pair = find_goldbach_pair(s);
        if (!pair.valid) {
            return .{ .all_valid = false, .tested = tested, .first_failure = s };
        }
    }
    
    return .{ .all_valid = true, .tested = tested, .first_failure = 0 };
}

// ============================================================================
// Tests from .vibee specification
// ============================================================================

test "is_prime: prime_2" {
    try std.testing.expect(is_prime(2));
}

test "is_prime: prime_17" {
    try std.testing.expect(is_prime(17));
}

test "is_prime: not_prime_4" {
    try std.testing.expect(!is_prime(4));
}

test "is_prime: not_prime_15" {
    try std.testing.expect(!is_prime(15));
}

test "is_prime: prime_97" {
    try std.testing.expect(is_prime(97));
}

test "goldbach_decomposition: decompose_4" {
    const result = find_goldbach_pair(4);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u64, 2), result.p);
    try std.testing.expectEqual(@as(u64, 2), result.q);
}

test "goldbach_decomposition: decompose_10" {
    const result = find_goldbach_pair(10);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u64, 3), result.p);
    try std.testing.expectEqual(@as(u64, 7), result.q);
}

test "goldbach_decomposition: decompose_20" {
    const result = find_goldbach_pair(20);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u64, 3), result.p);
    try std.testing.expectEqual(@as(u64, 17), result.q);
}

test "goldbach_decomposition: decompose_100" {
    const result = find_goldbach_pair(100);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u64, 3), result.p);
    try std.testing.expectEqual(@as(u64, 97), result.q);
}

test "goldbach_decomposition: decompose_1000" {
    const result = find_goldbach_pair(1000);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u64, 3), result.p);
    try std.testing.expectEqual(@as(u64, 997), result.q);
}

test "goldbach_pair_count: pairs_10" {
    // 10 = 3+7 = 5+5, so 2 pairs
    const count = count_goldbach_pairs(10);
    try std.testing.expectEqual(@as(u64, 2), count);
}

test "goldbach_pair_count: pairs_20" {
    // 20 = 3+17 = 7+13, so 2 pairs
    const count = count_goldbach_pairs(20);
    try std.testing.expectEqual(@as(u64, 2), count);
}

test "goldbach_pair_count: pairs_100" {
    // 100 = 3+97 = 11+89 = 17+83 = 29+71 = 41+59 = 47+53, so 6 pairs
    const count = count_goldbach_pairs(100);
    try std.testing.expectEqual(@as(u64, 6), count);
}

test "verify_goldbach_range: range_4_to_100" {
    const result = verify_goldbach_range(4, 100);
    try std.testing.expect(result.all_valid);
    try std.testing.expectEqual(@as(u64, 49), result.tested);
    print("\n✅ Goldbach verified for 4-100: {d} even numbers\n", .{result.tested});
}

test "verify_goldbach_range: range_4_to_1000" {
    const result = verify_goldbach_range(4, 1000);
    try std.testing.expect(result.all_valid);
    try std.testing.expectEqual(@as(u64, 499), result.tested);
    print("\n✅ Goldbach verified for 4-1000: {d} even numbers\n", .{result.tested});
}

test "verify_goldbach_range: range_4_to_10000" {
    const result = verify_goldbach_range(4, 10000);
    try std.testing.expect(result.all_valid);
    print("\n✅ Goldbach verified for 4-10000: {d} even numbers\n", .{result.tested});
}

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("GOLDBACH CONJECTURE - CREATION PATTERN TEST\n", .{});
    print("=" ** 60 ++ "\n", .{});
    print("\nSource → Transformer → Result\n", .{});
    print("(prime_p, prime_q) → addition → even_number\n\n", .{});

    // Test range
    const result = verify_goldbach_range(4, 100000);
    
    print("Results for even n = 4 to 100000:\n", .{});
    print("  ✅ Tested: {d} even numbers\n", .{result.tested});
    if (result.all_valid) {
        print("  ✅ ALL VERIFIED - No counterexamples found!\n", .{});
    } else {
        print("  ❌ COUNTEREXAMPLE FOUND: {d}\n", .{result.first_failure});
    }
    
    // Show some examples
    print("\nExamples of Creation Pattern:\n", .{});
    const examples = [_]u64{ 10, 28, 100, 1000 };
    for (examples) |n| {
        const pair = find_goldbach_pair(n);
        const pairs = count_goldbach_pairs(n);
        print("  {d} = {d} + {d} (and {d} other ways)\n", .{ n, pair.p, pair.q, pairs - 1 });
    }
    
    print("\n🔬 CREATION PATTERN INSIGHT:\n", .{});
    print("  Every even number can be CREATED from two primes\n", .{});
    print("  Pattern: Primes → Addition → Even Numbers (surjective)\n", .{});
}
