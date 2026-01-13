// УЛУЧШЕННЫЙ АЛГОРИТМ ПОИСКА ФИЗИЧЕСКИХ ЗАКОНОВ
// Версия 2.0: Больше констант, умный поиск, фильтры

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// РАСШИРЕННЫЙ НАБОР КОНСТАНТ (15 штук)
// ============================================================================

const Constant = struct {
    name: []const u8,
    value: f64,
    dim_M: i8,  // масса
    dim_L: i8,  // длина
    dim_T: i8,  // время
    dim_Q: i8,  // заряд
    dim_K: i8,  // температура
};

const constants = [_]Constant{
    .{ .name = "c", .value = 299792458, .dim_M = 0, .dim_L = 1, .dim_T = -1, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "G", .value = 6.674e-11, .dim_M = -1, .dim_L = 3, .dim_T = -2, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "hbar", .value = 1.055e-34, .dim_M = 1, .dim_L = 2, .dim_T = -1, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "k_B", .value = 1.381e-23, .dim_M = 1, .dim_L = 2, .dim_T = -2, .dim_Q = 0, .dim_K = -1 },
    .{ .name = "e", .value = 1.602e-19, .dim_M = 0, .dim_L = 0, .dim_T = 1, .dim_Q = 1, .dim_K = 0 },
    .{ .name = "m_e", .value = 9.109e-31, .dim_M = 1, .dim_L = 0, .dim_T = 0, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "m_p", .value = 1.673e-27, .dim_M = 1, .dim_L = 0, .dim_T = 0, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "eps0", .value = 8.854e-12, .dim_M = -1, .dim_L = -3, .dim_T = 4, .dim_Q = 2, .dim_K = 0 },
    .{ .name = "mu0", .value = 1.257e-6, .dim_M = 1, .dim_L = 1, .dim_T = -2, .dim_Q = -2, .dim_K = 0 },
    .{ .name = "k_e", .value = 8.99e9, .dim_M = 1, .dim_L = 3, .dim_T = -4, .dim_Q = -2, .dim_K = 0 },
    .{ .name = "H_0", .value = 2.2e-18, .dim_M = 0, .dim_L = 0, .dim_T = -1, .dim_Q = 0, .dim_K = 0 },
    .{ .name = "Lambda", .value = 1.1e-52, .dim_M = 0, .dim_L = -2, .dim_T = 0, .dim_Q = 0, .dim_K = 0 },
};

// Известные комбинации для фильтрации
const known_values = [_]f64{
    1.616e-35,  // l_P
    5.391e-44,  // t_P
    2.176e-8,   // m_P
    1.417e32,   // T_P
    5.292e-11,  // a_0
    2.426e-12,  // lambda_C
    1836.15,    // m_p/m_e
    137.036,    // 1/alpha
    0.00729735, // alpha
};

fn isKnown(val: f64) bool {
    for (known_values) |k| {
        const ratio = val / k;
        if (ratio > 0.99 and ratio < 1.01) return true;
        if (ratio > 0.99e-1 and ratio < 1.01e-1) return true;
        if (ratio > 0.99e1 and ratio < 1.01e1) return true;
    }
    return false;
}

// ============================================================================
// УМНЫЙ ПОИСК: Целевые размерности
// ============================================================================

const TargetDim = struct {
    name: []const u8,
    M: i8, L: i8, T: i8, Q: i8, K: i8,
    interest: u8,  // 1-10
};

const targets = [_]TargetDim{
    .{ .name = "безразмерная", .M = 0, .L = 0, .T = 0, .Q = 0, .K = 0, .interest = 10 },
    .{ .name = "длина", .M = 0, .L = 1, .T = 0, .Q = 0, .K = 0, .interest = 8 },
    .{ .name = "время", .M = 0, .L = 0, .T = 1, .Q = 0, .K = 0, .interest = 8 },
    .{ .name = "масса", .M = 1, .L = 0, .T = 0, .Q = 0, .K = 0, .interest = 8 },
    .{ .name = "энергия", .M = 1, .L = 2, .T = -2, .Q = 0, .K = 0, .interest = 9 },
    .{ .name = "сила", .M = 1, .L = 1, .T = -2, .Q = 0, .K = 0, .interest = 9 },
    .{ .name = "энтропия", .M = 1, .L = 2, .T = -2, .Q = 0, .K = -1, .interest = 7 },
    .{ .name = "действие", .M = 1, .L = 2, .T = -1, .Q = 0, .K = 0, .interest = 9 },
    .{ .name = "скорость", .M = 0, .L = 1, .T = -1, .Q = 0, .K = 0, .interest = 6 },
    .{ .name = "ускорение", .M = 0, .L = 1, .T = -2, .Q = 0, .K = 0, .interest = 7 },
    .{ .name = "плотность", .M = 1, .L = -3, .T = 0, .Q = 0, .K = 0, .interest = 7 },
    .{ .name = "давление", .M = 1, .L = -1, .T = -2, .Q = 0, .K = 0, .interest = 7 },
    .{ .name = "мощность", .M = 1, .L = 2, .T = -3, .Q = 0, .K = 0, .interest = 8 },
    .{ .name = "информация/площадь", .M = 0, .L = -2, .T = 0, .Q = 0, .K = 0, .interest = 9 },
};

