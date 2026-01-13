// VIBEEC - VIBEE Compiler
// Compiles .vibee specifications to Zig code

const std = @import("std");
const parser = @import("parser.zig");
const codegen = @import("codegen.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "gen") or std.mem.eql(u8, command, "generate")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            std.debug.print("Usage: vibeec gen <spec.vibee> [--output <dir>]\n", .{});
            return;
        }
        const spec_file = args[2];
        const output_dir = if (args.len >= 5 and std.mem.eql(u8, args[3], "--output")) args[4] else ".";
        try generateCode(allocator, spec_file, output_dir);
    } else if (std.mem.eql(u8, command, "check")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            return;
        }
        try checkSpec(allocator, args[2]);
    } else if (std.mem.eql(u8, command, "bee")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing bee subcommand\n", .{});
            std.debug.print("Usage: vibeec bee <status|achievements|daily>\n", .{});
            return;
        }
        const subcommand = args[2];
        if (std.mem.eql(u8, subcommand, "status")) {
            try beeStatus();
        } else if (std.mem.eql(u8, subcommand, "achievements")) {
            try beeAchievements();
        } else if (std.mem.eql(u8, subcommand, "daily")) {
            try beeDaily();
        } else {
            std.debug.print("Unknown bee subcommand: {s}\n", .{subcommand});
            std.debug.print("Available: status, achievements, daily\n", .{});
        }
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("vibeec 1.0.0\n", .{});
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\VIBEEC - VIBEE Compiler v1.0.0
        \\
        \\Usage: vibeec <command> [options]
        \\
        \\Commands:
        \\  gen <spec.vibee>     Generate code from specification
        \\  check <spec.vibee>   Validate specification
        \\  bee status           Show your bee status and XP
        \\  bee achievements     Show your achievements
        \\  bee daily            Show daily challenge
        \\  version              Show version
        \\  help                 Show this help
        \\
        \\Options:
        \\  --output <dir>       Output directory (default: current)
        \\
        \\Examples:
        \\  vibeec gen specs/example.vibee
        \\  vibeec gen specs/example.vibee --output src/
        \\  vibeec check specs/example.vibee
        \\  vibeec bee status
        \\
    , .{});
}

fn generateCode(allocator: std.mem.Allocator, spec_file: []const u8, output_dir: []const u8) !void {
    std.debug.print("Generating code from: {s}\n", .{spec_file});
    std.debug.print("Output directory: {s}\n", .{output_dir});

    // Read spec file
    const file = std.fs.cwd().openFile(spec_file, .{}) catch |err| {
        std.debug.print("Error: Cannot open file {s}: {}\n", .{ spec_file, err });
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Parse spec
    const spec = try parser.parse(allocator, content);
    defer spec.deinit();

    // Generate code
    const code = try codegen.generate(allocator, spec);
    defer allocator.free(code);

    // Write output
    const output_name = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ output_dir, spec.module });
    defer allocator.free(output_name);

    const out_file = try std.fs.cwd().createFile(output_name, .{});
    defer out_file.close();
    try out_file.writeAll(code);

    std.debug.print("Generated: {s}\n", .{output_name});
}

fn beeStatus() !void {
    const stdout = std.io.getStdOut().writer();
    
    // Get current day of week for variety
    const timestamp = std.time.timestamp();
    const day = @mod(@divFloor(timestamp, 86400), 7);
    
    // Simulated progress based on time (in real app, would read from ~/.vibeec/profile.json)
    const base_xp: u32 = 1234;
    const daily_bonus: u32 = @intCast(@mod(timestamp, 100));
    const xp = base_xp + daily_bonus;
    
    const level: u8 = if (xp < 500) 1 else if (xp < 2000) 2 else if (xp < 5000) 3 else if (xp < 10000) 4 else 5;
    const level_names = [_][]const u8{ "Larva", "Worker Bee", "Nurse Bee", "Guard Bee", "Scout Bee", "Queen Bee" };
    const next_level_xp = [_]u32{ 500, 2000, 5000, 10000, 25000, 100000 };
    
    const pollen_spec: u32 = 45 + @as(u32, @intCast(@mod(day, 10)));
    const pollen_test: u32 = 23 + @as(u32, @intCast(@mod(day, 5)));
    const pollen_code: u32 = 12 + @as(u32, @intCast(@mod(day, 3)));
    const honey: u32 = 8 + @as(u32, @intCast(@mod(day, 2)));
    
    try stdout.print(
        \\
        \\  🐝 {s} (Level {d})
        \\  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\  XP: {d} / {d}
        \\  Pollen: 🌼 {d} | 🌸 {d} | 🌻 {d}
        \\  Honey: 🍯 {d}
        \\  Next: {s} ({d} XP needed)
        \\
        \\  Tip: Run 'vibeec bee daily' for today's challenge!
        \\
    , .{ level_names[level], level, xp, next_level_xp[level], pollen_spec, pollen_test, pollen_code, honey, level_names[level + 1], next_level_xp[level] - xp });
}

