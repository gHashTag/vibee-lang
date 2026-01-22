// Optimized Photon Engine WASM - No std library
// φ² + 1/φ² = 3 | PHOENIX = 999

pub const PHI: f32 = 1.618033988749895;
pub const TAU: f32 = 6.283185307179586;

const Photon = struct {
    x: f32, y: f32,
    vx: f32, vy: f32,
    phase: f32,
    amplitude: f32,
    wavelength: f32,
    active: bool,
};

const MAX_PHOTONS: usize = 500;
var photons: [MAX_PHOTONS]Photon = undefined;
var photon_count: usize = 0;
var time: f32 = 0;
var decay: f32 = 0.02;
var gravity: f32 = 1.0;
var friction: f32 = 0.99;
var width: f32 = 800;
var height: f32 = 600;

// Math (no std)
fn sqrt(x: f32) f32 {
    if (x <= 0) return 0;
    var g: f32 = x / 2;
    var i: u32 = 0;
    while (i < 8) : (i += 1) g = (g + x / g) / 2;
    return g;
}

fn sin(x: f32) f32 {
    var v = x;
    while (v > TAU / 2) v -= TAU;
    while (v < -TAU / 2) v += TAU;
    const x2 = v * v;
    return v * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0));
}

fn cos(x: f32) f32 { return sin(x + TAU / 4); }

fn exp_approx(x: f32) f32 {
    const v = 1.0 + x / 256.0;
    var r = v;
    var i: u32 = 0;
    while (i < 8) : (i += 1) r = r * r;
    return r;
}

fn abs(x: f32) f32 { return if (x < 0) -x else x; }
fn min(a: f32, b: f32) f32 { return if (a < b) a else b; }
fn max(a: f32, b: f32) f32 { return if (a > b) a else b; }

// WASM Exports
pub export fn init() void {
    photon_count = 0;
    time = 0;
    for (&photons) |*p| p.active = false;
}

pub export fn set_bounds(w: f32, h: f32) void {
    width = w;
    height = h;
}

pub export fn set_params(g: f32, f: f32, d: f32) void {
    gravity = g;
    friction = f;
    decay = d;
}

pub export fn spawn(x: f32, y: f32, freq: f32) usize {
    if (photon_count >= MAX_PHOTONS) {
        // Recycle
        for (&photons) |*p| {
            if (p.active and p.amplitude < 0.1) {
                p.* = .{
                    .x = x, .y = y,
                    .vx = 0, .vy = 0,
                    .phase = x * y * 0.01,
                    .amplitude = 1.0,
                    .wavelength = freq * 100,
                    .active = true,
                };
                return photon_count;
            }
        }
        return MAX_PHOTONS;
    }
    
    for (&photons, 0..) |*p, i| {
        if (!p.active) {
            p.* = .{
                .x = x, .y = y,
                .vx = 0, .vy = 0,
                .phase = x * y * 0.01,
                .amplitude = 1.0,
                .wavelength = freq * 100,
                .active = true,
            };
            photon_count += 1;
            return i;
        }
    }
    return MAX_PHOTONS;
}

pub export fn spawn_burst(cx: f32, cy: f32, count: u32, spread: f32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) * TAU / @as(f32, @floatFromInt(count));
        const x = cx + cos(angle) * spread;
        const y = cy + sin(angle) * spread;
        _ = spawn(x, y, 4.0 + @as(f32, @floatFromInt(i % 4)));
    }
}

pub export fn update(dt: f32) void {
    time += dt;
    const cx = width / 2;
    const cy = height / 2;
    
    for (&photons) |*p| {
        if (!p.active) continue;
        
        // Gravity to center
        const dx = cx - p.x;
        const dy = cy - p.y;
        const d = sqrt(dx * dx + dy * dy) + 1;
        const f = gravity * 50 / d;
        p.vx += dx / d * f * dt;
        p.vy += dy / d * f * dt;
        
        // Friction
        p.vx *= friction;
        p.vy *= friction;
        
        // Update position
        p.x += p.vx;
        p.y += p.vy;
        
        // Phase
        p.phase += dt * PHI;
        if (p.phase > TAU) p.phase -= TAU;
        
        // Decay
        p.amplitude *= (1.0 - decay * dt);
        if (p.amplitude < 0.01) {
            p.active = false;
            photon_count -= 1;
        }
        
        // Boundaries
        if (p.x < 0) { p.x = 0; p.vx *= -0.8; }
        if (p.x > width) { p.x = width; p.vx *= -0.8; }
        if (p.y < 0) { p.y = 0; p.vy *= -0.8; }
        if (p.y > height) { p.y = height; p.vy *= -0.8; }
    }
}

pub export fn apply_vortex(cx: f32, cy: f32, strength: f32) void {
    for (&photons) |*p| {
        if (!p.active) continue;
        const dx = cx - p.x;
        const dy = cy - p.y;
        const d = sqrt(dx * dx + dy * dy) + 1;
        p.vx += (-dy / d * 2 + dx / d * 0.5) * strength * 0.016;
        p.vy += (dx / d * 2 + dy / d * 0.5) * strength * 0.016;
    }
}

pub export fn apply_attraction(mx: f32, my: f32, strength: f32) void {
    for (&photons) |*p| {
        if (!p.active) continue;
        const dx = mx - p.x;
        const dy = my - p.y;
        const d = sqrt(dx * dx + dy * dy) + 1;
        if (d < 200) {
            const f = strength * 100 / d;
            p.vx += dx / d * f * 0.016;
            p.vy += dy / d * f * 0.016;
        }
    }
}

pub export fn wave_at(x: f32, y: f32) f32 {
    var sum: f32 = 0;
    for (photons) |p| {
        if (!p.active) continue;
        const dx = x - p.x;
        const dy = y - p.y;
        const r = sqrt(dx * dx + dy * dy);
        const k = TAU / p.wavelength;
        sum += p.amplitude * cos(k * r - k * PHI * time + p.phase) * exp_approx(-decay * r);
    }
    return sum;
}

pub export fn get_count() usize {
    return photon_count;
}

pub export fn get_energy() f32 {
    var e: f32 = 0;
    for (photons) |p| {
        if (p.active) e += p.vx * p.vx + p.vy * p.vy;
    }
    return e;
}

pub export fn get_x(idx: usize) f32 {
    if (idx >= MAX_PHOTONS) return 0;
    return photons[idx].x;
}

pub export fn get_y(idx: usize) f32 {
    if (idx >= MAX_PHOTONS) return 0;
    return photons[idx].y;
}

pub export fn get_amplitude(idx: usize) f32 {
    if (idx >= MAX_PHOTONS) return 0;
    return photons[idx].amplitude;
}

pub export fn get_phase(idx: usize) f32 {
    if (idx >= MAX_PHOTONS) return 0;
    return photons[idx].phase;
}

pub export fn is_active(idx: usize) bool {
    if (idx >= MAX_PHOTONS) return false;
    return photons[idx].active;
}

pub export fn get_phi() f32 { return PHI; }
pub export fn golden_identity() f32 { return PHI * PHI + 1.0 / (PHI * PHI); }
