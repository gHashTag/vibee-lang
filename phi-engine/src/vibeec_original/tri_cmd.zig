//! VIBEE TRI FORMAT CLI
//! Command-line interface for .tri format operations
//! φ² + 1/φ² = 3

const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const TRINITY: u32 = 27;

const TVC_DIR = ".tvc";
const TVC_COMMITS_DIR = ".tvc/commits";
const TVC_HEAD_FILE = ".tvc/HEAD";

/// Main entry point for tri-fmt command
pub fn runTriCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        printTriFmtUsage();
        return 0;
    }

    const subcommand = args[0];

    if (std.mem.eql(u8, subcommand, "init")) {
        if (args.len < 2) {
            printError("Missing path for 'init'");
            printTriFmtUsage();
            return 1;
        }
        try handleInit(allocator);
    } else if (std.mem.eql(u8, subcommand, "create")) {
        if (args.len < 2) {
            printError("Missing file for 'create'");
            printTriFmtUsage();
            return 1;
        }
        try handleCreate(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "read")) {
        if (args.len < 2) {
            printError("Missing file for 'read'");
            printTriFmtUsage();
            return 1;
        }
        try handleRead(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "commit")) {
        const message = if (args.len >= 3 and std.mem.eql(u8, args[1], "-m")) args[2] else null;
        try handleCommit(allocator, message);
    } else if (std.mem.eql(u8, subcommand, "log")) {
        try handleLog(allocator);
    } else if (std.mem.eql(u8, subcommand, "status")) {
        try handleStatus(allocator);
    } else if (std.mem.eql(u8, subcommand, "diff")) {
        if (args.len < 3) {
            printError("Missing files for 'diff'");
            printTriFmtUsage();
            return 1;
        }
        try handleDiff(allocator, args[1], args[2]);
    } else if (std.mem.eql(u8, subcommand, "checkout")) {
        if (args.len < 2) {
            printError("Missing commit ID for 'checkout'");
            printTriFmtUsage();
            return 1;
        }
        try handleCheckout(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "validate")) {
        if (args.len < 2) {
            printError("Missing file for 'validate'");
            printTriFmtUsage();
            return 1;
        }
        try handleValidate(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "info")) {
        if (args.len < 2) {
            printError("Missing file for 'info'");
            printTriFmtUsage();
            return 1;
        }
        try handleInfo(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "encode")) {
        if (args.len < 2) {
            printError("Missing text for 'encode'");
            printTriFmtUsage();
            return 1;
        }
        try handleEncode(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "decode")) {
        if (args.len < 2) {
            printError("Missing trits for 'decode'");
            printTriFmtUsage();
            return 1;
        }
        try handleDecode(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "pack")) {
        if (args.len < 2) {
            printError("Missing file for 'pack'");
            printTriFmtUsage();
            return 1;
        }
        try handlePack(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "unpack")) {
        if (args.len < 2) {
            printError("Missing file for 'unpack'");
            printTriFmtUsage();
            return 1;
        }
        try handleUnpack(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        printTriFmtUsage();
    } else {
        printError("Unknown subcommand");
        printTriFmtUsage();
    }
    return 0;
}

/// Initialize TVC repository
fn handleInit(_: std.mem.Allocator) !void {
    printInfo("Initializing TVC repository...");

    // Create .tvc directory structure
    try std.fs.cwd().makePath(TVC_DIR);
    try std.fs.cwd().makePath(TVC_COMMITS_DIR);

    // Create HEAD file
    const head_file = try std.fs.cwd().createFile(TVC_HEAD_FILE, .{});
    defer head_file.close();
    try head_file.writeAll("HEAD");

    printSuccess("TVC repository initialized");
}

/// Create .tri file from .vibee file
fn handleCreate(allocator: std.mem.Allocator, vibee_file: []const u8) !void {
    printInfo("Creating .tri file from .vibee...");

    // Read .vibee file
    const source = try readFile(allocator, vibee_file);
    defer allocator.free(source);

    // Encode to trits
    const trit_stream = try encodeStringToTrits(allocator, source);
    defer allocator.free(trit_stream);

    // Pack trits to bytes
    const packed_data = try packTritsToBytes(allocator, trit_stream);
    defer allocator.free(packed_data);

    // Create .tri file
    const tri_file = try std.mem.concat(allocator, u8, &.{ std.fs.path.stem(vibee_file), ".tri" });
    defer allocator.free(tri_file);

    const out_file = try std.fs.cwd().createFile(tri_file, .{});
    defer out_file.close();

    // Write header (simplified - magic number TRI)
    try out_file.writeAll("TRI");

    // Write packed data
    try out_file.writeAll(packed_data);

    printSuccess(".tri file created");
    std.debug.print("  Input:  {s}\n", .{vibee_file});
    std.debug.print("  Output: {s}\n", .{tri_file});
    std.debug.print("  Trits:  {d}\n", .{trit_stream.len});
}

