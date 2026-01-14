// ═══════════════════════════════════════════════════════════════
// REPL 999 v2.0 - Enhanced Ternary Logic REPL
// Based on: Kleene logic, Tekum arithmetic, HT logic
// ═══════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════
// TERNARY TYPE (Balanced: -1, 0, +1 mapped to ▽, ○, △)
// ═══════════════════════════════════════════════════════════════

pub const Trit = enum(i8) {
    False = -1,   // ▽
    Unknown = 0,  // ○
    True = 1,     // △

    // Kleene Strong AND (minimum)
    pub fn tritAnd(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    // Kleene Strong OR (maximum)
    pub fn tritOr(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    // NOT (negation)
    pub fn tritNot(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    // Implication: ¬a ∨ b
    pub fn tritImplies(a: Trit, b: Trit) Trit {
        return tritOr(tritNot(a), b);
    }

    // Equivalence: (a→b) ∧ (b→a)
    pub fn tritEquiv(a: Trit, b: Trit) Trit {
        return tritAnd(tritImplies(a, b), tritImplies(b, a));
    }

    // Consensus: returns value if equal, else unknown
    pub fn tritConsensus(a: Trit, b: Trit) Trit {
        return if (a == b) a else .Unknown;
    }

    // Majority vote of three values
    pub fn tritMajority(a: Trit, b: Trit, c: Trit) Trit {
        const ab = tritAnd(a, b);
        const bc = tritAnd(b, c);
        const ac = tritAnd(a, c);
        return tritOr(ab, tritOr(bc, ac));
    }

    // Convert to confidence (0.0 - 1.0)
    pub fn toConfidence(self: Trit) f64 {
        return switch (self) {
            .True => 1.0,
            .Unknown => 0.5,
            .False => 0.0,
        };
    }

    // Convert from confidence
    pub fn fromConfidence(c: f64) Trit {
        if (c > 0.66) return .True;
        if (c > 0.33) return .Unknown;
        return .False;
    }

    // Balanced ternary value (-1, 0, +1)
    pub fn toBalanced(self: Trit) i8 {
        return @intFromEnum(self);
    }

    pub fn symbol(self: Trit) []const u8 {
        return switch (self) {
            .True => "△",
            .Unknown => "○",
            .False => "▽",
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// TEKUM-STYLE ARITHMETIC (Balanced Ternary)
// ═══════════════════════════════════════════════════════════════

pub const TekumNumber = struct {
    trits: [27]Trit, // 27 trits for precision
    exponent: i8,

    pub fn fromFloat(f: f64) TekumNumber {
        var result = TekumNumber{ .trits = undefined, .exponent = 0 };
        var val = f;
        
        // Normalize
        while (std.math.fabs(val) >= 1.5) {
            val /= 3.0;
            result.exponent += 1;
        }
        while (std.math.fabs(val) < 0.5 and val != 0) {
            val *= 3.0;
            result.exponent -= 1;
        }
        
        // Convert to balanced ternary
        for (&result.trits) |*t| {
            if (val > 0.5) {
                t.* = .True;
                val -= 1.0;
            } else if (val < -0.5) {
                t.* = .False;
                val += 1.0;
            } else {
                t.* = .Unknown;
            }
            val *= 3.0;
        }
        
        return result;
    }

    pub fn toFloat(self: TekumNumber) f64 {
        var result: f64 = 0;
        var power: f64 = 1.0;
        
        for (self.trits) |t| {
            result += @as(f64, @floatFromInt(t.toBalanced())) * power;
            power /= 3.0;
        }
        
        // Apply exponent
        var exp = self.exponent;
        while (exp > 0) : (exp -= 1) result *= 3.0;
        while (exp < 0) : (exp += 1) result /= 3.0;
        
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════
// REPL
// ═══════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll(
        \\╔══════════════════════════════════════════════════════════════════╗
        \\║  999 REPL v2.0 - Enhanced Ternary Logic                          ║
        \\║  Based on: Kleene logic, Tekum arithmetic, HT logic              ║
        \\╠══════════════════════════════════════════════════════════════════╣
        \\║  Ternary Values: △ (true/+1), ○ (unknown/0), ▽ (false/-1)       ║
        \\║  Type 'help' for commands, 'exit' to quit                        ║
        \\╚══════════════════════════════════════════════════════════════════╝
        \\
    );

    var buf: [1024]u8 = undefined;
    while (true) {
        try stdout.writeAll("\n999> ");
        const line = stdin.readUntilDelimiter(&buf, '\n') catch break;
        
        if (std.mem.eql(u8, line, "exit") or std.mem.eql(u8, line, "quit")) break;
        if (line.len == 0) continue;

        try processCommand(stdout, line);
    }

    try stdout.writeAll("\nGoodbye! △\n");
}

fn processCommand(stdout: anytype, line: []const u8) !void {
    // Ternary literals
    if (std.mem.eql(u8, line, "△") or std.mem.eql(u8, line, "true")) {
        try stdout.writeAll("△ (true, confidence: 1.0, balanced: +1)\n");
        return;
    }
    if (std.mem.eql(u8, line, "○") or std.mem.eql(u8, line, "unknown")) {
        try stdout.writeAll("○ (unknown, confidence: 0.5, balanced: 0)\n");
        return;
    }
    if (std.mem.eql(u8, line, "▽") or std.mem.eql(u8, line, "false")) {
        try stdout.writeAll("▽ (false, confidence: 0.0, balanced: -1)\n");
        return;
    }

    // Help
    if (std.mem.eql(u8, line, "help")) {
        try stdout.writeAll(
            \\
            \\═══════════════════════════════════════════════════════════════
            \\COMMANDS:
            \\═══════════════════════════════════════════════════════════════
            \\
            \\LITERALS:
            \\  △, true      - Ternary true (+1)
            \\  ○, unknown   - Ternary unknown (0)
            \\  ▽, false     - Ternary false (-1)
            \\
            \\OPERATIONS (Kleene Strong):
            \\  and          - Show AND truth table (minimum)
            \\  or           - Show OR truth table (maximum)
            \\  not          - Show NOT truth table (negation)
            \\  implies      - Show IMPLIES truth table (¬a ∨ b)
            \\  equiv        - Show EQUIV truth table ((a→b) ∧ (b→a))
            \\
            \\ADVANCED:
            \\  consensus    - Show CONSENSUS operation
            \\  majority     - Show MAJORITY voting
            \\  confidence   - Show confidence values
            \\  balanced     - Show balanced ternary values
            \\  tekum        - Show Tekum arithmetic info
            \\
            \\THEORY:
            \\  kleene       - About Kleene's 3-valued logic
            \\  lukasiewicz  - About Łukasiewicz logic
            \\  ht           - About Here-and-There logic
            \\
            \\OTHER:
            \\  help         - Show this help
            \\  exit, quit   - Exit REPL
            \\═══════════════════════════════════════════════════════════════
            \\
        );
        return;
    }

    // AND truth table
    if (std.mem.eql(u8, line, "and") or std.mem.eql(u8, line, "trit_and")) {
        try stdout.writeAll(
            \\
            \\AND (Kleene Strong) - Returns minimum:
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ▽
            \\  ○ │ ○   ○   ▽
            \\  ▽ │ ▽   ▽   ▽
            \\
            \\Rule: If either is ▽, result is ▽
            \\      If either is ○ (and none ▽), result is ○
            \\      Only △ ∧ △ = △
            \\
        );
        return;
    }

    // OR truth table
    if (std.mem.eql(u8, line, "or") or std.mem.eql(u8, line, "trit_or")) {
        try stdout.writeAll(
            \\
            \\OR (Kleene Strong) - Returns maximum:
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   △   △
            \\  ○ │ △   ○   ○
            \\  ▽ │ △   ○   ▽
            \\
            \\Rule: If either is △, result is △
            \\      If either is ○ (and none △), result is ○
            \\      Only ▽ ∨ ▽ = ▽
            \\
        );
        return;
    }

    // NOT truth table
    if (std.mem.eql(u8, line, "not") or std.mem.eql(u8, line, "trit_not")) {
        try stdout.writeAll(
            \\
            \\NOT (Negation):
            \\
            \\  ¬△ = ▽
            \\  ¬○ = ○  (unknown stays unknown)
            \\  ¬▽ = △
            \\
            \\In balanced ternary: ¬x = -x
            \\
        );
        return;
    }

    // IMPLIES
    if (std.mem.eql(u8, line, "implies") or std.mem.eql(u8, line, "trit_implies")) {
        try stdout.writeAll(
            \\
            \\IMPLIES (a → b = ¬a ∨ b):
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ▽
            \\  ○ │ △   ○   ○
            \\  ▽ │ △   △   △
            \\
            \\Rule: ▽ implies anything is △
            \\      △ implies ▽ is ▽
            \\
        );
        return;
    }

    // EQUIV
    if (std.mem.eql(u8, line, "equiv") or std.mem.eql(u8, line, "trit_equiv")) {
        try stdout.writeAll(
            \\
            \\EQUIV (a ↔ b = (a→b) ∧ (b→a)):
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ▽
            \\  ○ │ ○   ○   ○
            \\  ▽ │ ▽   ○   △
            \\
            \\Rule: Same values → that value
            \\      Different → ○ or ▽
            \\
        );
        return;
    }

    // CONSENSUS
    if (std.mem.eql(u8, line, "consensus")) {
        try stdout.writeAll(
            \\
            \\CONSENSUS (Agreement):
            \\
            \\  consensus(a, b) = a if a == b, else ○
            \\
            \\    │ △   ○   ▽
            \\────┼───────────
            \\  △ │ △   ○   ○
            \\  ○ │ ○   ○   ○
            \\  ▽ │ ○   ○   ▽
            \\
            \\Use: Distributed systems, voting
            \\
        );
        return;
    }

    // MAJORITY
    if (std.mem.eql(u8, line, "majority")) {
        try stdout.writeAll(
            \\
            \\MAJORITY (Voting with 3 inputs):
            \\
            \\  majority(a, b, c) = (a∧b) ∨ (b∧c) ∨ (a∧c)
            \\
            \\Examples:
            \\  majority(△, △, ▽) = △
            \\  majority(△, ▽, ▽) = ▽
            \\  majority(△, ○, ▽) = ○
            \\  majority(○, ○, △) = ○
            \\
            \\Use: Fault-tolerant systems, consensus
            \\
        );
        return;
    }

    // CONFIDENCE
    if (std.mem.eql(u8, line, "confidence")) {
        try stdout.writeAll(
            \\
            \\CONFIDENCE VALUES:
            \\
            \\  △ → 1.0 (100% certain true)
            \\  ○ → 0.5 (50% uncertain)
            \\  ▽ → 0.0 (100% certain false)
            \\
            \\Conversion:
            \\  c > 0.66 → △
            \\  c > 0.33 → ○
            \\  c ≤ 0.33 → ▽
            \\
        );
        return;
    }

    // BALANCED
    if (std.mem.eql(u8, line, "balanced")) {
        try stdout.writeAll(
            \\
            \\BALANCED TERNARY:
            \\
            \\  △ → +1
            \\  ○ →  0
            \\  ▽ → -1
            \\
            \\Properties:
            \\  - No separate sign bit needed
            \\  - Negation is just sign flip
            \\  - Rounding is simpler
            \\  - Used in Soviet Setun computer (1958)
            \\
        );
        return;
    }

    // TEKUM
    if (std.mem.eql(u8, line, "tekum")) {
        try stdout.writeAll(
            \\
            \\TEKUM ARITHMETIC (arXiv:2512.10964):
            \\
            \\Balanced ternary tapered precision format:
            \\  - Uses trits instead of bits
            \\  - More energy-efficient
            \\  - Better precision distribution
            \\  - Outperforms binary posits/takums
            \\
            \\999 OS uses 27 trits (3³) for numbers.
            \\
        );
        return;
    }

    // KLEENE
    if (std.mem.eql(u8, line, "kleene")) {
        try stdout.writeAll(
            \\
            \\KLEENE'S THREE-VALUED LOGIC (1938):
            \\
            \\Stephen Kleene introduced 3VL for partial recursive functions.
            \\
            \\Strong Kleene (K₃):
            \\  - AND = minimum
            \\  - OR = maximum
            \\  - Unknown doesn't always propagate
            \\
            \\Weak Kleene:
            \\  - Unknown always propagates
            \\  - △ ∧ ○ = ○ (not ○ like in strong)
            \\
            \\999 OS uses Strong Kleene semantics.
            \\
        );
        return;
    }

    // LUKASIEWICZ
    if (std.mem.eql(u8, line, "lukasiewicz")) {
        try stdout.writeAll(
            \\
            \\ŁUKASIEWICZ LOGIC (1920):
            \\
            \\Jan Łukasiewicz created first many-valued logic.
            \\
            \\Ł₃ (three-valued):
            \\  - Values: 0, ½, 1
            \\  - Implication: a → b = min(1, 1-a+b)
            \\  - Foundation for fuzzy logic
            \\
            \\Difference from Kleene:
            \\  - ○ → ○ = △ in Łukasiewicz
            \\  - ○ → ○ = ○ in Kleene
            \\
        );
        return;
    }

    // HT Logic
    if (std.mem.eql(u8, line, "ht")) {
        try stdout.writeAll(
            \\
            \\HERE-AND-THERE LOGIC (Gödel's G₃):
            \\
            \\Three-valued logic for Answer Set Programming.
            \\
            \\Values:
            \\  - Here (h) - definitely true
            \\  - There (t) - possibly true
            \\  - False (f) - definitely false
            \\
            \\Used in:
            \\  - Logic programming semantics
            \\  - Equilibrium models
            \\  - Non-monotonic reasoning
            \\
            \\See: arXiv:2601.04080
            \\
        );
        return;
    }

    // Unknown command
    try stdout.print("Unknown command: {s}\nType 'help' for available commands.\n", .{line});
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "kleene and" {
    try std.testing.expectEqual(Trit.True, Trit.tritAnd(.True, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritAnd(.True, .Unknown));
    try std.testing.expectEqual(Trit.False, Trit.tritAnd(.True, .False));
    try std.testing.expectEqual(Trit.False, Trit.tritAnd(.Unknown, .False));
}

test "kleene or" {
    try std.testing.expectEqual(Trit.True, Trit.tritOr(.True, .False));
    try std.testing.expectEqual(Trit.True, Trit.tritOr(.Unknown, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritOr(.Unknown, .Unknown));
}

test "kleene not" {
    try std.testing.expectEqual(Trit.False, Trit.tritNot(.True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritNot(.Unknown));
    try std.testing.expectEqual(Trit.True, Trit.tritNot(.False));
}

test "consensus" {
    try std.testing.expectEqual(Trit.True, Trit.tritConsensus(.True, .True));
    try std.testing.expectEqual(Trit.Unknown, Trit.tritConsensus(.True, .False));
}

test "majority" {
    try std.testing.expectEqual(Trit.True, Trit.tritMajority(.True, .True, .False));
    try std.testing.expectEqual(Trit.False, Trit.tritMajority(.True, .False, .False));
}

test "confidence" {
    try std.testing.expectEqual(@as(f64, 1.0), Trit.True.toConfidence());
    try std.testing.expectEqual(@as(f64, 0.5), Trit.Unknown.toConfidence());
    try std.testing.expectEqual(@as(f64, 0.0), Trit.False.toConfidence());
}
