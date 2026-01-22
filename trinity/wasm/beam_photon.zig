// ═══════════════════════════════════════════════════════════════════════════════
// BEAM PHOTON WASM MODULE
// Компилируется в WebAssembly для браузера
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred Constants
pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.618033988749895;
pub const TAU: f32 = 6.283185307179586;

// ═══════════════════════════════════════════════════════════════════════════════
// PHOTON STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_PHOTONS: usize = 1000;

const Photon = struct {
    x: f32,
    y: f32,
    wavelength: f32,
    phase: f32,
    amplitude: f32,
    active: bool,
};

var photons: [MAX_PHOTONS]Photon = undefined;
var photon_count: usize = 0;
var time: f32 = 0.0;
var decay: f32 = 0.01;
var emotion_hue: f32 = 45.0;
var emotion_sat: f32 = 1.0;
var emotion_bri: f32 = 1.2;

// ═══════════════════════════════════════════════════════════════════════════════
// WASM EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

pub export fn init() void {
    for (&photons) |*p| {
        p.active = false;
    }
    photon_count = 0;
    time = 0.0;
}

pub export fn spawn_photon(x: f32, y: f32, freq: f32) void {
    if (photon_count >= MAX_PHOTONS) {
        // Recycle oldest
        for (&photons) |*p| {
            if (p.active and p.amplitude < 0.1) {
                p.* = .{
                    .x = x,
                    .y = y,
                    .wavelength = freq * 100.0,
                    .phase = @as(f32, @floatFromInt(@mod(@as(i32, @intFromFloat(x * y * 1000.0)), 628))) / 100.0,
                    .amplitude = 1.0,
                    .active = true,
                };
                return;
            }
        }
        return;
    }
    
    for (&photons) |*p| {
        if (!p.active) {
            p.* = .{
                .x = x,
                .y = y,
                .wavelength = freq * 100.0,
                .phase = @as(f32, @floatFromInt(@mod(@as(i32, @intFromFloat(x * y * 1000.0)), 628))) / 100.0,
                .amplitude = 1.0,
                .active = true,
            };
            photon_count += 1;
            return;
        }
    }
}

pub export fn set_decay(d: f32) void {
    decay = d;
}

pub export fn set_emotion(hue: f32, sat: f32, bri: f32) void {
    emotion_hue = hue;
    emotion_sat = sat;
    emotion_bri = bri;
}

pub export fn evolve(dt: f32) void {
    time += dt;
    
    for (&photons) |*p| {
        if (p.active) {
            p.phase += dt * PHI;
            if (p.phase > TAU) p.phase -= TAU;
            p.amplitude *= (1.0 - dt * 0.02);
            
            if (p.amplitude < 0.01) {
                p.active = false;
                photon_count -= 1;
            }
        }
    }
}

pub export fn wave_at(x: f32, y: f32) f32 {
    var sum: f32 = 0.0;
    
    for (photons) |p| {
        if (p.active) {
            const dx = x - p.x;
            const dy = y - p.y;
            const r = @sqrt(dx * dx + dy * dy);
            const k = TAU / p.wavelength;
            const omega = k * PHI;
            
            sum += p.amplitude * @cos(k * r - omega * time + p.phase) * @exp(-decay * r);
        }
    }
    
    return sum;
}

pub export fn get_pixel_rgba(x: f32, y: f32) u32 {
    const interference = wave_at(x, y);
    const intensity = (interference + 1.0) / 2.0;
    
    // Map to color
    const hue = @mod(emotion_hue + interference * 30.0, 360.0);
    const bri = @min(@as(f32, 1.0), intensity * emotion_bri);
    
    // Simple HSL to RGB
    const c = (1.0 - @abs(2.0 * bri - 1.0)) * emotion_sat;
    const h_prime = hue / 60.0;
    const x_val = c * (1.0 - @abs(@mod(h_prime, 2.0) - 1.0));
    
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;
    
    if (h_prime < 1) { r = c; g = x_val; }
    else if (h_prime < 2) { r = x_val; g = c; }
    else if (h_prime < 3) { g = c; b = x_val; }
    else if (h_prime < 4) { g = x_val; b = c; }
    else if (h_prime < 5) { r = x_val; b = c; }
    else { r = c; b = x_val; }
    
    const m = bri - c / 2.0;
    r += m; g += m; b += m;
    
    const ri: u32 = @intFromFloat(@min(@as(f32, 255.0), r * 255.0));
    const gi: u32 = @intFromFloat(@min(@as(f32, 255.0), g * 255.0));
    const bi: u32 = @intFromFloat(@min(@as(f32, 255.0), b * 255.0));
    
    return (255 << 24) | (bi << 16) | (gi << 8) | ri;
}

pub export fn get_photon_count() usize {
    return photon_count;
}

pub export fn clear_all() void {
    for (&photons) |*p| {
        p.active = false;
    }
    photon_count = 0;
}

pub export fn get_phi() f32 {
    return PHI;
}

pub export fn get_golden_identity() f32 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}
