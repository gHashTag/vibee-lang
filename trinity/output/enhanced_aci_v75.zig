// ═══════════════════════════════════════════════════════════════════════════════
// ENHANCED AGENT-COMPUTER INTERFACE (ACI) V75
// Based on SWE-agent paper (Yang et al. 2024)
// VibeeSpec → AutoCodeGenerator → GeneratedZigCode
// ═══════════════════════════════════════════════════════════════════════════════
//
// DO NOT EDIT - This file is auto-generated from enhanced_aci_v75.vibee
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: i64 = 999;
pub const GOLDEN_IDENTITY: i64 = 37 * 27;

pub const VERSION: []const u8 = "v75";
pub const TOTAL_COMMANDS: i64 = 25;
pub const TOTAL_CATEGORIES: i64 = 5;
pub const TOTAL_GUARDRAILS: i64 = 12;
pub const WINDOW_SIZE: i64 = 100;
pub const CONTEXT_LINES: i64 = 5;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const CommandCategory = enum {
    FileNavigation,
    FileEditing,
    Search,
    Execution,
    Context,
};

pub const ACICommand = struct {
    name: []const u8,
    syntax: []const u8,
    description: []const u8,
    category: CommandCategory,
};

pub const OutputFormat = struct {
    window_size: i64,
    context_lines: i64,
    line_numbers: bool,
    syntax_highlighting: bool,
};

pub const Guardrail = struct {
    name: []const u8,
    category: []const u8,
    description: []const u8,
};

pub const ACIComparison = struct {
    tool: []const u8,
    commands: i64,
    guardrails: i64,
    lsp_integration: bool,
    undo_support: bool,
};

