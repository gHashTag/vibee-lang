const std = @import("std");
const tvc_vm = @import("tvc_vm.zig");
const tvc_ir = @import("tvc_ir.zig");

// TVC Runtime - Standard Library for TVC Programs

pub const Trit = tvc_vm.Trit;
const NEG1 = tvc_vm.NEG1;
const ZERO = tvc_vm.ZERO;
const POS1 = tvc_vm.POS1;

// TVC MEMORY MANAGEMENT
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
        // Simple bump allocator - no free implementation
        // TODO: Implement garbage collection
    }

    pub fn used(self: *const TVCMemoryManager) usize {
        return @intFromPtr(self.heap_ptr) - @intFromPtr(self.heap_start);
    }

    pub fn available(self: *const TVCMemoryManager) usize {
        return self.heap_size - self.used();
    }
};

// TVC I/O OPERATIONS
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

    pub fn printInt64(n: i64) void {
        std.debug.print("{}\n", .{n});
    }

    pub fn printFloat64(f: f64) void {
        std.debug.print("{d:.6}\n", .{f});
    }

    pub fn readLine(allocator: std.mem.Allocator) ![]u8 {
        const stdin = std.io.getStdIn();
        const reader = stdin.reader();
        return reader.readAllAlloc(allocator, 1024) catch "";
    }

    pub fn writeToFile(path: []const u8, data: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(data);
    }

    pub fn readFromFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        return file.readToEndAlloc(allocator);
    }
};

// TVC MATH LIBRARY (Trinary Math)
pub const TVCMath = struct {
    // Trinary arithmetic operations
    pub fn add(a: Trit, b: Trit) Trit {
        return switch (@as(i2, @intFromEnum(a)) + @as(i2, @intFromEnum(b))) {
            -2 => NEG1,
            -1 => NEG1,
            0 => ZERO,
            1 => POS1,
            2 => POS1,
            else => unreachable,
        };
    }

    pub fn sub(a: Trit, b: Trit) Trit {
        return switch (@as(i2, @intFromEnum(a)) - @as(i2, @intFromEnum(b))) {
            -2 => NEG1,
            -1 => NEG1,
            0 => ZERO,
            1 => POS1,
            2 => POS1,
            else => unreachable,
        };
    }

    pub fn mul(a: Trit, b: Trit) Trit {
        return switch (@as(i2, @intFromEnum(a)) * @as(i2, @intFromEnum(b))) {
            1 => POS1,
            0 => ZERO,
            -1 => NEG1,
            else => unreachable,
        };
    }

    // Trinary comparison operations
    pub fn eq(a: Trit, b: Trit) Trit {
        return if (a == b) POS1 else NEG1;
    }

    pub fn neq(a: Trit, b: Trit) Trit {
        return if (a != b) POS1 else NEG1;
    }

    pub fn gt(a: Trit, b: Trit) Trit {
        return if (@as(i2, @intFromEnum(a)) > @as(i2, @intFromEnum(b))) POS1 else NEG1;
    }

    pub fn lt(a: Trit, b: Trit) Trit {
        return if (@as(i2, @intFromEnum(a)) < @as(i2, @intFromEnum(b))) POS1 else NEG1;
    }

    // Trinary absolute value
    pub fn abs(a: Trit) Trit {
        return switch (a) {
            NEG1 => POS1,
            ZERO => ZERO,
            POS1 => POS1,
        };
    }

    // Trinary negation
    pub fn neg(a: Trit) Trit {
        return tvc_vm.trinaryNot(a);
    }

    // Trinary logical operations (aliases)
    pub fn tritAnd(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryAnd(a, b);
    }

    pub fn tritOr(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryOr(a, b);
    }

    pub fn tritXor(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryXor(a, b);
    }

    pub fn tritImplies(a: Trit, b: Trit) Trit {
        return tvc_vm.trinaryImplies(a, b);
    }

    // Convert trit to signed integer
    pub fn tritToInt(t: Trit) i8 {
        return @intFromEnum(t);
    }

    // Convert signed integer to trit (clamp)
    pub fn intToTrit(n: i8) Trit {
        return switch (n) {
            -1 => NEG1,
            0 => ZERO,
            1 => POS1,
            else => if (n > 1) POS1 else NEG1,
        };
    }

    // Trinary min (for AND)
    pub fn tmin(a: Trit, b: Trit) Trit {
        return if (@as(i2, @intFromEnum(a)) < @as(i2, @intFromEnum(b))) a else b;
    }

    // Trinary max (for OR)
    pub fn tmax(a: Trit, b: Trit) Trit {
        return if (@as(i2, @intFromEnum(a)) > @as(i2, @intFromEnum(b))) a else b;
    }
};

