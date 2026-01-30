const std = @import("std");
const tvc_vm = @import("tvc_vm.zig");
const tvc_ir = @import("tvc_ir.zig");

pub const Trit = tvc_vm.Trit;
const NEG1 = tvc_vm.NEG1;
const ZERO = tvc_vm.ZERO;
const POS1 = tvc_vm.POS1;

pub const TVCMemoryManager = struct {
    allocator: std.mem.Allocator,
    heap_size: usize,
    heap_start: [*]u8,
    heap_ptr: [*]u8,

    pub fn init(allocator: std.mem.Allocator, heap_size: usize) !TVCMemoryManager {
        const heap = try allocator.alloc(u8, heap_size);
        return TVCMemoryManager{
            .allocator = allocator,
            .heap_size = heap_size,
            .heap_start = heap,
            .heap_ptr = heap,
        };
    }

    pub fn deinit(self: *TVCMemoryManager) void {
        self.allocator.free(self.heap_start);
    }

    pub fn alloc(self: *TVCMemoryManager, size: usize) ![*]u8 {
        if (self.heap_ptr + size > self.heap_start + self.heap_size) {
            return error.OutOfMemory;
        }
        const ptr = self.heap_ptr;
        self.heap_ptr += size;
        return ptr;
    }

    pub fn free(self: *TVCMemoryManager, ptr: [*]u8) void {
        _ = self;
        _ = ptr;
    }

    pub fn used(self: *const TVCMemoryManager) usize {
        return @intFromPtr(self.heap_ptr) - @intFromPtr(self.heap_start);
    }

    pub fn available(self: *const TVCMemoryManager) usize {
        return self.heap_size - self.used();
    }
};

pub const TVCIO = struct {
    pub fn print(comptime fmt: []const u8, args: anytype) void {
        std.debug.print(fmt, args);
    }

    pub fn printTrit(t: Trit) void {
        std.debug.print("{s}\n", .{tvc_vm.tritToString(t)});
    }

    pub fn printTritArray(trits: []const Trit) void {
        std.debug.print("[", .{});
        for (trits, 0..) |t, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{s}", .{tvc_vm.tritToString(t)});
        }
        std.debug.print("]\n", .{});
    }
};

pub const TVCMath = struct {
    pub fn add(a: Trit, b: Trit) Trit {
        const result: i2 = @intFromEnum(a) + @intFromEnum(b);
        return if (result > 1) POS1 else if (result < -1) NEG1 else @enumFromInt(Trit, result);
    }

    pub fn sub(a: Trit, b: Trit) Trit {
        const result: i2 = @intFromEnum(a) - @intFromEnum(b);
        return if (result > 1) POS1 else if (result < -1) NEG1 else @enumFromInt(Trit, result);
    }

    pub fn mul(a: Trit, b: Trit) Trit {
        const result: i2 = @intFromEnum(a) * @intFromEnum(b);
        return if (result > 1) POS1 else if (result < -1) NEG1 else @enumFromInt(Trit, result);
    }

    pub fn eq(a: Trit, b: Trit) Trit {
        return if (a == b) POS1 else NEG1;
    }

    pub fn tritAnd(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryAnd(a, b);
    }

    pub fn tritOr(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryOr(a, b);
    }
};

pub const TVCRuntime = struct {
    pub fn init(allocator: std.mem.Allocator, heap_size: usize) !TVCRuntime {
        return TVCRuntime{};
    }

    pub fn deinit(self: *TVCRuntime) void {
        _ = self;
    }
};
