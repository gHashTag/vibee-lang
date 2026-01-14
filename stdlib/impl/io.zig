// ============================================================================
// VIBEE STDLIB - IO MODULE
// Input/Output functions
// ============================================================================

const std = @import("std");
const fs = std.fs;

// ============================================================================
// STANDARD OUTPUT
// ============================================================================

/// Print string to stdout
pub fn print(s: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.writeAll(s) catch {};
}

/// Print string with newline
pub fn println(s: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.writeAll(s) catch {};
    stdout.writeAll("\n") catch {};
}

/// Print formatted string
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch {};
}

// ============================================================================
// STANDARD ERROR
// ============================================================================

/// Print to stderr
pub fn eprint(s: []const u8) void {
    const stderr = std.io.getStdErr().writer();
    stderr.writeAll(s) catch {};
}

/// Print to stderr with newline
pub fn eprintln(s: []const u8) void {
    const stderr = std.io.getStdErr().writer();
    stderr.writeAll(s) catch {};
    stderr.writeAll("\n") catch {};
}

// ============================================================================
// STANDARD INPUT
// ============================================================================

/// Read line from stdin
pub fn readLine(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.io.getStdIn().reader();
    return stdin.readUntilDelimiterAlloc(allocator, '\n', 4096) catch |err| {
        if (err == error.EndOfStream) return try allocator.alloc(u8, 0);
        return err;
    };
}

/// Read all from stdin
pub fn readAll(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.io.getStdIn().reader();
    return stdin.readAllAlloc(allocator, 1024 * 1024);
}

// ============================================================================
// FILE OPERATIONS
// ============================================================================

/// Read entire file to string
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return fs.cwd().readFileAlloc(allocator, path, 1024 * 1024 * 10);
}

/// Write string to file
pub fn writeFile(path: []const u8, content: []const u8) !void {
    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

/// Append string to file
pub fn appendFile(path: []const u8, content: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{ .mode = .write_only });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writeAll(content);
}

/// Check if file exists
pub fn fileExists(path: []const u8) bool {
    fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Delete file
pub fn deleteFile(path: []const u8) !void {
    try fs.cwd().deleteFile(path);
}

/// Copy file
pub fn copyFile(src: []const u8, dst: []const u8) !void {
    try fs.cwd().copyFile(src, fs.cwd(), dst, .{});
}

/// Rename/move file
pub fn renameFile(old_path: []const u8, new_path: []const u8) !void {
    try fs.cwd().rename(old_path, new_path);
}

// ============================================================================
// DIRECTORY OPERATIONS
// ============================================================================

/// Create directory
pub fn createDir(path: []const u8) !void {
    try fs.cwd().makeDir(path);
}

/// Create directory and parents
pub fn createDirAll(path: []const u8) !void {
    try fs.cwd().makePath(path);
}

/// Delete directory
pub fn deleteDir(path: []const u8) !void {
    try fs.cwd().deleteDir(path);
}

/// Delete directory recursively
pub fn deleteDirAll(path: []const u8) !void {
    try fs.cwd().deleteTree(path);
}

/// Check if directory exists
pub fn dirExists(path: []const u8) bool {
    const stat = fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

/// List directory contents
pub fn listDir(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    
    var entries = std.ArrayList([]const u8).init(allocator);
    var iter = dir.iterate();
    
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(name);
    }
    
    return entries.toOwnedSlice();
}

// ============================================================================
// FILE INFO
// ============================================================================

pub const FileInfo = struct {
    size: u64,
    is_dir: bool,
    is_file: bool,
    is_symlink: bool,
};

/// Get file info
pub fn getFileInfo(path: []const u8) !FileInfo {
    const s = try fs.cwd().statFile(path);
    return FileInfo{
        .size = s.size,
        .is_dir = s.kind == .directory,
        .is_file = s.kind == .file,
        .is_symlink = s.kind == .sym_link,
    };
}

/// Get file size
pub fn fileSize(path: []const u8) !u64 {
    const s = try fs.cwd().statFile(path);
    return s.size;
}

// ============================================================================
// PATH UTILITIES
// ============================================================================

/// Join path components
pub fn joinPath(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    return fs.path.join(allocator, parts);
}

/// Get directory name from path
pub fn dirname(path: []const u8) []const u8 {
    return fs.path.dirname(path) orelse ".";
}

/// Get file name from path
pub fn basename(path: []const u8) []const u8 {
    return fs.path.basename(path);
}

/// Get file extension
pub fn extension(path: []const u8) []const u8 {
    return fs.path.extension(path);
}

/// Get absolute path
pub fn absolutePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return fs.cwd().realpathAlloc(allocator, path);
}

// ============================================================================
// BUFFERED IO
// ============================================================================

pub const BufferedWriter = struct {
    file: fs.File,
    buffer: std.io.BufferedWriter(4096, fs.File.Writer),
    
    pub fn init(path: []const u8) !BufferedWriter {
        const file = try fs.cwd().createFile(path, .{});
        return BufferedWriter{
            .file = file,
            .buffer = std.io.bufferedWriter(file.writer()),
        };
    }
    
    pub fn write(self: *BufferedWriter, data: []const u8) !void {
        try self.buffer.writer().writeAll(data);
    }
    
    pub fn writeLine(self: *BufferedWriter, data: []const u8) !void {
        try self.buffer.writer().writeAll(data);
        try self.buffer.writer().writeAll("\n");
    }
    
    pub fn flush(self: *BufferedWriter) !void {
        try self.buffer.flush();
    }
    
    pub fn close(self: *BufferedWriter) void {
        self.buffer.flush() catch {};
        self.file.close();
    }
};

pub const BufferedReader = struct {
    file: fs.File,
    buffer: std.io.BufferedReader(4096, fs.File.Reader),
    
    pub fn init(path: []const u8) !BufferedReader {
        const file = try fs.cwd().openFile(path, .{});
        return BufferedReader{
            .file = file,
            .buffer = std.io.bufferedReader(file.reader()),
        };
    }
    
    pub fn readLine(self: *BufferedReader, allocator: std.mem.Allocator) !?[]u8 {
        return self.buffer.reader().readUntilDelimiterAlloc(allocator, '\n', 4096) catch |err| {
            if (err == error.EndOfStream) return null;
            return err;
        };
    }
    
    pub fn close(self: *BufferedReader) void {
        self.file.close();
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "print functions compile" {
    // Just verify they compile - actual output testing is tricky
    _ = print;
    _ = println;
    _ = eprint;
    _ = eprintln;
}

test "path utilities" {
    try std.testing.expectEqualStrings("file.txt", basename("/path/to/file.txt"));
    try std.testing.expectEqualStrings(".txt", extension("file.txt"));
}

test "file operations" {
    const test_file = "/tmp/vibee_io_test.txt";
    const content = "Hello, VIBEE!";
    
    // Write
    try writeFile(test_file, content);
    try std.testing.expect(fileExists(test_file));
    
    // Read
    const read_content = try readFile(std.testing.allocator, test_file);
    defer std.testing.allocator.free(read_content);
    try std.testing.expectEqualStrings(content, read_content);
    
    // Size
    const size = try fileSize(test_file);
    try std.testing.expectEqual(@as(u64, content.len), size);
    
    // Delete
    try deleteFile(test_file);
    try std.testing.expect(!fileExists(test_file));
}

test "directory operations" {
    const test_dir = "/tmp/vibee_dir_test";
    
    // Create
    createDir(test_dir) catch {};
    try std.testing.expect(dirExists(test_dir));
    
    // Delete
    try deleteDir(test_dir);
    try std.testing.expect(!dirExists(test_dir));
}