// TVC STRING OPERATIONS
pub const TVCString = struct {
    pub fn compare(s1: []const u8, s2: []const u8) Trit {
        return if (std.mem.order(u8, s1, s2) == .lt) NEG1 else if (std.mem.order(u8, s1, s2) == .gt) POS1 else ZERO;
    }

    pub fn equals(s1: []const u8, s2: []const u8) bool {
        return std.mem.eql(u8, s1, s2);
    }

        return result;
    }
};

// TVC COLLECTION OPERATIONS
pub const TVCArray = struct {
    pub fn len(comptime T: type, arr: []const T) usize {
        return arr.len;
    }

    pub fn isEmpty(comptime T: type, arr: []const T) bool {
        return arr.len == 0;
    }

    pub fn get(comptime T: type, arr: []const T, index: usize) Trit {
        if (index >= arr.len) return NEG1;
        return if (arr[index] != 0) POS1 else NEG1;
    }

    pub fn set(comptime T: type, arr: []T, index: usize, value: T) Trit {
        if (index >= arr.len) return NEG1;
        arr[index] = value;
        return POS1;
    }

    pub fn push(comptime T: type, arr: *std.ArrayList(T), item: T) !void {
        try arr.append(item);
    }

    pub fn pop(comptime T: type, arr: *std.ArrayList(T)) ?T {
        if (arr.items.len == 0) return null;
        return arr.pop();
    }

    pub fn contains(comptime T: type, arr: []const T, item: T) Trit {
        for (arr) |x| {
            if (x == item) return POS1;
        }
        return NEG1;
    }

    pub fn indexOf(comptime T: type, arr: []const T, item: T) ?usize {
        for (arr, 0..) |x, i| {
            if (x == item) return i;
        }
        return null;
    }
};

// TVC ERROR HANDLING
pub const TVCError = union(enum) {
    Success,
    Error: []const u8,
};

pub fn toTVCError(err: anyerror) TVCError {
    return switch (err) {
        error.OutOfMemory => TVCError{ .Error = "OutOfMemory" },
        error.InvalidRange => TVCError{ .Error = "InvalidRange" },
        else => TVCError{ .Error = "Unknown" },
    };
}

// TVC CONSOLE / DEBUGGING
pub const TVCDebug = struct {
    pub fn printVMState(vm: *const tvc_vm.TVCVM) void {
        vm.dumpState();
    }

    pub fn printMemoryStats(mem: *const TVCMemoryManager) void {
        std.debug.print("Memory Stats:\n", .{});
        std.debug.print("  Used: {d} bytes\n", .{mem.used()});
        std.debug.print("  Available: {d} bytes\n", .{mem.available()});
        std.debug.print("  Total: {d} bytes\n", .{mem.heap_size});
    }

    pub fn printInstruction(inst: *const tvc_ir.TVCInstruction) void {
        std.debug.print("[@{d}] {s}", .{ inst.location, @tagName(inst.opcode) });
        if (inst.operands.len > 0) {
            std.debug.print(" operands={any}", .{inst.operands});
        }
        std.debug.print("\n", .{});
    }
};

// TVC RUNTIME INITIALIZATION
pub const TVCRuntime = struct {
    memory: TVCMemoryManager,

    pub fn init(allocator: std.mem.Allocator, heap_size: usize) !TVCRuntime {
        const memory = try TVCMemoryManager.init(allocator, heap_size);
        return TVCRuntime{
            .memory = memory,
        };
    }

    pub fn deinit(self: *TVCRuntime) void {
        self.memory.deinit();
    }
};
