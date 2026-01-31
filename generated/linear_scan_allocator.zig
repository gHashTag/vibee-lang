// ═══════════════════════════════════════════════════════════════════════════════
// linear_scan_allocator v1.0.0 - Generated from .vibee specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Author: 
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const NUM_ALLOCATABLE_REGS: f64 = 6;

pub const SPILL_TEMP_REG: f64 = 0;

pub const SPILL_TEMP_REG2: f64 = 0;

pub const STACK_SLOT_SIZE: f64 = 0;

pub const LOOP_WEIGHT_MULTIPLIER: f64 = 10;

pub const DEF_USE_WEIGHT: f64 = 1;

pub const FIXED_USE_WEIGHT: f64 = 0;

// Базовые φ-константы (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// 
pub const LiveInterval = struct {
    vreg: i64,
    start: i64,
    end: i64,
    phys_reg: ?[]const u8,
    spill_slot: ?[]const u8,
    is_fixed: bool,
    weight: f64,
};

/// 
pub const PhysRegState = struct {
    reg_id: i64,
    current_interval: ?[]const u8,
    is_reserved: bool,
};

/// 
pub const AllocatorConfig = struct {
    num_phys_regs: i64,
    spill_temp_reg: i64,
    spill_temp_reg2: i64,
    enable_coalescing: bool,
    enable_splitting: bool,
};

/// 
pub const AllocationResult = struct {
    reg_mapping: []const u8,
    spill_slots: []const u8,
    spill_stack_size: i64,
    moves_inserted: i64,
    spills_count: i64,
    reloads_count: i64,
};

/// 
pub const UsePosition = struct {
    pos: i64,
    is_def: bool,
    is_fixed: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // ▽ FALSE
    zero = 0,      // ○ UNKNOWN
    positive = 1,  // △ TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Проверка TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-интерполяция
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Генерация φ-спирали
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "compute_live_intervals" {
// Given: Array of IR instructions
// When: Analyzing liveness
// Then: Returns sorted array of LiveInterval by start position
    // TODO: Add test assertions
}

test "allocate_registers" {
// Given: Sorted live intervals and allocator config
// When: Performing linear scan
// Then: Returns AllocationResult with register assignments
    // TODO: Add test assertions
}

test "expire_old_intervals" {
// Given: Current position and active intervals
// When: Scanning past interval end points
// Then: Removes expired intervals from active set, frees registers
    // TODO: Add test assertions
}

test "spill_at_interval" {
// Given: Current interval and active intervals
// When: No free physical registers available
// Then: Spills interval with furthest next use, assigns freed register
    // TODO: Add test assertions
}

test "assign_spill_slot" {
// Given: Virtual register to spill
// When: Register must be stored to stack
// Then: Returns stack offset for spill slot (8-byte aligned)
    // TODO: Add test assertions
}

test "try_allocate_free_reg" {
// Given: Current interval and free register set
// When: Attempting allocation without spilling
// Then: Returns physical register or null if none available
    // TODO: Add test assertions
}

test "compute_spill_weight" {
// Given: Live interval with use positions
// When: Determining spill priority
// Then: Returns weight (loop depth * use count / interval length)
    // TODO: Add test assertions
}

test "build_interference" {
// Given: Live intervals
// When: Two intervals overlap
// Then: Records interference between virtual registers
    // TODO: Add test assertions
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
