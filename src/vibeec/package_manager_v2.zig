// VIBEE Package Manager V2
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;

// Package version
pub const Version = struct {
    major: u16,
    minor: u16,
    patch: u16,
    
    pub fn parse(str: []const u8) ?Version {
        var parts = std.mem.splitScalar(u8, str, '.');
        const major = std.fmt.parseInt(u16, parts.next() orelse return null, 10) catch return null;
        const minor = std.fmt.parseInt(u16, parts.next() orelse "0", 10) catch 0;
        const patch = std.fmt.parseInt(u16, parts.next() orelse "0", 10) catch 0;
        return Version{ .major = major, .minor = minor, .patch = patch };
    }
    
    pub fn format(self: Version, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        try buf.writer().print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
        return buf.toOwnedSlice();
    }
    
    pub fn compare(self: Version, other: Version) std.math.Order {
        if (self.major != other.major) return std.math.order(self.major, other.major);
        if (self.minor != other.minor) return std.math.order(self.minor, other.minor);
        return std.math.order(self.patch, other.patch);
    }
    
    pub fn satisfies(self: Version, requirement: []const u8) bool {
        // Simple semver matching
        if (requirement.len == 0) return true;
        
        if (requirement[0] == '^') {
            // Compatible with major version
            const req_ver = Version.parse(requirement[1..]) orelse return false;
            return self.major == req_ver.major and self.compare(req_ver) != .lt;
        }
        if (requirement[0] == '~') {
            // Compatible with minor version
            const req_ver = Version.parse(requirement[1..]) orelse return false;
            return self.major == req_ver.major and self.minor == req_ver.minor and self.compare(req_ver) != .lt;
        }
        if (std.mem.startsWith(u8, requirement, ">=")) {
            const req_ver = Version.parse(requirement[2..]) orelse return false;
            return self.compare(req_ver) != .lt;
        }
        
        // Exact match
        const req_ver = Version.parse(requirement) orelse return false;
        return self.compare(req_ver) == .eq;
    }
};

// Package dependency
pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    source: Source,
    
    pub const Source = enum {
        registry,
        git,
        local,
    };
};

// Package manifest (vibee.pkg)
pub const Manifest = struct {
    name: []const u8,
    version: Version,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    dependencies: std.ArrayList(Dependency),
    dev_dependencies: std.ArrayList(Dependency),
    
    // Sacred metadata
    phoenix_compatible: bool,
    trinity_score: f64,
    
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .name = "",
            .version = Version{ .major = 1, .minor = 0, .patch = 0 },
            .description = "",
            .author = "",
            .license = "MIT",
            .dependencies = std.ArrayList(Dependency).init(allocator),
            .dev_dependencies = std.ArrayList(Dependency).init(allocator),
            .phoenix_compatible = true,
            .trinity_score = 1.0,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.dependencies.deinit();
        self.dev_dependencies.deinit();
    }
    
    pub fn addDependency(self: *Self, name: []const u8, version: []const u8) !void {
        try self.dependencies.append(.{
            .name = name,
            .version = version,
            .source = .registry,
        });
    }
    
    pub fn toYaml(self: *Self) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        const writer = buf.writer();
        
        try writer.print("# VIBEE Package Manifest\n", .{});
        try writer.print("# PHOENIX = 999 = 3³ × 37\n\n", .{});
        
        try writer.print("name: {s}\n", .{self.name});
        const ver_str = try self.version.format(self.allocator);
        defer self.allocator.free(ver_str);
        try writer.print("version: \"{s}\"\n", .{ver_str});
        try writer.print("description: \"{s}\"\n", .{self.description});
        try writer.print("author: \"{s}\"\n", .{self.author});
        try writer.print("license: {s}\n\n", .{self.license});
        
        try writer.print("sacred:\n", .{});
        try writer.print("  phoenix_compatible: {}\n", .{self.phoenix_compatible});
        try writer.print("  trinity_score: {d:.2}\n\n", .{self.trinity_score});
        
        if (self.dependencies.items.len > 0) {
            try writer.print("dependencies:\n", .{});
            for (self.dependencies.items) |dep| {
                try writer.print("  {s}: \"{s}\"\n", .{ dep.name, dep.version });
            }
        }
        
        return buf.toOwnedSlice();
    }
};

