// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-LANGUAGE CODEGEN - Генератор кода для всех языков
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует код для 39 языков из .vibee спецификаций
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getAllLanguages() []const []const u8 {
    return &[_][]const u8{
        "zig", "python", "rust", "go", "typescript", "wasm",
        "java", "kotlin", "swift", "c", "csharp",
        "ruby", "php", "lua", "perl", "r",
        "haskell", "ocaml", "elixir", "erlang", "fsharp", "scala", "clojure",
        "d", "nim", "crystal", "julia", "odin", "jai", "vlang",
        "ada", "fortran", "cobol", "pascal", "objc",
        "groovy", "dart",
        "racket", "scheme", "commonlisp",
        "prolog", "gleam",
    };
}

pub fn getExtension(lang_name: []const u8) []const u8 {
    const extensions = std.StaticStringMap([]const u8).initComptime(.{
        .{ "zig", "zig" },
        .{ "python", "py" },
        .{ "rust", "rs" },
        .{ "go", "go" },
        .{ "typescript", "ts" },
        .{ "wasm", "wat" },
        .{ "java", "java" },
        .{ "kotlin", "kt" },
        .{ "swift", "swift" },
        .{ "c", "h" },
        .{ "csharp", "cs" },
        .{ "ruby", "rb" },
        .{ "php", "php" },
        .{ "lua", "lua" },
        .{ "perl", "pl" },
        .{ "r", "R" },
        .{ "haskell", "hs" },
        .{ "ocaml", "ml" },
        .{ "elixir", "ex" },
        .{ "erlang", "erl" },
        .{ "fsharp", "fs" },
        .{ "scala", "scala" },
        .{ "clojure", "clj" },
        .{ "d", "d" },
        .{ "nim", "nim" },
        .{ "crystal", "cr" },
        .{ "julia", "jl" },
        .{ "odin", "odin" },
        .{ "jai", "jai" },
        .{ "vlang", "v" },
        .{ "ada", "adb" },
        .{ "fortran", "f90" },
        .{ "cobol", "cob" },
        .{ "pascal", "pas" },
        .{ "objc", "m" },
        .{ "groovy", "groovy" },
        .{ "dart", "dart" },
        .{ "racket", "rkt" },
        .{ "scheme", "scm" },
        .{ "commonlisp", "lisp" },
        .{ "prolog", "pl" },
        .{ "gleam", "gleam" },
    });
    return extensions.get(lang_name) orelse "txt";
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUPPORTED LANGUAGES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Language = enum {
    // Systems
    zig,
    c,
    rust,
    d_lang,
    nim,
    crystal,
    odin,
    jai,
    v_lang,
    
    // JVM/CLR
    java,
    kotlin,
    scala,
    clojure,
    groovy,
    fsharp,
    
    // Scripting
    python,
    ruby,
    php,
    lua,
    perl,
    dart,
    
    // Functional
    haskell,
    ocaml,
    elixir,
    erlang,
    scheme,
    racket,
    common_lisp,
    
    // Scientific
    julia,
    r_lang,
    fortran,
    
    // Classic
    ada,
    cobol,
    pascal,
    objc,
    prolog,
    
    // Other
    go,
    swift,
    wasm,
    gleam,
    
    pub fn extension(self: Language) []const u8 {
        return switch (self) {
            .zig => ".zig",
            .c => ".h",
            .rust => ".rs",
            .d_lang => ".d",
            .nim => ".nim",
            .crystal => ".cr",
            .odin => ".odin",
            .jai => ".jai",
            .v_lang => ".v",
            .java => ".java",
            .kotlin => ".kt",
            .scala => ".scala",
            .clojure => ".clj",
            .groovy => ".groovy",
            .fsharp => ".fs",
            .python => ".py",
            .ruby => ".rb",
            .php => ".php",
            .lua => ".lua",
            .perl => ".pl",
            .dart => ".dart",
            .haskell => ".hs",
            .ocaml => ".ml",
            .elixir => ".ex",
            .erlang => ".erl",
            .scheme => ".scm",
            .racket => ".rkt",
            .common_lisp => ".lisp",
            .julia => ".jl",
            .r_lang => ".R",
            .fortran => ".f90",
            .ada => ".adb",
            .cobol => ".cob",
            .pascal => ".pas",
            .objc => ".m",
            .prolog => ".pl",
            .go => ".go",
            .swift => ".swift",
            .wasm => ".wat",
            .gleam => ".gleam",
        };
    }
    
    pub fn name(self: Language) []const u8 {
        return switch (self) {
            .zig => "Zig",
            .c => "C",
            .rust => "Rust",
            .d_lang => "D",
            .nim => "Nim",
            .crystal => "Crystal",
            .odin => "Odin",
            .jai => "Jai",
            .v_lang => "V",
            .java => "Java",
            .kotlin => "Kotlin",
            .scala => "Scala",
            .clojure => "Clojure",
            .groovy => "Groovy",
            .fsharp => "F#",
            .python => "Python",
            .ruby => "Ruby",
            .php => "PHP",
            .lua => "Lua",
            .perl => "Perl",
            .dart => "Dart",
            .haskell => "Haskell",
            .ocaml => "OCaml",
            .elixir => "Elixir",
            .erlang => "Erlang",
            .scheme => "Scheme",
            .racket => "Racket",
            .common_lisp => "Common Lisp",
            .julia => "Julia",
            .r_lang => "R",
            .fortran => "Fortran",
            .ada => "Ada",
            .cobol => "COBOL",
            .pascal => "Pascal",
            .objc => "Objective-C",
            .prolog => "Prolog",
            .go => "Go",
            .swift => "Swift",
            .wasm => "WebAssembly",
            .gleam => "Gleam",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeMapper = struct {
    pub fn mapType(vibee_type: []const u8, lang: Language) []const u8 {
        // String
        if (std.mem.eql(u8, vibee_type, "String")) {
            return switch (lang) {
                .zig => "[]const u8",
                .c => "const char*",
                .rust => "&str",
                .python => "str",
                .java => "String",
                .go => "string",
                .swift => "String",
                .kotlin => "String",
                .haskell => "String",
                .ocaml => "string",
                .julia => "String",
                .ruby => "String",
                .php => "string",
                .lua => "string",
                .perl => "string",
                .d_lang => "string",
                .nim => "string",
                .crystal => "String",
                .scala => "String",
                .fsharp => "string",
                .clojure => "String",
                .erlang => "binary()",
                .elixir => "String.t()",
                .fortran => "CHARACTER(*)",
                .ada => "String",
                .cobol => "PIC X",
                .pascal => "string",
                .r_lang => "character",
                .dart => "String",
                .v_lang => "string",
                .odin => "string",
                .jai => "string",
                .scheme => "string",
                .racket => "string?",
                .common_lisp => "string",
                .prolog => "atom",
                .objc => "NSString*",
                .groovy => "String",
                .wasm => "i32",
                .gleam => "String",
            };
        }
        
        // Int
        if (std.mem.eql(u8, vibee_type, "Int")) {
            return switch (lang) {
                .zig => "i64",
                .c => "int64_t",
                .rust => "i64",
                .python => "int",
                .java => "long",
                .go => "int64",
                .swift => "Int64",
                .kotlin => "Long",
                .haskell => "Int64",
                .ocaml => "int64",
                .julia => "Int64",
                .ruby => "Integer",
                .php => "int",
                .lua => "integer",
                .perl => "int",
                .d_lang => "long",
                .nim => "int64",
                .crystal => "Int64",
                .scala => "Long",
                .fsharp => "int64",
                .clojure => "Long",
                .erlang => "integer()",
                .elixir => "integer()",
                .fortran => "INTEGER(8)",
                .ada => "Long_Long_Integer",
                .cobol => "PIC 9(18)",
                .pascal => "Int64",
                .r_lang => "integer",
                .dart => "int",
                .v_lang => "i64",
                .odin => "i64",
                .jai => "s64",
                .scheme => "integer",
                .racket => "exact-integer?",
                .common_lisp => "integer",
                .prolog => "integer",
                .objc => "NSInteger",
                .groovy => "Long",
                .wasm => "i64",
                .gleam => "Int",
            };
        }
        
        // Float
        if (std.mem.eql(u8, vibee_type, "Float")) {
            return switch (lang) {
                .zig => "f64",
                .c => "double",
                .rust => "f64",
                .python => "float",
                .java => "double",
                .go => "float64",
                .swift => "Double",
                .kotlin => "Double",
                .haskell => "Double",
                .ocaml => "float",
                .julia => "Float64",
                .ruby => "Float",
                .php => "float",
                .lua => "number",
                .perl => "float",
                .d_lang => "double",
                .nim => "float64",
                .crystal => "Float64",
                .scala => "Double",
                .fsharp => "float",
                .clojure => "Double",
                .erlang => "float()",
                .elixir => "float()",
                .fortran => "REAL(8)",
                .ada => "Long_Float",
                .cobol => "PIC 9(18)V9(4)",
                .pascal => "Double",
                .r_lang => "numeric",
                .dart => "double",
                .v_lang => "f64",
                .odin => "f64",
                .jai => "float64",
                .scheme => "real",
                .racket => "flonum?",
                .common_lisp => "double-float",
                .prolog => "float",
                .objc => "double",
                .groovy => "Double",
                .wasm => "f64",
                .gleam => "Float",
            };
        }
        
        // Bool
        if (std.mem.eql(u8, vibee_type, "Bool")) {
            return switch (lang) {
                .zig => "bool",
                .c => "bool",
                .rust => "bool",
                .python => "bool",
                .java => "boolean",
                .go => "bool",
                .swift => "Bool",
                .kotlin => "Boolean",
                .haskell => "Bool",
                .ocaml => "bool",
                .julia => "Bool",
                .ruby => "TrueClass | FalseClass",
                .php => "bool",
                .lua => "boolean",
                .perl => "bool",
                .d_lang => "bool",
                .nim => "bool",
                .crystal => "Bool",
                .scala => "Boolean",
                .fsharp => "bool",
                .clojure => "Boolean",
                .erlang => "boolean()",
                .elixir => "boolean()",
                .fortran => "LOGICAL",
                .ada => "Boolean",
                .cobol => "PIC 9",
                .pascal => "Boolean",
                .r_lang => "logical",
                .dart => "bool",
                .v_lang => "bool",
                .odin => "bool",
                .jai => "bool",
                .scheme => "boolean",
                .racket => "boolean?",
                .common_lisp => "boolean",
                .prolog => "bool",
                .objc => "BOOL",
                .groovy => "Boolean",
                .wasm => "i32",
                .gleam => "Bool",
            };
        }
        
        // Default - return as-is
        return vibee_type;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE GENERATORS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MultiLangCodegen = struct {
    allocator: Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator };
    }
    
    pub fn generateAll(self: *Self, spec_name: []const u8, types: []const TypeDef, behaviors: []const Behavior, output_dir: []const u8) !void {
        const languages = [_]Language{
            .zig, .c, .rust, .python, .java, .go, .swift, .kotlin,
            .haskell, .ocaml, .julia, .ruby, .php, .lua,
            .d_lang, .nim, .crystal, .scala, .fsharp, .clojure,
            .erlang, .elixir, .fortran, .ada, .cobol, .pascal,
            .r_lang, .dart, .v_lang, .odin, .scheme, .racket,
            .common_lisp, .prolog, .objc, .groovy, .gleam,
        };
        
        for (languages) |lang| {
            try self.generateForLanguage(spec_name, types, behaviors, output_dir, lang);
        }
    }
    
    pub fn generateForLanguage(self: *Self, spec_name: []const u8, types: []const TypeDef, behaviors: []const Behavior, output_dir: []const u8, lang: Language) !void {
        _ = self;
        _ = spec_name;
        _ = types;
        _ = behaviors;
        _ = output_dir;
        _ = lang;
        // Implementation would go here
    }
    
    const TypeDef = struct {
        name: []const u8,
        fields: []const Field,
    };
    
    const Field = struct {
        name: []const u8,
        type_name: []const u8,
    };
    
    const Behavior = struct {
        name: []const u8,
        given: []const u8,
        when: []const u8,
        then: []const u8,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "type mapping for all languages" {
    const langs = [_]Language{ .zig, .c, .rust, .python, .java, .go };
    
    for (langs) |lang| {
        const str_type = TypeMapper.mapType("String", lang);
        try std.testing.expect(str_type.len > 0);
        
        const int_type = TypeMapper.mapType("Int", lang);
        try std.testing.expect(int_type.len > 0);
        
        const float_type = TypeMapper.mapType("Float", lang);
        try std.testing.expect(float_type.len > 0);
        
        const bool_type = TypeMapper.mapType("Bool", lang);
        try std.testing.expect(bool_type.len > 0);
    }
}

test "language extensions" {
    try std.testing.expectEqualStrings(".zig", Language.zig.extension());
    try std.testing.expectEqualStrings(".py", Language.python.extension());
    try std.testing.expectEqualStrings(".rs", Language.rust.extension());
    try std.testing.expectEqualStrings(".java", Language.java.extension());
    try std.testing.expectEqualStrings(".go", Language.go.extension());
}

test "language names" {
    try std.testing.expectEqualStrings("Zig", Language.zig.name());
    try std.testing.expectEqualStrings("Python", Language.python.name());
    try std.testing.expectEqualStrings("Rust", Language.rust.name());
    try std.testing.expectEqualStrings("Java", Language.java.name());
}
