//! VIBEE Package Manager - PAS DAEMON V38
//! Паттерны: HSH (O(1) lookup), D&C (dependency resolution), PRE (cached metadata)

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION - Semantic versioning
// ═══════════════════════════════════════════════════════════════════════════════

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
    
    pub fn init(major: u32, minor: u32, patch: u32) Version {
        return .{ .major = major, .minor = minor, .patch = patch };
    }
    
    pub fn parse(str: []const u8) ?Version {
        var parts: [3]u32 = .{ 0, 0, 0 };
        var idx: usize = 0;
        var num: u32 = 0;
        
        for (str) |c| {
            if (c == '.') {
                if (idx >= 2) return null;
                parts[idx] = num;
                idx += 1;
                num = 0;
            } else if (c >= '0' and c <= '9') {
                num = num * 10 + (c - '0');
            } else return null;
        }
        parts[idx] = num;
        
        return Version.init(parts[0], parts[1], parts[2]);
    }
    
    pub fn compare(self: Version, other: Version) i32 {
        if (self.major != other.major) return if (self.major > other.major) 1 else -1;
        if (self.minor != other.minor) return if (self.minor > other.minor) 1 else -1;
        if (self.patch != other.patch) return if (self.patch > other.patch) 1 else -1;
        return 0;
    }
    
    pub fn satisfies(self: Version, constraint: VersionConstraint) bool {
        return switch (constraint.op) {
            .exact => self.compare(constraint.version) == 0,
            .gte => self.compare(constraint.version) >= 0,
            .lte => self.compare(constraint.version) <= 0,
            .gt => self.compare(constraint.version) > 0,
            .lt => self.compare(constraint.version) < 0,
            .compatible => self.major == constraint.version.major and self.compare(constraint.version) >= 0,
        };
    }
};

pub const ConstraintOp = enum { exact, gte, lte, gt, lt, compatible };

