// ═══════════════════════════════════════════════════════════════════════════════
// phi_layout v24.φ - Generated from specs/phi_layout.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// Алгоритмы размещения с φ-оптимизацией
// Золотая идентичность: φ² + 1/φ² = 3
//
// DO NOT EDIT - This file is auto-generated from .vibee specification
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const phi_core = @import("phi_core.zig");

const PHI = phi_core.PHI;
const PHI_INV = phi_core.PHI_INV;
const TAU = phi_core.TAU;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec2 = extern struct {
    x: f64,
    y: f64,
    
    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x + other.x, .y = self.y + other.y };
    }
    
    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x - other.x, .y = self.y - other.y };
    }
    
    pub fn scale(self: Vec2, s: f64) Vec2 {
        return Vec2{ .x = self.x * s, .y = self.y * s };
    }
    
    pub fn magnitude(self: Vec2) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
    
    pub fn normalize(self: Vec2) Vec2 {
        const mag = self.magnitude();
        if (mag < 1e-10) return Vec2{ .x = 0, .y = 0 };
        return self.scale(1.0 / mag);
    }
};

pub const LayoutNode = extern struct {
    id: u64,
    x: f64,
    y: f64,
    vx: f64,
    vy: f64,
    fx: f64,
    fy: f64,
    mass: f64,
    phi_weight: f64,
    fixed: bool,
    _pad: [7]u8,
};

pub const LayoutEdge = extern struct {
    source: u32,
    target: u32,
    ideal_length: f64,
    strength: f64,
    phi_factor: f64,
};

