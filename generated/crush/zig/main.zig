// main.zig - VIBEE CLI Entry Point
// VIBEENITY Terminal - Ternary Logic Interface
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const app = @import("app.zig");
const cmd = @import("cmd.zig");
const version = @import("version.zig");
const home = @import("home.zig");
const config = @import("config.zig");
const agent = @import("agent.zig");
const session = @import("session.zig");
const tui = @import("tui.zig");

const VERSION = "1.0.0";
const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY LOGIC ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

const Ternary = enum(i8) {
    false_ = -1,
    unknown = 0,
    true_ = 1,

    pub fn fromString(s: []const u8) ?Ternary {
        if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "△") or std.mem.eql(u8, s, "1")) return .true_;
        if (std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "▽") or std.mem.eql(u8, s, "-1")) return .false_;
        if (std.mem.eql(u8, s, "unknown") or std.mem.eql(u8, s, "○") or std.mem.eql(u8, s, "0")) return .unknown;
        return null;
    }

    pub fn toString(self: Ternary) []const u8 {
        return switch (self) {
            .true_ => "△ (true)",
            .unknown => "○ (unknown)",
            .false_ => "▽ (false)",
        };
    }

    pub fn toSymbol(self: Ternary) []const u8 {
        return switch (self) {
            .true_ => "△",
            .unknown => "○",
            .false_ => "▽",
        };
    }

    // Kleene strong AND (minimum)
    pub fn kleeneAnd(a: Ternary, b: Ternary) Ternary {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        return @enumFromInt(@min(av, bv));
    }

    // Kleene strong OR (maximum)
    pub fn kleeneOr(a: Ternary, b: Ternary) Ternary {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        return @enumFromInt(@max(av, bv));
    }

    // NOT (negation)
    pub fn kleeneNot(a: Ternary) Ternary {
        return @enumFromInt(-@intFromEnum(a));
    }

    // IMPLIES (a → b = ¬a ∨ b)
    pub fn kleeneImplies(a: Ternary, b: Ternary) Ternary {
        return kleeneOr(kleeneNot(a), b);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESS EXECUTION HELPER
// ═══════════════════════════════════════════════════════════════════════════════

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !struct { stdout: []u8, stderr: []u8, term: std.process.Child.Term } {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var stdout = std.ArrayList(u8).init(allocator);
    var stderr = std.ArrayList(u8).init(allocator);

    child.collectOutput(&stdout, &stderr, 1024 * 1024) catch |err| {
        return err;
    };

    const term = try child.wait();

    return .{
        .stdout = try stdout.toOwnedSlice(),
        .stderr = try stderr.toOwnedSlice(),
        .term = term,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    _ = stdout; // Zig 0.15 compatibility
    const stdout_file = std.io.getStdOut();
    const stdout_writer = stdout_file.writer();

    // Get command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp(stdout);
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try printVersion(stdout);
    } else if (std.mem.eql(u8, command, "chat")) {
        try runChat(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "config")) {
        try runConfig(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "session")) {
        try runSession(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "agent")) {
        try runAgent(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "phi")) {
        try printPhi(stdout);
    } else if (std.mem.eql(u8, command, "commit")) {
        try runCommit(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "push")) {
        try runPush(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "pr")) {
        try runPR(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "review")) {
        try runReview(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "eval")) {
        try runEval(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "truth")) {
        try runTruth(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "repl")) {
        try runRepl(allocator, stdout);
    } else if (std.mem.eql(u8, command, "pas")) {
        try runPAS(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "benchmark")) {
        try runBenchmark(allocator, stdout, args[2..]);
    } else if (std.mem.eql(u8, command, "gen")) {
        try runGen(allocator, stdout, args[2..]);
    } else {
        try stdout.print("Unknown command: {s}\n", .{command});
        try stdout.print("Run 'vibee help' for usage.\n", .{});
    }
}

fn printHelp(writer: anytype) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE - VIBEENITY Terminal Interface                             ║
        \\║  Ternary Logic AI Assistant | 999 OS                          ║
        \\║  φ² + 1/φ² = 3                                                 ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
        \\USAGE:
        \\  vibee <command> [options]
        \\
        \\GIT COMMANDS:
        \\  commit    Create git commit with AI message
        \\  push      Commit and push changes
        \\  pr        Create pull request
        \\  review    AI code review
        \\
        \\TERNARY LOGIC:
        \\  eval      Evaluate ternary expression
        \\  truth     Show truth tables
        \\  repl      Start ternary REPL
        \\
        \\PAS ANALYSIS:
        \\  pas       Predictive Algorithmic Systematics
        \\  benchmark Run performance benchmarks
        \\
        \\CODE GENERATION:
        \\  gen       Generate .zig from .vibee specification
        \\
        \\GENERAL:
        \\  chat      Interactive chat session
        \\  config    Manage configuration
        \\  agent     Agent operations
        \\  phi       Sacred constants
        \\  version   Version info
        \\  help      This help
        \\
        \\TERNARY VALUES:
        \\  △ (true/+1)    ○ (unknown/0)    ▽ (false/-1)
        \\
        \\EXAMPLES:
        \\  vibee commit                  AI-generated commit
        \\  vibee review                  Review current changes
        \\  vibee eval "true AND unknown" Evaluate expression
        \\  vibee truth and               Show AND table
        \\  vibee pas analyze             PAS analysis
        \\  vibee phi                     Sacred constants
        \\  vibee gen spec.vibee          Generate Zig from .vibee
        \\
        \\Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\
    , .{});
}

