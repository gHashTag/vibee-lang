// ═══════════════════════════════════════════════════════════════
// CI VALIDATION for VIBEE
// Ensures all .zig files have corresponding .vibee sources
// Validates architecture compliance
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// VALIDATION RESULT
// ═══════════════════════════════════════════════════════════════

pub const ValidationResult = struct {
    passed: bool,
    total_zig_files: u32,
    zig_with_vibee: u32,
    zig_without_vibee: u32,
    violations: std.ArrayList(Violation),
    
    pub const Violation = struct {
        zig_path: []const u8,
        expected_vibee: []const u8,
        severity: Severity,
        message: []const u8,
    };
    
    pub const Severity = enum {
        err,
        warning,
        info,
    };
    
    pub fn print(self: ValidationResult, writer: anytype) !void {
        try writer.print(
            \\╔══════════════════════════════════════════════════════════════╗
            \\║  CI VALIDATION REPORT                                        ║
            \\╚══════════════════════════════════════════════════════════════╝
            \\
            \\Status: {s}
            \\
            \\Files:
            \\  Total .zig files: {}
            \\  With .vibee source: {}
            \\  Without .vibee source: {} {s}
            \\
            \\Coverage: {d:.1}%
            \\
        , .{
            if (self.passed) "✅ PASSED" else "❌ FAILED",
            self.total_zig_files,
            self.zig_with_vibee,
            self.zig_without_vibee,
            if (self.zig_without_vibee > 0) "⚠️" else "",
            if (self.total_zig_files > 0)
                @as(f64, @floatFromInt(self.zig_with_vibee)) / @as(f64, @floatFromInt(self.total_zig_files)) * 100
            else
                0.0,
        });
        
        if (self.violations.items.len > 0) {
            try writer.writeAll("\nViolations:\n");
            for (self.violations.items) |v| {
                const icon = switch (v.severity) {
                    .err => "X",
                    .warning => "!",
                    .info => "i",
                };
                try writer.print("  {s} {s}\n", .{ icon, v.message });
                try writer.print("     File: {s}\n", .{v.zig_path});
                try writer.print("     Expected: {s}\n", .{v.expected_vibee});
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// CI VALIDATOR
// ═══════════════════════════════════════════════════════════════

pub const CIValidator = struct {
    allocator: Allocator,
    src_path: []const u8,
    specs_path: []const u8,
    
    // Exceptions - files that don't need .vibee sources
    exceptions: std.StringHashMap(void),
    
    pub fn init(allocator: Allocator) CIValidator {
        var validator = CIValidator{
            .allocator = allocator,
            .src_path = "src",
            .specs_path = "specs",
            .exceptions = std.StringHashMap(void).init(allocator),
        };
        
        // Add known exceptions (bootstrap files)
        validator.addException("build.zig") catch {};
        validator.addException("main.zig") catch {}; // Entry point
        
        return validator;
    }
    
    pub fn deinit(self: *CIValidator) void {
        self.exceptions.deinit();
    }
    
    pub fn addException(self: *CIValidator, filename: []const u8) !void {
        try self.exceptions.put(filename, {});
    }
    
    /// Validate all .zig files have .vibee sources
    pub fn validate(self: *CIValidator) !ValidationResult {
        var result = ValidationResult{
            .passed = true,
            .total_zig_files = 0,
            .zig_with_vibee = 0,
            .zig_without_vibee = 0,
            .violations = std.ArrayList(ValidationResult.Violation).init(self.allocator),
        };
        
        // Find all .zig files
        try self.scanDirectory(self.src_path, &result);
        
        // Determine pass/fail
        result.passed = result.zig_without_vibee == 0;
        
        return result;
    }
    
    fn scanDirectory(self: *CIValidator, path: []const u8, result: *ValidationResult) !void {
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                // Skip .zig-cache
                if (std.mem.eql(u8, entry.name, ".zig-cache")) continue;
                
                const subpath = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}/{s}",
                    .{ path, entry.name }
                );
                defer self.allocator.free(subpath);
                
                try self.scanDirectory(subpath, result);
            } else if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".zig")) {
                    result.total_zig_files += 1;
                    
                    // Check if exception
                    if (self.exceptions.contains(entry.name)) {
                        result.zig_with_vibee += 1;
                        continue;
                    }
                    
                    // Check for corresponding .vibee
                    const has_vibee = try self.hasVibeeSource(entry.name);
                    
                    if (has_vibee) {
                        result.zig_with_vibee += 1;
                    } else {
                        result.zig_without_vibee += 1;
                        
                        const full_path = try std.fmt.allocPrint(
                            self.allocator,
                            "{s}/{s}",
                            .{ path, entry.name }
                        );
                        
                        const expected = try self.getExpectedVibeePath(entry.name);
                        
                        try result.violations.append(.{
                            .zig_path = full_path,
                            .expected_vibee = expected,
                            .severity = .warning,
                            .message = try std.fmt.allocPrint(
                                self.allocator,
                                "Missing .vibee source for {s}",
                                .{entry.name}
                            ),
                        });
                    }
                }
            }
        }
    }
    
    fn hasVibeeSource(self: *CIValidator, zig_filename: []const u8) !bool {
        // Convert .zig to .vibee
        const base_name = zig_filename[0 .. zig_filename.len - 4]; // Remove .zig
        
        // Check multiple possible locations
        const possible_paths = [_][]const u8{
            try std.fmt.allocPrint(self.allocator, "{s}/{s}.vibee", .{ self.specs_path, base_name }),
            try std.fmt.allocPrint(self.allocator, "{s}/999/ⲥⲩⲛⲧⲁⲝⲓⲥ/{s}.vibee", .{ self.specs_path, base_name }),
            try std.fmt.allocPrint(self.allocator, "{s}/999/ⲅⲉⲛⲉⲣⲁⲧⲟⲣ/{s}.vibee", .{ self.specs_path, base_name }),
            try std.fmt.allocPrint(self.allocator, "{s}/999/ⲣⲁⲛⲧⲁⲓⲙ/{s}.vibee", .{ self.specs_path, base_name }),
        };
        
        for (possible_paths) |path| {
            defer self.allocator.free(path);
            
            if (std.fs.cwd().access(path, .{})) |_| {
                return true;
            } else |_| {}
        }
        
        return false;
    }
    
    fn getExpectedVibeePath(self: *CIValidator, zig_filename: []const u8) ![]const u8 {
        const base_name = zig_filename[0 .. zig_filename.len - 4];
        return try std.fmt.allocPrint(
            self.allocator,
            "{s}/999/ⲥⲩⲛⲧⲁⲝⲓⲥ/{s}.vibee",
            .{ self.specs_path, base_name }
        );
    }
};

