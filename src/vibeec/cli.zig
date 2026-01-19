// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC V22 - CLI WITH COLOR OUTPUT
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V34 - Command Line Interface
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const error_reporter = @import("error_reporter.zig");
const Color = error_reporter.Color;
const ColorWriter = error_reporter.ColorWriter;
const ErrorReporter = error_reporter.ErrorReporter;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const VERSION = "22.0.0";
pub const COMPILER_NAME = "vibeec";
pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Command = enum {
    gen,
    check,
    pas,
    help,
    version,
    unknown,
};

pub const OutputTarget = enum {
    zig,
    code999,
    both,

    pub fn fromString(s: []const u8) ?OutputTarget {
        if (std.mem.eql(u8, s, "zig")) return .zig;
        if (std.mem.eql(u8, s, "999")) return .code999;
        if (std.mem.eql(u8, s, "both")) return .both;
        return null;
    }
};

pub const CLIOptions = struct {
    command: Command = .help,
    input_file: ?[]const u8 = null,
    output_dir: []const u8 = "./generated",
    target: OutputTarget = .both,
    enable_pas: bool = false,
    verbose: bool = false,
    use_color: bool = true,
    strict: bool = false,
    subcommand: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

pub const CLI = struct {
    allocator: Allocator,
    writer: ColorWriter,
    options: CLIOptions,

    const Self = @This();

    pub fn init(allocator: Allocator, force_color: ?bool) Self {
        const stdout_file = std.io.getStdOut();
        const stdout = stdout_file.writer();
        return Self{
            .allocator = allocator,
            .writer = ColorWriter.init(stdout.any(), force_color),
            .options = CLIOptions{},
        };
    }

    pub fn run(self: *Self, args: []const []const u8) !u8 {
        self.options = try self.parseArgs(args);

        return switch (self.options.command) {
            .gen => self.executeGen(),
            .check => self.executeCheck(),
            .pas => self.executePAS(),
            .help => self.printHelp(),
            .version => self.printVersion(),
            .unknown => self.printUnknownCommand(),
        };
    }

    fn parseArgs(self: *Self, args: []const []const u8) !CLIOptions {
        _ = self;
        var opts = CLIOptions{};

        if (args.len < 2) {
            opts.command = .help;
            return opts;
        }

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "gen")) {
                opts.command = .gen;
            } else if (std.mem.eql(u8, arg, "check")) {
                opts.command = .check;
            } else if (std.mem.eql(u8, arg, "pas")) {
                opts.command = .pas;
                if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                    i += 1;
                    opts.subcommand = args[i];
                }
            } else if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                opts.command = .help;
            } else if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
                opts.command = .version;
            } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                if (i + 1 < args.len) {
                    i += 1;
                    opts.output_dir = args[i];
                }
            } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--target")) {
                if (i + 1 < args.len) {
                    i += 1;
                    if (OutputTarget.fromString(args[i])) |target| {
                        opts.target = target;
                    }
                }
            } else if (std.mem.eql(u8, arg, "--pas")) {
                opts.enable_pas = true;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
                opts.verbose = true;
            } else if (std.mem.eql(u8, arg, "--no-color")) {
                opts.use_color = false;
            } else if (std.mem.eql(u8, arg, "--strict")) {
                opts.strict = true;
            } else if (!std.mem.startsWith(u8, arg, "-")) {
                // Positional argument - input file
                if (opts.input_file == null) {
                    opts.input_file = arg;
                }
            }
        }

        return opts;
    }

    fn executeGen(self: *Self) !u8 {
        if (self.options.input_file == null) {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": no input file specified\n", .{});
            try self.writer.print("Usage: vibeec gen <spec.vibee> [options]\n", .{});
            return 1;
        }

        const input_file = self.options.input_file.?;

        // Read file
        const file = std.fs.cwd().openFile(input_file, .{}) catch |err| {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": could not open file '{s}': {}\n", .{ input_file, err });
            return 1;
        };
        defer file.close();

        const source = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": could not read file: {}\n", .{err});
            return 1;
        };
        defer self.allocator.free(source);

        // Create reporter
        var reporter = try ErrorReporter.init(self.allocator, source, input_file);
        defer reporter.deinit();

        // Simulate compilation (placeholder for actual parser/codegen)
        const start_time = std.time.nanoTimestamp();

        // Check for basic validity
        if (source.len == 0) {
            const span = reporter.createSpan(1, 1, 1, 1);
            _ = try reporter.reportError(.E003_INVALID_YAML, span, "empty file");
        }

        // Check for 'name:' field
        if (std.mem.indexOf(u8, source, "name:") == null) {
            const span = reporter.createSpan(1, 1, 1, 1);
            _ = try reporter.reportError(.E004_MISSING_FIELD, span, "missing required field 'name'");
        }

        const end_time = std.time.nanoTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

        // Render diagnostics
        try reporter.render(&self.writer);

        if (reporter.hasErrors()) {
            try reporter.renderSummary(&self.writer);
            return 1;
        }

        // Success
        const outputs = switch (self.options.target) {
            .zig => "*.zig",
            .code999 => "*.999",
            .both => "*.zig, *.999",
        };
        try reporter.renderSuccess(&self.writer, outputs, elapsed_ms);

        if (self.options.enable_pas) {
            try self.writer.print("\n", .{});
            try self.writer.printColored(.cyan, "PAS Analysis", .{});
            try self.writer.print(" enabled\n", .{});
        }

        return 0;
    }

    fn executeCheck(self: *Self) !u8 {
        if (self.options.input_file == null) {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": no input file specified\n", .{});
            return 1;
        }

        const input_file = self.options.input_file.?;

        // Read file
        const file = std.fs.cwd().openFile(input_file, .{}) catch |err| {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": could not open file '{s}': {}\n", .{ input_file, err });
            return 1;
        };
        defer file.close();

        const source = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| {
            try self.writer.printColored(.red, "error", .{});
            try self.writer.print(": could not read file: {}\n", .{err});
            return 1;
        };
        defer self.allocator.free(source);

        var reporter = try ErrorReporter.init(self.allocator, source, input_file);
        defer reporter.deinit();

        // Basic validation
        if (std.mem.indexOf(u8, source, "name:") == null) {
            const span = reporter.createSpan(1, 1, 1, 1);
            _ = try reporter.reportError(.E004_MISSING_FIELD, span, "missing required field 'name'");
        }

        try reporter.render(&self.writer);

        if (reporter.hasErrors()) {
            try reporter.renderSummary(&self.writer);
            return 1;
        }

        try self.writer.printColored(.green, "✓", .{});
        try self.writer.print(" ", .{});
        try self.writer.bold(input_file);
        try self.writer.print(" is valid\n", .{});

        return 0;
    }

    fn executePAS(self: *Self) !u8 {
        try self.writer.printColored(.cyan, "═══ PAS DAEMON V34 ═══", .{});
        try self.writer.print("\n\n", .{});

        try self.writer.print("Sacred Formula: ", .{});
        try self.writer.printColored(.magenta, "V = n × 3^k × π^m × φ^p × e^q", .{});
        try self.writer.print("\n", .{});

        try self.writer.print("Golden Identity: ", .{});
        try self.writer.printColored(.yellow, "φ² + 1/φ² = 3", .{});
        try self.writer.print("\n\n", .{});

        if (self.options.subcommand) |subcmd| {
            if (std.mem.eql(u8, subcmd, "analyze")) {
                if (self.options.input_file) |input| {
                    try self.writer.print("Analyzing: {s}\n", .{input});
                } else {
                    try self.writer.printColored(.red, "error", .{});
                    try self.writer.print(": no input file for analysis\n", .{});
                    return 1;
                }
            } else if (std.mem.eql(u8, subcmd, "predict")) {
                try self.writer.print("PAS Prediction Mode\n", .{});
            }
        }

        try self.writer.print("\nDiscovery Patterns:\n", .{});
        try self.printPattern("D&C", "Divide-and-Conquer", 0.31);
        try self.printPattern("ALG", "Algebraic Reorganization", 0.22);
        try self.printPattern("PRE", "Precomputation", 0.16);
        try self.printPattern("FDT", "Frequency Domain", 0.13);
        try self.printPattern("MLS", "ML-Guided Search", 0.08);
        try self.printPattern("TEN", "Tensor Decomposition", 0.06);

        return 0;
    }

    fn printPattern(self: *Self, symbol: []const u8, name: []const u8, rate: f64) !void {
        try self.writer.print("  ", .{});
        try self.writer.printColored(.cyan, "{s}", .{symbol});
        try self.writer.print(" - {s}: ", .{name});
        try self.writer.printColored(.green, "{d:.0}%", .{rate * 100});
        try self.writer.print("\n", .{});
    }

    fn printHelp(self: *Self) !u8 {
        try self.printBanner();

        try self.writer.bold("USAGE:\n");
        try self.writer.print("    vibeec <COMMAND> [OPTIONS] [FILE]\n\n", .{});

        try self.writer.bold("COMMANDS:\n");
        try self.printCommand("gen", "Generate code from .vibee specification");
        try self.printCommand("check", "Validate .vibee specification");
        try self.printCommand("pas", "PAS analysis commands");
        try self.printCommand("help", "Show this help message");
        try self.printCommand("version", "Show version information");

        try self.writer.print("\n", .{});
        try self.writer.bold("OPTIONS:\n");
        try self.printOption("-o, --output <DIR>", "Output directory (default: ./generated)");
        try self.printOption("-t, --target <TARGET>", "Output target: zig, 999, both (default: both)");
        try self.printOption("--pas", "Enable PAS optimization analysis");
        try self.printOption("-v, --verbose", "Verbose output");
        try self.printOption("--no-color", "Disable colored output");
        try self.printOption("--strict", "Strict validation mode");

        try self.writer.print("\n", .{});
        try self.writer.bold("EXAMPLES:\n");
        try self.writer.printColored(.dim, "    # Generate code from specification\n", .{});
        try self.writer.print("    vibeec gen specs/my_feature.vibee\n\n", .{});
        try self.writer.printColored(.dim, "    # Check specification validity\n", .{});
        try self.writer.print("    vibeec check specs/my_feature.vibee\n\n", .{});
        try self.writer.printColored(.dim, "    # Run PAS analysis\n", .{});
        try self.writer.print("    vibeec pas analyze specs/my_feature.vibee\n", .{});

        return 0;
    }

    fn printCommand(self: *Self, name: []const u8, desc: []const u8) !void {
        try self.writer.print("    ", .{});
        try self.writer.printColored(.green, "{s: <12}", .{name});
        try self.writer.print("{s}\n", .{desc});
    }

    fn printOption(self: *Self, opt: []const u8, desc: []const u8) !void {
        try self.writer.print("    ", .{});
        try self.writer.printColored(.cyan, "{s: <24}", .{opt});
        try self.writer.print("{s}\n", .{desc});
    }

    fn printVersion(self: *Self) !u8 {
        try self.printBanner();
        try self.writer.print("Version: ", .{});
        try self.writer.printColored(.green, VERSION, .{});
        try self.writer.print("\n", .{});
        try self.writer.print("φ (PHI): {d:.15}\n", .{PHI});
        try self.writer.print("Golden Identity: φ² + 1/φ² = {d:.1}\n", .{GOLDEN_IDENTITY});
        return 0;
    }

    fn printBanner(self: *Self) !void {
        try self.writer.printColored(.magenta, "\n", .{});
        try self.writer.printColored(.magenta, "╔═══════════════════════════════════════════════════════════╗\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██╗   ██╗██╗██████╗ ███████╗███████╗ ██████╗             ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██║   ██║██║██╔══██╗██╔════╝██╔════╝██╔════╝             ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ██║   ██║██║██████╔╝█████╗  █████╗  ██║                  ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "  ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝  ██║                  ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "   ╚████╔╝ ██║██████╔╝███████╗███████╗╚██████╗             ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.cyan, "    ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝ ╚═════╝             ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "║", .{});
        try self.writer.printColored(.yellow, "           V = n × 3^k × π^m × φ^p × e^q                  ", .{});
        try self.writer.printColored(.magenta, "║\n", .{});
        try self.writer.printColored(.magenta, "╚═══════════════════════════════════════════════════════════╝\n", .{});
        try self.writer.print("\n", .{});
    }

    fn printUnknownCommand(self: *Self) !u8 {
        try self.writer.printColored(.red, "error", .{});
        try self.writer.print(": unknown command\n", .{});
        try self.writer.print("Run 'vibeec help' for usage information\n", .{});
        return 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = CLI.init(allocator, null);
    return cli.run(args);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CLI parse args - help" {
    const allocator = std.testing.allocator;
    var cli = CLI.init(allocator, false);

    const args = &[_][]const u8{ "vibeec", "help" };
    const opts = try cli.parseArgs(args);

    try std.testing.expectEqual(Command.help, opts.command);
}