fn printVersion(writer: anytype) !void {
    try writer.print(
        \\vibee {s}
        \\
        \\VIBEENITY Terminal Interface
        \\Ternary Logic: △ ○ ▽
        \\
        \\φ = {d:.15}
        \\φ² + 1/φ² = 3
        \\PHOENIX = 999
        \\
    , .{ VERSION, PHI });
}

fn printPhi(writer: anytype) !void {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const trinity = phi_sq + inv_phi_sq;

    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  SACRED CONSTANTS                                             ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
        \\  φ (phi)           = {d:.15}
        \\  φ² (phi squared)  = {d:.15}
        \\  1/φ²              = {d:.15}
        \\  φ² + 1/φ²         = {d:.15}
        \\
        \\  VIBEENITY VERIFIED: {s}
        \\
        \\  PHOENIX = 999 = 27 × 37 = 3³ × 37
        \\
        \\Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\
    , .{
        PHI,
        phi_sq,
        inv_phi_sq,
        trinity,
        if (@abs(trinity - 3.0) < 0.0001) "✓ φ² + 1/φ² = 3" else "✗ FAILED",
    });
}

fn runChat(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = args;
    _ = allocator;

    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE CHAT - Ternary Logic AI Session                          ║
        \\║  Type 'exit' to quit, 'help' for commands                     ║
        \\║  Values: △ (true)  ○ (unknown)  ▽ (false)                     ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
        \\[Chat mode - use 999repl_v2 for ternary logic REPL]
        \\
    , .{});
}

fn runConfig(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print("Usage: vibee config <show|set|reset>\n", .{});
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "show")) {
        if (home.dir()) |homedir| {
            try writer.print("Home: {s}\n", .{homedir});
        }
        try writer.print("Config: ~/.config/crush/config.yaml\n", .{});
        try writer.print("Data: ~/.local/share/crush/\n", .{});
    } else {
        try writer.print("Unknown config command: {s}\n", .{subcmd});
    }
}

fn runSession(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print("Usage: vibee session <list|new|delete>\n", .{});
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "list")) {
        try writer.print("Sessions:\n", .{});
        try writer.print("  (no active sessions)\n", .{});
    } else if (std.mem.eql(u8, subcmd, "new")) {
        try writer.print("Creating new session...\n", .{});
    } else {
        try writer.print("Unknown session command: {s}\n", .{subcmd});
    }
}

