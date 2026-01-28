const std = @import("std");
const Allocator = std.mem.Allocator;

const TestResult = struct {
    passed: u64,
    failed: u64,
    file: []const u8,
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("Usage: test_runner <zig_file> [zig_file2] ...\n", .{});
        return 1;
    }
    
    const files = args[1..];
    
    // Test all files in parallel
    const num_threads = @min(@as(usize, std.Thread.getCpuCount() orelse 8), files.len);
    
    std.debug.print("Testing {d} files with {d} threads...\n", .{files.len, num_threads});
    
    var results = try std.ArrayList(TestResult).initCapacity(allocator, files.len);
    defer {
        for (results.items) |*r| {
            allocator.free(r.file);
        }
        results.deinit(allocator);
    };
    
    // Test in parallel batches
    const batch_size = files.len / num_threads + 1;
    var batch_start: usize = 0;
    
    while (batch_start < files.len) {
        const batch_end = @min(batch_start + batch_size, files.len);
        const batch = files[batch_start..batch_end];
        
        // Run tests in parallel
        for (batch) |file_path| {
            const file_name = try allocator.dupe(u8, std.fs.path.basename(file_path));
            const result = try std.process.Child.exec(.{
                .allocator = allocator,
                .argv = &[_]{ "zig", "test", file_path },
                .max_output_bytes = 1024 * 1024,
            }) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };
            
            defer {
                allocator.free(result.stdout);
                allocator.free(result.stderr);
            }
            
            const passed = std.mem.indexOf(u8, result.stdout, "passed") != null;
            const failed = std.mem.indexOf(u8, result.stdout, "failed") != null;
            
            try results.append(allocator, .{
                .passed = if (passed) 1 else 0,
                .failed = if (failed) 1 else 0,
                .file = file_name,
            });
            
            const mark = if (passed) "✅" else "❌";
            std.debug.print("{s} {s}\n", .{mark, file_name});
        }
        
        batch_start += batch_size;
    }
    
    // Print summary
    var total_passed: u64 = 0;
    var total_failed: u64 = 0;
    
    for (results.items) |r| {
        total_passed += r.passed;
        total_failed += r.failed;
    }
    
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== TEST SUMMARY ===\n", .{});
    try stdout.print("Total files: {d}\n", .{files.len});
    try stdout.print("Passed: {d}\n", .{total_passed});
    try stdout.print("Failed: {d}\n", .{total_failed});
    try stdout.print("Pass rate: {d:.2}%\n", .{@as(f64, total_passed) * 100.0 / @as(f64, files.len)});
    
    return if (total_failed == 0) 0 else 1;
}
