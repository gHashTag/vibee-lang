//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ REPL - Interactive Shell
//! Run: zig build-exe repl_main.zig && ./repl_main
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_repl = @import("coptic_repl.zig");

const Repl = coptic_repl.Repl;
const ReplCommand = coptic_repl.ReplCommand;

pub const PHI: f64 = 1.6180339887498948482;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const MAGENTA = "\x1b[35m";
const CYAN = "\x1b[36m";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    
    // Banner
    try stdout.print(
        \\{s}
        \\╔══════════════════════════════════════════════════════════════╗
        \\║        VIBEE ⲦⲢⲒⲚⲒⲦⲨ REPL v0.2.0 - φ² + 1/φ² = 3           ║
        \\║                                                              ║
        \\║  Coptic Symbols: ⲁⲃⲅⲇⲉⲍⲏⲑⲓ ⲕⲗⲙⲛⲝⲟⲡⲣⲥ ⲧⲩⲫⲭⲯⲱϣϩϫ            ║
        \\║  Trit Literals:  △ (true)  ? (unknown)  ▽ (false)           ║
        \\║                                                              ║
        \\║  Commands: :env :clear :tokens :ast :trit :help :quit       ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\{s}
        \\
    , .{ CYAN, RESET });
    
    var line_buf: [4096]u8 = undefined;
    var repl = Repl.init(allocator);
    defer repl.deinit();
    
    while (repl.running) {
        // Prompt
        try stdout.print("{s}vibee>{s} ", .{ GREEN, RESET });
        
        // Read line
        const line = stdin.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| {
            try stdout.print("{s}Error reading input: {}{s}\n", .{ RED, err, RESET });
            continue;
        };
        
        if (line == null) break;
        const input = std.mem.trim(u8, line.?, " \t\r");
        if (input.len == 0) continue;
        
        // Parse command
        const cmd = Repl.parseCommand(input);
        
        switch (cmd) {
            .quit => {
                try stdout.print("{s}Goodbye! φ² + 1/φ² = 3{s}\n", .{ YELLOW, RESET });
                repl.running = false;
            },
            .help => {
                try Repl.showHelp(stdout);
            },
            .tokens => {
                const code = getArgument(input, ":tokens");
                if (code.len > 0) {
                    try stdout.print("{s}", .{BLUE});
                    try Repl.showTokens(code, stdout);
                    try stdout.print("{s}", .{RESET});
                } else {
                    try stdout.print("{s}Usage: :tokens <code>{s}\n", .{ YELLOW, RESET });
                }
            },
            .ast => {
                const code = getArgument(input, ":ast");
                if (code.len > 0) {
                    try stdout.print("{s}", .{MAGENTA});
                    try Repl.showAst(code, allocator, stdout);
                    try stdout.print("{s}", .{RESET});
                } else {
                    try stdout.print("{s}Usage: :ast <code>{s}\n", .{ YELLOW, RESET });
                }
            },
            .trit => {
                try stdout.print("{s}", .{CYAN});
                try Repl.showTritTables(stdout);
                try stdout.print("{s}", .{RESET});
            },
            .env => {
                try repl.showEnv(stdout);
            },
            .clear => {
                repl.clearEnvironment();
                try stdout.print("{s}Environment cleared.{s}\n", .{ YELLOW, RESET });
            },
            .eval => {
                // Interpret and show result
                try repl.evalInput(input, stdout);
            },
            .unknown => {
                try stdout.print("{s}Unknown command. Type :help for help.{s}\n", .{ YELLOW, RESET });
            },
        }
    }
}

fn getArgument(input: []const u8, cmd: []const u8) []const u8 {
    if (input.len <= cmd.len) return "";
    return std.mem.trim(u8, input[cmd.len..], " \t");
}

// Tests
test "repl main compiles" {
    // Just verify it compiles
    try std.testing.expect(PHI > 1.618);
}
