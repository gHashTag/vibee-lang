// filetracker.zig - File Access Tracking Module
// Generated from: specs/crush/filetracker.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Record tracks when a file was read/written
pub const Record = struct {
    path: []const u8,
    read_time: ?i64,
    write_time: ?i64,
};

/// Global file tracker state
var records: std.StringHashMap(Record) = undefined;
var mutex: std.Thread.RwLock = .{};
var initialized: bool = false;

fn ensureInit(allocator: std.mem.Allocator) void {
    if (!initialized) {
        records = std.StringHashMap(Record).init(allocator);
        initialized = true;
    }
}

/// FileTracker with explicit allocator
pub const FileTracker = struct {
    records: std.StringHashMap(Record),
    mutex: std.Thread.RwLock,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .records = std.StringHashMap(Record).init(allocator),
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.records.deinit();
    }

    /// Record when a file was read
    pub fn recordRead(self: *Self, path: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();

        if (self.records.get(path)) |existing| {
            try self.records.put(path, Record{
                .path = path,
                .read_time = now,
                .write_time = existing.write_time,
            });
        } else {
            try self.records.put(path, Record{
                .path = path,
                .read_time = now,
                .write_time = null,
            });
        }
    }

    /// Record when a file was written
    pub fn recordWrite(self: *Self, path: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();

        if (self.records.get(path)) |existing| {
            try self.records.put(path, Record{
                .path = path,
                .read_time = existing.read_time,
                .write_time = now,
            });
        } else {
            try self.records.put(path, Record{
                .path = path,
                .read_time = null,
                .write_time = now,
            });
        }
    }

    /// Get last read time for a file
    pub fn lastReadTime(self: *Self, path: []const u8) ?i64 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.records.get(path)) |rec| {
            return rec.read_time;
        }
        return null;
    }

    /// Get last write time for a file
    pub fn lastWriteTime(self: *Self, path: []const u8) ?i64 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.records.get(path)) |rec| {
            return rec.write_time;
        }
        return null;
    }

    /// Check if file was read
    pub fn wasRead(self: *Self, path: []const u8) bool {
        return self.lastReadTime(path) != null;
    }

    /// Check if file was written
    pub fn wasWritten(self: *Self, path: []const u8) bool {
        return self.lastWriteTime(path) != null;
    }

    /// Reset all records
    pub fn reset(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.records.clearRetainingCapacity();
    }

    /// Get record count
    pub fn count(self: *Self) usize {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();
        return self.records.count();
    }
};

// Tests
test "record_read" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordRead("/path/to/file.txt");
    try std.testing.expect(tracker.wasRead("/path/to/file.txt"));
    try std.testing.expect(tracker.lastReadTime("/path/to/file.txt") != null);
}

test "record_write" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordWrite("/path/to/file.txt");
    try std.testing.expect(tracker.wasWritten("/path/to/file.txt"));
    try std.testing.expect(tracker.lastWriteTime("/path/to/file.txt") != null);
}

test "last_read_time_not_found" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try std.testing.expect(tracker.lastReadTime("/nonexistent") == null);
}

test "reset" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordRead("/file1.txt");
    try tracker.recordRead("/file2.txt");
    try std.testing.expectEqual(@as(usize, 2), tracker.count());

    tracker.reset();
    try std.testing.expectEqual(@as(usize, 0), tracker.count());
}

test "read_then_write" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordRead("/file.txt");
    try tracker.recordWrite("/file.txt");

    try std.testing.expect(tracker.wasRead("/file.txt"));
    try std.testing.expect(tracker.wasWritten("/file.txt"));
}

test "multiple_files" {
    const allocator = std.testing.allocator;
    var tracker = FileTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordRead("/file1.txt");
    try tracker.recordWrite("/file2.txt");
    try tracker.recordRead("/file3.txt");

    try std.testing.expectEqual(@as(usize, 3), tracker.count());
}