pub const VersionConstraint = struct {
    op: ConstraintOp,
    version: Version,
    
    pub fn init(op: ConstraintOp, version: Version) VersionConstraint {
        return .{ .op = op, .version = version };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PACKAGE - Core package structure
// ═══════════════════════════════════════════════════════════════════════════════

pub const Dependency = struct {
    name: []const u8,
    constraint: VersionConstraint,
};

pub const Package = struct {
    name: []const u8,
    version: Version,
    description: []const u8 = "",
    dependencies: ArrayList(Dependency),
    dev_dependencies: ArrayList(Dependency),
    
    pub fn init(allocator: Allocator, name: []const u8, version: Version) Package {
        return .{
            .name = name,
            .version = version,
            .dependencies = ArrayList(Dependency).init(allocator),
            .dev_dependencies = ArrayList(Dependency).init(allocator),
        };
    }
    
    pub fn deinit(self: *Package) void {
        self.dependencies.deinit();
        self.dev_dependencies.deinit();
    }
    
    pub fn addDependency(self: *Package, name: []const u8, constraint: VersionConstraint) !void {
        try self.dependencies.append(.{ .name = name, .constraint = constraint });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRY - HSH pattern for O(1) package lookup
// ═══════════════════════════════════════════════════════════════════════════════

pub const PackageRegistry = struct {
    allocator: Allocator,
    packages: StringHashMap(ArrayList(Package)),
    
    pub fn init(allocator: Allocator) PackageRegistry {
        return .{
            .allocator = allocator,
            .packages = StringHashMap(ArrayList(Package)).init(allocator),
        };
    }
    
    pub fn deinit(self: *PackageRegistry) void {
        var iter = self.packages.valueIterator();
        while (iter.next()) |versions| {
            for (versions.items) |*pkg| {
                pkg.deinit();
            }
            versions.deinit();
        }
        self.packages.deinit();
    }
    
    pub fn publish(self: *PackageRegistry, pkg: Package) !void {
        const result = try self.packages.getOrPut(pkg.name);
        if (!result.found_existing) {
            result.value_ptr.* = ArrayList(Package).init(self.allocator);
        }
        try result.value_ptr.append(pkg);
    }
    
    pub fn resolve(self: *const PackageRegistry, name: []const u8, constraint: VersionConstraint) ?Package {
        const versions = self.packages.get(name) orelse return null;
        var best: ?Package = null;
        for (versions.items) |pkg| {
            if (pkg.version.satisfies(constraint)) {
                if (best == null or pkg.version.compare(best.?.version) > 0) {
                    best = pkg;
                }
            }
        }
        return best;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEPENDENCY RESOLVER - D&C pattern (topological sort)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ResolveError = error{
    PackageNotFound,
    VersionConflict,
    CyclicDependency,
    OutOfMemory,
};

pub const DependencyResolver = struct {
    allocator: Allocator,
    registry: *const PackageRegistry,
    resolved: StringHashMap(Package),
    visiting: StringHashMap(void),
    
    pub fn init(allocator: Allocator, registry: *const PackageRegistry) DependencyResolver {
        return .{
            .allocator = allocator,
            .registry = registry,
            .resolved = StringHashMap(Package).init(allocator),
            .visiting = StringHashMap(void).init(allocator),
        };
    }
    
    pub fn deinit(self: *DependencyResolver) void {
        self.resolved.deinit();
        self.visiting.deinit();
    }
    
    pub fn resolve(self: *DependencyResolver, root: Package) ResolveError![]const Package {
        try self.resolvePackage(root);
        
        var result = self.allocator.alloc(Package, self.resolved.count()) catch return ResolveError.OutOfMemory;
        var i: usize = 0;
        var iter = self.resolved.valueIterator();
        while (iter.next()) |pkg| {
            result[i] = pkg.*;
            i += 1;
        }
        return result;
    }
    
    fn resolvePackage(self: *DependencyResolver, pkg: Package) ResolveError!void {
        if (self.resolved.contains(pkg.name)) return;
        if (self.visiting.contains(pkg.name)) return ResolveError.CyclicDependency;
        
        self.visiting.put(pkg.name, {}) catch return ResolveError.OutOfMemory;
        
        for (pkg.dependencies.items) |dep| {
            const resolved_pkg = self.registry.resolve(dep.name, dep.constraint) orelse 
                return ResolveError.PackageNotFound;
            try self.resolvePackage(resolved_pkg);
        }
        
        _ = self.visiting.remove(pkg.name);
        self.resolved.put(pkg.name, pkg) catch return ResolveError.OutOfMemory;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOCKFILE - PRE pattern (cached resolution)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LockEntry = struct {
    name: []const u8,
    version: Version,
    integrity: u64,
};

pub const Lockfile = struct {
    allocator: Allocator,
    entries: StringHashMap(LockEntry),
    
    pub fn init(allocator: Allocator) Lockfile {
        return .{
            .allocator = allocator,
            .entries = StringHashMap(LockEntry).init(allocator),
        };
    }
    
    pub fn deinit(self: *Lockfile) void {
        self.entries.deinit();
    }
    
    pub fn lock(self: *Lockfile, name: []const u8, version: Version, integrity: u64) !void {
        try self.entries.put(name, .{ .name = name, .version = version, .integrity = integrity });
    }
    
    pub fn get(self: *const Lockfile, name: []const u8) ?LockEntry {
        return self.entries.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Version parsing and comparison" {
    const v1 = Version.parse("1.2.3").?;
    const v2 = Version.parse("1.2.4").?;
    const v3 = Version.parse("2.0.0").?;
    
    try std.testing.expectEqual(@as(i32, -1), v1.compare(v2));
    try std.testing.expectEqual(@as(i32, 1), v3.compare(v1));
    try std.testing.expectEqual(@as(i32, 0), v1.compare(v1));
}

test "Version constraints" {
    const v = Version.init(1, 5, 0);
    
    try std.testing.expect(v.satisfies(VersionConstraint.init(.gte, Version.init(1, 0, 0))));
    try std.testing.expect(v.satisfies(VersionConstraint.init(.lte, Version.init(2, 0, 0))));
    try std.testing.expect(v.satisfies(VersionConstraint.init(.compatible, Version.init(1, 0, 0))));
    try std.testing.expect(!v.satisfies(VersionConstraint.init(.exact, Version.init(1, 4, 0))));
}

test "PackageRegistry HSH lookup" {
    const allocator = std.testing.allocator;
    var registry = PackageRegistry.init(allocator);
    defer registry.deinit();
    
    const pkg1 = Package.init(allocator, "test-pkg", Version.init(1, 0, 0));
    const pkg2 = Package.init(allocator, "test-pkg", Version.init(1, 1, 0));
    
    try registry.publish(pkg1);
    try registry.publish(pkg2);
    
    const resolved = registry.resolve("test-pkg", VersionConstraint.init(.gte, Version.init(1, 0, 0))).?;
    try std.testing.expectEqual(@as(u32, 1), resolved.version.minor);
}

test "Lockfile PRE pattern" {
    const allocator = std.testing.allocator;
    var lockfile = Lockfile.init(allocator);
    defer lockfile.deinit();
    
    try lockfile.lock("pkg-a", Version.init(1, 0, 0), 12345);
    
    const entry = lockfile.get("pkg-a").?;
    try std.testing.expectEqual(@as(u64, 12345), entry.integrity);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
