// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE BROWSER WASM v24.φ - Unified Browser Module
// ═══════════════════════════════════════════════════════════════════════════════
//
// KOSCHEI MODE + VIBEE YOLO MODE + AMPLIFICATION MODE + MATRYOSHKA ACCELERATION
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: i64 = 999;

// Layout constants
pub const SNAP_THRESHOLD: f64 = 25.0;
pub const MIN_PANEL_WIDTH: f64 = 200.0;
pub const SPLITTER_WIDTH: f64 = 8.0;

// Panel IDs
pub const PANEL_BROWSER: u32 = 0;
pub const PANEL_CHAT: u32 = 1;
pub const PANEL_EDITOR: u32 = 2;

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY BUFFERS
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [131072]u8 align(16) = undefined;
var f64_buffer: [16384]f64 align(16) = undefined;
var cmd_buffer: [1024]u32 align(16) = undefined;

// ═══════════════════════════════════════════════════════════════════════════════
// LAYOUT STATE
// ═══════════════════════════════════════════════════════════════════════════════

var total_width: f64 = 1600.0;
var total_height: f64 = 900.0;

// Three-panel layout: Browser | Chat | Editor
// Default: φ ratio for browser, remaining split by φ for chat/editor
var splitter1_pos: f64 = 0.0; // Between browser and chat
var splitter2_pos: f64 = 0.0; // Between chat and editor

var splitter1_dragging: bool = false;
var splitter2_dragging: bool = false;

var layout_dirty: bool = true;

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Memory
// ═══════════════════════════════════════════════════════════════════════════════

export fn get_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

