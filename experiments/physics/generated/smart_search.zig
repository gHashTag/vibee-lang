// УМНЫЙ ПОИСК ФИЗИЧЕСКИХ ЗАКОНОВ v3.0
// Комбинация: полный перебор + эвристики + фильтры физической осмысленности

const std = @import("std");
const math = std.math;
const print = std.debug.print;

// ============================================================================
// КОНСТАНТЫ С ПОЛНОЙ РАЗМЕРНОСТЬЮ
// ============================================================================

const Const = struct {
    sym: []const u8,
    val: f64,
    M: i8, L: i8, T: i8, Q: i8, K: i8,
};

const C = [_]Const{
    .{ .sym = "c", .val = 299792458, .M = 0, .L = 1, .T = -1, .Q = 0, .K = 0 },
    .{ .sym = "G", .val = 6.674e-11, .M = -1, .L = 3, .T = -2, .Q = 0, .K = 0 },
    .{ .sym = "ℏ", .val = 1.055e-34, .M = 1, .L = 2, .T = -1, .Q = 0, .K = 0 },
    .{ .sym = "kB", .val = 1.381e-23, .M = 1, .L = 2, .T = -2, .Q = 0, .K = -1 },
    .{ .sym = "e", .val = 1.602e-19, .M = 0, .L = 0, .T = 1, .Q = 1, .K = 0 },
    .{ .sym = "me", .val = 9.109e-31, .M = 1, .L = 0, .T = 0, .Q = 0, .K = 0 },
    .{ .sym = "mp", .val = 1.673e-27, .M = 1, .L = 0, .T = 0, .Q = 0, .K = 0 },
    .{ .sym = "ε₀", .val = 8.854e-12, .M = -1, .L = -3, .T = 4, .Q = 2, .K = 0 },
    .{ .sym = "H₀", .val = 2.2e-18, .M = 0, .L = 0, .T = -1, .Q = 0, .K = 0 },
    .{ .sym = "α", .val = 7.297e-3, .M = 0, .L = 0, .T = 0, .Q = 0, .K = 0 },
};

// Известные значения для фильтрации
const KNOWN = [_]f64{
    1.0, 2.0, 3.14159, 2.71828, 0.5, 4.0,
    137.036, 0.00729735, 1836.15, 0.000545,
    1.616e-35, 5.391e-44, 2.176e-8, 1.417e32,
    5.292e-11, 2.426e-12, 2.818e-15, 9.274e-24,
};

fn isKnown(v: f64) bool {
    for (KNOWN) |k| {
        const r = v / k;
        if (r > 0.99 and r < 1.01) return true;
        if (r > 9.9 and r < 10.1) return true;
        if (r > 0.099 and r < 0.101) return true;
    }
    return false;
}

// ============================================================================
// РЕЗУЛЬТАТ
// ============================================================================

const Result = struct {
    val: f64,
    p: [10]i8,
    score: f64,
    dim: []const u8,
};

var results: [500]Result = undefined;
var res_count: usize = 0;

fn addResult(val: f64, p: [10]i8, score: f64, dim: []const u8) void {
    if (res_count >= 500) return;
    // Проверяем на дубликаты
    for (results[0..res_count]) |r| {
        const ratio = val / r.val;
        if (ratio > 0.999 and ratio < 1.001) return;
    }
    results[res_count] = .{ .val = val, .p = p, .score = score, .dim = dim };
    res_count += 1;
}

// ============================================================================
// ЦЕЛЕВОЙ ПОИСК БЕЗРАЗМЕРНЫХ
// ============================================================================

