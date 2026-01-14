const std = @import("std");
const math = std.math;

/// Molecular Graph Module
/// 
/// Молекула = Граф → Алгоритмы → Предсказание свойств
///
/// Топологические индексы предсказывают:
/// - Температуру кипения
/// - Растворимость  
/// - Токсичность
/// - Реакционную способность

pub const MAX_ATOMS: usize = 64;

pub const Element = enum(u8) {
    H = 1, C = 6, N = 7, O = 8, F = 9, 
    P = 15, S = 16, Cl = 17, Br = 35, I = 53,
    
    pub fn valence(self: Element) u8 {
        return switch (self) {
            .H => 1, .C => 4, .N => 3, .O => 2, .F => 1,
            .P => 3, .S => 2, .Cl => 1, .Br => 1, .I => 1,
        };
    }
    
    pub fn mass(self: Element) f64 {
        return switch (self) {
            .H => 1.008, .C => 12.011, .N => 14.007, .O => 15.999, .F => 18.998,
            .P => 30.974, .S => 32.06, .Cl => 35.45, .Br => 79.904, .I => 126.90,
        };
    }
    
    pub fn electronegativity(self: Element) f64 {
        return switch (self) {
            .H => 2.20, .C => 2.55, .N => 3.04, .O => 3.44, .F => 3.98,
            .P => 2.19, .S => 2.58, .Cl => 3.16, .Br => 2.96, .I => 2.66,
        };
    }
};

pub const BondType = enum(u8) {
    Single = 1,
    Double = 2,
    Triple = 3,
    Aromatic = 4,
    
    pub fn order(self: BondType) f64 {
        return switch (self) {
            .Single => 1.0, .Double => 2.0, .Triple => 3.0, .Aromatic => 1.5,
        };
    }
};

pub const Atom = struct {
    element: Element,
    charge: i8 = 0,
    hydrogens: u8 = 0, // implicit H
};

pub const Bond = struct {
    from: u8,
    to: u8,
    bond_type: BondType,
};

