// ═══════════════════════════════════════════════════════════════════════════════
// MULTILANG CODEGEN - Multi-Language Code Generator for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS: D&C + PRE | φ² + 1/φ² = 3
// Targets: Zig, Python, Go, Rust, TypeScript, Gleam, C, Java, Kotlin, Swift
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// LANGUAGE ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Language = enum {
    zig,
    python,
    go,
    rust,
    typescript,
    gleam,
    c,
    java,
    kotlin,
    swift,

    pub fn extension(self: Language) []const u8 {
        return switch (self) {
            .zig => ".zig",
            .python => ".py",
            .go => ".go",
            .rust => ".rs",
            .typescript => ".ts",
            .gleam => ".gleam",
            .c => ".c",
            .java => ".java",
            .kotlin => ".kt",
            .swift => ".swift",
        };
    }

    pub fn name(self: Language) []const u8 {
        return switch (self) {
            .zig => "Zig",
            .python => "Python",
            .go => "Go",
            .rust => "Rust",
            .typescript => "TypeScript",
            .gleam => "Gleam",
            .c => "C",
            .java => "Java",
            .kotlin => "Kotlin",
            .swift => "Swift",
        };
    }

    pub fn commentPrefix(self: Language) []const u8 {
        return switch (self) {
            .zig, .go, .rust, .typescript, .c, .java, .kotlin, .swift => "//",
            .python, .gleam => "#",
        };
    }

    pub fn testFramework(self: Language) []const u8 {
        return switch (self) {
            .zig => "std.testing",
            .python => "pytest",
            .go => "testing",
            .rust => "#[test]",
            .typescript => "jest",
            .gleam => "gleeunit",
            .c => "assert.h",
            .java => "JUnit",
            .kotlin => "kotlin.test",
            .swift => "XCTest",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPINGS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeMapper = struct {
    pub fn mapType(vibee_type: []const u8, lang: Language) []const u8 {
        // String type
        if (mem.eql(u8, vibee_type, "String")) {
            return switch (lang) {
                .zig => "[]const u8",
                .python => "str",
                .go => "string",
                .rust => "String",
                .typescript => "string",
                .gleam => "String",
                .c => "char*",
                .java => "String",
                .kotlin => "String",
                .swift => "String",
            };
        }
        // Int type
        if (mem.eql(u8, vibee_type, "Int")) {
            return switch (lang) {
                .zig => "i64",
                .python => "int",
                .go => "int64",
                .rust => "i64",
                .typescript => "number",
                .gleam => "Int",
                .c => "int64_t",
                .java => "long",
                .kotlin => "Long",
                .swift => "Int64",
            };
        }
        // Float type
        if (mem.eql(u8, vibee_type, "Float")) {
            return switch (lang) {
                .zig => "f64",
                .python => "float",
                .go => "float64",
                .rust => "f64",
                .typescript => "number",
                .gleam => "Float",
                .c => "double",
                .java => "double",
                .kotlin => "Double",
                .swift => "Double",
            };
        }
        // Bool type
        if (mem.eql(u8, vibee_type, "Bool")) {
            return switch (lang) {
                .zig => "bool",
                .python => "bool",
                .go => "bool",
                .rust => "bool",
                .typescript => "boolean",
                .gleam => "Bool",
                .c => "bool",
                .java => "boolean",
                .kotlin => "Boolean",
                .swift => "Bool",
            };
        }
        return vibee_type;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Templates = struct {
    pub fn goldenIdentity(lang: Language) []const u8 {
        return switch (lang) {
            .zig =>
                \\pub const PHI: f64 = 1.618033988749895;
                \\pub fn goldenIdentity() f64 {
                \\    const phi_sq = PHI * PHI;
                \\    const inv_phi_sq = 1.0 / phi_sq;
                \\    return phi_sq + inv_phi_sq; // = 3.0
                \\}
            ,
            .python =>
                \\PHI = 1.618033988749895
                \\def golden_identity():
                \\    phi_sq = PHI ** 2
                \\    inv_phi_sq = 1 / phi_sq
                \\    return phi_sq + inv_phi_sq  # = 3.0
            ,
            .go =>
                \\const PHI float64 = 1.618033988749895
                \\func GoldenIdentity() float64 {
                \\    phiSq := PHI * PHI
                \\    invPhiSq := 1.0 / phiSq
                \\    return phiSq + invPhiSq // = 3.0
                \\}
            ,
            .rust =>
                \\pub const PHI: f64 = 1.618033988749895;
                \\pub fn golden_identity() -> f64 {
                \\    let phi_sq = PHI * PHI;
                \\    let inv_phi_sq = 1.0 / phi_sq;
                \\    phi_sq + inv_phi_sq // = 3.0
                \\}
            ,
            .typescript =>
                \\export const PHI = 1.618033988749895;
                \\export function goldenIdentity(): number {
                \\    const phiSq = PHI * PHI;
                \\    const invPhiSq = 1 / phiSq;
                \\    return phiSq + invPhiSq; // = 3.0
                \\}
            ,
            .gleam =>
                \\pub const phi = 1.618033988749895
                \\pub fn golden_identity() -> Float {
                \\  let phi_sq = phi *. phi
                \\  let inv_phi_sq = 1.0 /. phi_sq
                \\  phi_sq +. inv_phi_sq // = 3.0
                \\}
            ,
            else => "// Not implemented",
        };
    }

    pub fn testTemplate(lang: Language) []const u8 {
        return switch (lang) {
            .zig =>
                \\test "golden identity" {
                \\    const result = goldenIdentity();
                \\    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
                \\}
            ,
            .python =>
                \\def test_golden_identity():
                \\    result = golden_identity()
                \\    assert abs(result - 3.0) < 0.0001
            ,
            .go =>
                \\func TestGoldenIdentity(t *testing.T) {
                \\    result := GoldenIdentity()
                \\    if math.Abs(result - 3.0) > 0.0001 {
                \\        t.Errorf("Expected 3.0, got %f", result)
                \\    }
                \\}
            ,
            .rust =>
                \\#[test]
                \\fn test_golden_identity() {
                \\    let result = golden_identity();
                \\    assert!((result - 3.0).abs() < 0.0001);
                \\}
            ,
            .typescript =>
                \\test('golden identity', () => {
                \\    const result = goldenIdentity();
                \\    expect(Math.abs(result - 3.0)).toBeLessThan(0.0001);
                \\});
            ,
            else => "// Test not implemented",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeGenerator = struct {
    target: Language,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, target: Language) Self {
        return Self{
            .target = target,
            .allocator = allocator,
        };
    }

    pub fn getExtension(self: *const Self) []const u8 {
        return self.target.extension();
    }

    pub fn getLanguageName(self: *const Self) []const u8 {
        return self.target.name();
    }

    pub fn mapType(self: *const Self, vibee_type: []const u8) []const u8 {
        return TypeMapper.mapType(vibee_type, self.target);
    }

    pub fn generateHeader(self: *const Self) []const u8 {
        const comment = self.target.commentPrefix();
        _ = comment;
        return switch (self.target) {
            .zig => "const std = @import(\"std\");\n",
            .python => "#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n",
            .go => "package main\n\nimport \"math\"\n",
            .rust => "// Generated by VIBEE\n",
            .typescript => "// Generated by VIBEE\n",
            else => "",
        };
    }

    pub fn supportedLanguages() [10]Language {
        return [10]Language{
            .zig, .python, .go, .rust, .typescript,
            .gleam, .c, .java, .kotlin, .swift,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Language extensions" {
    try std.testing.expectEqualStrings(".zig", Language.zig.extension());
    try std.testing.expectEqualStrings(".py", Language.python.extension());
    try std.testing.expectEqualStrings(".go", Language.go.extension());
    try std.testing.expectEqualStrings(".rs", Language.rust.extension());
    try std.testing.expectEqualStrings(".ts", Language.typescript.extension());
}

test "Language names" {
    try std.testing.expectEqualStrings("Zig", Language.zig.name());
    try std.testing.expectEqualStrings("Python", Language.python.name());
    try std.testing.expectEqualStrings("Go", Language.go.name());
    try std.testing.expectEqualStrings("Rust", Language.rust.name());
}

test "Type mapping String" {
    try std.testing.expectEqualStrings("[]const u8", TypeMapper.mapType("String", .zig));
    try std.testing.expectEqualStrings("str", TypeMapper.mapType("String", .python));
    try std.testing.expectEqualStrings("string", TypeMapper.mapType("String", .go));
    try std.testing.expectEqualStrings("String", TypeMapper.mapType("String", .rust));
}

test "Type mapping Int" {
    try std.testing.expectEqualStrings("i64", TypeMapper.mapType("Int", .zig));
    try std.testing.expectEqualStrings("int", TypeMapper.mapType("Int", .python));
    try std.testing.expectEqualStrings("int64", TypeMapper.mapType("Int", .go));
    try std.testing.expectEqualStrings("i64", TypeMapper.mapType("Int", .rust));
}

test "Type mapping Float" {
    try std.testing.expectEqualStrings("f64", TypeMapper.mapType("Float", .zig));
    try std.testing.expectEqualStrings("float", TypeMapper.mapType("Float", .python));
    try std.testing.expectEqualStrings("float64", TypeMapper.mapType("Float", .go));
}

test "Type mapping Bool" {
    try std.testing.expectEqualStrings("bool", TypeMapper.mapType("Bool", .zig));
    try std.testing.expectEqualStrings("bool", TypeMapper.mapType("Bool", .python));
    try std.testing.expectEqualStrings("boolean", TypeMapper.mapType("Bool", .typescript));
}

test "CodeGenerator init" {
    const allocator = std.testing.allocator;
    const gen = CodeGenerator.init(allocator, .python);
    
    try std.testing.expectEqualStrings(".py", gen.getExtension());
    try std.testing.expectEqualStrings("Python", gen.getLanguageName());
}

test "Supported languages count" {
    const langs = CodeGenerator.supportedLanguages();
    try std.testing.expectEqual(@as(usize, 10), langs.len);
}

test "Comment prefixes" {
    try std.testing.expectEqualStrings("//", Language.zig.commentPrefix());
    try std.testing.expectEqualStrings("#", Language.python.commentPrefix());
    try std.testing.expectEqualStrings("//", Language.go.commentPrefix());
}

test "Test frameworks" {
    try std.testing.expectEqualStrings("std.testing", Language.zig.testFramework());
    try std.testing.expectEqualStrings("pytest", Language.python.testFramework());
    try std.testing.expectEqualStrings("testing", Language.go.testFramework());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
