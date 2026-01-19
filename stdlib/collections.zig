// VIBEE Standard Library - Collections Module
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const GOLDEN_IDENTITY: f64 = 3.0;

// Stack (LIFO)
pub fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .items = std.ArrayList(T).init(allocator) };
        }
        
        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }
        
        pub fn push(self: *Self, item: T) !void {
            try self.items.append(item);
        }
        
        pub fn pop(self: *Self) ?T {
            return self.items.popOrNull();
        }
        
        pub fn peek(self: *Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[self.items.items.len - 1];
        }
        
        pub fn isEmpty(self: *Self) bool {
            return self.items.items.len == 0;
        }
        
        pub fn len(self: *Self) usize {
            return self.items.items.len;
        }
    };
}

// Queue (FIFO)
pub fn Queue(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        head: usize,
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .items = std.ArrayList(T).init(allocator),
                .head = 0,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }
        
        pub fn enqueue(self: *Self, item: T) !void {
            try self.items.append(item);
        }
        
        pub fn dequeue(self: *Self) ?T {
            if (self.head >= self.items.items.len) return null;
            const item = self.items.items[self.head];
            self.head += 1;
            return item;
        }
        
        pub fn peek(self: *Self) ?T {
            if (self.head >= self.items.items.len) return null;
            return self.items.items[self.head];
        }
        
        pub fn isEmpty(self: *Self) bool {
            return self.head >= self.items.items.len;
        }
        
        pub fn len(self: *Self) usize {
            return self.items.items.len - self.head;
        }
    };
}

// Ring Buffer
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T,
        head: usize,
        tail: usize,
        count: usize,
        
        const Self = @This();
        
        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = 0,
                .tail = 0,
                .count = 0,
            };
        }
        
        pub fn push(self: *Self, item: T) bool {
            if (self.count >= capacity) return false;
            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % capacity;
            self.count += 1;
            return true;
        }
        
        pub fn pop(self: *Self) ?T {
            if (self.count == 0) return null;
            const item = self.buffer[self.head];
            self.head = (self.head + 1) % capacity;
            self.count -= 1;
            return item;
        }
        
        pub fn isFull(self: *Self) bool {
            return self.count >= capacity;
        }
        
        pub fn isEmpty(self: *Self) bool {
            return self.count == 0;
        }
        
        pub fn len(self: *Self) usize {
            return self.count;
        }
    };
}

// Pair
pub fn Pair(comptime T1: type, comptime T2: type) type {
    return struct {
        first: T1,
        second: T2,
        
        const Self = @This();
        
        pub fn init(first: T1, second: T2) Self {
            return Self{ .first = first, .second = second };
        }
    };
}

// Triple (Trinity!)
pub fn Triple(comptime T1: type, comptime T2: type, comptime T3: type) type {
    return struct {
        first: T1,
        second: T2,
        third: T3,
        
        const Self = @This();
        
        pub fn init(first: T1, second: T2, third: T3) Self {
            return Self{ .first = first, .second = second, .third = third };
        }
    };
}

// Optional with default
pub fn Optional(comptime T: type) type {
    return struct {
        value: ?T,
        
        const Self = @This();
        
        pub fn some(value: T) Self {
            return Self{ .value = value };
        }
        
        pub fn none() Self {
            return Self{ .value = null };
        }
        
        pub fn unwrap(self: Self) T {
            return self.value.?;
        }
        
        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }
        
        pub fn isSome(self: Self) bool {
            return self.value != null;
        }
        
        pub fn isNone(self: Self) bool {
            return self.value == null;
        }
        
        pub fn map(self: Self, comptime f: fn (T) T) Self {
            if (self.value) |v| {
                return Self.some(f(v));
            }
            return Self.none();
        }
    };
}

// Result type
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,
        
        const Self = @This();
        
        pub fn ok(value: T) Self {
            return Self{ .ok = value };
        }
        
        pub fn err(e: E) Self {
            return Self{ .err = e };
        }
        
        pub fn isOk(self: Self) bool {
            return self == .ok;
        }
        
        pub fn isErr(self: Self) bool {
            return self == .err;
        }
        
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => unreachable,
            };
        }
        
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                .err => default,
            };
        }
    };
}

// Tests
test "Stack" {
    const allocator = std.testing.allocator;
    
    var stack = Stack(i32).init(allocator);
    defer stack.deinit();
    
    try stack.push(1);
    try stack.push(2);
    try stack.push(3);
    
    try std.testing.expectEqual(@as(usize, 3), stack.len());
    try std.testing.expectEqual(@as(?i32, 3), stack.pop());
    try std.testing.expectEqual(@as(?i32, 2), stack.pop());
    try std.testing.expectEqual(@as(?i32, 1), stack.pop());
    try std.testing.expect(stack.isEmpty());
}

test "Queue" {
    const allocator = std.testing.allocator;
    
    var queue = Queue(i32).init(allocator);
    defer queue.deinit();
    
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    
    try std.testing.expectEqual(@as(?i32, 1), queue.dequeue());
    try std.testing.expectEqual(@as(?i32, 2), queue.dequeue());
    try std.testing.expectEqual(@as(?i32, 3), queue.dequeue());
    try std.testing.expect(queue.isEmpty());
}

test "RingBuffer" {
    var rb = RingBuffer(i32, 3).init();
    
    try std.testing.expect(rb.push(1));
    try std.testing.expect(rb.push(2));
    try std.testing.expect(rb.push(3));
    try std.testing.expect(!rb.push(4)); // Full
    
    try std.testing.expectEqual(@as(?i32, 1), rb.pop());
    try std.testing.expect(rb.push(4)); // Now has space
}

test "Pair and Triple" {
    const pair = Pair(i32, []const u8).init(42, "hello");
    try std.testing.expectEqual(@as(i32, 42), pair.first);
    
    const triple = Triple(i32, i32, i32).init(1, 2, 3);
    try std.testing.expectEqual(@as(i32, 6), triple.first + triple.second + triple.third);
}

test "Optional" {
    const some = Optional(i32).some(42);
    const none = Optional(i32).none();
    
    try std.testing.expect(some.isSome());
    try std.testing.expect(none.isNone());
    try std.testing.expectEqual(@as(i32, 42), some.unwrap());
    try std.testing.expectEqual(@as(i32, 0), none.unwrapOr(0));
}

test "Result" {
    const ok_result = Result(i32, []const u8).ok(42);
    const err_result = Result(i32, []const u8).err("error");
    
    try std.testing.expect(ok_result.isOk());
    try std.testing.expect(err_result.isErr());
    try std.testing.expectEqual(@as(i32, 42), ok_result.unwrap());
    try std.testing.expectEqual(@as(i32, 0), err_result.unwrapOr(0));
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
