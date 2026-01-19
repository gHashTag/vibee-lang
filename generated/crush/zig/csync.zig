// csync.zig - Concurrent Synchronization Primitives
// Generated from: specs/crush/csync.vibee via generated/crush/tri/csync.tri
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3

const std = @import("std");

/// Thread-safe map with RWMutex protection
/// Creation Pattern: UnsafeCollection → MutexWrapper → ThreadSafeCollection
pub fn Map(comptime K: type, comptime V: type) type {
    return struct {
        inner: std.AutoHashMap(K, V),
        mu: std.Thread.RwLock,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create a new thread-safe map
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .inner = std.AutoHashMap(K, V).init(allocator),
                .mu = .{},
                .allocator = allocator,
            };
        }

        /// Deinitialize the map
        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        /// Set a value for the given key
        pub fn set(self: *Self, key: K, value: V) !void {
            self.mu.lock();
            defer self.mu.unlock();
            try self.inner.put(key, value);
        }

        /// Get a value for the given key
        pub fn get(self: *Self, key: K) ?V {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            return self.inner.get(key);
        }

        /// Delete a key from the map
        pub fn del(self: *Self, key: K) void {
            self.mu.lock();
            defer self.mu.unlock();
            _ = self.inner.remove(key);
        }

        /// Get the number of items in the map
        pub fn len(self: *Self) usize {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            return self.inner.count();
        }

        /// Take a value (get and delete atomically)
        pub fn take(self: *Self, key: K) struct { value: ?V, found: bool } {
            self.mu.lock();
            defer self.mu.unlock();
            if (self.inner.fetchRemove(key)) |kv| {
                return .{ .value = kv.value, .found = true };
            }
            return .{ .value = null, .found = false };
        }

        /// Reset the map with new data
        pub fn reset(self: *Self, data: std.AutoHashMap(K, V)) void {
            self.mu.lock();
            defer self.mu.unlock();
            self.inner.deinit();
            self.inner = data;
        }
    };
}

/// Thread-safe slice with mutex protection
pub fn Slice(comptime T: type) type {
    return struct {
        inner: std.ArrayList(T),
        mu: std.Thread.RwLock,

        const Self = @This();

        /// Create a new thread-safe slice
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .inner = std.ArrayList(T).init(allocator),
                .mu = .{},
            };
        }

        /// Deinitialize the slice
        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        /// Append items to the slice
        pub fn append(self: *Self, item: T) !void {
            self.mu.lock();
            defer self.mu.unlock();
            try self.inner.append(item);
        }

        /// Append multiple items
        pub fn appendSlice(self: *Self, items: []const T) !void {
            self.mu.lock();
            defer self.mu.unlock();
            try self.inner.appendSlice(items);
        }

        /// Get an item at the given index
        pub fn get(self: *Self, index: usize) struct { value: ?T, found: bool } {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            if (index >= self.inner.items.len) {
                return .{ .value = null, .found = false };
            }
            return .{ .value = self.inner.items[index], .found = true };
        }

        /// Get the length of the slice
        pub fn len(self: *Self) usize {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            return self.inner.items.len;
        }

        /// Replace the entire slice with new items
        pub fn setSlice(self: *Self, items: []const T) !void {
            self.mu.lock();
            defer self.mu.unlock();
            self.inner.clearRetainingCapacity();
            try self.inner.appendSlice(items);
        }

        /// Get a copy of the inner slice
        pub fn copy(self: *Self, allocator: std.mem.Allocator) ![]T {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            const result = try allocator.alloc(T, self.inner.items.len);
            @memcpy(result, self.inner.items);
            return result;
        }
    };
}

/// Thread-safe value wrapper
pub fn Value(comptime T: type) type {
    return struct {
        v: T,
        mu: std.Thread.RwLock,

        const Self = @This();

        /// Create a new thread-safe value
        pub fn init(initial: T) Self {
            return Self{
                .v = initial,
                .mu = .{},
            };
        }

        /// Get the current value
        pub fn get(self: *Self) T {
            self.mu.lockShared();
            defer self.mu.unlockShared();
            return self.v;
        }

        /// Set a new value
        pub fn set(self: *Self, value: T) void {
            self.mu.lock();
            defer self.mu.unlock();
            self.v = value;
        }
    };
}

// Tests
test "map_init" {
    const allocator = std.testing.allocator;
    var m = Map(u32, i32).init(allocator);
    defer m.deinit();

    try std.testing.expectEqual(@as(usize, 0), m.len());
}

test "map_set_get" {
    const allocator = std.testing.allocator;
    var m = Map(u32, i32).init(allocator);
    defer m.deinit();

    try m.set(1, 42);
    const result = m.get(1);
    try std.testing.expectEqual(@as(?i32, 42), result);
}

test "map_del" {
    const allocator = std.testing.allocator;
    var m = Map(u32, i32).init(allocator);
    defer m.deinit();

    try m.set(1, 42);
    m.del(1);
    try std.testing.expectEqual(@as(?i32, null), m.get(1));
}

test "map_take" {
    const allocator = std.testing.allocator;
    var m = Map(u32, i32).init(allocator);
    defer m.deinit();

    try m.set(1, 42);
    const result = m.take(1);
    try std.testing.expectEqual(@as(?i32, 42), result.value);
    try std.testing.expect(result.found);
    try std.testing.expectEqual(@as(?i32, null), m.get(1));
}

test "slice_init" {
    const allocator = std.testing.allocator;
    var s = Slice(i32).init(allocator);
    defer s.deinit();

    try std.testing.expectEqual(@as(usize, 0), s.len());
}

test "slice_append" {
    const allocator = std.testing.allocator;
    var s = Slice(i32).init(allocator);
    defer s.deinit();

    try s.append(42);
    try std.testing.expectEqual(@as(usize, 1), s.len());

    const result = s.get(0);
    try std.testing.expectEqual(@as(?i32, 42), result.value);
    try std.testing.expect(result.found);
}

test "slice_get_invalid" {
    const allocator = std.testing.allocator;
    var s = Slice(i32).init(allocator);
    defer s.deinit();

    const result = s.get(100);
    try std.testing.expect(!result.found);
}

test "slice_set_slice" {
    const allocator = std.testing.allocator;
    var s = Slice(i32).init(allocator);
    defer s.deinit();

    try s.appendSlice(&[_]i32{ 1, 2, 3 });
    try s.setSlice(&[_]i32{ 100, 200 });

    try std.testing.expectEqual(@as(usize, 2), s.len());
    try std.testing.expectEqual(@as(?i32, 100), s.get(0).value);
}

test "value_init_get" {
    var v = Value(i32).init(42);
    try std.testing.expectEqual(@as(i32, 42), v.get());
}

test "value_set" {
    var v = Value(i32).init(10);
    v.set(20);
    try std.testing.expectEqual(@as(i32, 20), v.get());
}

test "slice_copy" {
    const allocator = std.testing.allocator;
    var s = Slice(i32).init(allocator);
    defer s.deinit();

    try s.appendSlice(&[_]i32{ 1, 2, 3 });

    const copied = try s.copy(allocator);
    defer allocator.free(copied);

    try std.testing.expectEqual(@as(usize, 3), copied.len);
    try std.testing.expectEqual(@as(i32, 1), copied[0]);
    try std.testing.expectEqual(@as(i32, 2), copied[1]);
    try std.testing.expectEqual(@as(i32, 3), copied[2]);
}