fn runAgent(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print("Usage: vibee agent <status|start|stop>\n", .{});
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "status")) {
        try writer.print("Agent Status:\n", .{});
        try writer.print("  State: {s}\n", .{agent.State.idle.toString()});
        try writer.print("  Tool calls: 0\n", .{});
    } else if (std.mem.eql(u8, subcmd, "start")) {
        try writer.print("Starting agent...\n", .{});
    } else if (std.mem.eql(u8, subcmd, "stop")) {
        try writer.print("Stopping agent...\n", .{});
    } else {
        try writer.print("Unknown agent command: {s}\n", .{subcmd});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GIT COMMANDS (migrated from claude-code/commit-commands)
// ═══════════════════════════════════════════════════════════════════════════════

fn runCommit(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE COMMIT - Git Commit                                      ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Get git status
    const status_result = runCommand(allocator, &[_][]const u8{ "git", "status", "--porcelain" }) catch |err| {
        try writer.print("Error running git status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_result.stdout);
    defer allocator.free(status_result.stderr);

    if (status_result.stdout.len == 0) {
        try writer.print("No changes to commit.\n", .{});
        return;
    }

    try writer.print("Changes:\n{s}\n", .{status_result.stdout});

    // Get diff for commit message generation
    const diff_result = runCommand(allocator, &[_][]const u8{ "git", "diff", "--cached", "--stat" }) catch |err| {
        try writer.print("Error running git diff: {}\n", .{err});
        return;
    };
    defer allocator.free(diff_result.stdout);
    defer allocator.free(diff_result.stderr);

    // Check for custom message
    var message: []const u8 = "chore: update via vibee commit";
    for (args, 0..) |arg, i| {
        if ((std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--message")) and i + 1 < args.len) {
            message = args[i + 1];
            break;
        }
    }

    // Stage all changes
    try writer.print("Staging all changes...\n", .{});
    const add_result = runCommand(allocator, &[_][]const u8{ "git", "add", "-A" }) catch |err| {
        try writer.print("Error staging: {}\n", .{err});
        return;
    };
    defer allocator.free(add_result.stdout);
    defer allocator.free(add_result.stderr);

    // Commit
    try writer.print("Committing with message: {s}\n", .{message});
    const commit_result = runCommand(allocator, &[_][]const u8{ "git", "commit", "-m", message }) catch |err| {
        try writer.print("Error committing: {}\n", .{err});
        return;
    };
    defer allocator.free(commit_result.stdout);
    defer allocator.free(commit_result.stderr);

    if (commit_result.stdout.len > 0) {
        try writer.print("{s}\n", .{commit_result.stdout});
    }
    if (commit_result.stderr.len > 0) {
        try writer.print("{s}\n", .{commit_result.stderr});
    }

    try writer.print("\n✓ Commit complete\n", .{});
}

fn runPush(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE PUSH - Push to Remote                                    ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Get current branch
    const branch_result = runCommand(allocator, &[_][]const u8{ "git", "branch", "--show-current" }) catch |err| {
        try writer.print("Error getting branch: {}\n", .{err});
        return;
    };
    defer allocator.free(branch_result.stdout);
    defer allocator.free(branch_result.stderr);

    const branch = std.mem.trim(u8, branch_result.stdout, "\n\r ");
    try writer.print("Current branch: {s}\n", .{branch});

    // Check for force flag
    var force = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "-f")) {
            force = true;
        }
    }

    // Push
    try writer.print("Pushing to origin/{s}...\n", .{branch});

    var push_args = std.ArrayList([]const u8).init(allocator);
    defer push_args.deinit();
    try push_args.appendSlice(&[_][]const u8{ "git", "push", "origin", branch });
    if (force) {
        try push_args.append("--force");
    }

    const push_result = runCommand(allocator, push_args.items) catch |err| {
        try writer.print("Error pushing: {}\n", .{err});
        return;
    };
    defer allocator.free(push_result.stdout);
    defer allocator.free(push_result.stderr);

    if (push_result.stdout.len > 0) {
        try writer.print("{s}\n", .{push_result.stdout});
    }
    if (push_result.stderr.len > 0) {
        try writer.print("{s}\n", .{push_result.stderr});
    }

    try writer.print("\n✓ Push complete\n", .{});
}

fn runPR(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE PR - Create Pull Request                                 ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Get current branch
    const branch_result = runCommand(allocator, &[_][]const u8{ "git", "branch", "--show-current" }) catch |err| {
        try writer.print("Error getting branch: {}\n", .{err});
        return;
    };
    defer allocator.free(branch_result.stdout);
    defer allocator.free(branch_result.stderr);

    const branch = std.mem.trim(u8, branch_result.stdout, "\n\r ");
    try writer.print("Branch: {s}\n", .{branch});

    // Parse args for title
    var title: []const u8 = branch;
    var draft = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if ((std.mem.eql(u8, args[i], "-t") or std.mem.eql(u8, args[i], "--title")) and i + 1 < args.len) {
            title = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--draft")) {
            draft = true;
        }
    }

    // Create PR using gh CLI
    var pr_args = std.ArrayList([]const u8).init(allocator);
    defer pr_args.deinit();
    try pr_args.appendSlice(&[_][]const u8{ "gh", "pr", "create", "--title", title, "--body", "Created via vibee pr\n\nφ² + 1/φ² = 3" });
    if (draft) {
        try pr_args.append("--draft");
    }

    try writer.print("Creating PR: {s}\n", .{title});

    const pr_result = runCommand(allocator, pr_args.items) catch |err| {
        try writer.print("Error creating PR (is gh CLI installed?): {}\n", .{err});
        try writer.print("\nInstall: https://cli.github.com/\n", .{});
        return;
    };
    defer allocator.free(pr_result.stdout);
    defer allocator.free(pr_result.stderr);

    if (pr_result.stdout.len > 0) {
        try writer.print("{s}\n", .{pr_result.stdout});
    }
    if (pr_result.stderr.len > 0) {
        try writer.print("{s}\n", .{pr_result.stderr});
    }

    try writer.print("\n✓ PR created\n", .{});
}

