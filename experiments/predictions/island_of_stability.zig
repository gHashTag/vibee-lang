const std = @import("std");

const ALPHA: f64 = 1.0 / 137.036;

const IslandIsotope = struct {
    z: u16,
    n: u16,
    symbol: []const u8,
    name: []const u8,
    mass: f64,
    halflife_estimate: []const u8,
    stability_factor: f64, // 0-1, higher = more stable
    decay_mode: []const u8,
    notes: []const u8,
};

fn calculateStabilityFactor(z: u16, n: u16) f64 {
    var factor: f64 = 0.0;

    // Proton magic number bonus
    if (z == 114 or z == 120 or z == 126) {
        factor += 0.3;
    }

    // Neutron magic number bonus
    if (n == 184) {
        factor += 0.4;
    } else if (n == 178 or n == 172) {
        factor += 0.2;
    }

    // Even-even nucleus bonus
    if (z % 2 == 0 and n % 2 == 0) {
        factor += 0.2;
    }

    // Distance from optimal N/Z ratio penalty
    const optimal_ratio: f64 = 1.5;
    const actual_ratio = @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(z));
    const ratio_diff = @abs(actual_ratio - optimal_ratio);
    factor -= ratio_diff * 0.1;

    return @max(0.0, @min(1.0, factor));
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const isotopes = [_]IslandIsotope{
        // Flerovium region (Z=114)
        .{
            .z = 114,
            .n = 184,
            .symbol = "Fl",
            .name = "Flerovium-298",
            .mass = 298.0,
            .halflife_estimate = "hours-days",
            .stability_factor = 0.85,
            .decay_mode = "alpha",
            .notes = "Doubly magic candidate",
        },
        .{
            .z = 114,
            .n = 178,
            .symbol = "Fl",
            .name = "Flerovium-292",
            .mass = 292.0,
            .halflife_estimate = "seconds",
            .stability_factor = 0.65,
            .decay_mode = "alpha",
            .notes = "Known isotope, enhanced stability",
        },

        // Element 120 region
        .{
            .z = 120,
            .n = 184,
            .symbol = "Ubn",
            .name = "Unbinilium-304",
            .mass = 304.0,
            .halflife_estimate = "minutes-hours",
            .stability_factor = 0.80,
            .decay_mode = "alpha/SF",
            .notes = "Magic N, near magic Z",
        },
        .{
            .z = 120,
            .n = 178,
            .symbol = "Ubn",
            .name = "Unbinilium-298",
            .mass = 298.0,
            .halflife_estimate = "ms-seconds",
            .stability_factor = 0.55,
            .decay_mode = "alpha",
            .notes = "Synthesis target",
        },

        // Element 126 region - CENTER OF ISLAND
        .{
            .z = 126,
            .n = 184,
            .symbol = "Ubh",
            .name = "Unbihexium-310",
            .mass = 310.0,
            .halflife_estimate = "HOURS-DAYS",
            .stability_factor = 0.95,
            .decay_mode = "alpha",
            .notes = "DOUBLY MAGIC - MOST STABLE SUPERHEAVY",
        },
        .{
            .z = 126,
            .n = 182,
            .symbol = "Ubh",
            .name = "Unbihexium-308",
            .mass = 308.0,
            .halflife_estimate = "minutes-hours",
            .stability_factor = 0.75,
            .decay_mode = "alpha",
            .notes = "Near doubly magic",
        },
        .{
            .z = 126,
            .n = 178,
            .symbol = "Ubh",
            .name = "Unbihexium-304",
            .mass = 304.0,
            .halflife_estimate = "seconds-minutes",
            .stability_factor = 0.60,
            .decay_mode = "alpha",
            .notes = "Magic Z only",
        },

        // Surrounding elements
        .{
            .z = 118,
            .n = 184,
            .symbol = "Og",
            .name = "Oganesson-302",
            .mass = 302.0,
            .halflife_estimate = "seconds-minutes",
            .stability_factor = 0.70,
            .decay_mode = "alpha",
            .notes = "Magic N, noble gas",
        },
        .{
            .z = 124,
            .n = 184,
            .symbol = "Ubq",
            .name = "Unbiquadium-308",
            .mass = 308.0,
            .halflife_estimate = "minutes",
            .stability_factor = 0.72,
            .decay_mode = "alpha",
            .notes = "Magic N",
        },
    };

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    ISLAND OF STABILITY PREDICTIONS                           ║\n", .{});
    try stdout.print("║              Nuclear Shell Model + Creation Pattern Analysis                 ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    try stdout.print("Magic Numbers:\n", .{});
    try stdout.print("  Protons (Z):  2, 8, 20, 28, 50, 82, 114?, 120?, 126\n", .{});
    try stdout.print("  Neutrons (N): 2, 8, 20, 28, 50, 82, 126, 184\n\n", .{});

    try stdout.print("Island of Stability Map (Z vs N):\n", .{});
    try stdout.print("        N=172  N=178  N=184  N=190\n", .{});
    try stdout.print("Z=114    .      *      **     .\n", .{});
    try stdout.print("Z=118    .      *      **     .\n", .{});
    try stdout.print("Z=120    .      *      ***    *\n", .{});
    try stdout.print("Z=124    .      *      **     *\n", .{});
    try stdout.print("Z=126    *      **     ****   **\n", .{});
    try stdout.print("Legend: . = unstable, * = enhanced, ** = stable, *** = very stable, **** = MOST STABLE\n\n", .{});

    try stdout.print("┌──────────────────────────────────────────────────────────────────────────────┐\n", .{});
    try stdout.print("│                         DETAILED ISOTOPE PREDICTIONS                        │\n", .{});
    try stdout.print("└──────────────────────────────────────────────────────────────────────────────┘\n\n", .{});

    for (isotopes) |iso| {
        const calc_stability = calculateStabilityFactor(iso.z, iso.n);

        try stdout.print("┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
        try stdout.print("│ {s: <20} (Z={d}, N={d})                                          │\n", .{ iso.name, iso.z, iso.n });
        try stdout.print("├─────────────────────────────────────────────────────────────────────────────┤\n", .{});
        try stdout.print("│ Mass: {d:.0} u    Stability Factor: {d:.2}    Calculated: {d:.2}              │\n", .{ iso.mass, iso.stability_factor, calc_stability });
        try stdout.print("│ Half-life: {s: <15}  Decay: {s: <10}                              │\n", .{ iso.halflife_estimate, iso.decay_mode });
        try stdout.print("│ Notes: {s: <60}     │\n", .{iso.notes});
        try stdout.print("└─────────────────────────────────────────────────────────────────────────────┘\n\n", .{});
    }

    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("KEY PREDICTION: Unbihexium-310 (Z=126, N=184) is the MOST STABLE superheavy\n", .{});
    try stdout.print("element, with predicted half-life of HOURS TO DAYS - long enough for\n", .{});
    try stdout.print("chemical study and potential applications.\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    try stdout.print("✅ Island of stability predictions complete\n", .{});
}

test "doubly magic isotope has highest stability" {
    const stability_126_184 = calculateStabilityFactor(126, 184);
    const stability_114_178 = calculateStabilityFactor(114, 178);
    try std.testing.expect(stability_126_184 > stability_114_178);
}

test "magic numbers increase stability" {
    const stability_magic = calculateStabilityFactor(126, 184);
    const stability_nonmagic = calculateStabilityFactor(125, 183);
    try std.testing.expect(stability_magic > stability_nonmagic);
}
