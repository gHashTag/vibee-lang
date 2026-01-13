// FITNESS_V2.ZIG - Улучшенная фитнес-функция
// Многокритериальная оценка с физической мотивацией

const std = @import("std");
const math = std.math;
const genome = @import("genome.zig");
const constants = @import("constants_extended.zig");

// ============================================================================
// КРИТЕРИИ ОЦЕНКИ
// ============================================================================

pub const Criterion = struct {
    name: []const u8,
    weight: f64,
    evaluate: *const fn (*const genome.LawGenome) f64,
};

// ============================================================================
// ОСНОВНЫЕ КРИТЕРИИ
// ============================================================================

/// Бонус за безразмерность (самый важный!)
fn evalDimensionless(law: *const genome.LawGenome) f64 {
    if (law.isDimensionless()) return 100.0;
    return 0;
}

/// Бонус за близость к простым числам
fn evalSimpleValue(law: *const genome.LawGenome) f64 {
    const val = law.computeValue();
    if (math.isNan(val) or math.isInf(val) or val <= 0) return -50;
    
    if (constants.findNearestTarget(val, 0.05)) |target| {
        return @as(f64, @floatFromInt(target.importance)) * 10.0 * (1.0 - target.diff / 0.05);
    }
    
    // Бонус за близость к степеням 10
    const log_val = @log10(val);
    const frac = log_val - @floor(log_val);
    if (frac < 0.05 or frac > 0.95) {
        return 30.0;
    }
    
    return 0;
}

/// Штраф за известные значения
fn evalNovelty(law: *const genome.LawGenome) f64 {
    const val = law.computeValue();
    if (constants.isKnownValue(val, 0.01)) |_| {
        return -80.0;  // Сильный штраф за переоткрытие
    }
    return 20.0;  // Бонус за новизну
}

/// Бонус за простоту формулы
fn evalSimplicity(law: *const genome.LawGenome) f64 {
    const c = law.complexity();
    if (c <= 4) return 40.0;
    if (c <= 6) return 30.0;
    if (c <= 8) return 20.0;
    if (c <= 10) return 10.0;
    return -@as(f64, @floatFromInt(c - 10)) * 2.0;
}

/// Бонус за физически значимую размерность
fn evalPhysicalDimension(law: *const genome.LawGenome) f64 {
    const dim = law.computeDimension();
    
    // Безразмерная
    if (dim[0] == 0 and dim[1] == 0 and dim[2] == 0 and dim[3] == 0 and dim[4] == 0) return 50.0;
    
    // Энергия [M L² T⁻²]
    if (dim[0] == 1 and dim[1] == 2 and dim[2] == -2 and dim[3] == 0 and dim[4] == 0) return 30.0;
    
    // Сила [M L T⁻²]
    if (dim[0] == 1 and dim[1] == 1 and dim[2] == -2 and dim[3] == 0 and dim[4] == 0) return 30.0;
    
    // Длина [L]
    if (dim[0] == 0 and dim[1] == 1 and dim[2] == 0 and dim[3] == 0 and dim[4] == 0) return 25.0;
    
    // Время [T]
    if (dim[0] == 0 and dim[1] == 0 and dim[2] == 1 and dim[3] == 0 and dim[4] == 0) return 25.0;
    
    // Масса [M]
    if (dim[0] == 1 and dim[1] == 0 and dim[2] == 0 and dim[3] == 0 and dim[4] == 0) return 25.0;
    
    // Частота [T⁻¹]
    if (dim[0] == 0 and dim[1] == 0 and dim[2] == -1 and dim[3] == 0 and dim[4] == 0) return 25.0;
    
    // Плотность информации [L⁻²]
    if (dim[0] == 0 and dim[1] == -2 and dim[2] == 0 and dim[3] == 0 and dim[4] == 0) return 30.0;
    
    // Энтропия [M L² T⁻² K⁻¹]
    if (dim[0] == 1 and dim[1] == 2 and dim[2] == -2 and dim[3] == 0 and dim[4] == -1) return 25.0;
    
    return 0;
}

/// Бонус за связь квантов и гравитации
fn evalQuantumGravity(law: *const genome.LawGenome) f64 {
    const has_hbar = law.powers[2] != 0;
    const has_G = law.powers[1] != 0;
    const has_c = law.powers[0] != 0;
    
    var score: f64 = 0;
    
    if (has_hbar and has_G) score += 40.0;
    if (has_hbar and has_G and has_c) score += 20.0;
    
    return score;
}

/// Бонус за космологическую связь
fn evalCosmological(law: *const genome.LawGenome) f64 {
    var score: f64 = 0;
    
    // H₀ (индекс 9 в старом genome, нужно проверить)
    if (law.powers[9] != 0) score += 50.0;
    
    // Связь с массами частиц
    const has_me = law.powers[5] != 0;
    const has_mp = law.powers[6] != 0;
    
    if (has_me and has_mp) score += 30.0;
    
    return score;
}

