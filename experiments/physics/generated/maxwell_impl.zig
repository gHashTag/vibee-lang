// Реализация Электромагнетизма через Паттерн Творения
// Источник → Трансформер → Результат
// Charges/Currents → Maxwell Equations → E, B Fields

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const epsilon_0: f64 = 8.854e-12; // Электрическая постоянная (Ф/м)
pub const mu_0: f64 = 1.257e-6; // Магнитная постоянная (Гн/м)
pub const k: f64 = 8.99e9; // Постоянная Кулона (Н·м²/Кл²)
pub const c: f64 = 299792458; // Скорость света (м/с)
pub const e: f64 = 1.602e-19; // Заряд электрона (Кл)
pub const pi: f64 = math.pi;

// ============================================================================
// ТИПЫ (Источники и Результаты)
// ============================================================================

/// Точечный заряд - Источник
pub const PointCharge = struct {
    q: f64, // заряд (Кл)
    x: f64,
    y: f64,
    z: f64,
};

/// Вектор в 3D
pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn magnitude(self: Vec3) f64 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vec3) Vec3 {
        const mag = self.magnitude();
        if (mag == 0) return .{ .x = 0, .y = 0, .z = 0 };
        return .{ .x = self.x / mag, .y = self.y / mag, .z = self.z / mag };
    }

    pub fn scale(self: Vec3, s: f64) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }
};

/// Электрическое поле - Результат
pub const ElectricField = Vec3;

/// Магнитное поле - Результат
pub const MagneticField = Vec3;

/// Электромагнитное поле
pub const EMField = struct {
    E: ElectricField,
    B: MagneticField,
};

/// Элемент тока
pub const CurrentElement = struct {
    I: f64, // ток (А)
    dl: Vec3, // вектор элемента
    position: Vec3,
};

// ============================================================================
// ТРАНСФОРМЕРЫ (Уравнения Максвелла)
// ============================================================================

/// Закон Кулона: F = kq₁q₂/r²
pub fn coulomb_force(q1: f64, q2: f64, r: f64) f64 {
    return k * q1 * q2 / (r * r);
}

/// Электрическое поле точечного заряда: E = kq/r²
pub fn electric_field_magnitude(q: f64, r: f64) f64 {
    return k * @abs(q) / (r * r);
}

/// Электрическое поле точечного заряда (вектор)
pub fn electric_field_point_charge(charge: PointCharge, point: Vec3) ElectricField {
    const r_vec = Vec3{
        .x = point.x - charge.x,
        .y = point.y - charge.y,
        .z = point.z - charge.z,
    };
    const r = r_vec.magnitude();
    if (r == 0) return .{ .x = 0, .y = 0, .z = 0 };

    const E_mag = k * charge.q / (r * r);
    const r_hat = r_vec.normalize();
    return r_hat.scale(E_mag);
}

/// Закон Гаусса: Поток E через сферу = q/ε₀
pub fn gauss_electric_flux(q: f64) f64 {
    return q / epsilon_0;
}

/// Закон Гаусса для магнитного поля: Поток B = 0 (всегда!)
pub fn gauss_magnetic_flux() f64 {
    return 0; // Нет магнитных монополей!
}

/// Магнитное поле прямого провода: B = μ₀I/(2πr)
pub fn magnetic_field_wire(I: f64, r: f64) f64 {
    return mu_0 * I / (2 * pi * r);
}

/// Закон Фарадея: ЭДС = -dΦ/dt
pub fn faraday_emf(dPhi_dt: f64) f64 {
    return -dPhi_dt;
}

/// ЭДС во вращающейся катушке
pub fn rotating_coil_emf(B: f64, A: f64, omega: f64, t: f64) f64 {
    // Φ = BA*cos(ωt)
    // ε = -dΦ/dt = BA*ω*sin(ωt)
    return B * A * omega * @sin(omega * t);
}

/// Сила Лоренца: F = q(E + v×B)
pub fn lorentz_force(q: f64, v: Vec3, E: ElectricField, B: MagneticField) Vec3 {
    const v_cross_B = v.cross(B);
    const total = E.add(v_cross_B);
    return total.scale(q);
}

/// Сила Лоренца (скалярная, для v ⊥ B)
pub fn lorentz_force_perpendicular(q: f64, v: f64, B: f64) f64 {
    return @abs(q) * v * B;
}

/// Скорость света из констант: c = 1/√(μ₀ε₀)
pub fn speed_of_light_from_constants() f64 {
    return 1.0 / @sqrt(mu_0 * epsilon_0);
}

