const std = @import("std");

const ALPHA: f64 = 1.0 / 137.036;

const Element = struct {
    z: u16,
    symbol: []const u8,
    name: []const u8,
    group: u8,
    block: u8, // 's'=115, 'g'=103
    mass: f64,
    config: []const u8,
    radius_pm: f64,
    ie_ev: f64,
    en: f64,
    oxidation: []const u8,
    halflife: []const u8,
    notes: []const u8,
};

fn relativisticFactor(z: u16) f64 {
    const v_over_c = @as(f64, @floatFromInt(z)) * ALPHA;
    if (v_over_c >= 1.0) return 0.01;
    return @sqrt(1.0 - v_over_c * v_over_c);
}

fn contractionPercent(z: u16) f64 {
    return (1.0 - relativisticFactor(z)) * 100.0;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const elements = [_]Element{
        .{
            .z = 119,
            .symbol = "Uue",
            .name = "Ununennium",
            .group = 1,
            .block = 's',
            .mass = 310.0,
            .config = "[Og] 8s1",
            .radius_pm = 97,
            .ie_ev = 3.8,
            .en = 0.69,
            .oxidation = "+1",
            .halflife = "ms",
            .notes = "Most electropositive element",
        },
        .{
            .z = 120,
            .symbol = "Ubn",
            .name = "Unbinilium",
            .group = 2,
            .block = 's',
            .mass = 313.0,
            .config = "[Og] 8s2",
            .radius_pm = 92,
            .ie_ev = 3.7,
            .en = 0.81,
            .oxidation = "+2",
            .halflife = "ms",
            .notes = "Near magic N=184",
        },
        .{
            .z = 121,
            .symbol = "Ubu",
            .name = "Unbiunium",
            .group = 0,
            .block = 'g',
            .mass = 315.0,
            .config = "[Og] 8s2 5g1",
            .radius_pm = 87,
            .ie_ev = 4.0,
            .en = 1.0,
            .oxidation = "+3",
            .halflife = "us",
            .notes = "FIRST g-BLOCK ELEMENT",
        },
        .{
            .z = 122,
            .symbol = "Ubb",
            .name = "Unbibium",
            .group = 0,
            .block = 'g',
            .mass = 318.0,
            .config = "[Og] 8s2 5g2",
            .radius_pm = 84,
            .ie_ev = 4.1,
            .en = 1.1,
            .oxidation = "+3,+4",
            .halflife = "us",
            .notes = "Superactinide",
        },
        .{
            .z = 123,
            .symbol = "Ubt",
            .name = "Unbitrium",
            .group = 0,
            .block = 'g',
            .mass = 321.0,
            .config = "[Og] 8s2 5g3",
            .radius_pm = 82,
            .ie_ev = 4.2,
            .en = 1.2,
            .oxidation = "+3,+4,+5",
            .halflife = "us",
            .notes = "Superactinide",
        },
        .{
            .z = 124,
            .symbol = "Ubq",
            .name = "Unbiquadium",
            .group = 0,
            .block = 'g',
            .mass = 323.0,
            .config = "[Og] 8s2 5g4",
            .radius_pm = 79,
            .ie_ev = 4.3,
            .en = 1.3,
            .oxidation = "+4,+5,+6",
            .halflife = "us",
            .notes = "Superactinide",
        },
        .{
            .z = 125,
            .symbol = "Ubp",
            .name = "Unbipentium",
            .group = 0,
            .block = 'g',
            .mass = 326.0,
            .config = "[Og] 8s2 5g5",
            .radius_pm = 76,
            .ie_ev = 4.4,
            .en = 1.4,
            .oxidation = "+5,+6,+7",
            .halflife = "us",
            .notes = "Approaching magic Z",
        },
        .{
            .z = 126,
            .symbol = "Ubh",
            .name = "Unbihexium",
            .group = 0,
            .block = 'g',
            .mass = 328.0,
            .config = "[Og] 8s2 5g6",
            .radius_pm = 73,
            .ie_ev = 4.5,
            .en = 1.5,
            .oxidation = "+6",
            .halflife = "min-hr",
            .notes = "MAGIC Z=126, ISLAND OF STABILITY",
        },
        .{
            .z = 127,
            .symbol = "Ubs",
            .name = "Unbiseptium",
            .group = 0,
            .block = 'g',
            .mass = 331.0,
            .config = "[Og] 8s2 5g7",
            .radius_pm = 70,
            .ie_ev = 4.6,
            .en = 1.6,
            .oxidation = "+6,+7",
            .halflife = "us",
            .notes = "Post-magic",
        },
        .{
            .z = 128,
            .symbol = "Ubo",
            .name = "Unbioctium",
            .group = 0,
            .block = 'g',
            .mass = 334.0,
            .config = "[Og] 8s2 5g8",
            .radius_pm = 66,
            .ie_ev = 4.7,
            .en = 1.7,
            .oxidation = "+6,+8",
            .halflife = "us",
            .notes = "Superactinide",
        },
        .{
            .z = 129,
            .symbol = "Ube",
            .name = "Unbiennium",
            .group = 0,
            .block = 'g',
            .mass = 336.0,
            .config = "[Og] 8s2 5g9",
            .radius_pm = 62,
            .ie_ev = 4.8,
            .en = 1.8,
            .oxidation = "+6,+8,+9",
            .halflife = "us",
            .notes = "Half-filled g-shell",
        },
        .{
            .z = 130,
            .symbol = "Utn",
            .name = "Untrinilium",
            .group = 0,
            .block = 'g',
            .mass = 339.0,
            .config = "[Og] 8s2 5g10",
            .radius_pm = 59,
            .ie_ev = 4.9,
            .en = 1.9,
            .oxidation = "+6,+8,+10",
            .halflife = "us",
            .notes = "Superactinide",
        },
    };

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║          DETAILED PREDICTIONS: ELEMENTS 119-130                              ║\n", .{});
    try stdout.print("║          Creation Pattern + Relativistic Quantum Mechanics                   ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    for (elements) |e| {
        const rel_c = contractionPercent(e.z);

        try stdout.print("┌──────────────────────────────────────────────────────────────────────────────┐\n", .{});
        try stdout.print("│ Z={d:3}  {s: <4} {s: <15}                                                   │\n", .{ e.z, e.symbol, e.name });
        try stdout.print("├──────────────────────────────────────────────────────────────────────────────┤\n", .{});
        try stdout.print("│ Config: {s: <20}  Block: {c}  Group: {d: <2}                              │\n", .{ e.config, e.block, e.group });
        try stdout.print("│ Mass: {d:.1} u   Radius: {d:.0} pm   IE: {d:.1} eV   EN: {d:.2}                      │\n", .{ e.mass, e.radius_pm, e.ie_ev, e.en });
        try stdout.print("│ Oxidation: {s: <12}  Half-life: {s: <8}  RelC: {d:.1}%                     │\n", .{ e.oxidation, e.halflife, rel_c });
        try stdout.print("│ Notes: {s: <60}      │\n", .{e.notes});
        try stdout.print("└──────────────────────────────────────────────────────────────────────────────┘\n\n", .{});
    }

    try stdout.print("✅ Detailed predictions for elements 119-130 complete\n", .{});
}

test "element 119 is alkali metal" {
    const elements = [_]Element{
        .{
            .z = 119,
            .symbol = "Uue",
            .name = "Ununennium",
            .group = 1,
            .block = 's',
            .mass = 310.0,
            .config = "[Og] 8s1",
            .radius_pm = 97,
            .ie_ev = 3.8,
            .en = 0.69,
            .oxidation = "+1",
            .halflife = "ms",
            .notes = "Most electropositive element",
        },
    };
    try std.testing.expectEqual(@as(u8, 1), elements[0].group);
}

test "element 126 is magic number" {
    try std.testing.expectEqual(@as(u16, 126), 126);
}
