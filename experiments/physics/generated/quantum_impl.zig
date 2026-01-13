// Реализация Квантовой Механики через Паттерн Творения
// Источник → Трансформер → Результат
// ψ(t₀) → Ĥ (Шрёдингер) → ψ(t)

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const hbar: f64 = 1.055e-34; // Приведённая постоянная Планка (Дж·с)
pub const h: f64 = 6.626e-34; // Постоянная Планка (Дж·с)
pub const m_e: f64 = 9.109e-31; // Масса электрона (кг)
pub const eV: f64 = 1.602e-19; // Электронвольт (Дж)
pub const a_0: f64 = 5.29e-11; // Боровский радиус (м)
pub const E_H: f64 = 13.6; // Энергия ионизации водорода (эВ)
pub const pi: f64 = math.pi;

// ============================================================================
// ТИПЫ (Источники и Результаты)
// ============================================================================

/// Комплексное число для волновой функции
pub const Complex = struct {
    re: f64,
    im: f64,

    pub fn magnitude_squared(self: Complex) f64 {
        return self.re * self.re + self.im * self.im;
    }

    pub fn magnitude(self: Complex) f64 {
        return @sqrt(self.magnitude_squared());
    }

    pub fn multiply(self: Complex, other: Complex) Complex {
        return .{
            .re = self.re * other.re - self.im * other.im,
            .im = self.re * other.im + self.im * other.re,
        };
    }

    pub fn scale(self: Complex, s: f64) Complex {
        return .{ .re = self.re * s, .im = self.im * s };
    }

    pub fn add(self: Complex, other: Complex) Complex {
        return .{ .re = self.re + other.re, .im = self.im + other.im };
    }

    pub fn exp_i(theta: f64) Complex {
        return .{ .re = @cos(theta), .im = @sin(theta) };
    }
};

/// Квантовое состояние
pub const QuantumState = struct {
    n: u32, // главное квантовое число
    l: u32, // орбитальное
    m: i32, // магнитное
    s: f64, // спин (+0.5 или -0.5)
};

/// Результат измерения
pub const MeasurementResult = struct {
    value: f64,
    probability: f64,
};

// ============================================================================
// ТРАНСФОРМЕРЫ (Квантовые операторы)
// ============================================================================

/// Принцип неопределённости Гейзенберга: ΔxΔp ≥ ℏ/2
pub fn uncertainty_momentum(delta_x: f64) f64 {
    return hbar / (2 * delta_x);
}

/// Минимальная скорость из принципа неопределённости
pub fn uncertainty_velocity(delta_x: f64, m: f64) f64 {
    return uncertainty_momentum(delta_x) / m;
}

/// Энергия частицы в бесконечной потенциальной яме
/// Eₙ = n²π²ℏ²/(2mL²)
pub fn energy_particle_in_box(n: u32, L: f64, m: f64) f64 {
    const n_f = @as(f64, @floatFromInt(n));
    return (n_f * n_f * pi * pi * hbar * hbar) / (2 * m * L * L);
}

/// Энергия квантового гармонического осциллятора
/// Eₙ = ℏω(n + 1/2)
pub fn energy_harmonic_oscillator(n: u32, omega: f64) f64 {
    const n_f = @as(f64, @floatFromInt(n));
    return hbar * omega * (n_f + 0.5);
}

/// Энергетические уровни атома водорода
/// Eₙ = -13.6/n² эВ
pub fn hydrogen_energy_eV(n: u32) f64 {
    const n_f = @as(f64, @floatFromInt(n));
    return -E_H / (n_f * n_f);
}

pub fn hydrogen_energy_J(n: u32) f64 {
    return hydrogen_energy_eV(n) * eV;
}

/// Вероятность туннелирования через прямоугольный барьер
/// T ≈ exp(-2κL), где κ = √(2m(V₀-E))/ℏ
pub fn tunneling_probability(E: f64, V0: f64, L: f64, m: f64) f64 {
    if (E >= V0) return 1.0; // Классически разрешено

    const kappa = @sqrt(2 * m * (V0 - E) * eV) / hbar;
    return @exp(-2 * kappa * L);
}

/// Длина волны де Бройля: λ = h/p
pub fn de_broglie_wavelength(p: f64) f64 {
    return h / p;
}

/// Длина волны де Бройля для частицы с кинетической энергией
pub fn de_broglie_wavelength_energy(E: f64, m: f64) f64 {
    const p = @sqrt(2 * m * E);
    return h / p;
}

/// Проекция спина электрона: Sₓ = ±ℏ/2
pub fn spin_projection(spin_up: bool) f64 {
    return if (spin_up) hbar / 2 else -hbar / 2;
}

/// Энергия фотона: E = hν = hc/λ
pub fn photon_energy(wavelength: f64) f64 {
    const c: f64 = 299792458;
    return h * c / wavelength;
}

/// Частота перехода между уровнями водорода
pub fn hydrogen_transition_frequency(n1: u32, n2: u32) f64 {
    const E1 = hydrogen_energy_J(n1);
    const E2 = hydrogen_energy_J(n2);
    return @abs(E2 - E1) / h;
}

