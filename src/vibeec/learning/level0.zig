// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL 0: FOUNDATIONS - Zig, YAML, Git
// ═══════════════════════════════════════════════════════════════════════════════
//
// Prerequisites for VIBEE development
// Time: 2-4 weeks
//
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG BASICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Example: Hello World
pub fn helloWorld() void {
    std.debug.print("Hello VIBEE!\n", .{});
}

/// Example: Variables and Types
pub fn variablesExample() void {
    const x: i32 = 42;
    const y: f64 = PHI;
    var z: u32 = PHOENIX;
    z += 1;

    std.debug.print("x={}, y={d:.6}, z={}\n", .{ x, y, z });
}

/// Example: Functions
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

/// Example: Error Handling
pub const MathError = error{
    DivisionByZero,
    Overflow,
};

pub fn divide(a: i32, b: i32) MathError!i32 {
    if (b == 0) return MathError.DivisionByZero;
    return @divTrunc(a, b);
}

/// Example: Structs
pub const Point = struct {
    x: f64,
    y: f64,

    pub fn distance(self: Point, other: Point) f64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// Example: Arrays and Slices
pub fn sumArray(arr: []const i32) i32 {
    var sum: i32 = 0;
    for (arr) |val| {
        sum += val;
    }
    return sum;
}

/// Example: Fibonacci (recursive)
pub fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

/// Example: Fibonacci (iterative)
pub fn fibonacciIterative(n: u32) u64 {
    if (n <= 1) return n;

    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;

    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }

    return b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SKILL ASSESSMENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZigSkill = struct {
    syntax_knowledge: u32,
    memory_management: u32,
    testing_ability: u32,
    error_handling: u32,

    pub fn total(self: ZigSkill) u32 {
        return self.syntax_knowledge + self.memory_management +
            self.testing_ability + self.error_handling;
    }

    pub fn passed(self: ZigSkill) bool {
        return self.total() >= 280; // 70% of 400
    }
};

pub const YamlSkill = struct {
    basic_syntax: u32,
    nested_structures: u32,
    lists_and_maps: u32,

    pub fn total(self: YamlSkill) u32 {
        return self.basic_syntax + self.nested_structures + self.lists_and_maps;
    }

    pub fn passed(self: YamlSkill) bool {
        return self.total() >= 210; // 70% of 300
    }
};

pub const GitSkill = struct {
    basic_commands: u32,
    branching: u32,
    hooks: u32,

    pub fn total(self: GitSkill) u32 {
        return self.basic_commands + self.branching + self.hooks;
    }

    pub fn passed(self: GitSkill) bool {
        return self.total() >= 210; // 70% of 300
    }
};

pub const FoundationLevel = struct {
    zig: ZigSkill,
    yaml: YamlSkill,
    git: GitSkill,

    pub fn totalScore(self: FoundationLevel) u32 {
        return self.zig.total() + self.yaml.total() + self.git.total();
    }

    pub fn passed(self: FoundationLevel) bool {
        return self.zig.passed() and self.yaml.passed() and self.git.passed();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "add function" {
    try testing.expectEqual(@as(i32, 5), add(2, 3));
    try testing.expectEqual(@as(i32, 0), add(-1, 1));
}

test "multiply function" {
    try testing.expectApproxEqAbs(@as(f64, 6.0), multiply(2.0, 3.0), 0.0001);
    try testing.expectApproxEqAbs(PHI * PHI, multiply(PHI, PHI), 0.0001);
}

test "divide function" {
    try testing.expectEqual(@as(i32, 5), try divide(10, 2));
    try testing.expectError(MathError.DivisionByZero, divide(10, 0));
}

test "Point distance" {
    const p1 = Point{ .x = 0, .y = 0 };
    const p2 = Point{ .x = 3, .y = 4 };
    try testing.expectApproxEqAbs(@as(f64, 5.0), p1.distance(p2), 0.0001);
}

test "sumArray" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(i32, 15), sumArray(&arr));
}

test "fibonacci" {
    try testing.expectEqual(@as(u64, 0), fibonacci(0));
    try testing.expectEqual(@as(u64, 1), fibonacci(1));
    try testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "fibonacciIterative" {
    try testing.expectEqual(@as(u64, 0), fibonacciIterative(0));
    try testing.expectEqual(@as(u64, 1), fibonacciIterative(1));
    try testing.expectEqual(@as(u64, 55), fibonacciIterative(10));
    try testing.expectEqual(fibonacci(15), fibonacciIterative(15));
}

test "ZigSkill assessment" {
    const skill = ZigSkill{
        .syntax_knowledge = 80,
        .memory_management = 75,
        .testing_ability = 85,
        .error_handling = 70,
    };
    try testing.expectEqual(@as(u32, 310), skill.total());
    try testing.expect(skill.passed());
}

test "FoundationLevel assessment" {
    const level = FoundationLevel{
        .zig = ZigSkill{
            .syntax_knowledge = 80,
            .memory_management = 75,
            .testing_ability = 85,
            .error_handling = 70,
        },
        .yaml = YamlSkill{
            .basic_syntax = 90,
            .nested_structures = 80,
            .lists_and_maps = 85,
        },
        .git = GitSkill{
            .basic_commands = 95,
            .branching = 80,
            .hooks = 70,
        },
    };

    try testing.expect(level.passed());
    try testing.expect(level.totalScore() >= 700);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const result = phi_sq + phi_inv_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
