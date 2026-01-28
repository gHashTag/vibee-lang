const std = @import("std");

pub fn main() !void {
    std.io.stdout.writeAll("Hello, world!") catch {
        std.os.exit(1);
    };
}
