// РАСШИРЕННЫЙ ПОИСК НОВЫХ ФИЗИЧЕСКИХ ЗАКОНОВ
const std = @import("std");
const math = std.math;
const print = std.debug.print;

// Фундаментальные константы
const c: f64 = 299792458;
const G: f64 = 6.674e-11;
const hbar: f64 = 1.055e-34;
const k_B: f64 = 1.381e-23;
const e_charge: f64 = 1.602e-19;
const m_e: f64 = 9.109e-31;
const m_p: f64 = 1.673e-27;
const alpha: f64 = 1.0 / 137.036;
const epsilon_0: f64 = 8.854e-12;

pub fn main() !void {
    print("\n" ++ "=" ** 70 ++ "\n", .{});
    print("  РАСШИРЕННЫЙ ПОИСК: 7 констант, степени -3..3\n", .{});
    print("=" ** 70 ++ "\n\n", .{});

    var interesting: usize = 0;
    var total: usize = 0;

    // c^a * G^b * hbar^h * m_e^me * m_p^mp * e^eq
    var a: i8 = -2;
    while (a <= 2) : (a += 1) {
        var b: i8 = -2;
        while (b <= 2) : (b += 1) {
            var h: i8 = -2;
            while (h <= 2) : (h += 1) {
                var me: i8 = -1;
                while (me <= 1) : (me += 1) {
                    var mp: i8 = -1;
                    while (mp <= 1) : (mp += 1) {
                        if (a == 0 and b == 0 and h == 0 and me == 0 and mp == 0) continue;

                        const val = math.pow(f64, c, @floatFromInt(a)) *
                            math.pow(f64, G, @floatFromInt(b)) *
                            math.pow(f64, hbar, @floatFromInt(h)) *
                            math.pow(f64, m_e, @floatFromInt(me)) *
                            math.pow(f64, m_p, @floatFromInt(mp));

                        // Безразмерные комбинации
                        const dim_M = -b + h + me + mp;
                        const dim_L = a + 3 * b + 2 * h;
                        const dim_T = -a - 2 * b - h;

                        if (dim_M == 0 and dim_L == 0 and dim_T == 0) {
                            if (val > 1e-50 and val < 1e50 and val != 1.0) {
                                interesting += 1;
                                if (interesting <= 15) {
                                    print("#{}: c^{} G^{} h^{} me^{} mp^{} = {e:.3}\n", .{ interesting, a, b, h, me, mp, val });
                                }
                            }
                        }
                        total += 1;
                    }
                }
            }
        }
    }

    print("\nВсего: {}, безразмерных: {}\n", .{ total, interesting });
}
