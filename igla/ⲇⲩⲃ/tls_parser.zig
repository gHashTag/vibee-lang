// ═══════════════════════════════════════════════════════════════════════════════
// TLS PARSER - PARSE .TLS SPECIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════════
// Based on vibeec/parser_v3.zig architecture
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: PRE (Precomputation), HSH (Keyword Hash), D&C (Recursive Descent)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// SPECIFICATION STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Specification = struct {
    name: []const u8 = "",
    version: []const u8 = "",
    opcodes: ArrayList(OpcodeSpec),
    behaviors: ArrayList(Behavior),

    pub fn init(allocator: Allocator) Specification {
        return .{
            .opcodes = ArrayList(OpcodeSpec).init(allocator),
            .behaviors = ArrayList(Behavior).init(allocator),
        };
    }

    pub fn deinit(self: *Specification) void {
        self.opcodes.deinit();
        for (self.behaviors.items) |*b| {
            b.deinit();
        }
        self.behaviors.deinit();
    }
};

pub const OpcodeSpec = struct {
    code: u8 = 0,
    mnemonic: []const u8 = "",
    stack_in: u8 = 0,
    stack_out: u8 = 0,
    semantics: []const u8 = "",
};

pub const Behavior = struct {
    name: []const u8 = "",
    given: ArrayList([]const u8),
    when: ArrayList([]const u8),
    then: ArrayList([]const u8),
    test_data: ?TestData = null,

    pub fn init(allocator: Allocator) Behavior {
        return .{
            .given = ArrayList([]const u8).init(allocator),
            .when = ArrayList([]const u8).init(allocator),
            .then = ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Behavior) void {
        self.given.deinit();
        self.when.deinit();
        self.then.deinit();
    }
};

pub const TestData = struct {
    setup_stack: ArrayList(u64),
    expected_stack: ArrayList(u64),
    expected_pc: u64 = 0,
    expected_status: []const u8 = "Running",

    pub fn init(allocator: Allocator) TestData {
        return .{
            .setup_stack = ArrayList(u64).init(allocator),
            .expected_stack = ArrayList(u64).init(allocator),
        };
    }

    pub fn deinit(self: *TestData) void {
        self.setup_stack.deinit();
        self.expected_stack.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KEYWORD HASH - HSH PATTERN (from vibeec)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Keyword = enum {
    name,
    version,
    code,
    mnemonic,
    stack_in,
    stack_out,
    semantics,
    behaviors,
    given,
    when,
    then,
    test_data,
    setup,
    expected,
    opcodes,
    unknown,

    pub fn fromString(s: []const u8) Keyword {
        const trimmed = std.mem.trim(u8, s, " \t:");
        if (std.mem.eql(u8, trimmed, "name")) return .name;
        if (std.mem.eql(u8, trimmed, "version")) return .version;
        if (std.mem.eql(u8, trimmed, "code")) return .code;
        if (std.mem.eql(u8, trimmed, "mnemonic")) return .mnemonic;
        if (std.mem.eql(u8, trimmed, "stack_in")) return .stack_in;
        if (std.mem.eql(u8, trimmed, "stack_out")) return .stack_out;
        if (std.mem.eql(u8, trimmed, "semantics")) return .semantics;
        if (std.mem.eql(u8, trimmed, "behaviors")) return .behaviors;
        if (std.mem.eql(u8, trimmed, "given")) return .given;
        if (std.mem.eql(u8, trimmed, "when")) return .when;
        if (std.mem.eql(u8, trimmed, "then")) return .then;
        if (std.mem.eql(u8, trimmed, "test_data")) return .test_data;
        if (std.mem.eql(u8, trimmed, "setup")) return .setup;
        if (std.mem.eql(u8, trimmed, "expected")) return .expected;
        if (std.mem.eql(u8, trimmed, "opcodes")) return .opcodes;
        return .unknown;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TLS PARSER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TLSParser = struct {
    allocator: Allocator,
    source: []const u8,
    lines: ArrayList([]const u8),
    current_line: usize,

    // Metrics
    lines_parsed: u64,
    keywords_matched: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .source = "",
            .lines = ArrayList([]const u8).init(allocator),
            .current_line = 0,
            .lines_parsed = 0,
            .keywords_matched = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.lines.deinit();
    }

    pub fn parse(self: *Self, source: []const u8) !Specification {
        self.source = source;
        self.current_line = 0;
        self.lines.clearRetainingCapacity();

        // Split into lines
        var line_iter = std.mem.splitScalar(u8, source, '\n');
        while (line_iter.next()) |line| {
            try self.lines.append(line);
        }

        var spec = Specification.init(self.allocator);

        // Parse line by line (D&C pattern)
        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') {
                self.current_line += 1;
                continue;
            }

            // Parse key-value
            if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                const key = trimmed[0..colon_pos];
                const value = if (colon_pos + 1 < trimmed.len)
                    std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t\"")
                else
                    "";

                const keyword = Keyword.fromString(key);
                self.keywords_matched += 1;

                switch (keyword) {
                    .name => spec.name = value,
                    .version => spec.version = value,
                    .opcodes => try self.parseOpcodes(&spec),
                    .behaviors => try self.parseBehaviors(&spec),
                    else => {},
                }
            }

            self.current_line += 1;
            self.lines_parsed += 1;
        }

        return spec;
    }

    fn parseOpcodes(self: *Self, spec: *Specification) !void {
        self.current_line += 1;

        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Check for end of section (dedent)
            if (trimmed.len > 0 and trimmed[0] != ' ' and trimmed[0] != '-') {
                self.current_line -= 1;
                break;
            }

            // Parse opcode entry
            if (std.mem.startsWith(u8, trimmed, "- ") or std.mem.startsWith(u8, trimmed, "ADD:") or
                std.mem.startsWith(u8, trimmed, "SUB:") or std.mem.startsWith(u8, trimmed, "MUL:") or
                std.mem.startsWith(u8, trimmed, "DIV:"))
            {
                var opcode = OpcodeSpec{};
                try self.parseOpcodeEntry(&opcode);
                try spec.opcodes.append(opcode);
            }

            self.current_line += 1;
        }
    }

    fn parseOpcodeEntry(self: *Self, opcode: *OpcodeSpec) !void {
        // Parse opcode fields
        const start_line = self.current_line;
        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (trimmed.len == 0) {
                self.current_line += 1;
                continue;
            }

            // Check for next opcode or section
            if (self.current_line > start_line and
                (std.mem.startsWith(u8, trimmed, "- ") or
                (trimmed.len > 0 and trimmed[0] != ' ' and std.mem.indexOf(u8, trimmed, ":") != null and
                !std.mem.startsWith(u8, trimmed, "code:") and
                !std.mem.startsWith(u8, trimmed, "mnemonic:") and
                !std.mem.startsWith(u8, trimmed, "stack_in:") and
                !std.mem.startsWith(u8, trimmed, "stack_out:") and
                !std.mem.startsWith(u8, trimmed, "semantics:"))))
            {
                self.current_line -= 1;
                break;
            }

            if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                const key = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
                const value = if (colon_pos + 1 < trimmed.len)
                    std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t\"")
                else
                    "";

                const keyword = Keyword.fromString(key);
                switch (keyword) {
                    .code => {
                        if (std.mem.startsWith(u8, value, "0x")) {
                            opcode.code = std.fmt.parseInt(u8, value[2..], 16) catch 0;
                        } else {
                            opcode.code = std.fmt.parseInt(u8, value, 10) catch 0;
                        }
                    },
                    .mnemonic => opcode.mnemonic = value,
                    .stack_in => opcode.stack_in = std.fmt.parseInt(u8, value, 10) catch 0,
                    .stack_out => opcode.stack_out = std.fmt.parseInt(u8, value, 10) catch 0,
                    .semantics => opcode.semantics = value,
                    else => {},
                }
            }

            self.current_line += 1;
        }
    }

    fn parseBehaviors(self: *Self, spec: *Specification) !void {
        self.current_line += 1;

        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Check for end of section
            if (trimmed.len > 0 and trimmed[0] != ' ' and trimmed[0] != '-') {
                self.current_line -= 1;
                break;
            }

            // Parse behavior entry
            if (std.mem.startsWith(u8, trimmed, "- name:")) {
                var behavior = Behavior.init(self.allocator);
                const name_start = std.mem.indexOf(u8, trimmed, ":").? + 1;
                behavior.name = std.mem.trim(u8, trimmed[name_start..], " \t\"");
                try self.parseBehaviorEntry(&behavior);
                try spec.behaviors.append(behavior);
            }

            self.current_line += 1;
        }
    }

    fn parseBehaviorEntry(self: *Self, behavior: *Behavior) !void {
        self.current_line += 1;

        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (trimmed.len == 0) {
                self.current_line += 1;
                continue;
            }

            // Check for next behavior
            if (std.mem.startsWith(u8, trimmed, "- name:")) {
                self.current_line -= 1;
                break;
            }

            if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
                const key = std.mem.trim(u8, trimmed[0..colon_pos], " \t-");
                const keyword = Keyword.fromString(key);

                switch (keyword) {
                    .given => try self.parseStringList(&behavior.given),
                    .when => try self.parseStringList(&behavior.when),
                    .then => try self.parseStringList(&behavior.then),
                    else => {},
                }
            }

            self.current_line += 1;
        }
    }

    fn parseStringList(self: *Self, list: *ArrayList([]const u8)) !void {
        self.current_line += 1;

        while (self.current_line < self.lines.items.len) {
            const line = self.lines.items[self.current_line];
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (trimmed.len == 0) {
                self.current_line += 1;
                continue;
            }

            // Check for list item
            if (std.mem.startsWith(u8, trimmed, "- \"") or std.mem.startsWith(u8, trimmed, "- '")) {
                const content = std.mem.trim(u8, trimmed[2..], " \t\"'");
                try list.append(content);
            } else if (!std.mem.startsWith(u8, trimmed, "-")) {
                self.current_line -= 1;
                break;
            }

            self.current_line += 1;
        }
    }

    pub fn getMetrics(self: *const Self) ParserMetrics {
        return .{
            .lines_parsed = self.lines_parsed,
            .keywords_matched = self.keywords_matched,
        };
    }
};

pub const ParserMetrics = struct {
    lines_parsed: u64,
    keywords_matched: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "keyword_from_string" {
    try std.testing.expectEqual(Keyword.name, Keyword.fromString("name"));
    try std.testing.expectEqual(Keyword.version, Keyword.fromString("version"));
    try std.testing.expectEqual(Keyword.code, Keyword.fromString("code"));
    try std.testing.expectEqual(Keyword.unknown, Keyword.fromString("xyz"));
}

test "parse_simple_spec" {
    const allocator = std.testing.allocator;
    var parser = TLSParser.init(allocator);
    defer parser.deinit();

    const source =
        \\name: test_spec
        \\version: "1.0.0"
    ;

    var spec = try parser.parse(source);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test_spec", spec.name);
    try std.testing.expectEqualStrings("1.0.0", spec.version);
}

test "golden_identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