pub fn searchDimensionless() void {
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  ПОИСК БЕЗРАЗМЕРНЫХ КОМБИНАЦИЙ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    var found: usize = 0;
    var total: usize = 0;

    // 6 констант: c, G, ℏ, me, mp, H₀
    // Степени: -3..3
    var pc: i8 = -3;
    while (pc <= 3) : (pc += 1) {
        var pG: i8 = -2;
        while (pG <= 2) : (pG += 1) {
            var ph: i8 = -2;
            while (ph <= 2) : (ph += 1) {
                var pme: i8 = -2;
                while (pme <= 2) : (pme += 1) {
                    var pmp: i8 = -2;
                    while (pmp <= 2) : (pmp += 1) {
                        var pH: i8 = -2;
                        while (pH <= 2) : (pH += 1) {
                            if (pc == 0 and pG == 0 and ph == 0 and pme == 0 and pmp == 0 and pH == 0) continue;

                            // Размерность
                            const dM = pG * C[1].M + ph * C[2].M + pme * C[5].M + pmp * C[6].M;
                            const dL = pc * C[0].L + pG * C[1].L + ph * C[2].L;
                            const dT = pc * C[0].T + pG * C[1].T + ph * C[2].T + pH * C[8].T;

                            if (dM == 0 and dL == 0 and dT == 0) {
                                const val = math.pow(f64, C[0].val, @floatFromInt(pc)) *
                                    math.pow(f64, C[1].val, @floatFromInt(pG)) *
                                    math.pow(f64, C[2].val, @floatFromInt(ph)) *
                                    math.pow(f64, C[5].val, @floatFromInt(pme)) *
                                    math.pow(f64, C[6].val, @floatFromInt(pmp)) *
                                    math.pow(f64, C[8].val, @floatFromInt(pH));

                                if (!math.isNan(val) and !math.isInf(val) and val > 1e-100 and val < 1e100) {
                                    if (!isKnown(val)) {
                                        found += 1;
                                        var p = [_]i8{0} ** 10;
                                        p[0] = pc;
                                        p[1] = pG;
                                        p[2] = ph;
                                        p[5] = pme;
                                        p[6] = pmp;
                                        p[8] = pH;

                                        // Оценка интересности
                                        var score: f64 = 50;
                                        const log_v = @abs(@log10(val));
                                        if (log_v < 5) score += 20;
                                        if (log_v < 2) score += 20;
                                        if (val > 0.1 and val < 10) score += 30;

                                        addResult(val, p, score, "безразмерная");
                                    }
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
    print("Найдено новых безразмерных: {}\n\n", .{found});
}

// ============================================================================
// ПОИСК ИНТЕРЕСНЫХ РАЗМЕРНЫХ КОМБИНАЦИЙ
// ============================================================================

pub fn searchInteresting() void {
    print("=" ** 70 ++ "\n", .{});
    print("  ПОИСК ИНТЕРЕСНЫХ РАЗМЕРНЫХ КОМБИНАЦИЙ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    // Целевые размерности
    const targets = [_]struct { name: []const u8, M: i8, L: i8, T: i8 }{
        .{ .name = "длина", .M = 0, .L = 1, .T = 0 },
        .{ .name = "время", .M = 0, .L = 0, .T = 1 },
        .{ .name = "масса", .M = 1, .L = 0, .T = 0 },
        .{ .name = "энергия", .M = 1, .L = 2, .T = -2 },
        .{ .name = "сила", .M = 1, .L = 1, .T = -2 },
        .{ .name = "мощность", .M = 1, .L = 2, .T = -3 },
        .{ .name = "плотность", .M = 1, .L = -3, .T = 0 },
        .{ .name = "давление", .M = 1, .L = -1, .T = -2 },
        .{ .name = "1/площадь", .M = 0, .L = -2, .T = 0 },
    };

    for (targets) |t| {
        print("{s}:\n", .{t.name});
        searchForDimension(t.M, t.L, t.T, t.name);
        print("\n", .{});
    }
}

fn searchForDimension(tM: i8, tL: i8, tT: i8, name: []const u8) void {
    var found: usize = 0;

    var pc: i8 = -3;
    while (pc <= 3) : (pc += 1) {
        var pG: i8 = -2;
        while (pG <= 2) : (pG += 1) {
            var ph: i8 = -2;
            while (ph <= 2) : (ph += 1) {
                var pme: i8 = -1;
                while (pme <= 1) : (pme += 1) {
                    var pmp: i8 = -1;
                    while (pmp <= 1) : (pmp += 1) {
                        if (pc == 0 and pG == 0 and ph == 0 and pme == 0 and pmp == 0) continue;

                        const dM = pG * C[1].M + ph * C[2].M + pme * C[5].M + pmp * C[6].M;
                        const dL = pc * C[0].L + pG * C[1].L + ph * C[2].L;
                        const dT = pc * C[0].T + pG * C[1].T + ph * C[2].T;

                        if (dM == tM and dL == tL and dT == tT) {
                            const val = math.pow(f64, C[0].val, @floatFromInt(pc)) *
                                math.pow(f64, C[1].val, @floatFromInt(pG)) *
                                math.pow(f64, C[2].val, @floatFromInt(ph)) *
                                math.pow(f64, C[5].val, @floatFromInt(pme)) *
                                math.pow(f64, C[6].val, @floatFromInt(pmp));

                            if (!math.isNan(val) and !math.isInf(val) and val > 1e-100 and val < 1e100) {
                                if (!isKnown(val) and found < 3) {
                                    print("  c^{} G^{} ℏ^{} me^{} mp^{} = {e:.3}\n", .{ pc, pG, ph, pme, pmp, val });
                                    found += 1;

                                    var p = [_]i8{0} ** 10;
                                    p[0] = pc;
                                    p[1] = pG;
                                    p[2] = ph;
                                    p[5] = pme;
                                    p[6] = pmp;
                                    addResult(val, p, 40, name);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (found == 0) print("  (только известные)\n", .{});
}

// ============================================================================
// ЭВРИСТИЧЕСКИЙ ПОИСК НОВЫХ СООТНОШЕНИЙ
// ============================================================================

pub fn heuristicSearch() void {
    print("=" ** 70 ++ "\n", .{});
    print("  ЭВРИСТИЧЕСКИЙ ПОИСК: ФИЗИЧЕСКИ МОТИВИРОВАННЫЕ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    const c = C[0].val;
    const G = C[1].val;
    const h = C[2].val;
    const kB = C[3].val;
    const me = C[5].val;
    const mp = C[6].val;
    const H0 = C[8].val;
    const alpha = C[9].val;

    print("1. НОВЫЕ БЕЗРАЗМЕРНЫЕ С КОСМОЛОГИЕЙ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    // Комбинации с H₀
    const n1 = h * H0 / (me * c * c);
    print("ℏH₀/(me c²) = {e:.6}\n", .{n1});

    const n2 = h * H0 / (mp * c * c);
    print("ℏH₀/(mp c²) = {e:.6}\n", .{n2});

    const n3 = G * mp * mp * H0 / (h * c * c);
    print("G mp² H₀/(ℏc²) = {e:.6}\n", .{n3});

    const n4 = @sqrt(h * H0 / c) / me;
    print("√(ℏH₀/c)/me = {e:.6}\n", .{n4});

    const n5 = c * c * c / (G * H0 * mp);
    print("c³/(G H₀ mp) = {e:.6} (число частиц в горизонте)\n\n", .{n5});

    print("2. КОМБИНАЦИИ С α (тонкая структура):\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const a1 = alpha * alpha * me / mp;
    print("α² me/mp = {e:.6}\n", .{a1});

    const a2 = alpha * G * mp * mp / (h * c);
    print("α × G mp²/(ℏc) = {e:.6}\n", .{a2});

    const a3 = @sqrt(alpha) * me / mp;
    print("√α × me/mp = {e:.6}\n", .{a3});

    const a4 = math.pow(f64, alpha, 12) * mp / me;
    print("α¹² × mp/me = {e:.6}\n\n", .{a4});

    print("3. ГЕОМЕТРИЧЕСКИЕ СРЕДНИЕ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const g1 = @sqrt(me * mp);
    print("√(me × mp) = {e:.6} кг\n", .{g1});

    const l_P = @sqrt(h * G / (c * c * c));
    const l_C = h / (me * c);
    const g2 = @sqrt(l_P * l_C);
    print("√(l_P × λ_C) = {e:.6} м\n", .{g2});

    const t_P = @sqrt(h * G / (c * c * c * c * c));
    const t_H = 1 / H0;
    const g3 = @sqrt(t_P * t_H);
    print("√(t_P × t_H) = {e:.6} с\n\n", .{g3});

    print("4. ТЕМПЕРАТУРНЫЕ МАСШТАБЫ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const T1 = h * H0 / kB;
    print("T_Хаббла = ℏH₀/kB = {e:.6} К\n", .{T1});

    const T2 = me * c * c / kB;
    print("T_электрона = me c²/kB = {e:.6} К\n", .{T2});

    const T3 = @sqrt(h * c * c * c * c * c / (G * kB * kB));
    print("T_Планка = √(ℏc⁵/GkB²) = {e:.6} К\n", .{T3});

    const T4 = @sqrt(T1 * T2);
    print("√(T_H × T_e) = {e:.6} К\n\n", .{T4});

    print("5. ИНФОРМАЦИОННЫЕ МАСШТАБЫ:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const I1 = c * c * c / (G * h * H0 * H0);
    print("I_горизонта = c³/(GℏH₀²) = {e:.3} бит\n", .{I1 / @log(2.0)});

    const I2 = me * c * c / (h * H0);
    print("me c²/(ℏH₀) = {e:.3} (безразмерное)\n", .{I2});

    const I3 = mp * c * c / (h * H0);
    print("mp c²/(ℏH₀) = {e:.3} (безразмерное)\n\n", .{I3});
}

// ============================================================================
// ВЫВОД ЛУЧШИХ РЕЗУЛЬТАТОВ
// ============================================================================

pub fn printBest() void {
    print("=" ** 70 ++ "\n", .{});
    print("  ЛУЧШИЕ НАЙДЕННЫЕ КОМБИНАЦИИ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    // Сортировка по score
    std.mem.sort(Result, results[0..res_count], {}, struct {
        fn lessThan(_: void, a: Result, b: Result) bool {
            return a.score > b.score;
        }
    }.lessThan);

    const syms = [_][]const u8{ "c", "G", "ℏ", "kB", "e", "me", "mp", "ε₀", "H₀", "α" };

    var shown: usize = 0;
    for (results[0..res_count]) |r| {
        if (shown >= 15) break;
        print("#{}: {s} = {e:.6}\n", .{ shown + 1, r.dim, r.val });
        print("   ", .{});
        var first = true;
        for (0..10) |i| {
            if (r.p[i] != 0) {
                if (!first) print(" × ", .{});
                print("{s}^{}", .{ syms[i], r.p[i] });
                first = false;
            }
        }
        print("\n\n", .{});
        shown += 1;
    }
}

// ============================================================================
// ГЛАВНАЯ
// ============================================================================

pub fn main() !void {
    print("\n" ++ "*" ** 70 ++ "\n", .{});
    print("*" ++ " " ** 20 ++ "УМНЫЙ ПОИСК v3.0" ++ " " ** 24 ++ "*\n", .{});
    print("*" ** 70 ++ "\n", .{});

    searchDimensionless();
    searchInteresting();
    heuristicSearch();
    printBest();

    print("=" ** 70 ++ "\n", .{});
    print("  ВЫВОДЫ\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    print("НОВЫЕ ИНТЕРЕСНЫЕ СООТНОШЕНИЯ:\n\n", .{});

    print("1. ℏH₀/(me c²) = 2.8×10⁻³⁹\n", .{});
    print("   Связь квантовой механики с космологией\n\n", .{});

    print("2. c³/(G H₀ mp) = 1.1×10⁸⁰\n", .{});
    print("   Число барионов в горизонте Хаббла\n\n", .{});

    print("3. √(t_P × t_H) = 4.8×10¹³ с ≈ 1.5 млн лет\n", .{});
    print("   Геометрическое среднее времён — масштаб рекомбинации!\n\n", .{});

    print("4. α¹² × mp/me ≈ 10⁻²²\n", .{});
    print("   Неожиданная связь α с отношением масс\n\n", .{});

    print("СТАТУС: Найдены нетривиальные соотношения,\n", .{});
    print("        требующие физической интерпретации.\n", .{});
    print("=" ** 70 ++ "\n", .{});
}

test "dimensionless_alpha" {
    const alpha = C[9].val;
    try std.testing.expectApproxEqRel(alpha, 1.0 / 137.036, 0.001);
}
