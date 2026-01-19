// pubsub.zig - Publish/Subscribe Module
// Generated from: specs/crush/pubsub.vibee
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

pub const BUFFER_SIZE: usize = 64;

/// Event types
pub const EventType = enum {
    created,
    updated,
    deleted,

    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .created => "created",
            .updated => "updated",
            .deleted => "deleted",
        };
    }
};

/// Generic event with type and payload
pub fn Event(comptime T: type) type {
    return struct {
        event_type: EventType,
        payload: T,
    };
}

/// Subscriber callback type
pub fn SubscriberFn(comptime T: type) type {
    return *const fn (Event(T)) void;
}

/// Generic Pub/Sub Broker
pub fn Broker(comptime T: type) type {
    return struct {
        subscribers: std.ArrayList(SubscriberFn(T)),
        mutex: std.Thread.Mutex,
        allocator: std.mem.Allocator,
        event_count: usize,
        is_shutdown: bool,

        const Self = @This();
        const EventT = Event(T);

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .subscribers = std.ArrayList(SubscriberFn(T)).init(allocator),
                .mutex = .{},
                .allocator = allocator,
                .event_count = 0,
                .is_shutdown = false,
            };
        }

        pub fn deinit(self: *Self) void {
            self.shutdown();
            self.subscribers.deinit();
        }

        /// Subscribe to events
        pub fn subscribe(self: *Self, callback: SubscriberFn(T)) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.is_shutdown) return;

            try self.subscribers.append(callback);
        }

        /// Unsubscribe from events
        pub fn unsubscribe(self: *Self, callback: SubscriberFn(T)) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            for (self.subscribers.items, 0..) |sub, i| {
                if (sub == callback) {
                    _ = self.subscribers.orderedRemove(i);
                    break;
                }
            }
        }

        /// Publish event to all subscribers
        pub fn publish(self: *Self, event_type: EventType, payload: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.is_shutdown) return;

            const event = EventT{
                .event_type = event_type,
                .payload = payload,
            };

            for (self.subscribers.items) |callback| {
                callback(event);
            }

            self.event_count += 1;
        }

        /// Get subscriber count
        pub fn getSubscriberCount(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.subscribers.items.len;
        }

        /// Get total events published
        pub fn getEventCount(self: *Self) usize {
            return self.event_count;
        }

        /// Shutdown broker
        pub fn shutdown(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.is_shutdown) return;

            self.is_shutdown = true;
            self.subscribers.clearRetainingCapacity();
        }

        /// Check if shutdown
        pub fn isShutdown(self: *Self) bool {
            return self.is_shutdown;
        }
    };
}

/// Simple event queue for async processing
pub fn EventQueue(comptime T: type) type {
    return struct {
        events: std.ArrayList(Event(T)),
        mutex: std.Thread.Mutex,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .events = std.ArrayList(Event(T)).init(allocator),
                .mutex = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.events.deinit();
        }

        pub fn push(self: *Self, event_type: EventType, payload: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            try self.events.append(Event(T){
                .event_type = event_type,
                .payload = payload,
            });
        }

        pub fn pop(self: *Self) ?Event(T) {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.events.items.len == 0) return null;
            return self.events.orderedRemove(0);
        }

        pub fn len(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.events.items.len;
        }

        pub fn clear(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.events.clearRetainingCapacity();
        }
    };
}

// Test payload type
const TestPayload = struct {
    id: u32,
    message: []const u8,
};

// Test callback
var test_received_count: usize = 0;
fn testCallback(_: Event(TestPayload)) void {
    test_received_count += 1;
}

// Tests
test "broker_init" {
    const allocator = std.testing.allocator;
    var broker = Broker(TestPayload).init(allocator);
    defer broker.deinit();

    try std.testing.expectEqual(@as(usize, 0), broker.getSubscriberCount());
}

test "broker_subscribe" {
    const allocator = std.testing.allocator;
    var broker = Broker(TestPayload).init(allocator);
    defer broker.deinit();

    try broker.subscribe(testCallback);
    try std.testing.expectEqual(@as(usize, 1), broker.getSubscriberCount());
}

test "broker_publish" {
    const allocator = std.testing.allocator;
    var broker = Broker(TestPayload).init(allocator);
    defer broker.deinit();

    test_received_count = 0;
    try broker.subscribe(testCallback);

    broker.publish(.created, TestPayload{ .id = 1, .message = "test" });

    try std.testing.expectEqual(@as(usize, 1), test_received_count);
    try std.testing.expectEqual(@as(usize, 1), broker.getEventCount());
}

test "broker_unsubscribe" {
    const allocator = std.testing.allocator;
    var broker = Broker(TestPayload).init(allocator);
    defer broker.deinit();

    try broker.subscribe(testCallback);
    try std.testing.expectEqual(@as(usize, 1), broker.getSubscriberCount());

    broker.unsubscribe(testCallback);
    try std.testing.expectEqual(@as(usize, 0), broker.getSubscriberCount());
}

test "broker_shutdown" {
    const allocator = std.testing.allocator;
    var broker = Broker(TestPayload).init(allocator);
    defer broker.deinit();

    try broker.subscribe(testCallback);
    broker.shutdown();

    try std.testing.expect(broker.isShutdown());
    try std.testing.expectEqual(@as(usize, 0), broker.getSubscriberCount());
}

test "event_type_to_string" {
    try std.testing.expectEqualStrings("created", EventType.created.toString());
    try std.testing.expectEqualStrings("updated", EventType.updated.toString());
    try std.testing.expectEqualStrings("deleted", EventType.deleted.toString());
}

test "event_queue_push_pop" {
    const allocator = std.testing.allocator;
    var queue = EventQueue(TestPayload).init(allocator);
    defer queue.deinit();

    try queue.push(.created, TestPayload{ .id = 1, .message = "first" });
    try queue.push(.updated, TestPayload{ .id = 2, .message = "second" });

    try std.testing.expectEqual(@as(usize, 2), queue.len());

    const first = queue.pop();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(EventType.created, first.?.event_type);

    const second = queue.pop();
    try std.testing.expect(second != null);
    try std.testing.expectEqual(EventType.updated, second.?.event_type);

    try std.testing.expectEqual(@as(usize, 0), queue.len());
}

test "event_queue_empty_pop" {
    const allocator = std.testing.allocator;
    var queue = EventQueue(TestPayload).init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.pop() == null);
}