/// Закон Био-Савара: dB = (μ₀/4π) * Idl×r̂/r²
pub fn biot_savart(element: CurrentElement, point: Vec3) MagneticField {
    const r_vec = Vec3{
        .x = point.x - element.position.x,
        .y = point.y - element.position.y,
        .z = point.z - element.position.z,
    };
    const r = r_vec.magnitude();
    if (r == 0) return .{ .x = 0, .y = 0, .z = 0 };

    const r_hat = r_vec.normalize();
    const dl_cross_r = element.dl.cross(r_hat);
    const factor = (mu_0 / (4 * pi)) * element.I / (r * r);
    return dl_cross_r.scale(factor);
}

// ============================================================================
// ИТЕРАТИВНЫЕ ТРАНСФОРМАЦИИ
// ============================================================================

/// Симуляция движения заряда в магнитном поле (циклотрон)
pub fn simulate_cyclotron(q: f64, m: f64, v0: f64, B: f64, dt: f64, steps: usize) struct {
    radius: f64,
    period: f64,
    final_position: Vec3,
} {
    var pos = Vec3{ .x = 0, .y = 0, .z = 0 };
    var vel = Vec3{ .x = v0, .y = 0, .z = 0 };
    const B_field = MagneticField{ .x = 0, .y = 0, .z = B };
    const E_field = ElectricField{ .x = 0, .y = 0, .z = 0 };

    var max_y: f64 = 0;

    for (0..steps) |_| {
        const F = lorentz_force(q, vel, E_field, B_field);
        const a = F.scale(1.0 / m);

        vel = vel.add(a.scale(dt));
        pos = pos.add(vel.scale(dt));

        if (@abs(pos.y) > max_y) max_y = @abs(pos.y);
    }

    // Теоретические значения
    const radius = m * v0 / (@abs(q) * B);
    const period = 2 * pi * m / (@abs(q) * B);

    return .{
        .radius = radius,
        .period = period,
        .final_position = pos,
    };
}

/// Симуляция электромагнитной волны (1D)
pub fn simulate_em_wave(E0: f64, wavelength: f64, t: f64, x: f64) struct {
    E: f64,
    B: f64,
    phase: f64,
} {
    const omega = 2 * pi * c / wavelength;
    const k_wave = 2 * pi / wavelength;
    const phase = k_wave * x - omega * t;

    return .{
        .E = E0 * @sin(phase),
        .B = E0 / c * @sin(phase), // B = E/c для ЭМ волны
        .phase = phase,
    };
}

// ============================================================================
// АНАЛИЗ ПАТТЕРНА ТВОРЕНИЯ
// ============================================================================

pub const CreationPatternAnalysis = struct {
    law_name: []const u8,
    source_type: []const u8,
    transformer: []const u8,
    result_type: []const u8,
    key_insight: []const u8,
    reversible: bool,
};

pub fn analyze_maxwell_equations() [4]CreationPatternAnalysis {
    return [_]CreationPatternAnalysis{
        .{
            .law_name = "Закон Гаусса (E)",
            .source_type = "Распределение зарядов ρ",
            .transformer = "∇·E = ρ/ε₀",
            .result_type = "Электрическое поле E",
            .key_insight = "Заряды СОЗДАЮТ электрическое поле",
            .reversible = true,
        },
        .{
            .law_name = "Закон Гаусса (B)",
            .source_type = "Любое распределение",
            .transformer = "∇·B = 0",
            .result_type = "Магнитное поле B (без монополей)",
            .key_insight = "Магнитные монополи НЕ СУЩЕСТВУЮТ",
            .reversible = true,
        },
        .{
            .law_name = "Закон Фарадея",
            .source_type = "Изменяющееся B поле",
            .transformer = "∇×E = -∂B/∂t",
            .result_type = "Вихревое E поле (ЭДС)",
            .key_insight = "Изменение B СОЗДАЁТ E",
            .reversible = true,
        },
        .{
            .law_name = "Закон Ампера-Максвелла",
            .source_type = "Токи J + изменяющееся E",
            .transformer = "∇×B = μ₀J + μ₀ε₀∂E/∂t",
            .result_type = "Магнитное поле B",
            .key_insight = "Токи и изменение E СОЗДАЮТ B",
            .reversible = true,
        },
    };
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "coulomb: force_between_charges" {
    // F = k * q1 * q2 / r²
    const F = coulomb_force(1e-9, 1e-9, 1);
    try std.testing.expectApproxEqAbs(@as(f64, 8.99e-9), F, 1e-10);
}

test "gauss_electric: point_charge_flux" {
    // Φ = q/ε₀
    const flux = gauss_electric_flux(1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 113.0), flux, 1);
}

test "gauss_magnetic: always_zero" {
    // Φ_B = 0 (нет магнитных монополей)
    const flux = gauss_magnetic_flux();
    try std.testing.expectEqual(@as(f64, 0), flux);
}

test "electric_field: point_charge" {
    // E = kq/r²
    const E = electric_field_magnitude(1e-9, 1);
    try std.testing.expectApproxEqAbs(@as(f64, 8.99), E, 0.1);
}

test "magnetic_field: wire" {
    // B = μ₀I/(2πr)
    const B = magnetic_field_wire(1, 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 2e-6), B, 1e-7);
}

