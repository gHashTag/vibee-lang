// VIBEE REPL V2 - Interactive Console
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;
const PHOENIX: i64 = 999;

// REPL Value types
pub const Value = union(enum) {
    int: i64,
    float: f64,
    boolean: bool,
    string: []const u8,
    nil: void,
    
    pub fn format(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        const writer = buf.writer();
        
        switch (self) {
            .int => |v| try writer.print("{d}", .{v}),
            .float => |v| try writer.print("{d:.10}", .{v}),
            .boolean => |v| try writer.writeAll(if (v) "△ (true)" else "▽ (false)"),
            .string => |v| try writer.print("\"{s}\"", .{v}),
            .nil => try writer.writeAll("○ (nil)"),
        }
        
        return buf.toOwnedSlice();
    }
};

// REPL Environment
pub const Environment = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(Value),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        var env = Self{
            .allocator = allocator,
            .variables = std.StringHashMap(Value).init(allocator),
        };
        
        // Pre-define sacred constants
        env.variables.put("PHI", .{ .float = PHI }) catch {};
        env.variables.put("PHOENIX", .{ .int = PHOENIX }) catch {};
        env.variables.put("TRINITY", .{ .int = 3 }) catch {};
        
        return env;
    }
    
    pub fn deinit(self: *Self) void {
        self.variables.deinit();
    }
    
    pub fn get(self: *Self, name: []const u8) ?Value {
        return self.variables.get(name);
    }
};

// Expression evaluator
pub const Evaluator = struct {
    env: *Environment,
    
    const Self = @This();
    
    pub fn init(env: *Environment) Self {
        return Self{ .env = env };
    }
    
    pub fn eval(self: *Self, input: []const u8) !Value {
        const trimmed = std.mem.trim(u8, input, " \t\n\r");
        if (trimmed.len == 0) return .{ .nil = {} };
        
        // Check for variable lookup
        if (self.env.get(trimmed)) |value| {
            return value;
        }
        
        // Check for number
        if (std.fmt.parseFloat(f64, trimmed)) |f| {
            if (@floor(f) == f) {
                return .{ .int = @intFromFloat(f) };
            }
            return .{ .float = f };
        } else |_| {}
        
        // Check for boolean
        if (std.mem.eql(u8, trimmed, "true")) return .{ .boolean = true };
        if (std.mem.eql(u8, trimmed, "false")) return .{ .boolean = false };
        
        // Check for fib(n)
        if (std.mem.startsWith(u8, trimmed, "fib(")) {
            return self.evalFib(trimmed);
        }
        
        // Check for golden_identity
        if (std.mem.eql(u8, trimmed, "golden_identity")) {
            const phi_sq = PHI * PHI;
            const inv_phi_sq = 1.0 / phi_sq;
            return .{ .float = phi_sq + inv_phi_sq };
        }
        
        return .{ .nil = {} };
    }
    
    fn evalFib(self: *Self, expr: []const u8) !Value {
        _ = self;
        const start = std.mem.indexOf(u8, expr, "(") orelse return .{ .nil = {} };
        const end = std.mem.indexOf(u8, expr, ")") orelse return .{ .nil = {} };
        const arg_str = std.mem.trim(u8, expr[start + 1 .. end], " ");
        
        const n = std.fmt.parseInt(u32, arg_str, 10) catch return .{ .nil = {} };
        
        if (n <= 1) return .{ .int = n };
        
        var a: i64 = 0;
        var b: i64 = 1;
        var i: u32 = 2;
        while (i <= n) : (i += 1) {
            const c = a + b;
            a = b;
            b = c;
        }
        return .{ .int = b };
    }
};

// Tests
test "REPL evaluator basic" {
    const allocator = std.testing.allocator;
    
    var env = Environment.init(allocator);
    defer env.deinit();
    
    var eval = Evaluator.init(&env);
    
    const num = try eval.eval("42");
    try std.testing.expectEqual(Value{ .int = 42 }, num);
    
    const phi = try eval.eval("PHI");
    try std.testing.expectApproxEqAbs(PHI, phi.float, 0.0001);
}

test "REPL fibonacci" {
    const allocator = std.testing.allocator;
    
    var env = Environment.init(allocator);
    defer env.deinit();
    
    var eval = Evaluator.init(&env);
    
    const fib10 = try eval.eval("fib(10)");
    try std.testing.expectEqual(Value{ .int = 55 }, fib10);
}

test "REPL golden identity" {
    const allocator = std.testing.allocator;
    
    var env = Environment.init(allocator);
    defer env.deinit();
    
    var eval = Evaluator.init(&env);
    
    const golden = try eval.eval("golden_identity");
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, golden.float, 0.0001);
}

test "golden identity constant" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
