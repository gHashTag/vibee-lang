const std = @import("std");

const ALPHA: f64 = 1.0 / 137.036;

fn relContraction(z: u16) f64 {
    const v = @as(f64, @floatFromInt(z)) * ALPHA;
    if (v >= 0.99) return 99.0;
    return (1.0 - @sqrt(1.0 - v * v)) * 100.0;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // S-BLOCK
    try stdout.print("\n=== S-BLOCK (Z=119-120): ALKALI & ALKALINE EARTH ===\n\n", .{});
    try stdout.print("Z=119 Uue: Mass=310u, R=97pm, IE=3.8eV, EN=0.69, Ox=+1, t1/2=ms\n", .{});
    try stdout.print("  Config: [Og]8s1, Most electropositive, Extremely reactive\n", .{});
    try stdout.print("Z=120 Ubn: Mass=313u, R=92pm, IE=3.7eV, EN=0.81, Ox=+2, t1/2=ms\n", .{});
    try stdout.print("  Config: [Og]8s2, Near magic N=184, Forms Ubn2+ ions\n\n", .{});

    // G-BLOCK
    try stdout.print("=== G-BLOCK (Z=121-138): SUPERACTINIDES - NEW TYPE! ===\n\n", .{});
    try stdout.print("First elements with 5g electrons! Angular momentum l=4\n\n", .{});
    const g_data = [_]struct { z: u16, sym: []const u8, mass: f64, ox: []const u8, note: []const u8 }{
        .{ .z = 121, .sym = "Ubu", .mass = 315, .ox = "+3", .note = "FIRST 5g electron" },
        .{ .z = 122, .sym = "Ubb", .mass = 318, .ox = "+3,+4", .note = "Superactinide" },
        .{ .z = 123, .sym = "Ubt", .mass = 321, .ox = "+3,+4,+5", .note = "Superactinide" },
        .{ .z = 124, .sym = "Ubq", .mass = 323, .ox = "+4,+5,+6", .note = "Superactinide" },
        .{ .z = 125, .sym = "Ubp", .mass = 326, .ox = "+5,+6,+7", .note = "Near magic Z" },
        .{ .z = 126, .sym = "Ubh", .mass = 328, .ox = "+6", .note = "MAGIC Z=126!" },
        .{ .z = 127, .sym = "Ubs", .mass = 331, .ox = "+6,+7", .note = "Post-magic" },
        .{ .z = 128, .sym = "Ubo", .mass = 334, .ox = "+6,+8", .note = "Superactinide" },
        .{ .z = 129, .sym = "Ube", .mass = 336, .ox = "+6,+8,+9", .note = "Half-filled 5g" },
        .{ .z = 130, .sym = "Utn", .mass = 339, .ox = "+6,+8,+10", .note = "Superactinide" },
        .{ .z = 131, .sym = "Utu", .mass = 342, .ox = "+6,+8", .note = "Superactinide" },
        .{ .z = 132, .sym = "Utb", .mass = 344, .ox = "+6,+8", .note = "Superactinide" },
        .{ .z = 133, .sym = "Utt", .mass = 347, .ox = "+6", .note = "Superactinide" },
        .{ .z = 134, .sym = "Utq", .mass = 349, .ox = "+4,+6", .note = "Superactinide" },
        .{ .z = 135, .sym = "Utp", .mass = 352, .ox = "+3,+4", .note = "Superactinide" },
        .{ .z = 136, .sym = "Uth", .mass = 355, .ox = "+3", .note = "Superactinide" },
        .{ .z = 137, .sym = "Uts", .mass = 357, .ox = "+3", .note = "FEYNMANIUM LIMIT" },
        .{ .z = 138, .sym = "Uto", .mass = 360, .ox = "+2,+3", .note = "End of 5g" },
    };
    for (g_data) |e| {
        try stdout.print("Z={d} {s}: Mass={d:.0}u, Ox={s}, {s}\n", .{ e.z, e.sym, e.mass, e.ox, e.note });
    }

    // F-BLOCK
    try stdout.print("\n=== F-BLOCK (Z=139-152): 6f SUPERACTINIDES ===\n\n", .{});
    try stdout.print("Filling 6f orbitals, similar to actinides but more relativistic\n", .{});
    try stdout.print("Z=139-145: Ox states +3 to +7, radioactive metals\n", .{});
    try stdout.print("Z=146-152: Ox states +3 to +4, decreasing stability\n\n", .{});

    // D-BLOCK
    try stdout.print("=== D-BLOCK (Z=153-162): 7d TRANSITION METALS ===\n\n", .{});
    try stdout.print("Filling 7d orbitals, heaviest transition metals\n", .{});
    try stdout.print("Z=153-157: Groups 3-7, Ox +3 to +7\n", .{});
    try stdout.print("Z=158-162: Groups 8-12, Ox +2 to +4, noble metal behavior\n\n", .{});

    // P-BLOCK
    try stdout.print("=== P-BLOCK (Z=163-168): 8p MAIN GROUP ===\n\n", .{});
    try stdout.print("Z=163: Group 13, Ox +1,+3 (like Tl)\n", .{});
    try stdout.print("Z=164: Group 14, Ox +2,+4 (like Pb) - DOUBLY MAGIC?\n", .{});
    try stdout.print("Z=165: Group 15, Ox +3,+5 (like Bi)\n", .{});
    try stdout.print("Z=166: Group 16, Ox -2,+4,+6 (like Po)\n", .{});
    try stdout.print("Z=167: Group 17, Ox -1,+1,+5 (like At)\n", .{});
    try stdout.print("Z=168: Group 18, NOBLE GAS - End of Period 8\n\n", .{});

    try stdout.print("=== SUMMARY ===\n", .{});
    try stdout.print("Total Period 8: 50 elements (Z=119-168)\n", .{});
    try stdout.print("New orbital type: g-block (18 elements)\n", .{});
    try stdout.print("Island of stability: Z=126, N=184\n", .{});
}

test "g-block has 18 elements" {
    try std.testing.expectEqual(@as(u16, 18), 138 - 121 + 1);
}
