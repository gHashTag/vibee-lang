const std = @import("std");

/// Fine structure constant
const ALPHA: f64 = 1.0 / 137.036;

/// Speed of light (for reference)
const C: f64 = 299792458.0;

/// Relativistic correction factor for 1s electron
pub fn relativisticFactor(z: u16) f64 {
    const v_over_c = @as(f64, @floatFromInt(z)) * ALPHA;
    if (v_over_c >= 1.0) return 0.99;
    return @sqrt(1.0 - v_over_c * v_over_c);
}

/// Relativistic contraction percentage
pub fn contractionPercent(z: u16) f64 {
    return (1.0 - relativisticFactor(z)) * 100.0;
}

/// Corrected atomic radius (pm)
pub fn correctedRadius(z: u16, base_radius: f64) f64 {
    return base_radius * relativisticFactor(z);
}

/// Corrected ionization energy (eV)
pub fn correctedIE(z: u16, base_ie: f64) f64 {
    const gamma = relativisticFactor(z);
    if (gamma < 0.01) return base_ie * 10.0;
    return base_ie / gamma;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n=== RELATIVISTIC CORRECTIONS ===\n\n", .{});

    // Test elements
    const elements = [_]struct { z: u16, name: []const u8 }{
        .{ .z = 79, .name = "Gold" },
        .{ .z = 119, .name = "Uue" },
        .{ .z = 126, .name = "Ubh" },
        .{ .z = 137, .name = "Uts" },
    };

    for (elements) |e| {
        const factor = relativisticFactor(e.z);
        const contraction = contractionPercent(e.z);
        try stdout.print("Z={d:3} {s}: factor={d:.3}, contraction={d:.1}%\n", .{ e.z, e.name, factor, contraction });
    }

    try stdout.print("\n✅ Relativistic corrections computed\n", .{});
}

test "gold relativistic effect" {
    const factor = relativisticFactor(79);
    try std.testing.expect(factor > 0.8 and factor < 0.95);
}

test "element 126 contraction" {
    const contraction = contractionPercent(126);
    try std.testing.expect(contraction > 50.0 and contraction < 70.0);
}