// Package registry
pub const Registry = struct {
    allocator: std.mem.Allocator,
    packages: std.StringHashMap(PackageInfo),
    
    pub const PackageInfo = struct {
        name: []const u8,
        versions: std.ArrayList(Version),
        latest: Version,
        description: []const u8,
    };
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .packages = std.StringHashMap(PackageInfo).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.packages.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.versions.deinit();
        }
        self.packages.deinit();
    }
    
    pub fn register(self: *Self, name: []const u8, version: Version, description: []const u8) !void {
        if (self.packages.getPtr(name)) |info| {
            try info.versions.append(version);
            if (version.compare(info.latest) == .gt) {
                info.latest = version;
            }
        } else {
            var versions = std.ArrayList(Version).init(self.allocator);
            try versions.append(version);
            try self.packages.put(name, .{
                .name = name,
                .versions = versions,
                .latest = version,
                .description = description,
            });
        }
    }
    
    pub fn resolve(self: *Self, name: []const u8, requirement: []const u8) ?Version {
        const info = self.packages.get(name) orelse return null;
        
        // Find best matching version
        var best: ?Version = null;
        for (info.versions.items) |ver| {
            if (ver.satisfies(requirement)) {
                if (best == null or ver.compare(best.?) == .gt) {
                    best = ver;
                }
            }
        }
        return best;
    }
};

// Package Manager
pub const PackageManager = struct {
    allocator: std.mem.Allocator,
    registry: Registry,
    installed: std.StringHashMap(Version),
    cache_dir: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .registry = Registry.init(allocator),
            .installed = std.StringHashMap(Version).init(allocator),
            .cache_dir = ".vibee/cache",
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.registry.deinit();
        self.installed.deinit();
    }
    
    pub fn install(self: *Self, name: []const u8, version_req: []const u8) !?Version {
        const resolved = self.registry.resolve(name, version_req) orelse return null;
        try self.installed.put(name, resolved);
        return resolved;
    }
    
    pub fn uninstall(self: *Self, name: []const u8) bool {
        return self.installed.remove(name);
    }
    
    pub fn list(self: *Self) []const struct { name: []const u8, version: Version } {
        var result = std.ArrayList(struct { name: []const u8, version: Version }).init(self.allocator);
        var iter = self.installed.iterator();
        while (iter.next()) |entry| {
            result.append(.{ .name = entry.key_ptr.*, .version = entry.value_ptr.* }) catch {};
        }
        return result.items;
    }
    
    pub fn initProject(self: *Self, name: []const u8) !Manifest {
        var manifest = Manifest.init(self.allocator);
        manifest.name = name;
        manifest.description = "A VIBEE project";
        manifest.phoenix_compatible = true;
        manifest.trinity_score = 1.0;
        return manifest;
    }
};

// Tests
test "Version parsing" {
    const v = Version.parse("3.0.0").?;
    try std.testing.expectEqual(@as(u16, 3), v.major);
    try std.testing.expectEqual(@as(u16, 0), v.minor);
    try std.testing.expectEqual(@as(u16, 0), v.patch);
}

test "Version comparison" {
    const v1 = Version{ .major = 1, .minor = 0, .patch = 0 };
    const v2 = Version{ .major = 2, .minor = 0, .patch = 0 };
    const v3 = Version{ .major = 1, .minor = 1, .patch = 0 };
    
    try std.testing.expectEqual(std.math.Order.lt, v1.compare(v2));
    try std.testing.expectEqual(std.math.Order.lt, v1.compare(v3));
    try std.testing.expectEqual(std.math.Order.gt, v2.compare(v1));
}

test "Version satisfies" {
    const v = Version{ .major = 1, .minor = 5, .patch = 0 };
    
    try std.testing.expect(v.satisfies("^1.0.0"));
    try std.testing.expect(v.satisfies("~1.5.0"));
    try std.testing.expect(v.satisfies(">=1.0.0"));
    try std.testing.expect(!v.satisfies("^2.0.0"));
}

test "Registry resolve" {
    const allocator = std.testing.allocator;
    
    var registry = Registry.init(allocator);
    defer registry.deinit();
    
    try registry.register("test-pkg", Version{ .major = 1, .minor = 0, .patch = 0 }, "Test");
    try registry.register("test-pkg", Version{ .major = 1, .minor = 1, .patch = 0 }, "Test");
    try registry.register("test-pkg", Version{ .major = 2, .minor = 0, .patch = 0 }, "Test");
    
    const resolved = registry.resolve("test-pkg", "^1.0.0").?;
    try std.testing.expectEqual(@as(u16, 1), resolved.major);
    try std.testing.expectEqual(@as(u16, 1), resolved.minor);
}

test "Manifest to YAML" {
    const allocator = std.testing.allocator;
    
    var manifest = Manifest.init(allocator);
    defer manifest.deinit();
    
    manifest.name = "my-package";
    manifest.description = "A test package";
    manifest.author = "Test Author";
    
    const yaml = try manifest.toYaml();
    defer allocator.free(yaml);
    
    try std.testing.expect(std.mem.indexOf(u8, yaml, "name: my-package") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml, "PHOENIX = 999") != null);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
