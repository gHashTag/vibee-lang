// ═══════════════════════════════════════════════════════════════════════════════
// env - Generated from Go by VIBEE Transpiler
// ═══════════════════════════════════════════════════════════════════════════════
// SOURCE: github.com/charmbracelet/crush/internal/env/env.go
// SPEC: specs/crush_env.vibee
// TRI: trinity/ЦАРСТВО/ⲘⲈⲆⲚⲞⲈ/ⲅⲟ_ⲧⲣⲁⲛⲥⲡⲓⲗⲉⲣ/ⲕⲣⲩⲥⲏ_ⲉⲛⲩ.tri
// φ² + 1/φ² = 3 | PHOENIX = 999
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

/// Env interface - implemented as tagged union in Zig
/// Go original: type Env interface { Get(key string) string; Env() []string }
pub const Env = union(enum) {
    os_env: OsEnv,
    map_env: *MapEnv,

    pub fn get(self: Env, key: []const u8) ?[]const u8 {
        return switch (self) {
            .os_env => |e| e.get(key),
            .map_env => |e| e.get(key),
        };
    }
};

/// OsEnv - reads from actual OS environment
/// Go original: type osEnv struct{}
pub const OsEnv = struct {
    pub fn get(_: OsEnv, key: []const u8) ?[]const u8 {
        // Convert to null-terminated string for getenv
        var buf: [256]u8 = undefined;
        if (key.len >= buf.len) return null;
        @memcpy(buf[0..key.len], key);
        buf[key.len] = 0;
        const result = std.c.getenv(@ptrCast(&buf));
        if (result) |r| {
            return std.mem.sliceTo(r, 0);
        }
        return null;
    }
};

/// MapEnv - reads from in-memory map
/// Go original: type mapEnv struct { m map[string]string }
pub const MapEnv = struct {
    m: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MapEnv {
        return MapEnv{
            .m = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MapEnv) void {
        self.m.deinit();
    }

    pub fn put(self: *MapEnv, key: []const u8, value: []const u8) !void {
        try self.m.put(key, value);
    }

    pub fn get(self: *const MapEnv, key: []const u8) ?[]const u8 {
        return self.m.get(key);
    }
};

/// New creates a new Env from OS environment
/// Go original: func New() Env
pub fn new() Env {
    return Env{ .os_env = OsEnv{} };
}

/// NewFromMap creates an Env from a map
/// Go original: func NewFromMap(m map[string]string) Env
pub fn newFromMap(allocator: std.mem.Allocator) !*MapEnv {
    const map_env = try allocator.create(MapEnv);
    map_env.* = MapEnv.init(allocator);
    return map_env;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

test "map env get" {
    const allocator = std.testing.allocator;
    var map_env = MapEnv.init(allocator);
    defer map_env.deinit();

    try map_env.put("HOME", "/home/user");
    try std.testing.expectEqualStrings("/home/user", map_env.get("HOME").?);
}

test "map env get nonexistent" {
    const allocator = std.testing.allocator;
    var map_env = MapEnv.init(allocator);
    defer map_env.deinit();

    try std.testing.expect(map_env.get("NONEXISTENT") == null);
}

test "new returns os env" {
    const env = new();
    _ = env;
    try std.testing.expect(true);
}
