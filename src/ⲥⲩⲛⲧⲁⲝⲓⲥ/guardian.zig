// ═══════════════════════════════════════════════════════════════
// GUARDIAN.ZIG - Protection System for VIBEE 999
// Prevents manual editing of generated files
// Enforces: .vibee → .999 → runtime.html architecture
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const fs = std.fs;
const crypto = std.crypto;
const Sha256 = crypto.hash.sha2.Sha256;

// ═══════════════════════════════════════════════════════════════
// FORBIDDEN FILE TYPES
// ═══════════════════════════════════════════════════════════════

pub const ForbiddenExtensions = [_][]const u8{
    ".html",
    ".css",
    ".js",
    ".ts",
    ".jsx",
    ".tsx",
};

pub const AllowedExceptions = [_][]const u8{
    "runtime/runtime.html", // THE ONLY ALLOWED HTML
};

// ═══════════════════════════════════════════════════════════════
// GENERATED FILE HEADER
// ═══════════════════════════════════════════════════════════════

pub const GeneratedHeader = 
    \\// ═══════════════════════════════════════════════════════════════
    \\// Generated from: specs/{s}.vibee
    \\// DO NOT EDIT MANUALLY - Regenerate from specification
    \\// Hash: {s}
    \\// ═══════════════════════════════════════════════════════════════
;

// ═══════════════════════════════════════════════════════════════
// GUARDIAN ERROR TYPES
// ═══════════════════════════════════════════════════════════════

pub const GuardianError = error{
    ForbiddenFileType,
    ManualEditDetected,
    HashMismatch,
    MissingSpecification,
    InvalidHeader,
    RuntimeModificationAttempt,
};

// ═══════════════════════════════════════════════════════════════
// FILE REGISTRY - Tracks generated files and their hashes
// ═══════════════════════════════════════════════════════════════

pub const FileRecord = struct {
    path: []const u8,
    spec_path: []const u8,
    hash: [32]u8,
    generated_at: i64,
};

