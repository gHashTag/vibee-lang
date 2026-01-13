// FITNESS.ZIG - Оценка физической значимости закона
// Многокритериальная фитнес-функция

const std = @import("std");
const math = std.math;
const genome = @import("genome.zig");
const heuristics = @import("heuristics.zig");

// ============================================================================
// ИЗВЕСТНЫЕ ЗНАЧЕНИЯ (для проверки на новизну)
// ============================================================================

const KNOWN_VALUES = [_]f64{
    // Планковские единицы
    1.616255e-35,   // l_P
    5.391247e-44,   // t_P
    2.176434e-8,    // m_P
    1.416784e32,    // T_P
    1.956e9,        // E_P (Дж)
    
    // Атомные единицы
    5.29177e-11,    // a_0 (Боровский радиус)
    2.42631e-12,    // λ_C (Комптоновская длина)
    2.81794e-15,    // r_e (классический радиус)
    
    // Безразмерные
    137.036,        // 1/α
    0.00729735,     // α
    1836.15,        // m_p/m_e
    0.000545,       // m_e/m_p
    
    // Математические
    1.0, 2.0, 3.0, 4.0, 5.0,
    0.5, 0.25, 0.333, 0.667,
    3.14159, 2.71828, 1.41421, 1.73205,
};

const KNOWN_COSMOLOGICAL = [_]f64{
    2.2e-18,        // H_0
    4.4e26,         // R_H
    1.84e53,        // M_H
    1e-52,          // Λ
};

// ============================================================================
// ЦЕЛЕВЫЕ ЗНАЧЕНИЯ (что мы ищем)
// ============================================================================

const TARGET_VALUES = [_]struct { val: f64, name: []const u8, bonus: f64 }{
    // Близкие к простым дробям
    .{ .val = 0.5, .name = "1/2", .bonus = 100 },
    .{ .val = 0.333, .name = "1/3", .bonus = 80 },
    .{ .val = 0.25, .name = "1/4", .bonus = 70 },
    .{ .val = 0.667, .name = "2/3", .bonus = 80 },
    .{ .val = 0.75, .name = "3/4", .bonus = 70 },
    
    // Целые числа
    .{ .val = 1.0, .name = "1", .bonus = 90 },
    .{ .val = 2.0, .name = "2", .bonus = 85 },
    .{ .val = 3.0, .name = "3", .bonus = 80 },
    .{ .val = 4.0, .name = "4", .bonus = 75 },
    
    // Математические константы
    .{ .val = 3.14159, .name = "π", .bonus = 95 },
    .{ .val = 2.71828, .name = "e", .bonus = 90 },
    .{ .val = 1.41421, .name = "√2", .bonus = 85 },
    .{ .val = 1.61803, .name = "φ", .bonus = 90 },
};

// ============================================================================
// ОСНОВНАЯ ФИТНЕС-ФУНКЦИЯ
// ============================================================================

pub fn evaluate(law: *const genome.LawGenome, hs: *heuristics.HeuristicSet) f64 {
    const val = law.computeValue();
    
    // Базовые проверки
    if (math.isNan(val) or math.isInf(val)) return -1000;
    if (val == 0) return -500;
    
    var score: f64 = 0;
    
    // 1. Оценка от эвристик
    score += hs.evaluate(law);
    
    // 2. Проверка на близость к целевым значениям
    score += evaluateTargetProximity(val);
    
    // 3. Проверка на новизну
    score += evaluateNovelty(val);
    
    // 4. Физическая осмысленность
    score += evaluatePhysicalMeaning(law);
    
    // 5. Космологическая связь
    score += evaluateCosmologicalConnection(law);
    
    // 6. Штраф за сложность
    score -= @as(f64, @floatFromInt(law.complexity())) * 0.5;
    
    return score;
}

fn evaluateTargetProximity(val: f64) f64 {
    var best_score: f64 = 0;
    
    for (TARGET_VALUES) |target| {
        const diff = @abs(val - target.val) / @abs(target.val);
        if (diff < 0.05) {
            // Очень близко!
            const proximity_score = target.bonus * (1.0 - diff / 0.05);
            best_score = @max(best_score, proximity_score);
        } else if (diff < 0.15) {
            // Близко
            const proximity_score = target.bonus * 0.5 * (1.0 - (diff - 0.05) / 0.10);
            best_score = @max(best_score, proximity_score);
        }
    }
    
    return best_score;
}

