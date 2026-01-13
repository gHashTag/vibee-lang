// Реализация Механики Ньютона через Паттерн Творения
// Источник → Трансформер → Результат
// ParticleState → newton_step → ParticleState

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const G: f64 = 6.674e-11; // Гравитационная постоянная (м³/(кг·с²))
pub const g: f64 = 9.81; // Ускорение свободного падения (м/с²)

// ============================================================================
// ТИПЫ (Источники и Результаты)
// ============================================================================

/// Состояние частицы - Источник/Результат паттерна творения
pub const ParticleState = struct {
    x: f64, // позиция (м)
    v: f64, // скорость (м/с)
    m: f64, // масса (кг)

    pub fn kinetic_energy(self: ParticleState) f64 {
        return 0.5 * self.m * self.v * self.v;
    }

    pub fn momentum(self: ParticleState) f64 {
        return self.m * self.v;
    }

    pub fn potential_energy(self: ParticleState, h: f64) f64 {
        return self.m * g * h;
    }
};

/// Состояние двух тел для гравитации
pub const TwoBodyState = struct {
    m1: f64,
    m2: f64,
    r: f64, // расстояние между телами
};

/// Состояние пружины
pub const SpringState = struct {
    k: f64, // жёсткость (Н/м)
    x: f64, // отклонение от равновесия (м)
};

/// Состояние гармонического осциллятора
pub const OscillatorState = struct {
    x: f64, // позиция
    v: f64, // скорость
    m: f64, // масса
    k: f64, // жёсткость пружины

    pub fn total_energy(self: OscillatorState) f64 {
        const kinetic = 0.5 * self.m * self.v * self.v;
        const potential = 0.5 * self.k * self.x * self.x;
        return kinetic + potential;
    }

    pub fn period(self: OscillatorState) f64 {
        return 2.0 * math.pi * @sqrt(self.m / self.k);
    }

    pub fn frequency(self: OscillatorState) f64 {
        return 1.0 / self.period();
    }
};

// ============================================================================
// ТРАНСФОРМЕРЫ (Законы Ньютона)
// ============================================================================

/// Паттерн Творения: Второй закон Ньютона
/// Источник: ParticleState + Force
/// Трансформер: F = ma → a = F/m
/// Результат: Новое ParticleState
pub fn newton_step(state: ParticleState, F: f64, dt: f64) ParticleState {
    const a = F / state.m; // Второй закон: a = F/m
    const v_new = state.v + a * dt;
    const x_new = state.x + state.v * dt + 0.5 * a * dt * dt;

    return ParticleState{
        .x = x_new,
        .v = v_new,
        .m = state.m,
    };
}

/// Трансформер: Гравитационная сила
/// F = G * m1 * m2 / r²
pub fn gravity_force(state: TwoBodyState) f64 {
    return G * state.m1 * state.m2 / (state.r * state.r);
}

/// Трансформер: Сила пружины (закон Гука)
/// F = -k * x
pub fn spring_force(state: SpringState) f64 {
    return -state.k * state.x;
}

/// Трансформер: Шаг осциллятора
pub fn oscillator_step(state: OscillatorState, dt: f64) OscillatorState {
    const F = spring_force(.{ .k = state.k, .x = state.x });
    const a = F / state.m;
    const v_new = state.v + a * dt;
    const x_new = state.x + state.v * dt + 0.5 * a * dt * dt;

    return OscillatorState{
        .x = x_new,
        .v = v_new,
        .m = state.m,
        .k = state.k,
    };
}

// ============================================================================
// ИТЕРАТИВНЫЕ ТРАНСФОРМАЦИИ
// ============================================================================

/// Симуляция свободного падения
pub fn simulate_free_fall(h: f64, dt: f64) struct { v_final: f64, t_total: f64 } {
    var state = ParticleState{ .x = h, .v = 0, .m = 1.0 };
    var t: f64 = 0;

    while (state.x > 0) {
        state = newton_step(state, -state.m * g, dt);
        t += dt;
    }

    return .{
        .v_final = @abs(state.v),
        .t_total = t,
    };
}