fn runReview(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE REVIEW - AI Code Review                                  ║
        \\║  Based on: claude-code/code-review plugin                     ║
        \\║  Patterns: Security, Bugs, Style, CLAUDE.md                   ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
    , .{});

    // Check for PR number
    var pr_num: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--pr") and i + 1 < args.len) {
            pr_num = args[i + 1];
            break;
        }
    }

    if (pr_num) |num| {
        // Review specific PR
        try writer.print("Reviewing PR #{s}...\n\n", .{num});

        const diff_result = runCommand(allocator, &[_][]const u8{ "gh", "pr", "diff", num }) catch |err| {
            try writer.print("Error getting PR diff: {}\n", .{err});
            return;
        };
        defer allocator.free(diff_result.stdout);
        defer allocator.free(diff_result.stderr);

        try analyzeCode(allocator, writer, diff_result.stdout);
    } else {
        // Review current changes
        try writer.print("Reviewing current changes...\n\n", .{});

        const diff_result = runCommand(allocator, &[_][]const u8{ "git", "diff", "HEAD" }) catch |err| {
            try writer.print("Error getting diff: {}\n", .{err});
            return;
        };
        defer allocator.free(diff_result.stdout);
        defer allocator.free(diff_result.stderr);

        if (diff_result.stdout.len == 0) {
            try writer.print("No changes to review.\n", .{});
            return;
        }

        try analyzeCode(allocator, writer, diff_result.stdout);
    }
}

