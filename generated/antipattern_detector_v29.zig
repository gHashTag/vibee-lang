// ═══════════════════════════════════════════════════════════════════════════════
// ANTIPATTERN DETECTOR v29 - REAL CODE ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════
// v28: Extension checking only
// v29: Real code analysis, complexity detection, smell detection
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION: u32 = 29;
pub const MAX_FUNCTION_LINES: usize = 50;
pub const MAX_NESTING_DEPTH: usize = 4;
pub const MAX_COMPLEXITY: usize = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Severity = enum(u8) {
    CRITICAL = 0,
    HIGH = 1,
    MEDIUM = 2,
    LOW = 3,

    pub fn name(self: Severity) []const u8 {
        return switch (self) {
            .CRITICAL => "CRITICAL",
            .HIGH => "HIGH",
            .MEDIUM => "MEDIUM",
            .LOW => "LOW",
        };
    }

    pub fn weight(self: Severity) u32 {
        return switch (self) {
            .CRITICAL => 100,
            .HIGH => 50,
            .MEDIUM => 20,
            .LOW => 5,
        };
    }
};

pub const ViolationKind = enum(u8) {
    LONG_FUNCTION = 0,
    DEEP_NESTING = 1,
    HIGH_COMPLEXITY = 2,
    MAGIC_NUMBER = 3,
    DUPLICATE_CODE = 4,
    FORBIDDEN_FILE = 5,
    MISSING_SPEC = 6,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeMetrics = struct {
    lines: usize = 0,
    nesting_depth: usize = 0,
    max_nesting: usize = 0,
    cyclomatic_complexity: usize = 1, // Base complexity
    magic_number_count: usize = 0,
    function_count: usize = 0,

    const Self = @This();

    /// Analyze source code and compute metrics
    pub fn analyze(self: *Self, source: []const u8) void {
        self.lines = 0;
        self.nesting_depth = 0;
        self.max_nesting = 0;
        self.cyclomatic_complexity = 1;
        self.magic_number_count = 0;
        self.function_count = 0;

        var current_depth: usize = 0;
        var in_number = false;
        var number_start: usize = 0;

        for (source, 0..) |c, i| {
            switch (c) {
                '\n' => {
                    self.lines += 1;
                },
                '{' => {
                    current_depth += 1;
                    if (current_depth > self.max_nesting) {
                        self.max_nesting = current_depth;
                    }
                },
                '}' => {
                    if (current_depth > 0) current_depth -= 1;
                },
                'i' => {
                    // Check for "if"
                    if (i + 1 < source.len and source[i + 1] == 'f') {
                        self.cyclomatic_complexity += 1;
                    }
                },
                'w' => {
                    // Check for "while"
                    if (i + 4 < source.len and std.mem.eql(u8, source[i .. i + 5], "while")) {
                        self.cyclomatic_complexity += 1;
                    }
                },
                'f' => {
                    // Check for "for" or "fn"
                    if (i + 2 < source.len) {
                        if (std.mem.eql(u8, source[i .. i + 3], "for")) {
                            self.cyclomatic_complexity += 1;
                        } else if (std.mem.eql(u8, source[i .. i + 2], "fn")) {
                            self.function_count += 1;
                        }
                    }
                },
                '0'...'9' => {
                    if (!in_number) {
                        in_number = true;
                        number_start = i;
                    }
                },
                else => {
                    if (in_number) {
                        in_number = false;
                        // Check if it's a magic number (not 0, 1, or 2)
                        const num_len = i - number_start;
                        if (num_len > 0) {
                            const num_str = source[number_start..i];
                            if (!std.mem.eql(u8, num_str, "0") and
                                !std.mem.eql(u8, num_str, "1") and
                                !std.mem.eql(u8, num_str, "2"))
                            {
                                self.magic_number_count += 1;
                            }
                        }
                    }
                },
            }
        }

        self.nesting_depth = self.max_nesting;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VIOLATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Violation = struct {
    kind: ViolationKind,
    line: usize = 0,
    column: usize = 0,
    severity: Severity,
    message: [128]u8 = [_]u8{0} ** 128,
    message_len: usize = 0,

    const Self = @This();

    pub fn init(kind: ViolationKind, severity: Severity, line: usize, msg: []const u8) Self {
        var v = Self{
            .kind = kind,
            .severity = severity,
            .line = line,
        };
        const len = @min(msg.len, 128);
        @memcpy(v.message[0..len], msg[0..len]);
        v.message_len = len;
        return v;
    }

    pub fn getMessage(self: *const Self) []const u8 {
        return self.message[0..self.message_len];
    }

    pub fn score(self: Self) u32 {
        return self.severity.weight();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeAnalyzer = struct {
    metrics: CodeMetrics = CodeMetrics{},
    violations: std.ArrayList(Violation),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .violations = std.ArrayList(Violation).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.violations.deinit();
    }

    /// Analyze source code for antipatterns
    pub fn analyze(self: *Self, source: []const u8) ![]Violation {
        self.violations.clearRetainingCapacity();
        self.metrics.analyze(source);

        // Check for long functions
        if (self.metrics.lines > MAX_FUNCTION_LINES) {
            try self.violations.append(Violation.init(
                .LONG_FUNCTION,
                .MEDIUM,
                0,
                "Function exceeds 50 lines",
            ));
        }

        // Check for deep nesting
        if (self.metrics.nesting_depth > MAX_NESTING_DEPTH) {
            try self.violations.append(Violation.init(
                .DEEP_NESTING,
                .HIGH,
                0,
                "Nesting depth exceeds 4 levels",
            ));
        }

        // Check for high complexity
        if (self.metrics.cyclomatic_complexity > MAX_COMPLEXITY) {
            try self.violations.append(Violation.init(
                .HIGH_COMPLEXITY,
                .HIGH,
                0,
                "Cyclomatic complexity exceeds 10",
            ));
        }

        // Check for magic numbers
        if (self.metrics.magic_number_count > 3) {
            try self.violations.append(Violation.init(
                .MAGIC_NUMBER,
                .LOW,
                0,
                "Multiple magic numbers detected",
            ));
        }

        return self.violations.items;
    }

    pub fn getMetrics(self: *Self) CodeMetrics {
        return self.metrics;
    }

    pub fn totalScore(self: *Self) u32 {
        var total: u32 = 0;
        for (self.violations.items) |v| {
            total += v.score();
        }
        return total;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DUPLICATE DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const DuplicateDetector = struct {
    line_hashes: std.AutoHashMap(u64, usize),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .line_hashes = std.AutoHashMap(u64, usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.line_hashes.deinit();
    }

    /// Find duplicate lines in source
    pub fn findDuplicates(self: *Self, source: []const u8) !usize {
        self.line_hashes.clearRetainingCapacity();

        var duplicates: usize = 0;
        var line_start: usize = 0;
        var line_num: usize = 0;

        for (source, 0..) |c, i| {
            if (c == '\n' or i == source.len - 1) {
                const line_end = if (c == '\n') i else i + 1;
                const line = source[line_start..line_end];

                // Skip empty lines and whitespace-only lines
                var non_whitespace = false;
                for (line) |ch| {
                    if (ch != ' ' and ch != '\t' and ch != '\n' and ch != '\r') {
                        non_whitespace = true;
                        break;
                    }
                }

                if (non_whitespace and line.len > 10) {
                    const hash = self.hashLine(line);

                    if (self.line_hashes.get(hash)) |_| {
                        duplicates += 1;
                    } else {
                        try self.line_hashes.put(hash, line_num);
                    }
                }

                line_start = i + 1;
                line_num += 1;
            }
        }

        return duplicates;
    }

    fn hashLine(self: *Self, line: []const u8) u64 {
        _ = self;
        var h: u64 = 0;
        for (line) |c| {
            if (c != ' ' and c != '\t') { // Ignore whitespace
                h = h *% 31 +% c;
            }
        }
        return h;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANTIPATTERN DETECTOR v29
// ═══════════════════════════════════════════════════════════════════════════════

pub const AntipatternDetectorV29 = struct {
    analyzer: CodeAnalyzer,
    duplicate_detector: DuplicateDetector,
    version: u32 = VERSION,
    files_analyzed: usize = 0,
    total_violations: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .analyzer = CodeAnalyzer.init(allocator),
            .duplicate_detector = DuplicateDetector.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.analyzer.deinit();
        self.duplicate_detector.deinit();
    }

    pub fn analyzeSource(self: *Self, source: []const u8) ![]Violation {
        const violations = try self.analyzer.analyze(source);
        self.files_analyzed += 1;
        self.total_violations += violations.len;
        return violations;
    }

    pub fn getMetrics(self: *Self) CodeMetrics {
        return self.analyzer.getMetrics();
    }

    pub fn findDuplicates(self: *Self, source: []const u8) !usize {
        return self.duplicate_detector.findDuplicates(source);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "code_metrics_lines" {
    var metrics = CodeMetrics{};
    metrics.analyze("line1\nline2\nline3\n");
    try std.testing.expectEqual(@as(usize, 3), metrics.lines);
}

test "code_metrics_nesting" {
    var metrics = CodeMetrics{};
    metrics.analyze("fn test() { if (x) { while (y) { } } }");
    try std.testing.expectEqual(@as(usize, 3), metrics.max_nesting);
}

test "code_metrics_complexity" {
    var metrics = CodeMetrics{};
    metrics.analyze("fn test() { if (a) {} if (b) {} for (i) {} }");
    // Base 1 + 2 ifs + 1 for = 4
    try std.testing.expectEqual(@as(usize, 4), metrics.cyclomatic_complexity);
}

test "code_metrics_magic_numbers" {
    var metrics = CodeMetrics{};
    metrics.analyze("const x = 42; const y = 100; const z = 0;");
    // 42 and 100 are magic, 0 is not
    try std.testing.expectEqual(@as(usize, 2), metrics.magic_number_count);
}

test "analyzer_long_function" {
    var analyzer = CodeAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    // Create source with 60 lines
    var source: [600]u8 = undefined;
    var offset: usize = 0;
    for (0..60) |_| {
        const line = "x = 1;\n";
        @memcpy(source[offset..][0..line.len], line);
        offset += line.len;
    }

    const violations = try analyzer.analyze(source[0..offset]);
    try std.testing.expect(violations.len > 0);

    var found_long = false;
    for (violations) |v| {
        if (v.kind == .LONG_FUNCTION) found_long = true;
    }
    try std.testing.expect(found_long);
}

test "analyzer_deep_nesting" {
    var analyzer = CodeAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const source = "fn x() { { { { { } } } } }"; // 5 levels
    const violations = try analyzer.analyze(source);

    var found_deep = false;
    for (violations) |v| {
        if (v.kind == .DEEP_NESTING) found_deep = true;
    }
    try std.testing.expect(found_deep);
}

test "analyzer_high_complexity" {
    var analyzer = CodeAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    // 12 branches
    const source = "fn x() { if(a){} if(b){} if(c){} if(d){} if(e){} if(f){} if(g){} if(h){} if(i){} if(j){} if(k){} if(l){} }";
    const violations = try analyzer.analyze(source);

    var found_complex = false;
    for (violations) |v| {
        if (v.kind == .HIGH_COMPLEXITY) found_complex = true;
    }
    try std.testing.expect(found_complex);
}

test "duplicate_detector" {
    var detector = DuplicateDetector.init(std.testing.allocator);
    defer detector.deinit();

    const source = "const x = 123456789;\nconst y = 987654321;\nconst x = 123456789;\n";
    const duplicates = try detector.findDuplicates(source);

    try std.testing.expect(duplicates > 0);
}

test "violation_score" {
    const v = Violation.init(.HIGH_COMPLEXITY, .HIGH, 0, "test");
    try std.testing.expectEqual(@as(u32, 50), v.score());
}

test "golden_identity" {
    const phi_squared = PHI * PHI;
    const inv_phi_squared = 1.0 / (PHI * PHI);
    const result = phi_squared + inv_phi_squared;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "version_check" {
    var detector = AntipatternDetectorV29.init(std.testing.allocator);
    defer detector.deinit();
    try std.testing.expectEqual(@as(u32, 29), detector.version);
}