// ═══════════════════════════════════════════════════════════════
// SOURCE MAPPING
// Maps .zig files to their .vibee sources
// ═══════════════════════════════════════════════════════════════

pub const SourceMapping = struct {
    allocator: Allocator,
    mappings: std.StringHashMap([]const u8),
    
    pub fn init(allocator: Allocator) SourceMapping {
        return .{
            .allocator = allocator,
            .mappings = std.StringHashMap([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *SourceMapping) void {
        self.mappings.deinit();
    }
    
    pub fn addMapping(self: *SourceMapping, zig_path: []const u8, vibee_path: []const u8) !void {
        try self.mappings.put(zig_path, vibee_path);
    }
    
    pub fn getVibeeSource(self: *SourceMapping, zig_path: []const u8) ?[]const u8 {
        return self.mappings.get(zig_path);
    }
    
    /// Generate mapping file for CI
    pub fn generateMappingFile(self: *SourceMapping) ![]const u8 {
        var output = std.ArrayList(u8).init(self.allocator);
        const writer = output.writer();
        
        try writer.writeAll("# VIBEE Source Mapping\n");
        try writer.writeAll("# Format: zig_file -> vibee_source\n\n");
        
        var iter = self.mappings.iterator();
        while (iter.next()) |entry| {
            try writer.print("{s} -> {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        
        return try output.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════
// MAIN VALIDATION FUNCTION
// ═══════════════════════════════════════════════════════════════

pub fn runValidation(allocator: Allocator) !ValidationResult {
    var validator = CIValidator.init(allocator);
    defer validator.deinit();
    
    return try validator.validate();
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "ci validator initialization" {
    var validator = CIValidator.init(std.testing.allocator);
    defer validator.deinit();
    
    try std.testing.expect(validator.exceptions.contains("build.zig"));
}

test "source mapping" {
    var mapping = SourceMapping.init(std.testing.allocator);
    defer mapping.deinit();
    
    try mapping.addMapping("parser.zig", "specs/parser.vibee");
    
    const source = mapping.getVibeeSource("parser.zig");
    try std.testing.expect(source != null);
    try std.testing.expectEqualStrings("specs/parser.vibee", source.?);
}

test "validation result format" {
    var result = ValidationResult{
        .passed = true,
        .total_zig_files = 10,
        .zig_with_vibee = 8,
        .zig_without_vibee = 2,
        .violations = std.ArrayList(ValidationResult.Violation).init(std.testing.allocator),
    };
    defer result.violations.deinit();
    
    try std.testing.expectEqual(@as(u32, 10), result.total_zig_files);
}
