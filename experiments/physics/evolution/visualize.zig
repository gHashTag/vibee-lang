// VISUALIZE.ZIG - Визуализация результатов эволюции
// ASCII-графики и отчёты

const std = @import("std");
const genome = @import("genome.zig");
const constants = @import("constants_extended.zig");

// ============================================================================
// ASCII ГИСТОГРАММА
// ============================================================================

pub fn printHistogram(title: []const u8, values: []const f64, bins: u32) void {
    const print = std.debug.print;
    
    if (values.len == 0) return;
    
    // Находим min/max
    var min_val = values[0];
    var max_val = values[0];
    for (values) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }
    
    if (min_val == max_val) {
        print("{s}: all values = {d:.2}\n", .{ title, min_val });
        return;
    }
    
    // Считаем бины
    var counts: [50]u32 = [_]u32{0} ** 50;
    const actual_bins = @min(bins, 50);
    const bin_width = (max_val - min_val) / @as(f64, @floatFromInt(actual_bins));
    
    for (values) |v| {
        var bin_idx = @as(usize, @intFromFloat((v - min_val) / bin_width));
        if (bin_idx >= actual_bins) bin_idx = actual_bins - 1;
        counts[bin_idx] += 1;
    }
    
    // Находим максимум для масштабирования
    var max_count: u32 = 0;
    for (counts[0..actual_bins]) |c| {
        if (c > max_count) max_count = c;
    }
    
    // Печатаем
    print("\n{s}\n", .{title});
    print("-" ** 50 ++ "\n", .{});
    
    const bar_width: u32 = 40;
    for (0..actual_bins) |i| {
        const bin_start = min_val + @as(f64, @floatFromInt(i)) * bin_width;
        const bar_len = if (max_count > 0) counts[i] * bar_width / max_count else 0;
        
        print("{d:>8.1} |", .{bin_start});
        for (0..bar_len) |_| print("█", .{});
        print(" {}\n", .{counts[i]});
    }
    print("\n", .{});
}

// ============================================================================
// ТАБЛИЦА РЕЗУЛЬТАТОВ
// ============================================================================

pub fn printResultsTable(laws: []const genome.LawGenome, top_n: usize) void {
    const print = std.debug.print;
    
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  TOP {} DISCOVERED LAWS\n", .{top_n});
    print("=" ** 70 ++ "\n\n", .{});
    
    print("{s:>4} {s:>10} {s:>15} {s:>12} {s}\n", .{ "Rank", "Fitness", "Value", "Dimension", "Formula" });
    print("-" ** 70 ++ "\n", .{});
    
    for (laws[0..@min(top_n, laws.len)], 0..) |law, i| {
        print("{:>4} {d:>10.2} {e:>15.4} {s:>12} ", .{
            i + 1,
            law.fitness,
            law.computeValue(),
            law.getDimensionName(),
        });
        law.printFormula();
        print("\n", .{});
    }
    print("\n", .{});
}

// ============================================================================
// СТАТИСТИКА ЭВОЛЮЦИИ
// ============================================================================

pub fn printEvolutionStats(laws: []const genome.LawGenome) void {
    const print = std.debug.print;
    
    if (laws.len == 0) return;
    
    // Статистика фитнеса
    var sum_fitness: f64 = 0;
    var max_fitness: f64 = laws[0].fitness;
    var min_fitness: f64 = laws[0].fitness;
    
    for (laws) |law| {
        sum_fitness += law.fitness;
        if (law.fitness > max_fitness) max_fitness = law.fitness;
        if (law.fitness < min_fitness) min_fitness = law.fitness;
    }
    
    const avg_fitness = sum_fitness / @as(f64, @floatFromInt(laws.len));
    
    // Статистика размерностей
    var dimensionless_count: u32 = 0;
    var energy_count: u32 = 0;
    var length_count: u32 = 0;
    var other_count: u32 = 0;
    
    for (laws) |law| {
        const dim_name = law.getDimensionName();
        if (std.mem.eql(u8, dim_name, "безразмерная")) {
            dimensionless_count += 1;
        } else if (std.mem.eql(u8, dim_name, "энергия")) {
            energy_count += 1;
        } else if (std.mem.eql(u8, dim_name, "длина")) {
            length_count += 1;
        } else {
            other_count += 1;
        }
    }
    
    print("\n" ++ "=" ** 50 ++ "\n", .{});
    print("  EVOLUTION STATISTICS\n", .{});
    print("=" ** 50 ++ "\n\n", .{});
    
    print("Population size: {}\n", .{laws.len});
    print("\nFitness:\n", .{});
    print("  Max: {d:.2}\n", .{max_fitness});
    print("  Avg: {d:.2}\n", .{avg_fitness});
    print("  Min: {d:.2}\n", .{min_fitness});
    
    print("\nDimensions:\n", .{});
    print("  Dimensionless: {} ({d:.1}%)\n", .{ dimensionless_count, @as(f64, @floatFromInt(dimensionless_count)) / @as(f64, @floatFromInt(laws.len)) * 100 });
    print("  Energy: {}\n", .{energy_count});
    print("  Length: {}\n", .{length_count});
    print("  Other: {}\n", .{other_count});
    print("\n", .{});
}