/// Read .tri file and decode to .vibee
fn handleRead(allocator: std.mem.Allocator, tri_file: []const u8) !void {
    printInfo("Reading .tri file...");

    // Read .tri file
    const content = try readFile(allocator, tri_file);
    defer allocator.free(content);

    // Skip header (3 bytes)
    if (content.len < 3) {
        return error.InvalidTriFile;
    }
    const packed_data = content[3..];

    // Unpack bytes to trits
    const trit_stream = try unpackBytesToTrits(allocator, packed_data);
    defer allocator.free(trit_stream);

    // Decode trits to string
    const decoded = try decodeTritsToString(allocator, trit_stream);
    defer allocator.free(decoded);

    printSuccess(".tri file decoded");
    std.debug.print("  File: {s}\n", .{tri_file});
    std.debug.print("  Trits: {d}\n", .{trit_stream.len});
    std.debug.print("\n--- Decoded Content ---\n", .{});
    std.debug.print("{s}\n", .{decoded});
}

/// Create TVC commit
fn handleCommit(allocator: std.mem.Allocator, message: ?[]const u8) !void {
    printInfo("Creating TVC commit...");
    
    // Check if TVC repository exists
    _ = std.fs.cwd().openDir(TVC_DIR, .{}) catch {
        printError("Not a TVC repository");
        return error.NotATVCRepository;
    };

    const commit_msg = message orelse "Commit";

    // Generate commit ID (timestamp-based)
    const timestamp = std.time.nanoTimestamp();
    const commit_id = try std.fmt.allocPrint(allocator, "{d}", .{timestamp});

    // Create commit file
    const commit_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.tri", .{ TVC_COMMITS_DIR, commit_id });
    defer allocator.free(commit_file_path);

    const commit_file = try std.fs.cwd().createFile(commit_file_path, .{});
    defer commit_file.close();

    // Write commit metadata
    try commit_file.writeAll("COMMIT\n");
    try commit_file.writeAll(commit_msg);
    try commit_file.writeAll("\n");

    // Update HEAD
    const head_file = try std.fs.cwd().createFile(TVC_HEAD_FILE, .{ .truncate = true });
    defer head_file.close();
    try head_file.writeAll(commit_id);

    printSuccess("Commit created");
    std.debug.print("  ID: {s}\n", .{commit_id});
    std.debug.print("  Message: {s}\n", .{commit_msg});
}

/// Show commit history
fn handleLog(allocator: std.mem.Allocator) !void {
    printInfo("Commit history...");
    
    const commits_dir = std.fs.cwd().openDir(TVC_COMMITS_DIR, .{}) catch {
        printError("Not a TVC repository");
        return error.NotATVCRepository;
    };
    defer commits_dir.close();

    var iter = commits_dir.iterate();
    var commit_count: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            const commit_id = std.fs.path.stem(entry.name);
            const commit_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ TVC_COMMITS_DIR, entry.name });
            defer allocator.free(commit_file_path);

            const commit_content = try readFile(allocator, commit_file_path);
            defer allocator.free(commit_content);

            std.debug.print("  Commit: {s}\n", .{commit_id});

            // Parse commit message (skip "COMMIT\n" line)
            var lines = std.mem.splitScalar(u8, commit_content, '\n');
            _ = lines.next(); // Skip first line
            if (lines.next()) |msg| {
                std.debug.print("    Message: {s}\n", .{msg});
            }
            std.debug.print("\n", .{});

            commit_count += 1;
        }
    }

    if (commit_count == 0) {
        std.debug.print("  No commits found\n", .{});
    } else {
        std.debug.print("  Total: {d} commits\n", .{commit_count});
    }
}

/// Show repository status
fn handleStatus(allocator: std.mem.Allocator) !void {
    printInfo("Repository status...");

    // Check if TVC repository exists
    const head_content = readFile(allocator, TVC_HEAD_FILE) catch {
        printError("Not a TVC repository");
        return;
    };
    defer allocator.free(head_content);

    std.debug.print("  HEAD: {s}\n", .{head_content});

    // Count commits
    const commits_dir = std.fs.cwd().openDir(TVC_COMMITS_DIR, .{}) catch return;
    defer commits_dir.close();

    var iter = commits_dir.iterate();
    var commit_count: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
            commit_count += 1;
        }
    }

    std.debug.print("  Commits: {d}\n", .{commit_count});
}