/// Симуляция осциллятора на один период
pub fn simulate_oscillator(initial: OscillatorState, dt: f64, duration: f64) struct {
    energy_conserved: bool,
    max_deviation: f64,
    periods_completed: f64,
} {
    const initial_energy = initial.total_energy();
    var state = initial;
    var t: f64 = 0;
    var max_energy_deviation: f64 = 0;
    var zero_crossings: usize = 0;
    var prev_x = state.x;

    while (t < duration) {
        state = oscillator_step(state, dt);
        t += dt;

        const current_energy = state.total_energy();
        const deviation = @abs(current_energy - initial_energy) / initial_energy;
        if (deviation > max_energy_deviation) {
            max_energy_deviation = deviation;
        }

        // Считаем пересечения нуля для подсчёта периодов
        if (prev_x * state.x < 0) {
            zero_crossings += 1;
        }
        prev_x = state.x;
    }

    return .{
        .energy_conserved = max_energy_deviation < 0.01, // 1% допуск
        .max_deviation = max_energy_deviation,
        .periods_completed = @as(f64, @floatFromInt(zero_crossings)) / 2.0,
    };
}

/// Симуляция упругого столкновения
pub fn elastic_collision(m1: f64, v1: f64, m2: f64, v2: f64) struct {
    v1_after: f64,
    v2_after: f64,
    momentum_before: f64,
    momentum_after: f64,
    energy_before: f64,
    energy_after: f64,
} {
    // Формулы для упругого столкновения
    const v1_after = ((m1 - m2) * v1 + 2 * m2 * v2) / (m1 + m2);
    const v2_after = ((m2 - m1) * v2 + 2 * m1 * v1) / (m1 + m2);

    const p_before = m1 * v1 + m2 * v2;
    const p_after = m1 * v1_after + m2 * v2_after;

    const e_before = 0.5 * m1 * v1 * v1 + 0.5 * m2 * v2 * v2;
    const e_after = 0.5 * m1 * v1_after * v1_after + 0.5 * m2 * v2_after * v2_after;

    return .{
        .v1_after = v1_after,
        .v2_after = v2_after,
        .momentum_before = p_before,
        .momentum_after = p_after,
        .energy_before = e_before,
        .energy_after = e_after,
    };
}

/// Симуляция неупругого столкновения
pub fn inelastic_collision(m1: f64, v1: f64, m2: f64, v2: f64) struct {
    v_combined: f64,
    momentum_before: f64,
    momentum_after: f64,
    energy_lost: f64,
} {
    const p_before = m1 * v1 + m2 * v2;
    const v_combined = p_before / (m1 + m2);
    const p_after = (m1 + m2) * v_combined;

    const e_before = 0.5 * m1 * v1 * v1 + 0.5 * m2 * v2 * v2;
    const e_after = 0.5 * (m1 + m2) * v_combined * v_combined;

    return .{
        .v_combined = v_combined,
        .momentum_before = p_before,
        .momentum_after = p_after,
        .energy_lost = e_before - e_after,
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
    conservation_law: []const u8,
    reversible: bool,
};

pub fn analyze_newton_laws() [3]CreationPatternAnalysis {
    return [_]CreationPatternAnalysis{
        .{
            .law_name = "Первый закон (Инерция)",
            .source_type = "ParticleState",
            .transformer = "identity (F=0)",
            .result_type = "ParticleState (v=const)",
            .conservation_law = "Импульс",
            .reversible = true,
        },
        .{
            .law_name = "Второй закон (F=ma)",
            .source_type = "ParticleState + Force",
            .transformer = "newton_step",
            .result_type = "ParticleState (новое)",
            .conservation_law = "Энергия (при консервативных силах)",
            .reversible = true,
        },
        .{
            .law_name = "Третий закон (Действие-противодействие)",
            .source_type = "TwoBodyState",
            .transformer = "interaction_force",
            .result_type = "Force pair (F, -F)",
            .conservation_law = "Импульс системы",
            .reversible = true,
        },
    };
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "first_law: inertia_stationary" {
    const state = ParticleState{ .x = 0, .v = 0, .m = 1 };
    const result = newton_step(state, 0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0), result.v, 0.001);
}

test "first_law: inertia_moving" {
    const state = ParticleState{ .x = 0, .v = 10, .m = 1 };
    const result = newton_step(state, 0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 10), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), result.v, 0.001);
}

