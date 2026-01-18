// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC REPL - READ-EVAL-PRINT LOOP
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V37 - Interactive VIBEE Shell
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const error_reporter = @import("error_reporter.zig");
const ColorWriter = error_reporter.ColorWriter;
const Color = error_reporter.Color;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// REPL COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Command = enum {
    help,
    quit,
    clear,
    phi,
    golden,
    sacred,
    version,
    history,
    eval,
    unknown,

    pub fn fromString(s: []const u8) Command {
        if (s.len == 0) return .eval;
        if (s[0] != ':') return .eval;

        const cmd = s[1..];
        if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "h") or std.mem.eql(u8, cmd, "?")) return .help;
        if (std.mem.eql(u8, cmd, "quit") or std.mem.eql(u8, cmd, "q") or std.mem.eql(u8, cmd, "exit")) return .quit;
        if (std.mem.eql(u8, cmd, "clear") or std.mem.eql(u8, cmd, "c")) return .clear;
        if (std.mem.eql(u8, cmd, "phi") or std.mem.eql(u8, cmd, "φ")) return .phi;
        if (std.mem.eql(u8, cmd, "golden") or std.mem.eql(u8, cmd, "g")) return .golden;
        if (std.mem.eql(u8, cmd, "sacred") or std.mem.eql(u8, cmd, "s")) return .sacred;
        if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "v")) return .version;
        if (std.mem.eql(u8, cmd, "history")) return .history;
        return .unknown;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

