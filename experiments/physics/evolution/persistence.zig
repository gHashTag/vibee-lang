// PERSISTENCE.ZIG - Сохранение и загрузка состояния эволюции
// История открытий, эвристик, популяции

const std = @import("std");
const genome = @import("genome.zig");
const heuristics = @import("heuristics.zig");

const DATA_DIR = "evolution_data";
const POPULATION_FILE = "population.dat";
const HEURISTICS_FILE = "heuristics.dat";
const DISCOVERIES_FILE = "discoveries.dat";
const HISTORY_FILE = "history.log";

// ============================================================================
// СОХРАНЕНИЕ ПОПУЛЯЦИИ
// ============================================================================

pub fn save(_: std.mem.Allocator, population: *const genome.Population, hs: *const heuristics.HeuristicSet) !void {
    
    // Создаём директорию если нет
    std.fs.cwd().makeDir(DATA_DIR) catch {};
    
    // Сохраняем популяцию
    try savePopulation(population);
    
    // Сохраняем эвристики
    try saveHeuristics(undefined, hs);
    
    // Сохраняем открытия
    try saveDiscoveries(population);
    
    // Добавляем в историю
    try appendHistory(population, hs);
    
    std.debug.print("Saved: gen={}, discoveries={}\n", .{ population.generation, population.discoveries.items.len });
}

fn savePopulation(population: *const genome.Population) !void {
    const path = DATA_DIR ++ "/" ++ POPULATION_FILE;
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    var writer = file.writer();
    
    // Заголовок
    try writer.writeInt(u32, population.generation, .little);
    try writer.writeInt(u32, @as(u32, @intCast(population.laws.items.len)), .little);
    
    // Законы
    for (population.laws.items) |law| {
        for (law.powers) |p| {
            try writer.writeInt(i8, p, .little);
        }
        try writer.writeAll(std.mem.asBytes(&law.numerator_coeff));
        try writer.writeByte(if (law.sqrt_applied) 1 else 0);
        try writer.writeAll(std.mem.asBytes(&law.fitness));
        try writer.writeInt(u32, law.generation, .little);
        try writer.writeInt(u32, law.mutations, .little);
    }
}

pub fn saveHeuristics(_: std.mem.Allocator, hs: *const heuristics.HeuristicSet) !void {
    
    const path = DATA_DIR ++ "/" ++ HEURISTICS_FILE;
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    var writer = file.writer();
    
    try writer.writeInt(u32, hs.generation, .little);
    
    for (hs.heuristics) |h| {
        try writer.writeAll(std.mem.asBytes(&h.weight));
        try writer.writeAll(std.mem.asBytes(&h.threshold));
        try writer.writeByte(if (h.enabled) 1 else 0);
        try writer.writeInt(u64, h.times_triggered, .little);
        try writer.writeInt(u64, h.discoveries_contributed, .little);
    }
}

fn saveDiscoveries(population: *const genome.Population) !void {
    const path = DATA_DIR ++ "/" ++ DISCOVERIES_FILE;
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    var writer = file.writer();
    
    try writer.writeInt(u32, @as(u32, @intCast(population.discoveries.items.len)), .little);
    
    for (population.discoveries.items) |law| {
        for (law.powers) |p| {
            try writer.writeInt(i8, p, .little);
        }
        try writer.writeAll(std.mem.asBytes(&law.numerator_coeff));
        try writer.writeByte(if (law.sqrt_applied) 1 else 0);
        try writer.writeAll(std.mem.asBytes(&law.fitness));
    }
}

fn appendHistory(population: *const genome.Population, hs: *const heuristics.HeuristicSet) !void {
    const path = DATA_DIR ++ "/" ++ HISTORY_FILE;
    const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch 
        try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    try file.seekFromEnd(0);
    var writer = file.writer();
    
    const timestamp = std.time.timestamp();
    try writer.print("{}: gen={}, best_fitness={d:.2}, discoveries={}, heuristic_gen={}\n", .{
        timestamp,
        population.generation,
        population.best_fitness,
        population.discoveries.items.len,
        hs.generation,
    });
}

// ============================================================================
// ЗАГРУЗКА
// ============================================================================

pub fn loadOrCreate(allocator: std.mem.Allocator) !genome.Population {
    return loadPopulation(allocator) catch {
        // Создаём новую популяцию
        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        var rng = prng.random();
        
        var pop = genome.Population.init(allocator);
        try pop.randomInit(100, &rng);
        return pop;
    };
}