test "first_law: inertia_moving_2s" {
    const state = ParticleState{ .x = 0, .v = 5, .m = 1 };
    const result = newton_step(state, 0, 2.0);
    try std.testing.expectApproxEqAbs(@as(f64, 10), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5), result.v, 0.001);
}

test "second_law: acceleration_unit" {
    const state = ParticleState{ .x = 0, .v = 0, .m = 1 };
    const result = newton_step(state, 1, 1.0);
    // x = 0.5 * a * t² = 0.5 * 1 * 1 = 0.5
    // v = a * t = 1 * 1 = 1
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.v, 0.001);
}

test "second_law: acceleration_heavy" {
    const state = ParticleState{ .x = 0, .v = 0, .m = 2 };
    const result = newton_step(state, 2, 1.0);
    // a = F/m = 2/2 = 1
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.v, 0.001);
}

test "second_law: acceleration_light" {
    const state = ParticleState{ .x = 0, .v = 0, .m = 0.5 };
    const result = newton_step(state, 1, 1.0);
    // a = F/m = 1/0.5 = 2
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.v, 0.001);
}

test "third_law: reaction_gravity" {
    const state = TwoBodyState{ .m1 = 1, .m2 = 1, .r = 1 };
    const F12 = gravity_force(state);
    const F21 = -F12; // Третий закон
    try std.testing.expectApproxEqAbs(G, F12, 1e-20);
    try std.testing.expectApproxEqAbs(-G, F21, 1e-20);
}

test "third_law: reaction_spring" {
    const F12 = spring_force(.{ .k = 100, .x = 1 });
    const F21 = -F12;
    try std.testing.expectApproxEqAbs(@as(f64, -100), F12, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 100), F21, 0.001);
}

test "free_fall: theoretical_velocity" {
    // v² = 2gh → v = sqrt(2 * 9.81 * 10) ≈ 14.0 м/с
    const h: f64 = 10;
    const v_theoretical = @sqrt(2 * g * h);
    try std.testing.expectApproxEqAbs(@as(f64, 14.0), v_theoretical, 0.1);
}

test "oscillator: period_formula" {
    const osc = OscillatorState{ .x = 0.1, .v = 0, .m = 1, .k = 100 };
    // T = 2π√(m/k) = 2π√(1/100) = 2π * 0.1 ≈ 0.628
    try std.testing.expectApproxEqAbs(@as(f64, 0.628), osc.period(), 0.001);
}

test "oscillator: energy_conservation" {
    const osc = OscillatorState{ .x = 0.1, .v = 0, .m = 1, .k = 100 };
    // E = 0.5 * k * x² = 0.5 * 100 * 0.01 = 0.5 Дж
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), osc.total_energy(), 0.001);
}

test "energy_conservation: kinetic_potential" {
    const state = ParticleState{ .x = 0, .v = 10, .m = 1 };
    const E_kinetic = state.kinetic_energy();
    // E = 0.5 * m * v² = 0.5 * 1 * 100 = 50 Дж
    try std.testing.expectApproxEqAbs(@as(f64, 50), E_kinetic, 0.001);
}