pub const History = struct {
    entries: ArrayList([]const u8),
    allocator: Allocator,
    max_size: usize,

    pub fn init(allocator: Allocator, max_size: usize) History {
        return History{
            .entries = ArrayList([]const u8).init(allocator),
            .allocator = allocator,
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit();
    }

    pub fn add(self: *History, line: []const u8) !void {
        // Don't add empty lines or duplicates
        if (line.len == 0) return;
        if (self.entries.items.len > 0) {
            const last = self.entries.items[self.entries.items.len - 1];
            if (std.mem.eql(u8, last, line)) return;
        }

        // Remove oldest if at max
        if (self.entries.items.len >= self.max_size) {
            const old = self.entries.orderedRemove(0);
            self.allocator.free(old);
        }

        const copy = try self.allocator.dupe(u8, line);
        try self.entries.append(copy);
    }

    pub fn get(self: *const History, index: usize) ?[]const u8 {
        if (index >= self.entries.items.len) return null;
        return self.entries.items[index];
    }

    pub fn count(self: *const History) usize {
        return self.entries.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REPL
// ═══════════════════════════════════════════════════════════════════════════════

pub const REPL = struct {
    allocator: Allocator,
    writer: ColorWriter,
    history: History,
    running: bool,
    line_number: u32,

    // Metrics
    commands_executed: u64,
    expressions_evaluated: u64,

    const Self = @This();

    pub fn init(allocator: Allocator, force_color: ?bool) Self {
        const stdout = std.io.getStdOut().writer().any();
        return Self{
            .allocator = allocator,
            .writer = ColorWriter.init(stdout, force_color),
            .history = History.init(allocator, 100),
            .running = false,
            .line_number = 1,
            .commands_executed = 0,
            .expressions_evaluated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
    }

    pub fn run(self: *Self) !void {
        self.running = true;

        try self.printBanner();

        const stdin = std.io.getStdIn().reader();
        var buf: [4096]u8 = undefined;

        while (self.running) {
            try self.printPrompt();

            const line = stdin.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
                if (err == error.EndOfStream) {
                    self.running = false;
                    break;
                }
                return err;
            };

            if (line) |input| {
                const trimmed = std.mem.trim(u8, input, " \t\r\n");
                if (trimmed.len > 0) {
                    try self.history.add(trimmed);
                    try self.processLine(trimmed);
                }
                self.line_number += 1;
            } else {
                self.running = false;
            }
        }

        try self.writer.print("\nGoodbye! φ² + 1/φ² = 3\n", .{});
    }

    fn processLine(self: *Self, line: []const u8) !void {
        const cmd = Command.fromString(line);

        switch (cmd) {
            .help => try self.cmdHelp(),
            .quit => self.running = false,
            .clear => try self.cmdClear(),
            .phi => try self.cmdPhi(),
            .golden => try self.cmdGolden(),
            .sacred => try self.cmdSacred(),
            .version => try self.cmdVersion(),
            .history => try self.cmdHistory(),
            .eval => try self.evaluate(line),
            .unknown => {
                try self.writer.printColored(.red, "Unknown command: ", .{});
                try self.writer.print("{s}\n", .{line});
                try self.writer.print("Type :help for available commands\n", .{});
            },
        }

        self.commands_executed += 1;
    }

    fn evaluate(self: *Self, expr: []const u8) !void {
        self.expressions_evaluated += 1;

        // Simple expression evaluation
        if (std.mem.eql(u8, expr, "phi") or std.mem.eql(u8, expr, "φ")) {
            try self.writer.printColored(.cyan, "φ = ", .{});
            try self.writer.print("{d:.15}\n", .{PHI});
        } else if (std.mem.eql(u8, expr, "pi") or std.mem.eql(u8, expr, "π")) {
            try self.writer.printColored(.cyan, "π = ", .{});
            try self.writer.print("{d:.15}\n", .{PI});
        } else if (std.mem.eql(u8, expr, "e")) {
            try self.writer.printColored(.cyan, "e = ", .{});
            try self.writer.print("{d:.15}\n", .{E});
        } else if (std.mem.eql(u8, expr, "golden") or std.mem.eql(u8, expr, "3")) {
            try self.writer.printColored(.yellow, "φ² + 1/φ² = ", .{});
            try self.writer.print("{d:.15}\n", .{GOLDEN_IDENTITY});
        } else {
            // Try to parse as number
            if (std.fmt.parseFloat(f64, expr)) |num| {
                try self.writer.printColored(.green, "=> ", .{});
                try self.writer.print("{d}\n", .{num});
            } else |_| {
                // Echo as string
                try self.writer.printColored(.green, "=> ", .{});
                try self.writer.print("\"{s}\"\n", .{expr});
            }
        }
    }

    fn cmdHelp(self: *Self) !void {
        try self.writer.printColored(.cyan, "\n═══ VIBEE REPL Commands ═══\n\n", .{});

        try self.writer.printColored(.green, "  :help, :h, :?", .{});
        try self.writer.print("     Show this help\n", .{});

        try self.writer.printColored(.green, "  :quit, :q, :exit", .{});
        try self.writer.print("  Exit REPL\n", .{});

        try self.writer.printColored(.green, "  :clear, :c", .{});
        try self.writer.print("       Clear screen\n", .{});

        try self.writer.printColored(.green, "  :phi, :φ", .{});
        try self.writer.print("         Show φ (golden ratio)\n", .{});

        try self.writer.printColored(.green, "  :golden, :g", .{});
        try self.writer.print("      Show golden identity\n", .{});

        try self.writer.printColored(.green, "  :sacred, :s", .{});
        try self.writer.print("      Show sacred formula\n", .{});

        try self.writer.printColored(.green, "  :version, :v", .{});
        try self.writer.print("     Show version\n", .{});

        try self.writer.printColored(.green, "  :history", .{});
        try self.writer.print("         Show command history\n", .{});

        try self.writer.print("\n", .{});
        try self.writer.printColored(.cyan, "═══ Built-in Constants ═══\n\n", .{});
        try self.writer.print("  phi, φ    Golden ratio (1.618...)\n", .{});
        try self.writer.print("  pi, π     Pi (3.14159...)\n", .{});
        try self.writer.print("  e         Euler's number (2.718...)\n", .{});
        try self.writer.print("  golden    Golden identity (3)\n", .{});
        try self.writer.print("\n", .{});
    }

    fn cmdClear(self: *Self) !void {
        // ANSI clear screen
        try self.writer.writeAll("\x1b[2J\x1b[H");
    }

    fn cmdPhi(self: *Self) !void {
        try self.writer.printColored(.yellow, "\n  φ (PHI) = ", .{});
        try self.writer.print("{d:.15}\n", .{PHI});
        try self.writer.printColored(.yellow, "  φ²      = ", .{});
        try self.writer.print("{d:.15}\n", .{PHI_SQ});
        try self.writer.printColored(.yellow, "  1/φ²    = ", .{});
        try self.writer.print("{d:.15}\n", .{1.0 / PHI_SQ});
        try self.writer.print("\n", .{});
    }

    fn cmdGolden(self: *Self) !void {
        const phi_sq = PHI * PHI;
        const inv_phi_sq = 1.0 / phi_sq;
        const result = phi_sq + inv_phi_sq;

        try self.writer.printColored(.magenta, "\n  ═══ GOLDEN IDENTITY ═══\n\n", .{});
        try self.writer.print("  φ² + 1/φ² = {d:.15}\n", .{result});
        try self.writer.print("           = 3 ✓\n\n", .{});
    }

    fn cmdSacred(self: *Self) !void {
        try self.writer.printColored(.magenta, "\n  ═══ SACRED FORMULA ═══\n\n", .{});
        try self.writer.printColored(.yellow, "  V = n × 3^k × π^m × φ^p × e^q\n\n", .{});
        try self.writer.print("  Where:\n", .{});
        try self.writer.print("    n = base multiplier\n", .{});
        try self.writer.print("    k = power of 3 (trinity)\n", .{});
        try self.writer.print("    m = power of π (circle)\n", .{});
        try self.writer.print("    p = power of φ (golden ratio)\n", .{});
        try self.writer.print("    q = power of e (growth)\n\n", .{});
        try self.writer.printColored(.cyan, "  Golden Identity: φ² + 1/φ² = 3\n\n", .{});
    }

    fn cmdVersion(self: *Self) !void {
        try self.writer.printColored(.cyan, "\n  VIBEE REPL v", .{});
        try self.writer.print("{s}\n", .{VERSION});
        try self.writer.print("  φ = {d:.10}\n\n", .{PHI});
    }

    fn cmdHistory(self: *Self) !void {
        try self.writer.printColored(.cyan, "\n═══ Command History ═══\n\n", .{});

        if (self.history.count() == 0) {
            try self.writer.print("  (empty)\n", .{});
        } else {
            for (self.history.entries.items, 0..) |entry, i| {
                try self.writer.printColored(.dim, "  {d: >3}  ", .{i + 1});
                try self.writer.print("{s}\n", .{entry});
            }
        }
        try self.writer.print("\n", .{});
    }

    fn printBanner(self: *Self) !void {
        try self.writer.printColored(.magenta, "\n", .{});
        try self.writer.printColored(.magenta, "╔═══════════════════════════════════════════════════════════╗\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██╗   ██╗██╗██████╗ ███████╗███████╗                    ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██║   ██║██║██╔══██╗██╔════╝██╔════╝                    ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██║   ██║██║██████╔╝█████╗  █████╗                      ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝                      ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "   ╚████╔╝ ██║██████╔╝███████╗███████╗                    ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "    ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝  REPL             ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.yellow, "           V = n × 3^k × π^m × φ^p × e^q                  ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "╚═══════════════════════════════════════════════════════════╝\n", .{});
        try self.writer.print("\n", .{});
        try self.writer.print("Type :help for commands, :quit to exit\n\n", .{});
    }

    fn printPrompt(self: *Self) !void {
        try self.writer.printColored(.green, "vibee", .{});
        try self.writer.printColored(.dim, "[{d}]", .{self.line_number});
        try self.writer.printColored(.cyan, "> ", .{});
    }

    pub fn getMetrics(self: *const Self) REPLMetrics {
        return .{
            .commands_executed = self.commands_executed,
            .expressions_evaluated = self.expressions_evaluated,
            .history_size = self.history.count(),
        };
    }
};

pub const REPLMetrics = struct {
    commands_executed: u64,
    expressions_evaluated: u64,
    history_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Command parsing" {
    try std.testing.expectEqual(Command.help, Command.fromString(":help"));
    try std.testing.expectEqual(Command.help, Command.fromString(":h"));
    try std.testing.expectEqual(Command.quit, Command.fromString(":quit"));
    try std.testing.expectEqual(Command.quit, Command.fromString(":q"));
    try std.testing.expectEqual(Command.phi, Command.fromString(":phi"));
    try std.testing.expectEqual(Command.golden, Command.fromString(":golden"));
    try std.testing.expectEqual(Command.eval, Command.fromString("phi"));
    try std.testing.expectEqual(Command.eval, Command.fromString("123"));
    try std.testing.expectEqual(Command.unknown, Command.fromString(":invalid"));
}

test "History" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, 5);
    defer history.deinit();

    try history.add("first");
    try history.add("second");
    try history.add("third");

    try std.testing.expectEqual(@as(usize, 3), history.count());
    try std.testing.expectEqualStrings("first", history.get(0).?);
    try std.testing.expectEqualStrings("third", history.get(2).?);
}

test "History max size" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, 3);
    defer history.deinit();

    try history.add("1");
    try history.add("2");
    try history.add("3");
    try history.add("4"); // Should remove "1"

    try std.testing.expectEqual(@as(usize, 3), history.count());
    try std.testing.expectEqualStrings("2", history.get(0).?);
}

test "History no duplicates" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, 10);
    defer history.deinit();

    try history.add("same");
    try history.add("same");
    try history.add("same");

    try std.testing.expectEqual(@as(usize, 1), history.count());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