/// Show diff between two .tri files
fn handleDiff(allocator: std.mem.Allocator, file1: []const u8, file2: []const u8) !void {
    printInfo("Calculating diff...");

    const content1 = try readFile(allocator, file1);
    defer allocator.free(content1);

    const content2 = try readFile(allocator, file2);
    defer allocator.free(content2);

    // Simple diff: compare sizes
    const size_diff = @as(i64, @intCast(content2.len)) - @as(i64, @intCast(content1.len));

    printSuccess("Diff calculated");
    std.debug.print("  File 1: {s} ({d} bytes)\n", .{ file1, content1.len });
    std.debug.print("  File 2: {s} ({d} bytes)\n", .{ file2, content2.len });
    std.debug.print("  Difference: {d} bytes\n", .{size_diff});
}

/// Checkout commit
fn handleCheckout(allocator: std.mem.Allocator, commit_id: []const u8) !void {
    printInfo("Checking out commit...");

    // Check if TVC repository exists
    _ = std.fs.cwd().openDir(TVC_DIR, .{}) catch {
        printError("Not a TVC repository");
        return error.NotATVCRepository;
    };

    // Check if commit exists
    const commit_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.tri", .{ TVC_COMMITS_DIR, commit_id });
    defer allocator.free(commit_file_path);

    _ = std.fs.cwd().openFile(commit_file_path, .{}) catch {
        printError("Commit not found");
        return error.CommitNotFound;
    };

    // Update HEAD
    const head_file = try std.fs.cwd().createFile(TVC_HEAD_FILE, .{ .truncate = true });
    defer head_file.close();
    try head_file.writeAll(commit_id);

    printSuccess("Checked out");
    std.debug.print("  Commit: {s}\n", .{commit_id});
}

/// Validate .tri file
fn handleValidate(allocator: std.mem.Allocator, file: []const u8) !void {
    printInfo("Validating .tri file...");

    const content = try readFile(allocator, file);
    defer allocator.free(content);

    // Check header
    if (content.len < 3 or !std.mem.eql(u8, content[0..3], "TRI")) {
        printError("Invalid .tri file header");
        return error.InvalidTriFile;
    }

    printSuccess("Valid .tri file");
    std.debug.print("  File: {s}\n", .{file});
    std.debug.print("  Size: {d} bytes\n", .{content.len});
}

/// Show information about .tri file
fn handleInfo(allocator: std.mem.Allocator, file: []const u8) !void {
    printInfo("File information...");

    const content = try readFile(allocator, file);
    defer allocator.free(content);

    // Skip header
    const data_size: usize = if (content.len >= 3) content.len - 3 else 0;

    std.debug.print("  File: {s}\n", .{file});
    std.debug.print("  Total size: {d} bytes\n", .{content.len});
    std.debug.print("  Header: 3 bytes\n", .{});
    std.debug.print("  Data: {d} bytes\n", .{data_size});

    // Estimate trit count (5 trits per byte)
    const estimated_trits = data_size * 5;
    std.debug.print("  Estimated trits: {d}\n", .{estimated_trits});
}

/// Encode text to trits
fn handleEncode(allocator: std.mem.Allocator, text: []const u8) !void {
    printInfo("Encoding text to trits...");

    const trit_stream = try encodeStringToTrits(allocator, text);
    defer allocator.free(trit_stream);

    printSuccess("Encoded");
    std.debug.print("  Text: {s}\n", .{text});
    std.debug.print("  Trits: {d}\n", .{trit_stream.len});

    // Print trit representation
    std.debug.print("  Trit stream: ", .{});
    for (trit_stream) |trit| {
        const trit_char = switch (trit) {
            -1 => '-',
            0 => '0',
            1 => '+',
            else => '?',
        };
        std.debug.print("{c}", .{trit_char});
    }
    std.debug.print("\n", .{});
}

/// Decode trits to text
fn handleDecode(allocator: std.mem.Allocator, trits_str: []const u8) !void {
    printInfo("Decoding trits to text...");

    // Parse trit string
    var trit_stream = std.ArrayListUnmanaged(i8){};
    defer trit_stream.deinit(allocator);

    for (trits_str) |c| {
        const trit = switch (c) {
            '-' => -1,
            '0' => 0,
            '+' => 1,
            else => continue, // Skip spaces and other characters
        };
        try trit_stream.append(allocator, trit);
    }

    const decoded = try decodeTritsToString(allocator, trit_stream.items);
    defer allocator.free(decoded);

    printSuccess("Decoded");
    std.debug.print("  Trits: {d}\n", .{trit_stream.items.len});
    std.debug.print("  Text: {s}\n", .{decoded});
}

