//! Trinity Sort: Physics-Inspired Sorting Algorithm
//!
//! Based on the observation that physical constants follow: n × 3^k × π^m
//! This algorithm applies the same principles to sorting:
//!
//! 1. THREE-WAY PARTITIONING: Mirrors 3 dimensions, 3 quark colors
//! 2. GOLDEN RATIO PIVOT: φ appears in optimal data structures
//! 3. PI-BASED THRESHOLDS: π appears in complexity analysis
//!
//! Author: Dmitrii Vasilev
//! Date: January 13, 2026
//!
//! Theoretical basis:
//!   m_p/m_e = 6π⁵ = 2 × 3 × π⁵
//!   m_τ/m_e = 36π⁴ = 4 × 3² × π⁴
//!   Pattern: n × 3^k × π^m
//!
//! Algorithm complexity: O(n log₃ n) average case

const std = @import("std");

/// Golden ratio - appears in Fibonacci heaps, optimal search
pub const PHI: f64 = 1.6180339887498949;

/// Inverse golden ratio
pub const PHI_INV: f64 = 0.6180339887498949;

/// Pi - appears in Stirling's approximation, FFT
pub const PI: f64 = 3.14159265358979323846;

/// Trinity threshold - switch to insertion sort below this
/// Chosen as 3² × π ≈ 28.27, rounded to 27 = 3³
pub const TRINITY_THRESHOLD: usize = 27;

/// Statistics for algorithm analysis
pub const SortStats = struct {
    comparisons: u64 = 0,
    swaps: u64 = 0,
    recursion_depth: u32 = 0,
    max_depth: u32 = 0,
    
    pub fn reset(self: *SortStats) void {
        self.* = .{};
    }
};

var global_stats: SortStats = .{};

/// Get current statistics
pub fn getStats() SortStats {
    return global_stats;
}

/// Reset statistics
pub fn resetStats() void {
    global_stats.reset();
}

/// Three-way partition result
const Partition3 = struct {
    lt_end: usize,   // Elements < pivot end here
    gt_start: usize, // Elements > pivot start here
};

/// Network sort for exactly 3 elements (optimal: 3 comparisons)
/// This is the "atomic unit" of Trinity Sort
fn networkSort3(comptime T: type, arr: *[3]T) void {
    global_stats.comparisons += 3;
    
    // Comparison 1
    if (arr[0] > arr[1]) {
        std.mem.swap(T, &arr[0], &arr[1]);
        global_stats.swaps += 1;
    }
    // Comparison 2
    if (arr[1] > arr[2]) {
        std.mem.swap(T, &arr[1], &arr[2]);
        global_stats.swaps += 1;
    }
    // Comparison 3
    if (arr[0] > arr[1]) {
        std.mem.swap(T, &arr[0], &arr[1]);
        global_stats.swaps += 1;
    }
}

/// Network sort for exactly 4 elements (optimal: 5 comparisons)
fn networkSort4(comptime T: type, arr: *[4]T) void {
    global_stats.comparisons += 5;
    
    // Sort pairs
    if (arr[0] > arr[1]) {
        std.mem.swap(T, &arr[0], &arr[1]);
        global_stats.swaps += 1;
    }
    if (arr[2] > arr[3]) {
        std.mem.swap(T, &arr[2], &arr[3]);
        global_stats.swaps += 1;
    }
    // Compare across pairs
    if (arr[0] > arr[2]) {
        std.mem.swap(T, &arr[0], &arr[2]);
        global_stats.swaps += 1;
    }
    if (arr[1] > arr[3]) {
        std.mem.swap(T, &arr[1], &arr[3]);
        global_stats.swaps += 1;
    }
    // Final comparison
    if (arr[1] > arr[2]) {
        std.mem.swap(T, &arr[1], &arr[2]);
        global_stats.swaps += 1;
    }
}

