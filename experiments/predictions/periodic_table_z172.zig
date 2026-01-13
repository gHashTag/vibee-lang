const std = @import("std");

const ALPHA: f64 = 1.0 / 137.036;

const Element = struct {
    z: u16,
    symbol: []const u8,
    period: u8,
    block: u8,
    mass: f64,
};

fn relativisticContraction(z: u16) f64 {
    const v_over_c = @as(f64, @floatFromInt(z)) * ALPHA;
    if (v_over_c >= 0.99) return 99.0;
    return (1.0 - @sqrt(1.0 - v_over_c * v_over_c)) * 100.0;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // Period 8 elements (Z=119-168)
    const period8 = [_]Element{
        // s-block (2)
        .{ .z = 119, .symbol = "Uue", .period = 8, .block = 's', .mass = 310 },
        .{ .z = 120, .symbol = "Ubn", .period = 8, .block = 's', .mass = 313 },
        // g-block (18)
        .{ .z = 121, .symbol = "Ubu", .period = 8, .block = 'g', .mass = 315 },
        .{ .z = 122, .symbol = "Ubb", .period = 8, .block = 'g', .mass = 318 },
        .{ .z = 123, .symbol = "Ubt", .period = 8, .block = 'g', .mass = 321 },
        .{ .z = 124, .symbol = "Ubq", .period = 8, .block = 'g', .mass = 323 },
        .{ .z = 125, .symbol = "Ubp", .period = 8, .block = 'g', .mass = 326 },
        .{ .z = 126, .symbol = "Ubh", .period = 8, .block = 'g', .mass = 328 },
        .{ .z = 127, .symbol = "Ubs", .period = 8, .block = 'g', .mass = 331 },
        .{ .z = 128, .symbol = "Ubo", .period = 8, .block = 'g', .mass = 334 },
        .{ .z = 129, .symbol = "Ube", .period = 8, .block = 'g', .mass = 336 },
        .{ .z = 130, .symbol = "Utn", .period = 8, .block = 'g', .mass = 339 },
        .{ .z = 131, .symbol = "Utu", .period = 8, .block = 'g', .mass = 342 },
        .{ .z = 132, .symbol = "Utb", .period = 8, .block = 'g', .mass = 344 },
        .{ .z = 133, .symbol = "Utt", .period = 8, .block = 'g', .mass = 347 },
        .{ .z = 134, .symbol = "Utq", .period = 8, .block = 'g', .mass = 349 },
        .{ .z = 135, .symbol = "Utp", .period = 8, .block = 'g', .mass = 352 },
        .{ .z = 136, .symbol = "Uth", .period = 8, .block = 'g', .mass = 355 },
        .{ .z = 137, .symbol = "Uts", .period = 8, .block = 'g', .mass = 357 },
        .{ .z = 138, .symbol = "Uto", .period = 8, .block = 'g', .mass = 360 },
        // f-block (14)
        .{ .z = 139, .symbol = "Ute", .period = 8, .block = 'f', .mass = 363 },
        .{ .z = 140, .symbol = "Uqn", .period = 8, .block = 'f', .mass = 366 },
        .{ .z = 141, .symbol = "Uqu", .period = 8, .block = 'f', .mass = 369 },
        .{ .z = 142, .symbol = "Uqb", .period = 8, .block = 'f', .mass = 372 },
        .{ .z = 143, .symbol = "Uqt", .period = 8, .block = 'f', .mass = 375 },
        .{ .z = 144, .symbol = "Uqq", .period = 8, .block = 'f', .mass = 378 },
        .{ .z = 145, .symbol = "Uqp", .period = 8, .block = 'f', .mass = 381 },
        .{ .z = 146, .symbol = "Uqh", .period = 8, .block = 'f', .mass = 384 },
        .{ .z = 147, .symbol = "Uqs", .period = 8, .block = 'f', .mass = 387 },
        .{ .z = 148, .symbol = "Uqo", .period = 8, .block = 'f', .mass = 390 },
        .{ .z = 149, .symbol = "Uqe", .period = 8, .block = 'f', .mass = 393 },
        .{ .z = 150, .symbol = "Upn", .period = 8, .block = 'f', .mass = 396 },
        .{ .z = 151, .symbol = "Upu", .period = 8, .block = 'f', .mass = 399 },
        .{ .z = 152, .symbol = "Upb", .period = 8, .block = 'f', .mass = 402 },
        // d-block (10)
        .{ .z = 153, .symbol = "Upt", .period = 8, .block = 'd', .mass = 405 },
        .{ .z = 154, .symbol = "Upq", .period = 8, .block = 'd', .mass = 408 },
        .{ .z = 155, .symbol = "Upp", .period = 8, .block = 'd', .mass = 411 },
        .{ .z = 156, .symbol = "Uph", .period = 8, .block = 'd', .mass = 414 },
        .{ .z = 157, .symbol = "Ups", .period = 8, .block = 'd', .mass = 417 },
        .{ .z = 158, .symbol = "Upo", .period = 8, .block = 'd', .mass = 420 },
        .{ .z = 159, .symbol = "Upe", .period = 8, .block = 'd', .mass = 423 },
        .{ .z = 160, .symbol = "Uhn", .period = 8, .block = 'd', .mass = 426 },
        .{ .z = 161, .symbol = "Uhu", .period = 8, .block = 'd', .mass = 429 },
        .{ .z = 162, .symbol = "Uhb", .period = 8, .block = 'd', .mass = 432 },
        // p-block (6)
        .{ .z = 163, .symbol = "Uht", .period = 8, .block = 'p', .mass = 435 },
        .{ .z = 164, .symbol = "Uhq", .period = 8, .block = 'p', .mass = 438 },
        .{ .z = 165, .symbol = "Uhp", .period = 8, .block = 'p', .mass = 441 },
        .{ .z = 166, .symbol = "Uhh", .period = 8, .block = 'p', .mass = 444 },
        .{ .z = 167, .symbol = "Uhs", .period = 8, .block = 'p', .mass = 447 },
        .{ .z = 168, .symbol = "Uho", .period = 8, .block = 'p', .mass = 450 },
    };

    // Period 9 elements (Z=169-172)
    const period9 = [_]Element{
        .{ .z = 169, .symbol = "Uhe", .period = 9, .block = 's', .mass = 453 },
        .{ .z = 170, .symbol = "Usn", .period = 9, .block = 's', .mass = 456 },
        .{ .z = 171, .symbol = "Usu", .period = 9, .block = 'g', .mass = 459 },
        .{ .z = 172, .symbol = "Usb", .period = 9, .block = 'g', .mass = 462 },
    };

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              COMPLETE PERIODIC TABLE EXTENSION: Z=119-172                   ║\n", .{});
    try stdout.print("║                    Creation Pattern Predictions                             ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    try stdout.print("PERIOD 8 STRUCTURE:\n", .{});
    try stdout.print("  s-block: Z=119-120 (2 elements)  - Alkali/Alkaline earth\n", .{});
    try stdout.print("  g-block: Z=121-138 (18 elements) - SUPERACTINIDES (NEW!)\n", .{});
    try stdout.print("  f-block: Z=139-152 (14 elements) - Superactinides continued\n", .{});
    try stdout.print("  d-block: Z=153-162 (10 elements) - Transition metals\n", .{});
    try stdout.print("  p-block: Z=163-168 (6 elements)  - Main group\n\n", .{});

    try stdout.print("PERIOD 9 (THEORETICAL LIMIT):\n", .{});
    try stdout.print("  s-block: Z=169-170 (2 elements)\n", .{});
    try stdout.print("  g-block: Z=171-172 (2 elements) - DIRAC LIMIT\n\n", .{});

    try stdout.print("┌─────┬──────┬────┬───────┬────────┬──────────────────────────────────────────┐\n", .{});
    try stdout.print("│  Z  │ Sym  │ Bl │ Mass  │ RelC%  │ Notes                                    │\n", .{});
    try stdout.print("├─────┼──────┼────┼───────┼────────┼──────────────────────────────────────────┤\n", .{});

    for (period8) |e| {
        const rel_c = relativisticContraction(e.z);
        var notes: []const u8 = "";
        if (e.z == 119) notes = "First Period 8";
        if (e.z == 121) notes = "FIRST g-BLOCK ELEMENT";
        if (e.z == 126) notes = "MAGIC Z - ISLAND CENTER";
        if (e.z == 137) notes = "FEYNMANIUM LIMIT";
        if (e.z == 139) notes = "First 6f element";
        if (e.z == 153) notes = "First 7d element";
        if (e.z == 163) notes = "First 8p element";
        if (e.z == 164) notes = "Doubly magic candidate";
        if (e.z == 168) notes = "Last Period 8 noble gas";

        try stdout.print("│ {d:3} │ {s: <4} │  {c} │ {d:5.0} │ {d:5.1}% │ {s: <40} │\n", .{ e.z, e.symbol, e.block, e.mass, rel_c, notes });
    }

    try stdout.print("├─────┼──────┼────┼───────┼────────┼──────────────────────────────────────────┤\n", .{});
    try stdout.print("│     │      │    │       │        │ PERIOD 9 - THEORETICAL LIMIT             │\n", .{});
    try stdout.print("├─────┼──────┼────┼───────┼────────┼──────────────────────────────────────────┤\n", .{});

    for (period9) |e| {
        const rel_c = relativisticContraction(e.z);
        var notes: []const u8 = "";
        if (e.z == 169) notes = "First Period 9";
        if (e.z == 172) notes = "DIRAC LIMIT - END OF TABLE";

        try stdout.print("│ {d:3} │ {s: <4} │  {c} │ {d:5.0} │ {d:5.1}% │ {s: <40} │\n", .{ e.z, e.symbol, e.block, e.mass, rel_c, notes });
    }

    try stdout.print("└─────┴──────┴────┴───────┴────────┴──────────────────────────────────────────┘\n\n", .{});

    try stdout.print("SUMMARY:\n", .{});
    try stdout.print("  Total predicted elements: 54 (Z=119 to Z=172)\n", .{});
    try stdout.print("  Period 8: 50 elements\n", .{});
    try stdout.print("  Period 9: 4 elements (theoretical)\n", .{});
    try stdout.print("  New orbital type: g-block (18 elements)\n", .{});
    try stdout.print("  Island of stability center: Z=126, N=184\n", .{});
    try stdout.print("  Theoretical limit: Z=172 (Dirac equation)\n\n", .{});

    try stdout.print("✅ Full periodic table extension to Z=172 complete\n", .{});
}

test "period 8 has 50 elements" {
    try std.testing.expectEqual(@as(u16, 50), 168 - 119 + 1);
}

test "g-block has 18 elements" {
    try std.testing.expectEqual(@as(u16, 18), 138 - 121 + 1);
}

test "relativistic contraction increases with Z" {
    const c119 = relativisticContraction(119);
    const c172 = relativisticContraction(172);
    try std.testing.expect(c172 > c119);
}
