// Реализация Термодинамики через Паттерн Творения
// Источник → Трансформер → Результат
// ThermodynamicState → Laws → ThermodynamicState/Equilibrium

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const R: f64 = 8.314; // Газовая постоянная (Дж/(моль·К))
pub const k_B: f64 = 1.381e-23; // Постоянная Больцмана (Дж/К)
pub const N_A: f64 = 6.022e23; // Число Авогадро

// ============================================================================
// ТИПЫ (Источники и Результаты)
// ============================================================================

/// Термодинамическое состояние - Источник/Результат
pub const ThermodynamicState = struct {
    T: f64, // температура (K)
    P: f64, // давление (Pa)
    V: f64, // объём (m³)
    S: f64, // энтропия (J/K)
    U: f64, // внутренняя энергия (J)
};

/// Состояние идеального газа
pub const GasState = struct {
    n: f64, // количество вещества (моль)
    T: f64, // температура (K)
    P: f64, // давление (Pa)
    V: f64, // объём (m³)

    /// Проверка уравнения состояния PV = nRT
    pub fn verify_equation(self: GasState) bool {
        const expected_P = self.n * R * self.T / self.V;
        return @abs(self.P - expected_P) / self.P < 0.001;
    }
};

/// Состояние двух тел для теплообмена
pub const TwoBodyThermal = struct {
    T1: f64, // температура тела 1
    T2: f64, // температура тела 2
    C1: f64, // теплоёмкость тела 1
    C2: f64, // теплоёмкость тела 2

    pub fn in_equilibrium(self: TwoBodyThermal) bool {
        return @abs(self.T1 - self.T2) < 0.01;
    }

    pub fn equilibrium_temperature(self: TwoBodyThermal) f64 {
        return (self.C1 * self.T1 + self.C2 * self.T2) / (self.C1 + self.C2);
    }
};

/// Результат теплового процесса
pub const ProcessResult = struct {
    dU: f64, // изменение внутренней энергии
    dS: f64, // изменение энтропии
    W: f64, // работа
    Q: f64, // теплота
};

// ============================================================================
// ТРАНСФОРМЕРЫ (Законы Термодинамики)
// ============================================================================

/// Нулевой закон: Проверка термического равновесия
/// Транзитивность: если A~C и B~C, то A~B
pub fn check_equilibrium(T_A: f64, T_B: f64, T_C: f64, tolerance: f64) struct {
    A_eq_B: bool,
    A_eq_C: bool,
    B_eq_C: bool,
    transitive: bool,
} {
    const A_eq_C = @abs(T_A - T_C) < tolerance;
    const B_eq_C = @abs(T_B - T_C) < tolerance;
    const A_eq_B = @abs(T_A - T_B) < tolerance;

    // Проверка транзитивности: если A~C и B~C, то должно быть A~B
    const transitive = if (A_eq_C and B_eq_C) A_eq_B else true;

    return .{
        .A_eq_B = A_eq_B,
        .A_eq_C = A_eq_C,
        .B_eq_C = B_eq_C,
        .transitive = transitive,
    };
}

/// Первый закон: dU = δQ - δW
/// Сохранение энергии
pub fn first_law(Q: f64, W: f64) f64 {
    return Q - W; // dU
}

/// Второй закон: Изменение энтропии при теплопередаче
/// dS = δQ / T
pub fn entropy_change(Q: f64, T: f64) f64 {
    return Q / T;
}

/// Второй закон: Полное изменение энтропии при теплопередаче
pub fn total_entropy_change(T_hot: f64, T_cold: f64, Q: f64) struct {
    dS_hot: f64,
    dS_cold: f64,
    dS_total: f64,
    irreversible: bool,
} {
    const dS_hot = -Q / T_hot; // Горячее тело теряет энтропию
    const dS_cold = Q / T_cold; // Холодное тело получает энтропию
    const dS_total = dS_hot + dS_cold;

    return .{
        .dS_hot = dS_hot,
        .dS_cold = dS_cold,
        .dS_total = dS_total,
        .irreversible = dS_total > 0,
    };
}

/// Второй закон: Энтропия при свободном расширении
/// dS = nR * ln(V2/V1)
pub fn free_expansion_entropy(n: f64, V1: f64, V2: f64) f64 {
    return n * R * @log(V2 / V1);
}

