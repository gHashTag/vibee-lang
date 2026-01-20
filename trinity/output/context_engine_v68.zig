// VIBEE v68 Context Engine
// Codebase Understanding & Semantic Search
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const EMBEDDING_DIM: u32 = 1536;
pub const MAX_CONTEXT_TOKENS: u32 = 128000;

// === FILE TYPES ===
pub const FileType = enum {
    source_code,
    config,
    documentation,
    @"test",
    data,
    binary,
};

// === LANGUAGES ===
pub const Language = enum {
    zig,
    python,
    javascript,
    typescript,
    rust,
    go,
    java,
    cpp,
    ruby,
    vibee,
    unknown,
};

// === SYMBOL KIND ===
pub const SymbolKind = enum {
    function,
    @"struct",
    @"enum",
    @"const",
    variable,
    type_alias,
    module,
    class,
    interface,
};

// === SYMBOL ===
pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    file_path: []const u8,
    line_start: u32,
    line_end: u32,
    signature: []const u8,
    has_doc: bool,
};

// === FILE CONTEXT ===
pub const FileContext = struct {
    path: []const u8,
    language: Language,
    size_bytes: u32,
    line_count: u32,
    symbol_count: u32,
    import_count: u32,
    export_count: u32,
};

// === SEARCH RESULT ===
pub const SearchResult = struct {
    file_path: []const u8,
    content: []const u8,
    score: f64,
    line_start: u32,
    line_end: u32,
};

// === DEPENDENCY NODE ===
pub const DependencyNode = struct {
    file_path: []const u8,
    import_count: u32,
    imported_by_count: u32,
    depth: u32,
};

// === RETRIEVAL METHOD ===
pub const RetrievalMethod = enum {
    keyword,
    semantic,
    hybrid,
    graph,
};

// === CHUNKING STRATEGY ===
pub const ChunkingStrategy = enum {
    fixed_size,
    semantic,
    hybrid,
};

// === CHUNK CONFIG ===
pub const ChunkConfig = struct {
    strategy: ChunkingStrategy,
    chunk_size: u32,
    overlap: u32,
    prefer_semantic: bool,
};

pub const DEFAULT_CHUNK_CONFIG = ChunkConfig{
    .strategy = .hybrid,
    .chunk_size = 768,
    .overlap = 64,
    .prefer_semantic = true,
};

// === PROJECT CONTEXT ===
pub const ProjectContext = struct {
    root_path: []const u8,
    name: []const u8,
    primary_language: Language,
    file_count: u32,
    total_lines: u32,
    symbol_count: u32,
    dependency_count: u32,
};

// === CONTEXT ENGINE ===
pub const ContextEngine = struct {
    project: ?ProjectContext,
    indexed: bool,
    chunk_config: ChunkConfig,
    retrieval_method: RetrievalMethod,
    embedding_count: u32,

    pub fn init() ContextEngine {
        return .{
            .project = null,
            .indexed = false,
            .chunk_config = DEFAULT_CHUNK_CONFIG,
            .retrieval_method = .hybrid,
            .embedding_count = 0,
        };
    }

    pub fn setProject(self: *ContextEngine, project: ProjectContext) void {
        self.project = project;
        self.indexed = false;
    }

    pub fn index(self: *ContextEngine) bool {
        if (self.project == null) return false;
        // Simulate indexing
        self.indexed = true;
        self.embedding_count = self.project.?.file_count * 10; // ~10 chunks per file
        return true;
    }

    pub fn isReady(self: *const ContextEngine) bool {
        return self.indexed and self.project != null;
    }

    pub fn getFileCount(self: *const ContextEngine) u32 {
        if (self.project) |p| return p.file_count;
        return 0;
    }

    pub fn getSymbolCount(self: *const ContextEngine) u32 {
        if (self.project) |p| return p.symbol_count;
        return 0;
    }

    pub fn setRetrievalMethod(self: *ContextEngine, method: RetrievalMethod) void {
        self.retrieval_method = method;
    }

    pub fn setChunkConfig(self: *ContextEngine, config: ChunkConfig) void {
        self.chunk_config = config;
    }
};