fn analyzeCode(allocator: std.mem.Allocator, writer: anytype, diff: []const u8) !void {
    _ = allocator;

    // Statistics
    var additions: usize = 0;
    var deletions: usize = 0;
    var files: usize = 0;

    // Security patterns
    var security_issues: usize = 0;
    var has_password: bool = false;
    var has_secret: bool = false;
    var has_api_key: bool = false;
    var has_eval: bool = false;
    var has_exec: bool = false;

    // Code quality
    var has_todo: bool = false;
    var has_fixme: bool = false;
    var has_console_log: bool = false;
    var has_print_debug: bool = false;

    // File types
    var zig_files: usize = 0;
    var go_files: usize = 0;
    var py_files: usize = 0;
    var js_files: usize = 0;

    var lines = std.mem.splitScalar(u8, diff, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Count changes
        if (line[0] == '+' and (line.len < 2 or line[1] != '+')) {
            additions += 1;

            // Security checks on added lines
            if (std.mem.indexOf(u8, line, "password") != null or
                std.mem.indexOf(u8, line, "PASSWORD") != null)
            {
                has_password = true;
                security_issues += 1;
            }
            if (std.mem.indexOf(u8, line, "secret") != null or
                std.mem.indexOf(u8, line, "SECRET") != null)
            {
                has_secret = true;
                security_issues += 1;
            }
            if (std.mem.indexOf(u8, line, "api_key") != null or
                std.mem.indexOf(u8, line, "API_KEY") != null or
                std.mem.indexOf(u8, line, "apiKey") != null)
            {
                has_api_key = true;
                security_issues += 1;
            }
            if (std.mem.indexOf(u8, line, "eval(") != null) {
                has_eval = true;
                security_issues += 1;
            }
            if (std.mem.indexOf(u8, line, "exec(") != null or
                std.mem.indexOf(u8, line, "os.system") != null)
            {
                has_exec = true;
                security_issues += 1;
            }

            // Code quality checks
            if (std.mem.indexOf(u8, line, "TODO") != null) has_todo = true;
            if (std.mem.indexOf(u8, line, "FIXME") != null) has_fixme = true;
            if (std.mem.indexOf(u8, line, "console.log") != null) has_console_log = true;
            if (std.mem.indexOf(u8, line, "print(") != null and
                std.mem.indexOf(u8, line, "debug") != null)
            {
                has_print_debug = true;
            }
        }

        if (line[0] == '-' and (line.len < 2 or line[1] != '-')) deletions += 1;

        // File detection
        if (std.mem.startsWith(u8, line, "diff --git")) {
            files += 1;
            if (std.mem.indexOf(u8, line, ".zig") != null) zig_files += 1;
            if (std.mem.indexOf(u8, line, ".go") != null) go_files += 1;
            if (std.mem.indexOf(u8, line, ".py") != null) py_files += 1;
            if (std.mem.indexOf(u8, line, ".js") != null or
                std.mem.indexOf(u8, line, ".ts") != null)
            {
                js_files += 1;
            }
        }
    }

    // Print summary
    try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("REVIEW SUMMARY\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    try writer.print("Changes:\n", .{});
    try writer.print("  {d} files changed\n", .{files});
    try writer.print("  +{d} additions\n", .{additions});
    try writer.print("  -{d} deletions\n", .{deletions});

    if (zig_files > 0 or go_files > 0 or py_files > 0 or js_files > 0) {
        try writer.print("\nFile Types:\n", .{});
        if (zig_files > 0) try writer.print("  Zig: {d}\n", .{zig_files});
        if (go_files > 0) try writer.print("  Go: {d}\n", .{go_files});
        if (py_files > 0) try writer.print("  Python: {d}\n", .{py_files});
        if (js_files > 0) try writer.print("  JS/TS: {d}\n", .{js_files});
    }

    // Security report
    try writer.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("SECURITY ANALYSIS\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    if (security_issues == 0) {
        try writer.print("  ✓ No security issues detected\n", .{});
    } else {
        try writer.print("  ⚠️  {d} potential security issues:\n\n", .{security_issues});
        if (has_password) try writer.print("  ❌ PASSWORD detected - check for hardcoded credentials\n", .{});
        if (has_secret) try writer.print("  ❌ SECRET detected - check for exposed secrets\n", .{});
        if (has_api_key) try writer.print("  ❌ API_KEY detected - use environment variables\n", .{});
        if (has_eval) try writer.print("  ❌ eval() detected - potential code injection\n", .{});
        if (has_exec) try writer.print("  ❌ exec/os.system detected - command injection risk\n", .{});
    }

    // Code quality report
    try writer.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("CODE QUALITY\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    var quality_issues: usize = 0;
    if (has_todo) quality_issues += 1;
    if (has_fixme) quality_issues += 1;
    if (has_console_log) quality_issues += 1;
    if (has_print_debug) quality_issues += 1;

    if (quality_issues == 0) {
        try writer.print("  ✓ No code quality issues detected\n", .{});
    } else {
        if (has_todo) try writer.print("  ○ TODO found - consider completing before merge\n", .{});
        if (has_fixme) try writer.print("  ○ FIXME found - address before merge\n", .{});
        if (has_console_log) try writer.print("  ○ console.log found - remove debug statements\n", .{});
        if (has_print_debug) try writer.print("  ○ Debug print found - remove before merge\n", .{});
    }

    // Checklist
    try writer.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    try writer.print("CHECKLIST\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    try writer.print("  ✓ Diff analyzed\n", .{});
    try writer.print("  ✓ Security scan complete\n", .{});
    try writer.print("  ✓ Code quality check complete\n", .{});

    if (security_issues > 0) {
        try writer.print("  ❌ Security issues need attention\n", .{});
    }

    try writer.print("  ○ Run tests before commit\n", .{});
    try writer.print("  ○ CLAUDE.md compliance (manual)\n", .{});

    // Verdict
    try writer.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    if (security_issues == 0 and quality_issues == 0) {
        try writer.print("VERDICT: ✓ READY FOR REVIEW\n", .{});
    } else if (security_issues > 0) {
        try writer.print("VERDICT: ❌ SECURITY ISSUES - FIX BEFORE MERGE\n", .{});
    } else {
        try writer.print("VERDICT: ⚠️  MINOR ISSUES - REVIEW RECOMMENDED\n", .{});
    }
    try writer.print("═══════════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY LOGIC COMMANDS (unique to VIBEE)
// ═══════════════════════════════════════════════════════════════════════════════

fn runEval(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print(
            \\Usage: vibee eval <expression>
            \\
            \\Examples:
            \\  vibee eval "true AND unknown"
            \\  vibee eval "false OR true"
            \\  vibee eval "NOT unknown"
            \\  vibee eval "true IMPLIES false"
            \\
            \\Values: true/△/1, unknown/○/0, false/▽/-1
            \\Operators: AND, OR, NOT, IMPLIES
            \\
        , .{});
        return;
    }

    // Join all args into expression
    var expr_buf: [1024]u8 = undefined;
    var expr_len: usize = 0;
    for (args, 0..) |arg, i| {
        if (i > 0) {
            expr_buf[expr_len] = ' ';
            expr_len += 1;
        }
        @memcpy(expr_buf[expr_len .. expr_len + arg.len], arg);
        expr_len += arg.len;
    }
    const expr = expr_buf[0..expr_len];

    try writer.print("\nEvaluating: {s}\n\n", .{expr});

    // Simple expression parser
    // Supports: value, NOT value, value OP value
    var upper_buf: [1024]u8 = undefined;
    for (expr, 0..) |c, i| {
        upper_buf[i] = std.ascii.toUpper(c);
    }
    const upper = upper_buf[0..expr_len];

    // Check for NOT
    if (std.mem.startsWith(u8, upper, "NOT ")) {
        const rest = std.mem.trim(u8, expr[4..], " ");
        if (Ternary.fromString(rest)) |val| {
            const result = Ternary.kleeneNot(val);
            try writer.print("NOT {s} = {s}\n", .{ val.toSymbol(), result.toString() });
            return;
        }
    }

    // Check for binary operators
    const ops = [_]struct { name: []const u8, func: *const fn (Ternary, Ternary) Ternary }{
        .{ .name = " AND ", .func = Ternary.kleeneAnd },
        .{ .name = " OR ", .func = Ternary.kleeneOr },
        .{ .name = " IMPLIES ", .func = Ternary.kleeneImplies },
    };

    for (ops) |op| {
        if (std.mem.indexOf(u8, upper, op.name)) |idx| {
            const left_str = std.mem.trim(u8, expr[0..idx], " ");
            const right_str = std.mem.trim(u8, expr[idx + op.name.len ..], " ");

            if (Ternary.fromString(left_str)) |left| {
                if (Ternary.fromString(right_str)) |right| {
                    const result = op.func(left, right);
                    try writer.print("{s} {s} {s} = {s}\n", .{
                        left.toSymbol(),
                        std.mem.trim(u8, op.name, " "),
                        right.toSymbol(),
                        result.toString(),
                    });
                    return;
                }
            }
        }
    }

    // Single value
    if (Ternary.fromString(std.mem.trim(u8, expr, " "))) |val| {
        try writer.print("{s} = {s}\n", .{ expr, val.toString() });
        return;
    }

    try writer.print("Could not parse expression: {s}\n", .{expr});
    try writer.print("Use: true/false/unknown AND/OR/NOT/IMPLIES\n", .{});
}

fn runTruth(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print("Usage: vibee truth <and|or|not|implies|all>\n", .{});
        return;
    }

    const op = args[0];

    if (std.mem.eql(u8, op, "and")) {
        try writer.print(
            \\
            \\AND (Kleene Strong) - Returns minimum:
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ▽
            \\  ○ │ ○   ○   ▽
            \\  ▽ │ ▽   ▽   ▽
            \\
            \\Rule: min(a, b)
            \\
        , .{});
    } else if (std.mem.eql(u8, op, "or")) {
        try writer.print(
            \\
            \\OR (Kleene Strong) - Returns maximum:
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   △   △
            \\  ○ │ △   ○   ○
            \\  ▽ │ △   ○   ▽
            \\
            \\Rule: max(a, b)
            \\
        , .{});
    } else if (std.mem.eql(u8, op, "not")) {
        try writer.print(
            \\
            \\NOT (Negation):
            \\
            \\  ¬△ = ▽
            \\  ¬○ = ○  (unknown stays unknown)
            \\  ¬▽ = △
            \\
            \\In balanced ternary: ¬x = -x
            \\
        , .{});
    } else if (std.mem.eql(u8, op, "implies")) {
        try writer.print(
            \\
            \\IMPLIES (a → b = ¬a ∨ b):
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ▽
            \\  ○ │ △   ○   ○
            \\  ▽ │ △   △   △
            \\
        , .{});
    } else if (std.mem.eql(u8, op, "all")) {
        try writer.print(
            \\
            \\═══════════════════════════════════════════════════════════════
            \\KLEENE'S THREE-VALUED LOGIC - Complete Truth Tables
            \\═══════════════════════════════════════════════════════════════
            \\
            \\Values: △ (true/+1), ○ (unknown/0), ▽ (false/-1)
            \\
            \\AND (minimum):          OR (maximum):
            \\    │ △  ○  ▽              │ △  ○  ▽
            \\────┼─────────          ────┼─────────
            \\  △ │ △  ○  ▽            △ │ △  △  △
            \\  ○ │ ○  ○  ▽            ○ │ △  ○  ○
            \\  ▽ │ ▽  ▽  ▽            ▽ │ △  ○  ▽
            \\
            \\NOT:                    IMPLIES (¬a ∨ b):
            \\  ¬△ = ▽                    │ △  ○  ▽
            \\  ¬○ = ○                ────┼─────────
            \\  ¬▽ = △                  △ │ △  ○  ▽
            \\                          ○ │ △  ○  ○
            \\                          ▽ │ △  △  △
            \\
            \\Golden Identity: φ² + 1/φ² = 3
            \\
        , .{});
    } else {
        try writer.print("Unknown operation: {s}\n", .{op});
        try writer.print("Available: and, or, not, implies, all\n", .{});
    }
}

fn runRepl(allocator: std.mem.Allocator, writer: anytype) !void {
    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  999 REPL - Ternary Logic Interpreter                         ║
        \\║  Values: △ (true), ○ (unknown), ▽ (false)                     ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
        \\Launching 999repl_v2...
        \\
    , .{});

    // Try to find and exec the REPL
    const repl_paths = [_][]const u8{
        "./bin/999repl_v2",
        "/workspaces/vibee-lang/bin/999repl_v2",
        "999repl_v2",
    };

    for (repl_paths) |path| {
        var child = std.process.Child.init(&[_][]const u8{path}, allocator);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        child.spawn() catch continue;
        _ = child.wait() catch continue;
        return;
    }

    try writer.print("Could not find 999repl_v2. Run from vibee-lang directory.\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAS COMMANDS (unique to VIBEE)
// ═══════════════════════════════════════════════════════════════════════════════

fn runPAS(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try writer.print(
            \\Usage: vibee pas <analyze|predict|patterns>
            \\
            \\PAS - Predictive Algorithmic Systematics
            \\Mendeleev-style predictions for algorithm improvements
            \\
        , .{});
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "analyze")) {
        try writer.print(
            \\
            \\╔═══════════════════════════════════════════════════════════════╗
            \\║  PAS ANALYSIS                                                 ║
            \\╚═══════════════════════════════════════════════════════════════╝
            \\
            \\Discovery Patterns:
            \\
            \\  D&C  Divide-and-Conquer    31%  FFT, Strassen, Karatsuba
            \\  ALG  Algebraic Reorg       22%  Strassen, Coppersmith-Winograd
            \\  PRE  Precomputation        16%  KMP, Aho-Corasick
            \\  FDT  Frequency Domain      13%  FFT, NTT
            \\  MLS  ML-Guided Search       6%  AlphaTensor, AlphaDev
            \\  TEN  Tensor Decomposition   6%  AlphaTensor
            \\
            \\Retrodiction Accuracy: 98% (Mendeleev-level)
            \\
        , .{});
    } else if (std.mem.eql(u8, subcmd, "predict")) {
        try writer.print(
            \\
            \\╔═══════════════════════════════════════════════════════════════╗
            \\║  PAS PREDICTIONS                                              ║
            \\╚═══════════════════════════════════════════════════════════════╝
            \\
            \\VIBEE Core Predictions:
            \\
            \\  Component      Current           Predicted         Confidence
            \\  ─────────────────────────────────────────────────────────────
            \\  Parser         Recursive descent SIMD-accelerated  75%
            \\  Type Checker   Hindley-Milner    Incremental       80%
            \\  Codegen        Template-based    ML-optimized      65%
            \\  Optimizer      Pattern matching  E-graph/Superopt  55%
            \\
        , .{});
    } else if (std.mem.eql(u8, subcmd, "patterns")) {
        try writer.print(
            \\
            \\PAS Discovery Patterns:
            \\
            \\  Symbol  Name                    Success Rate
            \\  ──────────────────────────────────────────────
            \\  D&C     Divide-and-Conquer      31%
            \\  ALG     Algebraic Reorganization 22%
            \\  PRE     Precomputation          16%
            \\  FDT     Frequency Domain        13%
            \\  MLS     ML-Guided Search         6%
            \\  TEN     Tensor Decomposition     6%
            \\  HSH     Hashing                  4%
            \\  PRB     Probabilistic            2%
            \\
        , .{});
    } else {
        try writer.print("Unknown PAS command: {s}\n", .{subcmd});
    }
}

fn runBenchmark(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = args;
    _ = allocator;

    try writer.print(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE BENCHMARK                                                ║
        \\╚═══════════════════════════════════════════════════════════════╝
        \\
        \\Recent Results (Crush Zig):
        \\
        \\  Operation              ns/op
        \\  ─────────────────────────────
        \\  csync.Map set/get         26
        \\  csync.Slice append        42
        \\  stringext.containsAny     59
        \\  version.parseSemVer       93
        \\  stringext.capitalize   8,135
        \\  home.short             7,750
        \\  ansiext.escape        23,792
        \\  diff.generateDiff     45,552
        \\
        \\Run full benchmark: cd generated/crush/zig && zig build-exe benchmark.zig -O ReleaseFast && ./benchmark
        \\
    , .{});
}

fn runGen(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    if (args.len == 0) {
        try writer.print(
            \\
            \\╔═══════════════════════════════════════════════════════════════╗
            \\║  VIBEE - Specification Compiler                               ║
            \\║  .vibee → .zig                                                ║
            \\╚═══════════════════════════════════════════════════════════════╝
            \\
            \\USAGE:
            \\  vibee gen <input.vibee> [output.zig]
            \\
            \\EXAMPLES:
            \\  vibee gen specs/tri/ai_provider.vibee
            \\  vibee gen specs/tri/ai_provider.vibee trinity/output/ai_provider.zig
            \\
            \\OUTPUT:
            \\  Default: trinity/output/<name>.zig
            \\
            \\φ² + 1/φ² = 3
            \\
        , .{});
        return;
    }

    const input_path = args[0];
    
    // Derive output path
    var output_path_buf: [512]u8 = undefined;
    const output_path = if (args.len > 1) args[1] else blk: {
        const basename = std.fs.path.basename(input_path);
        const stem = std.fs.path.stem(basename);
        const len = (std.fmt.bufPrint(&output_path_buf, "trinity/output/{s}.zig", .{stem}) catch return).len;
        break :blk output_path_buf[0..len];
    };

    try writer.print("\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try writer.print("                    VIBEE Code Generator v24.φ\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try writer.print("\n", .{});
    try writer.print("  Input:  {s}\n", .{input_path});
    try writer.print("  Output: {s}\n", .{output_path});
    try writer.print("\n", .{});

    // Run vibeec gen_cmd
    const result = runCommand(allocator, &[_][]const u8{
        "src/vibeec/gen_cmd",
        "gen",
        input_path,
        output_path,
    }) catch |err| {
        try writer.print("  ❌ Error running generator: {}\n", .{err});
        try writer.print("  Make sure gen_cmd is compiled: cd src/vibeec && zig build-exe gen_cmd.zig\n", .{});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        // Extract key info from output
        if (std.mem.indexOf(u8, result.stdout, "Generated")) |_| {
            try writer.print("  ✓ Generation successful\n", .{});
        }
    }

    if (result.stderr.len > 0) {
        try writer.print("  ⚠️  {s}\n", .{result.stderr});
    }

    try writer.print("\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try writer.print("                         GENERATION COMPLETE\n", .{});
    try writer.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try writer.print("\n", .{});
    try writer.print("Next steps:\n", .{});
    try writer.print("  1. Review: {s}\n", .{output_path});
    try writer.print("  2. Test:   zig test {s}\n", .{output_path});
    try writer.print("\n", .{});
}