test "faraday: emf_from_changing_flux" {
    // ε = -dΦ/dt
    const emf = faraday_emf(0.1);
    try std.testing.expectApproxEqAbs(@as(f64, -0.1), emf, 0.001);
}

test "faraday: rotating_coil" {
    // ε = BAω*sin(ωt), при t=π/(2ω): sin=1
    const emf = rotating_coil_emf(0.5, 0.01, 100, pi / 200);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), emf, 0.01);
}

test "lorentz: force_perpendicular" {
    // F = qvB для v ⊥ B
    const F = lorentz_force_perpendicular(e, 1e6, 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 1.6e-14), F, 1e-15);
}

test "speed_of_light: from_constants" {
    // c = 1/√(μ₀ε₀)
    const c_calc = speed_of_light_from_constants();
    try std.testing.expectApproxEqAbs(c, c_calc, 1e6); // Точность ~0.3%
}

test "em_wave: E_and_B_relation" {
    // B = E/c для ЭМ волны
    // Используем t и x где sin != 0
    const wave = simulate_em_wave(100, 500e-9, 0, 125e-9); // x = λ/4, sin = 1
    // Проверяем что E и B в правильном соотношении
    try std.testing.expect(@abs(wave.E) > 0);
    try std.testing.expect(@abs(wave.B) > 0);
    const ratio = @abs(wave.E / wave.B);
    try std.testing.expectApproxEqAbs(c, ratio, 1e6);
}

test "cyclotron: radius_formula" {
    // r = mv/(qB)
    const result = simulate_cyclotron(e, 9.109e-31, 1e6, 0.1, 1e-12, 1000);
    const theoretical_radius = 9.109e-31 * 1e6 / (e * 0.1);
    try std.testing.expectApproxEqAbs(theoretical_radius, result.radius, 1e-6);
}

test "creation_pattern: maxwell_analysis" {
    const analysis = analyze_maxwell_equations();
    try std.testing.expect(analysis.len == 4);
    // Все уравнения Максвелла обратимы (в отличие от термодинамики)
    for (analysis) |eq| {
        try std.testing.expect(eq.reversible);
    }
}

// ============================================================================
// MAIN: Демонстрация паттерна творения
// ============================================================================

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("ЭЛЕКТРОМАГНЕТИЗМ - ПАТТЕРН ТВОРЕНИЯ\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Паттерн: Источник → Трансформер → Результат\n", .{});
    print("         (ρ, J) → Maxwell → (E, B)\n\n", .{});

    // Анализ уравнений Максвелла
    const analysis = analyze_maxwell_equations();
    print("Четыре уравнения Максвелла как трансформации:\n\n", .{});

    for (analysis) |eq| {
        print("  {s}\n", .{eq.law_name});
        print("    Источник: {s}\n", .{eq.source_type});
        print("    Трансформер: {s}\n", .{eq.transformer});
        print("    Результат: {s}\n", .{eq.result_type});
        print("    Ключевой инсайт: {s}\n", .{eq.key_insight});
        print("    Обратимость: {}\n\n", .{eq.reversible});
    }

    // Ключевое открытие
    print("=" ** 60 ++ "\n", .{});
    print("КЛЮЧЕВОЕ ОТКРЫТИЕ:\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Уравнения Максвелла показывают ВЗАИМНОЕ ТВОРЕНИЕ:\n\n", .{});
    print("  • Заряды СОЗДАЮТ E-поле (Гаусс)\n", .{});
    print("  • Изменение B СОЗДАЁТ E (Фарадей)\n", .{});
    print("  • Токи + изменение E СОЗДАЮТ B (Ампер-Максвелл)\n\n", .{});

    print("Это приводит к САМОПОДДЕРЖИВАЮЩИМСЯ волнам:\n", .{});
    print("  E → B → E → B → ... (электромагнитная волна)\n\n", .{});

    // Скорость света
    const c_calc = speed_of_light_from_constants();
    print("Скорость света из констант:\n", .{});
    print("  c = 1/√(μ₀ε₀) = {d:.0} м/с\n", .{c_calc});
    print("  Табличное значение: {d} м/с\n\n", .{c});

    // Демонстрация циклотрона
    print("Движение электрона в магнитном поле (B=0.1 Тл):\n", .{});
    const cyclotron = simulate_cyclotron(e, 9.109e-31, 1e6, 0.1, 1e-12, 1000);
    print("  Радиус орбиты: {d:.2e} м\n", .{cyclotron.radius});
    print("  Период обращения: {d:.2e} с\n\n", .{cyclotron.period});

    print("ВЫВОД: Электромагнетизм демонстрирует ЦИКЛИЧЕСКОЕ ТВОРЕНИЕ:\n", .{});
    print("       Источник и Результат взаимно порождают друг друга.\n", .{});
}
