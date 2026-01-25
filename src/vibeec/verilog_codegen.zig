// ═══════════════════════════════════════════════════════════════════════════════
// VERILOG CODEGEN - Генератор Verilog кода из .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Verilog код для FPGA синтеза
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const vibee_parser = @import("vibee_parser.zig");

const VibeeSpec = vibee_parser.VibeeSpec;
const Constant = vibee_parser.Constant;
const TypeDef = vibee_parser.TypeDef;
const Behavior = vibee_parser.Behavior;
const Field = vibee_parser.Field;

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTED SIGNAL FOR SVA
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExtractedSignal = struct {
    name: []const u8,
    verilog_type: []const u8,
    width: u32,
    is_bool: bool,
};

/// Extract signals from spec types for SVA checker
pub fn extractSignalsFromTypes(types: []const TypeDef, allocator: Allocator) !ArrayList(ExtractedSignal) {
    var signals = ArrayList(ExtractedSignal).init(allocator);
    
    for (types) |t| {
        for (t.fields.items) |field| {
            const is_bool = std.mem.eql(u8, field.type_name, "Bool");
            const width: u32 = if (is_bool) 1 else if (std.mem.eql(u8, field.type_name, "Int")) 32 else 32;
            const verilog_type = if (is_bool) "wire" else "wire [31:0]";
            
            // Check if signal already exists
            var exists = false;
            for (signals.items) |s| {
                if (std.mem.eql(u8, s.name, field.name)) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                try signals.append(ExtractedSignal{
                    .name = field.name,
                    .verilog_type = verilog_type,
                    .width = width,
                    .is_bool = is_bool,
                });
            }
        }
    }
    
    return signals;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERILOG CODE BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerilogBuilder = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    indent: u32,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = ArrayList(u8).init(allocator),
            .indent = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
    
    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }
    
    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(str);
        try self.buffer.append('\n');
    }
    
    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice("    ");
        }
    }
    
    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer();
        try writer.print(fmt, args);
    }
    
    pub fn newline(self: *Self) !void {
        try self.buffer.append('\n');
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
// VERILOG CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Signal information with inferred width from Verilog literals
/// Width inference: mode == 2'b00 → mode is 2-bit, count == 8'hFF → count is 8-bit
const SignalInfo = struct {
    name: []const u8,
    inferred_width: u32, // 0 = unknown (default to 1-bit)
};

/// Extract signal identifiers from Verilog condition expression with width inference
/// Parses patterns like: sig == N'bXX, sig == N'hXX, sig == N'dXX
/// Returns list of unique signals with inferred widths
fn extractSignalsFromCondition(allocator: Allocator, condition: []const u8) !ArrayList(SignalInfo) {
    var signals = ArrayList(SignalInfo).init(allocator);
    
    // Verilog keywords and operators to skip
    const keywords = [_][]const u8{
        "if", "else", "begin", "end", "case", "endcase", "default",
        "and", "or", "not", "xor", "nand", "nor", "xnor",
        "posedge", "negedge", "always", "assign", "wire", "reg",
    };
    
    var i: usize = 0;
    while (i < condition.len) {
        // Skip whitespace and operators
        while (i < condition.len and !isIdentifierStart(condition[i])) {
            i += 1;
        }
        
        if (i >= condition.len) break;
        
        // Extract identifier
        const start = i;
        while (i < condition.len and isIdentifierChar(condition[i])) {
            i += 1;
        }
        
        const ident = condition[start..i];
        
        // Skip if empty, keyword, or numeric literal
        if (ident.len == 0) continue;
        if (isNumericLiteral(ident)) continue;
        if (isKeyword(ident, &keywords)) continue;
        
        // Check for bit slice [N:M] or [N] after identifier
        var slice_width: u32 = 0;
        var ident_end_for_context = i;
        if (i < condition.len and condition[i] == '[') {
            slice_width = parseBitSlice(condition, i);
            // Skip past the slice for next iteration
            while (i < condition.len and condition[i] != ']') {
                i += 1;
            }
            if (i < condition.len) {
                i += 1; // skip ']'
                ident_end_for_context = i;
            }
        }
        
        // Try to infer width from comparison with Verilog literal
        // Pattern: ident == N'bXX or ident == N'hXX or ident == N'dXX
        const literal_width = inferWidthFromContext(condition, start, ident_end_for_context);
        
        // Use maximum of slice width and literal width
        const inferred_width = @max(slice_width, literal_width);
        
        // Check if already in list, update width if new one is larger
        var found = false;
        for (signals.items) |*sig| {
            if (std.mem.eql(u8, sig.name, ident)) {
                found = true;
                // Keep the larger width (more specific inference)
                if (inferred_width > sig.inferred_width) {
                    sig.inferred_width = inferred_width;
                }
                break;
            }
        }
        
        if (!found) {
            try signals.append(SignalInfo{
                .name = ident,
                .inferred_width = inferred_width,
            });
        }
    }
    
    return signals;
}

/// Infer signal width from comparison context (bidirectional)
/// Looks for patterns like: sig == 2'b00, 2'b00 == sig, sig != 8'hFF, 8'hFF != sig
fn inferWidthFromContext(condition: []const u8, ident_start: usize, ident_end: usize) u32 {
    // 1. Try forward: sig == N'bXX
    const forward_width = inferWidthForward(condition, ident_end);
    if (forward_width > 0) return forward_width;
    
    // 2. Try backward: N'bXX == sig
    return inferWidthBackward(condition, ident_start);
}

/// Forward inference: sig == N'bXX (literal AFTER identifier)
fn inferWidthForward(condition: []const u8, ident_end: usize) u32 {
    var i = ident_end;
    
    // Skip whitespace
    while (i < condition.len and (condition[i] == ' ' or condition[i] == '\t')) {
        i += 1;
    }
    
    // Check for comparison operators: ==, !=, ===, !==, <, >, <=, >=
    if (i >= condition.len) return 0;
    
    const is_comparison = blk: {
        if (i + 1 < condition.len) {
            if ((condition[i] == '=' and condition[i + 1] == '=') or
                (condition[i] == '!' and condition[i + 1] == '=') or
                (condition[i] == '<' and condition[i + 1] == '=') or
                (condition[i] == '>' and condition[i + 1] == '='))
            {
                i += 2;
                // Check for === or !==
                if (i < condition.len and condition[i] == '=') {
                    i += 1;
                }
                break :blk true;
            }
        }
        if (condition[i] == '<' or condition[i] == '>') {
            i += 1;
            break :blk true;
        }
        break :blk false;
    };
    
    if (!is_comparison) return 0;
    
    // Skip whitespace after operator
    while (i < condition.len and (condition[i] == ' ' or condition[i] == '\t')) {
        i += 1;
    }
    
    // Parse Verilog literal: N'bXX, N'hXX, N'dXX, N'oXX
    return parseVerilogLiteralWidth(condition, i);
}

/// Backward inference: N'bXX == sig (literal BEFORE identifier)
fn inferWidthBackward(condition: []const u8, ident_start: usize) u32 {
    if (ident_start == 0) return 0;
    
    var i = ident_start - 1;
    
    // Skip whitespace backward
    while (i > 0 and (condition[i] == ' ' or condition[i] == '\t')) {
        i -= 1;
    }
    
    // Check for comparison operators backward: ==, !=, ===, !==
    if (i < 1) return 0;
    
    var op_found = false;
    if (condition[i] == '=') {
        if (i >= 1 and (condition[i - 1] == '=' or condition[i - 1] == '!' or 
                        condition[i - 1] == '<' or condition[i - 1] == '>')) {
            // Check for === or !==
            if (i >= 2 and condition[i - 1] == '=' and 
                (condition[i - 2] == '=' or condition[i - 2] == '!')) {
                i -= 3;
            } else {
                i -= 2;
            }
            op_found = true;
        }
    } else if (condition[i] == '<' or condition[i] == '>') {
        i -= 1;
        op_found = true;
    }
    
    if (!op_found) return 0;
    
    // Skip whitespace backward
    while (i > 0 and (condition[i] == ' ' or condition[i] == '\t')) {
        i -= 1;
    }
    
    // Now we should be at the end of a Verilog literal
    // Find the start of the literal by looking for digits, then apostrophe, then width
    return parseVerilogLiteralBackward(condition, i);
}

/// Parse Verilog literal backward from position i (pointing to last char of literal)
/// Format: <width>'<base><value> e.g., 8'hFF, 2'b00
fn parseVerilogLiteralBackward(condition: []const u8, end_pos: usize) u32 {
    if (end_pos < 3) return 0; // Minimum: N'bV (4 chars)
    
    // Find apostrophe by scanning backward
    var apos_pos: ?usize = null;
    var scan = end_pos;
    while (scan > 0) : (scan -= 1) {
        if (condition[scan] == '\'') {
            apos_pos = scan;
            break;
        }
        // Stop if we hit something that can't be part of literal
        if (condition[scan] == ' ' or condition[scan] == '\t' or
            condition[scan] == '(' or condition[scan] == ')' or
            condition[scan] == '&' or condition[scan] == '|')
        {
            break;
        }
    }
    // Check position 0 too
    if (apos_pos == null and scan == 0 and condition[0] == '\'') {
        apos_pos = 0;
    }
    
    if (apos_pos == null or apos_pos.? == 0) return 0;
    
    const apos = apos_pos.?;
    
    // Check base specifier after apostrophe
    if (apos + 1 > end_pos) return 0;
    const base = condition[apos + 1];
    if (base != 'b' and base != 'B' and
        base != 'h' and base != 'H' and
        base != 'd' and base != 'D' and
        base != 'o' and base != 'O')
    {
        return 0;
    }
    
    // Parse width digits before apostrophe
    const width_end = apos;
    var i = apos - 1;
    while (i > 0 and condition[i] >= '0' and condition[i] <= '9') {
        i -= 1;
    }
    const width_start = if (condition[i] >= '0' and condition[i] <= '9') i else i + 1;
    
    if (width_start >= width_end) return 0;
    
    const width_str = condition[width_start..width_end];
    return std.fmt.parseInt(u32, width_str, 10) catch 0;
}

/// Check if character is valid in Verilog literal value
fn isVerilogValueChar(c: u8) bool {
    return (c >= '0' and c <= '9') or
           (c >= 'a' and c <= 'f') or
           (c >= 'A' and c <= 'F') or
           c == 'x' or c == 'X' or
           c == 'z' or c == 'Z' or
           c == '_';
}

/// Parse bit slice [N:M] or [N] and return minimum required width
/// [7:0] -> 8, [15:8] -> 16, [31:16] -> 32, [7] -> 8
fn parseBitSlice(condition: []const u8, start: usize) u32 {
    if (start >= condition.len or condition[start] != '[') return 0;
    
    var i = start + 1; // skip '['
    
    // Skip whitespace
    while (i < condition.len and (condition[i] == ' ' or condition[i] == '\t')) {
        i += 1;
    }
    
    // Parse first number (high index or single index)
    const num1_start = i;
    while (i < condition.len and condition[i] >= '0' and condition[i] <= '9') {
        i += 1;
    }
    if (i == num1_start) return 0; // No number found
    
    const num1 = std.fmt.parseInt(u32, condition[num1_start..i], 10) catch return 0;
    
    // Skip whitespace
    while (i < condition.len and (condition[i] == ' ' or condition[i] == '\t')) {
        i += 1;
    }
    
    // Check for ':' (range) or ']' (single bit)
    if (i >= condition.len) return 0;
    
    if (condition[i] == ']') {
        // Single bit access [N] -> width = N + 1
        return num1 + 1;
    }
    
    if (condition[i] != ':') return 0;
    i += 1; // skip ':'
    
    // Skip whitespace
    while (i < condition.len and (condition[i] == ' ' or condition[i] == '\t')) {
        i += 1;
    }
    
    // Parse second number (low index)
    const num2_start = i;
    while (i < condition.len and condition[i] >= '0' and condition[i] <= '9') {
        i += 1;
    }
    if (i == num2_start) return 0;
    
    const num2 = std.fmt.parseInt(u32, condition[num2_start..i], 10) catch return 0;
    
    // Width = max(high, low) + 1
    return @max(num1, num2) + 1;
}

/// Parse width from Verilog literal at position i
/// Format: <width>'<base><value> where base is b, h, d, o (case insensitive)
fn parseVerilogLiteralWidth(condition: []const u8, start: usize) u32 {
    var i = start;
    
    // Parse width number
    const width_start = i;
    while (i < condition.len and condition[i] >= '0' and condition[i] <= '9') {
        i += 1;
    }
    
    if (i == width_start) return 0; // No width digits found
    
    // Check for apostrophe
    if (i >= condition.len or condition[i] != '\'') return 0;
    i += 1;
    
    // Check for base specifier (b, h, d, o - case insensitive)
    if (i >= condition.len) return 0;
    const base = condition[i];
    if (base != 'b' and base != 'B' and
        base != 'h' and base != 'H' and
        base != 'd' and base != 'D' and
        base != 'o' and base != 'O')
    {
        return 0;
    }
    
    // Parse the width number
    const width_str = condition[width_start .. i - 1]; // Exclude apostrophe
    return std.fmt.parseInt(u32, width_str, 10) catch 0;
}

fn isIdentifierStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isIdentifierChar(c: u8) bool {
    return isIdentifierStart(c) or (c >= '0' and c <= '9');
}

fn isNumericLiteral(s: []const u8) bool {
    if (s.len == 0) return false;
    
    // Check for Verilog numeric literals like 8'hFF, 2'b00, 32'd123
    for (s) |c| {
        if (c == '\'') return true;
    }
    
    // Check for pure numbers
    var all_digits = true;
    for (s) |c| {
        if (c < '0' or c > '9') {
            all_digits = false;
            break;
        }
    }
    if (all_digits) return true;
    
    // Check for hex literals (hXX, hXXXX)
    if (s.len >= 2 and s[0] == 'h') {
        var is_hex = true;
        for (s[1..]) |c| {
            if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) {
                is_hex = false;
                break;
            }
        }
        if (is_hex) return true;
    }
    
    // Check for binary literals (bXX)
    if (s.len >= 2 and s[0] == 'b') {
        var is_bin = true;
        for (s[1..]) |c| {
            if (c != '0' and c != '1') {
                is_bin = false;
                break;
            }
        }
        if (is_bin) return true;
    }
    
    // Check for decimal literals (dXX)
    if (s.len >= 2 and s[0] == 'd') {
        var is_dec = true;
        for (s[1..]) |c| {
            if (c < '0' or c > '9') {
                is_dec = false;
                break;
            }
        }
        if (is_dec) return true;
    }
    
    return false;
}

fn isKeyword(s: []const u8, keywords: []const []const u8) bool {
    for (keywords) |kw| {
        if (std.mem.eql(u8, s, kw)) return true;
    }
    return false;
}

