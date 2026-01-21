// ═══════════════════════════════════════════════════════════════════════════════
// phi_ui v24.φ - Unified WASM UI Module
// ═══════════════════════════════════════════════════════════════════════════════
//
// Объединённый UI модуль для WASM
// Золотая идентичность: φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SNAP_THRESHOLD: f64 = 20.0;
pub const MIN_PANEL_SIZE: f64 = 100.0;

// Event types
pub const EVENT_NONE: u32 = 0;
pub const EVENT_MOUSE_DOWN: u32 = 1;
pub const EVENT_MOUSE_UP: u32 = 2;
pub const EVENT_MOUSE_MOVE: u32 = 3;
pub const EVENT_RESIZE: u32 = 6;
pub const EVENT_DBLCLICK: u32 = 7;

// Render commands
pub const CMD_SET_RECT: u32 = 1;
pub const CMD_SET_CURSOR: u32 = 5;

// State codes
pub const STATE_IDLE: u32 = 0;
pub const STATE_DRAGGING: u32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

// ═══════════════════════════════════════════════════════════════════════════════
// UI STATE
// ═══════════════════════════════════════════════════════════════════════════════

var ui_width: f64 = 1200.0;
var ui_height: f64 = 800.0;
var splitter_position: f64 = 0.0; // Will be set to φ ratio
var splitter_dragging: bool = false;
var drag_start_pos: f64 = 0.0;
var state_dirty: bool = true;

// Render command queue
const MAX_COMMANDS: usize = 64;
var cmd_queue: [MAX_COMMANDS]RenderCommand = undefined;
var cmd_count: u32 = 0;

