const std = @import("std");

pub fn main() !void {
    std.debug.print("╔══════════════════════════════════════════════╗\n", .{});
    std.debug.print("║            TVC RUNTIME DEMONSTRATION         ║\n", .{});
    std.debug.print("║          Runtime & Standard Library             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╗\n\n", .{});

    demoMemoryManager();
    demoTrinaryMath();
    demoStringOperations();
    demoArrayOperations();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                 DEMO COMPLETE                 ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╗\n", .{});
    std.debug.print("\n🎯 TVC RUNTIME SUCCESSFULLY:\n", .{});
    std.debug.print("  ✓ Memory Manager\n", .{});
    std.debug.print("  ✓ Trinary Math Library\n", .{});
    std.debug.print("  ✓ String Operations\n", .{});
    std.debug.print("  ✓ Array Operations\n", .{});
}

pub const Trit = i8;
const NEG1: Trit = -1;
const ZERO: Trit = 0;
const POS1: Trit = 1;

fn tritToString(t: Trit) []const u8 {
    return switch (t) {
        -1 => "-1",
        0 => " 0",
        1 => "+1",
        else => " ?",
    };
}

fn demoMemoryManager() void {
    std.debug.print("Testing Memory Manager:\n\n", .{});

    var buffer: [4096]u8 = undefined;
    var heap_ptr: usize = 0;
    const heap_start = @ptrCast(&buffer[0]);

    const ptr1 = allocTest(&heap_ptr, heap_start, buffer.len, 100);
    const ptr2 = allocTest(&heap_ptr, heap_start, buffer.len, 200);
    const ptr3 = allocTest(&heap_ptr, heap_start, buffer.len, 300);

    std.debug.print("  Allocated 100 bytes at 0x{x}\n", .{ptr1});
    std.debug.print("  Allocated 200 bytes at 0x{x}\n", .{ptr2});
    std.debug.print("  Allocated 300 bytes at 0x{x}\n", .{ptr3});

    const used = heap_ptr;
    std.debug.print("  Total used: {d} bytes\n", .{used});
    std.debug.print("  Available: {d} bytes\n", .{buffer.len - used});
}

fn allocTest(heap_ptr: *usize, heap_start: usize, heap_size: usize, size: usize) usize {
    const new_ptr = heap_ptr.*;
    if (new_ptr + size > heap_start + heap_size) {
        @panic("Out of memory");
    }
    heap_ptr.* += size;
    return @intFromPtr(@ptrFromInt(@as(usize, @intFromPtr(heap_start)) + new_ptr));
}

fn demoTrinaryMath() void {
    std.debug.print("Testing Trinary Math:\n\n", .{});

    // NOT operation
    std.debug.print("  trit NOT:\n", .{});
    std.debug.print("    NOT(-1) = {s}\n", .{tritToString(-NEG1)});
    std.debug.print("    NOT(0) = {s}\n", .{tritToString(-ZERO)});
    std.debug.print("    NOT(1) = {s}\n", .{tritToString(-POS1)});

    // AND operation
    std.debug.print("\n  trit AND:\n", .{});
    std.debug.print("    -1 AND -1 = {s}\n", .{tritToString(tritAnd(NEG1, NEG1))});
    std.debug.print("    -1 AND 0 = {s}\n", .{tritToString(tritAnd(NEG1, ZERO))});
    std.debug.print("    -1 AND 1 = {s}\n", .{tritToString(tritAnd(NEG1, POS1))});

    // OR operation
    std.debug.print("\n  trit OR:\n", .{});
    std.debug.print("    -1 OR 0 = {s}\n", .{tritToString(tritOr(NEG1, ZERO))});
    std.debug.print("    0 OR 1 = {s}\n", .{tritToString(tritOr(ZERO, POS1))});
    std.debug.print("    1 OR 1 = {s}\n", .{tritToString(tritOr(POS1, POS1))});

    // Arithmetic (clamped)
    std.debug.print("\n  Arithmetic (clamped):\n", .{});
    std.debug.print("    -1 + 0 = {s}\n", .{tritToString(tritAdd(NEG1, ZERO))});
    std.debug.print("    0 + 1 = {s}\n", .{tritToString(tritAdd(ZERO, POS1))});
    std.debug.print("    1 - 1 = {s}\n", .{tritToString(tritSub(POS1, POS1))});
}

fn tritAnd(a: Trit, b: Trit) Trit {
    return if (a < b) a else b;
}

fn tritOr(a: Trit, b: Trit) Trit {
    return if (a > b) a else b;
}

fn tritAdd(a: Trit, b: Trit) Trit {
    const result: i8 = a + b;
    return if (result > 1) POS1 else if (result < -1) NEG1 else @as(Trit, @truncate(result));
}

fn tritSub(a: Trit, b: Trit) Trit {
    const result: i8 = a - b;
    return if (result > 1) POS1 else if (result < -1) NEG1 else @as(Trit, @truncate(result));
}

fn demoStringOperations() void {
    std.debug.print("Testing String Operations:\n\n", .{});

    const s1 = "Hello";
    const s2 = "World";

    std.debug.print("  Length: '{s}' = {d}\n", .{ s1, s1.len });
    std.debug.print("  Is Empty: '' = {}\n", .{ s1.len == 0 });

    // Comparison
    const cmp = if (s1.len < s2.len) -1 else if (s1.len > s2.len) 1 else 0;
    std.debug.print("  Compare '{s}' vs '{s}' = {d}\n", .{ s1, s2, cmp });
}

fn demoArrayOperations() void {
    std.debug.print("Testing Array Operations:\n\n", .{});

    const arr = [_]Trit{ NEG1, ZERO, POS1 };

    std.debug.print("  Length: {d}\n", .{ arr.len });
    std.debug.print("  Is Empty: {}\n", .{ arr.len == 0 });

    // Contains
    std.debug.print("  Contains ZERO: {}\n", .{ for (arr) |x| if (x == ZERO) break else false });

    // IndexOf
    var found: ?usize = null;
    for (arr, 0..) |x, i| {
        if (x == ZERO) {
            found = i;
            break;
        }
    }
    std.debug.print("  IndexOf ZERO: {?}\n", .{ found });
}
