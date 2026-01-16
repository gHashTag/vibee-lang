// ═══════════════════════════════════════════════════════════════
// PARALLEL FILE PARSER for VIBEE
// Based on: "Scheduling Multithreaded Computations by Work Stealing"
//           (Blumofe & Leiserson, 1999)
// Expected speedup: Nx for N files on N cores
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");
const simd_parser = @import("simd_parser.zig");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// PARSE RESULT
// ═══════════════════════════════════════════════════════════════

pub const ParseResult = struct {
    path: []const u8,
    spec: ?parser.Spec,
    error_msg: ?[]const u8,
    parse_time_ns: u64,
    
    pub fn success(path: []const u8, spec: parser.Spec, time_ns: u64) ParseResult {
        return .{
            .path = path,
            .spec = spec,
            .error_msg = null,
            .parse_time_ns = time_ns,
        };
    }
    
    pub fn failure(path: []const u8, err: []const u8, time_ns: u64) ParseResult {
        return .{
            .path = path,
            .spec = null,
            .error_msg = err,
            .parse_time_ns = time_ns,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// PARSE TASK
// ═══════════════════════════════════════════════════════════════

const ParseTask = struct {
    path: []const u8,
    content: []const u8,
    allocator: Allocator,
    result: *ParseResult,
};

// ═══════════════════════════════════════════════════════════════
// PARALLEL PARSER
// ═══════════════════════════════════════════════════════════════

pub const ParallelParser = struct {
    allocator: Allocator,
    thread_pool: std.Thread.Pool,
    num_threads: usize,
    
    // Statistics
    total_files: usize,
    total_time_ns: u64,
    
    pub fn init(allocator: Allocator) !ParallelParser {
        const num_cpus = std.Thread.getCpuCount() catch 4;
        
        var pool: std.Thread.Pool = undefined;
        try pool.init(.{
            .allocator = allocator,
            .n_jobs = @intCast(num_cpus),
        });
        
        return .{
            .allocator = allocator,
            .thread_pool = pool,
            .num_threads = num_cpus,
            .total_files = 0,
            .total_time_ns = 0,
        };
    }
    
    pub fn deinit(self: *ParallelParser) void {
        self.thread_pool.deinit();
    }
    
    /// Parse multiple files in parallel
    /// Returns array of ParseResults (one per file)
    pub fn parseFiles(self: *ParallelParser, file_paths: []const []const u8) ![]ParseResult {
        const start_time = std.time.nanoTimestamp();
        
        // Allocate results array
        var results = try self.allocator.alloc(ParseResult, file_paths.len);
        
        // Read all files first (IO is often the bottleneck)
        var contents = try self.allocator.alloc([]const u8, file_paths.len);
        defer {
            for (contents) |c| {
                if (c.len > 0) self.allocator.free(c);
            }
            self.allocator.free(contents);
        }
        
        for (file_paths, 0..) |path, i| {
            contents[i] = self.readFile(path) catch "";
        }
        
        // Create wait group for synchronization
        var wg = std.Thread.WaitGroup{};
        
        // Spawn parse tasks
        for (file_paths, 0..) |path, i| {
            if (contents[i].len == 0) {
                results[i] = ParseResult.failure(path, "Failed to read file", 0);
                continue;
            }
            
            wg.start();
            self.thread_pool.spawn(parseWorker, .{
                self.allocator,
                path,
                contents[i],
                &results[i],
                &wg,
            }) catch {
                // Fallback to sequential if spawn fails
                results[i] = self.parseFileSync(path, contents[i]);
                wg.finish();
            };
        }
        
        // Wait for all tasks to complete
        wg.wait();
        
        const end_time = std.time.nanoTimestamp();
        self.total_time_ns = @intCast(end_time - start_time);
        self.total_files = file_paths.len;
        
        return results;
    }
    
    /// Worker function for parallel parsing
    fn parseWorker(
        allocator: Allocator,
        path: []const u8,
        content: []const u8,
        result: *ParseResult,
        wg: *std.Thread.WaitGroup,
    ) void {
        defer wg.finish();
        
        const start = std.time.nanoTimestamp();
        
        // Use adaptive parser (SIMD for large files, standard for small)
        var fast_parser = simd_parser.FastYamlParser.init(allocator);
        defer fast_parser.deinit();
        
        if (fast_parser.parse(content)) |spec| {
            const end = std.time.nanoTimestamp();
            result.* = ParseResult.success(path, spec, @intCast(end - start));
        } else |_| {
            const end = std.time.nanoTimestamp();
            result.* = ParseResult.failure(path, "Parse error", @intCast(end - start));
        }
    }
    
    /// Synchronous parse (fallback)
    fn parseFileSync(self: *ParallelParser, path: []const u8, content: []const u8) ParseResult {
        const start = std.time.nanoTimestamp();
        
        var fast_parser = simd_parser.FastYamlParser.init(self.allocator);
        defer fast_parser.deinit();
        
        if (fast_parser.parse(content)) |spec| {
            const end = std.time.nanoTimestamp();
            return ParseResult.success(path, spec, @intCast(end - start));
        } else |_| {
            const end = std.time.nanoTimestamp();
            return ParseResult.failure(path, "Parse error", @intCast(end - start));
        }
    }
    
    /// Read file content
    fn readFile(self: *ParallelParser, path: []const u8) ![]const u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        return try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB max
    }
    
    /// Get parallel efficiency (speedup / num_threads)
    pub fn getEfficiency(self: *ParallelParser, sequential_time_ns: u64) f64 {
        if (self.total_time_ns == 0) return 0;
        const speedup = @as(f64, @floatFromInt(sequential_time_ns)) / @as(f64, @floatFromInt(self.total_time_ns));
        return speedup / @as(f64, @floatFromInt(self.num_threads));
    }
    
    /// Get speedup factor
    pub fn getSpeedup(self: *ParallelParser, sequential_time_ns: u64) f64 {
        if (self.total_time_ns == 0) return 0;
        return @as(f64, @floatFromInt(sequential_time_ns)) / @as(f64, @floatFromInt(self.total_time_ns));
    }
};

// ═══════════════════════════════════════════════════════════════
// BATCH PARSER (simpler interface)
// ═══════════════════════════════════════════════════════════════

pub const BatchParser = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) BatchParser {
        return .{ .allocator = allocator };
    }
    
    /// Parse all .vibee files in a directory
    pub fn parseDirectory(self: *BatchParser, dir_path: []const u8) ![]ParseResult {
        var files = std.ArrayList([]const u8).init(self.allocator);
        defer files.deinit();
        
        // Find all .vibee files
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();
        
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".vibee")) {
                    const full_path = try std.fmt.allocPrint(
                        self.allocator,
                        "{s}/{s}",
                        .{ dir_path, entry.name }
                    );
                    try files.append(full_path);
                }
            }
        }
        
        // Parse in parallel
        var parallel = try ParallelParser.init(self.allocator);
        defer parallel.deinit();
        
        return try parallel.parseFiles(files.items);
    }
    
    /// Parse files sequentially (for comparison)
    pub fn parseSequential(self: *BatchParser, file_paths: []const []const u8) ![]ParseResult {
        var results = try self.allocator.alloc(ParseResult, file_paths.len);
        
        for (file_paths, 0..) |path, i| {
            const start = std.time.nanoTimestamp();
            
            const file = std.fs.cwd().openFile(path, .{}) catch {
                results[i] = ParseResult.failure(path, "Cannot open file", 0);
                continue;
            };
            defer file.close();
            
            const content = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch {
                results[i] = ParseResult.failure(path, "Cannot read file", 0);
                continue;
            };
            defer self.allocator.free(content);
            
            if (parser.parse(self.allocator, content)) |spec| {
                const end = std.time.nanoTimestamp();
                results[i] = ParseResult.success(path, spec, @intCast(end - start));
            } else |_| {
                const end = std.time.nanoTimestamp();
                results[i] = ParseResult.failure(path, "Parse error", @intCast(end - start));
            }
        }
        
        return results;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "parse result creation" {
    const success = ParseResult.success("test.vibee", undefined, 1000);
    try std.testing.expectEqualStrings("test.vibee", success.path);
    try std.testing.expect(success.error_msg == null);
    
    const failure = ParseResult.failure("bad.vibee", "error", 500);
    try std.testing.expect(failure.spec == null);
    try std.testing.expectEqualStrings("error", failure.error_msg.?);
}

test "parallel parser initialization" {
    var pp = try ParallelParser.init(std.testing.allocator);
    defer pp.deinit();
    
    try std.testing.expect(pp.num_threads > 0);
}

test "batch parser initialization" {
    const bp = BatchParser.init(std.testing.allocator);
    _ = bp;
}