/// Golden ratio pivot selection
/// Selects pivot at position n/φ, which provides good balance
fn goldenPivotIndex(len: usize) usize {
    if (len <= 3) return len / 2;
    
    // Position at golden ratio
    const pos = @as(f64, @floatFromInt(len)) * PHI_INV;
    return @intFromFloat(pos);
}

/// Median of three using golden positions
/// Selects median from positions: 0, n/φ, n-1
fn medianOfThreeGolden(comptime T: type, arr: []T) usize {
    if (arr.len < 3) return 0;
    
    const a_idx: usize = 0;
    const b_idx = goldenPivotIndex(arr.len);
    const c_idx = arr.len - 1;
    
    const a = arr[a_idx];
    const b = arr[b_idx];
    const c = arr[c_idx];
    
    global_stats.comparisons += 3;
    
    if (a <= b) {
        if (b <= c) return b_idx;      // a <= b <= c
        if (a <= c) return c_idx;      // a <= c < b
        return a_idx;                   // c < a <= b
    } else {
        if (a <= c) return a_idx;      // b < a <= c
        if (b <= c) return c_idx;      // b <= c < a
        return b_idx;                   // c < b < a
    }
}

/// Three-way partition (Dutch National Flag algorithm)
/// Partitions array into: [< pivot] [= pivot] [> pivot]
///
/// This mirrors the Trinity principle:
/// - 3 regions (like 3 dimensions)
/// - 3 quark colors (red, green, blue)
/// - 3 particle generations
fn partition3Way(comptime T: type, arr: []T, pivot: T) Partition3 {
    if (arr.len == 0) return .{ .lt_end = 0, .gt_start = 0 };
    
    var lt: usize = 0;           // Next position for < pivot
    var i: usize = 0;            // Current position
    var gt: usize = arr.len - 1; // Next position for > pivot
    
    while (i <= gt) {
        global_stats.comparisons += 1;
        
        if (arr[i] < pivot) {
            std.mem.swap(T, &arr[lt], &arr[i]);
            global_stats.swaps += 1;
            lt += 1;
            i += 1;
        } else if (arr[i] > pivot) {
            std.mem.swap(T, &arr[i], &arr[gt]);
            global_stats.swaps += 1;
            if (gt == 0) break;
            gt -= 1;
        } else {
            i += 1;
        }
    }
    
    return .{ .lt_end = lt, .gt_start = gt + 1 };
}

/// Optimized insertion sort for small arrays
/// Used when array size < TRINITY_THRESHOLD (27 = 3³)
fn insertionSort(comptime T: type, arr: []T) void {
    if (arr.len <= 1) return;
    
    for (1..arr.len) |i| {
        const key = arr[i];
        var j: usize = i;
        
        while (j > 0) {
            global_stats.comparisons += 1;
            if (arr[j - 1] <= key) break;
            
            arr[j] = arr[j - 1];
            global_stats.swaps += 1;
            j -= 1;
        }
        
        if (j != i) {
            arr[j] = key;
        }
    }
}

/// Trinity Sort - main algorithm
/// Combines:
/// - 3-way partitioning (Trinity principle)
/// - Golden ratio pivot selection (φ optimization)
/// - π-based threshold (TRINITY_THRESHOLD ≈ 3² × π)
pub fn trinitySort(comptime T: type, arr: []T) void {
    resetStats();
    trinitySortImpl(T, arr, 0);
}