// ============================================================================
// ОТЧЁТ ОБ ОТКРЫТИИ
// ============================================================================

pub fn printDiscoveryReport() void {
    const print = std.debug.print;
    
    print("\n", .{});
    print("*" ** 70 ++ "\n", .{});
    print("*" ++ " " ** 20 ++ "DISCOVERY REPORT" ++ " " ** 24 ++ "*\n", .{});
    print("*" ** 70 ++ "\n\n", .{});
    
    print("MAIN DISCOVERY:\n", .{});
    print("-" ** 50 ++ "\n\n", .{});
    
    print("Relation: ℏ²H₀/(cG·mₑ·mₚ²) ≈ 1/2\n\n", .{});
    
    // Вычисляем
    const hbar: f64 = 1.054571817e-34;
    const c: f64 = 299792458;
    const G: f64 = 6.67430e-11;
    const me: f64 = 9.1093837015e-31;
    const mp: f64 = 1.67262192369e-27;
    const H0: f64 = 2.2e-18;
    
    const ratio = hbar * hbar * H0 / (c * G * me * mp * mp);
    
    print("Numerical value: {d:.6}\n", .{ratio});
    print("Expected: 0.5\n", .{});
    print("Difference: {d:.2}%\n\n", .{@abs(ratio - 0.5) / 0.5 * 100});
    
    // Предсказание
    const H0_predicted = c * G * me * mp * mp / (2 * hbar * hbar);
    const Mpc: f64 = 3.086e22;
    const H0_kms = H0_predicted * Mpc / 1000;
    
    print("PREDICTION:\n", .{});
    print("-" ** 50 ++ "\n\n", .{});
    print("If relation = 1/2 exactly:\n", .{});
    print("  H₀ = cG·mₑ·mₚ²/(2ℏ²)\n", .{});
    print("  H₀ = {e:.4} s⁻¹\n", .{H0_predicted});
    print("  H₀ = {d:.1} km/s/Mpc\n\n", .{H0_kms});
    
    print("Observed: ~70 km/s/Mpc\n", .{});
    print("Agreement: ~{d:.0}%\n\n", .{100 - @abs(H0_kms - 70) / 70 * 100});
    
    print("SIGNIFICANCE:\n", .{});
    print("-" ** 50 ++ "\n\n", .{});
    print("1. Links cosmology (H₀) to particle physics (mₑ, mₚ)\n", .{});
    print("2. Involves quantum mechanics (ℏ) and gravity (G)\n", .{});
    print("3. Predicts H₀ between CMB (67) and SNe (73) values\n", .{});
    print("4. May help resolve the Hubble tension\n\n", .{});
    
    print("STATUS: Hypothesis - requires theoretical derivation\n", .{});
    print("\n" ++ "*" ** 70 ++ "\n", .{});
}

// ============================================================================
// ГЛАВНАЯ ФУНКЦИЯ ВИЗУАЛИЗАЦИИ
// ============================================================================

pub fn main() !void {
    printDiscoveryReport();
}

test "histogram" {
    const values = [_]f64{ 1, 2, 3, 4, 5, 5, 5, 6, 7, 8 };
    printHistogram("Test", &values, 5);
}