const RenderCommand = extern struct {
    cmd_type: u32,
    element_id: u32,
    param1: f64,
    param2: f64,
    param3: f64,
    param4: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Memory
// ═══════════════════════════════════════════════════════════════════════════════

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

export fn get_cmd_buffer_ptr() [*]RenderCommand {
    return &cmd_queue;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - UI Core
// ═══════════════════════════════════════════════════════════════════════════════

export fn ui_init(width: f64, height: f64) void {
    ui_width = width;
    ui_height = height;
    splitter_position = width * PHI_INV; // φ ratio
    splitter_dragging = false;
    state_dirty = true;
    cmd_count = 0;
}

export fn ui_resize(width: f64, height: f64) void {
    const ratio = splitter_position / ui_width;
    ui_width = width;
    ui_height = height;
    splitter_position = width * ratio;
    state_dirty = true;
}

export fn ui_get_width() f64 {
    return ui_width;
}

export fn ui_get_height() f64 {
    return ui_height;
}

export fn ui_is_dirty() u32 {
    return if (state_dirty) 1 else 0;
}

export fn ui_clear_dirty() void {
    state_dirty = false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Splitter
// ═══════════════════════════════════════════════════════════════════════════════

export fn splitter_get_position() f64 {
    return splitter_position;
}

export fn splitter_set_position(pos: f64) void {
    const clamped = @max(MIN_PANEL_SIZE, @min(pos, ui_width - MIN_PANEL_SIZE));
    splitter_position = clamped;
    state_dirty = true;
}

export fn splitter_start_drag(x: f64) void {
    _ = x;
    splitter_dragging = true;
    drag_start_pos = splitter_position;
}

export fn splitter_update_drag(x: f64) void {
    if (splitter_dragging) {
        splitter_set_position(x);
    }
}

export fn splitter_end_drag() f64 {
    splitter_dragging = false;
    // Snap to φ points
    const snapped = snap_to_phi(splitter_position, ui_width);
    splitter_position = snapped;
    state_dirty = true;
    return snapped;
}

export fn splitter_is_dragging() u32 {
    return if (splitter_dragging) 1 else 0;
}

export fn splitter_reset_to_phi() void {
    splitter_position = ui_width * PHI_INV;
    state_dirty = true;
}

export fn splitter_hit_test(x: f64, y: f64) u32 {
    _ = y;
    const tolerance: f64 = 8.0;
    if (@abs(x - splitter_position) <= tolerance) {
        return 1;
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Layout Calculations
// ═══════════════════════════════════════════════════════════════════════════════

export fn layout_get_left_width() f64 {
    return splitter_position;
}

export fn layout_get_right_width() f64 {
    return ui_width - splitter_position;
}

export fn layout_get_phi_ratio() f64 {
    return splitter_position / ui_width;
}

export fn layout_split_phi(total: f64) f64 {
    return total * PHI_INV;
}

export fn layout_split_phi_inverse(total: f64) f64 {
    return total * (1.0 - PHI_INV);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Snap Points
// ═══════════════════════════════════════════════════════════════════════════════

export fn get_snap_point_count() u32 {
    return 3; // φ, 1/φ, 0.5
}

export fn get_snap_point(index: u32, container_size: f64) f64 {
    return switch (index) {
        0 => container_size * PHI_INV, // 0.618
        1 => container_size * (1.0 - PHI_INV), // 0.382
        2 => container_size * 0.5, // 0.5
        else => container_size * PHI_INV,
    };
}

fn snap_to_phi(pos: f64, container_size: f64) f64 {
    const snap_points = [_]f64{
        container_size * PHI_INV,
        container_size * (1.0 - PHI_INV),
        container_size * 0.5,
    };

    var closest = pos;
    var min_dist = SNAP_THRESHOLD + 1.0;

    for (snap_points) |sp| {
        const dist = @abs(pos - sp);
        if (dist < min_dist and dist < SNAP_THRESHOLD) {
            min_dist = dist;
            closest = sp;
        }
    }

    return closest;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Render Commands
// ═══════════════════════════════════════════════════════════════════════════════

export fn render_get_command_count() u32 {
    return cmd_count;
}

export fn render_push_set_rect(element_id: u32, x: f64, y: f64, w: f64, h: f64) void {
    if (cmd_count < MAX_COMMANDS) {
        cmd_queue[cmd_count] = RenderCommand{
            .cmd_type = CMD_SET_RECT,
            .element_id = element_id,
            .param1 = x,
            .param2 = y,
            .param3 = w,
            .param4 = h,
        };
        cmd_count += 1;
    }
}

export fn render_push_set_cursor(cursor_type: u32) void {
    if (cmd_count < MAX_COMMANDS) {
        cmd_queue[cmd_count] = RenderCommand{
            .cmd_type = CMD_SET_CURSOR,
            .element_id = 0,
            .param1 = @floatFromInt(cursor_type),
            .param2 = 0,
            .param3 = 0,
            .param4 = 0,
        };
        cmd_count += 1;
    }
}

export fn render_clear_commands() void {
    cmd_count = 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - φ Constants
// ═══════════════════════════════════════════════════════════════════════════════

export fn get_phi() f64 {
    return PHI;
}

export fn get_phi_inv() f64 {
    return PHI_INV;
}

export fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}

test "trinity_identity" {
    const result = verify_trinity();
    try std.testing.expectApproxEqAbs(result, TRINITY, 1e-10);
}

test "snap_to_phi" {
    const container = 1000.0;
    const phi_point = container * PHI_INV;
    
    // Near φ point should snap
    const snapped = snap_to_phi(phi_point + 10.0, container);
    try std.testing.expectApproxEqAbs(snapped, phi_point, 1e-10);
    
    // Far from φ point should not snap
    const not_snapped = snap_to_phi(300.0, container);
    try std.testing.expectApproxEqAbs(not_snapped, 300.0, 1e-10);
}

test "layout_split" {
    const total = 1000.0;
    const left = layout_split_phi(total);
    const right = layout_split_phi_inverse(total);
    try std.testing.expectApproxEqAbs(left + right, total, 1e-10);
}