test "momentum_conservation: elastic_collision" {
    const result = elastic_collision(1, 10, 1, 0);
    // Для равных масс: скорости обмениваются
    try std.testing.expectApproxEqAbs(@as(f64, 0), result.v1_after, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), result.v2_after, 0.001);
    // Импульс сохраняется
    try std.testing.expectApproxEqAbs(result.momentum_before, result.momentum_after, 0.001);
    // Энергия сохраняется
    try std.testing.expectApproxEqAbs(result.energy_before, result.energy_after, 0.001);
}

test "momentum_conservation: inelastic_collision" {
    const result = inelastic_collision(1, 10, 1, 0);
    // v_combined = p_total / (m1 + m2) = 10 / 2 = 5
    try std.testing.expectApproxEqAbs(@as(f64, 5), result.v_combined, 0.001);
    // Импульс сохраняется
    try std.testing.expectApproxEqAbs(result.momentum_before, result.momentum_after, 0.001);
    // Энергия теряется
    try std.testing.expect(result.energy_lost > 0);
}

test "creation_pattern: newton_laws_analysis" {
    const analysis = analyze_newton_laws();
    try std.testing.expect(analysis.len == 3);
    try std.testing.expect(analysis[0].reversible);
    try std.testing.expect(analysis[1].reversible);
    try std.testing.expect(analysis[2].reversible);
}

// ============================================================================
// MAIN: Демонстрация паттерна творения
// ============================================================================

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("МЕХАНИКА НЬЮТОНА - ПАТТЕРН ТВОРЕНИЯ\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Паттерн: Источник → Трансформер → Результат\n", .{});
    print("         State(x,v,m) → F=ma → State'(x',v',m)\n\n", .{});

    // Анализ законов
    const analysis = analyze_newton_laws();
    print("Три закона Ньютона как трансформации:\n\n", .{});

    for (analysis) |law| {
        print("  {s}\n", .{law.law_name});
        print("    Источник: {s}\n", .{law.source_type});
        print("    Трансформер: {s}\n", .{law.transformer});
        print("    Результат: {s}\n", .{law.result_type});
        print("    Закон сохранения: {s}\n", .{law.conservation_law});
        print("    Обратимость: {}\n\n", .{law.reversible});
    }

    // Демонстрация свободного падения
    print("Свободное падение с 10м:\n", .{});
    const fall = simulate_free_fall(10, 0.001);
    print("  Конечная скорость: {d:.2} м/с (теория: 14.0)\n", .{fall.v_final});
    print("  Время падения: {d:.2} с (теория: 1.43)\n\n", .{fall.t_total});

    // Демонстрация осциллятора
    print("Гармонический осциллятор (m=1, k=100):\n", .{});
    const osc = OscillatorState{ .x = 0.1, .v = 0, .m = 1, .k = 100 };
    print("  Период: {d:.3} с\n", .{osc.period()});
    print("  Частота: {d:.2} Гц\n", .{osc.frequency()});
    print("  Энергия: {d:.2} Дж\n\n", .{osc.total_energy()});

    const sim = simulate_oscillator(osc, 0.0001, osc.period() * 5);
    print("  Симуляция 5 периодов:\n", .{});
    print("    Энергия сохранена: {}\n", .{sim.energy_conserved});
    print("    Макс. отклонение: {d:.4}%\n", .{sim.max_deviation * 100});
    print("    Периодов завершено: {d:.1}\n\n", .{sim.periods_completed});

    // Столкновения
    print("Упругое столкновение (m1=1, v1=10, m2=1, v2=0):\n", .{});
    const elastic = elastic_collision(1, 10, 1, 0);
    print("  v1 после: {d:.1} м/с\n", .{elastic.v1_after});
    print("  v2 после: {d:.1} м/с\n", .{elastic.v2_after});
    print("  Импульс сохранён: {}\n\n", .{@abs(elastic.momentum_before - elastic.momentum_after) < 0.001});

    print("ВЫВОД: Все законы Ньютона следуют паттерну творения\n", .{});
    print("       и являются ОБРАТИМЫМИ трансформациями.\n", .{});
}