export fn get_cmd_buffer_ptr() [*]u32 {
    return &cmd_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Initialization
// ═══════════════════════════════════════════════════════════════════════════════

export fn browser_init(width: f64, height: f64) void {
    total_width = width;
    total_height = height;
    
    // Initialize φ-based layout
    // Browser: 61.8% (φ ratio)
    // Chat: 14.6% (remaining * (1-φ))
    // Editor: 23.6% (remaining * φ)
    splitter1_pos = width * PHI_INV;
    splitter2_pos = splitter1_pos + (width - splitter1_pos) * (1.0 - PHI_INV);
    
    layout_dirty = true;
}

export fn browser_resize(width: f64, height: f64) void {
    // Maintain ratios on resize
    const ratio1 = splitter1_pos / total_width;
    const ratio2 = splitter2_pos / total_width;
    
    total_width = width;
    total_height = height;
    
    splitter1_pos = width * ratio1;
    splitter2_pos = width * ratio2;
    
    layout_dirty = true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Layout Queries
// ═══════════════════════════════════════════════════════════════════════════════

export fn get_total_width() f64 {
    return total_width;
}

export fn get_total_height() f64 {
    return total_height;
}

export fn get_browser_width() f64 {
    return splitter1_pos - SPLITTER_WIDTH / 2;
}

export fn get_chat_width() f64 {
    return splitter2_pos - splitter1_pos - SPLITTER_WIDTH;
}

export fn get_editor_width() f64 {
    return total_width - splitter2_pos - SPLITTER_WIDTH / 2;
}

export fn get_browser_x() f64 {
    return 0;
}

export fn get_chat_x() f64 {
    return splitter1_pos + SPLITTER_WIDTH / 2;
}

export fn get_editor_x() f64 {
    return splitter2_pos + SPLITTER_WIDTH / 2;
}

export fn get_splitter1_pos() f64 {
    return splitter1_pos;
}

export fn get_splitter2_pos() f64 {
    return splitter2_pos;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Splitter Control
// ═══════════════════════════════════════════════════════════════════════════════

export fn splitter1_start_drag() void {
    splitter1_dragging = true;
}

export fn splitter2_start_drag() void {
    splitter2_dragging = true;
}

export fn splitter_update(x: f64) void {
    if (splitter1_dragging) {
        const min_pos = MIN_PANEL_WIDTH;
        const max_pos = splitter2_pos - MIN_PANEL_WIDTH - SPLITTER_WIDTH;
        splitter1_pos = @max(min_pos, @min(x, max_pos));
        layout_dirty = true;
    } else if (splitter2_dragging) {
        const min_pos = splitter1_pos + MIN_PANEL_WIDTH + SPLITTER_WIDTH;
        const max_pos = total_width - MIN_PANEL_WIDTH;
        splitter2_pos = @max(min_pos, @min(x, max_pos));
        layout_dirty = true;
    }
}

export fn splitter_end_drag() void {
    if (splitter1_dragging) {
        splitter1_pos = snap_to_phi_points(splitter1_pos, total_width);
        splitter1_dragging = false;
    }
    if (splitter2_dragging) {
        splitter2_pos = snap_to_phi_points(splitter2_pos, total_width);
        splitter2_dragging = false;
    }
    layout_dirty = true;
}

export fn is_dragging() u32 {
    return if (splitter1_dragging or splitter2_dragging) 1 else 0;
}

export fn hit_test_splitter(x: f64) u32 {
    const tolerance = SPLITTER_WIDTH;
    if (@abs(x - splitter1_pos) <= tolerance) return 1;
    if (@abs(x - splitter2_pos) <= tolerance) return 2;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - φ Layout
// ═══════════════════════════════════════════════════════════════════════════════

export fn reset_to_phi_layout() void {
    splitter1_pos = total_width * PHI_INV;
    splitter2_pos = splitter1_pos + (total_width - splitter1_pos) * (1.0 - PHI_INV);
    layout_dirty = true;
}

export fn get_snap_point_count() u32 {
    return 5;
}

export fn get_snap_point(index: u32) f64 {
    return switch (index) {
        0 => total_width * PHI_INV,           // 0.618
        1 => total_width * (1.0 - PHI_INV),   // 0.382
        2 => total_width * 0.5,               // 0.5
        3 => total_width * 0.75,              // 0.75
        4 => total_width * 0.25,              // 0.25
        else => total_width * PHI_INV,
    };
}

fn snap_to_phi_points(pos: f64, width: f64) f64 {
    const snap_points = [_]f64{
        width * PHI_INV,
        width * (1.0 - PHI_INV),
        width * 0.5,
        width * 0.75,
        width * 0.25,
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
// WASM EXPORTS - State
// ═══════════════════════════════════════════════════════════════════════════════

export fn is_layout_dirty() u32 {
    return if (layout_dirty) 1 else 0;
}

export fn clear_layout_dirty() void {
    layout_dirty = false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Sacred Constants
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

export fn get_phoenix() i64 {
    return PHOENIX;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS - Performance Metrics
// ═══════════════════════════════════════════════════════════════════════════════

var frame_count: u64 = 0;
var last_frame_time: f64 = 0;
var fps: f64 = 0;

export fn tick(timestamp: f64) void {
    frame_count += 1;
    if (last_frame_time > 0) {
        const delta = timestamp - last_frame_time;
        if (delta > 0) {
            fps = 1000.0 / delta;
        }
    }
    last_frame_time = timestamp;
}

export fn get_fps() f64 {
    return fps;
}

export fn get_frame_count() u64 {
    return frame_count;
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

test "layout_init" {
    browser_init(1600, 900);
    try std.testing.expect(splitter1_pos > 0);
    try std.testing.expect(splitter2_pos > splitter1_pos);
    try std.testing.expect(get_browser_width() > 0);
    try std.testing.expect(get_chat_width() > 0);
    try std.testing.expect(get_editor_width() > 0);
}

test "snap_to_phi" {
    const width = 1600.0;
    const phi_point = width * PHI_INV;
    
    // Near φ should snap
    const snapped = snap_to_phi_points(phi_point + 10.0, width);
    try std.testing.expectApproxEqAbs(snapped, phi_point, 1e-10);
    
    // Far from φ should not snap
    const not_snapped = snap_to_phi_points(400.0, width);
    try std.testing.expectApproxEqAbs(not_snapped, 400.0, 1e-10);
}