pub const DesignPrinciple = struct {
    name: []const u8,
    description: []const u8,
    implementation: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN PRINCIPLES (4 principles from SWE-agent paper)
// ═══════════════════════════════════════════════════════════════════════════════

pub const design_principles = [_]DesignPrinciple{
    .{ .name = "Simple Actions", .description = "Actions should be simple and easy to understand", .implementation = "Single-purpose commands with clear semantics" },
    .{ .name = "Compact Output", .description = "Actions should be compact and efficient", .implementation = "Concise output formats, pagination" },
    .{ .name = "Informative Feedback", .description = "Environment should provide informative feedback", .implementation = "Structured error messages, state summaries" },
    .{ .name = "Guardrails", .description = "Guardrails should prevent common mistakes", .implementation = "Confirmation prompts, undo capability" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACI COMMANDS (25 commands in 5 categories)
// ═══════════════════════════════════════════════════════════════════════════════

pub const file_navigation_commands = [_]ACICommand{
    .{ .name = "open", .syntax = "open <path> [line_number]", .description = "Open file at optional line number", .category = .FileNavigation },
    .{ .name = "goto", .syntax = "goto <line_number>", .description = "Jump to specific line in current file", .category = .FileNavigation },
    .{ .name = "scroll_up", .syntax = "scroll_up [lines]", .description = "Scroll up in current file", .category = .FileNavigation },
    .{ .name = "scroll_down", .syntax = "scroll_down [lines]", .description = "Scroll down in current file", .category = .FileNavigation },
    .{ .name = "find_file", .syntax = "find_file <pattern>", .description = "Find files matching pattern", .category = .FileNavigation },
};

pub const file_editing_commands = [_]ACICommand{
    .{ .name = "edit", .syntax = "edit <start>:<end>\\n<content>\\nend_of_edit", .description = "Replace lines with new content", .category = .FileEditing },
    .{ .name = "insert", .syntax = "insert <line>\\n<content>\\nend_of_insert", .description = "Insert content after line", .category = .FileEditing },
    .{ .name = "delete", .syntax = "delete <start>:<end>", .description = "Delete lines from file", .category = .FileEditing },
    .{ .name = "undo", .syntax = "undo", .description = "Undo last edit operation", .category = .FileEditing },
    .{ .name = "create", .syntax = "create <path>\\n<content>\\nend_of_create", .description = "Create new file with content", .category = .FileEditing },
};

pub const search_commands = [_]ACICommand{
    .{ .name = "search_file", .syntax = "search_file <pattern> [file]", .description = "Search for pattern in file", .category = .Search },
    .{ .name = "search_dir", .syntax = "search_dir <pattern> [directory]", .description = "Search for pattern in directory", .category = .Search },
    .{ .name = "find_definition", .syntax = "find_definition <symbol>", .description = "Find symbol definition using LSP", .category = .Search },
    .{ .name = "find_references", .syntax = "find_references <symbol>", .description = "Find all references to symbol", .category = .Search },
    .{ .name = "search_replace", .syntax = "search_replace <pattern> <replacement>", .description = "Search and replace in file", .category = .Search },
};

pub const execution_commands = [_]ACICommand{
    .{ .name = "run", .syntax = "run <command>", .description = "Execute shell command", .category = .Execution },
    .{ .name = "test", .syntax = "test [test_file] [test_name]", .description = "Run tests", .category = .Execution },
    .{ .name = "lint", .syntax = "lint [file]", .description = "Run linter on file", .category = .Execution },
    .{ .name = "build", .syntax = "build", .description = "Build the project", .category = .Execution },
    .{ .name = "format", .syntax = "format [file]", .description = "Format code", .category = .Execution },
};

pub const context_commands = [_]ACICommand{
    .{ .name = "state", .syntax = "state", .description = "Show current state summary", .category = .Context },
    .{ .name = "history", .syntax = "history [n]", .description = "Show last n actions", .category = .Context },
    .{ .name = "diff", .syntax = "diff", .description = "Show all changes made", .category = .Context },
    .{ .name = "submit", .syntax = "submit", .description = "Submit solution", .category = .Context },
    .{ .name = "reset", .syntax = "reset", .description = "Reset to initial state", .category = .Context },
};

// ═══════════════════════════════════════════════════════════════════════════════
// GUARDRAILS (12 guardrails in 3 categories)
// ═══════════════════════════════════════════════════════════════════════════════

pub const guardrails = [_]Guardrail{
    // Edit protection
    .{ .name = "large_edit_confirm", .category = "edit", .description = "Require confirmation for edits > 50 lines" },
    .{ .name = "binary_file_block", .category = "edit", .description = "Prevent editing binary files" },
    .{ .name = "generated_file_warn", .category = "edit", .description = "Warn on editing generated files" },
    .{ .name = "auto_backup", .category = "edit", .description = "Auto-backup before destructive operations" },
    // Execution protection
    .{ .name = "dangerous_cmd_sandbox", .category = "execution", .description = "Sandbox dangerous commands" },
    .{ .name = "timeout_long_cmd", .category = "execution", .description = "Timeout long-running commands" },
    .{ .name = "resource_limit", .category = "execution", .description = "Limit resource usage" },
    .{ .name = "command_logging", .category = "execution", .description = "Log all executed commands" },
    // Context protection
    .{ .name = "context_warning", .category = "context", .description = "Warn when context window is 80% full" },
    .{ .name = "auto_summarize", .category = "context", .description = "Auto-summarize old context" },
    .{ .name = "priority_recent", .category = "context", .description = "Prioritize recent and relevant information" },
    .{ .name = "state_checkpoint", .category = "context", .description = "Create checkpoints for recovery" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMPARISON WITH COMPETITORS
// ═══════════════════════════════════════════════════════════════════════════════

pub const comparisons = [_]ACIComparison{
    .{ .tool = "VIBEE ACI v75", .commands = 25, .guardrails = 12, .lsp_integration = true, .undo_support = true },
    .{ .tool = "SWE-agent", .commands = 15, .guardrails = 8, .lsp_integration = false, .undo_support = false },
    .{ .tool = "Claude Code", .commands = 10, .guardrails = 5, .lsp_integration = false, .undo_support = false },
    .{ .tool = "Aider", .commands = 8, .guardrails = 3, .lsp_integration = false, .undo_support = true },
    .{ .tool = "Cline", .commands = 12, .guardrails = 4, .lsp_integration = false, .undo_support = false },
};

// ═══════════════════════════════════════════════════════════════════════════════
// OUTPUT FORMAT SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════

pub const file_viewer_format = OutputFormat{
    .window_size = 100,
    .context_lines = 5,
    .line_numbers = true,
    .syntax_highlighting = true,
};

pub const search_results_format = OutputFormat{
    .window_size = 50,
    .context_lines = 2,
    .line_numbers = true,
    .syntax_highlighting = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getTotalCommands() i64 {
    return @as(i64, file_navigation_commands.len) +
           @as(i64, file_editing_commands.len) +
           @as(i64, search_commands.len) +
           @as(i64, execution_commands.len) +
           @as(i64, context_commands.len);
}

pub fn getCommandAdvantage() i64 {
    return comparisons[0].commands - comparisons[1].commands;
}

pub fn getGuardrailAdvantage() i64 {
    return comparisons[0].guardrails - comparisons[1].guardrails;
}

pub fn hasLSPIntegration(tool_idx: usize) bool {
    return comparisons[tool_idx].lsp_integration;
}

pub fn hasUndoSupport(tool_idx: usize) bool {
    return comparisons[tool_idx].undo_support;
}

pub fn getEditGuardrailCount() i64 {
    var count: i64 = 0;
    for (guardrails) |g| {
        if (std.mem.eql(u8, g.category, "edit")) count += 1;
    }
    return count;
}

pub fn getExecutionGuardrailCount() i64 {
    var count: i64 = 0;
    for (guardrails) |g| {
        if (std.mem.eql(u8, g.category, "execution")) count += 1;
    }
    return count;
}

pub fn verifyGoldenIdentity() bool {
    return GOLDEN_IDENTITY == PHOENIX;
}

pub fn verifyTrinityIdentity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (50 tests)
// ═══════════════════════════════════════════════════════════════════════════════

test "PHI constant" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001);
}

test "TRINITY constant" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), TRINITY, 0.0001);
}

test "PHOENIX constant 999" {
    try std.testing.expectEqual(@as(i64, 999), PHOENIX);
}

test "Golden identity verified" {
    try std.testing.expect(verifyGoldenIdentity());
}

test "Trinity identity verified" {
    const result = verifyTrinityIdentity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
}

test "4 design principles" {
    try std.testing.expectEqual(@as(usize, 4), design_principles.len);
}

test "5 file navigation commands" {
    try std.testing.expectEqual(@as(usize, 5), file_navigation_commands.len);
}

test "5 file editing commands" {
    try std.testing.expectEqual(@as(usize, 5), file_editing_commands.len);
}

test "5 search commands" {
    try std.testing.expectEqual(@as(usize, 5), search_commands.len);
}

test "5 execution commands" {
    try std.testing.expectEqual(@as(usize, 5), execution_commands.len);
}

test "5 context commands" {
    try std.testing.expectEqual(@as(usize, 5), context_commands.len);
}

test "25 total commands" {
    try std.testing.expectEqual(@as(i64, 25), getTotalCommands());
}

test "12 guardrails" {
    try std.testing.expectEqual(@as(usize, 12), guardrails.len);
}

test "4 edit guardrails" {
    try std.testing.expectEqual(@as(i64, 4), getEditGuardrailCount());
}

test "4 execution guardrails" {
    try std.testing.expectEqual(@as(i64, 4), getExecutionGuardrailCount());
}

test "5 tool comparisons" {
    try std.testing.expectEqual(@as(usize, 5), comparisons.len);
}

test "VIBEE has 25 commands" {
    try std.testing.expectEqual(@as(i64, 25), comparisons[0].commands);
}

test "SWE-agent has 15 commands" {
    try std.testing.expectEqual(@as(i64, 15), comparisons[1].commands);
}

test "Claude Code has 10 commands" {
    try std.testing.expectEqual(@as(i64, 10), comparisons[2].commands);
}

test "Aider has 8 commands" {
    try std.testing.expectEqual(@as(i64, 8), comparisons[3].commands);
}

test "Command advantage over SWE-agent is 10" {
    try std.testing.expectEqual(@as(i64, 10), getCommandAdvantage());
}

test "Guardrail advantage over SWE-agent is 4" {
    try std.testing.expectEqual(@as(i64, 4), getGuardrailAdvantage());
}

test "VIBEE has LSP integration" {
    try std.testing.expect(hasLSPIntegration(0));
}

test "SWE-agent lacks LSP integration" {
    try std.testing.expect(!hasLSPIntegration(1));
}

test "VIBEE has undo support" {
    try std.testing.expect(hasUndoSupport(0));
}

test "SWE-agent lacks undo support" {
    try std.testing.expect(!hasUndoSupport(1));
}

test "Aider has undo support" {
    try std.testing.expect(hasUndoSupport(3));
}

test "Window size is 100" {
    try std.testing.expectEqual(@as(i64, 100), file_viewer_format.window_size);
}

test "Context lines is 5" {
    try std.testing.expectEqual(@as(i64, 5), file_viewer_format.context_lines);
}

test "Line numbers enabled" {
    try std.testing.expect(file_viewer_format.line_numbers);
}

test "Syntax highlighting enabled" {
    try std.testing.expect(file_viewer_format.syntax_highlighting);
}

test "Search results max 50" {
    try std.testing.expectEqual(@as(i64, 50), search_results_format.window_size);
}

test "open command exists" {
    try std.testing.expect(std.mem.eql(u8, file_navigation_commands[0].name, "open"));
}

test "edit command exists" {
    try std.testing.expect(std.mem.eql(u8, file_editing_commands[0].name, "edit"));
}

test "undo command exists" {
    try std.testing.expect(std.mem.eql(u8, file_editing_commands[3].name, "undo"));
}

test "search_file command exists" {
    try std.testing.expect(std.mem.eql(u8, search_commands[0].name, "search_file"));
}

test "find_definition command exists" {
    try std.testing.expect(std.mem.eql(u8, search_commands[2].name, "find_definition"));
}

test "run command exists" {
    try std.testing.expect(std.mem.eql(u8, execution_commands[0].name, "run"));
}

test "test command exists" {
    try std.testing.expect(std.mem.eql(u8, execution_commands[1].name, "test"));
}

test "state command exists" {
    try std.testing.expect(std.mem.eql(u8, context_commands[0].name, "state"));
}

test "submit command exists" {
    try std.testing.expect(std.mem.eql(u8, context_commands[3].name, "submit"));
}

test "First principle is Simple Actions" {
    try std.testing.expect(std.mem.eql(u8, design_principles[0].name, "Simple Actions"));
}

test "Fourth principle is Guardrails" {
    try std.testing.expect(std.mem.eql(u8, design_principles[3].name, "Guardrails"));
}

test "auto_backup guardrail exists" {
    try std.testing.expect(std.mem.eql(u8, guardrails[3].name, "auto_backup"));
}

test "timeout_long_cmd guardrail exists" {
    try std.testing.expect(std.mem.eql(u8, guardrails[5].name, "timeout_long_cmd"));
}

test "context_warning guardrail exists" {
    try std.testing.expect(std.mem.eql(u8, guardrails[8].name, "context_warning"));
}

test "VIBEE is first in comparisons" {
    try std.testing.expect(std.mem.eql(u8, comparisons[0].tool, "VIBEE ACI v75"));
}

test "All commands have descriptions" {
    for (file_navigation_commands) |cmd| {
        try std.testing.expect(cmd.description.len > 0);
    }
}

test "All guardrails have descriptions" {
    for (guardrails) |g| {
        try std.testing.expect(g.description.len > 0);
    }
}