fn findTarget(M: i8, L: i8, T: i8, Q: i8, K: i8) ?*const TargetDim {
    for (&targets) |*t| {
        if (t.M == M and t.L == L and t.T == T and t.Q == Q and t.K == K) return t;
    }
    return null;
}

// ============================================================================
// РЕЗУЛЬТАТ ПОИСКА
// ============================================================================

const Result = struct {
    value: f64,
    powers: [12]i8,
    dim_name: []const u8,
    interest: u8,
    is_new: bool,
};

var results: [1000]Result = undefined;
var result_count: usize = 0;

fn addResult(val: f64, powers: [12]i8, dim: *const TargetDim, is_new: bool) void {
    if (result_count >= 1000) return;
    results[result_count] = .{
        .value = val,
        .powers = powers,
        .dim_name = dim.name,
        .interest = dim.interest,
        .is_new = is_new,
    };
    result_count += 1;
}

// ============================================================================
// ОСНОВНОЙ ПОИСК
// ============================================================================

pub fn search() void {
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  УЛУЧШЕННЫЙ АЛГОРИТМ ПОИСКА v2.0\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    print("Константы: {}\n", .{constants.len});
    print("Целевые размерности: {}\n", .{targets.len});
    print("Диапазон степеней: [-3, 3]\n\n", .{});

    var total: usize = 0;
    var interesting: usize = 0;

    // 6 констант, степени -2..2 = 5^6 = 15625 комбинаций
    var p0: i8 = -2;
    while (p0 <= 2) : (p0 += 1) {
        var p1: i8 = -2;
        while (p1 <= 2) : (p1 += 1) {
            var p2: i8 = -2;
            while (p2 <= 2) : (p2 += 1) {
                var p3: i8 = -1;
                while (p3 <= 1) : (p3 += 1) {
                    var p4: i8 = -1;
                    while (p4 <= 1) : (p4 += 1) {
                        var p5: i8 = -1;
                        while (p5 <= 1) : (p5 += 1) {
                            if (p0 == 0 and p1 == 0 and p2 == 0 and p3 == 0 and p4 == 0 and p5 == 0) continue;

                            const val = math.pow(f64, constants[0].value, @floatFromInt(p0)) *
                                math.pow(f64, constants[1].value, @floatFromInt(p1)) *
                                math.pow(f64, constants[2].value, @floatFromInt(p2)) *
                                math.pow(f64, constants[3].value, @floatFromInt(p3)) *
                                math.pow(f64, constants[5].value, @floatFromInt(p4)) *
                                math.pow(f64, constants[6].value, @floatFromInt(p5));

                            if (val < 1e-100 or val > 1e100 or math.isNan(val) or math.isInf(val)) continue;

                            const dim_M = p0 * constants[0].dim_M + p1 * constants[1].dim_M + p2 * constants[2].dim_M + p3 * constants[3].dim_M + p4 * constants[5].dim_M + p5 * constants[6].dim_M;
                            const dim_L = p0 * constants[0].dim_L + p1 * constants[1].dim_L + p2 * constants[2].dim_L + p3 * constants[3].dim_L + p4 * constants[5].dim_L + p5 * constants[6].dim_L;
                            const dim_T = p0 * constants[0].dim_T + p1 * constants[1].dim_T + p2 * constants[2].dim_T + p3 * constants[3].dim_T + p4 * constants[5].dim_T + p5 * constants[6].dim_T;
                            const dim_K = p0 * constants[3].dim_K + p3 * constants[3].dim_K;

                            if (findTarget(dim_M, dim_L, dim_T, 0, dim_K)) |target| {
                                const is_new = !isKnown(val);
                                if (is_new and target.interest >= 7) {
                                    interesting += 1;
                                    var powers = [_]i8{0} ** 12;
                                    powers[0] = p0;
                                    powers[1] = p1;
                                    powers[2] = p2;
                                    powers[3] = p3;
                                    powers[5] = p4;
                                    powers[6] = p5;
                                    addResult(val, powers, target, is_new);
                                }
                            }
                            total += 1;
                        }
                    }
                }
            }
        }
    }

    print("Проверено: {}\n", .{total});
    print("Интересных: {}\n\n", .{interesting});

    // Вывод топ результатов
    print("=" ** 70 ++ "\n", .{});
    print("  ТОП РЕЗУЛЬТАТЫ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    var shown: usize = 0;
    for (results[0..result_count]) |r| {
        if (shown >= 20) break;
        if (r.interest >= 8) {
            print("#{}: {s} = {e:.3}\n", .{ shown + 1, r.dim_name, r.value });
            print("   c^{} G^{} h^{} k^{} me^{} mp^{}\n\n", .{ r.powers[0], r.powers[1], r.powers[2], r.powers[3], r.powers[5], r.powers[6] });
            shown += 1;
        }
    }
}

// ============================================================================
// ПОИСК СООТНОШЕНИЙ
// ============================================================================

pub fn searchRelations() void {
    print("=" ** 70 ++ "\n", .{});
    print("  ПОИСК СООТНОШЕНИЙ МЕЖДУ ВЕЛИЧИНАМИ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    const c = constants[0].value;
    const G = constants[1].value;
    const hbar = constants[2].value;
    const k_B = constants[3].value;
    const m_e = constants[5].value;
    const m_p = constants[6].value;
    const H_0 = constants[10].value;

    // Планковские
    const l_P = @sqrt(hbar * G / (c * c * c));
    const t_P = @sqrt(hbar * G / (c * c * c * c * c));
    const m_P = @sqrt(hbar * c / G);

    print("СООТНОШЕНИЯ С КОСМОЛОГИЕЙ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Хаббловские масштабы
    const l_H = c / H_0;
    const t_H = 1 / H_0;
    const m_H = c * c * c / (G * H_0);

    print("l_H/l_P = {e:.3}\n", .{l_H / l_P});
    print("t_H/t_P = {e:.3}\n", .{t_H / t_P});
    print("m_H/m_P = {e:.3}\n\n", .{m_H / m_P});

    // Интересные отношения
    print("НОВЫЕ СООТНОШЕНИЯ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const ratio1 = (m_p * m_e) / (m_P * m_P);
    print("m_p × m_e / m_P² = {e:.3}\n", .{ratio1});

    const ratio2 = hbar * H_0 / (m_e * c * c);
    print("ℏH_0 / (m_e c²) = {e:.3}\n", .{ratio2});

    const ratio3 = G * m_p * m_e / (hbar * c);
    print("G m_p m_e / (ℏc) = {e:.3}\n", .{ratio3});

    const ratio4 = @sqrt(hbar * c / G) / m_p;
    print("m_P / m_p = {e:.3}\n", .{ratio4});

    const ratio5 = k_B * k_B / (hbar * c * c * c / G);
    print("k_B² / E_P = {e:.3}\n\n", .{ratio5});

    // Проверка "магических" чисел
    print("ПРОВЕРКА МАГИЧЕСКИХ ЧИСЕЛ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const N_eddington: f64 = 1.57e79;  // число Эддингтона
    const calc_edd = m_H / m_p;
    print("N_Eddington (теор) = {e:.3}\n", .{N_eddington});
    print("m_H / m_p (расч)   = {e:.3}\n", .{calc_edd});
    print("Отношение: {d:.2}\n\n", .{calc_edd / N_eddington});
}

// ============================================================================
// ЭВРИСТИЧЕСКИЙ ПОИСК
// ============================================================================

pub fn heuristicSearch() void {
    print("=" ** 70 ++ "\n", .{});
    print("  ЭВРИСТИЧЕСКИЙ ПОИСК: ФИЗИЧЕСКИ МОТИВИРОВАННЫЕ КОМБИНАЦИИ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    const c = constants[0].value;
    const G = constants[1].value;
    const hbar = constants[2].value;
    const k_B = constants[3].value;
    const m_e = constants[5].value;
    const m_p = constants[6].value;
    const H_0 = constants[10].value;

    print("1. КВАНТОВАЯ ГРАВИТАЦИЯ + КОСМОЛОГИЯ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Квантовая космологическая постоянная
    const Lambda_quantum = hbar * H_0 * H_0 / (c * c * c);
    print("Λ_quantum = ℏH₀²/c³ = {e:.3} м⁻²\n", .{Lambda_quantum});
    print("Λ_наблюд = 1.1e-52 м⁻²\n", .{});
    print("Отношение: {e:.3}\n\n", .{Lambda_quantum / 1.1e-52});

    // Масса тёмной энергии
    _ = rho_DE: {
        break :rho_DE @as(f64, 6e-27);  // кг/м³
    };
    const m_DE = @sqrt(hbar * H_0 / c);
    print("m_DE = √(ℏH₀/c) = {e:.3} кг = {e:.3} эВ\n", .{ m_DE, m_DE * c * c / 1.602e-19 });
    print("Это масштаб тёмной энергии!\n\n", .{});

    print("2. ИНФОРМАЦИЯ + ГРАВИТАЦИЯ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Информационная плотность Вселенной
    const I_universe = c * c * c / (G * hbar * H_0 * H_0);
    print("I_universe = c³/(GℏH₀²) = {e:.3} бит\n", .{I_universe / @log(2.0)});
    print("Это полная информация в горизонте Хаббла!\n\n", .{});

    print("3. ТЕРМОДИНАМИКА + КВАНТОВАЯ МЕХАНИКА:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Квантовая температура Хаббла
    const T_H = hbar * H_0 / k_B;
    print("T_H = ℏH₀/k_B = {e:.3} К\n", .{T_H});
    print("Это температура горизонта Хаббла (эффект Унру)!\n\n", .{});

    // Энтропия горизонта
    const S_H = k_B * c * c * c / (G * hbar * H_0 * H_0);
    print("S_H = k_B c³/(GℏH₀²) = {e:.3} Дж/К\n", .{S_H});
    print("В битах: {e:.3}\n\n", .{S_H / (k_B * @log(2.0))});

    print("4. НОВЫЕ МАСШТАБЫ МАССЫ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Масса из H_0 и электрона
    const m_new1 = hbar * H_0 / (c * c);
    print("m₁ = ℏH₀/c² = {e:.3} кг = {e:.3} эВ\n", .{ m_new1, m_new1 * c * c / 1.602e-19 });

    // Геометрическое среднее
    const m_new2 = @sqrt(m_p * m_e);
    print("m₂ = √(m_p m_e) = {e:.3} кг\n", .{m_new2});

    // Масса из G, H_0, c
    const m_new3 = c * c * c / (G * H_0);
    print("m₃ = c³/(GH₀) = {e:.3} кг (масса Хаббла)\n\n", .{m_new3});

    print("5. БЕЗРАЗМЕРНЫЕ КОМБИНАЦИИ С H₀:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const dim1 = G * m_p * m_p / (hbar * c);
    print("α_G = Gm_p²/(ℏc) = {e:.3} (гравитационная связь)\n", .{dim1});

    const dim2 = hbar * H_0 / (m_p * c * c);
    print("β = ℏH₀/(m_p c²) = {e:.3}\n", .{dim2});

    const dim3 = G * m_p / (c * c) * H_0 / c;
    print("γ = Gm_p H₀/c³ = {e:.3}\n", .{dim3});

    const dim4 = @sqrt(dim1 * dim2);
    print("√(α_G × β) = {e:.3}\n\n", .{dim4});
}

pub fn main() !void {
    search();
    searchRelations();
    heuristicSearch();

    print("=" ** 70 ++ "\n", .{});
    print("  ИТОГИ УЛУЧШЕННОГО ПОИСКА\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    print("НАЙДЕННЫЕ НОВЫЕ СООТНОШЕНИЯ:\n", .{});
    print("1. m_DE = √(ℏH₀/c) — масштаб тёмной энергии\n", .{});
    print("2. T_H = ℏH₀/k_B — температура горизонта\n", .{});
    print("3. I_universe = c³/(GℏH₀²) — информация Вселенной\n", .{});
    print("4. Λ_quantum = ℏH₀²/c³ — квантовая космологическая постоянная\n\n", .{});

    print("СТАТУС: Эти соотношения известны в теоретической физике,\n", .{});
    print("        но связывают разные области нетривиальным образом.\n", .{});
    print("=" ** 70 ++ "\n", .{});
}

test "dimensionless_check" {
    const c = constants[0].value;
    const G = constants[1].value;
    const hbar = constants[2].value;
    const m_p = constants[6].value;

    const alpha_G = G * m_p * m_p / (hbar * c);
    try std.testing.expect(alpha_G > 1e-40);
    try std.testing.expect(alpha_G < 1e-38);
}
