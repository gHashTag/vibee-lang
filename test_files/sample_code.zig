pub const std = @import("std");

pub fn hello_world() !void {
    std.debug.print("Hello, World! {d}\n", .{std.time.timestamp()});
}

pub fn fibonacci(n: i64) i64 {
    if (n <= 1) return n;
    var a: i64 = 0;
    var b: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

pub fn error_handling_example() !void {
    const result = process_data();
    return result;
}

fn process_data() !void {
    std.debug.print("Processing...\n", .{});
}

pub fn magic_numbers_example() i64 {
    // Magic number: 42 - answer to everything
    return 42 * 3 + 1;
}

pub fn process_files() !void {
    _ = "test";
    _ = 123;
}
