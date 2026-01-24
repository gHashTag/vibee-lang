//! TRINITY CORE BENCHMARK SUITE
//! Measuring E-graph Saturation and Phase Transitions
//! φ² + 1/φ² = 3

const std = @import("std");
const egraph = @import("src/vibeec/egraph.zig");
const ast_bridge = @import("src/vibeec/ast_egraph_bridge.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var timer = try std.time.Timer.start();

    std.debug.print("🚀 Инициирую бенчмаркинг Trinity Core...\n", .{});

    // 1. Тест сатурации священных формул
    {
        const start = timer.read();
        var graph = egraph.EGraph.init(allocator);
        defer graph.deinit();

        try egraph.SacredRules.addSacredRules(&graph);

        // Добавляем сложное выражение: (phi^2 + phi^-2) * (pi * phi * e)
        // Должно свернуться в 3.0 * 13.8175 = 41.4525
        const phi = try graph.add(egraph.ENode.constPhi());
        const two = try graph.add(egraph.ENode.constInt(2));
        const neg_two = try graph.add(egraph.ENode.constInt(-2));

        const phi_sq = try graph.add(egraph.ENode.withChildren(.pow, phi, two));
        const inv_phi_sq = try graph.add(egraph.ENode.withChildren(.pow, phi, neg_two));
        const sum = try graph.add(egraph.ENode.withChildren(.add, phi_sq, inv_phi_sq));

        const pi = try graph.add(egraph.ENode.constPi());
        const e_const = try graph.add(egraph.ENode.constE());
        const pi_phi = try graph.add(egraph.ENode.withChildren(.mul, pi, phi));
        const cosmic = try graph.add(egraph.ENode.withChildren(.mul, pi_phi, e_const));

        const final = try graph.add(egraph.ENode.withChildren(.mul, sum, cosmic));
        _ = final;

        try graph.saturate(20);

        const end = timer.read();
        const duration = end - start;
        const stats = graph.getStats();

        std.debug.print("\n--- E-Graph Saturation Stats ---\n", .{});
        std.debug.print("Время: {d} нс\n", .{duration});
        std.debug.print("Итераций: {d}\n", .{stats.iterations});
        std.debug.print("Переписываний (rewrites): {d}\n", .{stats.rewrites});
        std.debug.print("Узлов в графе: {d}\n", .{stats.nodes_added});
    }

    // 2. Тест экстракции "лучшего" решения
    {
        // В будущем здесь будет замер эффективности функции стоимости
    }

    std.debug.print("\n🏁 Бенчмаркинг Trinity Core завершен.\n", .{});
}