pub const LayoutConfig = extern struct {
    width: f64,
    height: f64,
    iterations: u32,
    _pad: u32,
    damping: f64,
    repulsion_strength: f64,
    attraction_strength: f64,
    phi_factor: f64,
    convergence_threshold: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_LAYOUT_NODES = 2048;
const MAX_LAYOUT_EDGES = 8192;

var layout_nodes: [MAX_LAYOUT_NODES]LayoutNode align(16) = undefined;
var layout_edges: [MAX_LAYOUT_EDGES]LayoutEdge align(16) = undefined;
var layout_node_count: u32 = 0;
var layout_edge_count: u32 = 0;

var layout_config: LayoutConfig = LayoutConfig{
    .width = 1000.0,
    .height = 618.0, // 1000/φ
    .iterations = 100,
    ._pad = 0,
    .damping = PHI_INV,
    .repulsion_strength = PHI * 100.0, // Уменьшено для стабильности
    .attraction_strength = 0.05,
    .phi_factor = PHI,
    .convergence_threshold = 0.1,
};

export fn get_layout_nodes_ptr() [*]LayoutNode {
    return &layout_nodes;
}

export fn get_layout_edges_ptr() [*]LayoutEdge {
    return &layout_edges;
}

export fn get_layout_node_count() u32 {
    return layout_node_count;
}

export fn get_layout_edge_count() u32 {
    return layout_edge_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ИНИЦИАЛИЗАЦИЯ
// ═══════════════════════════════════════════════════════════════════════════════

/// Инициализация layout
export fn layout_init(width: f64, height: f64) void {
    layout_config.width = width;
    layout_config.height = if (height > 0) height else width / PHI;
    layout_node_count = 0;
    layout_edge_count = 0;
}

/// Добавление узла
export fn layout_add_node(id: u64, x: f64, y: f64) u32 {
    if (layout_node_count >= MAX_LAYOUT_NODES) return 0xFFFFFFFF;
    
    const idx = layout_node_count;
    layout_nodes[idx] = LayoutNode{
        .id = id,
        .x = x,
        .y = y,
        .vx = 0,
        .vy = 0,
        .fx = 0,
        .fy = 0,
        .mass = 1.0,
        .phi_weight = phi_core.phi_power(-@as(i32, @intCast(idx % 10))),
        .fixed = false,
        ._pad = [_]u8{0} ** 7,
    };
    layout_node_count += 1;
    return idx;
}

/// Добавление ребра
export fn layout_add_edge(source: u32, target: u32) u32 {
    if (layout_edge_count >= MAX_LAYOUT_EDGES) return 0xFFFFFFFF;
    if (source >= layout_node_count or target >= layout_node_count) return 0xFFFFFFFF;
    
    const idx = layout_edge_count;
    layout_edges[idx] = LayoutEdge{
        .source = source,
        .target = target,
        .ideal_length = 100.0 * PHI,
        .strength = 1.0,
        .phi_factor = PHI_INV,
    };
    layout_edge_count += 1;
    return idx;
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-SPIRAL LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

/// Размещение узлов по φ-спирали
export fn layout_phi_spiral() void {
    const cx = layout_config.width / 2.0;
    const cy = layout_config.height / 2.0;
    const scale = @min(layout_config.width, layout_config.height) * 0.4;
    
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * (1.0 - @exp(-fi * 0.1));
        
        layout_nodes[i].x = cx + radius * @cos(angle);
        layout_nodes[i].y = cy + radius * @sin(angle);
    }
}

/// Размещение по Fermat спирали (подсолнух)
export fn layout_fermat_spiral() void {
    const cx = layout_config.width / 2.0;
    const cy = layout_config.height / 2.0;
    const scale = @min(layout_config.width, layout_config.height) * 0.45 / @sqrt(@as(f64, @floatFromInt(layout_node_count)));
    
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * @sqrt(fi);
        
        layout_nodes[i].x = cx + radius * @cos(angle);
        layout_nodes[i].y = cy + radius * @sin(angle);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORCE-DIRECTED LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

/// Один шаг force-directed layout
export fn layout_force_step() f64 {
    // Сбрасываем силы
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        layout_nodes[i].fx = 0;
        layout_nodes[i].fy = 0;
    }
    
    // Вычисляем k (оптимальное расстояние)
    const area = layout_config.width * layout_config.height;
    const k = @sqrt(area / @as(f64, @floatFromInt(layout_node_count))) * PHI;
    
    // Отталкивание между всеми парами
    compute_repulsion(k);
    
    // Притяжение по рёбрам
    compute_attraction(k);
    
    // Применяем силы
    return apply_forces();
}

/// Вычисление сил отталкивания
fn compute_repulsion(k: f64) void {
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        var j: u32 = i + 1;
        while (j < layout_node_count) : (j += 1) {
            const dx = layout_nodes[j].x - layout_nodes[i].x;
            const dy = layout_nodes[j].y - layout_nodes[i].y;
            var dist = @sqrt(dx * dx + dy * dy);
            if (dist < 1.0) dist = 1.0;
            
            // F = φ × k² / d
            const force = layout_config.repulsion_strength * k * k / (dist * dist);
            const fx = (dx / dist) * force;
            const fy = (dy / dist) * force;
            
            layout_nodes[i].fx -= fx;
            layout_nodes[i].fy -= fy;
            layout_nodes[j].fx += fx;
            layout_nodes[j].fy += fy;
        }
    }
}

/// Вычисление сил притяжения
fn compute_attraction(k: f64) void {
    var i: u32 = 0;
    while (i < layout_edge_count) : (i += 1) {
        const edge = &layout_edges[i];
        const source = &layout_nodes[edge.source];
        const target = &layout_nodes[edge.target];
        
        const dx = target.x - source.x;
        const dy = target.y - source.y;
        var dist = @sqrt(dx * dx + dy * dy);
        if (dist < 1.0) dist = 1.0;
        
        // F = d² / (k × φ)
        const force = layout_config.attraction_strength * dist * dist / (k * PHI);
        const fx = (dx / dist) * force;
        const fy = (dy / dist) * force;
        
        layout_nodes[edge.source].fx += fx;
        layout_nodes[edge.source].fy += fy;
        layout_nodes[edge.target].fx -= fx;
        layout_nodes[edge.target].fy -= fy;
    }
}

/// Применение сил и возврат энергии системы
fn apply_forces() f64 {
    var energy: f64 = 0.0;
    const damping = layout_config.damping;
    
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        const node = &layout_nodes[i];
        if (node.fixed) continue;
        
        // Обновляем скорость
        node.vx = node.vx * 0.9 + node.fx * damping;
        node.vy = node.vy * 0.9 + node.fy * damping;
        
        // Ограничиваем скорость
        const speed = @sqrt(node.vx * node.vx + node.vy * node.vy);
        const max_speed = 50.0;
        if (speed > max_speed) {
            node.vx = node.vx / speed * max_speed;
            node.vy = node.vy / speed * max_speed;
        }
        
        // Обновляем позицию
        node.x += node.vx;
        node.y += node.vy;
        
        // Ограничиваем границами
        node.x = @max(50.0, @min(layout_config.width - 50.0, node.x));
        node.y = @max(50.0, @min(layout_config.height - 50.0, node.y));
        
        // Накапливаем энергию
        energy += node.vx * node.vx + node.vy * node.vy;
    }
    
    return energy;
}

