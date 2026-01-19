// skills.zig - Agent Skills Module
// Generated from: crush/internal/skills
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

pub const SKILL_FILE_NAME = "SKILL.md";
pub const MAX_NAME_LENGTH = 64;
pub const MAX_DESCRIPTION_LENGTH = 1024;
pub const MAX_COMPATIBILITY_LENGTH = 500;

/// Skill represents a parsed SKILL.md file
pub const Skill = struct {
    name: []const u8,
    description: []const u8,
    license: ?[]const u8,
    compatibility: ?[]const u8,
    instructions: []const u8,
    path: []const u8,
    skill_file_path: []const u8,

    const Self = @This();

    /// Validate skill meets spec requirements
    pub fn validate(self: Self) !void {
        if (self.name.len == 0) {
            return error.NameRequired;
        }

        if (self.name.len > MAX_NAME_LENGTH) {
            return error.NameTooLong;
        }

        if (!isValidName(self.name)) {
            return error.InvalidNameFormat;
        }

        if (self.description.len == 0) {
            return error.DescriptionRequired;
        }

        if (self.description.len > MAX_DESCRIPTION_LENGTH) {
            return error.DescriptionTooLong;
        }

        if (self.compatibility) |compat| {
            if (compat.len > MAX_COMPATIBILITY_LENGTH) {
                return error.CompatibilityTooLong;
            }
        }
    }
};

/// Check if name matches pattern: ^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$
pub fn isValidName(name: []const u8) bool {
    if (name.len == 0) return false;

    var i: usize = 0;
    var after_hyphen = false;

    while (i < name.len) : (i += 1) {
        const c = name[i];

        if (c == '-') {
            if (i == 0 or i == name.len - 1) return false;
            if (after_hyphen) return false;
            after_hyphen = true;
        } else if (std.ascii.isAlphanumeric(c)) {
            after_hyphen = false;
        } else {
            return false;
        }
    }

    return !after_hyphen;
}

/// Skill registry
pub const Registry = struct {
    skills: std.StringHashMap(Skill),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .skills = std.StringHashMap(Skill).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.skills.deinit();
    }

    /// Register a skill
    pub fn register(self: *Self, skill: Skill) !void {
        try skill.validate();
        try self.skills.put(skill.name, skill);
    }

    /// Get skill by name
    pub fn get(self: *Self, name: []const u8) ?Skill {
        return self.skills.get(name);
    }

    /// List all skills
    pub fn list(self: *Self, allocator: std.mem.Allocator) ![]Skill {
        var result = std.ArrayList(Skill).init(allocator);
        var iter = self.skills.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }
        return result.toOwnedSlice();
    }

    /// Get skill count
    pub fn count(self: *Self) usize {
        return self.skills.count();
    }
};

// Tests
test "is_valid_name" {
    try std.testing.expect(isValidName("my-skill"));
    try std.testing.expect(isValidName("skill123"));
    try std.testing.expect(isValidName("my-cool-skill"));
    try std.testing.expect(!isValidName("-skill"));
    try std.testing.expect(!isValidName("skill-"));
    try std.testing.expect(!isValidName("my--skill"));
    try std.testing.expect(!isValidName("my_skill"));
    try std.testing.expect(!isValidName(""));
}

test "skill_validate_valid" {
    const skill = Skill{
        .name = "my-skill",
        .description = "A test skill",
        .license = null,
        .compatibility = null,
        .instructions = "Do something",
        .path = "/path",
        .skill_file_path = "/path/SKILL.md",
    };

    try skill.validate();
}

test "skill_validate_empty_name" {
    const skill = Skill{
        .name = "",
        .description = "A test skill",
        .license = null,
        .compatibility = null,
        .instructions = "",
        .path = "",
        .skill_file_path = "",
    };

    try std.testing.expectError(error.NameRequired, skill.validate());
}

test "skill_validate_empty_description" {
    const skill = Skill{
        .name = "my-skill",
        .description = "",
        .license = null,
        .compatibility = null,
        .instructions = "",
        .path = "",
        .skill_file_path = "",
    };

    try std.testing.expectError(error.DescriptionRequired, skill.validate());
}

test "registry_register_and_get" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const skill = Skill{
        .name = "test-skill",
        .description = "Test description",
        .license = null,
        .compatibility = null,
        .instructions = "Instructions",
        .path = "/path",
        .skill_file_path = "/path/SKILL.md",
    };

    try registry.register(skill);
    const retrieved = registry.get("test-skill");

    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test-skill", retrieved.?.name);
}

test "registry_count" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    try std.testing.expectEqual(@as(usize, 0), registry.count());
}