pub const MolecularGraph = struct {
    atoms: [MAX_ATOMS]Atom = undefined,
    atom_count: u8 = 0,
    bonds: [MAX_ATOMS * 4]Bond = undefined,
    bond_count: u16 = 0,
    adj: [MAX_ATOMS][MAX_ATOMS]u8 = std.mem.zeroes([MAX_ATOMS][MAX_ATOMS]u8),
    
    pub fn addAtom(self: *MolecularGraph, element: Element) u8 {
        const idx = self.atom_count;
        self.atoms[idx] = .{ .element = element };
        self.atom_count += 1;
        return idx;
    }
    
    pub fn addBond(self: *MolecularGraph, from: u8, to: u8, bond_type: BondType) void {
        self.bonds[self.bond_count] = .{ .from = from, .to = to, .bond_type = bond_type };
        self.bond_count += 1;
        self.adj[from][to] = @intFromEnum(bond_type);
        self.adj[to][from] = @intFromEnum(bond_type);
    }
    
    // ═══ ТОПОЛОГИЧЕСКИЕ ИНДЕКСЫ ═══
    
    /// Индекс Винера — сумма кратчайших путей
    /// Коррелирует с температурой кипения
    pub fn wienerIndex(self: *const MolecularGraph) u32 {
        var dist: [MAX_ATOMS][MAX_ATOMS]u32 = undefined;
        const n = self.atom_count;
        
        // Floyd-Warshall
        for (0..n) |i| {
            for (0..n) |j| {
                if (i == j) {
                    dist[i][j] = 0;
                } else if (self.adj[i][j] > 0) {
                    dist[i][j] = 1;
                } else {
                    dist[i][j] = 10000;
                }
            }
        }
        
        for (0..n) |k| {
            for (0..n) |i| {
                for (0..n) |j| {
                    if (dist[i][k] + dist[k][j] < dist[i][j]) {
                        dist[i][j] = dist[i][k] + dist[k][j];
                    }
                }
            }
        }
        
        var sum: u32 = 0;
        for (0..n) |i| {
            for (i + 1..n) |j| {
                if (dist[i][j] < 10000) sum += dist[i][j];
            }
        }
        return sum;
    }
    
    /// Индекс связности Рандича
    /// Коррелирует с площадью поверхности
    pub fn randicIndex(self: *const MolecularGraph) f64 {
        var chi: f64 = 0;
        for (0..self.bond_count) |i| {
            const b = self.bonds[i];
            const deg_i = self.degree(b.from);
            const deg_j = self.degree(b.to);
            if (deg_i > 0 and deg_j > 0) {
                chi += 1.0 / @sqrt(@as(f64, @floatFromInt(deg_i * deg_j)));
            }
        }
        return chi;
    }
    
    /// Степень вершины (число связей)
    pub fn degree(self: *const MolecularGraph, atom: u8) u8 {
        var deg: u8 = 0;
        for (0..self.atom_count) |j| {
            if (self.adj[atom][j] > 0) deg += 1;
        }
        return deg;
    }
    
    /// Число циклов (cyclomatic complexity)
    pub fn cycleCount(self: *const MolecularGraph) i32 {
        // Эйлерова формула: V - E + F = 2, для связного графа: cycles = E - V + 1
        return @as(i32, self.bond_count) - @as(i32, self.atom_count) + 1;
    }
    
    /// Молекулярная масса
    pub fn molecularWeight(self: *const MolecularGraph) f64 {
        var mw: f64 = 0;
        for (0..self.atom_count) |i| {
            mw += self.atoms[i].element.mass();
            mw += @as(f64, @floatFromInt(self.atoms[i].hydrogens)) * 1.008;
        }
        return mw;
    }
    
    /// Полярность (сумма разностей электроотрицательностей)
    pub fn polarity(self: *const MolecularGraph) f64 {
        var pol: f64 = 0;
        for (0..self.bond_count) |i| {
            const b = self.bonds[i];
            const en1 = self.atoms[b.from].element.electronegativity();
            const en2 = self.atoms[b.to].element.electronegativity();
            pol += @abs(en1 - en2);
        }
        return pol;
    }
    
    // ═══ ПРЕДСКАЗАНИЕ СВОЙСТВ ═══
    
    /// Предсказание температуры кипения (°C)
    /// На основе индекса Винера
    pub fn predictBoilingPoint(self: *const MolecularGraph) f64 {
        const w = @as(f64, @floatFromInt(self.wienerIndex()));
        const mw = self.molecularWeight();
        // Эмпирическая формула для алканов
        return 30.0 + 5.5 * @sqrt(w) + 0.8 * mw;
    }
    
    /// Предсказание logP (липофильность)
    /// Положительный = жирорастворимый, отрицательный = водорастворимый
    pub fn predictLogP(self: *const MolecularGraph) f64 {
        var logp: f64 = 0;
        for (0..self.atom_count) |i| {
            logp += switch (self.atoms[i].element) {
                .C => 0.5,
                .H => 0.0,
                .O => -1.0,
                .N => -1.0,
                .F => 0.4,
                .Cl => 0.9,
                .Br => 1.1,
                .S => 0.6,
                else => 0.0,
            };
        }
        // Коррекция на циклы (ароматика более липофильна)
        const cycles = self.cycleCount();
        if (cycles > 0) logp += @as(f64, @floatFromInt(cycles)) * 0.3;
        return logp;
    }
    
    /// Предсказание токсичности (упрощённое)
    /// Возвращает оценку риска 0-10
    pub fn predictToxicity(self: *const MolecularGraph) f64 {
        var risk: f64 = 0;
        
        // Галогены увеличивают токсичность
        for (0..self.atom_count) |i| {
            risk += switch (self.atoms[i].element) {
                .F => 0.5, .Cl => 1.0, .Br => 1.5, .I => 2.0,
                else => 0.0,
            };
        }
        
        // Высокая липофильность = биоаккумуляция
        const logp = self.predictLogP();
        if (logp > 3.0) risk += (logp - 3.0) * 0.5;
        
        return @min(risk, 10.0);
    }
    
    /// Центральность атома (betweenness) — реакционные центры
    pub fn atomCentrality(self: *const MolecularGraph, atom: u8) f64 {
        const n = self.atom_count;
        if (n < 3) return 0;
        
        // Упрощённая центральность: степень / макс_степень
        const deg = @as(f64, @floatFromInt(self.degree(atom)));
        var max_deg: u8 = 1;
        for (0..n) |i| {
            const d = self.degree(@intCast(i));
            if (d > max_deg) max_deg = d;
        }
        return deg / @as(f64, @floatFromInt(max_deg));
    }
    
    /// Найти реакционный центр (атом с макс центральностью)
    pub fn findReactiveCenter(self: *const MolecularGraph) u8 {
        var max_c: f64 = 0;
        var center: u8 = 0;
        for (0..self.atom_count) |i| {
            const c = self.atomCentrality(@intCast(i));
            if (c > max_c) {
                max_c = c;
                center = @intCast(i);
            }
        }
        return center;
    }
    
    /// Предсказание реакционной способности
    pub fn predictReactivity(self: *const MolecularGraph) f64 {
        var react: f64 = 0;
        
        // Ненасыщенность увеличивает реакционность
        for (0..self.bond_count) |i| {
            react += switch (self.bonds[i].bond_type) {
                .Double => 1.0, .Triple => 2.0, else => 0.0,
            };
        }
        
        // Полярные связи более реакционноспособны
        react += self.polarity() * 0.2;
        
        return react;
    }
};

// ═══ КОНСТРУКТОРЫ МОЛЕКУЛ ═══

pub fn methane() MolecularGraph {
    var mol = MolecularGraph{};
    const c = mol.addAtom(.C);
    mol.atoms[c].hydrogens = 4;
    return mol;
}

pub fn ethane() MolecularGraph {
    var mol = MolecularGraph{};
    const c1 = mol.addAtom(.C);
    const c2 = mol.addAtom(.C);
    mol.addBond(c1, c2, .Single);
    mol.atoms[c1].hydrogens = 3;
    mol.atoms[c2].hydrogens = 3;
    return mol;
}

