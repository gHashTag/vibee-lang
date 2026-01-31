// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODEGEN - Генератор Zig кода из .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Zig код для компиляции в WASM
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const vibee_parser = @import("vibee_parser.zig");

const VibeeSpec = vibee_parser.VibeeSpec;
const Constant = vibee_parser.Constant;
const TypeDef = vibee_parser.TypeDef;
const CreationPattern = vibee_parser.CreationPattern;
const Behavior = vibee_parser.Behavior;
const TestCase = vibee_parser.TestCase;

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: std.ArrayListUnmanaged(u8),
    indent: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = .{},
            .indent = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(self.allocator, str);
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice(self.allocator, "    ");
        }
    }

    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer(self.allocator);
        try writer.print(fmt, args);
    }

    pub fn newline(self: *Self) !void {
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn incIndent(self: *Self) void {
        self.indent += 1;
    }

    pub fn decIndent(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZigCodeGen = struct {
    allocator: Allocator,
    builder: CodeBuilder,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = CodeBuilder.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }

    /// Генерация полного Zig файла из спецификации
    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeImports();
        try self.writeConstants(spec.constants.items);
        try self.writeTypes(spec.types.items);
        try self.writeMemoryBuffers();
        try self.writeCreationPatterns(spec.creation_patterns.items);
        try self.writeBehaviorFunctions(spec.behaviors.items);
        try self.writeTests(spec.behaviors.items);

        return self.builder.getOutput();
    }

    /// Generate functions from behaviors with implementation blocks
    fn writeBehaviorFunctions(self: *Self, behaviors: []const Behavior) !void {
        var has_impl = false;
        for (behaviors) |b| {
            if (b.implementation.len > 0 or b.when.len > 0) {
                has_impl = true;
                break;
            }
        }
        if (!has_impl) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR IMPLEMENTATIONS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (behaviors) |b| {
            if (b.implementation.len == 0 and b.when.len == 0) continue;

            try self.builder.writeFmt("/// {s}\n", .{b.given});
            try self.builder.writeFmt("/// When: {s}\n", .{b.when});
            try self.builder.writeFmt("/// Then: {s}\n", .{b.then});
            
            // Generate implementation from when/then or explicit implementation
            try self.generateBehaviorImplementation(b);

            try self.builder.newline();
        }
    }

    /// Generate behavior implementation from when/then or explicit implementation
    fn generateBehaviorImplementation(self: *Self, b: Behavior) !void {
        // Try to generate from DSL patterns first
        if (b.when.len > 0) {
            if (try self.generateFromDsLPattern(b)) {
                return; // Successfully generated from DSL pattern
            }
        }

        // Try to generate from when/then patterns
        if (b.when.len > 0) {
            if (try self.generateFromWhenThenPattern(b)) {
                return; // Successfully generated from pattern
            }
        }

        // Fallback to explicit implementation or stub
        try self.builder.writeFmt("pub fn {s}() !void {{\n", .{b.name});
        self.builder.incIndent();

        const impl = std.mem.trim(u8, b.implementation, " \t\n\r");
        if (impl.len > 0) {
            try self.builder.write(impl);
            try self.builder.newline();
        } else {
            try self.builder.writeLine("// TODO: implementation");
        }

        self.builder.decIndent();
        try self.builder.writeLine("}");
    }

    /// Generate implementation from DSL patterns ($fs.path.normalize)
    fn generateFromDsLPattern(self: *Self, b: Behavior) !bool {
        const when_text = b.when;
        _ = b.then; // Not used in DSL pattern

        // Check for DSL syntax: $fs.path.normalize(...)
        if (std.mem.indexOf(u8, when_text, "$fs.") == null) {
            return false;
        }

        // Extract DSL command
        var cmd_start = std.mem.indexOf(u8, when_text, "$fs.") orelse return false;
        cmd_start += 4; // Skip "$fs."
        
        // Find end of command (up to newline or space)
        var cmd_end = cmd_start;
        while (cmd_end < when_text.len and when_text[cmd_end] != '\n' and when_text[cmd_end] != ' ') {
            cmd_end += 1;
        }
        
        const cmd = when_text[cmd_start..cmd_end];
        
        // Parse arguments from command: normalize(path) -> path
        const paren_start = std.mem.indexOf(u8, cmd, "(") orelse return false;
        const paren_end = std.mem.lastIndexOf(u8, cmd, ")") orelse return false;
        _ = paren_start; // Not used in current implementation
        _ = paren_end; // Not used in current implementation

        // Generate implementation based on command
        if (std.mem.startsWith(u8, cmd, "path.normalize")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("return std.fs.path.resolve(allocator, &.{path}) catch |err| return err;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "path.resolve")) {
            try self.builder.writeFmt("pub fn {s}(base: []const u8, path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("return std.fs.path.resolve(allocator, &.{base, path}) catch |err| return err;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "path.exists")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !bool {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("std.fs.cwd().access(path, .{}) catch |err| return if (err == error.FileNotFound) false else return err;");
            try self.builder.writeLine("return true;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "dir.list")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![][]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var entries = std.ArrayList([]const u8).init(allocator);");
            try self.builder.writeLine("defer entries.deinit();");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("try entries.append(try allocator.dupe(u8, entry.name));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return entries.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "dir.create")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().makePath(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "dir.remove")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().deleteTree(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.read")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("return file.readToEndAlloc(allocator, 1024 * 1024);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.write")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, content: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.writeAll(content);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.append")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, content: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.seekFromEnd(0);");
            try self.builder.writeLine("try file.writeAll(content);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.delete")) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().deleteFile(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.copy")) {
            try self.builder.writeFmt("pub fn {s}(src: []const u8, dst: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{});");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std.mem.startsWith(u8, cmd, "file.move")) {
            try self.builder.writeFmt("pub fn {s}(src: []const u8, dst: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().rename(src, dst);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        return false;
    }

    /// Generate implementation from std.fs.* patterns in when/then
    fn generateFromWhenThenPattern(self: *Self, b: Behavior) !bool {
        const when_text = b.when;
        const then_text = b.then;

        // Pattern: normalize_path -> std.fs.path.normalize()
        if (std.mem.indexOf(u8, when_text, "normalize") != null and
            std.mem.indexOf(u8, then_text, "NormalizedPath") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("return std.fs.path.resolve(allocator, &.{path}) catch |err| return err;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: resolve_path -> std.fs.path.resolve()
        if (std.mem.indexOf(u8, when_text, "resolve") != null and
            std.mem.indexOf(u8, then_text, "ResolvedPath") != null) {
            try self.builder.writeFmt("pub fn {s}(base: []const u8, path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("return std.fs.path.resolve(allocator, &.{base, path}) catch |err| return err;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: path_exists -> std.fs.access()
        if (std.mem.indexOf(u8, when_text, "exists") != null and
            std.mem.indexOf(u8, then_text, "Bool") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !bool {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("std.fs.cwd().access(path, .{}) catch |err| return if (err == error.FileNotFound) false else return err;");
            try self.builder.writeLine("return true;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: list_directory -> fs.Dir.iterate()
        if (std.mem.indexOf(u8, when_text, "list") != null and
            std.mem.indexOf(u8, then_text, "EntryList") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![][]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var entries = std.ArrayList([]const u8).init(allocator);");
            try self.builder.writeLine("defer entries.deinit();");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("try entries.append(try allocator.dupe(u8, entry.name));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return entries.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: create_directory -> fs.Dir.makePath()
        if (std.mem.indexOf(u8, when_text, "create") != null and
            std.mem.indexOf(u8, when_text, "directory") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().makePath(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: remove_directory -> fs.Dir.deleteTree()
        if (std.mem.indexOf(u8, when_text, "remove") != null and
            std.mem.indexOf(u8, when_text, "directory") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().deleteTree(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: read_file -> fs.File.readToEndAlloc()
        if (std.mem.indexOf(u8, when_text, "read") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("return file.readToEndAlloc(allocator, 1024 * 1024);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: write_file -> fs.File.writeAll()
        if (std.mem.indexOf(u8, when_text, "write") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, content: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.writeAll(content);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: append_file -> fs.File.writeAll() with append mode
        if (std.mem.indexOf(u8, when_text, "append") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, content: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.seekFromEnd(0);");
            try self.builder.writeLine("try file.writeAll(content);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: delete_file -> fs.File.delete()
        if (std.mem.indexOf(u8, when_text, "delete") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().deleteFile(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: copy_file -> fs.File.copy()
        if (std.mem.indexOf(u8, when_text, "copy") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(src: []const u8, dst: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{});");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: move_file -> fs.File.rename()
        if (std.mem.indexOf(u8, when_text, "move") != null and
            std.mem.indexOf(u8, when_text, "file") != null) {
            try self.builder.writeFmt("pub fn {s}(src: []const u8, dst: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("try std.fs.cwd().rename(src, dst);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: get_permissions -> os.stat()
        if (std.mem.indexOf(u8, when_text, "permissions") != null and
            std.mem.indexOf(u8, then_text, "Permissions") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !std.fs.File.Permissions {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const stat = try std.fs.cwd().statFile(path);");
            try self.builder.writeLine("return stat.kind.file().permissions;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: set_permissions -> os.chmod()
        if (std.mem.indexOf(u8, when_text, "set") != null and
            std.mem.indexOf(u8, when_text, "permissions") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, perms: std.fs.File.Permissions) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.setPermissions(perms);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: get_file_stats -> os.stat()
        if (std.mem.indexOf(u8, when_text, "stats") != null and
            std.mem.indexOf(u8, then_text, "FileStats") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !std.fs.File.Stat {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("return std.fs.cwd().statFile(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: calculate_directory_size -> iterate and sum
        if (std.mem.indexOf(u8, when_text, "size") != null and
            std.mem.indexOf(u8, when_text, "directory") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !u64 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var total_size: u64 = 0;");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (entry.kind == .file) {");
            self.builder.incIndent();
            try self.builder.writeLine("const stat = try dir.statFile(entry.name);");
            try self.builder.writeLine("total_size += stat.size;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return total_size;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: initialize_repository -> create .vbt directory
        if (std.mem.indexOf(u8, when_text, "initialize") != null and
            std.mem.indexOf(u8, when_text, "repository") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const vbt_path = try std.fs.path.join(self.allocator, &.{path, \".vbt\"});");
            try self.builder.writeLine("defer self.allocator.free(vbt_path);");
            try self.builder.writeLine("try std.fs.cwd().makePath(vbt_path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: load_vbt_repository -> read .vbt/config
        if (std.mem.indexOf(u8, when_text, "load") != null and
            std.mem.indexOf(u8, when_text, "repository") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const config_path = try std.fs.path.join(allocator, &.{path, \".vbt\", \"config\"});");
            try self.builder.writeLine("defer allocator.free(config_path);");
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(config_path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("return file.readToEndAlloc(allocator, 1024 * 1024);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: save_vbt_repository -> write .vbt/config
        if (std.mem.indexOf(u8, when_text, "save") != null and
            std.mem.indexOf(u8, when_text, "repository") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, config: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const config_path = try std.fs.path.join(self.allocator, &.{path, \".vbt\", \"config\"});");
            try self.builder.writeLine("defer self.allocator.free(config_path);");
            try self.builder.writeLine("const file = try std.fs.cwd().createFile(config_path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("try file.writeAll(config);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: sync_workspace -> sync with remote
        if (std.mem.indexOf(u8, when_text, "sync") != null and
            std.mem.indexOf(u8, then_text, "SyncResult") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, force: bool) !SyncResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("_ = path;");
            try self.builder.writeLine("_ = force;");
            try self.builder.writeLine("return SyncResult{ .success = true, .synced_objects = 0, .conflicts = 0 };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: commit_changes -> create commit
        if (std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "CommitResult") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, message: []const u8) !CommitResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("_ = path;");
            try self.builder.writeLine("_ = message;");
            try self.builder.writeLine("return CommitResult{ .success = true, .commit_id = \"test-commit\", .timestamp = std.time.timestamp() };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: add_object -> store object
        if (std.mem.indexOf(u8, when_text, "add") != null and
            std.mem.indexOf(u8, then_text, "ObjectAdded") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, data: []const u8) !ObjectAdded {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("_ = path;");
            try self.builder.writeLine("_ = data;");
            try self.builder.writeLine("return ObjectAdded{ .object_id = \"test-object\", .trits = 0 };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: get_object -> retrieve object
        if (std.mem.indexOf(u8, when_text, "get") != null and
            std.mem.indexOf(u8, then_text, "ObjectData") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, object_id: []const u8) !ObjectData {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("_ = path;");
            try self.builder.writeLine("_ = object_id;");
            try self.builder.writeLine("return ObjectData{ .data = \"test-data\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: encode_trit -> encode trit to 2 bits
        if (std.mem.indexOf(u8, when_text, "encode") != null and
            std.mem.indexOf(u8, when_text, "trit") != null and
            std.mem.indexOf(u8, then_text, "encoded") != null) {
            try self.builder.writeFmt("pub fn {s}(trit_value: i64) !i64 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Encode trit (-1, 0, +1) to 2 bits: 00=+1, 01=0, 10=-1");
            try self.builder.writeLine("return if (trit_value == 1) 0 else if (trit_value == 0) 1 else 2;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: decode_trit -> decode 2 bits to trit
        if (std.mem.indexOf(u8, when_text, "decode") != null and
            std.mem.indexOf(u8, when_text, "trit") != null and
            std.mem.indexOf(u8, then_text, "Trit") != null) {
            try self.builder.writeFmt("pub fn {s}(encoded: i64) !i64 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Decode 2 bits to trit: 00=+1, 01=0, 10=-1");
            try self.builder.writeLine("return if (encoded == 0) 1 else if (encoded == 1) 0 else -1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: encode_trit_sequence -> encode trit sequence to bytes
        if (std.mem.indexOf(u8, when_text, "encode") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(trits: []const i64, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var encoded = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer encoded.deinit();");
            try self.builder.writeLine("var byte: i64 = 0;");
            try self.builder.writeLine("var bit_count: u32 = 0;");
            try self.builder.writeLine("for (trits) |trit| {");
            self.builder.incIndent();
            try self.builder.writeLine("const enc = if (trit == 1) 0 else if (trit == 0) 1 else 2;");
            try self.builder.writeLine("byte |= @as(i64, enc) << bit_count;");
            try self.builder.writeLine("bit_count += 2;");
            try self.builder.writeLine("if (bit_count >= 8) {");
            self.builder.incIndent();
            try self.builder.writeLine("try encoded.append(byte & 0xFF);");
            try self.builder.writeLine("byte >>= 8;");
            try self.builder.writeLine("bit_count -= 8;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("if (bit_count > 0) try encoded.append(byte);");
            try self.builder.writeLine("return TritSequence{ .trits = trits, .encoded_bytes = try encoded.toOwnedSlice() };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: decode_trit_sequence -> decode bytes to trit sequence
        if (std.mem.indexOf(u8, when_text, "decode") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(encoded_bytes: []const i64, trit_count: usize, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var trits = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer trits.deinit();");
            try self.builder.writeLine("var bit_pos: u32 = 0;");
            try self.builder.writeLine("var trit_idx: usize = 0;");
            try self.builder.writeLine("for (encoded_bytes) |byte| {");
            self.builder.incIndent();
            try self.builder.writeLine("var byte_bits: u32 = 8;");
            try self.builder.writeLine("while (byte_bits >= 2 and trit_idx < trit_count) {");
            self.builder.incIndent();
            try self.builder.writeLine("const enc = (byte >> bit_pos) & 0x3;");
            try self.builder.writeLine("const trit = if (enc == 0) 1 else if (enc == 1) 0 else -1;");
            try self.builder.writeLine("try trits.append(trit);");
            try self.builder.writeLine("bit_pos += 2;");
            try self.builder.writeLine("byte_bits -= 2;");
            try self.builder.writeLine("trit_idx += 1;");
            try self.builder.writeLine("if (bit_pos >= 8) { bit_pos = 0; break; }");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try trits.toOwnedSlice(), .encoded_bytes = encoded_bytes };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: parse_vbt_header -> parse VBT header
        if (std.mem.indexOf(u8, when_text, "parse") != null and
            std.mem.indexOf(u8, when_text, "header") != null and
            std.mem.indexOf(u8, then_text, "VBTHeader") != null) {
            try self.builder.writeFmt("pub fn {s}(data: []const u8) !VBTHeader {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Parse VBT header from first 32 bytes");
            try self.builder.writeLine("if (data.len < 32) return error.InvalidHeader;");
            try self.builder.writeLine("const magic = data[0..4];");
            try self.builder.writeLine("const version = data[4];");
            try self.builder.writeLine("const flags = @as(u32, @intFromBytes(u32, data[8..12], .little));");
            try self.builder.writeLine("const object_count = @as(u32, @intFromBytes(u32, data[12..16], .little));");
            try self.builder.writeLine("const commit_count = @as(u32, @intFromBytes(u32, data[16..20], .little));");
            try self.builder.writeLine("return VBTHeader{");
            try self.builder.writeLine("    .magic = magic,");
            try self.builder.writeLine("    .version = version,");
            try self.builder.writeLine("    .flags = flags,");
            try self.builder.writeLine("    .object_count = object_count,");
            try self.builder.writeLine("    .commit_count = commit_count,");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: write_vbt_header -> write VBT header
        if (std.mem.indexOf(u8, when_text, "write") != null and
            std.mem.indexOf(u8, when_text, "header") != null and
            std.mem.indexOf(u8, then_text, "bytes") != null) {
            try self.builder.writeFmt("pub fn {s}(header: VBTHeader, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var result = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer result.deinit();");
            try self.builder.writeLine("try result.appendSlice(header.magic);");
            try self.builder.writeLine("try result.append(header.version);");
            try self.builder.writeLine("const flags_bytes = @as([4]u8, @bitCast(@as(u32, header.flags)));");
            try self.builder.writeLine("try result.appendSlice(&flags_bytes);");
            try self.builder.writeLine("const obj_count_bytes = @as([4]u8, @bitCast(@as(u32, header.object_count)));");
            try self.builder.writeLine("try result.appendSlice(&obj_count_bytes);");
            try self.builder.writeLine("const commit_count_bytes = @as([4]u8, @bitCast(@as(u32, header.commit_count)));");
            try self.builder.writeLine("try result.appendSlice(&commit_count_bytes);");
            try self.builder.writeLine("// Pad to 32 bytes");
            try self.builder.writeLine("while (result.items.len < 32) try result.append(0);");
            try self.builder.writeLine("return try result.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: calculate_object_hash -> calculate SHA-256 hash
        if (std.mem.indexOf(u8, when_text, "calculate") != null and
            std.mem.indexOf(u8, when_text, "object") != null and
            std.mem.indexOf(u8, when_text, "hash") != null) {
            try self.builder.writeFmt("pub fn {s}(object: VBTObject, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var hasher = std.crypto.hash.sha2.Sha256.init(.{});");
            try self.builder.writeLine("hasher.update(object.hash);");
            try self.builder.writeLine("hasher.update(object.type);");
            try self.builder.writeLine("const size_bytes = @as([8]u8, @bitCast(@as(u64, object.size)));");
            try self.builder.writeLine("hasher.update(&size_bytes);");
            try self.builder.writeLine("for (object.trits.encoded_bytes) |byte| hasher.update(&[_]u8{@as(u8, byte)});");
            try self.builder.writeLine("var hash_result: [32]u8 = undefined;");
            try self.builder.writeLine("hasher.final(&hash_result);");
            try self.builder.writeLine("var hex = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer hex.deinit();");
            try self.builder.writeLine("for (hash_result) |byte| {");
            self.builder.incIndent();
            try self.builder.writeLine("const hi = byte >> 4;");
            try self.builder.writeLine("const lo = byte & 0xF;");
            try self.builder.writeLine("try hex.append(if (hi < 10) '0' + hi else 'a' + hi - 10);");
            try self.builder.writeLine("try hex.append(if (lo < 10) '0' + lo else 'a' + lo - 10);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return try hex.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: validate_vbt_file -> validate VBT file
        if (std.mem.indexOf(u8, when_text, "validate") != null and
            std.mem.indexOf(u8, when_text, "file") != null and
            std.mem.indexOf(u8, then_text, "Bool") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !bool {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("const stat = try file.stat();");
            try self.builder.writeLine("if (stat.size < 32) return false;");
            try self.builder.writeLine("var header_buf: [32]u8 = undefined;");
            try self.builder.writeLine("_ = try file.readAll(&header_buf);");
            try self.builder.writeLine("const header = try parse_vbt_header(&header_buf);");
            try self.builder.writeLine("// Check magic number");
            try self.builder.writeLine("if (!std.mem.eql(u8, header.magic, \"VBT1\")) return false;");
            try self.builder.writeLine("// Check version");
            try self.builder.writeLine("if (header.version != 1) return false;");
            try self.builder.writeLine("return true;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: get_vbt_metadata -> get VBT metadata
        if (std.mem.indexOf(u8, when_text, "metadata") != null and
            std.mem.indexOf(u8, then_text, "VBTMetadata") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) !VBTMetadata {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("const stat = try file.stat();");
            try self.builder.writeLine("var header_buf: [32]u8 = undefined;");
            try self.builder.writeLine("_ = try file.readAll(&header_buf);");
            try self.builder.writeLine("const header = try parse_vbt_header(&header_buf);");
            try self.builder.writeLine("return VBTMetadata{");
            try self.builder.writeLine("    .file_size = stat.size,");
            try self.builder.writeLine("    .object_count = header.object_count,");
            try self.builder.writeLine("    .commit_count = header.commit_count,");
            try self.builder.writeLine("    .total_trits = 0,");
            try self.builder.writeLine("    .compression_ratio = 1.0,");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: compress_trit_sequence -> compress with RLE
        if (std.mem.indexOf(u8, when_text, "compress") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(seq: TritSequence, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var compressed = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer compressed.deinit();");
            try self.builder.writeLine("if (seq.trits.len == 0) return TritSequence{ .trits = &.{}, .encoded_bytes = &.{} };");
            try self.builder.writeLine("var current = seq.trits[0];");
            try self.builder.writeLine("var count: u32 = 1;");
            try self.builder.writeLine("for (seq.trits[1..]) |trit| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (trit == current and count < 255) {");
            self.builder.incIndent();
            try self.builder.writeLine("count += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("} else {");
            self.builder.incIndent();
            try self.builder.writeLine("try compressed.append(current);");
            try self.builder.writeLine("try compressed.append(count);");
            try self.builder.writeLine("current = trit;");
            try self.builder.writeLine("count = 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("try compressed.append(current);");
            try self.builder.writeLine("try compressed.append(count);");
            try self.builder.writeLine("return TritSequence{ .trits = try compressed.toOwnedSlice(), .encoded_bytes = seq.encoded_bytes };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: decompress_trit_sequence -> decompress from RLE
        if (std.mem.indexOf(u8, when_text, "decompress") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(seq: TritSequence, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var decompressed = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer decompressed.deinit();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < seq.trits.len) {");
            self.builder.incIndent();
            try self.builder.writeLine("const trit = seq.trits[i];");
            try self.builder.writeLine("const count = @as(u32, @intCast(seq.trits[i + 1]));");
            try self.builder.writeLine("var j: u32 = 0;");
            try self.builder.writeLine("while (j < count) : (j += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("try decompressed.append(trit);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("i += 2;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try decompressed.toOwnedSlice(), .encoded_bytes = seq.encoded_bytes };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: parse_vbt_object -> parse VBT object
        if (std.mem.indexOf(u8, when_text, "parse") != null and
            std.mem.indexOf(u8, when_text, "object") != null and
            std.mem.indexOf(u8, then_text, "VBTObject") != null) {
            try self.builder.writeFmt("pub fn {s}(data: []const u8, offset: usize, allocator: Allocator) !VBTObject {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Parse VBT object at given offset");
            try self.builder.writeLine("var pos = offset;");
            try self.builder.writeLine("// Parse hash (64 hex chars = 32 bytes)");
            try self.builder.writeLine("const hash = data[pos..pos+64];");
            try self.builder.writeLine("pos += 64;");
            try self.builder.writeLine("// Parse type (string until null)");
            try self.builder.writeLine("var type_end = pos;");
            try self.builder.writeLine("while (type_end < data.len and data[type_end] != 0) : (type_end += 1) {}");
            try self.builder.writeLine("const type = data[pos..type_end];");
            try self.builder.writeLine("pos = type_end + 1;");
            try self.builder.writeLine("// Parse size (8 bytes)");
            try self.builder.writeLine("const size = @as(u64, @intFromBytes(u64, data[pos..pos+8], .little));");
            try self.builder.writeLine("pos += 8;");
            try self.builder.writeLine("// Parse trits (remaining bytes)");
            try self.builder.writeLine("const trit_count = @as(usize, size);");
            try self.builder.writeLine("var trits = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer trits.deinit();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < trit_count and pos < data.len) {");
            self.builder.incIndent();
            try self.builder.writeLine("const byte = data[pos];");
            try self.builder.writeLine("const high = @as(i64, (byte >> 4) & 0x3);");
            try self.builder.writeLine("const low = @as(i64, byte & 0x3);");
            try self.builder.writeLine("const trit_high = if (high == 0) 1 else if (high == 1) 0 else -1;");
            try self.builder.writeLine("const trit_low = if (low == 0) 1 else if (low == 1) 0 else -1;");
            try self.builder.writeLine("try trits.append(trit_high);");
            try self.builder.writeLine("try trits.append(trit_low);");
            try self.builder.writeLine("pos += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Parse encoded bytes");
            try self.builder.writeLine("var encoded = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer encoded.deinit();");
            try self.builder.writeLine("while (pos < data.len) {");
            self.builder.incIndent();
            try self.builder.writeLine("try encoded.append(@as(i64, data[pos]));");
            try self.builder.writeLine("pos += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return VBTObject{");
            try self.builder.writeLine("    .hash = hash,");
            try self.builder.writeLine("    .type = type,");
            try self.builder.writeLine("    .size = @as(i64, size),");
            try self.builder.writeLine("    .trits = TritSequence{ .trits = try trits.toOwnedSlice(), .encoded_bytes = try encoded.toOwnedSlice() },");
            try self.builder.writeLine("    .compressed = false,");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: write_vbt_object -> write VBT object
        if (std.mem.indexOf(u8, when_text, "write") != null and
            std.mem.indexOf(u8, when_text, "object") != null and
            std.mem.indexOf(u8, then_text, "bytes") != null) {
            try self.builder.writeFmt("pub fn {s}(object: VBTObject, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var result = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer result.deinit();");
            try self.builder.writeLine("// Write hash (64 bytes)");
            try self.builder.writeLine("try result.appendSlice(object.hash);");
            try self.builder.writeLine("// Write type (null-terminated)");
            try self.builder.writeLine("try result.appendSlice(object.type);");
            try self.builder.writeLine("try result.append(0);");
            try self.builder.writeLine("// Write size (8 bytes)");
            try self.builder.writeLine("const size_bytes = @as([8]u8, @bitCast(@as(u64, object.size)));");
            try self.builder.writeLine("try result.appendSlice(&size_bytes);");
            try self.builder.writeLine("// Write trits (2 bytes per trit)");
            try self.builder.writeLine("for (object.trits.trits) |trit| {");
            self.builder.incIndent();
            try self.builder.writeLine("const enc = if (trit == 1) 0 else if (trit == 0) 1 else 2;");
            try self.builder.writeLine("try result.append(@as(u8, enc));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Write encoded bytes");
            try self.builder.writeLine("for (object.trits.encoded_bytes) |byte| {");
            self.builder.incIndent();
            try self.builder.writeLine("try result.append(@as(u8, byte));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return try result.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: parse_vbt_commit -> parse VBT commit
        if (std.mem.indexOf(u8, when_text, "parse") != null and
            std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "VBTCommit") != null) {
            try self.builder.writeFmt("pub fn {s}(data: []const u8, offset: usize, allocator: Allocator) !VBTCommit {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Parse VBT commit at given offset");
            try self.builder.writeLine("var pos = offset;");
            try self.builder.writeLine("// Parse hash (64 hex chars = 32 bytes)");
            try self.builder.writeLine("const hash = data[pos..pos+64];");
            try self.builder.writeLine("pos += 64;");
            try self.builder.writeLine("// Parse parent hash (64 hex chars = 32 bytes)");
            try self.builder.writeLine("const parent_hash = data[pos..pos+64];");
            try self.builder.writeLine("pos += 64;");
            try self.builder.writeLine("// Parse timestamp (8 bytes)");
            try self.builder.writeLine("const timestamp = @as(i64, @intFromBytes(i64, data[pos..pos+8], .little));");
            try self.builder.writeLine("pos += 8;");
            try self.builder.writeLine("// Parse message (string until null)");
            try self.builder.writeLine("var msg_end = pos;");
            try self.builder.writeLine("while (msg_end < data.len and data[msg_end] != 0) : (msg_end += 1) {}");
            try self.builder.writeLine("const message = data[pos..msg_end];");
            try self.builder.writeLine("pos = msg_end + 1;");
            try self.builder.writeLine("// Parse author (string until null)");
            try self.builder.writeLine("var author_end = pos;");
            try self.builder.writeLine("while (author_end < data.len and data[author_end] != 0) : (author_end += 1) {}");
            try self.builder.writeLine("const author = data[pos..author_end];");
            try self.builder.writeLine("pos = author_end + 1;");
            try self.builder.writeLine("// Parse object count (4 bytes)");
            try self.builder.writeLine("const obj_count = @as(u32, @intFromBytes(u32, data[pos..pos+4], .little));");
            try self.builder.writeLine("pos += 4;");
            try self.builder.writeLine("// Parse object hashes (64 bytes each)");
            try self.builder.writeLine("var object_hashes = std.ArrayList([]const u8).init(allocator);");
            try self.builder.writeLine("defer object_hashes.deinit();");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < obj_count) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("const obj_hash = data[pos..pos+64];");
            try self.builder.writeLine("try object_hashes.append(obj_hash);");
            try self.builder.writeLine("pos += 64;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return VBTCommit{");
            try self.builder.writeLine("    .hash = hash,");
            try self.builder.writeLine("    .parent_hash = parent_hash,");
            try self.builder.writeLine("    .timestamp = timestamp,");
            try self.builder.writeLine("    .message = message,");
            try self.builder.writeLine("    .author = author,");
            try self.builder.writeLine("    .object_hashes = try object_hashes.toOwnedSlice(),");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: write_vbt_commit -> write VBT commit
        if (std.mem.indexOf(u8, when_text, "write") != null and
            std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "bytes") != null) {
            try self.builder.writeFmt("pub fn {s}(commit: VBTCommit, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var result = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer result.deinit();");
            try self.builder.writeLine("// Write hash (64 bytes)");
            try self.builder.writeLine("try result.appendSlice(commit.hash);");
            try self.builder.writeLine("// Write parent hash (64 bytes)");
            try self.builder.writeLine("try result.appendSlice(commit.parent_hash);");
            try self.builder.writeLine("// Write timestamp (8 bytes)");
            try self.builder.writeLine("const ts_bytes = @as([8]u8, @bitCast(@as(i64, commit.timestamp)));");
            try self.builder.writeLine("try result.appendSlice(&ts_bytes);");
            try self.builder.writeLine("// Write message (null-terminated)");
            try self.builder.writeLine("try result.appendSlice(commit.message);");
            try self.builder.writeLine("try result.append(0);");
            try self.builder.writeLine("// Write author (null-terminated)");
            try self.builder.writeLine("try result.appendSlice(commit.author);");
            try self.builder.writeLine("try result.append(0);");
            try self.builder.writeLine("// Write object count (4 bytes)");
            try self.builder.writeLine("const count_bytes = @as([4]u8, @bitCast(commit.object_hashes.len));");
            try self.builder.writeLine("try result.appendSlice(&count_bytes);");
            try self.builder.writeLine("// Write object hashes (64 bytes each)");
            try self.builder.writeLine("for (commit.object_hashes) |hash| {");
            self.builder.incIndent();
            try self.builder.writeLine("try result.appendSlice(hash);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return try result.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: parse_vbt_file -> parse complete VBT file
        if (std.mem.indexOf(u8, when_text, "parse") != null and
            std.mem.indexOf(u8, when_text, "file") != null and
            std.mem.indexOf(u8, then_text, "VBTFile") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8, allocator: Allocator) !VBTFile {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Read entire VBT file");
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("const stat = try file.stat();");
            try self.builder.writeLine("const data = try file.readToEndAlloc(allocator, stat.size);");
            try self.builder.writeLine("// Parse header");
            try self.builder.writeLine("const header = try parse_vbt_header(data);");
            try self.builder.writeLine("// Parse objects");
            try self.builder.writeLine("var objects = std.ArrayList(VBTObject).init(allocator);");
            try self.builder.writeLine("defer objects.deinit();");
            try self.builder.writeLine("var obj_pos: usize = 32;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < header.object_count) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("const obj = try parse_vbt_object(data, obj_pos, allocator);");
            try self.builder.writeLine("try objects.append(obj);");
            try self.builder.writeLine("obj_pos += 128 + @as(usize, obj.size * 2);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Parse commits");
            try self.builder.writeLine("var commits = std.ArrayList(VBTCommit).init(allocator);");
            try self.builder.writeLine("defer commits.deinit();");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < header.commit_count) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("const commit = try parse_vbt_commit(data, obj_pos, allocator);");
            try self.builder.writeLine("try commits.append(commit);");
            try self.builder.writeLine("obj_pos += 128 + 64 + commit.message.len + commit.author.len + @as(usize, commit.object_hashes.len * 64);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return VBTFile{");
            try self.builder.writeLine("    .header = header,");
            try self.builder.writeLine("    .objects = try objects.toOwnedSlice(),");
            try self.builder.writeLine("    .commits = try commits.toOwnedSlice(),");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: write_vbt_file -> write complete VBT file
        if (std.mem.indexOf(u8, when_text, "write") != null and
            std.mem.indexOf(u8, when_text, "file") != null and
            std.mem.indexOf(u8, then_text, "path") != null) {
            try self.builder.writeFmt("pub fn {s}(file: VBTFile, path: []const u8) !void {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Write VBT file");
            try self.builder.writeLine("const out_file = try std.fs.cwd().createFile(path, .{});");
            try self.builder.writeLine("defer out_file.close();");
            try self.builder.writeLine("// Write header");
            try self.builder.writeLine("const header_bytes = try write_vbt_header(file.header, std.testing.allocator);");
            try self.builder.writeLine("defer std.testing.allocator.free(header_bytes);");
            try self.builder.writeLine("try out_file.writeAll(header_bytes);");
            try self.builder.writeLine("// Write objects");
            try self.builder.writeLine("for (file.objects) |obj| {");
            self.builder.incIndent();
            try self.builder.writeLine("const obj_bytes = try write_vbt_object(obj, std.testing.allocator);");
            try self.builder.writeLine("defer std.testing.allocator.free(obj_bytes);");
            try self.builder.writeLine("try out_file.writeAll(obj_bytes);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Write commits");
            try self.builder.writeLine("for (file.commits) |commit| {");
            self.builder.incIndent();
            try self.builder.writeLine("const commit_bytes = try write_vbt_commit(commit, std.testing.allocator);");
            try self.builder.writeLine("defer std.testing.allocator.free(commit_bytes);");
            try self.builder.writeLine("try out_file.writeAll(commit_bytes);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: calculate_commit_hash -> calculate SHA-256 hash for commit
        if (std.mem.indexOf(u8, when_text, "calculate") != null and
            std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "hash") != null) {
            try self.builder.writeFmt("pub fn {s}(commit: VBTCommit, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("var hasher = std.crypto.hash.sha2.Sha256.init(.{});");
            try self.builder.writeLine("hasher.update(commit.hash);");
            try self.builder.writeLine("hasher.update(commit.parent_hash);");
            try self.builder.writeLine("const ts_bytes = @as([8]u8, @bitCast(@as(i64, commit.timestamp)));");
            try self.builder.writeLine("hasher.update(&ts_bytes);");
            try self.builder.writeLine("hasher.update(commit.message);");
            try self.builder.writeLine("hasher.update(commit.author);");
            try self.builder.writeLine("for (commit.object_hashes) |hash| hasher.update(hash);");
            try self.builder.writeLine("var hash_result: [32]u8 = undefined;");
            try self.builder.writeLine("hasher.final(&hash_result);");
            try self.builder.writeLine("var hex = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer hex.deinit();");
            try self.builder.writeLine("for (hash_result) |byte| {");
            self.builder.incIndent();
            try self.builder.writeLine("const hi = byte >> 4;");
            try self.builder.writeLine("const lo = byte & 0xF;");
            try self.builder.writeLine("try hex.append(if (hi < 10) '0' + hi else 'a' + hi - 10);");
            try self.builder.writeLine("try hex.append(if (lo < 10) '0' + lo else 'a' + lo - 10);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return try hex.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: merge_trit_sequences -> merge with ternary addition
        if (std.mem.indexOf(u8, when_text, "merge") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(seq1: TritSequence, seq2: TritSequence, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Merge two trit sequences with ternary addition");
            try self.builder.writeLine("const min_len = if (seq1.trits.len < seq2.trits.len) seq1.trits.len else seq2.trits.len;");
            try self.builder.writeLine("var merged = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer merged.deinit();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < min_len) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("// Ternary addition: -1 + -1 = -1, -1 + 0 = -1, -1 + 1 = 0");
            try self.builder.writeLine("// 0 + -1 = -1, 0 + 0 = 0, 0 + 1 = 1");
            try self.builder.writeLine("// 1 + -1 = 0, 1 + 0 = 1, 1 + 1 = 1");
            try self.builder.writeLine("const t1 = seq1.trits[i];");
            try self.builder.writeLine("const t2 = seq2.trits[i];");
            try self.builder.writeLine("const result = if (t1 == -1 and t2 == -1) -1 else if (t1 == -1 and t2 == 0) -1 else if (t1 == -1 and t2 == 1) 0 else if (t1 == 0 and t2 == -1) -1 else if (t1 == 0 and t2 == 0) 0 else if (t1 == 0 and t2 == 1) 1 else if (t1 == 1 and t2 == -1) 0 else if (t1 == 1 and t2 == 0) 1 else 1;");
            try self.builder.writeLine("try merged.append(result);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Append remaining from longer sequence");
            try self.builder.writeLine("if (seq1.trits.len > min_len) {");
            self.builder.incIndent();
            try self.builder.writeLine("for (seq1.trits[min_len..]) |trit| try merged.append(trit);");
            self.builder.decIndent();
            try self.builder.writeLine("} else if (seq2.trits.len > min_len) {");
            self.builder.incIndent();
            try self.builder.writeLine("for (seq2.trits[min_len..]) |trit| try merged.append(trit);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try merged.toOwnedSlice(), .encoded_bytes = &.{} };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: diff_trit_sequences -> compute ternary difference
        if (std.mem.indexOf(u8, when_text, "diff") != null and
            std.mem.indexOf(u8, when_text, "sequence") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(seq1: TritSequence, seq2: TritSequence, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Compute ternary difference");
            try self.builder.writeLine("const min_len = if (seq1.trits.len < seq2.trits.len) seq1.trits.len else seq2.trits.len;");
            try self.builder.writeLine("var diff = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer diff.deinit();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < min_len) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("// Ternary difference: a - b");
            try self.builder.writeLine("const t1 = seq1.trits[i];");
            try self.builder.writeLine("const t2 = seq2.trits[i];");
            try self.builder.writeLine("const result = if (t1 == t2) 0 else if (t1 == 1 and t2 == 0) 1 else if (t1 == 1 and t2 == -1) 1 else if (t1 == 0 and t2 == -1) 1 else if (t1 == 0 and t2 == 1) 1 else -1;");
            try self.builder.writeLine("try diff.append(result);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try diff.toOwnedSlice(), .encoded_bytes = &.{} };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: apply_trit_diff -> apply diff to sequence
        if (std.mem.indexOf(u8, when_text, "apply") != null and
            std.mem.indexOf(u8, when_text, "diff") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(seq: TritSequence, diff_seq: TritSequence, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Apply diff to sequence");
            try self.builder.writeLine("var result = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer result.deinit();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < seq.trits.len and i < diff_seq.trits.len) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("// Apply diff: seq + diff");
            try self.builder.writeLine("const t1 = seq.trits[i];");
            try self.builder.writeLine("const t2 = diff_seq.trits[i];");
            try self.builder.writeLine("const sum = if (t1 == -1 and t2 == -1) -1 else if (t1 == -1 and t2 == 0) -1 else if (t1 == -1 and t2 == 1) 0 else if (t1 == 0 and t2 == -1) -1 else if (t1 == 0 and t2 == 0) 0 else if (t1 == 0 and t2 == 1) 1 else if (t1 == 1 and t2 == -1) 0 else if (t1 == 1 and t2 == 0) 1 else if (t1 == 1 and t2 == 1) 1;");
            try self.builder.writeLine("try result.append(sum);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Append remaining from original sequence");
            try self.builder.writeLine("if (result.items.len < seq.trits.len) {");
            self.builder.incIndent();
            try self.builder.writeLine("for (seq.trits[result.items.len..]) |trit| try result.append(trit);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try result.toOwnedSlice(), .encoded_bytes = seq.encoded_bytes };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: find_object_by_hash -> find object in VBT file
        if (std.mem.indexOf(u8, when_text, "find") != null and
            std.mem.indexOf(u8, when_text, "object") != null and
            std.mem.indexOf(u8, then_text, "VBTObject") != null) {
            try self.builder.writeFmt("pub fn {s}(file: VBTFile, hash: []const u8) !?VBTObject {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Find object by hash");
            try self.builder.writeLine("for (file.objects) |obj| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (std.mem.eql(u8, obj.hash, hash)) return obj;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return null;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: find_commit_by_hash -> find commit in VBT file
        if (std.mem.indexOf(u8, when_text, "find") != null and
            std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "VBTCommit") != null) {
            try self.builder.writeFmt("pub fn {s}(file: VBTFile, hash: []const u8) !?VBTCommit {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Find commit by hash");
            try self.builder.writeLine("for (file.commits) |commit| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (std.mem.eql(u8, commit.hash, hash)) return commit;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return null;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: get_commit_chain -> get commit chain from root
        if (std.mem.indexOf(u8, when_text, "chain") != null and
            std.mem.indexOf(u8, then_text, "List") != null) {
            try self.builder.writeFmt("pub fn {s}(file: VBTFile, commit_hash: []const u8, allocator: Allocator) ![]const VBTCommit {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Walk commit chain from root to tip");
            try self.builder.writeLine("var chain = std.ArrayList(VBTCommit).init(allocator);");
            try self.builder.writeLine("defer chain.deinit();");
            try self.builder.writeLine("// Find commit by hash");
            try self.builder.writeLine("var current = try find_commit_by_hash(file, commit_hash);");
            try self.builder.writeLine("while (current != null) {");
            self.builder.incIndent();
            try self.builder.writeLine("try chain.append(current);");
            try self.builder.writeLine("if (std.mem.eql(u8, current.parent_hash, \"000000000000000000000000000000000000000000000000000000000000000000000000000000000\")) break;");
            try self.builder.writeLine("current = try find_commit_by_hash(file, current.parent_hash);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Reverse chain (from root to tip)");
            try self.builder.writeLine("const reversed = try chain.toOwnedSlice();");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < reversed.len / 2) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("const tmp = reversed[i];");
            try self.builder.writeLine("reversed[i] = reversed[reversed.len - 1 - i];");
            try self.builder.writeLine("reversed[reversed.len - 1 - i] = tmp;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return reversed;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: export_trits_to_binary -> export trits to binary
        if (std.mem.indexOf(u8, when_text, "export") != null and
            std.mem.indexOf(u8, when_text, "trits") != null and
            std.mem.indexOf(u8, then_text, "bytes") != null) {
            try self.builder.writeFmt("pub fn {s}(seq: TritSequence, allocator: Allocator) ![]const u8 {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Export trits to binary bytes");
            try self.builder.writeLine("var result = std.ArrayList(u8).init(allocator);");
            try self.builder.writeLine("defer result.deinit();");
            try self.builder.writeLine("// Each trit becomes 2 bits in a byte");
            try self.builder.writeLine("for (seq.trits) |trit| {");
            self.builder.incIndent();
            try self.builder.writeLine("const enc = if (trit == 1) 0 else if (trit == 0) 1 else 2;");
            try self.builder.writeLine("try result.append(@as(u8, enc));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return try result.toOwnedSlice();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: import_binary_to_trits -> import binary to trits
        if (std.mem.indexOf(u8, when_text, "import") != null and
            std.mem.indexOf(u8, when_text, "binary") != null and
            std.mem.indexOf(u8, then_text, "TritSequence") != null) {
            try self.builder.writeFmt("pub fn {s}(bytes: []const u8, trit_count: usize, allocator: Allocator) !TritSequence {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Import binary to trits");
            try self.builder.writeLine("var trits = std.ArrayList(i64).init(allocator);");
            try self.builder.writeLine("defer trits.deinit();");
            try self.builder.writeLine("// Each byte contains 2 trits");
            try self.builder.writeLine("var i: usize = 0;");
            try self.builder.writeLine("while (i < bytes.len and trits.items.len < trit_count) {");
            self.builder.incIndent();
            try self.builder.writeLine("const byte = bytes[i];");
            try self.builder.writeLine("const high = @as(i64, (byte >> 4) & 0x3);");
            try self.builder.writeLine("const low = @as(i64, byte & 0x3);");
            try self.builder.writeLine("const trit_high = if (high == 0) 1 else if (high == 1) 0 else -1;");
            try self.builder.writeLine("const trit_low = if (low == 0) 1 else if (low == 1) 0 else -1;");
            try self.builder.writeLine("try trits.append(trit_high);");
            try self.builder.writeLine("if (trits.items.len < trit_count) try trits.append(trit_low);");
            try self.builder.writeLine("i += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return TritSequence{ .trits = try trits.toOwnedSlice(), .encoded_bytes = bytes };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // ═══════════════════════════════════════════════════════════════════════════════
        // CLI COMMAND PATTERNS
        // ═══════════════════════════════════════════════════════════════════════════════

        // Pattern: parse_vbt_command -> parse CLI command
        if (std.mem.indexOf(u8, when_text, "parse") != null and
            std.mem.indexOf(u8, when_text, "command") != null and
            std.mem.indexOf(u8, then_text, "VBTCommand") != null) {
            try self.builder.writeFmt("pub fn {s}(args: [][]const u8) !VBTCommand {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Parse VBT CLI command from arguments");
            try self.builder.writeLine("if (args.len == 0) return error.NoCommand;");
            try self.builder.writeLine("const cmd = args[0];");
            try self.builder.writeLine("const command_args = args[1..];");
            try self.builder.writeLine("return VBTCommand{");
            try self.builder.writeLine("    .command = cmd,");
            try self.builder.writeLine("    .args = command_args,");
            try self.builder.writeLine("};");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_init -> initialize VBT repository
        if (std.mem.indexOf(u8, when_text, "init") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Initialize VBT repository");
            try self.builder.writeLine("const vbt_path = try std.fs.path.join(std.heap.page_allocator, &.{path, \".vbt\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(vbt_path);");
            try self.builder.writeLine("try std.fs.cwd().makePath(vbt_path);");
            try self.builder.writeLine("// Create subdirectories");
            try self.builder.writeLine("const objects_path = try std.fs.path.join(std.heap.page_allocator, &.{vbt_path, \"objects\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(objects_path);");
            try self.builder.writeLine("try std.fs.cwd().makePath(objects_path);");
            try self.builder.writeLine("const commits_path = try std.fs.path.join(std.heap.page_allocator, &.{vbt_path, \"commits\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(commits_path);");
            try self.builder.writeLine("try std.fs.cwd().makePath(commits_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"VBT repository initialized\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_add -> add files to VBT repository
        if (std.mem.indexOf(u8, when_text, "add") != null and
            std.mem.indexOf(u8, when_text, "files") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, files: [][]const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Add files to VBT repository using vbt_storage_integration");
            try self.builder.writeLine("var added_count: usize = 0;");
            try self.builder.writeLine("for (files) |file_path| {");
            self.builder.incIndent();
            try self.builder.writeLine("// Read file content");
            try self.builder.writeLine("const file = try std.fs.cwd().openFile(file_path, .{});");
            try self.builder.writeLine("defer file.close();");
            try self.builder.writeLine("const stat = try file.stat();");
            try self.builder.writeLine("const content = try file.readToEndAlloc(std.heap.page_allocator, stat.size);");
            try self.builder.writeLine("defer std.heap.page_allocator.free(content);");
            try self.builder.writeLine("// Create VBT file entry");
            try self.builder.writeLine("const entry = VBTFileEntry{");
            try self.builder.writeLine("    .path = file_path,");
            try self.builder.writeLine("    .trit_hash = \"\", // TODO: calculate trit hash");
            try self.builder.writeLine("    .size = @as(i64, stat.size),");
            try self.builder.writeLine("    .modified = std.time.timestamp(),");
            try self.builder.writeLine("    .trit_count = 0, // TODO: calculate trit count");
            try self.builder.writeLine("    .compressed = false,");
            try self.builder.writeLine("};");
            try self.builder.writeLine("// Write to VBT storage");
            try self.builder.writeLine("_ = try write_vbt_file(entry, content);");
            try self.builder.writeLine("added_count += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeFmt("return VBTResult{{ .success = true, .message = \"Added {} files\" }};\n", .{"added_count"});
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_commit -> create commit
        if (std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, when_text, "changes") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, message: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Create VBT commit using vbt_storage_integration");
            try self.builder.writeLine("// Get repository info to find staged files");
            try self.builder.writeLine("const repo_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("// Create commit with staged entries");
            try self.builder.writeLine("var entries = std.ArrayList(VBTFileEntry).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer entries.deinit();");
            try self.builder.writeLine("// TODO: Read staged files from .vbt/index");
            try self.builder.writeLine("const commit_result = try create_vbt_commit(message, entries.items);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Commit created\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_status -> show repository status
        if (std.mem.indexOf(u8, when_text, "status") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Show VBT repository status using vbt_storage_integration");
            try self.builder.writeLine("const repo_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("// Read HEAD commit");
            try self.builder.writeLine("const head_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"HEAD\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_path);");
            try self.builder.writeLine("const head_file = std.fs.cwd().openFile(head_path, .{}) catch |err| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (err == error.FileNotFound) return VBTResult{ .success = true, .message = \"No commits yet\" };");
            try self.builder.writeLine("return err;");
            self.builder.decIndent();
            try self.builder.writeLine("};");
            try self.builder.writeLine("defer head_file.close();");
            try self.builder.writeLine("const head_content = try head_file.readToEndAlloc(std.heap.page_allocator, 1024);");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_content);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = head_content };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_log -> show commit history
        if (std.mem.indexOf(u8, when_text, "log") != null and
            std.mem.indexOf(u8, when_text, "commits") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, limit: u32) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Show VBT commit history using vbt_storage_integration");
            try self.builder.writeLine("const commits = try list_vbt_commits(repo_path, limit);");
            try self.builder.writeLine("// Format commit history");
            try self.builder.writeLine("var output = std.ArrayList(u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer output.deinit();");
            try self.builder.writeLine("for (commits) |commit| {");
            self.builder.incIndent();
            try self.builder.writeLine("try output.writer().print(\"{s}: {s}\\n\", .{ commit.commit_id, commit.message });");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = output.items };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_checkout -> checkout commit
        if (std.mem.indexOf(u8, when_text, "checkout") != null and
            std.mem.indexOf(u8, when_text, "commit") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, commit_id: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Checkout VBT commit using vbt_storage_integration");
            try self.builder.writeLine("// Get commit details");
            try self.builder.writeLine("const commit = try get_vbt_commit(commit_id);");
            try self.builder.writeLine("// Update HEAD to commit_id");
            try self.builder.writeLine("const head_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"HEAD\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_path);");
            try self.builder.writeLine("const head_file = try std.fs.cwd().createFile(head_path, .{});");
            try self.builder.writeLine("defer head_file.close();");
            try self.builder.writeLine("try head_file.writeAll(commit_id);");
            try self.builder.writeLine("// TODO: Restore working directory from commit");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Checked out\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_branch -> create/list branches
        if (std.mem.indexOf(u8, when_text, "branch") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, branch_name: ?[]const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Create or list VBT branches using vbt_storage_integration");
            try self.builder.writeLine("if (branch_name) |name| {");
            self.builder.incIndent();
            try self.builder.writeLine("// Create new branch");
            try self.builder.writeLine("const branch_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"refs\", \"heads\", name});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(branch_path);");
            try self.builder.writeLine("try std.fs.cwd().makePath(branch_path);");
            try self.builder.writeLine("// Write HEAD commit to branch");
            try self.builder.writeLine("const head_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"HEAD\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_path);");
            try self.builder.writeLine("const head_content = try std.fs.cwd().readFileAlloc(head_path, std.heap.page_allocator, 1024);");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_content);");
            try self.builder.writeLine("try std.fs.cwd().writeFile(branch_path, head_content);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Branch created\" };");
            self.builder.decIndent();
            try self.builder.writeLine("} else {");
            self.builder.incIndent();
            try self.builder.writeLine("// List all branches");
            try self.builder.writeLine("const refs_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"refs\", \"heads\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(refs_path);");
            try self.builder.writeLine("var branches = std.ArrayList([]const u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer branches.deinit();");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(refs_path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("try branches.append(try std.heap.page_allocator.dupe(u8, entry.name));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Branches listed\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_merge -> merge branches
        if (std.mem.indexOf(u8, when_text, "merge") != null and
            std.mem.indexOf(u8, when_text, "branch") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, branch_name: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Merge VBT branch using vbt_storage_integration");
            try self.builder.writeLine("// Read branch HEAD");
            try self.builder.writeLine("const branch_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"refs\", \"heads\", branch_name});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(branch_path);");
            try self.builder.writeLine("const branch_head = try std.fs.cwd().readFileAlloc(branch_path, std.heap.page_allocator, 64);");
            try self.builder.writeLine("defer std.heap.page_allocator.free(branch_head);");
            try self.builder.writeLine("// Read current HEAD");
            try self.builder.writeLine("const head_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"HEAD\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(head_path);");
            try self.builder.writeLine("const current_head = try std.fs.cwd().readFileAlloc(head_path, std.heap.page_allocator, 64);");
            try self.builder.writeLine("defer std.heap.page_allocator.free(current_head);");
            try self.builder.writeLine("// TODO: Perform three-way merge");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Merged\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_push -> push to remote
        if (std.mem.indexOf(u8, when_text, "push") != null and
            std.mem.indexOf(u8, when_text, "remote") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, remote: ?[]const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Push to remote repository using vbt_storage_integration");
            try self.builder.writeLine("// Sync with filesystem first");
            try self.builder.writeLine("const sync_result = try sync_vbt_with_fs(repo_path, true);");
            try self.builder.writeLine("// TODO: Push to remote repository");
            try self.builder.writeLine("_ = remote;");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Pushed\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_pull -> pull from remote
        if (std.mem.indexOf(u8, when_text, "pull") != null and
            std.mem.indexOf(u8, when_text, "remote") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, remote: ?[]const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Pull from remote repository using vbt_storage_integration");
            try self.builder.writeLine("// TODO: Pull from remote repository");
            try self.builder.writeLine("_ = repo_path;");
            try self.builder.writeLine("_ = remote;");
            try self.builder.writeLine("// Sync with filesystem after pull");
            try self.builder.writeLine("const sync_result = try sync_vbt_with_fs(repo_path, true);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Pulled\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_diff -> show differences
        if (std.mem.indexOf(u8, when_text, "diff") != null and
            std.mem.indexOf(u8, when_text, "commits") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, commit_a: ?[]const u8, commit_b: ?[]const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Show VBT diff using vbt_storage_integration");
            try self.builder.writeLine("// Get commits to compare");
            try self.builder.writeLine("const commit_a_data = if (commit_a) |id| try get_vbt_commit(id) else null;");
            try self.builder.writeLine("const commit_b_data = if (commit_b) |id| try get_vbt_commit(id) else null;");
            try self.builder.writeLine("// TODO: Compute trit diff between commits");
            try self.builder.writeLine("_ = repo_path;");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Diff computed\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_export -> export files
        if (std.mem.indexOf(u8, when_text, "export") != null and
            std.mem.indexOf(u8, when_text, "files") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, export_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Export VBT files using vbt_storage_integration");
            try self.builder.writeLine("const export_result = try export_vbt_to_directory(repo_path, export_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Exported\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_import -> import files
        if (std.mem.indexOf(u8, when_text, "import") != null and
            std.mem.indexOf(u8, when_text, "files") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, import_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Import files to VBT using vbt_storage_integration");
            try self.builder.writeLine("const import_result = try import_vbt_from_directory(import_path, repo_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Imported\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_trit_info -> show trit information
        if (std.mem.indexOf(u8, when_text, "trit") != null and
            std.mem.indexOf(u8, when_text, "info") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Show trit information using vbt_storage_integration");
            try self.builder.writeLine("const stats = try calculate_vbt_stats(repo_path);");
            try self.builder.writeLine("// Format trit statistics");
            try self.builder.writeLine("var output = std.ArrayList(u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer output.deinit();");
            try self.builder.writeLine("try output.writer().print(\"Total trits: {d}\\n\", .{stats.total_trits});");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = output.items };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_compress -> compress VBT files
        if (std.mem.indexOf(u8, when_text, "compress") != null and
            std.mem.indexOf(u8, when_text, "VBT") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Compress VBT files using vbt_storage_integration");
            try self.builder.writeLine("// Find all .vbt files in repository");
            try self.builder.writeLine("const vbt_dir = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(vbt_dir);");
            try self.builder.writeLine("var files = std.ArrayList([]const u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer files.deinit();");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(vbt_dir, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (std.mem.endsWith(u8, entry.name, \".vbt\")) {");
            self.builder.incIndent();
            try self.builder.writeLine("try files.append(try std.heap.page_allocator.dupe(u8, entry.name));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Compress files");
            try self.builder.writeLine("const compress_result = try compress_vbt_files(files.items, 6);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Compressed\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_decompress -> decompress VBT files
        if (std.mem.indexOf(u8, when_text, "decompress") != null and
            std.mem.indexOf(u8, when_text, "VBT") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Decompress VBT files using vbt_storage_integration");
            try self.builder.writeLine("// Find all compressed .vbt files");
            try self.builder.writeLine("const vbt_dir = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(vbt_dir);");
            try self.builder.writeLine("var files = std.ArrayList([]const u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer files.deinit();");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(vbt_dir, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (std.mem.endsWith(u8, entry.name, \".vbt\")) {");
            self.builder.incIndent();
            try self.builder.writeLine("try files.append(try std.heap.page_allocator.dupe(u8, entry.name));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Decompress files");
            try self.builder.writeLine("const decompress_result = try decompress_vbt_files(files.items);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Decompressed\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_validate -> validate VBT repository
        if (std.mem.indexOf(u8, when_text, "validate") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Validate VBT repository using vbt_storage_integration");
            try self.builder.writeLine("const validation_result = try validate_vbt_repository(repo_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Valid\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_stats -> show statistics
        if (std.mem.indexOf(u8, when_text, "stats") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Show VBT repository statistics using vbt_storage_integration");
            try self.builder.writeLine("const stats = try calculate_vbt_stats(repo_path);");
            try self.builder.writeLine("// Format statistics");
            try self.builder.writeLine("var output = std.ArrayList(u8).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer output.deinit();");
            try self.builder.writeLine("try output.writer().print(\"Objects: {d}, Commits: {d}\\n\", .{stats.object_count, stats.commit_count});");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = output.items };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_cleanup -> cleanup repository
        if (std.mem.indexOf(u8, when_text, "cleanup") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Cleanup VBT repository using vbt_storage_integration");
            try self.builder.writeLine("// Get repository info");
            try self.builder.writeLine("const repo_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("// Get all commits to find reachable objects");
            try self.builder.writeLine("const commits = try list_vbt_commits(repo_path, 1000);");
            try self.builder.writeLine("// Build set of reachable object hashes");
            try self.builder.writeLine("var reachable = std.StringHashMap(void).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer reachable.deinit();");
            try self.builder.writeLine("for (commits) |commit| {");
            self.builder.incIndent();
            try self.builder.writeLine("try reachable.put(commit.commit_id, {});");
            try self.builder.writeLine("// TODO: Add objects referenced by commits");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// List all objects in repository");
            try self.builder.writeLine("const objects_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"objects\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(objects_path);");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(objects_path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("var removed_count: usize = 0;");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (entry.kind == .file) {");
            self.builder.incIndent();
            try self.builder.writeLine("const obj_hash = entry.name;");
            try self.builder.writeLine("if (!reachable.contains(obj_hash)) {");
            self.builder.incIndent();
            try self.builder.writeLine("// Remove unreachable object");
            try self.builder.writeLine("const obj_path = try std.fs.path.join(std.heap.page_allocator, &.{objects_path, obj_hash});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(obj_path);");
            try self.builder.writeLine("try std.fs.cwd().deleteFile(obj_path);");
            try self.builder.writeLine("removed_count += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Update repository info");
            try self.builder.writeLine("const new_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("var msg_buf: [128]u8 = undefined;");
            try self.builder.writeLine("const msg = try std.fmt.bufPrint(&msg_buf, \"Removed {d} unreachable objects\", .{removed_count});");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = msg };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_gc -> garbage collection
        if (std.mem.indexOf(u8, when_text, "garbage") != null and
            std.mem.indexOf(u8, when_text, "collection") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Garbage collection for VBT repository using vbt_storage_integration");
            try self.builder.writeLine("// Get repository info before GC");
            try self.builder.writeLine("const before_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("// Mark phase: find all reachable objects from HEAD");
            try self.builder.writeLine("const commits = try list_vbt_commits(repo_path, 1000);");
            try self.builder.writeLine("var reachable = std.StringHashMap(void).init(std.heap.page_allocator);");
            try self.builder.writeLine("defer reachable.deinit();");
            try self.builder.writeLine("// Mark all commits as reachable");
            try self.builder.writeLine("for (commits) |commit| {");
            self.builder.incIndent();
            try self.builder.writeLine("try reachable.put(commit.commit_id, {});");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Sweep phase: remove unreachable objects");
            try self.builder.writeLine("const objects_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"objects\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(objects_path);");
            try self.builder.writeLine("var dir = try std.fs.cwd().openDir(objects_path, .{ .iterate = true });");
            try self.builder.writeLine("defer dir.close();");
            try self.builder.writeLine("var iter = dir.iterate();");
            try self.builder.writeLine("var removed_count: usize = 0;");
            try self.builder.writeLine("while (try iter.next()) |entry| {");
            self.builder.incIndent();
            try self.builder.writeLine("if (entry.kind == .file) {");
            self.builder.incIndent();
            try self.builder.writeLine("const obj_hash = entry.name;");
            try self.builder.writeLine("if (!reachable.contains(obj_hash)) {");
            self.builder.incIndent();
            try self.builder.writeLine("// Remove unreachable object");
            try self.builder.writeLine("const obj_path = try std.fs.path.join(std.heap.page_allocator, &.{objects_path, obj_hash});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(obj_path);");
            try self.builder.writeLine("try std.fs.cwd().deleteFile(obj_path);");
            try self.builder.writeLine("removed_count += 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("// Compact storage: compress all .vbt files");
            try self.builder.writeLine("const compress_result = try compress_vbt_files(repo_path);");
            try self.builder.writeLine("// Get repository info after GC");
            try self.builder.writeLine("const after_info = try get_vbt_repository_info(repo_path);");
            try self.builder.writeLine("// Calculate freed space");
            try self.builder.writeLine("const freed_trits = before_info.total_trits - after_info.total_trits;");
            try self.builder.writeLine("const freed_bytes = before_info.total_size - after_info.total_size;");
            try self.builder.writeLine("var msg_buf: [256]u8 = undefined;");
            try self.builder.writeLine("const msg = try std.fmt.bufPrint(&msg_buf, \"GC completed: removed {d} objects, freed {d} trits ({d} bytes)\", .{removed_count, freed_trits, freed_bytes});");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = msg };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_repair -> repair repository
        if (std.mem.indexOf(u8, when_text, "repair") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Repair VBT repository using vbt_storage_integration");
            try self.builder.writeLine("const repair_result = try repair_vbt_repository(repo_path, true);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Repaired\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_backup -> backup repository
        if (std.mem.indexOf(u8, when_text, "backup") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, backup_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Backup VBT repository using vbt_storage_integration");
            try self.builder.writeLine("const backup_result = try backup_vbt_repository(repo_path, backup_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Backed up\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_restore -> restore repository
        if (std.mem.indexOf(u8, when_text, "restore") != null and
            std.mem.indexOf(u8, when_text, "repository") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, backup_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Restore VBT repository using vbt_storage_integration");
            try self.builder.writeLine("const restore_result = try restore_vbt_repository(repo_path, backup_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Restored\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_watch -> watch directory
        if (std.mem.indexOf(u8, when_text, "watch") != null and
            std.mem.indexOf(u8, when_text, "directory") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, watch_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Watch directory for changes using vbt_storage_integration");
            try self.builder.writeLine("// Start watching with filesystem watcher");
            try self.builder.writeLine("const watch_result = try watch_vbt_directory(repo_path, watch_path);");
            try self.builder.writeLine("// Create watch config file");
            try self.builder.writeLine("const watch_config_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"watch\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(watch_config_path);");
            try self.builder.writeLine("var watch_config = try std.fs.cwd().createFile(watch_config_path, .{});");
            try self.builder.writeLine("defer watch_config.close();");
            try self.builder.writeLine("try watch_config.writeAll(watch_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Watching\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Pattern: vbt_unwatch -> stop watching directory
        if (std.mem.indexOf(u8, when_text, "unwatch") != null and
            std.mem.indexOf(u8, when_text, "directory") != null and
            std.mem.indexOf(u8, then_text, "VBTResult") != null) {
            try self.builder.writeFmt("pub fn {s}(repo_path: []const u8, watch_path: []const u8) !VBTResult {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeLine("// Stop watching directory using vbt_storage_integration");
            try self.builder.writeLine("// Stop watching");
            try self.builder.writeLine("const unwatch_result = try unwatch_vbt_directory(repo_path, watch_path);");
            try self.builder.writeLine("// Remove watch config file");
            try self.builder.writeLine("const watch_config_path = try std.fs.path.join(std.heap.page_allocator, &.{repo_path, \".vbt\", \"watch\"});");
            try self.builder.writeLine("defer std.heap.page_allocator.free(watch_config_path);");
            try self.builder.writeLine("try std.fs.cwd().deleteFile(watch_config_path);");
            try self.builder.writeLine("return VBTResult{ .success = true, .message = \"Stopped watching\" };");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // No pattern matched
        return false;
    }

    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Священная формула: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Золотая идентичность: φ² + 1/φ² = 3");
        try self.builder.writeLine("//");
        try self.builder.writeFmt("// Author: {s}\n", .{spec.author});
        try self.builder.writeLine("// DO NOT EDIT - This file is auto-generated");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }

    fn writeImports(self: *Self) !void {
        try self.builder.writeLine("const std = @import(\"std\");");
        try self.builder.writeLine("const math = std.math;");
        try self.builder.newline();
    }

    fn writeConstants(self: *Self, constants: []const Constant) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// КОНСТАНТЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (constants) |c| {
            if (c.description.len > 0) {
                try self.builder.writeFmt("/// {s}\n", .{c.description});
            }
            try self.builder.writeFmt("pub const {s}: f64 = {d};\n", .{ c.name, c.value });
            try self.builder.newline();
        }

        // Добавляем базовые φ-константы только если их нет в спецификации
        var has_phi = false;
        for (constants) |c| {
            if (std.mem.eql(u8, c.name, "PHI")) {
                has_phi = true;
                break;
            }
        }

        // Добавляем базовые φ-константы если их нет
        try self.builder.writeLine("// Базовые φ-константы (Sacred Formula)");

        var has_phi_inv = false;
        var has_phi_sq = false;
        var has_trinity = false;
        var has_sqrt5 = false;
        var has_tau = false;
        var has_pi = false;
        var has_e = false;
        var has_phoenix = false;

        for (constants) |c| {
            if (std.mem.eql(u8, c.name, "PHI_INV")) has_phi_inv = true;
            if (std.mem.eql(u8, c.name, "PHI_SQ")) has_phi_sq = true;
            if (std.mem.eql(u8, c.name, "TRINITY")) has_trinity = true;
            if (std.mem.eql(u8, c.name, "SQRT5")) has_sqrt5 = true;
            if (std.mem.eql(u8, c.name, "TAU")) has_tau = true;
            if (std.mem.eql(u8, c.name, "PI")) has_pi = true;
            if (std.mem.eql(u8, c.name, "E")) has_e = true;
            if (std.mem.eql(u8, c.name, "PHOENIX")) has_phoenix = true;
        }

        if (!has_phi) try self.builder.writeLine("pub const PHI: f64 = 1.618033988749895;");
        if (!has_phi_inv) try self.builder.writeLine("pub const PHI_INV: f64 = 0.618033988749895;");
        if (!has_phi_sq) try self.builder.writeLine("pub const PHI_SQ: f64 = 2.618033988749895;");
        if (!has_trinity) try self.builder.writeLine("pub const TRINITY: f64 = 3.0;");
        if (!has_sqrt5) try self.builder.writeLine("pub const SQRT5: f64 = 2.2360679774997896;");
        if (!has_tau) try self.builder.writeLine("pub const TAU: f64 = 6.283185307179586;");
        if (!has_pi) try self.builder.writeLine("pub const PI: f64 = 3.141592653589793;");
        if (!has_e) try self.builder.writeLine("pub const E: f64 = 2.718281828459045;");
        if (!has_phoenix) try self.builder.writeLine("pub const PHOENIX: i64 = 999;");
        try self.builder.newline();
    }

    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        if (types.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ТИПЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (types) |t| {
            try self.builder.writeFmt("/// {s}\n", .{t.description});

            if (t.base) |base| {
                try self.builder.writeFmt("pub const {s} = {s};\n", .{ t.name, base });
            } else {
                try self.builder.writeFmt("pub const {s} = struct {{\n", .{t.name});
                self.builder.incIndent();

                for (t.fields.items) |field| {
                    try self.builder.writeIndent();
                    const clean_type = cleanTypeName(field.type_name);
                    const safe_name = escapeReservedWord(field.name);
                    try self.builder.writeFmt("{s}: {s},\n", .{ safe_name, mapType(clean_type) });
                }

                self.builder.decIndent();
                try self.builder.writeLine("};");
            }
            try self.builder.newline();
        }
    }

    fn writeMemoryBuffers(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ПАМЯТЬ ДЛЯ WASM");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeLine("var global_buffer: [65536]u8 align(16) = undefined;");
        try self.builder.writeLine("var f64_buffer: [8192]f64 align(16) = undefined;");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_global_buffer_ptr() [*]u8 {");
        try self.builder.writeLine("    return &global_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_f64_buffer_ptr() [*]f64 {");
        try self.builder.writeLine("    return &f64_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeCreationPatterns(self: *Self, patterns: []const CreationPattern) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// CREATION PATTERNS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (patterns) |p| {
            try self.builder.writeFmt("/// {s}\n", .{p.transformer});
            try self.builder.writeFmt("/// Source: {s} -> Result: {s}\n", .{ p.source, p.result });
            try self.generatePatternFunction(p);
            try self.builder.newline();
        }

        // Генерируем стандартные φ-функции
        try self.generateStandardFunctions();
    }

    fn generatePatternFunction(self: *Self, pattern: CreationPattern) !void {
        if (std.mem.eql(u8, pattern.name, "phi_power")) {
            try self.builder.writeLine("fn phi_power(n: i32) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 1.0;");
            try self.builder.writeLine("if (n == 1) return PHI;");
            try self.builder.writeLine("if (n == -1) return PHI_INV;");
            try self.builder.newline();
            try self.builder.writeLine("var result: f64 = 1.0;");
            try self.builder.writeLine("var base: f64 = if (n < 0) PHI_INV else PHI;");
            try self.builder.writeLine("var exp: u32 = if (n < 0) @intCast(-n) else @intCast(n);");
            try self.builder.newline();
            try self.builder.writeLine("while (exp > 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("if (exp & 1 == 1) result *= base;");
            try self.builder.writeLine("base *= base;");
            try self.builder.writeLine("exp >>= 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "fibonacci")) {
            try self.builder.writeLine("fn fibonacci(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("if (n <= 2) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round((phi_n - psi_n) / SQRT5));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lucas")) {
            try self.builder.writeLine("fn lucas(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 2;");
            try self.builder.writeLine("if (n == 1) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round(phi_n + psi_n));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "factorial")) {
            try self.builder.writeLine("/// Factorial n! - O(n)");
            try self.builder.writeLine("fn factorial(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n <= 1) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 2;");
            try self.builder.writeLine("while (i <= n) : (i += 1) result *%= i;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "gcd")) {
            try self.builder.writeLine("/// GCD using Euclidean algorithm - O(log(min(a,b)))");
            try self.builder.writeLine("fn gcd(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("var x = a;");
            try self.builder.writeLine("var y = b;");
            try self.builder.writeLine("while (y != 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("const t = y;");
            try self.builder.writeLine("y = x % y;");
            try self.builder.writeLine("x = t;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return x;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lcm")) {
            try self.builder.writeLine("/// LCM using GCD - O(log(min(a,b)))");
            try self.builder.writeLine("fn lcm(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (a == 0 or b == 0) return 0;");
            try self.builder.writeLine("return (a / gcd(a, b)) * b;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "digital_root")) {
            try self.builder.writeLine("/// Digital root (repeated digit sum until single digit) - O(1)");
            try self.builder.writeLine("fn digital_root(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("const r = n % 9;");
            try self.builder.writeLine("return if (r == 0) 9 else r;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "trinity_power")) {
            try self.builder.writeLine("/// Trinity power 3^k with lookup table - O(1) for k < 20");
            try self.builder.writeLine("fn trinity_power(k: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("const powers = [_]u64{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049, 177147, 531441, 1594323, 4782969, 14348907, 43046721, 129140163, 387420489, 1162261467 };");
            try self.builder.writeLine("if (k < powers.len) return powers[k];");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) result *= 3;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "sacred_formula")) {
            try self.builder.writeLine("/// Sacred formula: V = n × 3^k × π^m × φ^p × e^q");
            try self.builder.writeLine("fn sacred_formula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return n * math.pow(f64, 3.0, k) * math.pow(f64, PI, m) * math.pow(f64, PHI, p) * math.pow(f64, E, q);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "golden_identity")) {
            try self.builder.writeLine("/// Golden identity: φ² + 1/φ² = 3");
            try self.builder.writeLine("fn golden_identity() f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return PHI * PHI + 1.0 / (PHI * PHI);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "binomial")) {
            try self.builder.writeLine("/// Binomial coefficient C(n,k) = n! / (k! * (n-k)!)");
            try self.builder.writeLine("fn binomial(n: u64, k: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (k > n) return 0;");
            try self.builder.writeLine("if (k == 0 or k == n) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("result = result * (n - i) / (i + 1);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        }
    }

    fn generateStandardFunctions(self: *Self) !void {
        // Trit type and operations
        try self.builder.writeLine("/// Trit - ternary digit (-1, 0, +1)");
        try self.builder.writeLine("pub const Trit = enum(i8) {");
        try self.builder.writeLine("    negative = -1, // ▽ FALSE");
        try self.builder.writeLine("    zero = 0,      // ○ UNKNOWN");
        try self.builder.writeLine("    positive = 1,  // △ TRUE");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_and(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_or(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_not(a: Trit) Trit {");
        try self.builder.writeLine("        return @enumFromInt(-@intFromEnum(a));");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    pub fn trit_xor(a: Trit, b: Trit) Trit {");
        try self.builder.writeLine("        const av = @intFromEnum(a);");
        try self.builder.writeLine("        const bv = @intFromEnum(b);");
        try self.builder.writeLine("        if (av == 0 or bv == 0) return .zero;");
        try self.builder.writeLine("        if (av == bv) return .negative;");
        try self.builder.writeLine("        return .positive;");
        try self.builder.writeLine("    }");
        try self.builder.writeLine("};");
        try self.builder.newline();

        // verify_trinity
        try self.builder.writeLine("/// Проверка TRINITY identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("fn verify_trinity() f64 {");
        try self.builder.writeLine("    return PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // phi_lerp
        try self.builder.writeLine("/// φ-интерполяция");
        try self.builder.writeLine("fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
        try self.builder.writeLine("    const phi_t = math.pow(f64, t, PHI_INV);");
        try self.builder.writeLine("    return a + (b - a) * phi_t;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // generate_phi_spiral
        try self.builder.writeLine("/// Генерация φ-спирали");
        try self.builder.writeLine("fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {");
        self.builder.incIndent();
        try self.builder.writeLine("const max_points = f64_buffer.len / 2;");
        try self.builder.writeLine("const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;");
        try self.builder.writeLine("var i: u32 = 0;");
        try self.builder.writeLine("while (i < count) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("const fi: f64 = @floatFromInt(i);");
        try self.builder.writeLine("const angle = fi * TAU * PHI_INV;");
        try self.builder.writeLine("const radius = scale * math.pow(f64, PHI, fi * 0.1);");
        try self.builder.writeLine("f64_buffer[i * 2] = cx + radius * @cos(angle);");
        try self.builder.writeLine("f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.writeLine("return count;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeTests(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTS - Generated from behaviors and test_cases");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        // Отслеживаем уже добавленные тесты
        var added_tests = std.StringHashMap(void).init(self.allocator);
        defer added_tests.deinit();

        for (behaviors) |b| {
            // Пропускаем дубликаты
            if (added_tests.contains(b.name)) continue;
            added_tests.put(b.name, {}) catch continue;

            try self.builder.writeFmt("test \"{s}_behavior\" {{\n", .{b.name});
            self.builder.incIndent();
            try self.builder.writeFmt("// Given: {s}\n", .{b.given});
            try self.builder.writeFmt("// When: {s}\n", .{b.when});
            try self.builder.writeFmt("// Then: {s}\n", .{b.then});

            // Генерируем assertions из test_cases
            if (b.test_cases.items.len > 0) {
                for (b.test_cases.items) |tc| {
                    try self.generateTestAssertion(b.name, tc);
                }
            } else {
                // Fallback для известных тестов без test_cases
                try self.generateKnownTestAssertion(b.name);
            }

            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.newline();
        }

        // Добавляем базовый тест констант если его нет
        if (!added_tests.contains("phi_constants")) {
            try self.builder.writeLine("test \"phi_constants\" {");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);");
            try self.builder.writeLine("}");
        }
    }

    fn generateTestAssertion(self: *Self, behavior_name: []const u8, tc: TestCase) !void {
        // Парсим input: { n: 0 } или { a: 0, b: 100, t: 0.5 }
        // Убираем кавычки если есть
        const input = stripQuotes(tc.input);
        // Извлекаем только число из expected (может содержать комментарий)
        const expected = extractNumber(stripQuotes(tc.expected));

        // Используем tc.name если есть, иначе behavior_name
        const func_name = if (tc.name.len > 0) tc.name else behavior_name;

        // Определяем функцию по имени
        if (std.mem.startsWith(u8, func_name, "phi_power")) {
            // Извлекаем n из input
            if (extractIntParam(input, "n")) |n| {
                if (tc.tolerance) |tol| {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, {d});\n", .{ n, expected, tol });
                } else {
                    try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_power({d}), {s}, 1e-10);\n", .{ n, expected });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "fibonacci") or std.mem.startsWith(u8, func_name, "test_fibonacci")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(fibonacci({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "lucas") or std.mem.startsWith(u8, func_name, "test_lucas")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(lucas({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.eql(u8, func_name, "trinity_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else if (std.mem.startsWith(u8, func_name, "phi_spiral")) {
            // phi_spiral тесты
            try self.builder.writeLine("const count = generate_phi_spiral(100, 10.0, 0.0, 0.0);");
            try self.builder.writeLine("try std.testing.expect(count > 0);");
        } else if (std.mem.startsWith(u8, func_name, "phi_lerp")) {
            // phi_lerp тесты - используем большую tolerance из-за приближённых значений в spec
            if (extractFloatParam(input, "t")) |t| {
                const a = extractFloatParam(input, "a") orelse 0.0;
                const b_val = extractFloatParam(input, "b") orelse 100.0;
                const tol = tc.tolerance orelse 1.0; // Большая tolerance для phi_lerp
                try self.builder.writeFmt("try std.testing.expectApproxEqAbs(phi_lerp({d}, {d}, {d}), {s}, {d});\n", .{ a, b_val, t, expected, tol });
            }
        } else if (std.mem.startsWith(u8, func_name, "factorial") or std.mem.startsWith(u8, func_name, "test_factorial")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(factorial({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "gcd") or std.mem.startsWith(u8, func_name, "test_gcd")) {
            const a = extractIntParam(input, "a") orelse 0;
            const b_val = extractIntParam(input, "b") orelse 0;
            if (a != 0 or b_val != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(gcd({d}, {d}), {d});\n", .{ a, b_val, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "lcm") or std.mem.startsWith(u8, func_name, "test_lcm")) {
            const a = extractIntParam(input, "a") orelse 0;
            const b_val = extractIntParam(input, "b") orelse 0;
            if (a != 0 or b_val != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(lcm({d}, {d}), {d});\n", .{ a, b_val, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "digital_root") or std.mem.startsWith(u8, func_name, "test_digital_root")) {
            if (extractIntParam(input, "n")) |n| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(digital_root({d}), {d});\n", .{ n, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "trinity_power") or std.mem.startsWith(u8, func_name, "test_trinity_power")) {
            if (extractIntParam(input, "k")) |k| {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(trinity_power({d}), {d});\n", .{ k, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "golden_identity") or std.mem.startsWith(u8, func_name, "test_golden_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(golden_identity(), 3.0, 1e-10);");
        } else if (std.mem.startsWith(u8, func_name, "binomial") or std.mem.startsWith(u8, func_name, "test_binomial")) {
            const n = extractIntParam(input, "n") orelse 0;
            const k = extractIntParam(input, "k") orelse 0;
            if (n != 0) {
                if (parseU64(expected)) |exp_val| {
                    try self.builder.writeFmt("try std.testing.expectEqual(binomial({d}, {d}), {d});\n", .{ n, k, exp_val });
                }
            }
        } else if (std.mem.startsWith(u8, func_name, "sacred_formula") or std.mem.startsWith(u8, func_name, "test_sacred_formula")) {
            const n = extractFloatParam(input, "n") orelse 1.0;
            const k = extractFloatParam(input, "k") orelse 0.0;
            const m = extractFloatParam(input, "m") orelse 0.0;
            const p = extractFloatParam(input, "p") orelse 0.0;
            const q = extractFloatParam(input, "q") orelse 0.0;
            const tol = tc.tolerance orelse 1e-6;
            try self.builder.writeFmt("try std.testing.expectApproxEqAbs(sacred_formula({d}, {d}, {d}, {d}, {d}), {s}, {d});\n", .{ n, k, m, p, q, expected, tol });
        } else if (std.mem.startsWith(u8, func_name, "trit_and") or std.mem.startsWith(u8, func_name, "test_trit_and")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .negative), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .positive), .positive);");
        } else if (std.mem.startsWith(u8, func_name, "trit_or") or std.mem.startsWith(u8, func_name, "test_trit_or")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.positive, .negative), .positive);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .negative), .negative);");
        } else if (std.mem.startsWith(u8, func_name, "trit_not") or std.mem.startsWith(u8, func_name, "test_trit_not")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.positive), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.zero), .zero);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.negative), .positive);");
        } else if (std.mem.startsWith(u8, func_name, "verify_trinity") or std.mem.startsWith(u8, func_name, "test_verify_trinity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else {
            // Неизвестный тест - генерируем комментарий
            try self.builder.writeFmt("// Test case: input={s}, expected={s}\n", .{ input, expected });
        }
    }

    fn generateKnownTestAssertion(self: *Self, name: []const u8) !void {
        if (std.mem.eql(u8, name, "trinity_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_zero")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(0), 1.0, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_one")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(1), PHI, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_negative")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(-1), PHI_INV, 1e-10);");
        } else if (std.mem.eql(u8, name, "phi_power_squared")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(phi_power(2), PHI_SQ, 1e-10);");
        } else if (std.mem.eql(u8, name, "fibonacci_base_cases")) {
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(0), 0);");
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(1), 1);");
        } else if (std.mem.eql(u8, name, "fibonacci_sequence")) {
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(10), 55);");
            try self.builder.writeLine("try std.testing.expectEqual(fibonacci(20), 6765);");
        } else if (std.mem.eql(u8, name, "lucas_base_cases")) {
            try self.builder.writeLine("try std.testing.expectEqual(lucas(0), 2);");
            try self.builder.writeLine("try std.testing.expectEqual(lucas(1), 1);");
        } else if (std.mem.eql(u8, name, "lucas_sequence")) {
            try self.builder.writeLine("try std.testing.expectEqual(lucas(10), 123);");
        } else if (std.mem.eql(u8, name, "factorial_base") or std.mem.eql(u8, name, "test_factorial")) {
            try self.builder.writeLine("try std.testing.expectEqual(factorial(0), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(1), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(5), 120);");
            try self.builder.writeLine("try std.testing.expectEqual(factorial(10), 3628800);");
        } else if (std.mem.eql(u8, name, "gcd_test") or std.mem.eql(u8, name, "test_gcd")) {
            try self.builder.writeLine("try std.testing.expectEqual(gcd(999, 27), 27);");
            try self.builder.writeLine("try std.testing.expectEqual(gcd(48, 18), 6);");
            try self.builder.writeLine("try std.testing.expectEqual(gcd(17, 13), 1);");
        } else if (std.mem.eql(u8, name, "lcm_test") or std.mem.eql(u8, name, "test_lcm")) {
            try self.builder.writeLine("try std.testing.expectEqual(lcm(4, 6), 12);");
            try self.builder.writeLine("try std.testing.expectEqual(lcm(3, 9), 9);");
        } else if (std.mem.eql(u8, name, "digital_root_test") or std.mem.eql(u8, name, "test_digital_root")) {
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(999), 9);");
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(27), 9);");
            try self.builder.writeLine("try std.testing.expectEqual(digital_root(123), 6);");
        } else if (std.mem.eql(u8, name, "trinity_power_test") or std.mem.eql(u8, name, "test_trinity_power")) {
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(0), 1);");
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(3), 27);");
            try self.builder.writeLine("try std.testing.expectEqual(trinity_power(9), 19683);");
        } else if (std.mem.eql(u8, name, "golden_identity_test") or std.mem.eql(u8, name, "test_golden_identity")) {
            try self.builder.writeLine("try std.testing.expectApproxEqAbs(golden_identity(), 3.0, 1e-10);");
        } else if (std.mem.eql(u8, name, "binomial_test") or std.mem.eql(u8, name, "test_binomial")) {
            try self.builder.writeLine("try std.testing.expectEqual(binomial(5, 2), 10);");
            try self.builder.writeLine("try std.testing.expectEqual(binomial(10, 3), 120);");
        } else if (std.mem.eql(u8, name, "trit_and_test") or std.mem.eql(u8, name, "test_trit_and")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .negative), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_and(.positive, .positive), .positive);");
        } else if (std.mem.eql(u8, name, "trit_or_test") or std.mem.eql(u8, name, "test_trit_or")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.positive, .negative), .positive);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_or(.negative, .negative), .negative);");
        } else if (std.mem.eql(u8, name, "trit_not_test") or std.mem.eql(u8, name, "test_trit_not")) {
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.positive), .negative);");
            try self.builder.writeLine("try std.testing.expectEqual(Trit.trit_not(.zero), .zero);");
        } else {
            try self.builder.writeLine("// TODO: Add test assertions");
        }
    }

    fn stripQuotes(value: []const u8) []const u8 {
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
            return value[1 .. value.len - 1];
        }
        return value;
    }

    fn parseU64(value: []const u8) ?u64 {
        const trimmed = std.mem.trim(u8, value, " \t");
        return std.fmt.parseInt(u64, trimmed, 10) catch null;
    }

    fn parseF64(value: []const u8) ?f64 {
        const trimmed = std.mem.trim(u8, value, " \t");
        return std.fmt.parseFloat(f64, trimmed) catch null;
    }

    fn extractNumber(value: []const u8) []const u8 {
        // Извлекаем только число из строки типа "65.47  # comment"
        var end: usize = 0;
        // Пропускаем начальные пробелы
        var start: usize = 0;
        while (start < value.len and (value[start] == ' ' or value[start] == '\t')) {
            start += 1;
        }
        end = start;
        // Читаем число (может быть отрицательным, с точкой)
        if (end < value.len and value[end] == '-') {
            end += 1;
        }
        while (end < value.len and ((value[end] >= '0' and value[end] <= '9') or value[end] == '.')) {
            end += 1;
        }
        if (end > start) {
            return value[start..end];
        }
        return value;
    }

    fn extractIntParam(input: []const u8, param: []const u8) ?i32 {
        // Ищем "param: value" в строке типа "{ n: 0 }"
        var search_buf: [64]u8 = undefined;
        const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

        if (std.mem.indexOf(u8, input, search)) |idx| {
            var start = idx + search.len;
            // Пропускаем пробелы
            while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
                start += 1;
            }
            // Читаем число (может быть отрицательным)
            var end = start;
            if (end < input.len and input[end] == '-') {
                end += 1;
            }
            while (end < input.len and input[end] >= '0' and input[end] <= '9') {
                end += 1;
            }
            if (end > start) {
                return std.fmt.parseInt(i32, input[start..end], 10) catch null;
            }
        }
        return null;
    }

    fn extractFloatParam(input: []const u8, param: []const u8) ?f64 {
        var search_buf: [64]u8 = undefined;
        const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

        if (std.mem.indexOf(u8, input, search)) |idx| {
            var start = idx + search.len;
            while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
                start += 1;
            }
            var end = start;
            if (end < input.len and input[end] == '-') {
                end += 1;
            }
            while (end < input.len and ((input[end] >= '0' and input[end] <= '9') or input[end] == '.')) {
                end += 1;
            }
            if (end > start) {
                return std.fmt.parseFloat(f64, input[start..end]) catch null;
            }
        }
        return null;
    }

    fn escapeReservedWord(name: []const u8) []const u8 {
        // Zig reserved words that might appear as field names
        if (std.mem.eql(u8, name, "error")) return "@\"error\"";
        if (std.mem.eql(u8, name, "type")) return "@\"type\"";
        if (std.mem.eql(u8, name, "return")) return "@\"return\"";
        if (std.mem.eql(u8, name, "break")) return "@\"break\"";
        if (std.mem.eql(u8, name, "continue")) return "@\"continue\"";
        if (std.mem.eql(u8, name, "if")) return "@\"if\"";
        if (std.mem.eql(u8, name, "else")) return "@\"else\"";
        if (std.mem.eql(u8, name, "while")) return "@\"while\"";
        if (std.mem.eql(u8, name, "for")) return "@\"for\"";
        if (std.mem.eql(u8, name, "fn")) return "@\"fn\"";
        if (std.mem.eql(u8, name, "const")) return "@\"const\"";
        if (std.mem.eql(u8, name, "var")) return "@\"var\"";
        if (std.mem.eql(u8, name, "pub")) return "@\"pub\"";
        if (std.mem.eql(u8, name, "try")) return "@\"try\"";
        if (std.mem.eql(u8, name, "catch")) return "@\"catch\"";
        return name;
    }

    fn cleanTypeName(type_name: []const u8) []const u8 {
        var result = type_name;

        // Remove comments (# ...)
        if (std.mem.indexOf(u8, result, "#")) |pos| {
            result = result[0..pos];
        }

        // Remove default values (= "...")
        if (std.mem.indexOf(u8, result, "=")) |pos| {
            result = result[0..pos];
        }

        // Handle union types (A | B) -> use first type
        if (std.mem.indexOf(u8, result, "|")) |pos| {
            result = result[0..pos];
        }

        return std.mem.trim(u8, result, " \t");
    }

    fn mapType(type_name: []const u8) []const u8 {
        // Primitive types
        if (std.mem.eql(u8, type_name, "f64")) return "f64";
        if (std.mem.eql(u8, type_name, "f32")) return "f32";
        if (std.mem.eql(u8, type_name, "i32")) return "i32";
        if (std.mem.eql(u8, type_name, "i64")) return "i64";
        if (std.mem.eql(u8, type_name, "u32")) return "u32";
        if (std.mem.eql(u8, type_name, "u64")) return "u64";
        if (std.mem.eql(u8, type_name, "bool")) return "bool";

        // VIBEE types -> Zig types
        if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Int")) return "i64";
        if (std.mem.eql(u8, type_name, "Float")) return "f64";
        if (std.mem.eql(u8, type_name, "Bool")) return "bool";
        if (std.mem.eql(u8, type_name, "Bytes")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Timestamp")) return "i64";
        if (std.mem.eql(u8, type_name, "Duration")) return "i64";
        if (std.mem.eql(u8, type_name, "Any")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Void")) return "void";
        if (std.mem.eql(u8, type_name, "Error")) return "anyerror";

        // Generic types Option<T> -> ?T
        if (std.mem.startsWith(u8, type_name, "Option<")) {
            return "?[]const u8"; // Simplified: Option<T> -> ?[]const u8
        }

        // Generic types List<T> -> []T
        if (std.mem.startsWith(u8, type_name, "List<")) {
            return "[]const u8"; // Simplified: List<T> -> slice
        }

        // Plain List type -> slice
        if (std.mem.eql(u8, type_name, "List")) {
            return "[]const u8";
        }

        // Generic types Map<K,V> -> std.StringHashMap
        if (std.mem.startsWith(u8, type_name, "Map<")) {
            return "std.StringHashMap([]const u8)";
        }

        // Plain Map type -> std.StringHashMap
        if (std.mem.eql(u8, type_name, "Map")) {
            return "std.StringHashMap([]const u8)";
        }

        // Handle trailing ? (nullable) - convert Type? to ?Type
        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            return "?[]const u8"; // Simplified
        }

        // Object type
        if (std.mem.eql(u8, type_name, "Object")) {
            return "[]const u8";
        }

        // Unknown complex types -> []const u8
        if (std.mem.eql(u8, type_name, "JsonSchema")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "Role")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "PluginManifest")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "PluginConfig")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "StreamEvent")) return "[]const u8";
        if (std.mem.eql(u8, type_name, "TokenStats")) return "[]const u8";

        return type_name;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateFromFile(allocator: Allocator, vibee_path: []const u8, output_path: []const u8) !void {
    // Читаем .vibee файл
    const file = try std.fs.cwd().openFile(vibee_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    // Парсим
    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    // Генерируем Zig код
    var codegen = ZigCodeGen.init(allocator);
    defer codegen.deinit();

    const output = try codegen.generate(&spec);

    // Записываем в файл
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    try out_file.writeAll(output);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "code builder" {
    var builder = CodeBuilder.init(std.testing.allocator);
    defer builder.deinit();

    try builder.writeLine("const x = 1;");
    try builder.writeLine("const y = 2;");

    const output = builder.getOutput();
    try std.testing.expect(output.len > 0);
}

test "generate empty spec" {
    var spec = VibeeSpec.init(std.testing.allocator);
    defer spec.deinit();

    spec.name = "test";
    spec.version = "1.0";
    spec.author = "Test";

    var codegen = ZigCodeGen.init(std.testing.allocator);
    defer codegen.deinit();

    const output = try codegen.generate(&spec);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "PHI") != null);
}