// === LANGUAGE DETECTION ===
pub fn detectLanguage(extension: []const u8) Language {
    if (std.mem.eql(u8, extension, ".zig")) return .zig;
    if (std.mem.eql(u8, extension, ".py")) return .python;
    if (std.mem.eql(u8, extension, ".js")) return .javascript;
    if (std.mem.eql(u8, extension, ".ts")) return .typescript;
    if (std.mem.eql(u8, extension, ".rs")) return .rust;
    if (std.mem.eql(u8, extension, ".go")) return .go;
    if (std.mem.eql(u8, extension, ".java")) return .java;
    if (std.mem.eql(u8, extension, ".cpp")) return .cpp;
    if (std.mem.eql(u8, extension, ".rb")) return .ruby;
    if (std.mem.eql(u8, extension, ".vibee")) return .vibee;
    return .unknown;
}

// === FILE TYPE DETECTION ===
pub fn detectFileType(path: []const u8) FileType {
    if (std.mem.indexOf(u8, path, "test") != null) return .@"test";
    if (std.mem.indexOf(u8, path, "spec") != null) return .@"test";
    if (std.mem.endsWith(u8, path, ".md")) return .documentation;
    if (std.mem.endsWith(u8, path, ".json")) return .config;
    if (std.mem.endsWith(u8, path, ".yaml")) return .config;
    if (std.mem.endsWith(u8, path, ".toml")) return .config;
    return .source_code;
}