/// Штраф за экстремальные значения
fn evalExtreme(law: *const genome.LawGenome) f64 {
    const val = law.computeValue();
    if (math.isNan(val) or math.isInf(val)) return -200.0;
    if (val == 0) return -100.0;
    
    const log_val = @abs(@log10(val));
    if (log_val > 150) return -100.0;
    if (log_val > 100) return -50.0;
    
    return 0;
}

/// Бонус за предсказательную силу (связь с наблюдаемыми)
fn evalPredictive(law: *const genome.LawGenome) f64 {
    const val = law.computeValue();
    if (math.isNan(val) or math.isInf(val) or val <= 0) return 0;
    
    // Проверяем, предсказывает ли формула известные величины
    
    // H₀ ≈ 70 км/с/Мпк = 2.27e-18 1/с
    const H0_observed: f64 = 2.27e-18;
    var ratio = val / H0_observed;
    if (ratio > 0.9 and ratio < 1.1) return 100.0;
    
    // Λ ≈ 1.1e-52 м⁻²
    const Lambda_observed: f64 = 1.1e-52;
    ratio = val / Lambda_observed;
    if (ratio > 0.9 and ratio < 1.1) return 100.0;
    
    // T_CMB ≈ 2.725 K
    const TCMB_observed: f64 = 2.725;
    ratio = val / TCMB_observed;
    if (ratio > 0.9 and ratio < 1.1) return 80.0;
    
    return 0;
}

// ============================================================================
// ГЛАВНАЯ ФИТНЕС-ФУНКЦИЯ
// ============================================================================

pub const CRITERIA = [_]Criterion{
    .{ .name = "dimensionless", .weight = 1.0, .evaluate = evalDimensionless },
    .{ .name = "simple_value", .weight = 1.0, .evaluate = evalSimpleValue },
    .{ .name = "novelty", .weight = 1.0, .evaluate = evalNovelty },
    .{ .name = "simplicity", .weight = 0.8, .evaluate = evalSimplicity },
    .{ .name = "physical_dim", .weight = 0.7, .evaluate = evalPhysicalDimension },
    .{ .name = "quantum_gravity", .weight = 1.2, .evaluate = evalQuantumGravity },
    .{ .name = "cosmological", .weight = 1.5, .evaluate = evalCosmological },
    .{ .name = "extreme", .weight = 1.0, .evaluate = evalExtreme },
    .{ .name = "predictive", .weight = 2.0, .evaluate = evalPredictive },
};

pub fn evaluate(law: *const genome.LawGenome) f64 {
    var total: f64 = 0;
    
    for (CRITERIA) |criterion| {
        const score = criterion.evaluate(law);
        total += score * criterion.weight;
    }
    
    return total;
}

pub fn evaluateDetailed(law: *const genome.LawGenome) struct { total: f64, breakdown: [9]f64 } {
    var breakdown: [9]f64 = undefined;
    var total: f64 = 0;
    
    for (CRITERIA, 0..) |criterion, i| {
        const score = criterion.evaluate(law);
        breakdown[i] = score * criterion.weight;
        total += breakdown[i];
    }
    
    return .{ .total = total, .breakdown = breakdown };
}

// ============================================================================
// СПЕЦИАЛЬНАЯ ПРОВЕРКА НАШЕГО ОТКРЫТИЯ
// ============================================================================

pub fn checkHubbleRelation(law: *const genome.LawGenome) struct { matches: bool, value: f64, diff_percent: f64 } {
    // ℏ²H₀/(cG me mp²) ≈ 1/2
    // Требуется: c^-1, G^-1, ℏ^2, me^-1, mp^-2, H₀^1
    
    const expected_powers = [_]i8{ -1, -1, 2, 0, 0, -1, -2, 0, 0, 1, 0, 0 };
    
    var matches = true;
    for (0..12) |i| {
        if (i < law.powers.len and law.powers[i] != expected_powers[i]) {
            matches = false;
            break;
        }
    }
    
    const val = law.computeValue();
    const diff = @abs(val - 0.5) / 0.5 * 100;
    
    return .{ .matches = matches, .value = val, .diff_percent = diff };
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "fitness_dimensionless" {
    var law = genome.LawGenome.init();
    law.powers[8] = 1;  // α
    
    const score = evalDimensionless(&law);
    try std.testing.expect(score > 0);
}

test "fitness_quantum_gravity" {
    var law = genome.LawGenome.init();
    law.powers[1] = 1;  // G
    law.powers[2] = 1;  // ℏ
    
    const score = evalQuantumGravity(&law);
    try std.testing.expect(score >= 40);
}

test "fitness_total" {
    var law = genome.LawGenome.init();
    law.powers[0] = -1;  // c^-1
    law.powers[1] = -1;  // G^-1
    law.powers[2] = 2;   // ℏ^2
    law.powers[5] = -1;  // me^-1
    law.powers[6] = -2;  // mp^-2
    law.powers[9] = 1;   // H₀^1
    
    const score = evaluate(&law);
    try std.testing.expect(score > 100);  // Должен быть высокий
}