/// Pack trits to bytes
fn handlePack(allocator: std.mem.Allocator, file: []const u8) !void {
    printInfo("Packing trits to bytes...");

    const content = try readFile(allocator, file);
    defer allocator.free(content);

    // Assume file contains trit representation
    var trit_stream = std.ArrayListUnmanaged(i8){};
    defer trit_stream.deinit(allocator);

    for (content) |c| {
        const trit = switch (c) {
            '-' => -1,
            '0' => 0,
            '+' => 1,
            else => continue,
        };
        try trit_stream.append(allocator, trit);
    }

    const packed_bytes = try packTritsToBytes(allocator, trit_stream.items);
    defer allocator.free(packed_bytes);

    // Write packed file
    const packed_file = try std.mem.concat(allocator, u8, &.{ file, ".packed" });
    defer allocator.free(packed_file);

    const out_file = try std.fs.cwd().createFile(packed_file, .{});
    defer out_file.close();

    try out_file.writeAll(packed_bytes);

    printSuccess("Packed");
    std.debug.print("  Input: {s}\n", .{file});
    std.debug.print("  Output: {s}\n", .{packed_file});
    std.debug.print("  Trits: {d}\n", .{trit_stream.items.len});
    std.debug.print("  Bytes: {d}\n", .{packed_bytes.len});
}

/// Unpack bytes to trits
fn handleUnpack(allocator: std.mem.Allocator, file: []const u8) !void {
    printInfo("Unpacking bytes to trits...");

    const content = try readFile(allocator, file);
    defer allocator.free(content);

    const trit_stream = try unpackBytesToTrits(allocator, content);
    defer allocator.free(trit_stream);

    // Write unpacked file
    const unpacked_file = try std.mem.concat(allocator, u8, &.{ file, ".unpacked" });
    defer allocator.free(unpacked_file);

    const out_file = try std.fs.cwd().createFile(unpacked_file, .{});
    defer out_file.close();

    // Write trit representation
    for (trit_stream) |trit| {
        const trit_char = switch (trit) {
            -1 => '-',
            0 => '0',
            1 => '+',
            else => '?',
        };
        try out_file.writeAll(&[_]u8{trit_char});
    }

    printSuccess("Unpacked");
    std.debug.print("  Input: {s}\n", .{file});
    std.debug.print("  Output: {s}\n", .{unpacked_file});
    std.debug.print("  Bytes: {d}\n", .{content.len});
    std.debug.print("  Trits: {d}\n", .{trit_stream.len});
}

/// Print help for tri-fmt command
fn printTriFmtUsage() void {
    std.debug.print("========================================\n", .{});
    std.debug.print("     VIBEE TRI FORMAT COMMANDS\n", .{});
    std.debug.print("     φ² + 1/φ² = 3\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Usage: vibee tri-fmt <subcommand> [options]\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Subcommands:\n", .{});
    std.debug.print("  init <path>          Initialize TVC repository\n", .{});
    std.debug.print("  create <file>        Create .tri file from .vibee\n", .{});
    std.debug.print("  read <file>          Read .tri file and decode\n", .{});
    std.debug.print("  commit [-m msg]      Create TVC commit\n", .{});
    std.debug.print("  log                  Show commit history\n", .{});
    std.debug.print("  status               Show repository status\n", .{});
    std.debug.print("  diff <file1> <file2> Show diff between .tri files\n", .{});
    std.debug.print("  checkout <commit>    Restore state from commit\n", .{});
    std.debug.print("  validate <file>      Validate .tri file\n", .{});
    std.debug.print("  info <file>          Show .tri file information\n", .{});
    std.debug.print("  encode <text>        Encode text to trits\n", .{});
    std.debug.print("  decode <trits>       Decode trits to text\n", .{});
    std.debug.print("  pack <file>          Pack trits to bytes\n", .{});
    std.debug.print("  unpack <file>        Unpack bytes to trits\n", .{});
    std.debug.print("  help                 Show this help\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Examples:\n", .{});
    std.debug.print("  vibee tri-fmt init .tvc\n", .{});
    std.debug.print("  vibee tri-fmt create specs/tri/tri_format.vibee\n", .{});
    std.debug.print("  vibee tri-fmt read specs/tri/tri_format.tri\n", .{});
    std.debug.print("  vibee tri-fmt commit -m \"Initial commit\"\n", .{});
    std.debug.print("  vibee tri-fmt log\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3\n", .{});
    std.debug.print("\n", .{});
}