/// Полный force-directed layout
export fn layout_force_directed(iterations: u32) f64 {
    // Начальное размещение по φ-спирали
    layout_phi_spiral();
    
    var iter: u32 = 0;
    var energy: f64 = 0;
    
    while (iter < iterations) : (iter += 1) {
        // φ-адаптивное демпфирование
        const progress: f64 = @as(f64, @floatFromInt(iter)) / @as(f64, @floatFromInt(iterations));
        layout_config.damping = PHI_INV * math.pow(f64, PHI_INV, progress);
        
        energy = layout_force_step();
        
        // Проверка сходимости
        if (energy < layout_config.convergence_threshold) break;
    }
    
    return energy;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HIERARCHICAL LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

/// Иерархическое размещение с φ-пропорциями
export fn layout_hierarchical(root: u32) void {
    if (root >= layout_node_count) return;
    
    // Определяем уровни (BFS)
    var levels: [MAX_LAYOUT_NODES]u32 = [_]u32{0xFFFFFFFF} ** MAX_LAYOUT_NODES;
    var level_counts: [64]u32 = [_]u32{0} ** 64;
    var level_indices: [64]u32 = [_]u32{0} ** 64;
    var max_level: u32 = 0;
    
    // BFS для определения уровней
    var queue: [MAX_LAYOUT_NODES]u32 = undefined;
    var queue_start: u32 = 0;
    var queue_end: u32 = 0;
    
    queue[queue_end] = root;
    queue_end += 1;
    levels[root] = 0;
    level_counts[0] = 1;
    
    while (queue_start < queue_end) {
        const current = queue[queue_start];
        queue_start += 1;
        const current_level = levels[current];
        
        // Находим соседей через рёбра
        var i: u32 = 0;
        while (i < layout_edge_count) : (i += 1) {
            const edge = &layout_edges[i];
            var neighbor: u32 = 0xFFFFFFFF;
            
            if (edge.source == current and levels[edge.target] == 0xFFFFFFFF) {
                neighbor = edge.target;
            } else if (edge.target == current and levels[edge.source] == 0xFFFFFFFF) {
                neighbor = edge.source;
            }
            
            if (neighbor != 0xFFFFFFFF) {
                levels[neighbor] = current_level + 1;
                level_counts[current_level + 1] += 1;
                if (current_level + 1 > max_level) max_level = current_level + 1;
                queue[queue_end] = neighbor;
                queue_end += 1;
            }
        }
    }
    
    // Размещаем узлы по уровням с φ-пропорциями
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        const level = levels[i];
        if (level == 0xFFFFFFFF) continue;
        
        // y = height × (1 - φ^(-level))
        const y = layout_config.height * (1.0 - phi_core.phi_power(-@as(i32, @intCast(level + 1))));
        
        // x = равномерно по ширине
        const count: f64 = @floatFromInt(level_counts[level]);
        const idx: f64 = @floatFromInt(level_indices[level]);
        const spacing = layout_config.width / (count + 1.0);
        const x = spacing * (idx + 1.0);
        
        layout_nodes[i].x = x;
        layout_nodes[i].y = y;
        level_indices[level] += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RADIAL LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

/// Радиальное размещение с φ-секторами
export fn layout_radial(center_node: u32) void {
    if (center_node >= layout_node_count) return;
    
    const cx = layout_config.width / 2.0;
    const cy = layout_config.height / 2.0;
    const base_radius = @min(layout_config.width, layout_config.height) * 0.15;
    
    // Центральный узел
    layout_nodes[center_node].x = cx;
    layout_nodes[center_node].y = cy;
    
    // Определяем кольца (уровни от центра)
    var rings: [MAX_LAYOUT_NODES]u32 = [_]u32{0xFFFFFFFF} ** MAX_LAYOUT_NODES;
    var ring_counts: [32]u32 = [_]u32{0} ** 32;
    var ring_indices: [32]u32 = [_]u32{0} ** 32;
    
    rings[center_node] = 0;
    
    // BFS для определения колец
    var queue: [MAX_LAYOUT_NODES]u32 = undefined;
    var queue_start: u32 = 0;
    var queue_end: u32 = 0;
    
    queue[queue_end] = center_node;
    queue_end += 1;
    
    while (queue_start < queue_end) {
        const current = queue[queue_start];
        queue_start += 1;
        const current_ring = rings[current];
        
        var i: u32 = 0;
        while (i < layout_edge_count) : (i += 1) {
            const edge = &layout_edges[i];
            var neighbor: u32 = 0xFFFFFFFF;
            
            if (edge.source == current and rings[edge.target] == 0xFFFFFFFF) {
                neighbor = edge.target;
            } else if (edge.target == current and rings[edge.source] == 0xFFFFFFFF) {
                neighbor = edge.source;
            }
            
            if (neighbor != 0xFFFFFFFF) {
                rings[neighbor] = current_ring + 1;
                ring_counts[current_ring + 1] += 1;
                queue[queue_end] = neighbor;
                queue_end += 1;
            }
        }
    }
    
    // Размещаем по кольцам
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        if (i == center_node) continue;
        
        const ring = rings[i];
        if (ring == 0xFFFFFFFF) continue;
        
        // radius = base × φ^ring
        const radius = base_radius * phi_core.phi_power(@intCast(ring));
        
        // Угол в кольце
        const count: f64 = @floatFromInt(ring_counts[ring]);
        const idx: f64 = @floatFromInt(ring_indices[ring]);
        const angle = TAU * idx / count;
        
        layout_nodes[i].x = cx + radius * @cos(angle);
        layout_nodes[i].y = cy + radius * @sin(angle);
        ring_indices[ring] += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// УТИЛИТЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// Вычисление энергии системы
export fn layout_energy() f64 {
    var energy: f64 = 0.0;
    
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        const node = &layout_nodes[i];
        energy += node.vx * node.vx + node.vy * node.vy;
    }
    
    return energy;
}

/// Центрирование layout
export fn layout_center() void {
    if (layout_node_count == 0) return;
    
    // Находим центр масс
    var sum_x: f64 = 0;
    var sum_y: f64 = 0;
    
    var i: u32 = 0;
    while (i < layout_node_count) : (i += 1) {
        sum_x += layout_nodes[i].x;
        sum_y += layout_nodes[i].y;
    }
    
    const n: f64 = @floatFromInt(layout_node_count);
    const cx = sum_x / n;
    const cy = sum_y / n;
    
    // Смещаем к центру canvas
    const offset_x = layout_config.width / 2.0 - cx;
    const offset_y = layout_config.height / 2.0 - cy;
    
    i = 0;
    while (i < layout_node_count) : (i += 1) {
        layout_nodes[i].x += offset_x;
        layout_nodes[i].y += offset_y;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "layout_phi_spiral" {
    layout_init(1000.0, 618.0);
    
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = layout_add_node(i, 0, 0);
    }
    
    layout_phi_spiral();
    
    // Проверяем что узлы размещены
    try std.testing.expect(layout_nodes[0].x > 0);
    try std.testing.expect(layout_nodes[0].y > 0);
}

test "layout_force_directed" {
    layout_init(1000.0, 618.0);
    
    // Создаём простой граф с начальными позициями по спирали
    _ = layout_add_node(0, 500, 309);
    _ = layout_add_node(1, 600, 309);
    _ = layout_add_node(2, 550, 400);
    _ = layout_add_edge(0, 1);
    _ = layout_add_edge(1, 2);
    _ = layout_add_edge(2, 0);
    
    // Больше итераций для сходимости
    const energy = layout_force_directed(100);
    
    // Энергия должна быть разумной (не бесконечной)
    try std.testing.expect(energy < 10000.0);
    try std.testing.expect(!std.math.isNan(energy));
    try std.testing.expect(!std.math.isInf(energy));
}
