//! VIBEE QUANTUM TRIT-CODE ENGINE - CLI
//!
//! Command-line interface for Quantum Trit-Code Engine
//!
//! Usage:
//!   vibee-quantum --code "Hello World" --target "l"
//!   vibee-quantum --code "ABC" --target "B"
//!
//! Flow:
//! 1. Tritizer: Code -> Trits
//! 2. Qutritizer: Trits -> Amplitudes (Superposition)
//! 3. Quantum Agent: Search target in Superposition (Grover-like)

const std = @import("std");
const tritizer = @import("src/quantum/tritizer.zig");
const qutritizer = @import("src/quantum/qutritizer.zig");
const quantum_agent = @import("src/quantum/quantum_agent.zig");

/// CLI Command
pub const Command = struct {
    /// Code to search in (string)
    code: []const u8,
    /// Target character to find (trit: -1, 0, 1)
    target: u8,
    /// Verbose mode (print debug info)
    verbose: bool,
};

/// Run Quantum Trit-Code Engine
pub fn run(cmd: Command) !void {
    const allocator = std.heap.page_allocator;

    // Step 1: Tritizer (Code -> Trits)
    if (cmd.verbose) std.debug.print("Step 1: Tritizing code...\n", .{});
    const trits = try tritizer.stringToTrits(allocator, cmd.code);
    defer allocator.free(trits);

    if (cmd.verbose) {
        const trit_str = try tritizer.tritsToString(allocator, trits);
        defer allocator.free(trit_str);
        std.debug.print("  Code: '{s}' -> Trits: '{s}'\n", .{ cmd.code, trit_str });
    }

    // Step 2: Qutritizer (Trits -> Amplitudes)
    if (cmd.verbose) std.debug.print("Step 2: Qutritizing trits...\n", .{});
    const qstate = qutritizer.tritsToQutrit(trits);
    std.debug.print("  Amplitudes: α={d:.3}, β={d:.3}, γ={d:.3}\n", .{ qstate.alpha, qstate.beta, qstate.gamma });

    // Step 3: Quantum Agent (Search in Superposition)
    if (cmd.verbose) std.debug.print("Step 3: Quantum Agent searching...\n", .{});
    const target_i8 = @as(i8, @intCast(cmd.target));
    var agent = quantum_agent.QuantumAgent.init(allocator, trits, target_i8);

    const start_time = std.time.nanoTimestamp();
    const result = try agent.search();
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    // Step 4: Output Results
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║       QUANTUM TRIT-CODE ENGINE (MVP DEMO)        ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Input Code: {s: >20}                        ║\n", .{cmd.code});
    std.debug.print("║  Code Length: {d: >2} trits                       ║\n", .{trits.len});
    std.debug.print("║  Target Char: '{c}' (Trit: {d: >2})                  ║\n", .{ cmd.target, target_i8 });
    std.debug.print("║  Search Mode: Grover-like (O(√N))               ║\n", .{});
    std.debug.print("║                                                   ║\n", .{});
    std.debug.print("║  Found At: Index {d: >2}                         ║\n", .{result.index});
    std.debug.print("║  Target Value: '{c}' (Trit: {d: >2})    ║\n", .{ cmd.code[result.index], trits[result.index] });
    std.debug.print("║  Iterations: {d: >2} (Classical: {d: >2})         ║\n", .{ result.iterations, trits.len });
    std.debug.print("║  Speedup:   {d: >2}× (Theoretical)              ║\n", .{@divFloor(trits.len, result.iterations)});
    std.debug.print("║  Duration:  {d: >5} ms                                ║\n", .{@as(usize, @intFromFloat(duration_ms))});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n", .{});
}

pub fn main() !void {
    var args = try std.process.argsAlloc(std.heap.page_allocator);
    defer args.deinit();

    // Parse arguments
    if (args.len < 2) {
        std.debug.print("VIBEE Quantum Trit-Code Engine (MVP)\n\n", .{});
        std.debug.print("Usage: vibee-quantum --code \"<string>\" --target \"<char>\"\n", .{});
        std.debug.print("Example: vibee-quantum --code \"Hello World\" --target \"l\"\n", .{});
        return;
    }

    var cmd = Command{
        .code = "",
        .target = 0,
        .verbose = false,
    };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--code")) {
            if (i + 1 < args.len) {
                i += 1;
                cmd.code = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--target")) {
            if (i + 1 < args.len) {
                i += 1;
                if (args[i].len == 1) {
                    cmd.target = args[i][0];
                }
            }
        } else if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
            cmd.verbose = true;
        }
    }

    // Validate input
    if (cmd.code.len == 0) {
        std.debug.print("Error: --code argument is required.\n", .{});
        return;
    }
    if (cmd.target == 0) {
        std.debug.print("Error: --target argument must be a single character.\n", .{});
        return;
    }

    // Run engine
    try run(cmd);
}
