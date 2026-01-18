// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC V22 - ERROR REPORTER
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V34 - Structured Diagnostics with Color Output
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "22.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI COLOR CODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Color = enum {
    reset,
    bold,
    dim,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_red,
    bright_green,
    bright_yellow,
    bright_cyan,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .bright_red => "\x1b[91m",
            .bright_green => "\x1b[92m",
            .bright_yellow => "\x1b[93m",
            .bright_cyan => "\x1b[96m",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR WRITER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ColorWriter = struct {
    writer: std.io.AnyWriter,
    use_color: bool,

    const Self = @This();

    pub fn init(writer: std.io.AnyWriter, force_color: ?bool) Self {
        const use_color = force_color orelse detectTty();
        return Self{
            .writer = writer,
            .use_color = use_color,
        };
    }

    fn detectTty() bool {
        // Check if stdout is a TTY
        const stdout = std.io.getStdOut();
        return stdout.isTty();
    }

    pub fn setColor(self: *Self, color: Color) !void {
        if (self.use_color) {
            try self.writer.writeAll(color.code());
        }
    }

    pub fn resetColor(self: *Self) !void {
        if (self.use_color) {
            try self.writer.writeAll(Color.reset.code());
        }
    }

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.writer.print(fmt, args);
    }

    pub fn writeAll(self: *Self, bytes: []const u8) !void {
        try self.writer.writeAll(bytes);
    }

    pub fn printColored(self: *Self, color: Color, comptime fmt: []const u8, args: anytype) !void {
        try self.setColor(color);
        try self.writer.print(fmt, args);
        try self.resetColor();
    }

    pub fn bold(self: *Self, text: []const u8) !void {
        try self.setColor(.bold);
        try self.writer.writeAll(text);
        try self.resetColor();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE LOCATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SourceLocation = struct {
    file: []const u8,
    line: u32,
    column: u32,
    offset: usize,

    pub fn format(self: SourceLocation, allocator: Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s}:{d}:{d}", .{ self.file, self.line, self.column });
    }
};

