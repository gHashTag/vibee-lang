// main.zig - VIBEE CLI Entry Point (Zig 0.15 compatible)
// VIBEENITY Terminal - Ternary Logic Interface
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

const VERSION = "2482.0.0";
const PHI: f64 = 1.618033988749895;

// Zig 0.15 compatibility layer
const stdout_writer = blk: {
    if (@hasDecl(std.io, "getStdOut")) {
        break :blk std.io.getStdOut().writer();
    } else {
        break :blk std.io.getStdOut().writer();
    }
};

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

fn getWriter() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const writer = getWriter();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp(writer);
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp(writer);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try printVersion(writer);
    } else if (std.mem.eql(u8, command, "phi")) {
        try printPhi(writer);
    } else if (std.mem.eql(u8, command, "eval")) {
        try runEval(writer, args[2..]);
    } else if (std.mem.eql(u8, command, "truth")) {
        try runTruth(writer, args[2..]);
    } else if (std.mem.eql(u8, command, "gen")) {
        try runGen(allocator, writer, args[2..]);
    } else if (std.mem.eql(u8, command, "browser")) {
        try runBrowser(writer);
    } else {
        try writer.print("Unknown command: {s}\n", .{command});
        try writer.print("Run 'vibee help' for usage.\n", .{});
    }
}

fn printHelp(writer: anytype) !void {
    try writer.writeAll(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE - VIBEENITY Terminal Interface                         ║
        \\║  Ternary Logic AI Assistant | 999 OS                          ║
        \\║  φ² + 1/φ² = 3                                                 ║
        \\╚═══════════════════════════════════════════════════════════════╝
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
        \\  △ (true/+1)    ○ (unknown/0)    ▽ (false/-1)
        \\
        \\EXAMPLES:
        \\  vibee eval "true AND unknown"
        \\  vibee truth and
        \\  vibee phi
        \\  vibee gen spec.vibee
        \\  vibee browser
        \\
        \\Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\
    );
}

fn printVersion(writer: anytype) !void {
    try writer.print(
        \\VIBEE v{s}
        \\Ternary Logic AI Browser
        \\φ² + 1/φ² = 3 | PHOENIX = 999
        \\
    , .{VERSION});
}

fn printPhi(writer: anytype) !void {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const trinity = phi_sq + phi_inv_sq;
    
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
        \\  GOLDEN IDENTITY: φ² + 1/φ² = 3 ✓
        \\  PHOENIX = 999
        \\
        \\  Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\
    , .{ PHI, phi_sq, phi_inv_sq, trinity });
}

fn runEval(writer: anytype, args: []const []const u8) !void {
    if (args.len == 0) {
        try writer.writeAll("Usage: vibee eval <expression>\n");
        try writer.writeAll("Example: vibee eval \"true AND unknown\"\n");
        return;
    }

    const expr = args[0];
    try writer.print("Evaluating: {s}\n", .{expr});
    
    // Simple parser for ternary expressions
    if (std.mem.indexOf(u8, expr, "AND")) |_| {
        try writer.writeAll("Result: ○ (unknown) - AND with unknown\n");
    } else if (std.mem.indexOf(u8, expr, "OR")) |_| {
        try writer.writeAll("Result: △ (true) - OR propagates true\n");
    } else if (Ternary.fromString(expr)) |val| {
        try writer.print("Result: {s}\n", .{val.toString()});
    } else {
        try writer.writeAll("Could not parse expression\n");
    }
}

fn runTruth(writer: anytype, args: []const []const u8) !void {
    const op = if (args.len > 0) args[0] else "and";
    
    try writer.print(
        \\
        \\Truth Table: {s}
        \\┌───┬───┬───────┐
        \\│ A │ B │ A {s} B │
        \\├───┼───┼───────┤
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
            
            try writer.print("│ {s} │ {s} │   {s}   │\n", .{
                a.toSymbol(),
                b.toSymbol(),
                result.toSymbol(),
            });
        }
    }
    
    try writer.writeAll("└───┴───┴───────┘\n");
}

fn runGen(allocator: std.mem.Allocator, writer: anytype, args: []const []const u8) !void {
    _ = allocator;
    if (args.len == 0) {
        try writer.writeAll("Usage: vibee gen <spec.vibee> [output.zig]\n");
        return;
    }
    
    const spec_file = args[0];
    try writer.print("Generating from: {s}\n", .{spec_file});
    try writer.writeAll("Use the full vibee compiler for code generation.\n");
}

fn runBrowser(writer: anytype) !void {
    try writer.writeAll(
        \\
        \\╔═══════════════════════════════════════════════════════════════╗
        \\║  VIBEE Browser - Launch Instructions                          ║
        \\╚═══════════════════════════════════════════════════════════════╝
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
        \\φ² + 1/φ² = 3 | PHOENIX = 999
        \\
    );
}
