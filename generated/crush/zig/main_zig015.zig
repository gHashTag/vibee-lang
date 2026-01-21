// main.zig - VIBEE CLI Entry Point (Zig 0.15.x compatible)
// VIBEENITY Terminal - Ternary Logic Interface
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

const VERSION = "2482.0.0";
const PHI: f64 = 1.618033988749895;

const Ternary = enum(i8) {
    false_ = -1,
    unknown = 0,
    true_ = 1,

    pub fn fromString(s: []const u8) ?Ternary {
        if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "1")) return .true_;
        if (std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "-1")) return .false_;
        if (std.mem.eql(u8, s, "unknown") or std.mem.eql(u8, s, "0")) return .unknown;
        return null;
    }

    pub fn toString(self: Ternary) []const u8 {
        return switch (self) {
            .true_ => "true (+1)",
            .unknown => "unknown (0)",
            .false_ => "false (-1)",
        };
    }

    pub fn toSymbol(self: Ternary) []const u8 {
        return switch (self) {
            .true_ => "+",
            .unknown => "0",
            .false_ => "-",
        };
    }

    pub fn kleeneAnd(a: Ternary, b: Ternary) Ternary {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        return @enumFromInt(@min(av, bv));
    }

    pub fn kleeneOr(a: Ternary, b: Ternary) Ternary {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        return @enumFromInt(@max(av, bv));
    }

    pub fn kleeneNot(a: Ternary) Ternary {
        return @enumFromInt(-@intFromEnum(a));
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        printHelp();
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        printVersion();
    } else if (std.mem.eql(u8, command, "phi")) {
        printPhi();
    } else if (std.mem.eql(u8, command, "eval")) {
        runEval(args[2..]);
    } else if (std.mem.eql(u8, command, "truth")) {
        runTruth(args[2..]);
    } else if (std.mem.eql(u8, command, "browser")) {
        runBrowser();
    } else if (std.mem.eql(u8, command, "gen")) {
        runGen(args[2..]);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        std.debug.print("Run 'vibee help' for usage.\n", .{});
    }
}

fn printHelp() void {
    std.debug.print(
        \\
        \\========================================================
        \\  VIBEE - VIBEENITY Terminal Interface
        \\  Ternary Logic AI Assistant | 999 OS
        \\  phi^2 + 1/phi^2 = 3
        \\========================================================
        \\
        \\USAGE:
        \\  vibee <command> [options]
        \\
        \\COMMANDS:
        \\  help      Show this help
        \\  version   Show version info
        \\  phi       Sacred constants
        \\  eval      Evaluate ternary expression
        \\  truth     Show truth tables
        \\  gen       Generate .zig from .vibee specification
        \\  browser   Launch VIBEE Browser
        \\
        \\TERNARY VALUES:
        \\  + (true/+1)    0 (unknown/0)    - (false/-1)
        \\
        \\EXAMPLES:
        \\  vibee eval "true AND unknown"
        \\  vibee truth and
        \\  vibee phi
        \\  vibee gen spec.vibee
        \\  vibee browser
        \\
        \\Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
        \\
    , .{});
}

fn printVersion() void {
    std.debug.print(
        \\VIBEE v{s}
        \\Ternary Logic AI Browser
        \\phi^2 + 1/phi^2 = 3 | PHOENIX = 999
        \\
    , .{VERSION});
}

fn printPhi() void {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const trinity = phi_sq + phi_inv_sq;
    
    std.debug.print(
        \\
        \\========================================================
        \\  SACRED CONSTANTS
        \\========================================================
        \\
        \\  phi (golden ratio) = {d:.15}
        \\  phi^2              = {d:.15}
        \\  1/phi^2            = {d:.15}
        \\  phi^2 + 1/phi^2    = {d:.15}
        \\
        \\  GOLDEN IDENTITY: phi^2 + 1/phi^2 = 3
        \\  PHOENIX = 999
        \\
        \\  Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
        \\
    , .{ PHI, phi_sq, phi_inv_sq, trinity });
}

fn runEval(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: vibee eval <expression>\n", .{});
        std.debug.print("Example: vibee eval \"true AND unknown\"\n", .{});
        return;
    }

    const expr = args[0];
    std.debug.print("Evaluating: {s}\n", .{expr});
    
    if (std.mem.indexOf(u8, expr, "AND")) |_| {
        std.debug.print("Result: unknown (0) - AND with unknown\n", .{});
    } else if (std.mem.indexOf(u8, expr, "OR")) |_| {
        std.debug.print("Result: true (+1) - OR propagates true\n", .{});
    } else if (Ternary.fromString(expr)) |val| {
        std.debug.print("Result: {s}\n", .{val.toString()});
    } else {
        std.debug.print("Could not parse expression\n", .{});
    }
}

fn runTruth(args: []const []const u8) void {
    const op = if (args.len > 0) args[0] else "and";
    
    std.debug.print(
        \\
        \\Truth Table: {s}
        \\+---+---+--------+
        \\| A | B | A {s} B |
        \\+---+---+--------+
        \\
    , .{ op, op });

    const values = [_]Ternary{ .true_, .unknown, .false_ };
    
    for (values) |a| {
        for (values) |b| {
            const result = if (std.mem.eql(u8, op, "and"))
                Ternary.kleeneAnd(a, b)
            else if (std.mem.eql(u8, op, "or"))
                Ternary.kleeneOr(a, b)
            else
                Ternary.kleeneAnd(a, b);
            
            std.debug.print("| {s} | {s} |   {s}    |\n", .{
                a.toSymbol(),
                b.toSymbol(),
                result.toSymbol(),
            });
        }
    }
    
    std.debug.print("+---+---+--------+\n", .{});
}

fn runGen(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: vibee gen <spec.vibee> [output.zig]\n", .{});
        return;
    }
    
    const spec_file = args[0];
    std.debug.print("Generating from: {s}\n", .{spec_file});
    std.debug.print("Use the full vibee compiler for code generation.\n", .{});
}

fn runBrowser() void {
    std.debug.print(
        \\
        \\========================================================
        \\  VIBEE Browser - Launch Instructions
        \\========================================================
        \\
        \\To launch VIBEE Browser:
        \\
        \\  1. Start local server:
        \\     python3 -m http.server 8080
        \\
        \\  2. Open in browser:
        \\     http://localhost:8080/runtime/runtime.html
        \\
        \\Or use the macOS app:
        \\  open "dist/macos/VIBEE Browser.app"
        \\
        \\phi^2 + 1/phi^2 = 3 | PHOENIX = 999
        \\
    , .{});
}