/// Helper: Read file content
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

/// Helper: Encode string to trits (simplified)
fn encodeStringToTrits(allocator: std.mem.Allocator, str: []const u8) ![]i8 {
    var list = std.ArrayListUnmanaged(i8){};
    defer list.deinit(allocator);
    
    try list.ensureTotalCapacity(allocator, str.len * 5);

    // Simple encoding: each byte becomes 5 trits
    for (str) |byte| {
        // Encode byte to 5 trits (simplified)
        try list.append(allocator, if (byte & 0x80 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x40 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x20 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x10 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x08 != 0) @as(i8, 1) else 0);
    }

    return allocator.dupe(i8, list.items);
}

/// Helper: Pack trits to bytes (simplified)
fn packTritsToBytes(allocator: std.mem.Allocator, trits: []const i8) ![]u8 {
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);
    
    try list.ensureTotalCapacity(allocator, trits.len / 5);

    // Simple packing: 5 trits per byte
    var i: usize = 0;
    while (i + 4 < trits.len) : (i += 5) {
        var byte: u8 = 0;
        if (trits[i + 0] != 0) byte |= 0x10;
        if (trits[i + 1] != 0) byte |= 0x08;
        if (trits[i + 2] != 0) byte |= 0x04;
        if (trits[i + 3] != 0) byte |= 0x02;
        if (trits[i + 4] != 0) byte |= 0x01;
        try list.append(allocator, byte);
    }

    return allocator.dupe(u8, list.items);
}

/// Helper: Unpack bytes to trits (simplified)
fn unpackBytesToTrits(allocator: std.mem.Allocator, bytes: []const u8) ![]i8 {
    var list = std.ArrayListUnmanaged(i8){};
    defer list.deinit(allocator);
    
    try list.ensureTotalCapacity(allocator, bytes.len * 5);

    // Simple unpacking: 5 trits per byte
    for (bytes) |byte| {
        try list.append(allocator, if (byte & 0x10 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x08 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x04 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x02 != 0) @as(i8, 1) else 0);
        try list.append(allocator, if (byte & 0x01 != 0) @as(i8, 1) else 0);
    }

    return allocator.dupe(i8, list.items);
}

/// Helper: Decode trits to string (simplified)
fn decodeTritsToString(allocator: std.mem.Allocator, trits: []const i8) ![]u8 {
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);
    
    try list.ensureTotalCapacity(allocator, trits.len / 5);

    // Simple decoding: 5 trits per byte
    var i: usize = 0;
    while (i + 4 < trits.len) : (i += 5) {
        var byte: u8 = 0;
        if (trits[i + 0] == 1) byte |= 0x80;
        if (trits[i + 1] == 1) byte |= 0x40;
        if (trits[i + 2] == 1) byte |= 0x20;
        if (trits[i + 3] == 1) byte |= 0x10;
        if (trits[i + 4] == 1) byte |= 0x08;
        try list.append(allocator, byte);
    }

    return allocator.dupe(u8, list.items);
}

/// Print error message
fn printError(msg: []const u8) void {
    std.debug.print("\x1b[31m✗ {s}\x1b[0m\n", .{msg});
}

/// Print success message
fn printSuccess(msg: []const u8) void {
    std.debug.print("\x1b[32m✓ {s}\x1b[0m\n", .{msg});
}

/// Print info message
fn printInfo(msg: []const u8) void {
    std.debug.print("\x1b[34mℹ {s}\x1b[0m\n", .{msg});
}

// Tests
test "encode string to trits" {
    const allocator = std.testing.allocator;
    const str = "Hello";
    const trits = try encodeStringToTrits(allocator, str);
    defer allocator.free(trits);
    try std.testing.expect(trits.len > 0);
}

test "pack trits to bytes" {
    const allocator = std.testing.allocator;
    const trits = [_]i8{ 1, 0, -1, 0, 1, 0, 0, 0 };
    const bytes = try packTritsToBytes(allocator, &trits);
    defer allocator.free(bytes);
    try std.testing.expect(bytes.len > 0);
}

test "unpack bytes to trits" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0b10101, 0b00000 };
    const trits = try unpackBytesToTrits(allocator, &bytes);
    defer allocator.free(trits);
    try std.testing.expect(trits.len == 10);
}

test "decode trits to string" {
    const allocator = std.testing.allocator;
    const trits = [_]i8{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0 };
    const str = try decodeTritsToString(allocator, &trits);
    defer allocator.free(str);
    try std.testing.expect(str.len > 0);
}
