// FULL PERIODIC TABLE EXTENSION
// Complete property predictions for elements 119-172

const std = @import("std");
const print = std.debug.print;
const math = std.math;

const FINE_STRUCTURE: f64 = 1.0 / 137.036;

const Element = struct {
    z: u32,
    symbol: [4]u8,
    name: [20]u8,
    group: u8,
    period: u8,
    block: u8,
    mass: f64,
    radius_pm: f64,
    electronegativity: f64,
    ionization_ev: f64,
    density_gcc: f64,
    melting_k: f64,
    boiling_k: f64,
    rel_contraction: f64,
    half_life: [30]u8,
    chemical_behavior: [50]u8,
};

fn copyStr(dest: []u8, src: []const u8) void {
    const len = @min(dest.len - 1, src.len);
    @memcpy(dest[0..len], src[0..len]);
    dest[len] = 0;
}

fn relativisticFactor(z: u32) f64 {
    const zf = @as(f64, @floatFromInt(z));
    const za = zf * FINE_STRUCTURE;
    if (za >= 0.99) return 0.15;
    return @sqrt(1.0 - za * za);
}

fn predictElement(z: u32) Element {
    var e: Element = undefined;
    e.z = z;
    
    // Symbol
    const symbols = [_][]const u8{
        "Uue", "Ubn", "Ubu", "Ubb", "Ubt", "Ubq", "Ubp", "Ubh",
        "Ubs", "Ubo", "Ube", "Utn", "Utu", "Utb", "Utt", "Utq",
        "Utp", "Uth", "Uts", "Uto", "Ute", "Uqn", "Uqu", "Uqb",
        "Uqt", "Uqq", "Uqp", "Uqh", "Uqs", "Uqo", "Uqe", "Upn",
        "Upu", "Upb", "Upt", "Upq", "Upp", "Uph", "Ups", "Upo",
        "Upe", "Uhn", "Uhu", "Uhb", "Uht", "Uhq", "Uhp", "Uhh",
        "Uhs", "Uho", "Uhe", "Usn", "Usu", "Usb",
    };
    const idx = if (z >= 119 and z <= 172) z - 119 else 0;
    copyStr(&e.symbol, symbols[@min(idx, symbols.len - 1)]);
    
    // Name
    const names = [_][]const u8{
        "Ununennium", "Unbinilium", "Unbiunium", "Unbibium",
        "Unbitrium", "Unbiquadium", "Unbipentium", "Unbihexium",
        "Unbiseptium", "Unbioctium", "Unbiennium", "Untrinilium",
    };
    copyStr(&e.name, if (idx < names.len) names[idx] else "Unknown");
    
    // Period and block
    e.period = if (z <= 170) 8 else 9;
    
    if (z >= 119 and z <= 120) {
        e.block = 0; // s
        e.group = @intCast(z - 118);
    } else if (z >= 121 and z <= 138) {
        e.block = 4; // g (NEW!)
        e.group = 3;
    } else if (z >= 139 and z <= 152) {
        e.block = 3; // f
        e.group = 3;
    } else if (z >= 153 and z <= 162) {
        e.block = 2; // d
        e.group = @intCast((z - 153) + 3);
    } else if (z >= 163 and z <= 168) {
        e.block = 1; // p
        e.group = @intCast((z - 163) + 13);
    } else if (z >= 169 and z <= 170) {
        e.block = 0; // s
        e.group = @intCast(z - 168);
    } else {
        e.block = 0;
        e.group = 0;
    }
    
    // Mass
    const zf = @as(f64, @floatFromInt(z));
    e.mass = zf * 2.6 + (zf - 100) * 0.03;
    
    // Relativistic contraction
    e.rel_contraction = relativisticFactor(z);
    
    // Radius (pm) with relativistic correction
    const base_r = 200.0 - @as(f64, @floatFromInt(e.group)) * 5.0;
    e.radius_pm = base_r * e.rel_contraction;
    
    // Electronegativity
    if (e.group == 18) {
        e.electronegativity = 0;
    } else {
        e.electronegativity = 0.5 + @as(f64, @floatFromInt(e.group)) * 0.1;
        e.electronegativity *= (1.0 + (1.0 - e.rel_contraction) * 0.3);
    }
    
    // Ionization energy
    const n = @as(f64, @floatFromInt(e.period));
    e.ionization_ev = 13.6 * (zf * 0.3) / (n * n) * e.rel_contraction;
    
    // Density
    e.density_gcc = e.mass / (e.radius_pm * 0.1) * 0.5;
    
    // Melting/boiling points
    e.melting_k = switch (e.block) {
        0 => 400 - @as(f64, @floatFromInt(e.period)) * 30,
        1 => 500,
        2 => 1800,
        3 => 1200,
        4 => 1000,
        else => 500,
    };
    e.boiling_k = e.melting_k * 1.8;
    
    // Half-life prediction
    if (z == 126) {
        copyStr(&e.half_life, "minutes-hours (magic)");
    } else if (z >= 119 and z <= 122) {
        copyStr(&e.half_life, "milliseconds");
    } else if (z >= 123 and z <= 130) {
        copyStr(&e.half_life, "microseconds");
    } else {
        copyStr(&e.half_life, "nanoseconds");
    }
    
    // Chemical behavior
    if (z == 119) {
        copyStr(&e.chemical_behavior, "Most reactive alkali metal");
    } else if (z == 120) {
        copyStr(&e.chemical_behavior, "Highly reactive alkaline earth");
    } else if (z == 121) {
        copyStr(&e.chemical_behavior, "FIRST g-block element!");
    } else if (z == 126) {
        copyStr(&e.chemical_behavior, "Island of stability center");
    } else if (e.block == 4) {
        copyStr(&e.chemical_behavior, "g-block: new chemistry");
    } else {
        copyStr(&e.chemical_behavior, "Predicted from trends");
    }
    
    return e;
}

