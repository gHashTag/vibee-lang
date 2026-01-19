// projects.zig - Projects Module
// Generated from: crush/internal/projects
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Project record
pub const Project = struct {
    id: []const u8,
    name: []const u8,
    path: []const u8,
    description: ?[]const u8,
    created_at: i64,
    updated_at: i64,
};

/// Projects service
pub const Service = struct {
    projects: std.StringHashMap(Project),
    allocator: std.mem.Allocator,
    next_id: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .projects = std.StringHashMap(Project).init(allocator),
            .allocator = allocator,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.projects.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.projects.deinit();
    }

    fn generateId(self: *Self) ![]u8 {
        const id = try std.fmt.allocPrint(self.allocator, "proj_{d}", .{self.next_id});
        self.next_id += 1;
        return id;
    }

    pub fn create(self: *Self, name: []const u8, path: []const u8) !Project {
        const id = try self.generateId();
        const now = std.time.milliTimestamp();

        const project = Project{
            .id = id,
            .name = name,
            .path = path,
            .description = null,
            .created_at = now,
            .updated_at = now,
        };

        try self.projects.put(id, project);
        return project;
    }

    pub fn get(self: *Self, id: []const u8) ?Project {
        return self.projects.get(id);
    }

    pub fn getByPath(self: *Self, path: []const u8) ?Project {
        var iter = self.projects.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.path, path)) {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    pub fn list(self: *Self, allocator: std.mem.Allocator) ![]Project {
        var result = std.ArrayList(Project).init(allocator);
        var iter = self.projects.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }
        return result.toOwnedSlice();
    }

    pub fn delete(self: *Self, id: []const u8) bool {
        if (self.projects.fetchRemove(id)) |kv| {
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn count(self: *Self) usize {
        return self.projects.count();
    }
};

// Tests
test "create_project" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const project = try service.create("My Project", "/path/to/project");
    try std.testing.expectEqualStrings("My Project", project.name);
    try std.testing.expectEqualStrings("/path/to/project", project.path);
}

test "get_project" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const created = try service.create("Test", "/test");
    const retrieved = service.get(created.id);

    try std.testing.expect(retrieved != null);
}

test "get_by_path" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("Project", "/my/path");
    const found = service.getByPath("/my/path");

    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Project", found.?.name);
}

test "list_projects" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("P1", "/p1");
    _ = try service.create("P2", "/p2");

    const projects = try service.list(allocator);
    defer allocator.free(projects);

    try std.testing.expectEqual(@as(usize, 2), projects.len);
}

test "delete_project" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const project = try service.create("ToDelete", "/delete");
    try std.testing.expect(service.delete(project.id));
    try std.testing.expectEqual(@as(usize, 0), service.count());
}
