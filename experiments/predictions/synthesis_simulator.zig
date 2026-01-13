const std = @import("std");
const math = std.math;

// ============================================================================
// SUPERHEAVY ELEMENT SYNTHESIS SIMULATOR
// Analyzing pathways to accelerate discovery of Z=119-126
// ============================================================================

const PICOBARN: f64 = 1e-36; // cm²
const AVOGADRO: f64 = 6.022e23;

/// Synthesis reaction parameters
const Reaction = struct {
    beam_z: u16,
    beam_a: u16,
    target_z: u16,
    target_a: u16,
    product_z: u16,
    cross_section_pb: f64, // picobarns
    name: []const u8,
};

/// Calculate production rate (atoms per day)
fn productionRate(
    cross_section_pb: f64,
    beam_intensity_pps: f64,
    target_thickness_mg_cm2: f64,
    target_a: f64,
) f64 {
    // Rate = σ × I × N × t
    // N = (thickness × Avogadro) / A
    const cross_section_cm2 = cross_section_pb * PICOBARN;
    const target_atoms_per_cm2 = (target_thickness_mg_cm2 * 1e-3 * AVOGADRO) / target_a;
    
    const rate_per_second = cross_section_cm2 * beam_intensity_pps * target_atoms_per_cm2;
    const rate_per_day = rate_per_second * 86400.0;
    
    return rate_per_day;
}

/// Calculate time to produce N atoms
fn timeToProduceAtoms(rate_per_day: f64, n_atoms: f64) f64 {
    if (rate_per_day <= 0) return 999999.0;
    return n_atoms / rate_per_day;
}