pub fn benzene() MolecularGraph {
    var mol = MolecularGraph{};
    var carbons: [6]u8 = undefined;
    for (0..6) |i| {
        carbons[i] = mol.addAtom(.C);
        mol.atoms[carbons[i]].hydrogens = 1;
    }
    for (0..6) |i| {
        mol.addBond(carbons[i], carbons[(i + 1) % 6], .Aromatic);
    }
    return mol;
}

pub fn water() MolecularGraph {
    var mol = MolecularGraph{};
    const o = mol.addAtom(.O);
    const h1 = mol.addAtom(.H);
    const h2 = mol.addAtom(.H);
    mol.addBond(o, h1, .Single);
    mol.addBond(o, h2, .Single);
    return mol;
}

pub fn ethanol() MolecularGraph {
    var mol = MolecularGraph{};
    const c1 = mol.addAtom(.C);
    const c2 = mol.addAtom(.C);
    const o = mol.addAtom(.O);
    mol.addBond(c1, c2, .Single);
    mol.addBond(c2, o, .Single);
    mol.atoms[c1].hydrogens = 3;
    mol.atoms[c2].hydrogens = 2;
    mol.atoms[o].hydrogens = 1;
    return mol;
}

// ═══ ТЕСТЫ ═══

test "methane properties" {
    const mol = methane();
    try std.testing.expectEqual(@as(u8, 1), mol.atom_count);
    const mw = mol.molecularWeight();
    try std.testing.expect(mw > 16.0 and mw < 16.1);
}

test "benzene cycles" {
    const mol = benzene();
    try std.testing.expectEqual(@as(i32, 1), mol.cycleCount());
}

test "wiener index" {
    const mol = ethane();
    const w = mol.wienerIndex();
    try std.testing.expectEqual(@as(u32, 1), w);
}

test "polarity" {
    const h2o = water();
    const eth = ethane();
    try std.testing.expect(h2o.polarity() > eth.polarity());
}

// ═══ MAIN ═══

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("{s}\n", .{
        \\╔═══════════════════════════════════════════════════════════╗
        \\║          MOLECULAR GRAPH ANALYSIS                        ║
        \\║          Граф → Алгоритм → Свойство                      ║
        \\╚═══════════════════════════════════════════════════════════╝
    });
    
    const molecules = [_]struct { name: []const u8, mol: MolecularGraph }{
        .{ .name = "Methane (CH4)", .mol = methane() },
        .{ .name = "Ethane (C2H6)", .mol = ethane() },
        .{ .name = "Benzene (C6H6)", .mol = benzene() },
        .{ .name = "Water (H2O)", .mol = water() },
        .{ .name = "Ethanol (C2H5OH)", .mol = ethanol() },
    };
    
    try stdout.print("\n═══ ТОПОЛОГИЧЕСКИЕ ИНДЕКСЫ ═══\n\n", .{});
    try stdout.print("{s:<20} {s:>8} {s:>8} {s:>8} {s:>8}\n", .{
        "Molecule", "Wiener", "Randic", "Cycles", "MW",
    });
    try stdout.print("{s}\n", .{"-" ** 56});
    
    for (molecules) |m| {
        try stdout.print("{s:<20} {d:>8} {d:>8.2} {d:>8} {d:>8.1}\n", .{
            m.name,
            m.mol.wienerIndex(),
            m.mol.randicIndex(),
            m.mol.cycleCount(),
            m.mol.molecularWeight(),
        });
    }
    
    try stdout.print("\n═══ ПРЕДСКАЗАНИЕ СВОЙСТВ ═══\n\n", .{});
    try stdout.print("{s:<20} {s:>10} {s:>8} {s:>10} {s:>10}\n", .{
        "Molecule", "BP (°C)", "logP", "Toxicity", "Reactivity",
    });
    try stdout.print("{s}\n", .{"-" ** 62});
    
    for (molecules) |m| {
        try stdout.print("{s:<20} {d:>10.1} {d:>8.2} {d:>10.1} {d:>10.1}\n", .{
            m.name,
            m.mol.predictBoilingPoint(),
            m.mol.predictLogP(),
            m.mol.predictToxicity(),
            m.mol.predictReactivity(),
        });
    }
    
    try stdout.print("\n═══ ИНТЕРПРЕТАЦИЯ ═══\n\n", .{});
    try stdout.print("Wiener Index → Температура кипения (больше = выше)\n", .{});
    try stdout.print("Randic Index → Площадь поверхности\n", .{});
    try stdout.print("logP > 0 → Жирорастворимый (липофильный)\n", .{});
    try stdout.print("logP < 0 → Водорастворимый (гидрофильный)\n", .{});
    try stdout.print("Toxicity → Риск биоаккумуляции\n", .{});
    
    try stdout.print("\n✅ Граф-алгоритмы предсказывают химические свойства\n", .{});
}