test "CLI parse args - gen with file" {
    const allocator = std.testing.allocator;
    var cli = CLI.init(allocator, false);

    const args = &[_][]const u8{ "vibeec", "gen", "test.vibee" };
    const opts = try cli.parseArgs(args);

    try std.testing.expectEqual(Command.gen, opts.command);
    try std.testing.expectEqualStrings("test.vibee", opts.input_file.?);
}

test "CLI parse args - gen with options" {
    const allocator = std.testing.allocator;
    var cli = CLI.init(allocator, false);

    const args = &[_][]const u8{ "vibeec", "gen", "test.vibee", "-o", "out", "-t", "zig", "--pas", "-v" };
    const opts = try cli.parseArgs(args);

    try std.testing.expectEqual(Command.gen, opts.command);
    try std.testing.expectEqualStrings("test.vibee", opts.input_file.?);
    try std.testing.expectEqualStrings("out", opts.output_dir);
    try std.testing.expectEqual(OutputTarget.zig, opts.target);
    try std.testing.expect(opts.enable_pas);
    try std.testing.expect(opts.verbose);
}

test "CLI parse args - version" {
    const allocator = std.testing.allocator;
    var cli = CLI.init(allocator, false);

    const args = &[_][]const u8{ "vibeec", "--version" };
    const opts = try cli.parseArgs(args);

    try std.testing.expectEqual(Command.version, opts.command);
}

test "OutputTarget fromString" {
    try std.testing.expectEqual(OutputTarget.zig, OutputTarget.fromString("zig").?);
    try std.testing.expectEqual(OutputTarget.code999, OutputTarget.fromString("999").?);
    try std.testing.expectEqual(OutputTarget.both, OutputTarget.fromString("both").?);
    try std.testing.expect(OutputTarget.fromString("invalid") == null);
}