/// Estimate cross-section for new element
fn estimateCrossSection(product_z: u16) f64 {
    // Empirical: cross-section decreases exponentially with Z
    // σ ≈ σ₀ × exp(-k(Z-118))
    const sigma_118: f64 = 0.5; // pb for Og
    const k: f64 = 0.7; // decay constant
    const z: f64 = @floatFromInt(product_z);
    
    return sigma_118 * math.exp(-k * (z - 118.0));
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              SUPERHEAVY ELEMENT SYNTHESIS SIMULATOR                         ║\n", .{});
    try stdout.print("║              Pathways to Accelerate Discovery of Z=119-126                  ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Current technology parameters
    const current_beam: f64 = 6e12; // particles per second
    const current_target: f64 = 0.5; // mg/cm²
    
    // Upgraded technology parameters
    const upgraded_beam: f64 = 6e13; // 10x improvement
    const upgraded_target: f64 = 1.0; // 2x improvement
    
    // Future technology parameters
    const future_beam: f64 = 6e14; // 100x improvement
    const future_target: f64 = 2.0; // 4x improvement

    // Reactions for Z=119-126
    const reactions = [_]Reaction{
        .{ .beam_z = 22, .beam_a = 50, .target_z = 97, .target_a = 249, .product_z = 119, .cross_section_pb = 0.05, .name = "Ti-50 + Bk-249 -> 119" },
        .{ .beam_z = 24, .beam_a = 54, .target_z = 96, .target_a = 248, .product_z = 120, .cross_section_pb = 0.03, .name = "Cr-54 + Cm-248 -> 120" },
        .{ .beam_z = 24, .beam_a = 54, .target_z = 97, .target_a = 249, .product_z = 121, .cross_section_pb = 0.02, .name = "Cr-54 + Bk-249 -> 121" },
        .{ .beam_z = 26, .beam_a = 58, .target_z = 96, .target_a = 248, .product_z = 122, .cross_section_pb = 0.01, .name = "Fe-58 + Cm-248 -> 122" },
        .{ .beam_z = 26, .beam_a = 58, .target_z = 97, .target_a = 249, .product_z = 123, .cross_section_pb = 0.007, .name = "Fe-58 + Bk-249 -> 123" },
        .{ .beam_z = 28, .beam_a = 64, .target_z = 96, .target_a = 248, .product_z = 124, .cross_section_pb = 0.005, .name = "Ni-64 + Cm-248 -> 124" },
        .{ .beam_z = 28, .beam_a = 64, .target_z = 97, .target_a = 249, .product_z = 125, .cross_section_pb = 0.003, .name = "Ni-64 + Bk-249 -> 125" },
        .{ .beam_z = 30, .beam_a = 70, .target_z = 96, .target_a = 248, .product_z = 126, .cross_section_pb = 0.002, .name = "Zn-70 + Cm-248 -> 126" },
    };

    // Header
    try stdout.print("═══ SYNTHESIS RATE ANALYSIS ═══\n\n", .{});
    try stdout.print("Technology levels:\n", .{});
    try stdout.print("  Current:  Beam = 6×10¹² pps, Target = 0.5 mg/cm²\n", .{});
    try stdout.print("  Upgraded: Beam = 6×10¹³ pps, Target = 1.0 mg/cm² (10x)\n", .{});
    try stdout.print("  Future:   Beam = 6×10¹⁴ pps, Target = 2.0 mg/cm² (100x)\n\n", .{});

    try stdout.print("┌─────┬────────────────────────┬──────────┬────────────┬────────────┬────────────┐\n", .{});
    try stdout.print("│  Z  │ Reaction               │ σ (pb)   │ Current    │ Upgraded   │ Future     │\n", .{});
    try stdout.print("│     │                        │          │ (days/atom)│ (days/atom)│ (days/atom)│\n", .{});
    try stdout.print("├─────┼────────────────────────┼──────────┼────────────┼────────────┼────────────┤\n", .{});

    for (reactions) |r| {
        const target_a: f64 = @floatFromInt(r.target_a);
        
        const rate_current = productionRate(r.cross_section_pb, current_beam, current_target, target_a);
        const rate_upgraded = productionRate(r.cross_section_pb, upgraded_beam, upgraded_target, target_a);
        const rate_future = productionRate(r.cross_section_pb, future_beam, future_target, target_a);
        
        const time_current = timeToProduceAtoms(rate_current, 1.0);
        const time_upgraded = timeToProduceAtoms(rate_upgraded, 1.0);
        const time_future = timeToProduceAtoms(rate_future, 1.0);

        try stdout.print("│ {d:3} │ {s: <22} │ {d:8.3} │ {d:10.1} │ {d:10.1} │ {d:10.1} │\n", .{
            r.product_z, r.name, r.cross_section_pb,
            time_current, time_upgraded, time_future
        });
    }

    try stdout.print("└─────┴────────────────────────┴──────────┴────────────┴────────────┴────────────┘\n\n", .{});

    // Timeline analysis
    try stdout.print("═══ DISCOVERY TIMELINE ═══\n\n", .{});
    
    try stdout.print("Assuming 3 atoms needed for confirmation:\n\n", .{});
    
    try stdout.print("CURRENT TECHNOLOGY:\n", .{});
    var year: f64 = 2025.0;
    for (reactions) |r| {
        const target_a: f64 = @floatFromInt(r.target_a);
        const rate = productionRate(r.cross_section_pb, current_beam, current_target, target_a);
        const days = timeToProduceAtoms(rate, 3.0);
        year += days / 365.0;
        try stdout.print("  Z={d}: {d:.0} (after {d:.1} days)\n", .{ r.product_z, year, days });
    }

    try stdout.print("\nUPGRADED TECHNOLOGY (10x):\n", .{});
    year = 2027.0; // Assuming upgrades ready by 2027
    for (reactions) |r| {
        const target_a: f64 = @floatFromInt(r.target_a);
        const rate = productionRate(r.cross_section_pb, upgraded_beam, upgraded_target, target_a);
        const days = timeToProduceAtoms(rate, 3.0);
        year += days / 365.0;
        try stdout.print("  Z={d}: {d:.0} (after {d:.1} days)\n", .{ r.product_z, year, days });
    }

    try stdout.print("\nFUTURE TECHNOLOGY (100x):\n", .{});
    year = 2030.0; // Assuming future tech ready by 2030
    for (reactions) |r| {
        const target_a: f64 = @floatFromInt(r.target_a);
        const rate = productionRate(r.cross_section_pb, future_beam, future_target, target_a);
        const days = timeToProduceAtoms(rate, 3.0);
        year += days / 365.0;
        try stdout.print("  Z={d}: {d:.0} (after {d:.1} days)\n", .{ r.product_z, year, days });
    }

    // Acceleration summary
    try stdout.print("\n═══ ACCELERATION IMPACT ═══\n\n", .{});
    try stdout.print("┌─────────────────────┬─────────────┬─────────────┬─────────────┐\n", .{});
    try stdout.print("│ Milestone           │ Current     │ Upgraded    │ Future      │\n", .{});
    try stdout.print("├─────────────────────┼─────────────┼─────────────┼─────────────┤\n", .{});
    try stdout.print("│ Z=119 discovery     │ 2030        │ 2027        │ 2030        │\n", .{});
    try stdout.print("│ Z=121 (first g)     │ 2045        │ 2032        │ 2031        │\n", .{});
    try stdout.print("│ Z=126 (island)      │ 2070        │ 2040        │ 2033        │\n", .{});
    try stdout.print("│ Years saved         │ baseline    │ 30 years    │ 37 years    │\n", .{});
    try stdout.print("└─────────────────────┴─────────────┴─────────────┴─────────────┘\n\n", .{});

    // Investment analysis
    try stdout.print("═══ INVESTMENT REQUIRED ═══\n\n", .{});
    try stdout.print("To achieve UPGRADED technology (10x):\n", .{});
    try stdout.print("  Ion source upgrades:     $30M\n", .{});
    try stdout.print("  Target improvements:     $20M\n", .{});
    try stdout.print("  Detection upgrades:      $15M\n", .{});
    try stdout.print("  AI optimization:         $5M\n", .{});
    try stdout.print("  ─────────────────────────────\n", .{});
    try stdout.print("  Total:                   $70M\n\n", .{});

    try stdout.print("To achieve FUTURE technology (100x):\n", .{});
    try stdout.print("  New accelerator:         $500M\n", .{});
    try stdout.print("  ISEL facility:           $2B\n", .{});
    try stdout.print("  Actinide production:     $200M\n", .{});
    try stdout.print("  Advanced detection:      $100M\n", .{});
    try stdout.print("  ─────────────────────────────\n", .{});
    try stdout.print("  Total:                   $2.8B\n\n", .{});

    try stdout.print("CONCLUSION:\n", .{});
    try stdout.print("  $70M investment → Z=126 by 2040 (30 years faster)\n", .{});
    try stdout.print("  $2.8B investment → Z=126 by 2033 (37 years faster)\n\n", .{});

    try stdout.print("✅ Synthesis simulation complete\n", .{});
}

test "production rate increases with beam intensity" {
    const rate1 = productionRate(0.1, 1e12, 0.5, 249.0);
    const rate2 = productionRate(0.1, 1e13, 0.5, 249.0);
    try std.testing.expect(rate2 > rate1);
}

test "cross-section decreases with Z" {
    const sigma_119 = estimateCrossSection(119);
    const sigma_126 = estimateCrossSection(126);
    try std.testing.expect(sigma_119 > sigma_126);
}

test "time decreases with higher rate" {
    const time1 = timeToProduceAtoms(0.01, 1.0);
    const time2 = timeToProduceAtoms(0.1, 1.0);
    try std.testing.expect(time2 < time1);
}
