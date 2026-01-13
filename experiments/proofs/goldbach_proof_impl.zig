// GOLDBACH PROOF ATTEMPT via Creation Pattern
// Source: Primes (p, q) → Transformer: Addition → Result: Even n

const std = @import("std");
const print = std.debug.print;

fn is_prime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

// Creation Pattern: Can even n be CREATED from primes?
fn goldbach_pairs(n: u64) u64 {
    if (n < 4 or n % 2 != 0) return 0;
    var count: u64 = 0;
    var p: u64 = 2;
    while (p <= n / 2) : (p += 1) {
        if (is_prime(p) and is_prime(n - p)) count += 1;
    }
    return count;
}

// KEY INSIGHT: Prime density analysis
fn prime_density(limit: u64) f64 {
    var count: u64 = 0;
    var n: u64 = 2;
    while (n <= limit) : (n += 1) {
        if (is_prime(n)) count += 1;
    }
    return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(limit));
}

// Expected pairs by probabilistic argument
fn expected_pairs(n: u64) f64 {
    // By prime number theorem: π(n) ≈ n/ln(n)
    // Probability p is prime ≈ 1/ln(p)
    // Expected pairs ≈ n / (2 * ln(n/2)^2)
    const nf = @as(f64, @floatFromInt(n));
    const ln_n = @log(nf / 2.0);
    return nf / (2.0 * ln_n * ln_n);
}

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("GOLDBACH PROOF ATTEMPT via Creation Pattern\n", .{});
    print("=" ** 60 ++ "\n", .{});
    
    print("\n🔬 KEY INSIGHT: Surjectivity of Prime Addition\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print("Creation: (p, q) → p + q → even n\n", .{});
    print("Question: Is this mapping SURJECTIVE onto evens > 2?\n\n", .{});

    // Analyze pair counts vs expected
    print("n\t\tPairs\tExpected\tRatio\n", .{});
    print("-" ** 50 ++ "\n", .{});
    
    const test_values = [_]u64{ 10, 100, 1000, 10000, 100000 };
    for (test_values) |n| {
        const pairs = goldbach_pairs(n);
        const expected = expected_pairs(n);
        const ratio = @as(f64, @floatFromInt(pairs)) / expected;
        print("{d}\t\t{d}\t{d:.1}\t\t{d:.3}\n", .{ n, pairs, expected, ratio });
    }

    print("\n🔬 PROOF STRUCTURE from Creation Pattern:\n", .{});
    print("-" ** 50 ++ "\n", .{});
    print(
        \\1. Primes have density ~1/ln(n) by Prime Number Theorem
        \\2. For even n, we need p and n-p both prime
        \\3. Expected pairs ≈ n/(2*ln²(n/2)) → ∞ as n → ∞
        \\4. If expected pairs > 0 for all n, Goldbach holds
        \\
        \\PROBLEM: Expected value > 0 doesn't guarantee existence!
        \\NEEDED: Prove variance is bounded, or use sieve methods
        \\
        \\PARTIAL RESULT (Chen 1966):
        \\Every large even = prime + (prime or semiprime)
        \\
    , .{});

    // Check minimum pairs
    print("\n📊 Minimum pairs analysis:\n", .{});
    var min_pairs: u64 = 999999;
    var min_n: u64 = 0;
    var n: u64 = 4;
    while (n <= 100000) : (n += 2) {
        const pairs = goldbach_pairs(n);
        if (pairs < min_pairs) {
            min_pairs = pairs;
            min_n = n;
        }
    }
    print("Minimum pairs up to 100000: {d} pairs at n={d}\n", .{ min_pairs, min_n });
    print("Even the minimum has {d} ways to be CREATED from primes!\n", .{min_pairs});
}
