//! VIBEE ⲦⲢⲒⲚⲒⲦⲨ REPL - Interactive Coptic Shell
//! Commands: :tokens, :ast, :trit, :env, :clear, :help, :quit
//! φ² + 1/φ² = 3

const std = @import("std");
const coptic_lexer = @import("coptic_lexer.zig");
const coptic_parser = @import("coptic_parser_real.zig");
const coptic_interpreter = @import("coptic_interpreter.zig");
const trit_logic = @import("trit_logic.zig");

const Lexer = coptic_lexer.Lexer;
const Parser = coptic_parser.Parser;
const AstNode = coptic_parser.AstNode;
const Interpreter = coptic_interpreter.Interpreter;
const Value = coptic_interpreter.Value;
const Trit = trit_logic.Trit;

pub const PHI: f64 = 1.6180339887498948482;

pub const ReplCommand = enum {
    tokens,
    ast,
    trit,
    env,
    clear,
    help,
    quit,
    eval,
    unknown,
};

pub const Repl = struct {
    allocator: std.mem.Allocator,
    history: std.ArrayList([]const u8),
    running: bool,
    interpreter: ?Interpreter,
    source_buffer: std.ArrayList(u8),
    
    pub fn init(allocator: std.mem.Allocator) Repl {
        return .{
            .allocator = allocator,
            .history = std.ArrayList([]const u8).init(allocator),
            .running = true,
            .interpreter = null,
            .source_buffer = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Repl) void {
        for (self.history.items) |item| self.allocator.free(item);
        self.history.deinit();
        if (self.interpreter) |*interp| interp.deinit();
        self.source_buffer.deinit();
    }
    
    pub fn ensureInterpreter(self: *Repl) *Interpreter {
        if (self.interpreter == null) {
            self.interpreter = Interpreter.init(self.allocator, "");
        }
        return &self.interpreter.?;
    }
    
    pub fn clearEnvironment(self: *Repl) void {
        if (self.interpreter) |*interp| interp.deinit();
        self.interpreter = null;
    }
    
    pub fn parseCommand(input: []const u8) ReplCommand {
        const trimmed = std.mem.trim(u8, input, " \t\n\r");
        if (trimmed.len == 0) return .eval;
        if (trimmed[0] != ':') return .eval;
        
        if (std.mem.eql(u8, trimmed, ":tokens")) return .tokens;
        if (std.mem.eql(u8, trimmed, ":ast")) return .ast;
        if (std.mem.eql(u8, trimmed, ":trit")) return .trit;
        if (std.mem.eql(u8, trimmed, ":env")) return .env;
        if (std.mem.eql(u8, trimmed, ":clear")) return .clear;
        if (std.mem.eql(u8, trimmed, ":help")) return .help;
        if (std.mem.eql(u8, trimmed, ":quit") or std.mem.eql(u8, trimmed, ":q")) return .quit;
        return .unknown;
    }
    
    pub fn evalInput(self: *Repl, input: []const u8, writer: anytype) !void {
        const trimmed = std.mem.trim(u8, input, " \t\n\r");
        if (trimmed.len == 0) return;
        
        // Store source for interpreter
        self.source_buffer.clearRetainingCapacity();
        try self.source_buffer.appendSlice(trimmed);
        
        // Parse
        var parser = Parser.init(self.source_buffer.items, self.allocator);
        var ast = parser.parseProgram() catch |err| {
            try writer.print("\x1b[31mParse error: {}\x1b[0m\n", .{err});
            return;
        };
        defer ast.deinit();
        
        // Get or create interpreter
        const interp = self.ensureInterpreter();
        interp.source = self.source_buffer.items;
        
        // Interpret
        const result = interp.interpret(&ast) catch |err| {
            try writer.print("\x1b[31mRuntime error: {}\x1b[0m\n", .{err});
            return;
        };
        
        // Print output
        const output = interp.getOutput();
        if (output.len > 0) {
            try writer.writeAll(output);
            interp.output.clearRetainingCapacity();
        }
        
        // Print result (unless nil)
        if (result != .nil) {
            try writer.print("\x1b[32m=> {}\x1b[0m\n", .{result});
        }
    }
    
    pub fn showEnv(self: *Repl, writer: anytype) !void {
        const interp = self.ensureInterpreter();
        try writer.writeAll("\x1b[33m--- Environment ---\x1b[0m\n");
        
        var iter = interp.global.values.iterator();
        while (iter.next()) |entry| {
            try writer.print("  {s} = {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
    
    pub fn showHelp(writer: anytype) !void {
        try writer.writeAll(
            \\
            \\VIBEE ⲦⲢⲒⲚⲒⲦⲨ REPL v0.2.0 - φ² + 1/φ² = 3
            \\
            \\Commands:
            \\  :tokens <code>  - Show tokens for code
            \\  :ast <code>     - Show AST for code
            \\  :trit           - Show trit truth tables
            \\  :env            - Show environment variables
            \\  :clear          - Clear environment
            \\  :help           - Show this help
            \\  :quit, :q       - Exit REPL
            \\
            \\Examples:
            \\  const x = 42
            \\  x + 10
            \\  func double(n) { n * 2 }
            \\  double(5)
            \\  [1, 2, 3][0]
            \\  for i in range(3) { print(i) }
            \\
        );
    }
    
    pub fn showTokens(source: []const u8, writer: anytype) !void {
        var lexer = Lexer.init(source);
        try writer.writeAll("Tokens:\n");
        while (true) {
            const tok = lexer.nextToken();
            try writer.print("  {s}: '{s}'\n", .{@tagName(tok.kind), tok.lexeme(source)});
            if (tok.kind == .eof) break;
        }
    }
    
    pub fn showAst(source: []const u8, allocator: std.mem.Allocator, writer: anytype) !void {
        var parser = Parser.init(source, allocator);
        var ast = parser.parseProgram() catch |err| {
            try writer.print("Parse error: {}\n", .{err});
            return;
        };
        defer ast.deinit();
        
        try writer.writeAll("AST:\n");
        try printAstNode(&ast, 0, writer);
    }
    
    fn printAstNode(node: *const AstNode, indent: u32, writer: anytype) !void {
        var i: u32 = 0;
        while (i < indent) : (i += 1) try writer.writeAll("  ");
        try writer.print("{s}\n", .{@tagName(node.kind)});
        for (node.children.items) |*child| {
            try printAstNode(child, indent + 1, writer);
        }
    }
    
    pub fn showTritTables(writer: anytype) !void {
        try writer.writeAll(
            \\
            \\Ternary Logic (Kleene) - φ² + 1/φ² = 3
            \\
            \\Symbols: △ (true/+1), ○ (unknown/0), ▽ (false/-1)
            \\
            \\NOT (¬):
            \\  ¬△ = ▽
            \\  ¬○ = ○
            \\  ¬▽ = △
            \\
            \\AND (∧) - min(a,b):
            \\     │ △  ○  ▽
            \\  ───┼─────────
            \\   △ │ △  ○  ▽
            \\   ○ │ ○  ○  ▽
            \\   ▽ │ ▽  ▽  ▽
            \\
            \\OR (∨) - max(a,b):
            \\     │ △  ○  ▽
            \\  ───┼─────────
            \\   △ │ △  △  △
            \\   ○ │ △  ○  ○
            \\   ▽ │ △  ○  ▽
            \\
        );
    }
    
    pub fn evaluate(source: []const u8, allocator: std.mem.Allocator, writer: anytype) !void {
        const trimmed = std.mem.trim(u8, source, " \t\n\r");
        if (trimmed.len == 0) return;
        
        // Check for trit literals
        if (std.mem.eql(u8, trimmed, "△")) {
            try writer.writeAll("=> △ (true, +1)\n");
            return;
        }
        if (std.mem.eql(u8, trimmed, "○")) {
            try writer.writeAll("=> ○ (unknown, 0)\n");
            return;
        }
        if (std.mem.eql(u8, trimmed, "▽")) {
            try writer.writeAll("=> ▽ (false, -1)\n");
            return;
        }
        
        // Parse and show result
        var parser = Parser.init(trimmed, allocator);
        var ast = parser.parseProgram() catch |err| {
            try writer.print("Error: {}\n", .{err});
            return;
        };
        defer ast.deinit();
        
        if (ast.children.items.len > 0) {
            const node = &ast.children.items[0];
            try writer.print("=> {s}\n", .{@tagName(node.kind)});
        }
    }
};

// Tests
test "repl command parsing" {
    try std.testing.expectEqual(Repl.parseCommand(":tokens"), .tokens);
    try std.testing.expectEqual(Repl.parseCommand(":ast"), .ast);
    try std.testing.expectEqual(Repl.parseCommand(":help"), .help);
    try std.testing.expectEqual(Repl.parseCommand(":quit"), .quit);
    try std.testing.expectEqual(Repl.parseCommand(":q"), .quit);
    try std.testing.expectEqual(Repl.parseCommand("const x = 1"), .eval);
}

test "repl show tokens" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try Repl.showTokens("const x = 42", stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "kw_const") != null);
}

test "repl show ast" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try Repl.showAst("const x = 42", std.testing.allocator, stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "program") != null);
}

test "repl evaluate trit" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try Repl.evaluate("△", std.testing.allocator, stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "true") != null);
}

test "phi constant" {
    try std.testing.expect(PHI > 1.618 and PHI < 1.619);
}