/// Третий закон: Энтропия при низких температурах
/// S → 0 при T → 0
pub fn low_temperature_entropy(T: f64, S_0: f64, C: f64) f64 {
    // Модель Дебая: S ∝ T³ при низких T
    if (T < 1) {
        return S_0 * math.pow(f64, T, 3);
    }
    return C * @log(T);
}

/// Уравнение состояния идеального газа: PV = nRT
pub fn ideal_gas_pressure(n: f64, T: f64, V: f64) f64 {
    return n * R * T / V;
}

pub fn ideal_gas_volume(n: f64, T: f64, P: f64) f64 {
    return n * R * T / P;
}

pub fn ideal_gas_temperature(P: f64, V: f64, n: f64) f64 {
    return P * V / (n * R);
}

/// КПД цикла Карно: η = 1 - T_cold/T_hot
pub fn carnot_efficiency(T_hot: f64, T_cold: f64) f64 {
    return 1.0 - T_cold / T_hot;
}

/// Свободная энергия Гиббса: G = H - TS
pub fn gibbs_energy(H: f64, T: f64, S: f64) f64 {
    return H - T * S;
}

/// Изменение энергии Гиббса: dG = dH - T*dS
pub fn gibbs_change(dH: f64, T: f64, dS: f64) struct {
    dG: f64,
    spontaneous: bool,
} {
    const dG = dH - T * dS;
    return .{
        .dG = dG,
        .spontaneous = dG < 0,
    };
}

// ============================================================================
// ИТЕРАТИВНЫЕ ТРАНСФОРМАЦИИ
// ============================================================================

/// Симуляция теплообмена до равновесия
pub fn simulate_heat_transfer(initial: TwoBodyThermal, k: f64, dt: f64) struct {
    final_state: TwoBodyThermal,
    steps: usize,
    T_equilibrium: f64,
    entropy_generated: f64,
} {
    var state = initial;
    var steps: usize = 0;
    var total_entropy: f64 = 0;
    const max_steps: usize = 100000;

    while (!state.in_equilibrium() and steps < max_steps) {
        const dQ = k * (state.T1 - state.T2) * dt;

        // Изменение энтропии
        if (@abs(dQ) > 1e-10) {
            total_entropy += -dQ / state.T1 + dQ / state.T2;
        }

        state.T1 -= dQ / state.C1;
        state.T2 += dQ / state.C2;
        steps += 1;
    }

    return .{
        .final_state = state,
        .steps = steps,
        .T_equilibrium = state.equilibrium_temperature(),
        .entropy_generated = total_entropy,
    };
}

/// Адиабатический процесс: PV^γ = const
pub fn adiabatic_process(initial: GasState, V_final: f64, gamma: f64) GasState {
    // P1 * V1^γ = P2 * V2^γ
    const P_final = initial.P * math.pow(f64, initial.V / V_final, gamma);
    // T1 * V1^(γ-1) = T2 * V2^(γ-1)
    const T_final = initial.T * math.pow(f64, initial.V / V_final, gamma - 1);

    return GasState{
        .n = initial.n,
        .T = T_final,
        .P = P_final,
        .V = V_final,
    };
}

