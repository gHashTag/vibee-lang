// ═══════════════════════════════════════════════════════════════════════════════
// TRI CODEGEN - GENERATED FROM ⲧⲣⲓ_ⲕⲟⲇⲉⲅⲉⲛ.tri
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_parser = @import("tri_parser.zig");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: usize = 3;
pub const TRINITY_PRIME: usize = 33;

// ═══════════════════════════════════════════════════════════════════════════════
// ⲔⲞⲆⲈⲄⲈⲚ
// ═══════════════════════════════════════════════════════════════════════════════

pub const Codegen = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    indent_level: usize,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .indent_level = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }
    
    pub fn generate(self: *Self, doc: *const tri_parser.Document, source_file: []const u8) ![]const u8 {
        // Header
        try self.emitHeader(source_file);
        
        // Process entries
        for (doc.root.entries.items) |entry| {
            try self.processEntry(entry);
        }
        
        return self.output.items;
    }
    
    fn emitHeader(self: *Self, source_file: []const u8) !void {
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n");
        try self.emit("// GENERATED FROM ");
        try self.emit(source_file);
        try self.emit("\n");
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n");
        try self.emit("// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n");
        try self.emit("// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3\n");
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n\n");
        try self.emit("const std = @import(\"std\");\n\n");
    }
    
    fn processEntry(self: *Self, entry: tri_parser.MapEntry) !void {
        const key = entry.key;
        
        // ⲥⲁⲕⲣⲁ_ⲕⲟⲛⲥⲧⲁⲛⲧⲥ → pub const
        if (std.mem.indexOf(u8, key, "ⲥⲁⲕⲣⲁ") != null or 
            std.mem.indexOf(u8, key, "ⲕⲟⲛⲥⲧⲁⲛⲧⲥ") != null) {
            try self.emitSacredConstants();
            return;
        }
        
        // ⲥⲧⲣⲩⲕⲧ → struct
        if (std.mem.indexOf(u8, key, "ⲥⲧⲣⲩⲕⲧ") != null) {
            try self.emitStruct(key, entry.value);
            return;
        }
        
        // ⲉⲛⲩⲙ → enum
        if (std.mem.indexOf(u8, key, "ⲉⲛⲩⲙ") != null or
            std.mem.indexOf(u8, key, "ⲧⲓⲡⲩ") != null) {
            try self.emitEnum(key, entry.value);
            return;
        }
        
        // ⲧⲉⲥⲧ_ⲕⲁⲥⲉⲥ → test
        if (std.mem.indexOf(u8, key, "ⲧⲉⲥⲧ") != null) {
            try self.emitTests(entry.value);
            return;
        }
        
        // Default: emit as comment
        try self.emit("// ");
        try self.emit(key);
        try self.emit("\n");
    }
    
    fn emitSacredConstants(self: *Self) !void {
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n");
        try self.emit("// ⲤⲀⲔⲢⲀ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ\n");
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n\n");
        try self.emit("pub const PHI: f64 = 1.618033988749895;\n");
        try self.emit("pub const TRINITY: usize = 3;\n");
        try self.emit("pub const TRINITY_PRIME: usize = 33;\n");
        try self.emit("pub const PHOENIX: usize = 999;\n\n");
    }
    
    fn emitStruct(self: *Self, name: []const u8, value: tri_parser.ValueNode) !void {
        _ = value;
        try self.emit("pub const ");
        try self.emitZigName(name);
        try self.emit(" = struct {\n");
        self.indent_level += 1;
        
        // TODO: process fields from value
        try self.emitIndent();
        try self.emit("// Fields from .tri spec\n");
        
        self.indent_level -= 1;
        try self.emit("};\n\n");
    }
    
    fn emitEnum(self: *Self, name: []const u8, value: tri_parser.ValueNode) !void {
        _ = value;
        try self.emit("pub const ");
        try self.emitZigName(name);
        try self.emit(" = enum(u8) {\n");
        self.indent_level += 1;
        
        // TODO: process variants from value
        try self.emitIndent();
        try self.emit("// Variants from .tri spec\n");
        
        self.indent_level -= 1;
        try self.emit("};\n\n");
    }
    
    fn emitTests(self: *Self, value: tri_parser.ValueNode) !void {
        _ = value;
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n");
        try self.emit("// ⲦⲈⲤⲦⲤ\n");
        try self.emit("// ═══════════════════════════════════════════════════════════════════════════════\n\n");
        
        try self.emit("test \"ⲍⲟⲗⲟⲧⲁⲓⲁ_ⲓⲇⲉⲛⲧⲓⲭⲛⲟⲥⲧⲓ\" {\n");
        try self.emit("    const phi_sq = PHI * PHI;\n");
        try self.emit("    const inv_phi_sq = 1.0 / phi_sq;\n");
        try self.emit("    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);\n");
        try self.emit("}\n\n");
    }
    
    fn emitZigName(self: *Self, coptic_name: []const u8) !void {
        // Convert Coptic to ASCII for Zig identifier
        var i: usize = 0;
        while (i < coptic_name.len) {
            const c = coptic_name[i];
            if (c < 0x80) {
                try self.output.append(c);
                i += 1;
            } else {
                // Skip UTF-8 multi-byte sequences, emit underscore
                while (i < coptic_name.len and coptic_name[i] >= 0x80) {
                    i += 1;
                }
                try self.output.append('_');
            }
        }
    }
    
    fn emitIndent(self: *Self) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.emit("    ");
        }
    }
    
    fn emit(self: *Self, s: []const u8) !void {
        try self.output.appendSlice(s);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ⲦⲈⲤⲦⲤ
// ═══════════════════════════════════════════════════════════════════════════════

test "ⲍⲟⲗⲟⲧⲁⲓⲁ_ⲓⲇⲉⲛⲧⲓⲭⲛⲟⲥⲧⲓ" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "ⲕⲟⲇⲉⲅⲉⲛ_ⲓⲛⲓⲧ" {
    var codegen = Codegen.init(std.testing.allocator);
    defer codegen.deinit();
    try std.testing.expectEqual(@as(usize, 0), codegen.output.items.len);
}

test "ⲕⲟⲇⲉⲅⲉⲛ_ⲏⲉⲁⲇⲉⲣ" {
    var codegen = Codegen.init(std.testing.allocator);
    defer codegen.deinit();
    try codegen.emitHeader("test.tri");
    try std.testing.expect(codegen.output.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, codegen.output.items, "GENERATED FROM") != null);
}
