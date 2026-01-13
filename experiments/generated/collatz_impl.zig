// Implementation of Collatz Conjecture via Creation Pattern
// Source → Transformer → Result
// n → collatz_step → sequence converging to 1

const std = @import("std");
const print = std.debug.print;

/// Creation Pattern: Source → Transformer → Result
/// For Collatz: n → collatz_step → next_n
pub fn collatz_step(n: u64) u64 {
    if (n % 2 == 0) {
        return n / 2; // Even: compress
    } else {
        return 3 * n + 1; // Odd: expand then compress
    }
}

/// Apply Creation Pattern iteratively until reaching 1
pub fn collatz_sequence(n: u64, max_steps: u64) struct { steps: u64, reached_one: bool, max_value: u64 } {
    var current = n;
    var steps: u64 = 0;
    var max_value: u64 = n;

    while (current != 1 and steps < max_steps) {
        current = collatz_step(current);
        steps += 1;
        if (current > max_value) {
            max_value = current;
        }
    }

    return .{
        .steps = steps,
        .reached_one = current == 1,
        .max_value = max_value,
    };
}

/// Test the Creation Pattern on a range of numbers
pub fn test_creation_pattern(start: u64, end: u64) struct { tested: u64, converged: u64, max_steps: u64 } {
    var tested: u64 = 0;
    var converged: u64 = 0;
    var max_steps: u64 = 0;

    var n = start;
    while (n <= end) : (n += 1) {
        const result = collatz_sequence(n, 10000);
        tested += 1;
        if (result.reached_one) {
            converged += 1;
        }
        if (result.steps > max_steps) {
            max_steps = result.steps;
        }
    }

    return .{
        .tested = tested,
        .converged = converged,
        .max_steps = max_steps,
    };
}

// ============================================================================
// Tests from .vibee specification
// ============================================================================

test "collatz_step_even: step_4" {
    // Source: 4, Transformer: collatz_step, Expected Result: 2
    const result = collatz_step(4);
    try std.testing.expectEqual(@as(u64, 2), result);
}

test "collatz_step_even: step_10" {
    const result = collatz_step(10);
    try std.testing.expectEqual(@as(u64, 5), result);
}

test "collatz_step_even: step_16" {
    const result = collatz_step(16);
    try std.testing.expectEqual(@as(u64, 8), result);
}

test "collatz_step_odd: step_3" {
    // Source: 3, Transformer: collatz_step, Expected Result: 10
    const result = collatz_step(3);
    try std.testing.expectEqual(@as(u64, 10), result);
}

test "collatz_step_odd: step_7" {
    const result = collatz_step(7);
    try std.testing.expectEqual(@as(u64, 22), result);
}

test "collatz_step_odd: step_27" {
    const result = collatz_step(27);
    try std.testing.expectEqual(@as(u64, 82), result);
}

test "collatz_converges: converge_1" {
    const result = collatz_sequence(1, 10000);
    try std.testing.expectEqual(@as(u64, 0), result.steps);
    try std.testing.expect(result.reached_one);
}

test "collatz_converges: converge_2" {
    const result = collatz_sequence(2, 10000);
    try std.testing.expectEqual(@as(u64, 1), result.steps);
    try std.testing.expect(result.reached_one);
}

test "collatz_converges: converge_7" {
    const result = collatz_sequence(7, 10000);
    try std.testing.expectEqual(@as(u64, 16), result.steps);
    try std.testing.expect(result.reached_one);
}

test "collatz_converges: converge_27" {
    const result = collatz_sequence(27, 10000);
    try std.testing.expectEqual(@as(u64, 111), result.steps);
    try std.testing.expect(result.reached_one);
}

test "collatz_converges: converge_97" {
    const result = collatz_sequence(97, 10000);
    try std.testing.expectEqual(@as(u64, 118), result.steps);
    try std.testing.expect(result.reached_one);
}

test "creation_pattern: range 1-1000" {
    const result = test_creation_pattern(1, 1000);
    try std.testing.expectEqual(@as(u64, 1000), result.tested);
    try std.testing.expectEqual(@as(u64, 1000), result.converged);
    print("\n✅ Collatz: {d}/{d} converged, max_steps={d}\n", .{ result.converged, result.tested, result.max_steps });
}

test "creation_pattern: range 1-10000" {
    const result = test_creation_pattern(1, 10000);
    try std.testing.expectEqual(@as(u64, 10000), result.tested);
    try std.testing.expectEqual(@as(u64, 10000), result.converged);
    print("\n✅ Collatz: {d}/{d} converged, max_steps={d}\n", .{ result.converged, result.tested, result.max_steps });
}

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("COLLATZ CONJECTURE - CREATION PATTERN TEST\n", .{});
    print("=" ** 60 ++ "\n", .{});
    print("\nSource → Transformer → Result\n", .{});
    print("n → collatz_step → sequence → 1\n\n", .{});

    // Test range
    const result = test_creation_pattern(1, 100000);
    
    print("Results for n = 1 to {d}:\n", .{result.tested});
    print("  ✅ Converged to 1: {d} ({d:.2}%)\n", .{ 
        result.converged, 
        @as(f64, @floatFromInt(result.converged)) / @as(f64, @floatFromInt(result.tested)) * 100.0 
    });
    print("  📊 Max steps needed: {d}\n", .{result.max_steps});
    
    print("\n🔬 CREATION PATTERN INSIGHT:\n", .{});
    print("  The Collatz transformer acts as an 'entropy reducer'\n", .{});
    print("  Pattern: Source → [compress/prepare cycle] → 1\n", .{});
}
