// history.zig - File History Module (In-Memory Implementation)
// Generated from: specs/crush/history.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

pub const INITIAL_VERSION: i64 = 0;

/// File record with version history
pub const File = struct {
    id: []const u8,
    session_id: []const u8,
    path: []const u8,
    content: []const u8,
    version: i64,
    created_at: i64,
    updated_at: i64,
};

/// In-memory file history service
pub const Service = struct {
    files: std.StringHashMap(File),
    allocator: std.mem.Allocator,
    next_id: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .files = std.StringHashMap(File).init(allocator),
            .allocator = allocator,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.files.deinit();
    }

    /// Generate unique ID
    fn generateId(self: *Self) ![]u8 {
        const id = try std.fmt.allocPrint(self.allocator, "file_{d}", .{self.next_id});
        self.next_id += 1;
        return id;
    }

    /// Create initial version of file
    pub fn create(self: *Self, session_id: []const u8, path: []const u8, content: []const u8) !File {
        return self.createWithVersion(session_id, path, content, INITIAL_VERSION);
    }

    /// Create new version of file
    pub fn createVersion(self: *Self, session_id: []const u8, path: []const u8, content: []const u8) !File {
        // Find latest version for this path
        var latest_version: i64 = -1;
        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.path, path)) {
                if (entry.value_ptr.version > latest_version) {
                    latest_version = entry.value_ptr.version;
                }
            }
        }

        const next_version = if (latest_version >= 0) latest_version + 1 else INITIAL_VERSION;
        return self.createWithVersion(session_id, path, content, next_version);
    }

    fn createWithVersion(self: *Self, session_id: []const u8, path: []const u8, content: []const u8, version: i64) !File {
        const id = try self.generateId();
        const now = std.time.milliTimestamp();

        const file = File{
            .id = id,
            .session_id = session_id,
            .path = path,
            .content = content,
            .version = version,
            .created_at = now,
            .updated_at = now,
        };

        try self.files.put(id, file);
        return file;
    }

    /// Get file by ID
    pub fn get(self: *Self, id: []const u8) ?File {
        return self.files.get(id);
    }

    /// Get file by path and session
    pub fn getByPathAndSession(self: *Self, path: []const u8, session_id: []const u8) ?File {
        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.path, path) and
                std.mem.eql(u8, entry.value_ptr.session_id, session_id))
            {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    /// List all files for session
    pub fn listBySession(self: *Self, allocator: std.mem.Allocator, session_id: []const u8) ![]File {
        var result = std.ArrayList(File).init(allocator);
        errdefer result.deinit();

        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.session_id, session_id)) {
                try result.append(entry.value_ptr.*);
            }
        }

        return result.toOwnedSlice();
    }

    /// List latest version of each file for session
    pub fn listLatestSessionFiles(self: *Self, allocator: std.mem.Allocator, session_id: []const u8) ![]File {
        var latest = std.StringHashMap(File).init(allocator);
        defer latest.deinit();

        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.session_id, session_id)) {
                if (latest.get(entry.value_ptr.path)) |existing| {
                    if (entry.value_ptr.version > existing.version) {
                        try latest.put(entry.value_ptr.path, entry.value_ptr.*);
                    }
                } else {
                    try latest.put(entry.value_ptr.path, entry.value_ptr.*);
                }
            }
        }

        var result = std.ArrayList(File).init(allocator);
        var latest_iter = latest.iterator();
        while (latest_iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }

        return result.toOwnedSlice();
    }

    /// Delete file by ID
    pub fn delete(self: *Self, id: []const u8) bool {
        if (self.files.fetchRemove(id)) |kv| {
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    /// Delete all files for session
    pub fn deleteSessionFiles(self: *Self, session_id: []const u8) !void {
        var to_delete = std.ArrayList([]const u8).init(self.allocator);
        defer to_delete.deinit();

        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.session_id, session_id)) {
                try to_delete.append(entry.key_ptr.*);
            }
        }

        for (to_delete.items) |id| {
            _ = self.delete(id);
        }
    }

    /// Get file count
    pub fn count(self: *Self) usize {
        return self.files.count();
    }
};

// Tests
test "create_file" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const file = try service.create("session1", "/path/to/file.txt", "content");
    try std.testing.expectEqual(INITIAL_VERSION, file.version);
    try std.testing.expectEqualStrings("/path/to/file.txt", file.path);
}

test "create_version" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("session1", "/file.txt", "v0");
    const v1 = try service.createVersion("session1", "/file.txt", "v1");
    const v2 = try service.createVersion("session1", "/file.txt", "v2");

    try std.testing.expectEqual(@as(i64, 1), v1.version);
    try std.testing.expectEqual(@as(i64, 2), v2.version);
}

test "get_file" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const created = try service.create("session1", "/file.txt", "content");
    const retrieved = service.get(created.id);

    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings(created.path, retrieved.?.path);
}

test "get_by_path_and_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("session1", "/file.txt", "content");
    const found = service.getByPathAndSession("/file.txt", "session1");

    try std.testing.expect(found != null);
}

test "list_by_session" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("session1", "/file1.txt", "c1");
    _ = try service.create("session1", "/file2.txt", "c2");
    _ = try service.create("session2", "/file3.txt", "c3");

    const files = try service.listBySession(allocator, "session1");
    defer allocator.free(files);

    try std.testing.expectEqual(@as(usize, 2), files.len);
}

test "delete_file" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    const file = try service.create("session1", "/file.txt", "content");
    try std.testing.expectEqual(@as(usize, 1), service.count());

    const deleted = service.delete(file.id);
    try std.testing.expect(deleted);
    try std.testing.expectEqual(@as(usize, 0), service.count());
}

test "delete_session_files" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("session1", "/file1.txt", "c1");
    _ = try service.create("session1", "/file2.txt", "c2");
    _ = try service.create("session2", "/file3.txt", "c3");

    try service.deleteSessionFiles("session1");

    try std.testing.expectEqual(@as(usize, 1), service.count());
}

test "list_latest_session_files" {
    const allocator = std.testing.allocator;
    var service = Service.init(allocator);
    defer service.deinit();

    _ = try service.create("session1", "/file.txt", "v0");
    _ = try service.createVersion("session1", "/file.txt", "v1");
    _ = try service.createVersion("session1", "/file.txt", "v2");

    const latest = try service.listLatestSessionFiles(allocator, "session1");
    defer allocator.free(latest);

    try std.testing.expectEqual(@as(usize, 1), latest.len);
    try std.testing.expectEqual(@as(i64, 2), latest[0].version);
}
