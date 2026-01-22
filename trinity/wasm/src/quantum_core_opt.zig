// Optimized Quantum WASM Core - No std library
// φ² + 1/φ² = 3 | PHOENIX = 999

pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.618033988749895;
pub const TAU: f32 = 6.283185307179586;

// Qubit: |ψ⟩ = α|0⟩ + β|1⟩
const Qubit = struct {
    alpha_r: f32, alpha_i: f32,
    beta_r: f32, beta_i: f32,
};

const MAX_QUBITS: usize = 16;
var qubits: [MAX_QUBITS]Qubit = undefined;
var qubit_count: usize = 0;

// Math functions (no std)
fn sqrt(x: f32) f32 {
    if (x <= 0) return 0;
    var guess: f32 = x / 2;
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        guess = (guess + x / guess) / 2;
    }
    return guess;
}

fn sin(x: f32) f32 {
    var v = x;
    while (v > TAU / 2) v -= TAU;
    while (v < -TAU / 2) v += TAU;
    const x2 = v * v;
    return v * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

fn cos(x: f32) f32 {
    return sin(x + TAU / 4);
}

// WASM Exports
pub export fn init() void {
    qubit_count = 0;
    for (&qubits) |*q| {
        q.* = .{ .alpha_r = 1, .alpha_i = 0, .beta_r = 0, .beta_i = 0 };
    }
}

pub export fn create_qubit() usize {
    if (qubit_count >= MAX_QUBITS) return MAX_QUBITS;
    qubits[qubit_count] = .{ .alpha_r = 1, .alpha_i = 0, .beta_r = 0, .beta_i = 0 };
    qubit_count += 1;
    return qubit_count - 1;
}

pub export fn hadamard(idx: usize) void {
    if (idx >= qubit_count) return;
    const q = &qubits[idx];
    const inv_sqrt2: f32 = 0.7071067811865476;
    const new_alpha_r = (q.alpha_r + q.beta_r) * inv_sqrt2;
    const new_alpha_i = (q.alpha_i + q.beta_i) * inv_sqrt2;
    const new_beta_r = (q.alpha_r - q.beta_r) * inv_sqrt2;
    const new_beta_i = (q.alpha_i - q.beta_i) * inv_sqrt2;
    q.alpha_r = new_alpha_r;
    q.alpha_i = new_alpha_i;
    q.beta_r = new_beta_r;
    q.beta_i = new_beta_i;
}

pub export fn pauli_x(idx: usize) void {
    if (idx >= qubit_count) return;
    const q = &qubits[idx];
    const tmp_r = q.alpha_r;
    const tmp_i = q.alpha_i;
    q.alpha_r = q.beta_r;
    q.alpha_i = q.beta_i;
    q.beta_r = tmp_r;
    q.beta_i = tmp_i;
}

pub export fn pauli_z(idx: usize) void {
    if (idx >= qubit_count) return;
    const q = &qubits[idx];
    q.beta_r = -q.beta_r;
    q.beta_i = -q.beta_i;
}

pub export fn phase_rotate(idx: usize, angle: f32) void {
    if (idx >= qubit_count) return;
    const q = &qubits[idx];
    const c = cos(angle);
    const s = sin(angle);
    const new_beta_r = q.beta_r * c - q.beta_i * s;
    const new_beta_i = q.beta_r * s + q.beta_i * c;
    q.beta_r = new_beta_r;
    q.beta_i = new_beta_i;
}

pub export fn measure_probability_0(idx: usize) f32 {
    if (idx >= qubit_count) return 0;
    const q = qubits[idx];
    return q.alpha_r * q.alpha_r + q.alpha_i * q.alpha_i;
}

pub export fn measure_probability_1(idx: usize) f32 {
    if (idx >= qubit_count) return 0;
    const q = qubits[idx];
    return q.beta_r * q.beta_r + q.beta_i * q.beta_i;
}

pub export fn entangle(idx_a: usize, idx_b: usize) void {
    if (idx_a >= qubit_count or idx_b >= qubit_count) return;
    hadamard(idx_a);
    // CNOT: flip beta of B if alpha of A is significant
    const prob_a = measure_probability_1(idx_a);
    if (prob_a > 0.5) {
        pauli_x(idx_b);
    }
}

pub export fn get_phi() f32 {
    return PHI;
}

pub export fn golden_identity() f32 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

pub export fn quantum_interference(x: f32, y: f32, time: f32) f32 {
    const wave1 = sin(x * 0.02 + time * PHI);
    const wave2 = cos(y * 0.02 + time);
    return (wave1 + wave2) / 2.0;
}

pub export fn superposition_value(idx: usize, time: f32) f32 {
    if (idx >= qubit_count) return 0;
    const q = qubits[idx];
    const phase = time * PHI;
    return q.alpha_r * cos(phase) + q.beta_r * sin(phase);
}

pub export fn get_qubit_count() usize {
    return qubit_count;
}