/// Изотермический процесс: PV = const
pub fn isothermal_process(initial: GasState, V_final: f64) struct {
    final_state: GasState,
    work: f64,
    heat: f64,
} {
    const P_final = initial.P * initial.V / V_final;
    const work = initial.n * R * initial.T * @log(V_final / initial.V);

    return .{
        .final_state = GasState{
            .n = initial.n,
            .T = initial.T,
            .P = P_final,
            .V = V_final,
        },
        .work = work,
        .heat = work, // Для изотермического процесса Q = W
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

pub fn analyze_thermodynamic_laws() [4]CreationPatternAnalysis {
    return [_]CreationPatternAnalysis{
        .{
            .law_name = "Нулевой закон (Равновесие)",
            .source_type = "Три системы (T_A, T_B, T_C)",
            .transformer = "thermal_contact",
            .result_type = "Равновесие (T_A = T_B = T_C)",
            .conservation_law = "Температура (транзитивность)",
            .reversible = true,
        },
        .{
            .law_name = "Первый закон (Энергия)",
            .source_type = "ThermodynamicState + Q, W",
            .transformer = "dU = Q - W",
            .result_type = "ThermodynamicState (новое U)",
            .conservation_law = "Энергия",
            .reversible = true,
        },
        .{
            .law_name = "Второй закон (Энтропия)",
            .source_type = "ThermodynamicState",
            .transformer = "irreversible_process",
            .result_type = "ThermodynamicState (S увеличено)",
            .conservation_law = "Энтропия (только возрастает)",
            .reversible = false, // КЛЮЧЕВОЕ ОТЛИЧИЕ!
        },
        .{
            .law_name = "Третий закон (Абсолютный ноль)",
            .source_type = "ThermodynamicState (T > 0)",
            .transformer = "cooling",
            .result_type = "ThermodynamicState (T → 0, S → 0)",
            .conservation_law = "Недостижимость T = 0",
            .reversible = false,
        },
    };
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "zeroth_law: transitive_equilibrium" {
    const result = check_equilibrium(300, 300, 300, 1);
    try std.testing.expect(result.A_eq_B);
    try std.testing.expect(result.A_eq_C);
    try std.testing.expect(result.B_eq_C);
    try std.testing.expect(result.transitive);
}

test "zeroth_law: not_equilibrium" {
    const result = check_equilibrium(300, 350, 300, 1);
    try std.testing.expect(!result.A_eq_B);
    try std.testing.expect(result.A_eq_C);
    try std.testing.expect(!result.B_eq_C);
}

test "first_law: adiabatic_compression" {
    // Q = 0, W = -100 (работа над системой)
    const dU = first_law(0, -100);
    try std.testing.expectApproxEqAbs(@as(f64, 100), dU, 0.001);
}

test "first_law: isothermal_expansion" {
    // Q = 500, W = 500 (работа системы)
    const dU = first_law(500, 500);
    try std.testing.expectApproxEqAbs(@as(f64, 0), dU, 0.001);
}

test "first_law: isochoric_heating" {
    // Q = 200, W = 0 (постоянный объём)
    const dU = first_law(200, 0);
    try std.testing.expectApproxEqAbs(@as(f64, 200), dU, 0.001);
}

test "second_law: heat_transfer_entropy" {
    const result = total_entropy_change(400, 300, 100);
    try std.testing.expectApproxEqAbs(@as(f64, -0.25), result.dS_hot, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.333), result.dS_cold, 0.001);
    try std.testing.expect(result.dS_total > 0); // Второй закон!
    try std.testing.expect(result.irreversible);
}

test "second_law: free_expansion" {
    // dS = nR * ln(V2/V1) = 1 * 8.314 * ln(2) ≈ 5.76 Дж/К
    const dS = free_expansion_entropy(1, 1, 2);
    try std.testing.expectApproxEqAbs(@as(f64, 5.76), dS, 0.1);
}

test "third_law: entropy_approaches_zero" {
    // При T < 1K используется модель Дебая: S ∝ T³
    const S_at_0_5K = low_temperature_entropy(0.5, 1, 1); // 0.5³ = 0.125
    const S_at_0_1K = low_temperature_entropy(0.1, 1, 1); // 0.1³ = 0.001
    // Энтропия уменьшается при понижении температуры
    try std.testing.expect(S_at_0_1K < S_at_0_5K);
    // И стремится к нулю
    try std.testing.expect(S_at_0_1K < 0.01);
}

test "ideal_gas: standard_conditions" {
    // 1 моль при 273.15 K и 22.4 л → P ≈ 101325 Па
    const P = ideal_gas_pressure(1, 273.15, 0.0224);
    try std.testing.expectApproxEqAbs(@as(f64, 101325), P, 500);
}

test "ideal_gas: double_temperature" {
    const P1 = ideal_gas_pressure(1, 273.15, 0.0224);
    const P2 = ideal_gas_pressure(1, 546.3, 0.0224);
    try std.testing.expectApproxEqAbs(P1 * 2, P2, 500);
}

test "carnot: efficiency" {
    const eta = carnot_efficiency(500, 300);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), eta, 0.001);
}

test "carnot: max_efficiency" {
    const eta = carnot_efficiency(1000, 300);
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), eta, 0.001);
}

test "gibbs: spontaneous_reaction" {
    // dH = -100, T = 300, dS = 0.1
    // dG = -100 - 300 * 0.1 = -130
    const result = gibbs_change(-100, 300, 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, -130), result.dG, 0.001);
    try std.testing.expect(result.spontaneous);
}