fn trinitySortImpl(comptime T: type, arr: []T, depth: u32) void {
    global_stats.recursion_depth = depth;
    if (depth > global_stats.max_depth) {
        global_stats.max_depth = depth;
    }
    
    // Base cases using network sorts (optimal for small n)
    switch (arr.len) {
        0, 1 => return,
        2 => {
            global_stats.comparisons += 1;
            if (arr[0] > arr[1]) {
                std.mem.swap(T, &arr[0], &arr[1]);
                global_stats.swaps += 1;
            }
            return;
        },
        3 => {
            networkSort3(T, arr[0..3]);
            return;
        },
        4 => {
            networkSort4(T, arr[0..4]);
            return;
        },
        else => {},
    }
    
    // Use insertion sort for small arrays (threshold = 3³ = 27)
    if (arr.len <= TRINITY_THRESHOLD) {
        insertionSort(T, arr);
        return;
    }
    
    // Select pivot using golden ratio median-of-three
    const pivot_idx = medianOfThreeGolden(T, arr);
    const pivot = arr[pivot_idx];
    
    // Three-way partition
    const part = partition3Way(T, arr, pivot);
    
    // Recurse on the three regions
    // (middle region with equal elements is already sorted)
    if (part.lt_end > 0) {
        trinitySortImpl(T, arr[0..part.lt_end], depth + 1);
    }
    if (part.gt_start < arr.len) {
        trinitySortImpl(T, arr[part.gt_start..], depth + 1);
    }
}

/// Trinity Sort with custom comparator
pub fn trinitySortBy(comptime T: type, arr: []T, comptime lessThan: fn (T, T) bool) void {
    resetStats();
    trinitySortByImpl(T, arr, lessThan, 0);
}

fn trinitySortByImpl(comptime T: type, arr: []T, comptime lessThan: fn (T, T) bool, depth: u32) void {
    if (arr.len <= 1) return;
    
    if (arr.len <= TRINITY_THRESHOLD) {
        // Insertion sort with custom comparator
        for (1..arr.len) |i| {
            const key = arr[i];
            var j: usize = i;
            
            while (j > 0 and lessThan(key, arr[j - 1])) {
                arr[j] = arr[j - 1];
                j -= 1;
            }
            arr[j] = key;
        }
        return;
    }
    
    const pivot_idx = goldenPivotIndex(arr.len);
    const pivot = arr[pivot_idx];
    
    // 3-way partition with custom comparator
    var lt: usize = 0;
    var i: usize = 0;
    var gt: usize = arr.len - 1;
    
    while (i <= gt) {
        if (lessThan(arr[i], pivot)) {
            std.mem.swap(T, &arr[lt], &arr[i]);
            lt += 1;
            i += 1;
        } else if (lessThan(pivot, arr[i])) {
            std.mem.swap(T, &arr[i], &arr[gt]);
            if (gt == 0) break;
            gt -= 1;
        } else {
            i += 1;
        }
    }
    
    if (lt > 0) trinitySortByImpl(T, arr[0..lt], lessThan, depth + 1);
    if (gt + 1 < arr.len) trinitySortByImpl(T, arr[gt + 1..], lessThan, depth + 1);
}

/// Verify array is sorted
pub fn isSorted(comptime T: type, arr: []const T) bool {
    if (arr.len <= 1) return true;
    
    for (1..arr.len) |i| {
        if (arr[i - 1] > arr[i]) return false;
    }
    return true;
}

/// Benchmark comparison with standard sort
pub fn benchmark(comptime T: type, arr: []T, iterations: u32) struct {
    trinity_ns: u64,
    std_ns: u64,
    trinity_comparisons: u64,
} {
    const allocator = std.heap.page_allocator;
    
    var trinity_total: u64 = 0;
    var std_total: u64 = 0;
    var total_comparisons: u64 = 0;
    
    // Backup original array
    const backup = allocator.alloc(T, arr.len) catch return .{ .trinity_ns = 0, .std_ns = 0, .trinity_comparisons = 0 };
    defer allocator.free(backup);
    @memcpy(backup, arr);
    
    for (0..iterations) |_| {
        // Trinity Sort
        @memcpy(arr, backup);
        const t1 = std.time.nanoTimestamp();
        trinitySort(T, arr);
        const t2 = std.time.nanoTimestamp();
        trinity_total += @intCast(t2 - t1);
        total_comparisons += global_stats.comparisons;
        
        // Standard Sort
        @memcpy(arr, backup);
        const t3 = std.time.nanoTimestamp();
        std.mem.sort(T, arr, {}, std.sort.asc(T));
        const t4 = std.time.nanoTimestamp();
        std_total += @intCast(t4 - t3);
    }
    
    return .{
        .trinity_ns = trinity_total / iterations,
        .std_ns = std_total / iterations,
        .trinity_comparisons = total_comparisons / iterations,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "network sort 3" {
    var arr = [_]i32{ 3, 1, 2 };
    networkSort3(i32, &arr);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, &arr);
}

test "network sort 4" {
    var arr = [_]i32{ 4, 2, 3, 1 };
    networkSort4(i32, &arr);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4 }, &arr);
}