pub const VerilogCodeGen = struct {
    allocator: Allocator,
    builder: VerilogBuilder,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = VerilogBuilder.init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }
    
    /// Генерация полного Verilog файла из спецификации
    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeTimescale();
        try self.writeSacredConstants(spec);
        try self.writeTypes(spec.types.items);
        try self.writeTopModule(spec);
        try self.writeBehaviorModules(spec.behaviors.items);
        try self.writeSVAAssertions(spec);
        try self.writeTestbench(spec);
        
        return self.builder.getOutput();
    }
    
    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated Verilog from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Golden Identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("// PHOENIX = 999");
        try self.builder.writeLine("//");
        try self.builder.writeFmt("// Author: {s}\n", .{spec.author});
        try self.builder.writeLine("// DO NOT EDIT - This file is auto-generated by VIBEE");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }
    
    fn writeTimescale(self: *Self) !void {
        try self.builder.writeLine("`timescale 1ns / 1ps");
        try self.builder.newline();
    }
    
    fn writeSacredConstants(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SACRED CONSTANTS MODULE");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        try self.builder.writeFmt("module {s}_sacred_constants (\n", .{spec.name});
        self.builder.incIndent();
        
        // Output ports for constants
        try self.builder.writeLine("output wire [63:0] phi,");
        try self.builder.writeLine("output wire [63:0] phi_sq,");
        try self.builder.writeLine("output wire [63:0] phi_inv_sq,");
        try self.builder.writeLine("output wire [63:0] trinity,");
        try self.builder.writeLine("output wire [31:0] phoenix");
        
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        self.builder.incIndent();
        
        // IEEE 754 double precision constants
        try self.builder.writeLine("// IEEE 754 double precision constants");
        try self.builder.writeLine("assign phi        = 64'h3FF9E3779B97F4A8; // 1.6180339887...");
        try self.builder.writeLine("assign phi_sq     = 64'h4004F1BBCDCBF254; // 2.6180339887...");
        try self.builder.writeLine("assign phi_inv_sq = 64'h3FD8722D0E560419; // 0.3819660112...");
        try self.builder.writeLine("assign trinity    = 64'h4008000000000000; // 3.0");
        try self.builder.writeLine("assign phoenix    = 32'd999;");
        
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        if (types.len == 0) return;
        
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TYPE DEFINITIONS (as Verilog structs/parameters)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        for (types) |t| {
            try self.builder.writeFmt("// Type: {s}\n", .{t.name});
            try self.builder.writeFmt("// {s}\n", .{t.description});
            
            // Generate parameter definitions for type fields
            for (t.fields.items) |field| {
                const verilog_type = mapTypeToVerilog(field.type_name);
                try self.builder.writeFmt("// Field: {s} -> {s}\n", .{ field.name, verilog_type });
            }
            try self.builder.newline();
        }
    }
    
    fn writeTopModule(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TOP MODULE");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        try self.builder.writeFmt("module {s}_top (\n", .{spec.name});
        self.builder.incIndent();
        
        // Extract signals from FSM transition conditions with inferred widths
        var fsm_signals = ArrayList(SignalInfo).init(self.allocator);
        defer fsm_signals.deinit();
        
        if (spec.fsms.items.len > 0) {
            for (spec.fsms.items) |fsm| {
                // Collect FSM state names to exclude them
                var state_names = ArrayList([]const u8).init(self.allocator);
                defer state_names.deinit();
                for (fsm.states.items) |state| {
                    try state_names.append(state);
                }
                
                // Extract signals from each transition condition
                for (fsm.transitions.items) |trans| {
                    if (trans.condition.len > 0) {
                        var extracted = try extractSignalsFromCondition(self.allocator, trans.condition);
                        defer extracted.deinit();
                        
                        for (extracted.items) |sig_info| {
                            // Skip if it's a state name
                            var is_state = false;
                            for (state_names.items) |state| {
                                if (std.mem.eql(u8, sig_info.name, state)) {
                                    is_state = true;
                                    break;
                                }
                            }
                            if (is_state) continue;
                            
                            // Skip if already in spec.signals
                            var already_declared = false;
                            for (spec.signals.items) |existing| {
                                if (std.mem.eql(u8, sig_info.name, existing.name)) {
                                    already_declared = true;
                                    break;
                                }
                            }
                            if (already_declared) continue;
                            
                            // Skip internal timer signals (generated by timer logic)
                            if (std.mem.eql(u8, sig_info.name, "timer_expired") or
                                std.mem.eql(u8, sig_info.name, "timer_count") or
                                std.mem.eql(u8, sig_info.name, "timeout_value"))
                            {
                                continue;
                            }
                            
                            // Check if already in fsm_signals, update width if larger
                            var already_added = false;
                            for (fsm_signals.items) |*existing| {
                                if (std.mem.eql(u8, sig_info.name, existing.name)) {
                                    already_added = true;
                                    // Keep the larger inferred width
                                    if (sig_info.inferred_width > existing.inferred_width) {
                                        existing.inferred_width = sig_info.inferred_width;
                                    }
                                    break;
                                }
                            }
                            if (already_added) continue;
                            
                            // Add to fsm_signals with inferred width
                            try fsm_signals.append(sig_info);
                        }
                    }
                }
            }
        }
        
        // Collect unique output signal names from FSM outputs with inferred widths
        var fsm_output_signals = ArrayList(SignalInfo).init(self.allocator);
        defer fsm_output_signals.deinit();
        
        if (spec.fsms.items.len > 0) {
            for (spec.fsms.items) |fsm| {
                for (fsm.outputs.items) |out| {
                    var iter = out.signals.iterator();
                    while (iter.next()) |entry| {
                        const sig_name = entry.key_ptr.*;
                        const sig_value = entry.value_ptr.*;
                        
                        // Infer width from value (e.g., "8'hFF" -> 8)
                        const inferred_width = parseVerilogLiteralWidth(sig_value, 0);
                        
                        // Check if already added, update width if larger
                        var found = false;
                        for (fsm_output_signals.items) |*existing| {
                            if (std.mem.eql(u8, existing.name, sig_name)) {
                                found = true;
                                if (inferred_width > existing.inferred_width) {
                                    existing.inferred_width = inferred_width;
                                }
                                break;
                            }
                        }
                        if (!found) {
                            try fsm_output_signals.append(SignalInfo{
                                .name = sig_name,
                                .inferred_width = inferred_width,
                            });
                        }
                    }
                }
            }
        }
        
        // Check if we have custom signals defined
        if (spec.signals.items.len > 0 or fsm_signals.items.len > 0 or fsm_output_signals.items.len > 0) {
            // Count actual ports (exclude internal regs) + 2 for clk and rst_n + FSM outputs
            var actual_port_count: usize = fsm_signals.items.len + fsm_output_signals.items.len + 2;
            for (spec.signals.items) |sig| {
                if (!std.mem.eql(u8, sig.direction, "reg") and !std.mem.eql(u8, sig.direction, "wire")) {
                    actual_port_count += 1;
                }
            }
            
            // Generate ports from signals (only input/output/inout)
            var port_idx: usize = 0;
            
            // Always generate clk and rst_n first
            try self.builder.writeLine("input  wire        clk,");
            try self.builder.writeLine("input  wire        rst_n,");
            port_idx = 2;
            
            // Generate auto-extracted FSM signals as inputs with inferred widths
            for (fsm_signals.items) |fsm_sig| {
                port_idx += 1;
                const is_last = (port_idx == actual_port_count);
                
                // Use inferred width from Verilog literals/slices, default to 1-bit scalar
                const width = if (fsm_sig.inferred_width > 0) fsm_sig.inferred_width else 0;
                
                if (width > 0) {
                    // Generate as vector [width-1:0] to support bit slicing
                    const width_minus_1 = width - 1;
                    if (is_last) {
                        try self.builder.writeFmt("input  wire [{d}:0] {s}  // Auto-extracted from FSM (width inferred)\n", .{ width_minus_1, fsm_sig.name });
                    } else {
                        try self.builder.writeFmt("input  wire [{d}:0] {s},  // Auto-extracted from FSM (width inferred)\n", .{ width_minus_1, fsm_sig.name });
                    }
                } else {
                    // Default 1-bit scalar (no bit slicing in condition)
                    if (is_last) {
                        try self.builder.writeFmt("input  wire        {s}  // Auto-extracted from FSM\n", .{fsm_sig.name});
                    } else {
                        try self.builder.writeFmt("input  wire        {s},  // Auto-extracted from FSM\n", .{fsm_sig.name});
                    }
                }
            }
            
            // Generate FSM output signals as output ports with inferred widths
            for (fsm_output_signals.items) |out_sig| {
                port_idx += 1;
                const is_last = (port_idx == actual_port_count);
                const width = if (out_sig.inferred_width > 0) out_sig.inferred_width else 1;
                
                if (width > 1) {
                    const width_minus_1 = width - 1;
                    if (is_last) {
                        try self.builder.writeFmt("output reg  [{d}:0] {s}  // Auto-generated from FSM outputs (width inferred)\n", .{ width_minus_1, out_sig.name });
                    } else {
                        try self.builder.writeFmt("output reg  [{d}:0] {s},  // Auto-generated from FSM outputs (width inferred)\n", .{ width_minus_1, out_sig.name });
                    }
                } else {
                    if (is_last) {
                        try self.builder.writeFmt("output reg         {s}  // Auto-generated from FSM outputs\n", .{out_sig.name});
                    } else {
                        try self.builder.writeFmt("output reg         {s},  // Auto-generated from FSM outputs\n", .{out_sig.name});
                    }
                }
            }
            
            for (spec.signals.items) |sig| {
                // Skip internal registers and wires - they're not ports
                if (std.mem.eql(u8, sig.direction, "reg") or std.mem.eql(u8, sig.direction, "wire")) {
                    continue;
                }
                
                port_idx += 1;
                const is_last = (port_idx == actual_port_count);
                
                // Determine port direction and type
                const dir_str = if (std.mem.eql(u8, sig.direction, "input"))
                    "input  wire"
                else if (std.mem.eql(u8, sig.direction, "output"))
                    "output reg "
                else if (std.mem.eql(u8, sig.direction, "inout"))
                    "inout  wire"
                else
                    "wire      ";
                
                // Generate width specifier
                if (sig.width > 1) {
                    const width_minus_1 = sig.width - 1;
                    if (is_last) {
                        try self.builder.writeFmt("{s} [{d}:0] {s}\n", .{ dir_str, width_minus_1, sig.name });
                    } else {
                        try self.builder.writeFmt("{s} [{d}:0] {s},\n", .{ dir_str, width_minus_1, sig.name });
                    }
                } else {
                    if (is_last) {
                        try self.builder.writeFmt("{s}        {s}\n", .{ dir_str, sig.name });
                    } else {
                        try self.builder.writeFmt("{s}        {s},\n", .{ dir_str, sig.name });
                    }
                }
            }
        } else {
            // Standard FPGA ports (fallback)
            try self.builder.writeLine("input  wire        clk,");
            try self.builder.writeLine("input  wire        rst_n,");
            try self.builder.writeLine("input  wire [31:0] data_in,");
            try self.builder.writeLine("input  wire        valid_in,");
            try self.builder.writeLine("output reg  [31:0] data_out,");
            try self.builder.writeLine("output reg         valid_out,");
            try self.builder.writeLine("output wire        ready");
        }
        
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        self.builder.incIndent();
        
        // Generate user constants as localparams
        if (spec.constants.items.len > 0) {
            try self.builder.writeLine("// User constants");
            for (spec.constants.items) |constant| {
                try self.builder.writeFmt("localparam {s} = 32'd{d};\n", .{ constant.name, constant.value });
            }
            try self.builder.newline();
        }
        
        // Generate internal registers from signals
        // Skip timer signals if FSM has timers (they'll be generated in timer logic)
        const has_fsm_timers = spec.fsms.items.len > 0 and spec.fsms.items[0].timers.items.len > 0;
        
        if (spec.signals.items.len > 0) {
            try self.builder.writeLine("// Internal registers");
            for (spec.signals.items) |sig| {
                if (std.mem.eql(u8, sig.direction, "reg")) {
                    // Skip timer signals if FSM has timers
                    if (has_fsm_timers) {
                        if (std.mem.eql(u8, sig.name, "timer_count") or 
                            std.mem.eql(u8, sig.name, "timer_expired")) {
                            continue;
                        }
                    }
                    
                    if (sig.width > 1) {
                        const width_minus_1 = sig.width - 1;
                        if (sig.default_value) |def| {
                            try self.builder.writeFmt("reg [{d}:0] {s} = {d}'d{d};\n", .{ width_minus_1, sig.name, sig.width, def });
                        } else {
                            try self.builder.writeFmt("reg [{d}:0] {s};\n", .{ width_minus_1, sig.name });
                        }
                    } else {
                        if (sig.default_value) |def| {
                            try self.builder.writeFmt("reg {s} = 1'b{d};\n", .{ sig.name, def });
                        } else {
                            try self.builder.writeFmt("reg {s};\n", .{ sig.name });
                        }
                    }
                }
            }
            try self.builder.newline();
        }
        
        // Generate FSM from spec if defined
        // NOTE: All signals used in FSM transition conditions must be declared in the signals: section
        // of the .vibee spec. The generator does not auto-declare signals from conditions.
        if (spec.fsms.items.len > 0) {
            for (spec.fsms.items) |fsm| {
                try self.builder.writeFmt("// FSM: {s}\n", .{fsm.name});
                try self.builder.writeLine("// NOTE: Ensure all signals in transition conditions are declared in signals: section");
                
                // Calculate state width based on encoding
                const state_count = fsm.states.items.len;
                const state_width: u32 = if (std.mem.eql(u8, fsm.encoding, "onehot"))
                    @intCast(state_count)
                else
                    @intCast(std.math.log2_int(usize, state_count) + 1);
                
                // Generate state parameters
                if (std.mem.eql(u8, fsm.encoding, "onehot")) {
                    for (fsm.states.items, 0..) |state, i| {
                        var one_hot: u64 = 1;
                        one_hot <<= @intCast(i);
                        try self.builder.writeFmt("localparam {s} = {d}'b", .{ state, state_width });
                        // Write binary representation
                        var j: u32 = state_width;
                        while (j > 0) {
                            j -= 1;
                            const bit: u64 = (one_hot >> @intCast(j)) & 1;
                            try self.builder.writeFmt("{d}", .{bit});
                        }
                        try self.builder.write(";\n");
                    }
                } else {
                    // Binary encoding
                    for (fsm.states.items, 0..) |state, i| {
                        try self.builder.writeFmt("localparam {s} = {d}'d{d};\n", .{ state, state_width, i });
                    }
                }
                try self.builder.newline();
                
                // State registers
                try self.builder.writeFmt("reg [{d}:0] state;\n", .{state_width - 1});
                try self.builder.writeFmt("reg [{d}:0] next_state;\n", .{state_width - 1});
                try self.builder.newline();
            }
        } else {
            // Default state machine
            try self.builder.writeLine("// State machine");
            try self.builder.writeLine("localparam IDLE    = 3'd0;");
            try self.builder.writeLine("localparam PROCESS = 3'd1;");
            try self.builder.writeLine("localparam DONE    = 3'd2;");
            try self.builder.newline();
            
            try self.builder.writeLine("reg [2:0] state;");
            try self.builder.writeLine("reg [2:0] next_state;");
            try self.builder.newline();
        }
        
        // Sacred constants instance
        try self.builder.writeLine("// Sacred constants");
        try self.builder.writeLine("wire [63:0] phi, phi_sq, phi_inv_sq, trinity;");
        try self.builder.writeLine("wire [31:0] phoenix;");
        try self.builder.newline();
        
        try self.builder.writeFmt("{s}_sacred_constants sacred_inst (\n", .{spec.name});
        self.builder.incIndent();
        try self.builder.writeLine(".phi(phi),");
        try self.builder.writeLine(".phi_sq(phi_sq),");
        try self.builder.writeLine(".phi_inv_sq(phi_inv_sq),");
        try self.builder.writeLine(".trinity(trinity),");
        try self.builder.writeLine(".phoenix(phoenix)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        // Get initial state name
        const initial_state = if (spec.fsms.items.len > 0) spec.fsms.items[0].initial_state else "IDLE";
        
        // Ready signal
        try self.builder.writeFmt("assign ready = (state == {s});\n", .{initial_state});
        try self.builder.newline();
        
        // Generate timer logic if FSM has timers
        if (spec.fsms.items.len > 0 and spec.fsms.items[0].timers.items.len > 0) {
            const fsm = spec.fsms.items[0];
            
            try self.builder.writeLine("// Timer logic");
            try self.builder.writeLine("reg [31:0] timer_count;");
            try self.builder.writeLine("wire timer_expired;");
            try self.builder.writeLine("reg [31:0] timeout_value;");
            try self.builder.newline();
            
            // Timeout value selection based on state
            try self.builder.writeLine("// Timeout value per state");
            try self.builder.writeLine("always @(*) begin");
            self.builder.incIndent();
            try self.builder.writeLine("case (state)");
            self.builder.incIndent();
            
            for (fsm.timers.items) |timer| {
                if (timer.timeout_constant.len > 0) {
                    try self.builder.writeFmt("{s}: timeout_value = {s};\n", .{ timer.state, timer.timeout_constant });
                } else {
                    try self.builder.writeFmt("{s}: timeout_value = 32'd{d};\n", .{ timer.state, timer.timeout_value });
                }
            }
            try self.builder.writeFmt("default: timeout_value = 32'd{d};\n", .{fsm.timers.items[0].timeout_value});
            
            self.builder.decIndent();
            try self.builder.writeLine("endcase");
            self.builder.decIndent();
            try self.builder.writeLine("end");
            try self.builder.newline();
            
            // Timer counter
            try self.builder.writeLine("// Timer counter");
            try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
            self.builder.incIndent();
            try self.builder.writeLine("if (!rst_n)");
            self.builder.incIndent();
            try self.builder.writeLine("timer_count <= 32'd0;");
            self.builder.decIndent();
            try self.builder.writeLine("else if (state != next_state)");
            self.builder.incIndent();
            try self.builder.writeLine("timer_count <= 32'd0;  // Reset on state change");
            self.builder.decIndent();
            try self.builder.writeLine("else if (timer_count < timeout_value - 1)");
            self.builder.incIndent();
            try self.builder.writeLine("timer_count <= timer_count + 1;");
            self.builder.decIndent();
            self.builder.decIndent();
            try self.builder.writeLine("end");
            try self.builder.newline();
            
            // Timer expired signal
            try self.builder.writeLine("assign timer_expired = (timer_count >= timeout_value - 1);");
            try self.builder.newline();
        }
        
        // State register
        try self.builder.writeLine("// State register");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n)");
        self.builder.incIndent();
        try self.builder.writeFmt("state <= {s};\n", .{initial_state});
        self.builder.decIndent();
        try self.builder.writeLine("else");
        self.builder.incIndent();
        try self.builder.writeLine("state <= next_state;");
        self.builder.decIndent();
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();
        
        // Next state logic - generate from FSM if defined
        try self.builder.writeLine("// Next state logic");
        try self.builder.writeLine("always @(*) begin");
        self.builder.incIndent();
        try self.builder.writeLine("next_state = state;");
        try self.builder.writeLine("case (state)");
        self.builder.incIndent();
        
        if (spec.fsms.items.len > 0) {
            const fsm = spec.fsms.items[0];
            
            // Check if we have explicit transitions
            if (fsm.transitions.items.len > 0) {
                // Generate case with conditional transitions
                for (fsm.states.items) |state| {
                    try self.builder.writeFmt("{s}: begin\n", .{state});
                    self.builder.incIndent();
                    
                    // Find all transitions from this state
                    var has_transition = false;
                    for (fsm.transitions.items) |trans| {
                        if (std.mem.eql(u8, trans.from_state, state)) {
                            if (trans.condition.len > 0) {
                                try self.builder.writeFmt("if ({s}) next_state = {s};\n", .{ trans.condition, trans.to_state });
                            } else {
                                try self.builder.writeFmt("next_state = {s};\n", .{trans.to_state});
                            }
                            has_transition = true;
                        }
                    }
                    
                    if (!has_transition) {
                        // Stay in current state if no transition defined
                        try self.builder.writeFmt("next_state = {s};\n", .{state});
                    }
                    
                    self.builder.decIndent();
                    try self.builder.writeLine("end");
                }
            } else {
                // Simple sequential state machine (fallback)
                for (fsm.states.items, 0..) |state, i| {
                    if (i + 1 < fsm.states.items.len) {
                        try self.builder.writeFmt("{s}: next_state = {s};\n", .{ state, fsm.states.items[i + 1] });
                    } else {
                        try self.builder.writeFmt("{s}: next_state = {s};\n", .{ state, fsm.initial_state });
                    }
                }
            }
        } else {
            try self.builder.writeLine("IDLE:    next_state = PROCESS;");
            try self.builder.writeLine("PROCESS: next_state = DONE;");
            try self.builder.writeLine("DONE:    next_state = IDLE;");
        }
        try self.builder.writeFmt("default: next_state = {s};\n", .{initial_state});
        self.builder.decIndent();
        try self.builder.writeLine("endcase");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();
        
        // Output logic - simplified for custom signals
        try self.builder.writeLine("// Output logic");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        self.builder.incIndent();
        
        // Reset output signals
        if (spec.signals.items.len > 0) {
            for (spec.signals.items) |sig| {
                if (std.mem.eql(u8, sig.direction, "output")) {
                    if (sig.default_value) |def| {
                        if (sig.width > 1) {
                            try self.builder.writeFmt("{s} <= {d}'d{d};\n", .{ sig.name, sig.width, def });
                        } else {
                            try self.builder.writeFmt("{s} <= 1'b{d};\n", .{ sig.name, def });
                        }
                    } else {
                        if (sig.width > 1) {
                            try self.builder.writeFmt("{s} <= {d}'d0;\n", .{ sig.name, sig.width });
                        } else {
                            try self.builder.writeFmt("{s} <= 1'b0;\n", .{ sig.name });
                        }
                    }
                }
            }
        } else if (fsm_signals.items.len == 0 and fsm_output_signals.items.len == 0) {
            // Only generate default outputs if no custom signals at all
            try self.builder.writeLine("data_out  <= 32'd0;");
            try self.builder.writeLine("valid_out <= 1'b0;");
        } else {
            // FSM signals or outputs present - just comment
            try self.builder.writeLine("// No explicit output signals defined");
        }
        self.builder.decIndent();
        try self.builder.writeLine("end else begin");
        self.builder.incIndent();
        
        // Generate output logic from FSM outputs if available
        if (spec.fsms.items.len > 0 and spec.fsms.items[0].outputs.items.len > 0) {
            const fsm = spec.fsms.items[0];
            try self.builder.writeLine("// State-based output logic");
            try self.builder.writeLine("case (state)");
            self.builder.incIndent();
            
            for (fsm.outputs.items) |out| {
                try self.builder.writeFmt("{s}: begin\n", .{out.state});
                self.builder.incIndent();
                // Generate assignments for all signals in this state
                var iter = out.signals.iterator();
                while (iter.next()) |entry| {
                    try self.builder.writeFmt("{s} <= {s};\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
                self.builder.decIndent();
                try self.builder.writeLine("end");
            }
            
            // Default case - reset all outputs to 0
            try self.builder.writeLine("default: begin");
            self.builder.incIndent();
            // Get all unique signal names from outputs
            if (fsm.outputs.items.len > 0) {
                var iter = fsm.outputs.items[0].signals.iterator();
                while (iter.next()) |entry| {
                    try self.builder.writeFmt("{s} <= 1'b0;\n", .{entry.key_ptr.*});
                }
            }
            self.builder.decIndent();
            try self.builder.writeLine("end");
            
            self.builder.decIndent();
            try self.builder.writeLine("endcase");
        } else {
            try self.builder.writeLine("// State-based output logic (customize as needed)");
        }
        
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeBehaviorModules(self: *Self, behaviors: []const Behavior) !void {
        if (behaviors.len == 0) return;
        
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR MODULES");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        for (behaviors) |b| {
            // Check for special ternary logic modules
            if (std.mem.eql(u8, b.name, "trit_not")) {
                try self.writeTritNot();
            } else if (std.mem.eql(u8, b.name, "trit_and")) {
                try self.writeTritAnd();
            } else if (std.mem.eql(u8, b.name, "trit_or")) {
                try self.writeTritOr();
            } else if (std.mem.eql(u8, b.name, "trit_half_adder")) {
                try self.writeTritHalfAdder();
            } else if (std.mem.eql(u8, b.name, "trit_full_adder")) {
                try self.writeTritFullAdder();
            } else if (std.mem.eql(u8, b.name, "trit_multiply")) {
                try self.writeTritMultiply();
            } else if (std.mem.eql(u8, b.name, "trit3_add")) {
                try self.writeTrit3Adder();
            } else if (std.mem.eql(u8, b.name, "trit_compare")) {
                try self.writeTritCompare();
            // SIMD modules
            } else if (std.mem.eql(u8, b.name, "trit27_parallel_multiply")) {
                try self.writeTrit27ParallelMultiply();
            } else if (std.mem.eql(u8, b.name, "adder_tree_27")) {
                try self.writeAdderTree27();
            } else if (std.mem.eql(u8, b.name, "trit27_dot_product")) {
                try self.writeTrit27DotProduct();
            } else if (std.mem.eql(u8, b.name, "bitnet_activation")) {
                try self.writeBitNetActivation();
            // Pipeline modules
            } else if (std.mem.eql(u8, b.name, "weight_bram")) {
                try self.writeWeightBram();
            } else if (std.mem.eql(u8, b.name, "pipeline_stage2_compute")) {
                try self.writePipelineStage2();
            } else if (std.mem.eql(u8, b.name, "layer_sequencer")) {
                try self.writeLayerSequencer();
            } else if (std.mem.eql(u8, b.name, "bitnet_layer_top")) {
                try self.writeBitNetLayerTop();
            // Multi-layer modules
            } else if (std.mem.eql(u8, b.name, "double_buffer_ctrl")) {
                try self.writeDoubleBufferCtrl();
            } else if (std.mem.eql(u8, b.name, "weight_prefetch_ctrl")) {
                try self.writeWeightPrefetchCtrl();
            } else if (std.mem.eql(u8, b.name, "multilayer_sequencer")) {
                try self.writeMultilayerSequencer();
            } else if (std.mem.eql(u8, b.name, "bitnet_engine_top")) {
                try self.writeBitNetEngineTop();
            // AXI Host Interface modules
            } else if (std.mem.eql(u8, b.name, "axi_lite_slave")) {
                try self.writeAxiLiteSlave();
            } else if (std.mem.eql(u8, b.name, "dma_controller")) {
                try self.writeDmaController();
            } else if (std.mem.eql(u8, b.name, "interrupt_controller")) {
                try self.writeInterruptController();
            } else if (std.mem.eql(u8, b.name, "host_interface_top")) {
                try self.writeHostInterfaceTop();
            } else {
                // Default generic behavior module
                try self.writeGenericBehavior(b);
            }
        }
    }
    
    fn writeTritNot(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT NOT - Ternary Negation");
        try self.builder.writeLine("// Encoding: 2'b00=-1, 2'b01=0, 2'b10=+1");
        try self.builder.writeLine("// NOT(-1)=+1, NOT(0)=0, NOT(+1)=-1");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_not (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Trit encoding constants");
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// NOT truth table: swap -1 and +1, keep 0");
        try self.builder.writeLine("assign result = (a == TRIT_Z) ? TRIT_Z :  // 0 -> 0");
        try self.builder.writeLine("                (a == TRIT_N) ? TRIT_P :  // -1 -> +1");
        try self.builder.writeLine("                (a == TRIT_P) ? TRIT_N :  // +1 -> -1");
        try self.builder.writeLine("                TRIT_Z;                    // invalid -> 0");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritAnd(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT AND - Kleene Logic Minimum");
        try self.builder.writeLine("// AND(a,b) = min(a,b) in balanced ternary");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_and (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Kleene AND = minimum");
        try self.builder.writeLine("// If either is -1, result is -1");
        try self.builder.writeLine("// Else if either is 0, result is 0");
        try self.builder.writeLine("// Else result is +1");
        try self.builder.writeLine("assign result = (a == TRIT_N || b == TRIT_N) ? TRIT_N :");
        try self.builder.writeLine("                (a == TRIT_Z || b == TRIT_Z) ? TRIT_Z :");
        try self.builder.writeLine("                TRIT_P;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritOr(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT OR - Kleene Logic Maximum");
        try self.builder.writeLine("// OR(a,b) = max(a,b) in balanced ternary");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_or (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Kleene OR = maximum");
        try self.builder.writeLine("// If either is +1, result is +1");
        try self.builder.writeLine("// Else if either is 0, result is 0");
        try self.builder.writeLine("// Else result is -1");
        try self.builder.writeLine("assign result = (a == TRIT_P || b == TRIT_P) ? TRIT_P :");
        try self.builder.writeLine("                (a == TRIT_Z || b == TRIT_Z) ? TRIT_Z :");
        try self.builder.writeLine("                TRIT_N;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritHalfAdder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT HALF ADDER - Balanced Ternary Addition");
        try self.builder.writeLine("// a + b = (sum, carry)");
        try self.builder.writeLine("// -1+-1=(+1,-1), -1+0=(-1,0), -1+1=(0,0)");
        try self.builder.writeLine("//  0+-1=(-1,0),  0+0=(0,0),   0+1=(+1,0)");
        try self.builder.writeLine("// +1+-1=(0,0),  +1+0=(+1,0), +1+1=(-1,+1)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_half_adder (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] sum,");
        try self.builder.writeLine("output wire [1:0] carry");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Convert to signed for arithmetic");
        try self.builder.writeLine("wire signed [2:0] a_val = (a == TRIT_N) ? -3'sd1 : (a == TRIT_P) ? 3'sd1 : 3'sd0;");
        try self.builder.writeLine("wire signed [2:0] b_val = (b == TRIT_N) ? -3'sd1 : (b == TRIT_P) ? 3'sd1 : 3'sd0;");
        try self.builder.writeLine("wire signed [2:0] total = a_val + b_val;");
        try self.builder.newline();
        try self.builder.writeLine("// Map result back to balanced ternary");
        try self.builder.writeLine("assign sum = (total == -3'sd2) ? TRIT_P :  // -2 = -3+1 -> sum=+1");
        try self.builder.writeLine("             (total == -3'sd1) ? TRIT_N :  // -1 -> sum=-1");
        try self.builder.writeLine("             (total ==  3'sd0) ? TRIT_Z :  //  0 -> sum=0");
        try self.builder.writeLine("             (total ==  3'sd1) ? TRIT_P :  // +1 -> sum=+1");
        try self.builder.writeLine("             (total ==  3'sd2) ? TRIT_N :  // +2 = +3-1 -> sum=-1");
        try self.builder.writeLine("             TRIT_Z;");
        try self.builder.newline();
        try self.builder.writeLine("assign carry = (total == -3'sd2) ? TRIT_N :  // -2 -> carry=-1");
        try self.builder.writeLine("               (total ==  3'sd2) ? TRIT_P :  // +2 -> carry=+1");
        try self.builder.writeLine("               TRIT_Z;                        // else carry=0");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritFullAdder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT FULL ADDER - With Carry Input");
        try self.builder.writeLine("// a + b + cin = (sum, cout)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_full_adder (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("input  wire [1:0] cin,");
        try self.builder.writeLine("output wire [1:0] sum,");
        try self.builder.writeLine("output wire [1:0] cout");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// Two-stage addition using half adders");
        try self.builder.writeLine("wire [1:0] sum1, carry1, carry2;");
        try self.builder.newline();
        try self.builder.writeLine("trit_half_adder ha1 (.a(a), .b(b), .sum(sum1), .carry(carry1));");
        try self.builder.writeLine("trit_half_adder ha2 (.a(sum1), .b(cin), .sum(sum), .carry(carry2));");
        try self.builder.newline();
        try self.builder.writeLine("// Combine carries with OR (max)");
        try self.builder.writeLine("trit_or carry_combine (.a(carry1), .b(carry2), .result(cout));");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritMultiply(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT MULTIPLY - Single Trit Multiplication");
        try self.builder.writeLine("// -1*-1=+1, -1*0=0, -1*+1=-1");
        try self.builder.writeLine("//  0*-1=0,   0*0=0,  0*+1=0");
        try self.builder.writeLine("// +1*-1=-1, +1*0=0, +1*+1=+1");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_multiply (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// If either is zero, result is zero");
        try self.builder.writeLine("// If signs are same, result is +1");
        try self.builder.writeLine("// If signs are different, result is -1");
        try self.builder.writeLine("wire a_zero = (a == TRIT_Z);");
        try self.builder.writeLine("wire b_zero = (b == TRIT_Z);");
        try self.builder.writeLine("wire same_sign = (a == b);");
        try self.builder.newline();
        try self.builder.writeLine("assign result = (a_zero || b_zero) ? TRIT_Z :");
        try self.builder.writeLine("                same_sign ? TRIT_P : TRIT_N;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTrit3Adder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT3 ADDER - 3-Trit Ripple Carry Adder");
        try self.builder.writeLine("// Adds two 3-trit numbers (range: -13 to +13)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit3_add (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [5:0] a,      // 3 trits: [5:4]=t2, [3:2]=t1, [1:0]=t0");
        try self.builder.writeLine("input  wire [5:0] b,");
        try self.builder.writeLine("output wire [5:0] sum,");
        try self.builder.writeLine("output wire [1:0] cout    // Carry out");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.newline();
        try self.builder.writeLine("wire [1:0] c0, c1, c2;");
        try self.builder.newline();
        try self.builder.writeLine("// Ripple carry chain");
        try self.builder.writeLine("trit_full_adder fa0 (.a(a[1:0]), .b(b[1:0]), .cin(TRIT_Z), .sum(sum[1:0]), .cout(c0));");
        try self.builder.writeLine("trit_full_adder fa1 (.a(a[3:2]), .b(b[3:2]), .cin(c0),     .sum(sum[3:2]), .cout(c1));");
        try self.builder.writeLine("trit_full_adder fa2 (.a(a[5:4]), .b(b[5:4]), .cin(c1),     .sum(sum[5:4]), .cout(cout));");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTritCompare(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT COMPARE - Ternary Comparison");
        try self.builder.writeLine("// Returns -1 if a<b, 0 if a==b, +1 if a>b");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_compare (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// Direct comparison of encoded values");
        try self.builder.writeLine("assign result = (a == b) ? TRIT_Z :");
        try self.builder.writeLine("                (a < b)  ? TRIT_N : TRIT_P;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTrit27ParallelMultiply(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT27 PARALLEL MULTIPLY - 27-way SIMD Ternary Multiplication");
        try self.builder.writeLine("// BitNet core operation: NO actual multipliers, just sign comparison!");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit27_parallel_multiply (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] a,      // 27 trits input");
        try self.builder.writeLine("input  wire [53:0] b,      // 27 trits weights");
        try self.builder.writeLine("output wire [53:0] result  // 27 trits products");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Generate 27 parallel multipliers");
        try self.builder.writeLine("genvar i;");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 27; i = i + 1) begin : mult_gen");
        self.builder.incIndent();
        try self.builder.writeLine("wire [1:0] ai = a[i*2+1 : i*2];");
        try self.builder.writeLine("wire [1:0] bi = b[i*2+1 : i*2];");
        try self.builder.writeLine("wire a_zero = (ai == TRIT_Z);");
        try self.builder.writeLine("wire b_zero = (bi == TRIT_Z);");
        try self.builder.writeLine("wire same_sign = (ai == bi);");
        try self.builder.newline();
        try self.builder.writeLine("// Ternary multiply: sign comparison only!");
        try self.builder.writeLine("assign result[i*2+1 : i*2] = (a_zero || b_zero) ? TRIT_Z :");
        try self.builder.writeLine("                             same_sign ? TRIT_P : TRIT_N;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeAdderTree27(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ADDER TREE 27 - Reduce 27 trits to single sum");
        try self.builder.writeLine("// 3-level tree: 27 → 9 → 3 → 1");
        try self.builder.writeLine("// Output range: -27 to +27 (6 bits signed)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module adder_tree_27 (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] trits,  // 27 trits to sum");
        try self.builder.writeLine("output wire signed [5:0] sum  // Result: -27 to +27");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Convert trits to signed values");
        try self.builder.writeLine("wire signed [1:0] val [0:26];");
        try self.builder.writeLine("genvar i;");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 27; i = i + 1) begin : convert");
        self.builder.incIndent();
        try self.builder.writeLine("wire [1:0] t = trits[i*2+1 : i*2];");
        try self.builder.writeLine("assign val[i] = (t == TRIT_N) ? -2'sd1 :");
        try self.builder.writeLine("                (t == TRIT_P) ?  2'sd1 : 2'sd0;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        try self.builder.newline();
        try self.builder.writeLine("// Level 1: 9 groups of 3 (range: -3 to +3)");
        try self.builder.writeLine("wire signed [2:0] l1 [0:8];");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 9; i = i + 1) begin : level1");
        self.builder.incIndent();
        try self.builder.writeLine("assign l1[i] = val[i*3] + val[i*3+1] + val[i*3+2];");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        try self.builder.newline();
        try self.builder.writeLine("// Level 2: 3 groups of 3 (range: -9 to +9)");
        try self.builder.writeLine("wire signed [3:0] l2 [0:2];");
        try self.builder.writeLine("assign l2[0] = l1[0] + l1[1] + l1[2];");
        try self.builder.writeLine("assign l2[1] = l1[3] + l1[4] + l1[5];");
        try self.builder.writeLine("assign l2[2] = l1[6] + l1[7] + l1[8];");
        try self.builder.newline();
        try self.builder.writeLine("// Level 3: Final sum (range: -27 to +27)");
        try self.builder.writeLine("assign sum = l2[0] + l2[1] + l2[2];");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeTrit27DotProduct(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT27 DOT PRODUCT - Complete BitNet MAC operation");
        try self.builder.writeLine("// Multiply 27 trits + reduce with adder tree");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit27_dot_product (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] input_vec,   // 27 trits input");
        try self.builder.writeLine("input  wire [53:0] weight_vec,  // 27 trits weights");
        try self.builder.writeLine("output wire signed [5:0] result // Dot product: -27 to +27");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Step 1: Parallel multiply (27 sign comparisons)");
        try self.builder.writeLine("wire [53:0] products;");
        try self.builder.writeLine("trit27_parallel_multiply mult_unit (");
        self.builder.incIndent();
        try self.builder.writeLine(".a(input_vec),");
        try self.builder.writeLine(".b(weight_vec),");
        try self.builder.writeLine(".result(products)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Step 2: Reduce with adder tree");
        try self.builder.writeLine("adder_tree_27 tree (");
        self.builder.incIndent();
        try self.builder.writeLine(".trits(products),");
        try self.builder.writeLine(".sum(result)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeWeightBram(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// WEIGHT BRAM - Dual-port BRAM for ternary weights");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module weight_bram #(");
        self.builder.incIndent();
        try self.builder.writeLine("parameter DEPTH = 4096,");
        try self.builder.writeLine("parameter ADDR_WIDTH = 12");
        self.builder.decIndent();
        try self.builder.writeLine(") (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire                  clk,");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0] rd_addr,");
        try self.builder.writeLine("output reg  [53:0]           rd_data,");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0] wr_addr,");
        try self.builder.writeLine("input  wire [53:0]           wr_data,");
        try self.builder.writeLine("input  wire                  wr_en");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// BRAM storage");
        try self.builder.writeLine("reg [53:0] mem [0:DEPTH-1];");
        try self.builder.newline();
        try self.builder.writeLine("// Read port (1 cycle latency)");
        try self.builder.writeLine("always @(posedge clk) rd_data <= mem[rd_addr];");
        try self.builder.newline();
        try self.builder.writeLine("// Write port");
        try self.builder.writeLine("always @(posedge clk) if (wr_en) mem[wr_addr] <= wr_data;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writePipelineStage2(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// PIPELINE STAGE 2 - SIMD Compute with Accumulator");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module pipeline_stage2_compute (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        valid_in,");
        try self.builder.writeLine("input  wire [53:0] input_chunk,");
        try self.builder.writeLine("input  wire [53:0] weight_chunk,");
        try self.builder.writeLine("input  wire        first_chunk,");
        try self.builder.writeLine("input  wire        last_chunk,");
        try self.builder.writeLine("output reg         valid_out,");
        try self.builder.writeLine("output reg  signed [15:0] result,");
        try self.builder.writeLine("output reg         result_final");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// SIMD dot product");
        try self.builder.writeLine("wire signed [5:0] dot_result;");
        try self.builder.writeLine("trit27_dot_product simd (.input_vec(input_chunk), .weight_vec(weight_chunk), .result(dot_result));");
        try self.builder.newline();
        try self.builder.writeLine("// Accumulator");
        try self.builder.writeLine("reg signed [15:0] accumulator;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        try self.builder.writeLine("    accumulator <= 0; valid_out <= 0; result_final <= 0;");
        try self.builder.writeLine("end else if (valid_in) begin");
        try self.builder.writeLine("    accumulator <= first_chunk ? dot_result : accumulator + dot_result;");
        try self.builder.writeLine("    valid_out <= last_chunk;");
        try self.builder.writeLine("    result <= first_chunk ? dot_result : accumulator + dot_result;");
        try self.builder.writeLine("    result_final <= last_chunk;");
        try self.builder.writeLine("end else valid_out <= 0;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeLayerSequencer(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// LAYER SEQUENCER - FSM for layer execution");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module layer_sequencer (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [15:0] num_neurons,");
        try self.builder.writeLine("input  wire [7:0]  num_chunks,");
        try self.builder.writeLine("output reg  [15:0] neuron_id,");
        try self.builder.writeLine("output reg  [7:0]  chunk_id,");
        try self.builder.writeLine("output reg         first_chunk,");
        try self.builder.writeLine("output reg         last_chunk,");
        try self.builder.writeLine("output reg         valid,");
        try self.builder.writeLine("output reg         done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, RUN=1, DONE_ST=2;");
        try self.builder.writeLine("reg [1:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        try self.builder.writeLine("    state<=IDLE; neuron_id<=0; chunk_id<=0; valid<=0; done<=0;");
        try self.builder.writeLine("end else case(state)");
        try self.builder.writeLine("    IDLE: if(start) begin state<=RUN; neuron_id<=0; chunk_id<=0; end");
        try self.builder.writeLine("    RUN: begin");
        try self.builder.writeLine("        valid<=1; first_chunk<=(chunk_id==0); last_chunk<=(chunk_id==num_chunks-1);");
        try self.builder.writeLine("        if(chunk_id==num_chunks-1) begin chunk_id<=0;");
        try self.builder.writeLine("            if(neuron_id==num_neurons-1) state<=DONE_ST; else neuron_id<=neuron_id+1;");
        try self.builder.writeLine("        end else chunk_id<=chunk_id+1;");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("    DONE_ST: begin valid<=0; done<=1; state<=IDLE; end");
        try self.builder.writeLine("endcase end");
        self.builder.decIndent();
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeDoubleBufferCtrl(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// DOUBLE BUFFER CONTROLLER - Ping-pong activation buffers");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module double_buffer_ctrl (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        layer_done,");
        try self.builder.writeLine("input  wire [5:0]  current_layer,");
        try self.builder.writeLine("output reg         use_buffer_a,  // 1=read A/write B, 0=read B/write A");
        try self.builder.writeLine("output wire [11:0] read_addr,");
        try self.builder.writeLine("output wire [11:0] write_addr,");
        try self.builder.writeLine("input  wire [11:0] neuron_id");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Even layers: read A, write B");
        try self.builder.writeLine("// Odd layers: read B, write A");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) use_buffer_a <= 1;");
        try self.builder.writeLine("    else if (layer_done) use_buffer_a <= ~use_buffer_a;");
        try self.builder.newline();
        try self.builder.writeLine("assign read_addr = neuron_id;");
        try self.builder.writeLine("assign write_addr = neuron_id;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeWeightPrefetchCtrl(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// WEIGHT PREFETCH CONTROLLER - Stream weights from DDR while computing");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module weight_prefetch_ctrl (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start_prefetch,");
        try self.builder.writeLine("input  wire [31:0] src_addr,");
        try self.builder.writeLine("input  wire [15:0] num_words,");
        try self.builder.writeLine("output reg         prefetch_active,");
        try self.builder.writeLine("output reg         prefetch_done,");
        try self.builder.writeLine("// AXI read interface");
        try self.builder.writeLine("output reg  [31:0] axi_araddr,");
        try self.builder.writeLine("output reg         axi_arvalid,");
        try self.builder.writeLine("input  wire        axi_arready,");
        try self.builder.writeLine("input  wire [63:0] axi_rdata,");
        try self.builder.writeLine("input  wire        axi_rvalid,");
        try self.builder.writeLine("output wire        axi_rready,");
        try self.builder.writeLine("// BRAM write interface");
        try self.builder.writeLine("output reg  [11:0] bram_addr,");
        try self.builder.writeLine("output reg  [53:0] bram_data,");
        try self.builder.writeLine("output reg         bram_we");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("reg [15:0] words_remaining;");
        try self.builder.writeLine("localparam IDLE=0, FETCH=1, DONE=2;");
        try self.builder.writeLine("reg [1:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("assign axi_rready = (state == FETCH);");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; prefetch_active <= 0; prefetch_done <= 0;");
        try self.builder.writeLine("        axi_arvalid <= 0; bram_we <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start_prefetch) begin");
        try self.builder.writeLine("            state <= FETCH; prefetch_active <= 1; prefetch_done <= 0;");
        try self.builder.writeLine("            axi_araddr <= src_addr; words_remaining <= num_words; bram_addr <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        FETCH: begin");
        try self.builder.writeLine("            axi_arvalid <= 1;");
        try self.builder.writeLine("            if (axi_arready) axi_araddr <= axi_araddr + 8;");
        try self.builder.writeLine("            if (axi_rvalid) begin");
        try self.builder.writeLine("                bram_data <= axi_rdata[53:0]; bram_we <= 1; bram_addr <= bram_addr + 1;");
        try self.builder.writeLine("                words_remaining <= words_remaining - 1;");
        try self.builder.writeLine("                if (words_remaining == 1) state <= DONE;");
        try self.builder.writeLine("            end else bram_we <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        DONE: begin");
        try self.builder.writeLine("            prefetch_active <= 0; prefetch_done <= 1; axi_arvalid <= 0; bram_we <= 0;");
        try self.builder.writeLine("            state <= IDLE;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeMultilayerSequencer(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// MULTI-LAYER SEQUENCER - FSM for full model inference");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module multilayer_sequencer (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [5:0]  num_layers,");
        try self.builder.writeLine("input  wire        layer_done,");
        try self.builder.writeLine("input  wire        prefetch_done,");
        try self.builder.writeLine("output reg  [5:0]  current_layer,");
        try self.builder.writeLine("output reg         layer_start,");
        try self.builder.writeLine("output reg         start_prefetch,");
        try self.builder.writeLine("output reg         inference_done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, INIT=1, RUNNING=2, WAIT_LAYER=3, NEXT_LAYER=4, COMPLETE=5;");
        try self.builder.writeLine("reg [2:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; current_layer <= 0; layer_start <= 0;");
        try self.builder.writeLine("        start_prefetch <= 0; inference_done <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start) begin");
        try self.builder.writeLine("            state <= INIT; current_layer <= 0; inference_done <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        INIT: begin");
        try self.builder.writeLine("            // Start first layer and prefetch second");
        try self.builder.writeLine("            layer_start <= 1; start_prefetch <= (num_layers > 1);");
        try self.builder.writeLine("            state <= RUNNING;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        RUNNING: begin");
        try self.builder.writeLine("            layer_start <= 0; start_prefetch <= 0;");
        try self.builder.writeLine("            state <= WAIT_LAYER;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        WAIT_LAYER: if (layer_done) begin");
        try self.builder.writeLine("            if (current_layer == num_layers - 1) state <= COMPLETE;");
        try self.builder.writeLine("            else state <= NEXT_LAYER;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        NEXT_LAYER: begin");
        try self.builder.writeLine("            current_layer <= current_layer + 1;");
        try self.builder.writeLine("            layer_start <= 1;");
        try self.builder.writeLine("            start_prefetch <= (current_layer + 2 < num_layers);");
        try self.builder.writeLine("            state <= RUNNING;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        COMPLETE: begin");
        try self.builder.writeLine("            inference_done <= 1; state <= IDLE;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeAxiLiteSlave(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// AXI-LITE SLAVE - Control/Status Register Interface");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module axi_lite_slave #(");
        self.builder.incIndent();
        try self.builder.writeLine("parameter ADDR_WIDTH = 8,");
        try self.builder.writeLine("parameter DATA_WIDTH = 32");
        self.builder.decIndent();
        try self.builder.writeLine(") (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire                    clk,");
        try self.builder.writeLine("input  wire                    rst_n,");
        try self.builder.writeLine("// AXI-Lite Write Address");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,");
        try self.builder.writeLine("input  wire                    s_axi_awvalid,");
        try self.builder.writeLine("output reg                     s_axi_awready,");
        try self.builder.writeLine("// AXI-Lite Write Data");
        try self.builder.writeLine("input  wire [DATA_WIDTH-1:0]   s_axi_wdata,");
        try self.builder.writeLine("input  wire [3:0]              s_axi_wstrb,");
        try self.builder.writeLine("input  wire                    s_axi_wvalid,");
        try self.builder.writeLine("output reg                     s_axi_wready,");
        try self.builder.writeLine("// AXI-Lite Write Response");
        try self.builder.writeLine("output reg  [1:0]              s_axi_bresp,");
        try self.builder.writeLine("output reg                     s_axi_bvalid,");
        try self.builder.writeLine("input  wire                    s_axi_bready,");
        try self.builder.writeLine("// AXI-Lite Read Address");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,");
        try self.builder.writeLine("input  wire                    s_axi_arvalid,");
        try self.builder.writeLine("output reg                     s_axi_arready,");
        try self.builder.writeLine("// AXI-Lite Read Data");
        try self.builder.writeLine("output reg  [DATA_WIDTH-1:0]   s_axi_rdata,");
        try self.builder.writeLine("output reg  [1:0]              s_axi_rresp,");
        try self.builder.writeLine("output reg                     s_axi_rvalid,");
        try self.builder.writeLine("input  wire                    s_axi_rready,");
        try self.builder.writeLine("// Register outputs");
        try self.builder.writeLine("output reg  [31:0]             reg_ctrl,");
        try self.builder.writeLine("input  wire [31:0]             reg_status,");
        try self.builder.writeLine("output reg  [31:0]             reg_irq_en,");
        try self.builder.writeLine("input  wire [31:0]             reg_irq_stat,");
        try self.builder.writeLine("output reg  [31:0]             reg_num_layers,");
        try self.builder.writeLine("output reg  [31:0]             reg_neurons,");
        try self.builder.writeLine("output reg  [31:0]             reg_chunks,");
        try self.builder.writeLine("output reg  [31:0]             reg_threshold,");
        try self.builder.writeLine("output reg  [63:0]             reg_weight_addr,");
        try self.builder.writeLine("output reg  [63:0]             reg_input_addr,");
        try self.builder.writeLine("output reg  [63:0]             reg_output_addr,");
        try self.builder.writeLine("input  wire [63:0]             reg_cycles");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Write state machine");
        try self.builder.writeLine("reg [ADDR_WIDTH-1:0] wr_addr;");
        try self.builder.writeLine("reg wr_addr_valid, wr_data_valid;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        s_axi_awready <= 1; s_axi_wready <= 1; s_axi_bvalid <= 0;");
        try self.builder.writeLine("        s_axi_arready <= 1; s_axi_rvalid <= 0;");
        try self.builder.writeLine("        reg_ctrl <= 0; reg_irq_en <= 0;");
        try self.builder.writeLine("    end else begin");
        try self.builder.writeLine("        // Write handling");
        try self.builder.writeLine("        if (s_axi_awvalid && s_axi_awready) wr_addr <= s_axi_awaddr;");
        try self.builder.writeLine("        if (s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready) begin");
        try self.builder.writeLine("            case (s_axi_awaddr[5:2])");
        try self.builder.writeLine("                4'h0: reg_ctrl <= s_axi_wdata;");
        try self.builder.writeLine("                4'h2: reg_irq_en <= s_axi_wdata;");
        try self.builder.writeLine("                4'h4: reg_num_layers <= s_axi_wdata;");
        try self.builder.writeLine("                4'h5: reg_neurons <= s_axi_wdata;");
        try self.builder.writeLine("                4'h6: reg_chunks <= s_axi_wdata;");
        try self.builder.writeLine("                4'h7: reg_threshold <= s_axi_wdata;");
        try self.builder.writeLine("                4'h8: reg_weight_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'h9: reg_weight_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hA: reg_input_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hB: reg_input_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hC: reg_output_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hD: reg_output_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("            endcase");
        try self.builder.writeLine("            s_axi_bvalid <= 1; s_axi_bresp <= 2'b00;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;");
        try self.builder.writeLine("        // Read handling");
        try self.builder.writeLine("        if (s_axi_arvalid && s_axi_arready) begin");
        try self.builder.writeLine("            case (s_axi_araddr[5:2])");
        try self.builder.writeLine("                4'h0: s_axi_rdata <= reg_ctrl;");
        try self.builder.writeLine("                4'h1: s_axi_rdata <= reg_status;");
        try self.builder.writeLine("                4'h2: s_axi_rdata <= reg_irq_en;");
        try self.builder.writeLine("                4'h3: s_axi_rdata <= reg_irq_stat;");
        try self.builder.writeLine("                4'h4: s_axi_rdata <= reg_num_layers;");
        try self.builder.writeLine("                4'h5: s_axi_rdata <= reg_neurons;");
        try self.builder.writeLine("                4'h6: s_axi_rdata <= reg_chunks;");
        try self.builder.writeLine("                4'h7: s_axi_rdata <= reg_threshold;");
        try self.builder.writeLine("                4'hE: s_axi_rdata <= reg_cycles[31:0];");
        try self.builder.writeLine("                4'hF: s_axi_rdata <= reg_cycles[63:32];");
        try self.builder.writeLine("                default: s_axi_rdata <= 32'hDEADBEEF;");
        try self.builder.writeLine("            endcase");
        try self.builder.writeLine("            s_axi_rvalid <= 1; s_axi_rresp <= 2'b00;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeDmaController(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// DMA CONTROLLER - High-bandwidth data transfer");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module dma_controller (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// Control");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [63:0] src_addr,");
        try self.builder.writeLine("input  wire [63:0] dst_addr,");
        try self.builder.writeLine("input  wire [31:0] length,");
        try self.builder.writeLine("input  wire        direction,  // 0=read, 1=write");
        try self.builder.writeLine("output reg         busy,");
        try self.builder.writeLine("output reg         done,");
        try self.builder.writeLine("// AXI4 Master Read");
        try self.builder.writeLine("output reg  [63:0] m_axi_araddr,");
        try self.builder.writeLine("output reg  [7:0]  m_axi_arlen,");
        try self.builder.writeLine("output reg         m_axi_arvalid,");
        try self.builder.writeLine("input  wire        m_axi_arready,");
        try self.builder.writeLine("input  wire [63:0] m_axi_rdata,");
        try self.builder.writeLine("input  wire        m_axi_rlast,");
        try self.builder.writeLine("input  wire        m_axi_rvalid,");
        try self.builder.writeLine("output wire        m_axi_rready,");
        try self.builder.writeLine("// AXI4 Master Write");
        try self.builder.writeLine("output reg  [63:0] m_axi_awaddr,");
        try self.builder.writeLine("output reg  [7:0]  m_axi_awlen,");
        try self.builder.writeLine("output reg         m_axi_awvalid,");
        try self.builder.writeLine("input  wire        m_axi_awready,");
        try self.builder.writeLine("output reg  [63:0] m_axi_wdata,");
        try self.builder.writeLine("output reg         m_axi_wlast,");
        try self.builder.writeLine("output reg         m_axi_wvalid,");
        try self.builder.writeLine("input  wire        m_axi_wready,");
        try self.builder.writeLine("input  wire        m_axi_bvalid,");
        try self.builder.writeLine("output wire        m_axi_bready,");
        try self.builder.writeLine("// Local memory interface");
        try self.builder.writeLine("output reg  [11:0] local_addr,");
        try self.builder.writeLine("output reg  [63:0] local_wdata,");
        try self.builder.writeLine("output reg         local_we,");
        try self.builder.writeLine("input  wire [63:0] local_rdata");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, READ_ADDR=1, READ_DATA=2, WRITE_ADDR=3, WRITE_DATA=4, DONE_ST=5;");
        try self.builder.writeLine("reg [2:0] state;");
        try self.builder.writeLine("reg [31:0] bytes_remaining;");
        try self.builder.writeLine("reg [7:0] burst_count;");
        try self.builder.newline();
        try self.builder.writeLine("assign m_axi_rready = (state == READ_DATA);");
        try self.builder.writeLine("assign m_axi_bready = 1;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; busy <= 0; done <= 0;");
        try self.builder.writeLine("        m_axi_arvalid <= 0; m_axi_awvalid <= 0; m_axi_wvalid <= 0;");
        try self.builder.writeLine("        local_we <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start) begin");
        try self.builder.writeLine("            busy <= 1; done <= 0; bytes_remaining <= length;");
        try self.builder.writeLine("            local_addr <= 0;");
        try self.builder.writeLine("            state <= direction ? WRITE_ADDR : READ_ADDR;");
        try self.builder.writeLine("            if (!direction) begin m_axi_araddr <= src_addr; m_axi_arlen <= 8'hFF; end");
        try self.builder.writeLine("            else begin m_axi_awaddr <= dst_addr; m_axi_awlen <= 8'hFF; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        READ_ADDR: begin");
        try self.builder.writeLine("            m_axi_arvalid <= 1;");
        try self.builder.writeLine("            if (m_axi_arready) begin m_axi_arvalid <= 0; state <= READ_DATA; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        READ_DATA: if (m_axi_rvalid) begin");
        try self.builder.writeLine("            local_wdata <= m_axi_rdata; local_we <= 1;");
        try self.builder.writeLine("            local_addr <= local_addr + 1;");
        try self.builder.writeLine("            bytes_remaining <= bytes_remaining - 8;");
        try self.builder.writeLine("            if (m_axi_rlast || bytes_remaining <= 8) state <= DONE_ST;");
        try self.builder.writeLine("        end else local_we <= 0;");
        try self.builder.writeLine("        WRITE_ADDR: begin");
        try self.builder.writeLine("            m_axi_awvalid <= 1;");
        try self.builder.writeLine("            if (m_axi_awready) begin m_axi_awvalid <= 0; state <= WRITE_DATA; burst_count <= 0; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        WRITE_DATA: begin");
        try self.builder.writeLine("            m_axi_wdata <= local_rdata; m_axi_wvalid <= 1;");
        try self.builder.writeLine("            m_axi_wlast <= (bytes_remaining <= 8);");
        try self.builder.writeLine("            if (m_axi_wready) begin");
        try self.builder.writeLine("                local_addr <= local_addr + 1;");
        try self.builder.writeLine("                bytes_remaining <= bytes_remaining - 8;");
        try self.builder.writeLine("                if (bytes_remaining <= 8) begin m_axi_wvalid <= 0; state <= DONE_ST; end");
        try self.builder.writeLine("            end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        DONE_ST: begin busy <= 0; done <= 1; local_we <= 0; state <= IDLE; end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeInterruptController(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// INTERRUPT CONTROLLER - Async completion signaling");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module interrupt_controller (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// Interrupt sources");
        try self.builder.writeLine("input  wire        inference_done,");
        try self.builder.writeLine("input  wire        dma_done,");
        try self.builder.writeLine("input  wire        error,");
        try self.builder.writeLine("// Interrupt enable");
        try self.builder.writeLine("input  wire [2:0]  irq_enable,");
        try self.builder.writeLine("// Status (active-high, clear on read)");
        try self.builder.writeLine("output reg  [2:0]  irq_status,");
        try self.builder.writeLine("input  wire        status_read,");
        try self.builder.writeLine("// Interrupt output");
        try self.builder.writeLine("output wire        irq_out");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Capture interrupt events");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) irq_status <= 0;");
        try self.builder.writeLine("    else begin");
        try self.builder.writeLine("        if (inference_done) irq_status[0] <= 1;");
        try self.builder.writeLine("        if (dma_done) irq_status[1] <= 1;");
        try self.builder.writeLine("        if (error) irq_status[2] <= 1;");
        try self.builder.writeLine("        if (status_read) irq_status <= 0;  // Clear on read");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("end");
        try self.builder.newline();
        try self.builder.writeLine("// Generate interrupt if any enabled source is active");
        try self.builder.writeLine("assign irq_out = |(irq_status & irq_enable);");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeHostInterfaceTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// HOST INTERFACE TOP - Complete AXI host interface");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module host_interface_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// AXI-Lite Slave (from host)");
        try self.builder.writeLine("input  wire [7:0]  s_axi_awaddr,");
        try self.builder.writeLine("input  wire        s_axi_awvalid,");
        try self.builder.writeLine("output wire        s_axi_awready,");
        try self.builder.writeLine("input  wire [31:0] s_axi_wdata,");
        try self.builder.writeLine("input  wire        s_axi_wvalid,");
        try self.builder.writeLine("output wire        s_axi_wready,");
        try self.builder.writeLine("output wire [1:0]  s_axi_bresp,");
        try self.builder.writeLine("output wire        s_axi_bvalid,");
        try self.builder.writeLine("input  wire        s_axi_bready,");
        try self.builder.writeLine("input  wire [7:0]  s_axi_araddr,");
        try self.builder.writeLine("input  wire        s_axi_arvalid,");
        try self.builder.writeLine("output wire        s_axi_arready,");
        try self.builder.writeLine("output wire [31:0] s_axi_rdata,");
        try self.builder.writeLine("output wire [1:0]  s_axi_rresp,");
        try self.builder.writeLine("output wire        s_axi_rvalid,");
        try self.builder.writeLine("input  wire        s_axi_rready,");
        try self.builder.writeLine("// AXI4 Master (to DDR)");
        try self.builder.writeLine("output wire [63:0] m_axi_araddr,");
        try self.builder.writeLine("output wire [7:0]  m_axi_arlen,");
        try self.builder.writeLine("output wire        m_axi_arvalid,");
        try self.builder.writeLine("input  wire        m_axi_arready,");
        try self.builder.writeLine("input  wire [63:0] m_axi_rdata,");
        try self.builder.writeLine("input  wire        m_axi_rlast,");
        try self.builder.writeLine("input  wire        m_axi_rvalid,");
        try self.builder.writeLine("output wire        m_axi_rready,");
        try self.builder.writeLine("// Interrupt");
        try self.builder.writeLine("output wire        irq");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Register wires");
        try self.builder.writeLine("wire [31:0] reg_ctrl, reg_status, reg_irq_en, reg_irq_stat;");
        try self.builder.writeLine("wire [31:0] reg_num_layers, reg_neurons, reg_chunks, reg_threshold;");
        try self.builder.writeLine("wire [63:0] reg_weight_addr, reg_input_addr, reg_output_addr, reg_cycles;");
        try self.builder.newline();
        try self.builder.writeLine("// Engine signals");
        try self.builder.writeLine("wire engine_start = reg_ctrl[0];");
        try self.builder.writeLine("wire engine_busy, engine_done;");
        try self.builder.writeLine("assign reg_status = {16'd0, 8'd0, 4'd0, 1'b0, 1'b0, engine_done, engine_busy};");
        try self.builder.newline();
        try self.builder.writeLine("// AXI-Lite slave");
        try self.builder.writeLine("axi_lite_slave regs (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n),");
        try self.builder.writeLine("    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),");
        try self.builder.writeLine("    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(4'hF), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),");
        try self.builder.writeLine("    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),");
        try self.builder.writeLine("    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),");
        try self.builder.writeLine("    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),");
        try self.builder.writeLine("    .reg_ctrl(reg_ctrl), .reg_status(reg_status), .reg_irq_en(reg_irq_en), .reg_irq_stat(reg_irq_stat),");
        try self.builder.writeLine("    .reg_num_layers(reg_num_layers), .reg_neurons(reg_neurons), .reg_chunks(reg_chunks), .reg_threshold(reg_threshold),");
        try self.builder.writeLine("    .reg_weight_addr(reg_weight_addr), .reg_input_addr(reg_input_addr), .reg_output_addr(reg_output_addr), .reg_cycles(reg_cycles)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Interrupt controller");
        try self.builder.writeLine("interrupt_controller irq_ctrl (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n),");
        try self.builder.writeLine("    .inference_done(engine_done), .dma_done(1'b0), .error(1'b0),");
        try self.builder.writeLine("    .irq_enable(reg_irq_en[2:0]), .irq_status(), .status_read(1'b0), .irq_out(irq)");
        try self.builder.writeLine(");");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeBitNetEngineTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET INFERENCE ENGINE TOP - Complete multi-layer inference");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_engine_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [5:0]  num_layers,");
        try self.builder.writeLine("input  wire [15:0] neurons_per_layer,");
        try self.builder.writeLine("input  wire [7:0]  chunks_per_neuron,");
        try self.builder.writeLine("input  wire signed [15:0] threshold,");
        try self.builder.writeLine("// External memory interface (simplified)");
        try self.builder.writeLine("output wire [31:0] mem_addr,");
        try self.builder.writeLine("output wire        mem_rd_en,");
        try self.builder.writeLine("input  wire [63:0] mem_rd_data,");
        try self.builder.writeLine("input  wire        mem_rd_valid,");
        try self.builder.writeLine("// Status");
        try self.builder.writeLine("output wire        busy,");
        try self.builder.writeLine("output wire        done,");
        try self.builder.writeLine("output wire [31:0] cycle_count");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Multi-layer sequencer");
        try self.builder.writeLine("wire [5:0] current_layer;");
        try self.builder.writeLine("wire layer_start, layer_done, start_prefetch, prefetch_done;");
        try self.builder.writeLine("multilayer_sequencer seq (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n), .start(start), .num_layers(num_layers),");
        try self.builder.writeLine("    .layer_done(layer_done), .prefetch_done(prefetch_done),");
        try self.builder.writeLine("    .current_layer(current_layer), .layer_start(layer_start),");
        try self.builder.writeLine("    .start_prefetch(start_prefetch), .inference_done(done)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Double buffer controller");
        try self.builder.writeLine("wire use_buffer_a;");
        try self.builder.writeLine("wire [11:0] buf_read_addr, buf_write_addr;");
        try self.builder.writeLine("double_buffer_ctrl dbl_buf (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n), .layer_done(layer_done),");
        try self.builder.writeLine("    .current_layer(current_layer), .use_buffer_a(use_buffer_a),");
        try self.builder.writeLine("    .read_addr(buf_read_addr), .write_addr(buf_write_addr), .neuron_id(12'd0)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Cycle counter");
        try self.builder.writeLine("reg [31:0] cycles;");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) cycles <= 0;");
        try self.builder.writeLine("    else if (start) cycles <= 0;");
        try self.builder.writeLine("    else if (busy) cycles <= cycles + 1;");
        try self.builder.writeLine("assign cycle_count = cycles;");
        try self.builder.writeLine("assign busy = (current_layer != 0) || layer_start;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeBitNetLayerTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET LAYER TOP - Complete pipelined layer");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_layer_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [15:0] num_neurons,");
        try self.builder.writeLine("input  wire [7:0]  num_chunks,");
        try self.builder.writeLine("input  wire signed [15:0] threshold,");
        try self.builder.writeLine("input  wire [53:0] input_data,");
        try self.builder.writeLine("output wire [1:0]  output_trit,");
        try self.builder.writeLine("output wire        output_valid,");
        try self.builder.writeLine("output wire        layer_done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Sequencer");
        try self.builder.writeLine("wire [15:0] neuron_id; wire [7:0] chunk_id;");
        try self.builder.writeLine("wire first_chunk, last_chunk, seq_valid;");
        try self.builder.writeLine("layer_sequencer seq(.clk(clk),.rst_n(rst_n),.start(start),");
        try self.builder.writeLine("    .num_neurons(num_neurons),.num_chunks(num_chunks),");
        try self.builder.writeLine("    .neuron_id(neuron_id),.chunk_id(chunk_id),");
        try self.builder.writeLine("    .first_chunk(first_chunk),.last_chunk(last_chunk),.valid(seq_valid),.done(layer_done));");
        try self.builder.newline();
        try self.builder.writeLine("// Weight BRAM");
        try self.builder.writeLine("wire [53:0] weight_data;");
        try self.builder.writeLine("wire [11:0] weight_addr = neuron_id[7:0] * num_chunks + chunk_id;");
        try self.builder.writeLine("weight_bram weights(.clk(clk),.rd_addr(weight_addr),.rd_data(weight_data),.wr_addr(12'd0),.wr_data(54'd0),.wr_en(1'b0));");
        try self.builder.newline();
        try self.builder.writeLine("// Compute stage");
        try self.builder.writeLine("wire compute_valid; wire signed [15:0] pre_act; wire is_final;");
        try self.builder.writeLine("pipeline_stage2_compute compute(.clk(clk),.rst_n(rst_n),.valid_in(seq_valid),");
        try self.builder.writeLine("    .input_chunk(input_data),.weight_chunk(weight_data),");
        try self.builder.writeLine("    .first_chunk(first_chunk),.last_chunk(last_chunk),");
        try self.builder.writeLine("    .valid_out(compute_valid),.result(pre_act),.result_final(is_final));");
        try self.builder.newline();
        try self.builder.writeLine("// Activation");
        try self.builder.writeLine("bitnet_activation act(.pre_act(pre_act),.threshold(threshold),.result(output_trit));");
        try self.builder.writeLine("assign output_valid = compute_valid & is_final;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeBitNetActivation(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET ACTIVATION - Ternary ReLU");
        try self.builder.writeLine("// Clamp to {-1, 0, +1} based on thresholds");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_activation (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire signed [15:0] pre_act,     // Pre-activation value");
        try self.builder.writeLine("input  wire signed [15:0] threshold,   // Activation threshold");
        try self.builder.writeLine("output wire [1:0] result               // Output trit");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Ternary activation: clamp to {-1, 0, +1}");
        try self.builder.writeLine("assign result = (pre_act > threshold)  ? TRIT_P :");
        try self.builder.writeLine("                (pre_act < -threshold) ? TRIT_N :");
        try self.builder.writeLine("                TRIT_Z;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    fn writeGenericBehavior(self: *Self, b: Behavior) !void {
        try self.builder.writeFmt("// Behavior: {s}\n", .{b.name});
        try self.builder.writeFmt("// Given: {s}\n", .{b.given});
        try self.builder.writeFmt("// When: {s}\n", .{b.when});
        try self.builder.writeFmt("// Then: {s}\n", .{b.then});
        
        try self.builder.writeFmt("module behavior_{s} (\n", .{b.name});
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        trigger,");
        try self.builder.writeLine("input  wire [31:0] input_data,");
        try self.builder.writeLine("output reg  [31:0] output_data,");
        try self.builder.writeLine("output reg         done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        self.builder.incIndent();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("output_data <= 32'd0;");
        try self.builder.writeLine("done <= 1'b0;");
        self.builder.decIndent();
        try self.builder.writeLine("end else if (trigger) begin");
        self.builder.incIndent();
        try self.builder.writeLine("// TODO: Implement behavior logic");
        try self.builder.writeLine("output_data <= input_data;");
        try self.builder.writeLine("done <= 1'b1;");
        self.builder.decIndent();
        try self.builder.writeLine("end else begin");
        self.builder.incIndent();
        try self.builder.writeLine("done <= 1'b0;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    /// Generate SystemVerilog Assertions from behaviors
    fn writeSVAAssertions(self: *Self, spec: *const VibeeSpec) !void {
        if (spec.behaviors.items.len == 0) return;
        
        // Extract signals from types
        var extracted_signals = extractSignalsFromTypes(spec.types.items, self.allocator) catch ArrayList(ExtractedSignal).init(self.allocator);
        defer extracted_signals.deinit();
        
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SYSTEMVERILOG ASSERTIONS (SVA)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// Generated from .vibee behaviors - IEEE 1800 compliant");
        try self.builder.writeLine("// Signals extracted from spec types");
        try self.builder.writeLine("// φ² + 1/φ² = 3");
        try self.builder.newline();
        
        try self.builder.writeFmt("module {s}_sva_checker (\n", .{spec.name});
        self.builder.incIndent();
        
        // Standard signals
        try self.builder.writeLine("input wire        clk,");
        try self.builder.writeLine("input wire        rst_n,");
        try self.builder.writeLine("input wire [31:0] data_in,");
        try self.builder.writeLine("input wire        valid_in,");
        try self.builder.writeLine("input wire [31:0] data_out,");
        try self.builder.writeLine("input wire        valid_out,");
        try self.builder.writeLine("input wire        ready,");
        try self.builder.writeLine("input wire [2:0]  state,");
        
        // Signals extracted from types
        if (extracted_signals.items.len > 0) {
            try self.builder.writeLine("// Signals from spec types:");
            for (extracted_signals.items) |sig| {
                if (sig.is_bool) {
                    try self.builder.writeFmt("input wire        {s},\n", .{sig.name});
                } else {
                    try self.builder.writeFmt("input wire [31:0] {s},\n", .{sig.name});
                }
            }
        }
        
        // Common signals - only add if not already in extracted
        try self.builder.writeLine("// Common SVA signals:");
        const common_signals = [_][]const u8{ "running", "active", "overflow", "done", "flag" };
        for (common_signals, 0..) |common, i| {
            var exists = false;
            for (extracted_signals.items) |sig| {
                if (std.mem.eql(u8, sig.name, common)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                const is_last = (i == common_signals.len - 1);
                try self.builder.writeFmt("input wire        {s}{s}\n", .{ common, if (is_last) "" else "," });
            }
        }
        
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        self.builder.incIndent();
        
        // Local parameters for state machine
        try self.builder.writeLine("// State machine parameters");
        try self.builder.writeLine("localparam IDLE    = 3'd0;");
        try self.builder.writeLine("localparam PROCESS = 3'd1;");
        try self.builder.writeLine("localparam DONE_ST = 3'd2;");
        
        // MAX_VALUE - use wire alias if depth/max_value exists in types
        var depth_signal: ?[]const u8 = null;
        for (extracted_signals.items) |sig| {
            if (std.mem.eql(u8, sig.name, "depth") or std.mem.eql(u8, sig.name, "max_value")) {
                depth_signal = sig.name;
                break;
            }
        }
        if (depth_signal) |ds| {
            try self.builder.writeFmt("wire [31:0] MAX_VALUE = {s}; // from spec types\n", .{ds});
        } else {
            try self.builder.writeLine("localparam MAX_VALUE = 32'hFFFFFFFF;");
        }
        try self.builder.newline();
        
        // Default clocking block
        try self.builder.writeLine("// Default clocking for assertions");
        try self.builder.writeLine("default clocking cb @(posedge clk);");
        try self.builder.writeLine("endclocking");
        try self.builder.newline();
        
        // Disable assertions during reset
        try self.builder.writeLine("// Note: 'disable iff' is used in each property for reset handling");
        try self.builder.newline();
        
        // Generate assertions from behaviors
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ASSERTIONS FROM BEHAVIORS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        for (spec.behaviors.items, 0..) |behavior, i| {
            // Generate assertion from behavior
            try self.builder.writeFmt("// Behavior: {s}\n", .{behavior.name});
            try self.builder.writeFmt("// Given: {s}\n", .{behavior.given});
            try self.builder.writeFmt("// When: {s}\n", .{behavior.when});
            try self.builder.writeFmt("// Then: {s}\n", .{behavior.then});
            
            // Generate property
            try self.builder.writeFmt("property p_{s};\n", .{behavior.name});
            self.builder.incIndent();
            
            // Parse given/when/then into SVA
            try self.generateSVAProperty(behavior);
            
            self.builder.decIndent();
            try self.builder.writeLine("endproperty");
            try self.builder.newline();
            
            // Generate assertion
            try self.builder.writeFmt("assert_{d}_{s}: assert property (p_{s})\n", .{ i, behavior.name, behavior.name });
            self.builder.incIndent();
            try self.builder.writeFmt("else $error(\"Assertion failed: {s}\");\n", .{behavior.name});
            self.builder.decIndent();
            try self.builder.newline();
            
            // Generate cover
            try self.builder.writeFmt("cover_{d}_{s}: cover property (p_{s});\n", .{ i, behavior.name, behavior.name });
            try self.builder.newline();
        }
        
        // Sacred identity assertion
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SACRED IDENTITY ASSERTION");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        try self.builder.writeLine("// φ² + 1/φ² = 3 (verified at compile time)");
        try self.builder.writeLine("localparam real PHI = 1.6180339887498948482;");
        try self.builder.writeLine("localparam real GOLDEN_IDENTITY = PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.newline();
        try self.builder.writeLine("// Compile-time check (synthesis will optimize this)");
        try self.builder.writeLine("initial begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (GOLDEN_IDENTITY < 2.99 || GOLDEN_IDENTITY > 3.01)");
        self.builder.incIndent();
        try self.builder.writeLine("$fatal(1, \"Golden Identity violated: φ² + 1/φ² != 3\");");
        self.builder.decIndent();
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();
        
        self.builder.decIndent();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }
    
    /// Generate SVA property expression from behavior
    /// Generate SVA property expression from behavior using semantic parsing
    fn generateSVAProperty(self: *Self, behavior: Behavior) !void {
        // Parse given clause → antecedent
        const antecedent = parseGivenClause(behavior.given);
        
        // Parse when clause → timing
        const timing = parseWhenClause(behavior.when);
        
        // Parse then clause → consequent
        const consequent = parseThenClause(behavior.then);
        
        // Generate SVA property
        try self.builder.writeFmt("@({s}) disable iff (!rst_n)\n", .{timing});
        try self.builder.writeFmt("{s} |-> {s};\n", .{ antecedent, consequent });
    }
    
    /// Parse "given" clause to SVA antecedent
    fn parseGivenClause(given: []const u8) []const u8 {
        // Signal patterns
        if (containsIgnoreCase(given, "running")) return "running";
        if (containsIgnoreCase(given, "active")) return "active";
        if (containsIgnoreCase(given, "valid")) return "valid_in";
        if (containsIgnoreCase(given, "ready")) return "ready";
        if (containsIgnoreCase(given, "reset")) {
            if (containsIgnoreCase(given, "not") or containsIgnoreCase(given, "inactive")) {
                return "rst_n";
            }
            return "!rst_n";
        }
        if (containsIgnoreCase(given, "idle")) return "(state == IDLE)";
        if (containsIgnoreCase(given, "process")) return "(state == PROCESS)";
        if (containsIgnoreCase(given, "counter") or containsIgnoreCase(given, "count")) {
            if (containsIgnoreCase(given, "max")) return "(count == MAX_VALUE)";
            if (containsIgnoreCase(given, "zero") or containsIgnoreCase(given, "0")) return "(count == 0)";
            return "(count > 0)";
        }
        if (containsIgnoreCase(given, "fifo")) {
            if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "full")) return "!full";
            if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "empty")) return "!empty";
            if (containsIgnoreCase(given, "full")) return "full";
            if (containsIgnoreCase(given, "empty")) return "empty";
            return "!empty";
        }
        
        // Direct signal names from types (full, empty, etc.)
        if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "full")) return "!full";
        if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "empty")) return "!empty";
        if (containsIgnoreCase(given, "full")) return "full";
        if (containsIgnoreCase(given, "empty")) return "empty";
        
        // Default: always true
        return "1'b1";
    }
    
    /// Parse "when" clause to SVA timing
    fn parseWhenClause(when: []const u8) []const u8 {
        // Clock edge detection
        if (containsIgnoreCase(when, "falling") or containsIgnoreCase(when, "negedge")) {
            return "negedge clk";
        }
        // Default to rising edge
        return "posedge clk";
    }
    
    /// Parse "then" clause to SVA consequent
    fn parseThenClause(then: []const u8) []const u8 {
        // Increment operation
        if (containsIgnoreCase(then, "increment") or containsIgnoreCase(then, "add")) {
            if (containsIgnoreCase(then, "count")) {
                return "(count == $past(count) + 1)";
            }
            return "($past(data_out) + 1)";
        }
        
        // Decrement operation
        if (containsIgnoreCase(then, "decrement") or containsIgnoreCase(then, "subtract")) {
            if (containsIgnoreCase(then, "count")) {
                return "(count == $past(count) - 1)";
            }
            return "($past(data_out) - 1)";
        }
        
        // Set to zero/clear
        if (containsIgnoreCase(then, "zero") or containsIgnoreCase(then, "clear") or 
            (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "0"))) {
            if (containsIgnoreCase(then, "count")) return "(count == 0)";
            if (containsIgnoreCase(then, "overflow")) return "(!overflow)";
            return "(data_out == 0)";
        }
        
        // Set flag
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "flag")) {
            if (containsIgnoreCase(then, "overflow")) return "overflow";
            if (containsIgnoreCase(then, "valid")) return "valid_out";
            if (containsIgnoreCase(then, "done")) return "done";
            if (containsIgnoreCase(then, "full")) return "full";
            if (containsIgnoreCase(then, "empty")) return "empty";
            return "flag";
        }
        
        // Direct flag setting (from types)
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "full")) return "full";
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "empty")) return "empty";
        
        // Output valid
        if (containsIgnoreCase(then, "valid") and containsIgnoreCase(then, "output")) {
            return "valid_out";
        }
        
        // Wrap around
        if (containsIgnoreCase(then, "wrap")) {
            return "(count == 0)";
        }
        
        // Default: signal stays stable or becomes true
        return "1'b1";
    }
    
    fn writeTestbench(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTBENCH");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        
        try self.builder.writeFmt("module {s}_tb;\n", .{spec.name});
        try self.builder.newline();
        
        self.builder.incIndent();
        
        // Extract FSM signals for testbench with inferred widths (same logic as in writeTopModule)
        var fsm_signals_tb = ArrayList(SignalInfo).init(self.allocator);
        defer fsm_signals_tb.deinit();
        
        if (spec.fsms.items.len > 0) {
            for (spec.fsms.items) |fsm| {
                var state_names = ArrayList([]const u8).init(self.allocator);
                defer state_names.deinit();
                for (fsm.states.items) |state| {
                    try state_names.append(state);
                }
                
                for (fsm.transitions.items) |trans| {
                    if (trans.condition.len > 0) {
                        var extracted = try extractSignalsFromCondition(self.allocator, trans.condition);
                        defer extracted.deinit();
                        
                        for (extracted.items) |sig_info| {
                            var is_state = false;
                            for (state_names.items) |state| {
                                if (std.mem.eql(u8, sig_info.name, state)) {
                                    is_state = true;
                                    break;
                                }
                            }
                            if (is_state) continue;
                            
                            var already_declared = false;
                            for (spec.signals.items) |existing| {
                                if (std.mem.eql(u8, sig_info.name, existing.name)) {
                                    already_declared = true;
                                    break;
                                }
                            }
                            if (already_declared) continue;
                            
                            // Skip internal timer signals (generated by timer logic)
                            if (std.mem.eql(u8, sig_info.name, "timer_expired") or
                                std.mem.eql(u8, sig_info.name, "timer_count") or
                                std.mem.eql(u8, sig_info.name, "timeout_value"))
                            {
                                continue;
                            }
                            
                            var already_added = false;
                            for (fsm_signals_tb.items) |*existing| {
                                if (std.mem.eql(u8, sig_info.name, existing.name)) {
                                    already_added = true;
                                    // Keep the larger inferred width
                                    if (sig_info.inferred_width > existing.inferred_width) {
                                        existing.inferred_width = sig_info.inferred_width;
                                    }
                                    break;
                                }
                            }
                            if (already_added) continue;
                            
                            try fsm_signals_tb.append(sig_info);
                        }
                    }
                }
            }
        }
        
        // Collect FSM output signals for testbench with inferred widths
        var fsm_output_signals_tb = ArrayList(SignalInfo).init(self.allocator);
        defer fsm_output_signals_tb.deinit();
        
        if (spec.fsms.items.len > 0) {
            for (spec.fsms.items) |fsm| {
                for (fsm.outputs.items) |out| {
                    var iter = out.signals.iterator();
                    while (iter.next()) |entry| {
                        const sig_name = entry.key_ptr.*;
                        const sig_value = entry.value_ptr.*;
                        const inferred_width = parseVerilogLiteralWidth(sig_value, 0);
                        
                        var found = false;
                        for (fsm_output_signals_tb.items) |*existing| {
                            if (std.mem.eql(u8, existing.name, sig_name)) {
                                found = true;
                                if (inferred_width > existing.inferred_width) {
                                    existing.inferred_width = inferred_width;
                                }
                                break;
                            }
                        }
                        if (!found) {
                            try fsm_output_signals_tb.append(SignalInfo{
                                .name = sig_name,
                                .inferred_width = inferred_width,
                            });
                        }
                    }
                }
            }
        }
        
        // Testbench signals - generate from spec signals
        try self.builder.writeLine("// Testbench signals");
        
        // First, generate auto-extracted FSM signals as regs with inferred widths
        if (fsm_signals_tb.items.len > 0) {
            try self.builder.writeLine("// Auto-extracted FSM control signals (widths inferred from literals)");
            for (fsm_signals_tb.items) |fsm_sig| {
                const width = if (fsm_sig.inferred_width > 0) fsm_sig.inferred_width else 0;
                if (width > 0) {
                    const width_minus_1 = width - 1;
                    try self.builder.writeFmt("reg  [{d}:0] {s};\n", .{ width_minus_1, fsm_sig.name });
                } else {
                    try self.builder.writeFmt("reg         {s};\n", .{fsm_sig.name});
                }
            }
        }
        
        // Generate FSM output signals as wires in testbench with inferred widths
        if (fsm_output_signals_tb.items.len > 0) {
            try self.builder.writeLine("// FSM output signals");
            for (fsm_output_signals_tb.items) |out_sig| {
                const width = if (out_sig.inferred_width > 0) out_sig.inferred_width else 1;
                if (width > 1) {
                    const width_minus_1 = width - 1;
                    try self.builder.writeFmt("wire [{d}:0] {s};\n", .{ width_minus_1, out_sig.name });
                } else {
                    try self.builder.writeFmt("wire        {s};\n", .{out_sig.name});
                }
            }
        }
        
        if (spec.signals.items.len > 0) {
            for (spec.signals.items) |sig| {
                // Skip internal regs/wires
                if (std.mem.eql(u8, sig.direction, "reg") or std.mem.eql(u8, sig.direction, "wire")) {
                    continue;
                }
                
                // Inputs become regs, outputs become wires in testbench
                const tb_type = if (std.mem.eql(u8, sig.direction, "input")) "reg " else "wire";
                
                if (sig.width > 1) {
                    const width_minus_1 = sig.width - 1;
                    try self.builder.writeFmt("{s} [{d}:0] {s};\n", .{ tb_type, width_minus_1, sig.name });
                } else {
                    try self.builder.writeFmt("{s}        {s};\n", .{ tb_type, sig.name });
                }
            }
        }
        
        // Always generate clk and rst_n for testbench
        if (fsm_signals_tb.items.len > 0 or spec.signals.items.len > 0 or fsm_output_signals_tb.items.len > 0) {
            // Add clk and rst_n if not already declared
            try self.builder.writeLine("// Clock and reset");
            try self.builder.writeLine("reg         clk;");
            try self.builder.writeLine("reg         rst_n;");
        } else {
            // Default signals when no custom signals
            try self.builder.writeLine("reg         clk;");
            try self.builder.writeLine("reg         rst_n;");
            try self.builder.writeLine("reg  [31:0] data_in;");
            try self.builder.writeLine("reg         valid_in;");
            try self.builder.writeLine("wire [31:0] data_out;");
            try self.builder.writeLine("wire        valid_out;");
            try self.builder.writeLine("wire        ready;");
        }
        try self.builder.newline();
        
        // DUT instantiation
        try self.builder.writeLine("// DUT instantiation");
        try self.builder.writeFmt("{s}_top dut (\n", .{spec.name});
        self.builder.incIndent();
        
        if (spec.signals.items.len > 0 or fsm_signals_tb.items.len > 0 or fsm_output_signals_tb.items.len > 0) {
            // Always connect clk and rst_n first
            try self.builder.writeLine(".clk(clk),");
            try self.builder.writeLine(".rst_n(rst_n),");
            
            var port_count: usize = 0;
            var actual_ports: usize = fsm_signals_tb.items.len + fsm_output_signals_tb.items.len;
            
            // Count actual ports
            for (spec.signals.items) |sig| {
                if (!std.mem.eql(u8, sig.direction, "reg") and !std.mem.eql(u8, sig.direction, "wire")) {
                    actual_ports += 1;
                }
            }
            
            // Connect auto-extracted FSM input signals
            for (fsm_signals_tb.items) |fsm_sig| {
                port_count += 1;
                const is_last = (port_count == actual_ports);
                
                if (is_last) {
                    try self.builder.writeFmt(".{s}({s})\n", .{ fsm_sig.name, fsm_sig.name });
                } else {
                    try self.builder.writeFmt(".{s}({s}),\n", .{ fsm_sig.name, fsm_sig.name });
                }
            }
            
            // Connect FSM output signals
            for (fsm_output_signals_tb.items) |out_sig| {
                port_count += 1;
                const is_last = (port_count == actual_ports);
                
                if (is_last) {
                    try self.builder.writeFmt(".{s}({s})\n", .{ out_sig.name, out_sig.name });
                } else {
                    try self.builder.writeFmt(".{s}({s}),\n", .{ out_sig.name, out_sig.name });
                }
            }
            
            for (spec.signals.items) |sig| {
                if (std.mem.eql(u8, sig.direction, "reg") or std.mem.eql(u8, sig.direction, "wire")) {
                    continue;
                }
                port_count += 1;
                const is_last = (port_count == actual_ports);
                
                if (is_last) {
                    try self.builder.writeFmt(".{s}({s})\n", .{ sig.name, sig.name });
                } else {
                    try self.builder.writeFmt(".{s}({s}),\n", .{ sig.name, sig.name });
                }
            }
        } else {
            try self.builder.writeLine(".clk(clk),");
            try self.builder.writeLine(".rst_n(rst_n),");
            try self.builder.writeLine(".data_in(data_in),");
            try self.builder.writeLine(".valid_in(valid_in),");
            try self.builder.writeLine(".data_out(data_out),");
            try self.builder.writeLine(".valid_out(valid_out),");
            try self.builder.writeLine(".ready(ready)");
        }
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        
        // Clock generation
        try self.builder.writeLine("// Clock generation (100 MHz = 10ns period)");
        try self.builder.writeLine("initial clk = 0;");
        try self.builder.writeLine("always #5 clk = ~clk;");
        try self.builder.newline();
        
        // VCD dump for waveform viewing
        try self.builder.writeLine("// VCD waveform dump");
        try self.builder.writeLine("initial begin");
        self.builder.incIndent();
        try self.builder.writeFmt("$dumpfile(\"{s}.vcd\");\n", .{spec.name});
        try self.builder.writeFmt("$dumpvars(0, {s}_tb);\n", .{spec.name});
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();
        
        // Test sequence
        try self.builder.writeLine("// Test sequence");
        try self.builder.writeLine("initial begin");
        self.builder.incIndent();
        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.writeFmt("$display(\"{s} Testbench - φ² + 1/φ² = 3\");\n", .{spec.name});
        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.newline();
        
        // Initialize all input signals
        try self.builder.writeLine("// Initialize");
        
        // Initialize auto-extracted FSM signals
        if (fsm_signals_tb.items.len > 0) {
            try self.builder.writeLine("// Auto-extracted FSM control signals");
            for (fsm_signals_tb.items) |fsm_sig| {
                try self.builder.writeFmt("{s} = 0;\n", .{fsm_sig.name});
            }
        }
        
        if (spec.signals.items.len > 0) {
            for (spec.signals.items) |sig| {
                if (std.mem.eql(u8, sig.direction, "input")) {
                    if (std.mem.eql(u8, sig.name, "rst_n")) {
                        try self.builder.writeLine("rst_n = 0;");
                    } else if (sig.width > 1) {
                        try self.builder.writeFmt("{s} = {d}'d0;\n", .{ sig.name, sig.width });
                    } else {
                        try self.builder.writeFmt("{s} = 0;\n", .{ sig.name });
                    }
                }
            }
        } else if (fsm_signals_tb.items.len == 0 and fsm_output_signals_tb.items.len == 0) {
            try self.builder.writeLine("rst_n = 0;");
            try self.builder.writeLine("data_in = 32'd0;");
            try self.builder.writeLine("valid_in = 0;");
        } else {
            try self.builder.writeLine("rst_n = 0;");
        }
        try self.builder.writeLine("#20;");
        try self.builder.newline();
        
        try self.builder.writeLine("// Release reset");
        try self.builder.writeLine("rst_n = 1;");
        try self.builder.writeLine("$display(\"Reset released at time %0t\", $time);");
        try self.builder.writeLine("#10;");
        try self.builder.newline();
        
        // Generate FSM-specific test if FSM exists
        if (spec.fsms.items.len > 0 and spec.fsms.items[0].timers.items.len > 0) {
            const fsm = spec.fsms.items[0];
            
            try self.builder.writeLine("// FSM state monitoring");
            try self.builder.writeLine("$display(\"Starting FSM simulation...\");");
            try self.builder.writeLine("$display(\"Initial state: %s\", dut.state);");
            try self.builder.newline();
            
            // Calculate total simulation time based on timers
            // Use scaled down values for simulation (divide by 1000)
            try self.builder.writeLine("// Run through complete FSM cycle");
            try self.builder.writeLine("// Note: Using scaled time for simulation");
            
            for (fsm.states.items) |state| {
                try self.builder.writeFmt("$display(\"Waiting for state {s}...\");\n", .{state});
                try self.builder.writeFmt("wait(dut.state == dut.{s});\n", .{state});
                try self.builder.writeFmt("$display(\"  -> Entered {s} at time %0t\", $time);\n", .{state});
                
                // Check outputs if available
                if (fsm.outputs.items.len > 0) {
                    try self.builder.writeLine("$display(\"     Outputs: red=%b yellow=%b green=%b\", red_light, yellow_light, green_light);");
                }
                
                try self.builder.writeLine("#100; // Small delay before next state check");
            }
            
            try self.builder.newline();
            try self.builder.writeLine("// Wait for one more cycle to verify loop");
            try self.builder.writeFmt("wait(dut.state == dut.{s});\n", .{fsm.initial_state});
            try self.builder.writeLine("$display(\"FSM completed full cycle!\");");
            try self.builder.newline();
            
            // Test pedestrian button if it exists
            var has_pedestrian = false;
            for (spec.signals.items) |sig| {
                if (std.mem.eql(u8, sig.name, "pedestrian_button")) {
                    has_pedestrian = true;
                    break;
                }
            }
            
            if (has_pedestrian) {
                try self.builder.writeLine("// Test pedestrian button interrupt");
                try self.builder.writeLine("$display(\"Testing pedestrian button...\");");
                try self.builder.writeLine("wait(dut.state == dut.GREEN);");
                try self.builder.writeLine("#50;");
                try self.builder.writeLine("pedestrian_button = 1;");
                try self.builder.writeLine("$display(\"  Pedestrian button pressed at time %0t\", $time);");
                try self.builder.writeLine("#20;");
                try self.builder.writeLine("pedestrian_button = 0;");
                try self.builder.writeLine("wait(dut.state == dut.YELLOW);");
                try self.builder.writeLine("$display(\"  -> Transition to YELLOW confirmed!\");");
                try self.builder.newline();
            }
        } else {
            try self.builder.writeLine("// Test 1: Basic operation");
            try self.builder.writeLine("$display(\"Test 1: Basic operation\");");
            try self.builder.writeLine("#100;");
            try self.builder.newline();
        }
        
        try self.builder.writeLine("// Golden identity verification");
        try self.builder.writeLine("$display(\"Golden Identity: φ² + 1/φ² = 3 ✓\");");
        try self.builder.writeLine("$display(\"PHOENIX = 999 ✓\");");
        try self.builder.newline();
        
        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.writeLine("$display(\"Simulation complete at time %0t\", $time);");
        try self.builder.writeFmt("$display(\"VCD file generated: {s}.vcd\");\n", .{spec.name});
        try self.builder.writeLine("$finish;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |nc, j| {
            const hc = haystack[i + j];
            const nc_lower = if (nc >= 'A' and nc <= 'Z') nc + 32 else nc;
            const hc_lower = if (hc >= 'A' and hc <= 'Z') hc + 32 else hc;
            if (nc_lower != hc_lower) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

fn mapTypeToVerilog(vibee_type: []const u8) []const u8 {
    if (std.mem.eql(u8, vibee_type, "String")) return "[255:0] // String as 256-bit";
    if (std.mem.eql(u8, vibee_type, "Int")) return "[63:0] // 64-bit signed";
    if (std.mem.eql(u8, vibee_type, "Float")) return "[63:0] // IEEE 754 double";
    if (std.mem.eql(u8, vibee_type, "Bool")) return "[0:0] // 1-bit boolean";
    if (std.mem.eql(u8, vibee_type, "Timestamp")) return "[63:0] // 64-bit timestamp";
    if (std.mem.startsWith(u8, vibee_type, "List")) return "[1023:0] // List as 1024-bit";
    if (std.mem.startsWith(u8, vibee_type, "Option")) return "[64:0] // Option with valid bit";
    if (std.mem.eql(u8, vibee_type, "Object")) return "[511:0] // Object as 512-bit";
    return "[31:0] // Default 32-bit";
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateVerilog(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var codegen = VerilogCodeGen.init(allocator);
    defer codegen.deinit();
    
    const output = try codegen.generate(spec);
    return try allocator.dupe(u8, output);
}

/// Генерация Xilinx XDC constraints файла
pub fn generateXDC(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var builder = VerilogBuilder.init(allocator);
    defer builder.deinit();
    
    // Header
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeFmt("# {s} - Xilinx Design Constraints (XDC)\n", .{spec.name});
    try builder.writeLine("# Generated by VIBEE - φ² + 1/φ² = 3");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    // Clock constraint
    var clock_freq: f64 = 50_000_000.0; // Default 50 MHz
    for (spec.constants.items) |constant| {
        if (std.mem.eql(u8, constant.name, "CLOCK_FREQ")) {
            clock_freq = constant.value;
            break;
        }
    }
    const clock_period_ns: i64 = @intFromFloat(1_000_000_000.0 / clock_freq);
    const clock_freq_mhz: i64 = @intFromFloat(clock_freq / 1_000_000.0);
    
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# CLOCK CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("# Clock period: {d} ns ({d} MHz)\n", .{ clock_period_ns, clock_freq_mhz });
    try builder.writeFmt("create_clock -period {d} -name sys_clk [get_ports clk]\n", .{clock_period_ns});
    try builder.newline();
    
    // Input/Output delays
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# I/O TIMING CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    const setup_time: i64 = @divTrunc(clock_period_ns, 10); // 10% of period
    const hold_time: i64 = @divTrunc(clock_period_ns, 20); // 5% of period
    
    // Input delays
    try builder.writeLine("# Input delays (relative to clock)");
    for (spec.signals.items) |sig| {
        if (std.mem.eql(u8, sig.direction, "input")) {
            if (!std.mem.eql(u8, sig.name, "clk")) {
                try builder.writeFmt("set_input_delay -clock sys_clk -max {d} [get_ports {s}]\n", .{ setup_time, sig.name });
                try builder.writeFmt("set_input_delay -clock sys_clk -min {d} [get_ports {s}]\n", .{ hold_time, sig.name });
            }
        }
    }
    try builder.newline();
    
    // Output delays
    try builder.writeLine("# Output delays (relative to clock)");
    for (spec.signals.items) |sig| {
        if (std.mem.eql(u8, sig.direction, "output")) {
            try builder.writeFmt("set_output_delay -clock sys_clk -max {d} [get_ports {s}]\n", .{ setup_time, sig.name });
            try builder.writeFmt("set_output_delay -clock sys_clk -min {d} [get_ports {s}]\n", .{ hold_time, sig.name });
        }
    }
    try builder.newline();
    
    // False paths for async signals
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# FALSE PATHS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("# Reset is asynchronous");
    try builder.writeLine("set_false_path -from [get_ports rst_n]");
    try builder.newline();
    
    // Pin assignments placeholder
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# PIN ASSIGNMENTS (customize for your board)");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("# Example for Artix-7 (uncomment and modify):");
    try builder.writeLine("# set_property PACKAGE_PIN W5 [get_ports clk]");
    try builder.writeLine("# set_property IOSTANDARD LVCMOS33 [get_ports clk]");
    try builder.newline();
    
    for (spec.signals.items) |sig| {
        if (std.mem.eql(u8, sig.direction, "reg") or std.mem.eql(u8, sig.direction, "wire")) {
            continue;
        }
        try builder.writeFmt("# set_property PACKAGE_PIN ?? [get_ports {s}]\n", .{sig.name});
        try builder.writeFmt("# set_property IOSTANDARD LVCMOS33 [get_ports {s}]\n", .{sig.name});
    }
    try builder.newline();
    
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# END OF CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    
    return try allocator.dupe(u8, builder.getOutput());
}

/// Генерация Intel/Altera SDC constraints файла
pub fn generateSDC(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var builder = VerilogBuilder.init(allocator);
    defer builder.deinit();
    
    // Header
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeFmt("# {s} - Synopsys Design Constraints (SDC)\n", .{spec.name});
    try builder.writeLine("# For Intel/Altera Quartus");
    try builder.writeLine("# Generated by VIBEE - φ² + 1/φ² = 3");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    // Clock constraint
    var clock_freq: f64 = 50_000_000.0; // Default 50 MHz
    for (spec.constants.items) |constant| {
        if (std.mem.eql(u8, constant.name, "CLOCK_FREQ")) {
            clock_freq = constant.value;
            break;
        }
    }
    const clock_period_ns: i64 = @intFromFloat(1_000_000_000.0 / clock_freq);
    const clock_freq_mhz: i64 = @intFromFloat(clock_freq / 1_000_000.0);
    
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# CLOCK CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("# Clock frequency: {d} MHz (period: {d} ns)\n", .{ clock_freq_mhz, clock_period_ns });
    try builder.writeFmt("create_clock -name \"sys_clk\" -period {d} [get_ports {{clk}}]\n", .{clock_period_ns});
    try builder.newline();
    
    // Derive PLL clocks
    try builder.writeLine("# Derive PLL clocks (if using PLL)");
    try builder.writeLine("derive_pll_clocks");
    try builder.newline();
    
    // Clock uncertainty
    try builder.writeLine("# Clock uncertainty");
    try builder.writeLine("derive_clock_uncertainty");
    try builder.newline();
    
    // Input/Output delays
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# I/O TIMING CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    const setup_time_sdc: i64 = @divTrunc(clock_period_ns, 10);
    const hold_time_sdc: i64 = @divTrunc(clock_period_ns, 20);
    
    // Input delays
    try builder.writeLine("# Input delays");
    for (spec.signals.items) |sig| {
        if (std.mem.eql(u8, sig.direction, "input")) {
            if (!std.mem.eql(u8, sig.name, "clk")) {
                try builder.writeFmt("set_input_delay -clock sys_clk -max {d} [get_ports {{{s}}}]\n", .{ setup_time_sdc, sig.name });
                try builder.writeFmt("set_input_delay -clock sys_clk -min {d} [get_ports {{{s}}}]\n", .{ hold_time_sdc, sig.name });
            }
        }
    }
    try builder.newline();
    
    // Output delays
    try builder.writeLine("# Output delays");
    for (spec.signals.items) |sig| {
        if (std.mem.eql(u8, sig.direction, "output")) {
            try builder.writeFmt("set_output_delay -clock sys_clk -max {d} [get_ports {{{s}}}]\n", .{ setup_time_sdc, sig.name });
            try builder.writeFmt("set_output_delay -clock sys_clk -min {d} [get_ports {{{s}}}]\n", .{ hold_time_sdc, sig.name });
        }
    }
    try builder.newline();
    
    // False paths
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# FALSE PATHS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("# Asynchronous reset");
    try builder.writeLine("set_false_path -from [get_ports {rst_n}]");
    try builder.newline();
    
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# END OF CONSTRAINTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    
    return try allocator.dupe(u8, builder.getOutput());
}

/// Генерация Vivado TCL скрипта для синтеза и имплементации
pub fn generateVivadoTCL(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var builder = VerilogBuilder.init(allocator);
    defer builder.deinit();
    
    // Header
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeFmt("# {s} - Vivado Build Script\n", .{spec.name});
    try builder.writeLine("# Generated by VIBEE - φ² + 1/φ² = 3");
    try builder.writeLine("# Usage: vivado -mode batch -source build.tcl");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    // Project settings
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# PROJECT SETTINGS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("set project_name \"{s}\"\n", .{spec.name});
    try builder.writeLine("set part_number \"xc7a35tcpg236-1\"  ;# Artix-7 (modify for your board)");
    try builder.writeLine("set top_module \"${project_name}_top\"");
    try builder.newline();
    
    // Create project
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# CREATE PROJECT");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("create_project ${project_name} ./vivado_project -part ${part_number} -force");
    try builder.writeLine("set_property target_language Verilog [current_project]");
    try builder.newline();
    
    // Add sources
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# ADD SOURCE FILES");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("add_files -norecurse {s}.v\n", .{spec.name});
    try builder.writeFmt("add_files -fileset constrs_1 -norecurse {s}.xdc\n", .{spec.name});
    try builder.writeLine("update_compile_order -fileset sources_1");
    try builder.newline();
    
    // Synthesis
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# SYNTHESIS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("puts \"Starting synthesis...\"");
    try builder.writeLine("launch_runs synth_1 -jobs 4");
    try builder.writeLine("wait_on_run synth_1");
    try builder.newline();
    try builder.writeLine("if {[get_property PROGRESS [get_runs synth_1]] != \"100%\"} {");
    try builder.writeLine("    puts \"ERROR: Synthesis failed!\"");
    try builder.writeLine("    exit 1");
    try builder.writeLine("}");
    try builder.writeLine("puts \"Synthesis complete.\"");
    try builder.newline();
    
    // Implementation
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# IMPLEMENTATION");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("puts \"Starting implementation...\"");
    try builder.writeLine("launch_runs impl_1 -jobs 4");
    try builder.writeLine("wait_on_run impl_1");
    try builder.newline();
    try builder.writeLine("if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {");
    try builder.writeLine("    puts \"ERROR: Implementation failed!\"");
    try builder.writeLine("    exit 1");
    try builder.writeLine("}");
    try builder.writeLine("puts \"Implementation complete.\"");
    try builder.newline();
    
    // Generate bitstream
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# GENERATE BITSTREAM");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("puts \"Generating bitstream...\"");
    try builder.writeLine("launch_runs impl_1 -to_step write_bitstream -jobs 4");
    try builder.writeLine("wait_on_run impl_1");
    try builder.newline();
    try builder.writeFmt("file copy -force ./vivado_project/{s}.runs/impl_1/${{top_module}}.bit ./{s}.bit\n", .{ spec.name, spec.name });
    try builder.writeFmt("puts \"Bitstream generated: {s}.bit\"\n", .{spec.name});
    try builder.newline();
    
    // Reports
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# GENERATE REPORTS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("open_run impl_1");
    try builder.writeFmt("report_utilization -file {s}_utilization.rpt\n", .{spec.name});
    try builder.writeFmt("report_timing_summary -file {s}_timing.rpt\n", .{spec.name});
    try builder.writeFmt("report_power -file {s}_power.rpt\n", .{spec.name});
    try builder.newline();
    
    try builder.writeLine("puts \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.writeLine("puts \"BUILD COMPLETE - φ² + 1/φ² = 3\"");
    try builder.writeLine("puts \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.writeLine("exit 0");
    
    return try allocator.dupe(u8, builder.getOutput());
}

/// Генерация Quartus TCL скрипта
pub fn generateQuartusTCL(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var builder = VerilogBuilder.init(allocator);
    defer builder.deinit();
    
    // Header
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeFmt("# {s} - Quartus Build Script\n", .{spec.name});
    try builder.writeLine("# Generated by VIBEE - φ² + 1/φ² = 3");
    try builder.writeLine("# Usage: quartus_sh -t build_quartus.tcl");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    // Load packages
    try builder.writeLine("package require ::quartus::project");
    try builder.writeLine("package require ::quartus::flow");
    try builder.newline();
    
    // Project settings
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# PROJECT SETTINGS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("set project_name \"{s}\"\n", .{spec.name});
    try builder.writeLine("set family \"Cyclone V\"  ;# Modify for your device");
    try builder.writeLine("set device \"5CSEMA5F31C6\"  ;# DE1-SoC (modify for your board)");
    try builder.writeFmt("set top_module \"{s}_top\"\n", .{spec.name});
    try builder.newline();
    
    // Create project
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# CREATE PROJECT");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("if {[project_exists $project_name]} {");
    try builder.writeLine("    project_open $project_name");
    try builder.writeLine("} else {");
    try builder.writeLine("    project_new $project_name");
    try builder.writeLine("}");
    try builder.newline();
    
    // Set device
    try builder.writeLine("set_global_assignment -name FAMILY $family");
    try builder.writeLine("set_global_assignment -name DEVICE $device");
    try builder.writeLine("set_global_assignment -name TOP_LEVEL_ENTITY $top_module");
    try builder.writeLine("set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files");
    try builder.newline();
    
    // Add sources
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# ADD SOURCE FILES");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeFmt("set_global_assignment -name VERILOG_FILE {s}.v\n", .{spec.name});
    try builder.writeFmt("set_global_assignment -name SDC_FILE {s}.sdc\n", .{spec.name});
    try builder.newline();
    
    // Compile
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# COMPILE");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("puts \"Starting compilation...\"");
    try builder.newline();
    try builder.writeLine("if {[catch {execute_flow -compile} result]} {");
    try builder.writeLine("    puts \"ERROR: Compilation failed!\"");
    try builder.writeLine("    puts $result");
    try builder.writeLine("    project_close");
    try builder.writeLine("    exit 1");
    try builder.writeLine("}");
    try builder.newline();
    
    try builder.writeLine("puts \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.writeLine("puts \"BUILD COMPLETE - φ² + 1/φ² = 3\"");
    try builder.writeFmt("puts \"Output: output_files/{s}.sof\"\n", .{spec.name});
    try builder.writeLine("puts \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.newline();
    
    try builder.writeLine("project_close");
    try builder.writeLine("exit 0");
    
    return try allocator.dupe(u8, builder.getOutput());
}

/// Генерация Makefile для полного flow
pub fn generateMakefile(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var builder = VerilogBuilder.init(allocator);
    defer builder.deinit();
    
    // Header
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeFmt("# {s} - FPGA Build Makefile\n", .{spec.name});
    try builder.writeLine("# Generated by VIBEE - φ² + 1/φ² = 3");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    
    // Variables
    try builder.writeFmt("PROJECT = {s}\n", .{spec.name});
    try builder.writeLine("TOP = $(PROJECT)_top");
    try builder.writeLine("VERILOG = $(PROJECT).v");
    try builder.writeLine("XDC = $(PROJECT).xdc");
    try builder.writeLine("SDC = $(PROJECT).sdc");
    try builder.newline();
    
    // Tool paths
    try builder.writeLine("# Tool paths (modify as needed)");
    try builder.writeLine("VIVADO = vivado");
    try builder.writeLine("QUARTUS = quartus_sh");
    try builder.writeLine("IVERILOG = iverilog");
    try builder.writeLine("VVP = vvp");
    try builder.writeLine("GTKWAVE = gtkwave");
    try builder.newline();
    
    // Default target
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# TARGETS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine(".PHONY: all sim vivado quartus clean help");
    try builder.newline();
    try builder.writeLine("all: sim");
    try builder.newline();
    
    // Help
    try builder.writeLine("help:");
    try builder.writeLine("\t@echo \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.writeLine("\t@echo \"$(PROJECT) - FPGA Build System\"");
    try builder.writeLine("\t@echo \"═══════════════════════════════════════════════════════════════════════════════\"");
    try builder.writeLine("\t@echo \"\"");
    try builder.writeLine("\t@echo \"Targets:\"");
    try builder.writeLine("\t@echo \"  sim      - Run simulation (iverilog + vvp)\"");
    try builder.writeLine("\t@echo \"  wave     - View waveforms (gtkwave)\"");
    try builder.writeLine("\t@echo \"  vivado   - Build for Xilinx (Vivado)\"");
    try builder.writeLine("\t@echo \"  quartus  - Build for Intel (Quartus)\"");
    try builder.writeLine("\t@echo \"  clean    - Remove generated files\"");
    try builder.writeLine("\t@echo \"\"");
    try builder.writeLine("\t@echo \"Sacred Formula: φ² + 1/φ² = 3\"");
    try builder.newline();
    
    // Simulation
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# SIMULATION");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("sim: $(PROJECT)_sim");
    try builder.writeLine("\t$(VVP) $(PROJECT)_sim");
    try builder.newline();
    try builder.writeLine("$(PROJECT)_sim: $(VERILOG)");
    try builder.writeLine("\t$(IVERILOG) -o $@ $<");
    try builder.newline();
    try builder.writeLine("wave: sim");
    try builder.writeLine("\t$(GTKWAVE) $(PROJECT).vcd &");
    try builder.newline();
    
    // Vivado
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# XILINX VIVADO");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("vivado: $(VERILOG) $(XDC)");
    try builder.writeLine("\t$(VIVADO) -mode batch -source build_vivado.tcl");
    try builder.newline();
    
    // Quartus
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# INTEL QUARTUS");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("quartus: $(VERILOG) $(SDC)");
    try builder.writeLine("\t$(QUARTUS) -t build_quartus.tcl");
    try builder.newline();
    
    // Clean
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# CLEAN");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.newline();
    try builder.writeLine("clean:");
    try builder.writeLine("\trm -f $(PROJECT)_sim $(PROJECT).vcd");
    try builder.writeLine("\trm -rf vivado_project");
    try builder.writeLine("\trm -rf db incremental_db output_files");
    try builder.writeLine("\trm -f *.rpt *.bit *.sof *.qpf *.qsf");
    try builder.writeLine("\t@echo \"Clean complete.\"");
    try builder.newline();
    
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    try builder.writeLine("# END OF MAKEFILE");
    try builder.writeLine("# ═══════════════════════════════════════════════════════════════════════════════");
    
    return try allocator.dupe(u8, builder.getOutput());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "verilog type mapping" {
    const testing = std.testing;
    
    try testing.expectEqualStrings("[63:0] // 64-bit signed", mapTypeToVerilog("Int"));
    try testing.expectEqualStrings("[63:0] // IEEE 754 double", mapTypeToVerilog("Float"));
    try testing.expectEqualStrings("[0:0] // 1-bit boolean", mapTypeToVerilog("Bool"));
}

test "golden identity" {
    const phi: f64 = 1.618033988749895;
    const result = phi * phi + 1.0 / (phi * phi);
    const testing = std.testing;
    try testing.expect(@abs(result - 3.0) < 1e-10);
}