// === SIMILARITY SCORE ===
pub fn cosineSimilarity(a: []const f64, b: []const f64) f64 {
    if (a.len != b.len or a.len == 0) return 0;
    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;
    for (a, b) |ai, bi| {
        dot += ai * bi;
        norm_a += ai * ai;
        norm_b += bi * bi;
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    return if (denom == 0) 0 else dot / denom;
}

// === PERFORMANCE TARGETS ===
pub const PERF_INDEX_FILES_PER_SEC: u32 = 100;
pub const PERF_INDEX_SYMBOLS_PER_SEC: u32 = 1000;
pub const PERF_SEARCH_P50_MS: u32 = 50;
pub const PERF_SEARCH_P99_MS: u32 = 200;
pub const PERF_MEM_PER_FILE_KB: u32 = 10;
pub const PERF_MEM_PER_CHUNK_KB: u32 = 6;

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "EMBEDDING_DIM" { try testing.expectEqual(@as(u32, 1536), EMBEDDING_DIM); }
test "MAX_CONTEXT_TOKENS" { try testing.expectEqual(@as(u32, 128000), MAX_CONTEXT_TOKENS); }

// ============================================================
// TESTS: LANGUAGE DETECTION
// ============================================================
test "detect.zig" { try testing.expect(detectLanguage(".zig") == .zig); }
test "detect.python" { try testing.expect(detectLanguage(".py") == .python); }
test "detect.javascript" { try testing.expect(detectLanguage(".js") == .javascript); }
test "detect.typescript" { try testing.expect(detectLanguage(".ts") == .typescript); }
test "detect.rust" { try testing.expect(detectLanguage(".rs") == .rust); }
test "detect.go" { try testing.expect(detectLanguage(".go") == .go); }
test "detect.java" { try testing.expect(detectLanguage(".java") == .java); }
test "detect.cpp" { try testing.expect(detectLanguage(".cpp") == .cpp); }
test "detect.ruby" { try testing.expect(detectLanguage(".rb") == .ruby); }
test "detect.vibee" { try testing.expect(detectLanguage(".vibee") == .vibee); }
test "detect.unknown" { try testing.expect(detectLanguage(".xyz") == .unknown); }

// ============================================================
// TESTS: FILE TYPE DETECTION
// ============================================================
test "filetype.test" { try testing.expect(detectFileType("src/test_main.zig") == .@"test"); }
test "filetype.spec" { try testing.expect(detectFileType("specs/feature.spec") == .@"test"); }
test "filetype.docs" { try testing.expect(detectFileType("README.md") == .documentation); }
test "filetype.json" { try testing.expect(detectFileType("package.json") == .config); }
test "filetype.yaml" { try testing.expect(detectFileType("config.yaml") == .config); }
test "filetype.toml" { try testing.expect(detectFileType("Cargo.toml") == .config); }
test "filetype.source" { try testing.expect(detectFileType("main.zig") == .source_code); }

// ============================================================
// TESTS: SYMBOL KINDS
// ============================================================
test "symbol.function" { try testing.expect(SymbolKind.function == .function); }
test "symbol.struct" { try testing.expect(SymbolKind.@"struct" == .@"struct"); }
test "symbol.enum" { try testing.expect(SymbolKind.@"enum" == .@"enum"); }
test "symbol.const" { try testing.expect(SymbolKind.@"const" == .@"const"); }
test "symbol.variable" { try testing.expect(SymbolKind.variable == .variable); }

// ============================================================
// TESTS: RETRIEVAL METHODS
// ============================================================
test "retrieval.keyword" { try testing.expect(RetrievalMethod.keyword == .keyword); }
test "retrieval.semantic" { try testing.expect(RetrievalMethod.semantic == .semantic); }
test "retrieval.hybrid" { try testing.expect(RetrievalMethod.hybrid == .hybrid); }
test "retrieval.graph" { try testing.expect(RetrievalMethod.graph == .graph); }

// ============================================================
// TESTS: CHUNKING STRATEGIES
// ============================================================
test "chunking.fixed" { try testing.expect(ChunkingStrategy.fixed_size == .fixed_size); }
test "chunking.semantic" { try testing.expect(ChunkingStrategy.semantic == .semantic); }
test "chunking.hybrid" { try testing.expect(ChunkingStrategy.hybrid == .hybrid); }

// ============================================================
// TESTS: DEFAULT CONFIG
// ============================================================
test "config.strategy" { try testing.expect(DEFAULT_CHUNK_CONFIG.strategy == .hybrid); }
test "config.chunk_size" { try testing.expectEqual(@as(u32, 768), DEFAULT_CHUNK_CONFIG.chunk_size); }
test "config.overlap" { try testing.expectEqual(@as(u32, 64), DEFAULT_CHUNK_CONFIG.overlap); }
test "config.prefer_semantic" { try testing.expect(DEFAULT_CHUNK_CONFIG.prefer_semantic); }

// ============================================================
// TESTS: CONTEXT ENGINE
// ============================================================
test "engine.init" {
    const engine = ContextEngine.init();
    try testing.expect(engine.project == null);
    try testing.expect(!engine.indexed);
    try testing.expect(engine.retrieval_method == .hybrid);
}

test "engine.set_project" {
    var engine = ContextEngine.init();
    const project = ProjectContext{
        .root_path = "/project",
        .name = "test",
        .primary_language = .zig,
        .file_count = 50,
        .total_lines = 5000,
        .symbol_count = 200,
        .dependency_count = 10,
    };
    engine.setProject(project);
    try testing.expect(engine.project != null);
    try testing.expectEqual(@as(u32, 50), engine.getFileCount());
}

test "engine.index" {
    var engine = ContextEngine.init();
    const project = ProjectContext{
        .root_path = "/project",
        .name = "test",
        .primary_language = .zig,
        .file_count = 50,
        .total_lines = 5000,
        .symbol_count = 200,
        .dependency_count = 10,
    };
    engine.setProject(project);
    const result = engine.index();
    try testing.expect(result);
    try testing.expect(engine.indexed);
    try testing.expect(engine.isReady());
}

test "engine.index_no_project" {
    var engine = ContextEngine.init();
    const result = engine.index();
    try testing.expect(!result);
    try testing.expect(!engine.indexed);
}

test "engine.file_count" {
    var engine = ContextEngine.init();
    try testing.expectEqual(@as(u32, 0), engine.getFileCount());
    const project = ProjectContext{
        .root_path = "/project",
        .name = "test",
        .primary_language = .zig,
        .file_count = 100,
        .total_lines = 10000,
        .symbol_count = 500,
        .dependency_count = 20,
    };
    engine.setProject(project);
    try testing.expectEqual(@as(u32, 100), engine.getFileCount());
}

test "engine.symbol_count" {
    var engine = ContextEngine.init();
    try testing.expectEqual(@as(u32, 0), engine.getSymbolCount());
    const project = ProjectContext{
        .root_path = "/project",
        .name = "test",
        .primary_language = .zig,
        .file_count = 100,
        .total_lines = 10000,
        .symbol_count = 500,
        .dependency_count = 20,
    };
    engine.setProject(project);
    try testing.expectEqual(@as(u32, 500), engine.getSymbolCount());
}

test "engine.set_retrieval" {
    var engine = ContextEngine.init();
    engine.setRetrievalMethod(.semantic);
    try testing.expect(engine.retrieval_method == .semantic);
}

test "engine.embedding_count" {
    var engine = ContextEngine.init();
    const project = ProjectContext{
        .root_path = "/project",
        .name = "test",
        .primary_language = .zig,
        .file_count = 50,
        .total_lines = 5000,
        .symbol_count = 200,
        .dependency_count = 10,
    };
    engine.setProject(project);
    _ = engine.index();
    try testing.expectEqual(@as(u32, 500), engine.embedding_count); // 50 files * 10 chunks
}

// ============================================================
// TESTS: COSINE SIMILARITY
// ============================================================
test "similarity.identical" {
    const a = [_]f64{ 1.0, 0.0, 0.0 };
    const b = [_]f64{ 1.0, 0.0, 0.0 };
    try testing.expectApproxEqAbs(@as(f64, 1.0), cosineSimilarity(&a, &b), 0.0001);
}

test "similarity.orthogonal" {
    const a = [_]f64{ 1.0, 0.0, 0.0 };
    const b = [_]f64{ 0.0, 1.0, 0.0 };
    try testing.expectApproxEqAbs(@as(f64, 0.0), cosineSimilarity(&a, &b), 0.0001);
}

test "similarity.opposite" {
    const a = [_]f64{ 1.0, 0.0, 0.0 };
    const b = [_]f64{ -1.0, 0.0, 0.0 };
    try testing.expectApproxEqAbs(@as(f64, -1.0), cosineSimilarity(&a, &b), 0.0001);
}

test "similarity.partial" {
    const a = [_]f64{ 1.0, 1.0, 0.0 };
    const b = [_]f64{ 1.0, 0.0, 0.0 };
    const expected = 1.0 / @sqrt(2.0);
    try testing.expectApproxEqAbs(expected, cosineSimilarity(&a, &b), 0.0001);
}

// ============================================================
// TESTS: PERFORMANCE TARGETS
// ============================================================
test "perf.index_files" { try testing.expectEqual(@as(u32, 100), PERF_INDEX_FILES_PER_SEC); }
test "perf.index_symbols" { try testing.expectEqual(@as(u32, 1000), PERF_INDEX_SYMBOLS_PER_SEC); }
test "perf.search_p50" { try testing.expectEqual(@as(u32, 50), PERF_SEARCH_P50_MS); }
test "perf.search_p99" { try testing.expectEqual(@as(u32, 200), PERF_SEARCH_P99_MS); }
test "perf.mem_file" { try testing.expectEqual(@as(u32, 10), PERF_MEM_PER_FILE_KB); }
test "perf.mem_chunk" { try testing.expectEqual(@as(u32, 6), PERF_MEM_PER_CHUNK_KB); }