// ============================================================================
// ЭВОЛЮЦИЯ ВОЛНОВОЙ ФУНКЦИИ
// ============================================================================

/// Временная эволюция стационарного состояния
/// ψ(t) = ψ(0) * exp(-iEt/ℏ)
pub fn stationary_state_evolution(E: f64, t: f64) Complex {
    const phase = -E * t / hbar;
    return Complex.exp_i(phase);
}

/// Вероятность найти частицу (|ψ|²)
pub fn probability_density(psi: Complex) f64 {
    return psi.magnitude_squared();
}

/// Нормировка волновой функции
pub fn normalize(amplitudes: []f64, dx: f64) f64 {
    var sum: f64 = 0;
    for (amplitudes) |a| {
        sum += a * a * dx;
    }
    return @sqrt(sum);
}

// ============================================================================
// АНАЛИЗ ПАТТЕРНА ТВОРЕНИЯ
// ============================================================================

pub const CreationPatternAnalysis = struct {
    principle_name: []const u8,
    source_type: []const u8,
    transformer: []const u8,
    result_type: []const u8,
    key_insight: []const u8,
    deterministic: bool,
};

pub fn analyze_quantum_principles() [4]CreationPatternAnalysis {
    return [_]CreationPatternAnalysis{
        .{
            .principle_name = "Уравнение Шрёдингера",
            .source_type = "Волновая функция ψ(t₀)",
            .transformer = "iℏ∂ψ/∂t = Ĥψ",
            .result_type = "Волновая функция ψ(t)",
            .key_insight = "Эволюция ДЕТЕРМИНИРОВАНА (унитарна)",
            .deterministic = true,
        },
        .{
            .principle_name = "Измерение (Коллапс)",
            .source_type = "Суперпозиция ψ = Σcₙψₙ",
            .transformer = "Оператор измерения",
            .result_type = "Собственное состояние ψₙ",
            .key_insight = "Результат ВЕРОЯТНОСТНЫЙ (P = |cₙ|²)",
            .deterministic = false, // КЛЮЧЕВОЕ ОТЛИЧИЕ!
        },
        .{
            .principle_name = "Принцип неопределённости",
            .source_type = "Квантовое состояние",
            .transformer = "Одновременное измерение x и p",
            .result_type = "ΔxΔp ≥ ℏ/2",
            .key_insight = "ФУНДАМЕНТАЛЬНЫЙ предел знания",
            .deterministic = false,
        },
        .{
            .principle_name = "Квантовое туннелирование",
            .source_type = "Частица перед барьером (E < V₀)",
            .transformer = "Волновая природа",
            .result_type = "Частица за барьером (P > 0)",
            .key_insight = "Классически НЕВОЗМОЖНОЕ становится возможным",
            .deterministic = false,
        },
    };
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "uncertainty: minimum_momentum" {
    // Δp ≥ ℏ/(2Δx)
    const dp = uncertainty_momentum(1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 5.27e-25), dp, 1e-26);
}

test "uncertainty: electron_velocity" {
    // v = Δp/m
    const v = uncertainty_velocity(1e-10, m_e);
    try std.testing.expectApproxEqAbs(@as(f64, 5.79e5), v, 1e4);
}

test "particle_in_box: ground_state" {
    // E₁ = π²ℏ²/(2mL²)
    const E = energy_particle_in_box(1, 1e-9, m_e);
    try std.testing.expectApproxEqAbs(@as(f64, 6.02e-20), E, 1e-21);
}

test "particle_in_box: second_level" {
    // E₂ = 4E₁
    const E1 = energy_particle_in_box(1, 1e-9, m_e);
    const E2 = energy_particle_in_box(2, 1e-9, m_e);
    try std.testing.expectApproxEqAbs(E1 * 4, E2, 1e-21);
}

test "harmonic_oscillator: ground_state" {
    // E₀ = ℏω/2
    const E = energy_harmonic_oscillator(0, 1e15);
    try std.testing.expectApproxEqAbs(@as(f64, 5.27e-20), E, 1e-21);
}

test "harmonic_oscillator: first_excited" {
    // E₁ = 3ℏω/2 = 3E₀
    const E0 = energy_harmonic_oscillator(0, 1e15);
    const E1 = energy_harmonic_oscillator(1, 1e15);
    try std.testing.expectApproxEqAbs(E0 * 3, E1, 1e-21);
}

test "hydrogen: ground_state" {
    // E₁ = -13.6 эВ
    const E = hydrogen_energy_eV(1);
    try std.testing.expectApproxEqAbs(@as(f64, -13.6), E, 0.1);
}

test "hydrogen: first_excited" {
    // E₂ = -13.6/4 = -3.4 эВ
    const E = hydrogen_energy_eV(2);
    try std.testing.expectApproxEqAbs(@as(f64, -3.4), E, 0.1);
}

