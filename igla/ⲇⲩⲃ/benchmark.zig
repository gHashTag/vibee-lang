// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: SWITCH vs PERFECT HASH DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY_PRIME: u32 = 33;
pub const TABLE_SIZE: u32 = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const ITERATIONS: u64 = 10_000_000;
const WARMUP: u64 = 1_000_000;

// Test opcodes (realistic distribution)
const test_opcodes = [_]u8{
    0x01, 0x01, 0x01, 0x02, // ADD heavy
    0x03, 0x04, 0x10, 0x11, // Mixed
    0x12, 0x13, 0xFF, 0x01, // Stack ops
    0x02, 0x03, 0x01, 0x04, // Arithmetic
};

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 1: SWITCH DISPATCH (baseline)
// ═══════════════════════════════════════════════════════════════════════════════

var switch_counter: u64 = 0;

fn switchDispatch(opcode: u8) void {
    switch (opcode) {
        0x01 => switch_counter +%= 1, // ADD
        0x02 => switch_counter +%= 2, // SUB
        0x03 => switch_counter +%= 3, // MUL
        0x04 => switch_counter +%= 4, // DIV
        0x10 => switch_counter +%= 16, // PUSH
        0x11 => switch_counter +%= 17, // POP
        0x12 => switch_counter +%= 18, // DUP
        0x13 => switch_counter +%= 19, // SWAP
        0xFF => switch_counter +%= 255, // HALT
        else => switch_counter +%= 0,
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 2: PERFECT HASH DISPATCH (optimized)
// ═══════════════════════════════════════════════════════════════════════════════

var hash_counter: u64 = 0;

const Handler = *const fn () void;

fn exec_ADD() void {
    hash_counter +%= 1;
}
fn exec_SUB() void {
    hash_counter +%= 2;
}
fn exec_MUL() void {
    hash_counter +%= 3;
}
fn exec_DIV() void {
    hash_counter +%= 4;
}
fn exec_PUSH() void {
    hash_counter +%= 16;
}
fn exec_POP() void {
    hash_counter +%= 17;
}
fn exec_DUP() void {
    hash_counter +%= 18;
}
fn exec_SWAP() void {
    hash_counter +%= 19;
}
fn exec_HALT() void {
    hash_counter +%= 255;
}
fn exec_INVALID() void {
    hash_counter +%= 0;
}

/// Perfect hash: h(opcode) = (opcode * 33) % 64
inline fn perfectHash(opcode: u8) u6 {
    return @truncate((opcode *% TRINITY_PRIME) % TABLE_SIZE);
}

const dispatch_table: [TABLE_SIZE]Handler = blk: {
    var table: [TABLE_SIZE]Handler = [_]Handler{exec_INVALID} ** TABLE_SIZE;
    table[perfectHash(0x01)] = exec_ADD;
    table[perfectHash(0x02)] = exec_SUB;
    table[perfectHash(0x03)] = exec_MUL;
    table[perfectHash(0x04)] = exec_DIV;
    table[perfectHash(0x10)] = exec_PUSH;
    table[perfectHash(0x11)] = exec_POP;
    table[perfectHash(0x12)] = exec_DUP;
    table[perfectHash(0x13)] = exec_SWAP;
    table[perfectHash(0xFF)] = exec_HALT;
    break :blk table;
};

inline fn hashDispatch(opcode: u8) void {
    dispatch_table[perfectHash(opcode)]();
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 3: DIRECT JUMP TABLE (comparison)
// ═══════════════════════════════════════════════════════════════════════════════

var jump_counter: u64 = 0;

const full_table: [256]Handler = blk: {
    var table: [256]Handler = [_]Handler{exec_INVALID_JUMP} ** 256;
    table[0x01] = exec_ADD_JUMP;
    table[0x02] = exec_SUB_JUMP;
    table[0x03] = exec_MUL_JUMP;
    table[0x04] = exec_DIV_JUMP;
    table[0x10] = exec_PUSH_JUMP;
    table[0x11] = exec_POP_JUMP;
    table[0x12] = exec_DUP_JUMP;
    table[0x13] = exec_SWAP_JUMP;
    table[0xFF] = exec_HALT_JUMP;
    break :blk table;
};

fn exec_ADD_JUMP() void {
    jump_counter +%= 1;
}
fn exec_SUB_JUMP() void {
    jump_counter +%= 2;
}
fn exec_MUL_JUMP() void {
    jump_counter +%= 3;
}
fn exec_DIV_JUMP() void {
    jump_counter +%= 4;
}
fn exec_PUSH_JUMP() void {
    jump_counter +%= 16;
}
fn exec_POP_JUMP() void {
    jump_counter +%= 17;
}
fn exec_DUP_JUMP() void {
    jump_counter +%= 18;
}
fn exec_SWAP_JUMP() void {
    jump_counter +%= 19;
}
fn exec_HALT_JUMP() void {
    jump_counter +%= 255;
}
fn exec_INVALID_JUMP() void {
    jump_counter +%= 0;
}

inline fn jumpDispatch(opcode: u8) void {
    full_table[opcode]();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  DISPATCH BENCHMARK - IGLA vs VIBEEC PATTERNS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\  Golden Identity: φ² + 1/φ² = 3
        \\  Iterations: {d}
        \\  Warmup: {d}
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{ ITERATIONS, WARMUP });

    // Warmup
    try stdout.print("  Warming up...\n", .{});
    var i: u64 = 0;
    while (i < WARMUP) : (i += 1) {
        const opcode = test_opcodes[i % test_opcodes.len];
        switchDispatch(opcode);
        hashDispatch(opcode);
        jumpDispatch(opcode);
    }

    // Reset counters
    switch_counter = 0;
    hash_counter = 0;
    jump_counter = 0;

    // Benchmark 1: Switch
    try stdout.print("\n  [1] SWITCH DISPATCH (baseline)...\n", .{});
    const switch_start = std.time.nanoTimestamp();
    i = 0;
    while (i < ITERATIONS) : (i += 1) {
        const opcode = test_opcodes[i % test_opcodes.len];
        switchDispatch(opcode);
    }
    const switch_end = std.time.nanoTimestamp();
    const switch_ns = @as(u64, @intCast(switch_end - switch_start));
    const switch_ns_per_op = @as(f64, @floatFromInt(switch_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    // Benchmark 2: Perfect Hash
    try stdout.print("  [2] PERFECT HASH DISPATCH (HSH pattern)...\n", .{});
    const hash_start = std.time.nanoTimestamp();
    i = 0;
    while (i < ITERATIONS) : (i += 1) {
        const opcode = test_opcodes[i % test_opcodes.len];
        hashDispatch(opcode);
    }
    const hash_end = std.time.nanoTimestamp();
    const hash_ns = @as(u64, @intCast(hash_end - hash_start));
    const hash_ns_per_op = @as(f64, @floatFromInt(hash_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    // Benchmark 3: Direct Jump Table
    try stdout.print("  [3] DIRECT JUMP TABLE (256 entries)...\n", .{});
    const jump_start = std.time.nanoTimestamp();
    i = 0;
    while (i < ITERATIONS) : (i += 1) {
        const opcode = test_opcodes[i % test_opcodes.len];
        jumpDispatch(opcode);
    }
    const jump_end = std.time.nanoTimestamp();
    const jump_ns = @as(u64, @intCast(jump_end - jump_start));
    const jump_ns_per_op = @as(f64, @floatFromInt(jump_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    // Results
    const hash_speedup = switch_ns_per_op / hash_ns_per_op;
    const jump_speedup = switch_ns_per_op / jump_ns_per_op;

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  RESULTS
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\  METHOD                    TIME/OP      SPEEDUP    MEMORY
        \\  ─────────────────────────────────────────────────────────────────────────────
        \\  Switch (baseline)         {d:.2} ns    1.00x      ~0 bytes
        \\  Perfect Hash (64 slots)   {d:.2} ns    {d:.2}x     512 bytes
        \\  Direct Jump (256 slots)   {d:.2} ns    {d:.2}x     2048 bytes
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  VERIFICATION
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  Switch counter:  {d}
        \\  Hash counter:    {d}
        \\  Jump counter:    {d}
        \\  Counters match:  {s}
        \\
    , .{
        switch_ns_per_op,
        hash_ns_per_op,
        hash_speedup,
        jump_ns_per_op,
        jump_speedup,
        switch_counter,
        hash_counter,
        jump_counter,
        if (switch_counter == hash_counter and hash_counter == jump_counter) "✓ YES" else "✗ NO",
    });

    // Analysis
    try stdout.print(
        \\═══════════════════════════════════════════════════════════════════════════════
        \\  ANALYSIS (PAS METHODOLOGY)
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\  Pattern Applied: HSH (Hashing)
        \\  
        \\  SWITCH:
        \\    - Compiler generates jump table or binary search
        \\    - Branch prediction dependent
        \\    - O(1) average, O(log n) worst case
        \\
        \\  PERFECT HASH:
        \\    - Guaranteed O(1) lookup
        \\    - Single multiplication + modulo
        \\    - 4x smaller table than direct jump
        \\    - Better cache locality
        \\
        \\  DIRECT JUMP:
        \\    - O(1) lookup, no computation
        \\    - Larger memory footprint
        \\    - May cause cache misses
        \\
        \\  RECOMMENDATION:
        \\    Perfect Hash is optimal for sparse opcode sets (< 64 opcodes)
        \\    Direct Jump is better for dense opcode sets (> 128 opcodes)
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{});
}

test "perfect_hash_correctness" {
    // Verify no collisions
    var seen: [TABLE_SIZE]bool = [_]bool{false} ** TABLE_SIZE;
    const opcodes = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x10, 0x11, 0x12, 0x13, 0xFF };

    for (opcodes) |opcode| {
        const idx = perfectHash(opcode);
        try std.testing.expect(!seen[idx]);
        seen[idx] = true;
    }
}

test "dispatch_equivalence" {
    // Reset
    switch_counter = 0;
    hash_counter = 0;
    jump_counter = 0;

    // Run same sequence
    for (test_opcodes) |opcode| {
        switchDispatch(opcode);
        hashDispatch(opcode);
        jumpDispatch(opcode);
    }

    // Verify equivalence
    try std.testing.expectEqual(switch_counter, hash_counter);
    try std.testing.expectEqual(hash_counter, jump_counter);
}