fn loadPopulation(allocator: std.mem.Allocator) !genome.Population {
    const path = DATA_DIR ++ "/" ++ POPULATION_FILE;
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    var reader = file.reader();
    
    var pop = genome.Population.init(allocator);
    
    pop.generation = try reader.readInt(u32, .little);
    const count = try reader.readInt(u32, .little);
    
    for (0..count) |_| {
        var law = genome.LawGenome.init();
        
        for (&law.powers) |*p| {
            p.* = try reader.readInt(i8, .little);
        }
        
        var coeff_bytes: [@sizeOf(f64)]u8 align(@alignOf(f64)) = undefined;
        _ = try reader.read(&coeff_bytes);
        law.numerator_coeff = @as(*const f64, @ptrCast(&coeff_bytes)).*;
        
        law.sqrt_applied = (try reader.readByte()) == 1;
        
        var fitness_bytes: [@sizeOf(f64)]u8 align(@alignOf(f64)) = undefined;
        _ = try reader.read(&fitness_bytes);
        law.fitness = @as(*const f64, @ptrCast(&fitness_bytes)).*;
        
        law.generation = try reader.readInt(u32, .little);
        law.mutations = try reader.readInt(u32, .little);
        
        try pop.laws.append(law);
    }
    
    return pop;
}

pub fn loadHeuristics(_: std.mem.Allocator) !heuristics.HeuristicSet {
    
    const path = DATA_DIR ++ "/" ++ HEURISTICS_FILE;
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return heuristics.HeuristicSet.init();
    };
    defer file.close();
    
    var reader = file.reader();
    var hs = heuristics.HeuristicSet.init();
    
    hs.generation = try reader.readInt(u32, .little);
    
    for (&hs.heuristics) |*h| {
        var weight_bytes: [@sizeOf(f64)]u8 align(@alignOf(f64)) = undefined;
        _ = try reader.read(&weight_bytes);
        h.weight = @as(*const f64, @ptrCast(&weight_bytes)).*;
        
        var thresh_bytes: [@sizeOf(f64)]u8 align(@alignOf(f64)) = undefined;
        _ = try reader.read(&thresh_bytes);
        h.threshold = @as(*const f64, @ptrCast(&thresh_bytes)).*;
        
        h.enabled = (try reader.readByte()) == 1;
        h.times_triggered = try reader.readInt(u64, .little);
        h.discoveries_contributed = try reader.readInt(u64, .little);
    }
    
    return hs;
}

// ============================================================================
// ЭКСПОРТ ОТКРЫТИЙ
// ============================================================================

pub fn exportDiscoveries(_: std.mem.Allocator, population: *const genome.Population) !void {
    
    const path = DATA_DIR ++ "/discoveries_report.txt";
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    var writer = file.writer();
    
    try writer.print("=== DISCOVERED PHYSICAL LAWS ===\n\n", .{});
    try writer.print("Total discoveries: {}\n\n", .{population.discoveries.items.len});
    
    for (population.discoveries.items, 0..) |law, i| {
        try writer.print("Discovery #{}\n", .{i + 1});
        try writer.print("  Fitness: {d:.2}\n", .{law.fitness});
        try writer.print("  Value: {e:.6}\n", .{law.computeValue()});
        try writer.print("  Dimension: {s}\n", .{law.getDimensionName()});
        try writer.print("  Formula: ", .{});
        
        var first = true;
        for (genome.CONSTANTS, 0..) |c, j| {
            const p = law.powers[j];
            if (p != 0) {
                if (!first) try writer.print(" × ", .{});
                try writer.print("{s}", .{c.symbol});
                if (p != 1) try writer.print("^{}", .{p});
                first = false;
            }
        }
        try writer.print("\n\n", .{});
    }
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "persistence_heuristics" {
    const allocator = std.testing.allocator;
    
    var hs = heuristics.HeuristicSet.init();
    hs.heuristics[0].weight = 2.5;
    hs.generation = 42;
    
    try saveHeuristics(allocator, &hs);
    
    var loaded = try loadHeuristics(allocator);
    defer loaded.deinit();
    
    try std.testing.expectEqual(loaded.generation, 42);
    try std.testing.expectApproxEqRel(loaded.heuristics[0].weight, 2.5, 0.001);
}