test "gibbs: non_spontaneous" {
    // dH = 100, T = 300, dS = 0.1
    // dG = 100 - 300 * 0.1 = 70
    const result = gibbs_change(100, 300, 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 70), result.dG, 0.001);
    try std.testing.expect(!result.spontaneous);
}

test "heat_transfer_simulation" {
    const initial = TwoBodyThermal{
        .T1 = 400,
        .T2 = 300,
        .C1 = 100,
        .C2 = 100,
    };
    const result = simulate_heat_transfer(initial, 10, 0.01);

    // Должны достичь равновесия при T = 350 K
    try std.testing.expectApproxEqAbs(@as(f64, 350), result.T_equilibrium, 1);
    try std.testing.expect(result.final_state.in_equilibrium());
    // Энтропия должна увеличиться (второй закон)
    try std.testing.expect(result.entropy_generated > 0);
}

test "creation_pattern: thermodynamic_laws_analysis" {
    const analysis = analyze_thermodynamic_laws();
    try std.testing.expect(analysis.len == 4);
    // Первые два закона обратимы
    try std.testing.expect(analysis[0].reversible);
    try std.testing.expect(analysis[1].reversible);
    // Второй и третий законы НЕОБРАТИМЫ - ключевое отличие от механики!
    try std.testing.expect(!analysis[2].reversible);
    try std.testing.expect(!analysis[3].reversible);
}

// ============================================================================
// MAIN: Демонстрация паттерна творения
// ============================================================================

pub fn main() !void {
    print("=" ** 60 ++ "\n", .{});
    print("ТЕРМОДИНАМИКА - ПАТТЕРН ТВОРЕНИЯ\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("Паттерн: Источник → Трансформер → Результат\n", .{});
    print("         State(T,P,V,S,U) → Laws → State'/Equilibrium\n\n", .{});

    // Анализ законов
    const analysis = analyze_thermodynamic_laws();
    print("Четыре закона термодинамики как трансформации:\n\n", .{});

    for (analysis) |law| {
        print("  {s}\n", .{law.law_name});
        print("    Источник: {s}\n", .{law.source_type});
        print("    Трансформер: {s}\n", .{law.transformer});
        print("    Результат: {s}\n", .{law.result_type});
        print("    Закон сохранения: {s}\n", .{law.conservation_law});
        print("    Обратимость: {}\n\n", .{law.reversible});
    }

    // Ключевое отличие от механики
    print("=" ** 60 ++ "\n", .{});
    print("КЛЮЧЕВОЕ ОТКРЫТИЕ:\n", .{});
    print("=" ** 60 ++ "\n\n", .{});

    print("В механике Ньютона ВСЕ трансформации ОБРАТИМЫ.\n", .{});
    print("В термодинамике Второй закон вводит НЕОБРАТИМОСТЬ.\n\n", .{});

    print("Это означает:\n", .{});
    print("  • Механика: время симметрично (t ↔ -t)\n", .{});
    print("  • Термодинамика: время имеет направление (стрела времени)\n\n", .{});

    // Демонстрация теплообмена
    print("Демонстрация теплообмена (400K ↔ 300K):\n", .{});
    const initial = TwoBodyThermal{ .T1 = 400, .T2 = 300, .C1 = 100, .C2 = 100 };
    const result = simulate_heat_transfer(initial, 10, 0.01);
    print("  Начальное: T1={d:.0}K, T2={d:.0}K\n", .{ initial.T1, initial.T2 });
    print("  Конечное: T={d:.1}K (равновесие)\n", .{result.T_equilibrium});
    print("  Шагов: {d}\n", .{result.steps});
    print("  Энтропия создана: {d:.4} Дж/К\n\n", .{result.entropy_generated});

    // КПД Карно
    print("Цикл Карно (T_hot=500K, T_cold=300K):\n", .{});
    const eta = carnot_efficiency(500, 300);
    print("  Максимальный КПД: {d:.0}%\n", .{eta * 100});
    print("  Это ТЕОРЕТИЧЕСКИЙ ПРЕДЕЛ - недостижим на практике!\n\n", .{});

    print("ВЫВОД: Термодинамика вводит СТРЕЛУ ВРЕМЕНИ через\n", .{});
    print("       необратимость Второго закона (dS ≥ 0).\n", .{});
}