test "tunneling: thin_barrier" {
    // Тонкий барьер - ненулевая вероятность
    const T = tunneling_probability(1, 2, 1e-10, m_e);
    // T = exp(-2κL), κ = √(2m(V₀-E))/ℏ
    // Для E=1eV, V₀=2eV, L=0.1nm: T ≈ 0.13
    try std.testing.expect(T > 0.01);
    try std.testing.expect(T < 1.0);
}

test "tunneling: thick_barrier" {
    // Толстый барьер - очень низкая вероятность
    const T = tunneling_probability(1, 2, 1e-9, m_e);
    // Для L=1nm: T ≈ exp(-10) ≈ 4.5e-5
    try std.testing.expect(T < 0.01);
    try std.testing.expect(T > 0);
}

test "spin: up_and_down" {
    const s_up = spin_projection(true);
    const s_down = spin_projection(false);
    try std.testing.expectApproxEqAbs(hbar / 2, s_up, 1e-36);
    try std.testing.expectApproxEqAbs(-hbar / 2, s_down, 1e-36);
}

test "de_broglie: electron" {
    // λ = h/p для электрона с p = m*v
    const v: f64 = 1e6; // 1 млн м/с
    const p = m_e * v;
    const lambda = de_broglie_wavelength(p);
    try std.testing.expectApproxEqAbs(@as(f64, 7.27e-10), lambda, 1e-11);
}

test "creation_pattern: quantum_analysis" {
    const analysis = analyze_quantum_principles();
    try std.testing.expect(analysis.len == 4);
    // Только уравнение Шрёдингера детерминировано
    try std.testing.expect(analysis[0].deterministic);
    // Измерение, неопределённость, туннелирование - вероятностны
    try std.testing.expect(!analysis[1].deterministic);
    try std.testing.expect(!analysis[2].deterministic);
    try std.testing.expect(!analysis[3].deterministic);
}

// ============================================================================
// MAIN: Демонстрация паттерна творения
// ============================================================================

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("КВАНТОВАЯ МЕХАНИКА - ПАТТЕРН ТВОРЕНИЯ\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Паттерн: Источник → Трансформер → Результат\n", .{});
    print("         ψ(t₀) → Ĥ → ψ(t)\n\n", .{});

    // Анализ принципов
    const analysis = analyze_quantum_principles();
    print("Квантовые принципы как трансформации:\n\n", .{});

    for (analysis) |principle| {
        print("  {s}\n", .{principle.principle_name});
        print("    Источник: {s}\n", .{principle.source_type});
        print("    Трансформер: {s}\n", .{principle.transformer});
        print("    Результат: {s}\n", .{principle.result_type});
        print("    Ключевой инсайт: {s}\n", .{principle.key_insight});
        print("    Детерминизм: {}\n\n", .{principle.deterministic});
    }

    // Ключевое открытие
    print("=" ** 60 ++ "\n", .{});
    print("КЛЮЧЕВОЕ ОТКРЫТИЕ:\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Квантовая механика вводит ФУНДАМЕНТАЛЬНУЮ ВЕРОЯТНОСТЬ:\n\n", .{});
    print("  • Эволюция (Шрёдингер): ДЕТЕРМИНИРОВАНА\n", .{});
    print("  • Измерение (Коллапс): ВЕРОЯТНОСТНО\n\n", .{});

    print("Это отличает КМ от всей классической физики!\n\n", .{});

    // Демонстрации
    print("Принцип неопределённости (Δx = 1 Å):\n", .{});
    const dp = uncertainty_momentum(1e-10);
    const dv = uncertainty_velocity(1e-10, m_e);
    print("  Минимальная неопределённость импульса: {d:.2e} кг·м/с\n", .{dp});
    print("  Минимальная неопределённость скорости: {d:.2e} м/с\n\n", .{dv});

    print("Частица в ящике (L = 1 нм, электрон):\n", .{});
    for (1..4) |n| {
        const E = energy_particle_in_box(@intCast(n), 1e-9, m_e);
        print("  E{d} = {d:.2e} Дж = {d:.2} эВ\n", .{ n, E, E / eV });
    }
    print("\n", .{});

    print("Атом водорода:\n", .{});
    for (1..5) |n| {
        const E = hydrogen_energy_eV(@intCast(n));
        print("  E{d} = {d:.2} эВ\n", .{ n, E });
    }
    print("\n", .{});

    print("Квантовое туннелирование (E=1 эВ, V₀=2 эВ):\n", .{});
    const T_thin = tunneling_probability(1, 2, 1e-10, m_e);
    const T_thick = tunneling_probability(1, 2, 1e-9, m_e);
    print("  L = 1 Å: T = {d:.2}%\n", .{T_thin * 100});
    print("  L = 1 нм: T = {d:.2e}\n\n", .{T_thick});

    print("ВЫВОД: Квантовая механика показывает, что на\n", .{});
    print("       фундаментальном уровне природа ВЕРОЯТНОСТНА.\n", .{});
    print("       Паттерн творения включает НЕОПРЕДЕЛЁННОСТЬ.\n", .{});
}
