// VIBEEC Parser - Parses .vibee YAML specifications

const std = @import("std");

pub const Spec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8,
    module: []const u8,
    description: []const u8,
    behaviors: []Behavior,
    types: []Type,
    functions: []Function,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const Spec) void {
        self.allocator.free(self.behaviors);
        self.allocator.free(self.types);
        self.allocator.free(self.functions);
    }
};

pub const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

pub const Type = struct {
    name: []const u8,
    fields: []Field,
};

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const Function = struct {
    name: []const u8,
    params: []Field,
    returns: []const u8,
};

pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Spec {
    var spec = Spec{
        .name = "unknown",
        .version = "1.0.0",
        .language = "zig",
        .module = "module",
        .description = "",
        .behaviors = &[_]Behavior{},
        .types = &[_]Type{},
        .functions = &[_]Function{},
        .allocator = allocator,
    };

    var behaviors = std.ArrayList(Behavior).init(allocator);
    var types = std.ArrayList(Type).init(allocator);
    var functions = std.ArrayList(Function).init(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var in_behavior = false;
    var current_behavior: ?Behavior = null;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Parse top-level fields
        if (std.mem.startsWith(u8, trimmed, "name:")) {
            spec.name = extractValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "version:")) {
            spec.version = extractValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "language:")) {
            spec.language = extractValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "module:")) {
            spec.module = extractValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "description:")) {
            spec.description = extractValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
            in_behavior = true;
        } else if (in_behavior and std.mem.startsWith(u8, trimmed, "- name:")) {
            if (current_behavior) |b| {
                try behaviors.append(b);
            }
            current_behavior = Behavior{
                .name = extractValue(trimmed[2..]),
                .given = "",
                .when = "",
                .then = "",
            };
        } else if (current_behavior != null) {
            if (std.mem.startsWith(u8, trimmed, "given:")) {
                current_behavior.?.given = extractValue(trimmed);
            } else if (std.mem.startsWith(u8, trimmed, "when:")) {
                current_behavior.?.when = extractValue(trimmed);
            } else if (std.mem.startsWith(u8, trimmed, "then:")) {
                current_behavior.?.then = extractValue(trimmed);
            }
        }
    }

    // Add last behavior
    if (current_behavior) |b| {
        try behaviors.append(b);
    }

    spec.behaviors = try behaviors.toOwnedSlice();
    spec.types = try types.toOwnedSlice();
    spec.functions = try functions.toOwnedSlice();

    return spec;
}

fn extractValue(line: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, line, ":") orelse return "";
    const value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t\"'");
    return value;
}

test "parse simple spec" {
    const content =
        \\name: test
        \\version: "1.0.0"
        \\language: zig
        \\module: test_module
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: Input provided
        \\    when: Function called
        \\    then: Result returned
    ;

    const spec = try parse(std.testing.allocator, content);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test", spec.name);
    try std.testing.expectEqualStrings("zig", spec.language);
    try std.testing.expect(spec.behaviors.len == 1);
}
