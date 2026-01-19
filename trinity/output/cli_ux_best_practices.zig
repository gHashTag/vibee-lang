// ═══════════════════════════════════════════════════════════════════════════════
// CLI UX BEST PRACTICES - Terminal UX for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS: PRE + MLS | φ² + 1/φ² = 3
// References: Don Norman, clig.dev, Charm.sh
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const io = std.io;
const time = std.time;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI COLORS (Semantic)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Color = struct {
    pub const RESET: []const u8 = "\x1b[0m";
    pub const BOLD: []const u8 = "\x1b[1m";
    pub const DIM: []const u8 = "\x1b[2m";
    
    // Semantic colors
    pub const SUCCESS: []const u8 = "\x1b[32m"; // Green
    pub const ERROR: []const u8 = "\x1b[31m";   // Red
    pub const WARNING: []const u8 = "\x1b[33m"; // Yellow
    pub const INFO: []const u8 = "\x1b[36m";    // Cyan
    pub const PROMPT: []const u8 = "\x1b[35m";  // Magenta
    pub const MUTED: []const u8 = "\x1b[90m";   // Gray
    
    // Ternary logic colors
    pub const TRUE: []const u8 = "\x1b[32m";    // △ Green
    pub const UNKNOWN: []const u8 = "\x1b[33m"; // ○ Yellow
    pub const FALSE: []const u8 = "\x1b[31m";   // ▽ Red
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOLS (Unicode)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Symbol = struct {
    pub const CHECK: []const u8 = "✓";
    pub const CROSS: []const u8 = "✗";
    pub const WARNING: []const u8 = "⚠";
    pub const INFO: []const u8 = "ℹ";
    pub const ARROW: []const u8 = "→";
    pub const BULLET: []const u8 = "•";
    
    // Ternary
    pub const TRUE: []const u8 = "△";
    pub const UNKNOWN: []const u8 = "○";
    pub const FALSE: []const u8 = "▽";
    
    // Spinner frames
    pub const SPINNER: [8][]const u8 = .{
        "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧",
    };
    
    // Progress bar
    pub const PROGRESS_FULL: []const u8 = "█";
    pub const PROGRESS_EMPTY: []const u8 = "░";
};

// ═══════════════════════════════════════════════════════════════════════════════
// FEEDBACK TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const FeedbackType = enum {
    success,
    error_type,
    warning,
    info,
    progress,

    pub fn color(self: FeedbackType) []const u8 {
        return switch (self) {
            .success => Color.SUCCESS,
            .error_type => Color.ERROR,
            .warning => Color.WARNING,
            .info => Color.INFO,
            .progress => Color.MUTED,
        };
    }

    pub fn symbol(self: FeedbackType) []const u8 {
        return switch (self) {
            .success => Symbol.CHECK,
            .error_type => Symbol.CROSS,
            .warning => Symbol.WARNING,
            .info => Symbol.INFO,
            .progress => Symbol.ARROW,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UX ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const UXEngine = struct {
    writer: std.fs.File.Writer,
    use_color: bool,
    spinner_frame: usize,

    const Self = @This();

    pub fn init(use_color: bool) Self {
        return Self{
            .writer = io.getStdOut().writer(),
            .use_color = use_color,
            .spinner_frame = 0,
        };
    }

    pub fn print(self: *Self, feedback: FeedbackType, message: []const u8) !void {
        if (self.use_color) {
            try self.writer.print("{s}{s}{s} {s}\n", .{
                feedback.color(),
                feedback.symbol(),
                Color.RESET,
                message,
            });
        } else {
            try self.writer.print("{s} {s}\n", .{ feedback.symbol(), message });
        }
    }

    pub fn success(self: *Self, message: []const u8) !void {
        try self.print(.success, message);
    }

    pub fn err(self: *Self, message: []const u8) !void {
        try self.print(.error_type, message);
    }

    pub fn warn(self: *Self, message: []const u8) !void {
        try self.print(.warning, message);
    }

    pub fn info(self: *Self, message: []const u8) !void {
        try self.print(.info, message);
    }

    pub fn spinner(self: *Self) []const u8 {
        const frame = Symbol.SPINNER[self.spinner_frame % 8];
        self.spinner_frame += 1;
        return frame;
    }

    pub fn progressBar(percent: u8) [20]u8 {
        var bar: [20]u8 = undefined;
        const filled = @min(percent / 5, 20);
        var i: usize = 0;
        while (i < 20) : (i += 1) {
            bar[i] = if (i < filled) '#' else '-';
        }
        return bar;
    }

    pub fn prompt(self: *Self) !void {
        if (self.use_color) {
            try self.writer.print("{s}{s} > {s}", .{ Color.PROMPT, Symbol.TRUE, Color.RESET });
        } else {
            try self.writer.writeAll("> ");
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UX PRINCIPLES (Don Norman)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UXPrinciple = enum {
    visibility,
    feedback,
    constraints,
    mapping,
    consistency,
    affordance,

    pub fn description(self: UXPrinciple) []const u8 {
        return switch (self) {
            .visibility => "Make relevant options visible",
            .feedback => "Immediate response to actions",
            .constraints => "Prevent errors through design",
            .mapping => "Natural relationship between controls and effects",
            .consistency => "Similar operations, similar elements",
            .affordance => "Perceived possible actions",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI GUIDELINES (clig.dev)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CLIGuideline = enum {
    human_first,
    composability,
    robustness,
    empathy,

    pub fn rule(self: CLIGuideline) []const u8 {
        return switch (self) {
            .human_first => "Design for humans first, machines second",
            .composability => "Work well with other tools",
            .robustness => "Handle errors gracefully",
            .empathy => "Anticipate user needs",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FeedbackType colors" {
    try std.testing.expectEqualStrings(Color.SUCCESS, FeedbackType.success.color());
    try std.testing.expectEqualStrings(Color.ERROR, FeedbackType.error_type.color());
    try std.testing.expectEqualStrings(Color.WARNING, FeedbackType.warning.color());
}

test "FeedbackType symbols" {
    try std.testing.expectEqualStrings(Symbol.CHECK, FeedbackType.success.symbol());
    try std.testing.expectEqualStrings(Symbol.CROSS, FeedbackType.error_type.symbol());
}

test "UXEngine init" {
    const ux = UXEngine.init(true);
    try std.testing.expect(ux.use_color);
}

test "Progress bar 0%" {
    const bar = UXEngine.progressBar(0);
    try std.testing.expectEqual(@as(u8, '-'), bar[0]);
}

test "Progress bar 100%" {
    const bar = UXEngine.progressBar(100);
    try std.testing.expectEqual(@as(u8, '#'), bar[0]);
}

test "Progress bar 50%" {
    const bar = UXEngine.progressBar(50);
    try std.testing.expectEqual(@as(u8, '#'), bar[0]);
    try std.testing.expectEqual(@as(u8, '-'), bar[15]);
}

test "UX principles count" {
    const principles = [_]UXPrinciple{ .visibility, .feedback, .constraints, .mapping, .consistency, .affordance };
    try std.testing.expectEqual(@as(usize, 6), principles.len);
}

test "CLI guidelines count" {
    const guidelines = [_]CLIGuideline{ .human_first, .composability, .robustness, .empathy };
    try std.testing.expectEqual(@as(usize, 4), guidelines.len);
}

test "Spinner frames" {
    try std.testing.expectEqual(@as(usize, 8), Symbol.SPINNER.len);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