pub const SourceSpan = struct {
    start: SourceLocation,
    end: SourceLocation,
    source_line: ?[]const u8,

    pub fn length(self: SourceSpan) usize {
        if (self.start.line == self.end.line) {
            return self.end.column - self.start.column;
        }
        return 1; // Multi-line spans show single caret
    }

    pub fn getUnderline(self: SourceSpan, allocator: Allocator) ![]const u8 {
        const len = @max(1, self.length());
        const underline = try allocator.alloc(u8, len);
        @memset(underline, '^');
        return underline;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSTIC TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiagnosticSeverity = enum {
    error_level,
    warning,
    info,
    hint,
    note,

    pub fn color(self: DiagnosticSeverity) Color {
        return switch (self) {
            .error_level => .red,
            .warning => .yellow,
            .info => .cyan,
            .hint => .green,
            .note => .blue,
        };
    }

    pub fn label(self: DiagnosticSeverity) []const u8 {
        return switch (self) {
            .error_level => "error",
            .warning => "warning",
            .info => "info",
            .hint => "hint",
            .note => "note",
        };
    }
};

pub const DiagnosticCode = enum {
    // Parser errors (E001-E099)
    E001_UNEXPECTED_TOKEN,
    E002_UNCLOSED_BRACKET,
    E003_INVALID_YAML,
    E004_MISSING_FIELD,
    E005_DUPLICATE_KEY,
    E006_INVALID_INDENT,
    E007_EXPECTED_COLON,
    E008_INVALID_VALUE,
    // Semantic errors (E100-E199)
    E100_UNDEFINED_TYPE,
    E101_TYPE_MISMATCH,
    E102_UNDEFINED_REFERENCE,
    E103_DUPLICATE_DEFINITION,
    E104_INVALID_PATTERN,
    // PAS errors (E200-E299)
    E200_INVALID_COMPLEXITY,
    E201_UNKNOWN_PATTERN,
    // Warnings (W001-W099)
    W001_UNUSED_TYPE,
    W002_DEPRECATED_SYNTAX,
    W003_MISSING_TEST_CASE,

    pub fn message(self: DiagnosticCode) []const u8 {
        return switch (self) {
            .E001_UNEXPECTED_TOKEN => "unexpected token",
            .E002_UNCLOSED_BRACKET => "unclosed bracket",
            .E003_INVALID_YAML => "invalid YAML syntax",
            .E004_MISSING_FIELD => "missing required field",
            .E005_DUPLICATE_KEY => "duplicate key",
            .E006_INVALID_INDENT => "invalid indentation",
            .E007_EXPECTED_COLON => "expected ':'",
            .E008_INVALID_VALUE => "invalid value",
            .E100_UNDEFINED_TYPE => "undefined type",
            .E101_TYPE_MISMATCH => "type mismatch",
            .E102_UNDEFINED_REFERENCE => "undefined reference",
            .E103_DUPLICATE_DEFINITION => "duplicate definition",
            .E104_INVALID_PATTERN => "invalid creation pattern",
            .E200_INVALID_COMPLEXITY => "invalid complexity notation",
            .E201_UNKNOWN_PATTERN => "unknown PAS pattern",
            .W001_UNUSED_TYPE => "unused type definition",
            .W002_DEPRECATED_SYNTAX => "deprecated syntax",
            .W003_MISSING_TEST_CASE => "behavior missing test cases",
        };
    }

    pub fn codeString(self: DiagnosticCode) []const u8 {
        return switch (self) {
            .E001_UNEXPECTED_TOKEN => "E001",
            .E002_UNCLOSED_BRACKET => "E002",
            .E003_INVALID_YAML => "E003",
            .E004_MISSING_FIELD => "E004",
            .E005_DUPLICATE_KEY => "E005",
            .E006_INVALID_INDENT => "E006",
            .E007_EXPECTED_COLON => "E007",
            .E008_INVALID_VALUE => "E008",
            .E100_UNDEFINED_TYPE => "E100",
            .E101_TYPE_MISMATCH => "E101",
            .E102_UNDEFINED_REFERENCE => "E102",
            .E103_DUPLICATE_DEFINITION => "E103",
            .E104_INVALID_PATTERN => "E104",
            .E200_INVALID_COMPLEXITY => "E200",
            .E201_UNKNOWN_PATTERN => "E201",
            .W001_UNUSED_TYPE => "W001",
            .W002_DEPRECATED_SYNTAX => "W002",
            .W003_MISSING_TEST_CASE => "W003",
        };
    }

    pub fn severity(self: DiagnosticCode) DiagnosticSeverity {
        return switch (self) {
            .W001_UNUSED_TYPE, .W002_DEPRECATED_SYNTAX, .W003_MISSING_TEST_CASE => .warning,
            else => .error_level,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SUGGESTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Suggestion = struct {
    message: []const u8,
    replacement: ?[]const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSTIC
// ═══════════════════════════════════════════════════════════════════════════════

pub const Diagnostic = struct {
    severity: DiagnosticSeverity,
    code: DiagnosticCode,
    message: []const u8,
    span: SourceSpan,
    notes: ArrayList(Diagnostic),
    suggestions: ArrayList(Suggestion),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, severity: DiagnosticSeverity, code: DiagnosticCode, message: []const u8, span: SourceSpan) Self {
        return Self{
            .severity = severity,
            .code = code,
            .message = message,
            .span = span,
            .notes = ArrayList(Diagnostic).init(allocator),
            .suggestions = ArrayList(Suggestion).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.notes.items) |*note| {
            note.deinit();
        }
        self.notes.deinit();
        self.suggestions.deinit();
    }

    pub fn isError(self: Self) bool {
        return self.severity == .error_level;
    }

    pub fn addNote(self: *Self, message: []const u8, span: ?SourceSpan) !void {
        const note_span = span orelse self.span;
        const note = Diagnostic.init(self.allocator, .note, self.code, message, note_span);
        try self.notes.append(note);
    }

    pub fn addSuggestion(self: *Self, message: []const u8, replacement: ?[]const u8) !void {
        try self.suggestions.append(.{
            .message = message,
            .replacement = replacement,
        });
    }

    pub fn render(self: *Self, writer: *ColorWriter) !void {
        // error[E001]: unexpected token
        try writer.printColored(self.severity.color(), "{s}", .{self.severity.label()});
        try writer.printColored(.bold, "[{s}]", .{self.code.codeString()});
        try writer.print(": ", .{});
        try writer.bold(self.message);
        try writer.print("\n", .{});

        // --> file:line:column
        try writer.printColored(.blue, "  --> ", .{});
        try writer.print("{s}:{d}:{d}\n", .{ self.span.start.file, self.span.start.line, self.span.start.column });

        // |
        try writer.printColored(.blue, "   |\n", .{});

        // line_num | source_line
        if (self.span.source_line) |source_line| {
            try writer.printColored(.blue, " {d: >3} | ", .{self.span.start.line});
            try writer.print("{s}\n", .{source_line});

            // | ^^^^
            try writer.printColored(.blue, "   | ", .{});

            // Padding to column
            var i: u32 = 1;
            while (i < self.span.start.column) : (i += 1) {
                try writer.print(" ", .{});
            }

            // Underline
            const underline = try self.span.getUnderline(self.allocator);
            defer self.allocator.free(underline);
            try writer.printColored(self.severity.color(), "{s}", .{underline});
            try writer.print("\n", .{});
        }

        try writer.printColored(.blue, "   |\n", .{});

        // Notes
        for (self.notes.items) |*note| {
            try writer.printColored(.blue, "   = ", .{});
            try writer.printColored(.bold, "note", .{});
            try writer.print(": {s}\n", .{note.message});
        }

        // Suggestions
        for (self.suggestions.items) |suggestion| {
            try writer.printColored(.blue, "   = ", .{});
            try writer.printColored(.green, "help", .{});
            try writer.print(": {s}", .{suggestion.message});
            if (suggestion.replacement) |replacement| {
                try writer.print(": `{s}`", .{replacement});
            }
            try writer.print("\n", .{});
        }

        try writer.print("\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR REPORTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ErrorReporter = struct {
    allocator: Allocator,
    diagnostics: ArrayList(Diagnostic),
    source: []const u8,
    source_lines: ArrayList([]const u8),
    file_name: []const u8,
    error_count: u32,
    warning_count: u32,
    max_errors: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8, file_name: []const u8) !Self {
        var self = Self{
            .allocator = allocator,
            .diagnostics = ArrayList(Diagnostic).init(allocator),
            .source = source,
            .source_lines = ArrayList([]const u8).init(allocator),
            .file_name = file_name,
            .error_count = 0,
            .warning_count = 0,
            .max_errors = 20,
        };

        // Split source into lines
        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            try self.source_lines.append(line);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.diagnostics.items) |*diag| {
            diag.deinit();
        }
        self.diagnostics.deinit();
        self.source_lines.deinit();
    }

    pub fn report(self: *Self, severity: DiagnosticSeverity, code: DiagnosticCode, span: SourceSpan, message: []const u8) !*Diagnostic {
        if (self.error_count >= self.max_errors) {
            return error.TooManyErrors;
        }

        var diag_span = span;
        diag_span.source_line = self.getSourceLine(span.start.line);

        const diag = Diagnostic.init(self.allocator, severity, code, message, diag_span);
        try self.diagnostics.append(diag);

        if (severity == .error_level) {
            self.error_count += 1;
        } else if (severity == .warning) {
            self.warning_count += 1;
        }

        return &self.diagnostics.items[self.diagnostics.items.len - 1];
    }

    pub fn reportError(self: *Self, code: DiagnosticCode, span: SourceSpan, message: []const u8) !*Diagnostic {
        return self.report(.error_level, code, span, message);
    }

    pub fn reportWarning(self: *Self, code: DiagnosticCode, span: SourceSpan, message: []const u8) !*Diagnostic {
        return self.report(.warning, code, span, message);
    }

    pub fn hasErrors(self: Self) bool {
        return self.error_count > 0;
    }

    pub fn getSourceLine(self: Self, line: u32) ?[]const u8 {
        if (line == 0 or line > self.source_lines.items.len) {
            return null;
        }
        return self.source_lines.items[line - 1];
    }

    pub fn createSpan(self: Self, start_line: u32, start_col: u32, end_line: u32, end_col: u32) SourceSpan {
        return SourceSpan{
            .start = SourceLocation{
                .file = self.file_name,
                .line = start_line,
                .column = start_col,
                .offset = 0,
            },
            .end = SourceLocation{
                .file = self.file_name,
                .line = end_line,
                .column = end_col,
                .offset = 0,
            },
            .source_line = self.getSourceLine(start_line),
        };
    }

    pub fn render(self: *Self, writer: *ColorWriter) !void {
        for (self.diagnostics.items) |*diag| {
            try diag.render(writer);
        }
    }

    pub fn renderSummary(self: *Self, writer: *ColorWriter) !void {
        if (self.error_count > 0) {
            try writer.printColored(.red, "error", .{});
            try writer.print(": could not compile `{s}`\n\n", .{self.file_name});
        }

        try writer.bold("Summary: ");
        if (self.error_count > 0) {
            try writer.printColored(.red, "{d} error(s)", .{self.error_count});
        } else {
            try writer.print("0 errors", .{});
        }
        try writer.print(", ", .{});
        if (self.warning_count > 0) {
            try writer.printColored(.yellow, "{d} warning(s)", .{self.warning_count});
        } else {
            try writer.print("0 warnings", .{});
        }
        try writer.print("\n", .{});
    }

    pub fn renderSuccess(self: *Self, writer: *ColorWriter, outputs: []const u8, time_ms: f64) !void {
        try writer.printColored(.green, "✓", .{});
        try writer.print(" Compiled ", .{});
        try writer.bold(self.file_name);
        try writer.print(" successfully\n", .{});
        try writer.print("   Generated: {s}\n", .{outputs});
        try writer.print("   Time: {d:.2}ms\n", .{time_ms});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Color codes" {
    try std.testing.expectEqualStrings("\x1b[31m", Color.red.code());
    try std.testing.expectEqualStrings("\x1b[0m", Color.reset.code());
    try std.testing.expectEqualStrings("\x1b[1m", Color.bold.code());
}

test "DiagnosticCode messages" {
    try std.testing.expectEqualStrings("unexpected token", DiagnosticCode.E001_UNEXPECTED_TOKEN.message());
    try std.testing.expectEqualStrings("E001", DiagnosticCode.E001_UNEXPECTED_TOKEN.codeString());
}

test "ErrorReporter basic" {
    const allocator = std.testing.allocator;
    const source = "line1\nline2\nline3";

    var reporter = try ErrorReporter.init(allocator, source, "test.vibee");
    defer reporter.deinit();

    const span = reporter.createSpan(2, 1, 2, 5);
    _ = try reporter.reportError(.E001_UNEXPECTED_TOKEN, span, "test error");

    try std.testing.expect(reporter.hasErrors());
    try std.testing.expectEqual(@as(u32, 1), reporter.error_count);
}

test "SourceSpan underline" {
    const allocator = std.testing.allocator;

    const span = SourceSpan{
        .start = .{ .file = "test.vibee", .line = 1, .column = 5, .offset = 0 },
        .end = .{ .file = "test.vibee", .line = 1, .column = 10, .offset = 0 },
        .source_line = null,
    };

    const underline = try span.getUnderline(allocator);
    defer allocator.free(underline);

    try std.testing.expectEqual(@as(usize, 5), underline.len);
    try std.testing.expectEqualStrings("^^^^^", underline);
}

test "ColorWriter no color" {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var writer = ColorWriter.init(fbs.writer().any(), false);

    try writer.printColored(.red, "error", .{});

    const written = fbs.getWritten();
    try std.testing.expectEqualStrings("error", written);
}

test "ColorWriter with color" {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var writer = ColorWriter.init(fbs.writer().any(), true);

    try writer.printColored(.red, "error", .{});

    const written = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b[31m") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "error") != null);
}