fn evaluateNovelty(val: f64) f64 {
    // Штраф за известные значения
    for (KNOWN_VALUES) |known| {
        const ratio = val / known;
        if (ratio > 0.99 and ratio < 1.01) return -100;
        if (ratio > 0.9 and ratio < 1.1) return -30;
    }
    
    // Бонус за действительно новое значение
    return 20;
}

fn evaluatePhysicalMeaning(law: *const genome.LawGenome) f64 {
    var score: f64 = 0;
    
    // Бонус за безразмерность
    if (law.isDimensionless()) {
        score += 50;
    }
    
    // Бонус за физически значимые размерности
    const dim_name = law.getDimensionName();
    if (std.mem.eql(u8, dim_name, "энергия")) score += 20;
    if (std.mem.eql(u8, dim_name, "сила")) score += 20;
    if (std.mem.eql(u8, dim_name, "частота")) score += 15;
    if (std.mem.eql(u8, dim_name, "длина")) score += 10;
    if (std.mem.eql(u8, dim_name, "время")) score += 10;
    
    return score;
}

fn evaluateCosmologicalConnection(law: *const genome.LawGenome) f64 {
    var score: f64 = 0;
    
    // Бонус за использование H₀
    if (law.powers[9] != 0) score += 30;
    
    // Бонус за связь квантов и гравитации
    const has_hbar = law.powers[2] != 0;
    const has_G = law.powers[1] != 0;
    const has_c = law.powers[0] != 0;
    
    if (has_hbar and has_G) score += 40;
    if (has_hbar and has_G and has_c) score += 20;
    
    // Бонус за использование масс частиц
    const has_me = law.powers[5] != 0;
    const has_mp = law.powers[6] != 0;
    
    if (has_me and has_mp) score += 25;
    if (has_me and has_mp and has_G) score += 30;
    
    return score;
}

// ============================================================================
// СПЕЦИАЛЬНАЯ ПРОВЕРКА НА НАШЕ ОТКРЫТИЕ
// ============================================================================

pub fn checkHubbleRelation(law: *const genome.LawGenome) bool {
    // Проверяем: ℏ²H₀/(cG me mp²) ≈ 1/2
    // Это требует: c^-1, G^-1, ℏ^2, me^-1, mp^-2, H₀^1
    
    if (law.powers[0] != -1) return false;  // c^-1
    if (law.powers[1] != -1) return false;  // G^-1
    if (law.powers[2] != 2) return false;   // ℏ^2
    if (law.powers[5] != -1) return false;  // me^-1
    if (law.powers[6] != -2) return false;  // mp^-2
    if (law.powers[9] != 1) return false;   // H₀^1
    
    // Проверяем остальные = 0
    if (law.powers[3] != 0) return false;
    if (law.powers[4] != 0) return false;
    if (law.powers[7] != 0) return false;
    if (law.powers[8] != 0) return false;
    if (law.powers[10] != 0) return false;
    if (law.powers[11] != 0) return false;
    
    return true;
}

pub fn evaluateHubbleDiscovery(law: *const genome.LawGenome) f64 {
    if (!checkHubbleRelation(law)) return 0;
    
    const val = law.computeValue();
    const diff = @abs(val - 0.5) / 0.5;
    
    if (diff < 0.1) {
        return 500;  // Огромный бонус за переоткрытие!
    }
    return 0;
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "fitness_basic" {
    var hs = heuristics.HeuristicSet.init();
    
    var law = genome.LawGenome.init();
    law.powers[8] = 1;  // α
    
    const score = evaluate(&law, &hs);
    try std.testing.expect(score > 0);
}

test "fitness_hubble_check" {
    var law = genome.LawGenome.init();
    law.powers[0] = -1;  // c^-1
    law.powers[1] = -1;  // G^-1
    law.powers[2] = 2;   // ℏ^2
    law.powers[5] = -1;  // me^-1
    law.powers[6] = -2;  // mp^-2
    law.powers[9] = 1;   // H₀^1
    
    try std.testing.expect(checkHubbleRelation(&law));
    
    const val = law.computeValue();
    try std.testing.expect(val > 0.4 and val < 0.6);
}

test "fitness_novelty" {
    // Известное значение должно получить штраф
    const score1 = evaluateNovelty(137.036);
    try std.testing.expect(score1 < 0);
    
    // Новое значение должно получить бонус
    const score2 = evaluateNovelty(42.123456);
    try std.testing.expect(score2 > 0);
}