pub const FileRegistry = struct {
    records: std.ArrayList(FileRecord),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FileRegistry {
        return .{
            .records = std.ArrayList(FileRecord).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FileRegistry) void {
        self.records.deinit();
    }

    pub fn register(self: *FileRegistry, path: []const u8, spec_path: []const u8, content: []const u8) !void {
        var hash: [32]u8 = undefined;
        Sha256.hash(content, &hash, .{});

        try self.records.append(.{
            .path = path,
            .spec_path = spec_path,
            .hash = hash,
            .generated_at = std.time.timestamp(),
        });
    }

    pub fn verify(self: *FileRegistry, path: []const u8, content: []const u8) !bool {
        for (self.records.items) |record| {
            if (std.mem.eql(u8, record.path, path)) {
                var current_hash: [32]u8 = undefined;
                Sha256.hash(content, &current_hash, .{});
                return std.mem.eql(u8, &record.hash, &current_hash);
            }
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════
// GUARDIAN - Main protection system
// ═══════════════════════════════════════════════════════════════

pub const Guardian = struct {
    registry: FileRegistry,
    allocator: std.mem.Allocator,
    strict_mode: bool,

    pub fn init(allocator: std.mem.Allocator) Guardian {
        return .{
            .registry = FileRegistry.init(allocator),
            .allocator = allocator,
            .strict_mode = true,
        };
    }

    pub fn deinit(self: *Guardian) void {
        self.registry.deinit();
    }

    // ═══════════════════════════════════════════════════════════════
    // CHECK FILE CREATION
    // ═══════════════════════════════════════════════════════════════

    pub fn checkFileCreation(_: *Guardian, path: []const u8) GuardianError!void {
        // Check for forbidden extensions
        for (ForbiddenExtensions) |ext| {
            if (std.mem.endsWith(u8, path, ext)) {
                // Check if it's an allowed exception
                for (AllowedExceptions) |exception| {
                    if (std.mem.endsWith(u8, path, exception)) {
                        return; // Allowed
                    }
                }
                
                std.debug.print(
                    \\
                    \\⛔ GUARDIAN ERROR: Forbidden file type
                    \\   Path: {s}
                    \\   Extension: {s}
                    \\
                    \\   VIBEE architecture requires:
                    \\   .vibee (spec) → .999 (code) → runtime.html (interpreter)
                    \\
                    \\   Create a .vibee specification instead!
                    \\
                , .{ path, ext });
                
                return GuardianError.ForbiddenFileType;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VERIFY GENERATED FILE
    // ═══════════════════════════════════════════════════════════════

    pub fn verifyGeneratedFile(self: *Guardian, path: []const u8, content: []const u8) GuardianError!void {
        // Check if file has proper header
        if (!std.mem.startsWith(u8, content, "// ═══")) {
            std.debug.print(
                \\
                \\⛔ GUARDIAN ERROR: Invalid header in generated file
                \\   Path: {s}
                \\
                \\   Generated .999 files must have proper header.
                \\   Regenerate from specification.
                \\
            , .{path});
            return GuardianError.InvalidHeader;
        }

        // Check if "DO NOT EDIT MANUALLY" is present
        if (std.mem.indexOf(u8, content, "DO NOT EDIT MANUALLY") == null) {
            std.debug.print(
                \\
                \\⛔ GUARDIAN ERROR: Missing protection marker
                \\   Path: {s}
                \\
                \\   File appears to be manually created.
                \\   Use vibeec to generate from .vibee spec.
                \\
            , .{path});
            return GuardianError.ManualEditDetected;
        }

        // Verify hash if in registry
        if (!try self.registry.verify(path, content)) {
            if (self.strict_mode) {
                std.debug.print(
                    \\
                    \\⛔ GUARDIAN ERROR: Hash mismatch detected
                    \\   Path: {s}
                    \\
                    \\   File has been modified since generation.
                    \\   Regenerate from specification or update spec.
                    \\
                , .{path});
                return GuardianError.HashMismatch;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PROTECT RUNTIME
    // ═══════════════════════════════════════════════════════════════

    pub fn protectRuntime(_: *Guardian, path: []const u8) GuardianError!void {
        if (std.mem.endsWith(u8, path, "runtime/runtime.html")) {
            std.debug.print(
                \\
                \\⛔ GUARDIAN ERROR: Runtime modification attempt
                \\   Path: {s}
                \\
                \\   runtime.html is FINAL and must not be modified.
                \\   All logic should be in .999 files.
                \\
                \\   Architecture:
                \\   .vibee → .999 → runtime.html (LOCKED)
                \\
            , .{path});
            return GuardianError.RuntimeModificationAttempt;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // GENERATE WITH PROTECTION
    // ═══════════════════════════════════════════════════════════════

    pub fn generateProtected(
        self: *Guardian,
        spec_path: []const u8,
        output_path: []const u8,
        content: []const u8,
    ) ![]const u8 {
        // Calculate hash
        var hash: [32]u8 = undefined;
        Sha256.hash(content, &hash, .{});

        // Format hash as hex
        var hash_hex: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hash_hex, "{x}", .{std.fmt.fmtSliceHexLower(&hash)}) catch unreachable;

        // Extract spec name
        const spec_name = std.fs.path.stem(spec_path);

        // Create protected content with header
        const header = try std.fmt.allocPrint(self.allocator, GeneratedHeader, .{ spec_name, hash_hex[0..16] });
        defer self.allocator.free(header);

        const protected_content = try std.fmt.allocPrint(
            self.allocator,
            "{s}\n\n{s}",
            .{ header, content },
        );

        // Register in registry
        try self.registry.register(output_path, spec_path, protected_content);

        return protected_content;
    }

    // ═══════════════════════════════════════════════════════════════
    // SCAN PROJECT
    // ═══════════════════════════════════════════════════════════════

    pub fn scanProject(self: *Guardian, root_path: []const u8) !void {
        var dir = try fs.cwd().openDir(root_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        var violations: u32 = 0;

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;

            // Check for forbidden files
            self.checkFileCreation(entry.path) catch {
                violations += 1;
            };
        }

        if (violations > 0) {
            std.debug.print(
                \\
                \\═══════════════════════════════════════════════════════════════
                \\GUARDIAN SCAN COMPLETE
                \\Violations found: {d}
                \\
                \\Fix violations by:
                \\1. Delete forbidden files
                \\2. Create .vibee specifications
                \\3. Generate .999 code with vibeec
                \\═══════════════════════════════════════════════════════════════
                \\
            , .{violations});
        } else {
            std.debug.print(
                \\
                \\✅ GUARDIAN SCAN COMPLETE - No violations
                \\
            , .{});
        }
    }
};

// ═══════════════════════════════════════════════════════════════
// CLI INTERFACE
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    var guardian = Guardian.init(allocator);
    defer guardian.deinit();

    const command = args[1];

    if (std.mem.eql(u8, command, "scan")) {
        const path = if (args.len > 2) args[2] else ".";
        try guardian.scanProject(path);
    } else if (std.mem.eql(u8, command, "check")) {
        if (args.len < 3) {
            std.debug.print("Usage: guardian check <file>\n", .{});
            return;
        }
        guardian.checkFileCreation(args[2]) catch |err| {
            std.debug.print("Check failed: {}\n", .{err});
        };
    } else if (std.mem.eql(u8, command, "verify")) {
        if (args.len < 3) {
            std.debug.print("Usage: guardian verify <file>\n", .{});
            return;
        }
        const file = try fs.cwd().openFile(args[2], .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);
        guardian.verifyGeneratedFile(args[2], content) catch |err| {
            std.debug.print("Verification failed: {}\n", .{err});
        };
    } else {
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\VIBEE 999 GUARDIAN - File Protection System
        \\
        \\Usage:
        \\  guardian scan [path]     - Scan project for violations
        \\  guardian check <file>    - Check if file type is allowed
        \\  guardian verify <file>   - Verify generated file integrity
        \\
        \\Protected Architecture:
        \\  .vibee (spec) → .999 (code) → runtime.html (final)
        \\
        \\Forbidden file types: .html .css .js .ts .jsx .tsx
        \\Exception: runtime/runtime.html (THE ONLY ALLOWED HTML)
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "forbidden file detection" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var guardian = Guardian.init(gpa.allocator());
    defer guardian.deinit();

    // Should fail for .html
    try std.testing.expectError(
        GuardianError.ForbiddenFileType,
        guardian.checkFileCreation("test.html"),
    );

    // Should fail for .js
    try std.testing.expectError(
        GuardianError.ForbiddenFileType,
        guardian.checkFileCreation("app.js"),
    );

    // Should pass for .999
    try guardian.checkFileCreation("module.999");

    // Should pass for .vibee
    try guardian.checkFileCreation("spec.vibee");

    // Should pass for runtime exception
    try guardian.checkFileCreation("runtime/runtime.html");
}

test "hash verification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var guardian = Guardian.init(gpa.allocator());
    defer guardian.deinit();

    const content = "test content";
    try guardian.registry.register("test.999", "test.vibee", content);

    // Same content should verify
    try std.testing.expect(try guardian.registry.verify("test.999", content));

    // Modified content should fail
    try std.testing.expect(!try guardian.registry.verify("test.999", "modified content"));
}