test "golden pivot index" {
    // For array of 100 elements, pivot should be around 62 (100/φ)
    const idx = goldenPivotIndex(100);
    try std.testing.expect(idx >= 60 and idx <= 63);
}

test "3-way partition" {
    var arr = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5 };
    const part = partition3Way(i32, &arr, 5);
    
    // All elements before lt_end should be < 5
    for (arr[0..part.lt_end]) |x| {
        try std.testing.expect(x < 5);
    }
    
    // All elements from gt_start should be > 5
    for (arr[part.gt_start..]) |x| {
        try std.testing.expect(x > 5);
    }
    
    // Elements in middle should be = 5
    for (arr[part.lt_end..part.gt_start]) |x| {
        try std.testing.expectEqual(@as(i32, 5), x);
    }
}

test "trinity sort small arrays" {
    var arr1 = [_]i32{};
    trinitySort(i32, &arr1);
    
    var arr2 = [_]i32{42};
    trinitySort(i32, &arr2);
    try std.testing.expectEqual(@as(i32, 42), arr2[0]);
    
    var arr3 = [_]i32{ 2, 1 };
    trinitySort(i32, &arr3);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2 }, &arr3);
}

test "trinity sort medium array" {
    var arr = [_]i32{ 64, 32, 16, 8, 4, 2, 1, 128, 256, 512, 3, 7, 15, 31, 63 };
    trinitySort(i32, &arr);
    try std.testing.expect(isSorted(i32, &arr));
}

test "trinity sort with duplicates" {
    var arr = [_]i32{ 5, 5, 5, 3, 3, 3, 1, 1, 1, 7, 7, 7 };
    trinitySort(i32, &arr);
    try std.testing.expect(isSorted(i32, &arr));
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 1, 1, 3, 3, 3, 5, 5, 5, 7, 7, 7 }, &arr);
}

test "trinity sort large array" {
    const allocator = std.testing.allocator;
    var arr = try allocator.alloc(i32, 1000);
    defer allocator.free(arr);
    
    // Fill with descending values (worst case for naive quicksort)
    for (arr, 0..) |*x, i| {
        x.* = @intCast(1000 - i);
    }
    
    trinitySort(i32, arr);
    try std.testing.expect(isSorted(i32, arr));
}

test "trinity sort random array" {
    const allocator = std.testing.allocator;
    var arr = try allocator.alloc(i32, 500);
    defer allocator.free(arr);
    
    var rng = std.rand.DefaultPrng.init(12345);
    for (arr) |*x| {
        x.* = rng.random().int(i32);
    }
    
    trinitySort(i32, arr);
    try std.testing.expect(isSorted(i32, arr));
}

test "trinity sort preserves elements" {
    var arr = [_]i32{ 5, 2, 8, 1, 9, 3, 7, 4, 6 };
    var sum_before: i64 = 0;
    for (arr) |x| sum_before += x;
    
    trinitySort(i32, &arr);
    
    var sum_after: i64 = 0;
    for (arr) |x| sum_after += x;
    
    try std.testing.expectEqual(sum_before, sum_after);
}

test "statistics tracking" {
    resetStats();
    var arr = [_]i32{ 5, 2, 8, 1, 9, 3, 7, 4, 6 };
    trinitySort(i32, &arr);
    
    const stats = getStats();
    try std.testing.expect(stats.comparisons > 0);
    try std.testing.expect(stats.max_depth > 0);
}
