// ═══════════════════════════════════════════════════════════════════════════════
// TRI GENERATOR - ПОЛНЫЙ ГЕНЕРАТОР .tri → .zig
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_parser = @import("tri_parser.zig");
const tri_codegen = @import("tri_codegen.zig");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: usize = 3;

// ═══════════════════════════════════════════════════════════════════════════════
// ⲄⲈⲚⲈⲢⲀⲦⲞⲢ
// ═══════════════════════════════════════════════════════════════════════════════

pub const Generator = struct {
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
    files_generated: usize,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, input_dir: []const u8, output_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .input_dir = input_dir,
            .output_dir = output_dir,
            .files_generated = 0,
        };
    }
    
    pub fn generateAll(self: *Self) !void {
        var dir = try std.fs.cwd().openDir(self.input_dir, .{ .iterate = true });
        defer dir.close();
        
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const name = entry.name;
                if (std.mem.endsWith(u8, name, ".tri")) {
                    try self.generateFile(name);
                }
            }
        }
    }
    
    pub fn generateFile(self: *Self, filename: []const u8) !void {
        // Read .tri file
        const input_path = try std.fs.path.join(self.allocator, &.{ self.input_dir, filename });
        defer self.allocator.free(input_path);
        
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();
        
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);
        
        // Parse
        var parser = tri_parser.Parser.init(self.allocator, content);
        var doc = try parser.parse();
        defer doc.deinit();
        
        // Generate
        var codegen = tri_codegen.Codegen.init(self.allocator);
        defer codegen.deinit();
        
        const output = try codegen.generate(&doc, filename);
        
        // Write .zig file
        const base_name = filename[0 .. filename.len - 4]; // remove .tri
        const output_filename = try std.fmt.allocPrint(self.allocator, "{s}.zig", .{base_name});
        defer self.allocator.free(output_filename);
        
        const output_path = try std.fs.path.join(self.allocator, &.{ self.output_dir, output_filename });
        defer self.allocator.free(output_path);
        
        const out_file = try std.fs.cwd().createFile(output_path, .{});
        defer out_file.close();
        
        try out_file.writeAll(output);
        
        self.files_generated += 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ⲘⲀⲒⲚ
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const input_dir = if (args.len > 1) args[1] else ".";
    const output_dir = if (args.len > 2) args[2] else "output";
    
    var generator = Generator.init(allocator, input_dir, output_dir);
    try generator.generateAll();
    
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Generated {d} files\n", .{generator.files_generated});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ⲦⲈⲤⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

test "ⲍⲟⲗⲟⲧⲁⲓⲁ_ⲓⲇⲉⲛⲧⲓⲭⲛⲟⲥⲧⲓ" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "ⲅⲉⲛⲉⲣⲁⲧⲟⲣ_ⲓⲛⲓⲧ" {
    const generator = Generator.init(std.testing.allocator, ".", "output");
    try std.testing.expectEqual(@as(usize, 0), generator.files_generated);
}