fn blockChar(b: u8) u8 {
    return switch (b) {
        0 => 's', 1 => 'p', 2 => 'd', 3 => 'f', 4 => 'g', else => '?',
    };
}

fn printStr(s: []const u8) void {
    for (s) |c| {
        if (c == 0) break;
        print("{c}", .{c});
    }
}

pub fn main() !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    print("║          EXTENDED PERIODIC TABLE: ELEMENTS 119-172                           ║\n", .{});
    print("║          Predicted via Creation Pattern Analysis                             ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════════════════════╝\n", .{});
    
    // Period 8 s-block
    print("\n┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
    print("│ PERIOD 8 s-BLOCK (Z=119-120): Alkali and Alkaline Earth Metals              │\n", .{});
    print("└─────────────────────────────────────────────────────────────────────────────┘\n", .{});
    
    print("\n{s:>4} {s:>5} {s:<12} {s:>4} {s:>2} {s:>7} {s:>7} {s:>5} {s:>6} {s:>7}\n", .{
        "Z", "Sym", "Name", "Grp", "Bl", "Mass", "R(pm)", "EN", "IE", "RelC%",
    });
    print("{s}\n", .{"-" ** 75});
    
    var z: u32 = 119;
    while (z <= 120) : (z += 1) {
        const e = predictElement(z);
        print("{d:>4} ", .{e.z});
        printStr(&e.symbol);
        print("  ", .{});
        printStr(&e.name);
        print(" {d:>4} {c:>2} {d:>7.1} {d:>7.1} {d:>5.2} {d:>6.1} {d:>6.1}%\n", .{
            e.group, blockChar(e.block), e.mass, e.radius_pm,
            e.electronegativity, e.ionization_ev, (1.0 - e.rel_contraction) * 100,
        });
    }
    
    // Period 8 g-block
    print("\n┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
    print("│ PERIOD 8 g-BLOCK (Z=121-138): SUPERACTINIDES - NEW TYPE OF ELEMENTS!        │\n", .{});
    print("└─────────────────────────────────────────────────────────────────────────────┘\n", .{});
    
    print("\n{s:>4} {s:>5} {s:<12} {s:>4} {s:>2} {s:>7} {s:>7} {s:>5} {s:>6} {s:>7}\n", .{
        "Z", "Sym", "Name", "Grp", "Bl", "Mass", "R(pm)", "EN", "IE", "RelC%",
    });
    print("{s}\n", .{"-" ** 75});
    
    z = 121;
    while (z <= 138) : (z += 1) {
        const e = predictElement(z);
        print("{d:>4} ", .{e.z});
        printStr(&e.symbol);
        print("  ", .{});
        printStr(&e.name);
        print(" {d:>4} {c:>2} {d:>7.1} {d:>7.1} {d:>5.2} {d:>6.1} {d:>6.1}%", .{
            e.group, blockChar(e.block), e.mass, e.radius_pm,
            e.electronegativity, e.ionization_ev, (1.0 - e.rel_contraction) * 100,
        });
        if (z == 126) print(" ★ MAGIC", .{});
        print("\n", .{});
    }
    
    // Island of stability detail
    print("\n┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
    print("│ ISLAND OF STABILITY: Detailed Predictions                                   │\n", .{});
    print("└─────────────────────────────────────────────────────────────────────────────┘\n", .{});
    
    const island_elements = [_]u32{ 114, 120, 126 };
    for (island_elements) |iz| {
        const e = predictElement(iz);
        print("\n★ Element {d} (", .{iz});
        printStr(&e.symbol);
        print("):\n", .{});
        print("   Atomic mass: {d:.1} u\n", .{e.mass});
        print("   Atomic radius: {d:.1} pm\n", .{e.radius_pm});
        print("   Relativistic contraction: {d:.1}%\n", .{(1.0 - e.rel_contraction) * 100});
        print("   Predicted half-life: ", .{});
        printStr(&e.half_life);
        print("\n", .{});
        print("   Chemical behavior: ", .{});
        printStr(&e.chemical_behavior);
        print("\n", .{});
        
        if (iz == 126) {
            print("\n   ╔═══════════════════════════════════════════════════════════╗\n", .{});
            print("   ║ Z=126 is a MAGIC NUMBER (closed proton shell)             ║\n", .{});
            print("   ║ Predicted to be center of ISLAND OF STABILITY             ║\n", .{});
            print("   ║ Half-life could be MINUTES TO HOURS instead of μs         ║\n", .{});
            print("   ╚═══════════════════════════════════════════════════════════╝\n", .{});
        }
    }
    
    // Relativistic effects
    print("\n┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
    print("│ RELATIVISTIC EFFECTS: Why Superheavy Elements Are Different                 │\n", .{});
    print("└─────────────────────────────────────────────────────────────────────────────┘\n", .{});
    
    print(
        \\
        \\As Z increases, inner electrons approach speed of light:
        \\
        \\  v/c ≈ Z × α ≈ Z / 137
        \\
        \\For Z=137 (Feynmanium): v/c = 1 (theoretical limit!)
        \\
        \\Effects:
        \\  1. s and p orbitals CONTRACT (closer to nucleus)
        \\  2. d and f orbitals EXPAND (shielded by contracted s/p)
        \\  3. Chemical properties DEVIATE from periodic trends
        \\
        \\Examples:
        \\  - Gold is yellow (not silver) due to relativistic effects
        \\  - Mercury is liquid due to relativistic effects
        \\  - Element 119 may be LESS reactive than expected
        \\
    , .{});
    
    // Summary table
    print("\n┌─────────────────────────────────────────────────────────────────────────────┐\n", .{});
    print("│ SUMMARY: Key Predicted Elements                                             │\n", .{});
    print("└─────────────────────────────────────────────────────────────────────────────┘\n", .{});
    
    print(
        \\
        \\┌───────┬────────┬─────────────────────────────────────────────────────────────┐
        \\│   Z   │ Symbol │ Significance                                                │
        \\├───────┼────────┼─────────────────────────────────────────────────────────────┤
        \\│  119  │  Uue   │ First Period 8 element, most electropositive                │
        \\│  120  │  Ubn   │ Heaviest alkaline earth, near magic N=184                   │
        \\│  121  │  Ubu   │ FIRST g-BLOCK ELEMENT - new chemistry!                      │
        \\│  126  │  Ubh   │ MAGIC NUMBER Z=126 - island of stability                    │
        \\│  164  │  Uhq   │ Possibly doubly magic (Z=164, N=308)                        │
        \\│  172  │  Usb   │ Feynmanium limit - QED may break down                       │
        \\└───────┴────────┴─────────────────────────────────────────────────────────────┘
        \\
    , .{});
    
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    print("║ Creation Pattern: Protons + Neutrons → Nuclear Forces → Element Properties  ║\n", .{});
    print("║ These predictions are based on periodic law extrapolation + relativity      ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════════════════════╝\n", .{});
}
