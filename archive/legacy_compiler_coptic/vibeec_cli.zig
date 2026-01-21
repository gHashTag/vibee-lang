//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEEC CLI - GENERATED FROM specs/vibee_unified_compiler.vibee
//! ═══════════════════════════════════════════════════════════════════════════════
//! Command-line interface for VIBEE Compiler V2
//! Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
//! Golden Identity: φ² + 1/φ² = 3
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const unified_compiler = @import("unified_compiler.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const VERSION = "2.1.0";
pub const DEFAULT_OUTPUT_DIR = "./generated";
pub const COMPILER_NAME = "vibeec";
pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Command = enum {
    gen,
    check,
    pas,
    watch,
    help,
    version,
    unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

pub const CLI = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    compiler: unified_compiler.UnifiedCompiler,
    stdout: std.fs.File.Writer,
    stderr: std.fs.File.Writer,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .compiler = try unified_compiler.UnifiedCompiler.init(allocator),
            .stdout = std.io.getStdOut().writer(),
            .stderr = std.io.getStdErr().writer(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.compiler.deinit();
    }

    /// Run CLI with arguments
    pub fn run(self: *Self, args: []const []const u8) !u8 {
        if (args.len < 2) {
            try self.printHelp();
            return 0;
        }

        const cmd = self.parseCommand(args[1]);

        return switch (cmd) {
            .gen => try self.executeGen(args[2..]),
            .check => try self.executeCheck(args[2..]),
            .pas => try self.executePAS(args[2..]),
            .watch => try self.executeWatch(args[2..]),
            .help => {
                try self.printHelp();
                return 0;
            },
            .version => {
                try self.printVersion();
                return 0;
            },
            .unknown => {
                try self.stderr.print("Unknown command: {s}\n", .{args[1]});
                try self.printHelp();
                return 1;
            },
        };
    }

    fn parseCommand(_: *Self, arg: []const u8) Command {
        if (std.mem.eql(u8, arg, "gen") or std.mem.eql(u8, arg, "generate")) {
            return .gen;
        } else if (std.mem.eql(u8, arg, "check") or std.mem.eql(u8, arg, "validate")) {
            return .check;
        } else if (std.mem.eql(u8, arg, "pas") or std.mem.eql(u8, arg, "analyze")) {
            return .pas;
        } else if (std.mem.eql(u8, arg, "watch") or std.mem.eql(u8, arg, "w")) {
            return .watch;
        } else if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            return .help;
        } else if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            return .version;
        }
        return .unknown;
    }

    /// Execute 'gen' command
    fn executeGen(self: *Self, args: []const []const u8) !u8 {
        if (args.len < 1) {
            try self.stderr.print("Error: Missing input file\n", .{});
            try self.stderr.print("Usage: vibeec gen <spec.vibee> [options]\n", .{});
            return 1;
        }

        const input_path = args[0];

        // Parse options
        var options = unified_compiler.CompileOptions{
            .input_path = input_path,
            .target = .both,
            .enable_pas = false,
            .verbose = false,
            .output_dir = DEFAULT_OUTPUT_DIR,
        };
        var write_to_stdout = false;

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--zig") or std.mem.eql(u8, arg, "-z")) {
                options.target = .zig;
            } else if (std.mem.eql(u8, arg, "--999") or std.mem.eql(u8, arg, "-9")) {
                options.target = .code999;
            } else if (std.mem.eql(u8, arg, "--pas") or std.mem.eql(u8, arg, "-p")) {
                options.enable_pas = true;
            } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
                options.verbose = true;
            } else if (std.mem.eql(u8, arg, "--stdout")) {
                write_to_stdout = true;
            } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                if (i + 1 < args.len) {
                    i += 1;
                    options.output_dir = args[i];
                }
            }
        }

        // Read input file
        const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
            try self.stderr.print("Error: Cannot open file '{s}': {}\n", .{ input_path, err });
            return 1;
        };
        defer file.close();

        const source = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
            try self.stderr.print("Error: Cannot read file: {}\n", .{err});
            return 1;
        };
        defer self.allocator.free(source);

        // Compile
        const result = self.compiler.compile(source, options) catch |err| {
            try self.stderr.print("Error: Compilation failed: {}\n", .{err});
            return 1;
        };

        if (!result.success) {
            try self.stderr.print("Error: Compilation failed\n", .{});
            return 1;
        }

        // Write to files or stdout
        if (write_to_stdout) {
            // Output to stdout
            if (result.zig_code) |code| {
                try self.stdout.print("\n--- Generated Zig Code ---\n", .{});
                try self.stdout.print("{s}\n", .{code});
            }
            if (result.code_999) |code| {
                try self.stdout.print("\n--- Generated .999 Code ---\n", .{});
                try self.stdout.print("{s}\n", .{code});
            }
        } else {
            // Write to files
            try self.writeOutputFiles(&result, options.output_dir);
        }

        // Print summary
        try self.compiler.printSummary(&result, self.stdout);

        return 0;
    }

    /// Write generated code to files
    fn writeOutputFiles(self: *Self, result: *const unified_compiler.CompileResult, output_dir: []const u8) !void {
        // Ensure output directory exists
        std.fs.cwd().makePath(output_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                try self.stderr.print("Error: Cannot create directory '{s}': {}\n", .{ output_dir, err });
                return err;
            }
        };

        const spec_name = result.spec.name;

        // Write Zig file
        if (result.zig_code) |code| {
            const zig_filename = try std.fmt.allocPrint(self.allocator, "{s}/{s}.zig", .{ output_dir, spec_name });
            defer self.allocator.free(zig_filename);

            const zig_file = try std.fs.cwd().createFile(zig_filename, .{});
            defer zig_file.close();
            try zig_file.writeAll(code);

            try self.stdout.print("✅ Written: {s}\n", .{zig_filename});
        }

        // Write .999 file
        if (result.code_999) |code| {
            const nine_filename = try std.fmt.allocPrint(self.allocator, "{s}/{s}.999", .{ output_dir, spec_name });
            defer self.allocator.free(nine_filename);

            const nine_file = try std.fs.cwd().createFile(nine_filename, .{});
            defer nine_file.close();
            try nine_file.writeAll(code);

            try self.stdout.print("✅ Written: {s}\n", .{nine_filename});
        }
    }

    /// Execute 'check' command
    fn executeCheck(self: *Self, args: []const []const u8) !u8 {
        if (args.len < 1) {
            try self.stderr.print("Error: Missing input file\n", .{});
            try self.stderr.print("Usage: vibeec check <spec.vibee>\n", .{});
            return 1;
        }

        const input_path = args[0];

        // Read input file
        const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
            try self.stderr.print("Error: Cannot open file '{s}': {}\n", .{ input_path, err });
            return 1;
        };
        defer file.close();

        const source = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
            try self.stderr.print("Error: Cannot read file: {}\n", .{err});
            return 1;
        };
        defer self.allocator.free(source);

        // Parse only (no codegen)
        var parser = @import("parser_v2.zig").ParserV2.init(self.allocator);
        defer parser.deinit();

        const spec = parser.parse(source) catch |err| {
            try self.stderr.print("Error: Invalid specification: {}\n", .{err});
            return 1;
        };

        try self.stdout.print("✅ Valid VIBEE specification\n", .{});
        try self.stdout.print("   Name: {s}\n", .{spec.name});
        try self.stdout.print("   Version: {s}\n", .{spec.version});
        try self.stdout.print("   Behaviors: {}\n", .{spec.getBehaviorCount()});
        try self.stdout.print("   Types: {}\n", .{spec.getTypeCount()});
        try self.stdout.print("   Has Creation Pattern: {}\n", .{spec.hasCreationPattern()});

        return 0;
    }

    /// Execute 'pas' command
    fn executePAS(self: *Self, args: []const []const u8) !u8 {
        if (args.len < 1) {
            try self.stderr.print("Error: Missing subcommand\n", .{});
            try self.stderr.print("Usage: vibeec pas <analyze|predict> [args]\n", .{});
            return 1;
        }

        const subcommand = args[0];

        if (std.mem.eql(u8, subcommand, "analyze")) {
            if (args.len < 2) {
                try self.stderr.print("Error: Missing input file\n", .{});
                return 1;
            }

            const input_path = args[1];

            // Read and compile with PAS
            const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
                try self.stderr.print("Error: Cannot open file '{s}': {}\n", .{ input_path, err });
                return 1;
            };
            defer file.close();

            const source = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
                try self.stderr.print("Error: Cannot read file: {}\n", .{err});
                return 1;
            };
            defer self.allocator.free(source);

            const result = self.compiler.compile(source, .{ .enable_pas = true }) catch |err| {
                try self.stderr.print("Error: Analysis failed: {}\n", .{err});
                return 1;
            };

            try self.printPASReport(&result);
            return 0;
        } else if (std.mem.eql(u8, subcommand, "predict")) {
            if (args.len < 3) {
                try self.stderr.print("Error: Missing algorithm and complexity\n", .{});
                try self.stderr.print("Usage: vibeec pas predict <algorithm> <complexity>\n", .{});
                return 1;
            }

            const algorithm = args[1];
            const complexity = args[2];

            const prediction = self.compiler.pas_engine.predict(algorithm, complexity) catch |err| {
                try self.stderr.print("Error: Prediction failed: {}\n", .{err});
                return 1;
            };

            try self.stdout.print("\n═══════════════════════════════════════════════════════════════════════════════\n", .{});
            try self.stdout.print("PAS PREDICTION\n", .{});
            try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
            try self.stdout.print("Target: {s}\n", .{prediction.target});
            try self.stdout.print("Current: {s}\n", .{prediction.current_complexity});
            try self.stdout.print("Predicted: {s}\n", .{prediction.predicted_complexity});
            try self.stdout.print("Speedup: {d:.1}x\n", .{prediction.speedup});
            try self.stdout.print("Confidence: {d:.0}%\n", .{prediction.confidence * 100});
            try self.stdout.print("Timeline: {s}\n", .{prediction.timeline});
            try self.stdout.print("\nφ² + 1/φ² = 3\n", .{});

            return 0;
        }

        try self.stderr.print("Unknown PAS subcommand: {s}\n", .{subcommand});
        return 1;
    }

    /// Execute 'watch' command - poll-based file watching
    fn executeWatch(self: *Self, args: []const []const u8) !u8 {
        if (args.len < 1) {
            try self.stderr.print("Error: Missing watch path\n", .{});
            try self.stderr.print("Usage: vibeec watch <path> [options]\n", .{});
            return 1;
        }

        const watch_path = args[0];
        var output_dir: []const u8 = DEFAULT_OUTPUT_DIR;
        var poll_interval_ms: u64 = 1000; // 1 second default

        // Parse options
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                if (i + 1 < args.len) {
                    i += 1;
                    output_dir = args[i];
                }
            } else if (std.mem.eql(u8, arg, "--interval")) {
                if (i + 1 < args.len) {
                    i += 1;
                    poll_interval_ms = std.fmt.parseInt(u64, args[i], 10) catch 1000;
                }
            }
        }

        try self.stdout.print("\n", .{});
        try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try self.stdout.print("VIBEEC WATCH MODE V{s}\n", .{VERSION});
        try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try self.stdout.print("Watching: {s}\n", .{watch_path});
        try self.stdout.print("Output: {s}\n", .{output_dir});
        try self.stdout.print("Poll interval: {}ms\n", .{poll_interval_ms});
        try self.stdout.print("Press Ctrl+C to stop\n", .{});
        try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try self.stdout.print("\n", .{});

        // Store last modification times
        var last_mtime: i128 = 0;

        // Poll loop
        while (true) {
            // Check if path is a file or directory
            const stat = std.fs.cwd().statFile(watch_path) catch |err| {
                try self.stderr.print("Error: Cannot stat '{s}': {}\n", .{ watch_path, err });
                std.time.sleep(poll_interval_ms * 1_000_000);
                continue;
            };

            const current_mtime = stat.mtime;

            if (current_mtime != last_mtime and last_mtime != 0) {
                try self.stdout.print("\n🔄 Change detected in {s}\n", .{watch_path});

                // Recompile
                const compile_result = self.compileFile(watch_path, output_dir);
                if (compile_result) {
                    try self.stdout.print("✅ Compilation successful\n", .{});
                } else |_| {
                    try self.stderr.print("❌ Compilation failed\n", .{});
                }

                try self.stdout.print("\n⏳ Watching for changes...\n", .{});
            }

            last_mtime = current_mtime;

            // Sleep for poll interval
            std.time.sleep(poll_interval_ms * 1_000_000);
        }
    }

    /// Compile a single file (helper for watch mode)
    fn compileFile(self: *Self, path: []const u8, output_dir: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(source);

        const result = try self.compiler.compile(source, .{
            .input_path = path,
            .output_dir = output_dir,
            .target = .both,
            .enable_pas = false,
        });

        if (!result.success) {
            return error.CompilationFailed;
        }

        try self.writeOutputFiles(&result, output_dir);
    }

    fn printPASReport(self: *Self, result: *const unified_compiler.CompileResult) !void {
        try self.stdout.print("\n═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try self.stdout.print("PAS ANALYSIS REPORT\n", .{});
        try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
        try self.stdout.print("Specification: {s}\n", .{result.spec.name});

        if (result.pas_report) |report| {
            try self.stdout.print("\nPredictions:\n", .{});
            for (report.predictions) |pred| {
                try self.stdout.print("  • {s}\n", .{pred.target});
                try self.stdout.print("    Current: {s} → Predicted: {s}\n", .{ pred.current_complexity, pred.predicted_complexity });
                try self.stdout.print("    Speedup: {d:.1}x, Confidence: {d:.0}%\n", .{ pred.speedup, pred.confidence * 100 });
            }

            try self.stdout.print("\nSummary:\n", .{});
            try self.stdout.print("  Total Speedup: {d:.1}x\n", .{report.total_speedup});
            try self.stdout.print("  Avg Confidence: {d:.0}%\n", .{report.avg_confidence * 100});
        }

        try self.stdout.print("\nφ² + 1/φ² = 3\n", .{});
        try self.stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    }

    pub fn printHelp(self: *Self) !void {
        try self.stdout.print(
            \\
            \\═══════════════════════════════════════════════════════════════════════════════
            \\VIBEEC - VIBEE Compiler V{s}
            \\═══════════════════════════════════════════════════════════════════════════════
            \\
            \\USAGE:
            \\  vibeec <command> [options]
            \\
            \\COMMANDS:
            \\  gen <spec.vibee>     Generate code from specification
            \\    --zig, -z          Generate Zig code only
            \\    --999, -9          Generate .999 code only
            \\    --pas, -p          Enable PAS optimization analysis
            \\    --output, -o DIR   Output directory (default: ./generated)
            \\    --stdout           Print to stdout instead of files
            \\    --verbose, -v      Verbose output
            \\
            \\  check <spec.vibee>   Validate specification
            \\
            \\  watch <path>         Watch for changes and auto-recompile
            \\    --output, -o DIR   Output directory
            \\    --interval MS      Poll interval in ms (default: 1000)
            \\
            \\  pas analyze <spec>   PAS analysis of specification
            \\  pas predict ALG CMP  Predict improvement for algorithm
            \\
            \\  help                 Show this help
            \\  version              Show version
            \\
            \\SACRED FORMULA:
            \\  V = n × 3^k × π^m × φ^p × e^q
            \\  φ² + 1/φ² = 3
            \\
            \\═══════════════════════════════════════════════════════════════════════════════
            \\
        , .{VERSION});
    }

    pub fn printVersion(self: *Self) !void {
        try self.stdout.print(
            \\vibeec {s}
            \\VIBEE Compiler - Specification-First Development
            \\φ² + 1/φ² = 3
            \\
        , .{VERSION});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cli = try CLI.init(allocator);
    defer cli.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    return cli.run(args);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CLI parseCommand" {
    var cli = try CLI.init(std.testing.allocator);
    defer cli.deinit();

    try std.testing.expectEqual(Command.gen, cli.parseCommand("gen"));
    try std.testing.expectEqual(Command.gen, cli.parseCommand("generate"));
    try std.testing.expectEqual(Command.check, cli.parseCommand("check"));
    try std.testing.expectEqual(Command.pas, cli.parseCommand("pas"));
    try std.testing.expectEqual(Command.help, cli.parseCommand("help"));
    try std.testing.expectEqual(Command.help, cli.parseCommand("-h"));
    try std.testing.expectEqual(Command.version, cli.parseCommand("version"));
    try std.testing.expectEqual(Command.unknown, cli.parseCommand("invalid"));
}