fn beeAchievements() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\
        \\  🏆 YOUR ACHIEVEMENTS
        \\  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\
        \\  ✅ 🏅 First Flight      - Complete tutorial
        \\  ✅ 🥚 First Spec        - Write your first .vibee file
        \\  ✅ 🌱 Hello Hive        - Generate first code
        \\  ✅ 📖 Reader            - Read documentation
        \\  ⬜ 🐝 First Honey       - Create working module
        \\  ⬜ 🧪 Tester            - Write 10 test cases
        \\  ⬜ 🎖️ Busy Bee          - 100 specs written
        \\  ⬜ 🏆 Honey Master      - 1000 lines generated
        \\  ⬜ 👑 Queen's Guard     - 0 violations in 30 days
        \\
        \\  Progress: 4/9 achievements unlocked
        \\
    , .{});
}

fn beeDaily() !void {
    const stdout = std.io.getStdOut().writer();
    
    const timestamp = std.time.timestamp();
    const day_of_week = @mod(@divFloor(timestamp, 86400), 7);
    
    const challenges = [_][]const u8{
        "🍯 Honey Flow    - Generate code for 3 specs",
        "🐝 Waggle Dance  - Share knowledge with a teammate",
        "🌸 Foraging      - Research a new VIBEE feature",
        "🏗️ Comb Building - Create a new module architecture",
        "🛡️ Hive Defense  - Review 5 specs for quality",
        "🌼 Nectar Hunt   - Write 3 new behaviors",
        "📖 Royal Rest    - Read documentation for 15 min",
    };
    
    const rewards = [_][]const u8{ "60 XP", "70 XP", "55 XP", "80 XP", "50 XP", "50 XP", "30 XP" };
    
    const day_names = [_][]const u8{ "Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday" };
    
    try stdout.print(
        \\
        \\  📅 DAILY CHALLENGE - {s}
        \\  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\
        \\  {s}
        \\
        \\  Reward: {s} + 🌼 x3
        \\
        \\  Status: ⬜ Not completed
        \\
        \\  Complete by writing specs and running:
        \\    vibeec gen <your-spec.vibee>
        \\
    , .{ day_names[@intCast(day_of_week)], challenges[@intCast(day_of_week)], rewards[@intCast(day_of_week)] });
}

fn checkSpec(allocator: std.mem.Allocator, spec_file: []const u8) !void {
    std.debug.print("Checking: {s}\n", .{spec_file});

    const file = std.fs.cwd().openFile(spec_file, .{}) catch |err| {
        std.debug.print("Error: Cannot open file {s}: {}\n", .{ spec_file, err });
        return;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const spec = parser.parse(allocator, content) catch |err| {
        std.debug.print("Error: Invalid spec: {}\n", .{err});
        return;
    };
    defer spec.deinit();

    std.debug.print("Valid spec: {s} v{s}\n", .{ spec.name, spec.version });
    std.debug.print("  Module: {s}\n", .{spec.module});
    std.debug.print("  Language: {s}\n", .{spec.language});
    std.debug.print("  Behaviors: {d}\n", .{spec.behaviors.len});
    std.debug.print("  Types: {d}\n", .{spec.types.len});
    std.debug.print("  Functions: {d}\n", .{spec.functions.len});
}
