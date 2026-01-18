// ═══════════════════════════════════════════════════════════════════════════════
// IGLA - ИГЛА КОЩЕЯ COMPILER
// ═══════════════════════════════════════════════════════════════════════════════
// Based on vibeec/compiler.zig architecture
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tls_parser = @import("tls_parser.zig");
const zmei = @import("zmei_gorynych.zig");

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Print banner
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\═══════════════════════════════════════════════════════════════════════════════
        \\IGLA - ИГЛА КОЩЕЯ v{s}
        \\═══════════════════════════════════════════════════════════════════════════════
        \\Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
        \\Golden Identity: φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
    , .{VERSION});

    // Verify golden identity
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    if (@abs(result - GOLDEN_IDENTITY) < 0.0001) {
        try stdout.print("✓ Golden Identity verified: φ² + 1/φ² = {d:.6}\n\n", .{result});
    }

    if (args.len < 2) {
        try stdout.writeAll("Usage: igla <command> [options]\n\n");
        try stdout.writeAll("Commands:\n");
        try stdout.writeAll("  gen <file.tls>  Generate code from TLS specification\n");
        try stdout.writeAll("  test            Run tests\n");
        try stdout.writeAll("  version         Show version\n");
        return 0;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "version")) {
        try stdout.print("Igla version {s}\n", .{VERSION});
        return 0;
    }

    if (std.mem.eql(u8, command, "gen")) {
        if (args.len < 3) {
            try stdout.writeAll("Error: Missing input file\n");
            return 1;
        }

        const input_file = args[2];
        try stdout.print("Generating from: {s}\n", .{input_file});

        // Read file
        const file = std.fs.cwd().openFile(input_file, .{}) catch |err| {
            try stdout.print("Error opening file: {}\n", .{err});
            return 1;
        };
        defer file.close();

        const source = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch |err| {
            try stdout.print("Error reading file: {}\n", .{err});
            return 1;
        };
        defer allocator.free(source);

        // Parse
        var parser = tls_parser.TLSParser.init(allocator);
        defer parser.deinit();

        var spec = parser.parse(source) catch |err| {
            try stdout.print("Parse error: {}\n", .{err});
            return 1;
        };
        defer spec.deinit();

        try stdout.print("Parsed: {s} v{s}\n", .{ spec.name, spec.version });
        try stdout.print("Opcodes: {d}\n", .{spec.opcodes.items.len});
        try stdout.print("Behaviors: {d}\n", .{spec.behaviors.items.len});

        // Generate
        var generator = zmei.ZmeiGorynych.init(allocator) catch |err| {
            try stdout.print("Generator init error: {}\n", .{err});
            return 1;
        };
        defer generator.deinit();

        // Convert opcodes
        var opcodes = std.ArrayList(zmei.Opcode).init(allocator);
        defer opcodes.deinit();

        for (spec.opcodes.items) |op| {
            try opcodes.append(.{
                .code = op.code,
                .mnemonic = op.mnemonic,
                .stack_in = op.stack_in,
                .stack_out = op.stack_out,
                .semantics = op.semantics,
            });
        }

        const gen_result = generator.generate(opcodes.items) catch |err| {
            try stdout.print("Generation error: {}\n", .{err});
            return 1;
        };
        defer allocator.free(gen_result.zig_code);

        // Write output
        const output_path = "igla/output/trinity_vm_generated.zig";
        const out_file = std.fs.cwd().createFile(output_path, .{}) catch |err| {
            try stdout.print("Error creating output file: {}\n", .{err});
            return 1;
        };
        defer out_file.close();

        out_file.writeAll(gen_result.zig_code) catch |err| {
            try stdout.print("Error writing output: {}\n", .{err});
            return 1;
        };

        try stdout.print("\n✓ Generated: {s}\n", .{output_path});
        try stdout.print("  Types: {d}\n", .{gen_result.metrics.types_generated});
        try stdout.print("  Functions: {d}\n", .{gen_result.metrics.functions_generated});
        try stdout.print("  Tests: {d}\n", .{gen_result.metrics.tests_generated});
        try stdout.print("  Cache hit ratio: {d:.1}%\n", .{gen_result.metrics.cache_hit_ratio * 100});
        try stdout.print("  Buffer reallocations: {d}\n", .{gen_result.metrics.buffer_reallocations});
        try stdout.print("  Total bytes: {d}\n", .{gen_result.metrics.total_bytes});

        return 0;
    }

    if (std.mem.eql(u8, command, "test")) {
        try stdout.writeAll("Running tests...\n");
        // Tests are run via `zig build test`
        return 0;
    }

    try stdout.print("Unknown command: {s}\n", .{command});
    return 1;
}

test "main_golden_identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}
