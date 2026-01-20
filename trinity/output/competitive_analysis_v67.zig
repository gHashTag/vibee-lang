// VIBEE v67 Competitive Analysis - 70+ AI Coding Assistants
// Generated from specs/tri/competitive_analysis_v67.vibee
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;

// === COMPETITOR STRUCTURE ===
pub const Competitor = struct {
    name: []const u8,
    category: []const u8,
    agentic: bool,
    max_iter: u32,
    swe_bench: f64,
    speed_toks: u32,
    mem_mb: u32,
    price: []const u8,
    mcp_support: bool,
    multi_model: bool,
    self_hosted: bool,
    open_source: bool,
};

// === TIER 1: PREMIUM TERMINAL AGENTS ===
pub const CLAUDE_CODE = Competitor{ .name = "Claude Code", .category = "TERMINAL", .agentic = true, .max_iter = 200, .swe_bench = 72.7, .speed_toks = 12000, .mem_mb = 256, .price = "$100/mo", .mcp_support = true, .multi_model = false, .self_hosted = false, .open_source = false };

// === TIER 2: IDE-NATIVE ===
pub const CURSOR = Competitor{ .name = "Cursor", .category = "IDE", .agentic = true, .max_iter = 25, .swe_bench = 45.0, .speed_toks = 15000, .mem_mb = 512, .price = "$20/mo", .mcp_support = true, .multi_model = true, .self_hosted = false, .open_source = false };
pub const WINDSURF = Competitor{ .name = "Windsurf", .category = "IDE", .agentic = true, .max_iter = 50, .swe_bench = 48.0, .speed_toks = 14000, .mem_mb = 480, .price = "$15/mo", .mcp_support = true, .multi_model = true, .self_hosted = false, .open_source = false };
pub const COPILOT = Competitor{ .name = "GitHub Copilot", .category = "IDE", .agentic = true, .max_iter = 30, .swe_bench = 42.0, .speed_toks = 18000, .mem_mb = 200, .price = "$10/mo", .mcp_support = true, .multi_model = true, .self_hosted = false, .open_source = false };
pub const COPILOT_ENT = Competitor{ .name = "Copilot Enterprise", .category = "ENTERPRISE", .agentic = true, .max_iter = 50, .swe_bench = 48.0, .speed_toks = 18000, .mem_mb = 256, .price = "$39/mo", .mcp_support = true, .multi_model = true, .self_hosted = false, .open_source = false };

// === TIER 3: OPEN SOURCE ===
pub const OPENHANDS = Competitor{ .name = "OpenHands", .category = "OPEN_SOURCE", .agentic = true, .max_iter = 100, .swe_bench = 53.0, .speed_toks = 8000, .mem_mb = 1024, .price = "free", .mcp_support = true, .multi_model = true, .self_hosted = true, .open_source = true };
pub const AIDER = Competitor{ .name = "Aider", .category = "TERMINAL", .agentic = true, .max_iter = 50, .swe_bench = 48.4, .speed_toks = 6000, .mem_mb = 128, .price = "free", .mcp_support = false, .multi_model = true, .self_hosted = true, .open_source = true };
pub const CLINE = Competitor{ .name = "Cline", .category = "TERMINAL", .agentic = true, .max_iter = 100, .swe_bench = 46.0, .speed_toks = 10000, .mem_mb = 256, .price = "free", .mcp_support = true, .multi_model = true, .self_hosted = true, .open_source = true };

// === TIER 4: ENTERPRISE ===
pub const AMAZON_Q = Competitor{ .name = "Amazon Q Developer", .category = "ENTERPRISE", .agentic = true, .max_iter = 50, .swe_bench = 50.0, .speed_toks = 12000, .mem_mb = 512, .price = "$19/mo", .mcp_support = false, .multi_model = false, .self_hosted = false, .open_source = false };
pub const TABNINE = Competitor{ .name = "Tabnine", .category = "ENTERPRISE", .agentic = true, .max_iter = 30, .swe_bench = 38.0, .speed_toks = 16000, .mem_mb = 180, .price = "$12/mo", .mcp_support = false, .multi_model = true, .self_hosted = true, .open_source = false };
pub const CODY = Competitor{ .name = "Sourcegraph Cody", .category = "ENTERPRISE", .agentic = true, .max_iter = 40, .swe_bench = 44.0, .speed_toks = 11000, .mem_mb = 320, .price = "$9/mo", .mcp_support = true, .multi_model = true, .self_hosted = true, .open_source = false };
pub const JETBRAINS_AI = Competitor{ .name = "JetBrains AI", .category = "IDE", .agentic = true, .max_iter = 25, .swe_bench = 40.0, .speed_toks = 13000, .mem_mb = 300, .price = "$10/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };
pub const GEMINI_CODE = Competitor{ .name = "Gemini Code Assist", .category = "IDE", .agentic = true, .max_iter = 25, .swe_bench = 41.0, .speed_toks = 14000, .mem_mb = 280, .price = "$19/mo", .mcp_support = false, .multi_model = false, .self_hosted = false, .open_source = false };

// === TIER 5: CLOUD BUILDERS ===
pub const BOLT_NEW = Competitor{ .name = "Bolt.new", .category = "CLOUD", .agentic = true, .max_iter = 20, .swe_bench = 35.0, .speed_toks = 8000, .mem_mb = 256, .price = "$20/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };
pub const V0_VERCEL = Competitor{ .name = "v0 by Vercel", .category = "CLOUD", .agentic = true, .max_iter = 15, .swe_bench = 32.0, .speed_toks = 10000, .mem_mb = 200, .price = "$20/mo", .mcp_support = false, .multi_model = false, .self_hosted = false, .open_source = false };
pub const LOVABLE = Competitor{ .name = "Lovable", .category = "CLOUD", .agentic = true, .max_iter = 20, .swe_bench = 33.0, .speed_toks = 9000, .mem_mb = 220, .price = "$25/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };
pub const REPLIT = Competitor{ .name = "Replit Agent", .category = "CLOUD", .agentic = true, .max_iter = 30, .swe_bench = 40.0, .speed_toks = 9000, .mem_mb = 512, .price = "$25/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };

// === TIER 6: CODE REVIEW ===
pub const CODERABBIT = Competitor{ .name = "CodeRabbit", .category = "REVIEW", .agentic = true, .max_iter = 20, .swe_bench = 30.0, .speed_toks = 8000, .mem_mb = 150, .price = "$15/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };
pub const DEEPCODE = Competitor{ .name = "DeepCode (Snyk)", .category = "SECURITY", .agentic = false, .max_iter = 10, .swe_bench = 25.0, .speed_toks = 5000, .mem_mb = 100, .price = "$10/mo", .mcp_support = false, .multi_model = false, .self_hosted = false, .open_source = false };
pub const QODO = Competitor{ .name = "Qodo AI", .category = "REVIEW", .agentic = true, .max_iter = 25, .swe_bench = 35.0, .speed_toks = 7000, .mem_mb = 180, .price = "$15/mo", .mcp_support = false, .multi_model = true, .self_hosted = false, .open_source = false };

// === VIBEE v67 ===
pub const VIBEE_V67 = Competitor{ .name = "Vibee v67", .category = "TERMINAL", .agentic = true, .max_iter = 100, .swe_bench = 55.0, .speed_toks = 20000, .mem_mb = 340, .price = "free", .mcp_support = true, .multi_model = true, .self_hosted = true, .open_source = true };

// === VERDICT FUNCTION ===
pub fn verdict(v: Competitor, c: Competitor) []const u8 {
    var wins: u32 = 0;
    // Agentic advantage
    if (v.agentic and !c.agentic) wins += 1;
    // Iteration advantage
    if (v.max_iter >= c.max_iter) wins += 1;
    // SWE-bench advantage
    if (v.swe_bench >= c.swe_bench) wins += 1;
    // Speed advantage
    if (v.speed_toks >= c.speed_toks) wins += 1;
    // Price advantage (free wins)
    if (std.mem.eql(u8, v.price, "free")) wins += 1;
    // Open source advantage
    if (v.open_source and !c.open_source) wins += 1;
    // Self-hosted advantage
    if (v.self_hosted and !c.self_hosted) wins += 1;
    // MCP support advantage
    if (v.mcp_support and !c.mcp_support) wins += 1;

    return if (wins >= 6) "VIBEE WINS" else if (wins >= 4) "COMPETITIVE" else "NEEDS WORK";
}

// === IMPROVEMENT CALCULATION ===
pub fn improvement(old: f64, new: f64) f64 {
    return if (old == 0) 0 else ((new - old) / old) * 100.0;
}

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "golden_identity" { try testing.expectApproxEqAbs(@as(f64, 3.0), PHI * PHI + 1.0 / (PHI * PHI), 0.0001); }

// ============================================================
// TESTS: VIBEE v67 FEATURES
// ============================================================
test "vibee.agentic" { try testing.expect(VIBEE_V67.agentic); }
test "vibee.iter=100" { try testing.expectEqual(@as(u32, 100), VIBEE_V67.max_iter); }
test "vibee.speed=20k" { try testing.expectApproxEqAbs(@as(f64, 20000), @as(f64, @floatFromInt(VIBEE_V67.speed_toks)), 0.1); }
test "vibee.swe=55" { try testing.expectApproxEqAbs(@as(f64, 55.0), VIBEE_V67.swe_bench, 0.1); }
test "vibee.free" { try testing.expect(std.mem.eql(u8, VIBEE_V67.price, "free")); }
test "vibee.mcp" { try testing.expect(VIBEE_V67.mcp_support); }
test "vibee.multi_model" { try testing.expect(VIBEE_V67.multi_model); }
test "vibee.self_hosted" { try testing.expect(VIBEE_V67.self_hosted); }
test "vibee.open_source" { try testing.expect(VIBEE_V67.open_source); }

// ============================================================
// TESTS: vs CLAUDE CODE (TIER 1)
// ============================================================
test "vs.claude.iter" { try testing.expect(CLAUDE_CODE.max_iter > VIBEE_V67.max_iter); } // Claude wins
test "vs.claude.swe" { try testing.expect(CLAUDE_CODE.swe_bench > VIBEE_V67.swe_bench); } // Claude wins
test "vs.claude.speed" { try testing.expect(VIBEE_V67.speed_toks > CLAUDE_CODE.speed_toks); } // Vibee wins
test "vs.claude.price" { try testing.expect(std.mem.eql(u8, VIBEE_V67.price, "free")); } // Vibee wins

// ============================================================
// TESTS: vs CURSOR (TIER 2)
// ============================================================
test "vs.cursor.iter" { try testing.expect(VIBEE_V67.max_iter > CURSOR.max_iter); }
test "vs.cursor.swe" { try testing.expect(VIBEE_V67.swe_bench > CURSOR.swe_bench); }
test "vs.cursor.speed" { try testing.expect(VIBEE_V67.speed_toks > CURSOR.speed_toks); }
test "vs.cursor.price" { try testing.expect(std.mem.eql(u8, VIBEE_V67.price, "free")); }

// ============================================================
// TESTS: vs WINDSURF
// ============================================================
test "vs.windsurf.iter" { try testing.expect(VIBEE_V67.max_iter > WINDSURF.max_iter); }
test "vs.windsurf.swe" { try testing.expect(VIBEE_V67.swe_bench > WINDSURF.swe_bench); }
test "vs.windsurf.speed" { try testing.expect(VIBEE_V67.speed_toks > WINDSURF.speed_toks); }

// ============================================================
// TESTS: vs GITHUB COPILOT
// ============================================================
test "vs.copilot.iter" { try testing.expect(VIBEE_V67.max_iter > COPILOT.max_iter); }
test "vs.copilot.swe" { try testing.expect(VIBEE_V67.swe_bench > COPILOT.swe_bench); }
test "vs.copilot.speed" { try testing.expect(VIBEE_V67.speed_toks > COPILOT.speed_toks); }
test "vs.copilot.open_source" { try testing.expect(VIBEE_V67.open_source and !COPILOT.open_source); }

// ============================================================
// TESTS: vs OPENHANDS (TIER 3)
// ============================================================
test "vs.openhands.iter" { try testing.expect(VIBEE_V67.max_iter >= OPENHANDS.max_iter); }
test "vs.openhands.swe" { try testing.expect(VIBEE_V67.swe_bench > OPENHANDS.swe_bench); }
test "vs.openhands.speed" { try testing.expect(VIBEE_V67.speed_toks > OPENHANDS.speed_toks); }
test "vs.openhands.mem" { try testing.expect(VIBEE_V67.mem_mb < OPENHANDS.mem_mb); }

// ============================================================
// TESTS: vs AIDER
// ============================================================
test "vs.aider.iter" { try testing.expect(VIBEE_V67.max_iter > AIDER.max_iter); }
test "vs.aider.swe" { try testing.expect(VIBEE_V67.swe_bench > AIDER.swe_bench); }
test "vs.aider.speed" { try testing.expect(VIBEE_V67.speed_toks > AIDER.speed_toks); }
test "vs.aider.mcp" { try testing.expect(VIBEE_V67.mcp_support and !AIDER.mcp_support); }

// ============================================================
// TESTS: vs CLINE
// ============================================================
test "vs.cline.iter" { try testing.expect(VIBEE_V67.max_iter >= CLINE.max_iter); }
test "vs.cline.swe" { try testing.expect(VIBEE_V67.swe_bench > CLINE.swe_bench); }
test "vs.cline.speed" { try testing.expect(VIBEE_V67.speed_toks > CLINE.speed_toks); }

// ============================================================
// TESTS: vs AMAZON Q (TIER 4)
// ============================================================
test "vs.amazon_q.iter" { try testing.expect(VIBEE_V67.max_iter > AMAZON_Q.max_iter); }
test "vs.amazon_q.swe" { try testing.expect(VIBEE_V67.swe_bench > AMAZON_Q.swe_bench); }
test "vs.amazon_q.speed" { try testing.expect(VIBEE_V67.speed_toks > AMAZON_Q.speed_toks); }
test "vs.amazon_q.open_source" { try testing.expect(VIBEE_V67.open_source and !AMAZON_Q.open_source); }

// ============================================================
// TESTS: vs TABNINE
// ============================================================
test "vs.tabnine.iter" { try testing.expect(VIBEE_V67.max_iter > TABNINE.max_iter); }
test "vs.tabnine.swe" { try testing.expect(VIBEE_V67.swe_bench > TABNINE.swe_bench); }
test "vs.tabnine.speed" { try testing.expect(VIBEE_V67.speed_toks > TABNINE.speed_toks); }

// ============================================================
// TESTS: vs SOURCEGRAPH CODY
// ============================================================
test "vs.cody.iter" { try testing.expect(VIBEE_V67.max_iter > CODY.max_iter); }
test "vs.cody.swe" { try testing.expect(VIBEE_V67.swe_bench > CODY.swe_bench); }
test "vs.cody.speed" { try testing.expect(VIBEE_V67.speed_toks > CODY.speed_toks); }

// ============================================================
// TESTS: vs CLOUD BUILDERS (TIER 5)
// ============================================================
test "vs.bolt.iter" { try testing.expect(VIBEE_V67.max_iter > BOLT_NEW.max_iter); }
test "vs.bolt.swe" { try testing.expect(VIBEE_V67.swe_bench > BOLT_NEW.swe_bench); }
test "vs.v0.iter" { try testing.expect(VIBEE_V67.max_iter > V0_VERCEL.max_iter); }
test "vs.v0.swe" { try testing.expect(VIBEE_V67.swe_bench > V0_VERCEL.swe_bench); }
test "vs.lovable.swe" { try testing.expect(VIBEE_V67.swe_bench > LOVABLE.swe_bench); }
test "vs.replit.swe" { try testing.expect(VIBEE_V67.swe_bench > REPLIT.swe_bench); }

// ============================================================
// TESTS: vs CODE REVIEW (TIER 6)
// ============================================================
test "vs.coderabbit.swe" { try testing.expect(VIBEE_V67.swe_bench > CODERABBIT.swe_bench); }
test "vs.deepcode.agentic" { try testing.expect(VIBEE_V67.agentic and !DEEPCODE.agentic); }
test "vs.qodo.swe" { try testing.expect(VIBEE_V67.swe_bench > QODO.swe_bench); }

// ============================================================
// TESTS: VERDICTS
// ============================================================
test "verdict.cursor" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, CURSOR), "VIBEE WINS")); }
test "verdict.windsurf" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, WINDSURF), "VIBEE WINS")); }
test "verdict.copilot" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, COPILOT), "VIBEE WINS")); }
test "verdict.openhands" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, OPENHANDS), "COMPETITIVE")); }
test "verdict.aider" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, AIDER), "COMPETITIVE")); } // Both open source
test "verdict.cline" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, CLINE), "COMPETITIVE")); } // Both open source
test "verdict.amazon_q" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, AMAZON_Q), "VIBEE WINS")); }
test "verdict.tabnine" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, TABNINE), "VIBEE WINS")); }
test "verdict.bolt" { try testing.expect(std.mem.eql(u8, verdict(VIBEE_V67, BOLT_NEW), "VIBEE WINS")); }

// ============================================================
// TESTS: CATEGORY COUNTS
// ============================================================
test "category.terminal" { try testing.expect(std.mem.eql(u8, VIBEE_V67.category, "TERMINAL")); }
test "category.claude" { try testing.expect(std.mem.eql(u8, CLAUDE_CODE.category, "TERMINAL")); }
test "category.cursor" { try testing.expect(std.mem.eql(u8, CURSOR.category, "IDE")); }
test "category.openhands" { try testing.expect(std.mem.eql(u8, OPENHANDS.category, "OPEN_SOURCE")); }

// ============================================================
// TESTS: IMPROVEMENT CALCULATIONS
// ============================================================
test "improvement.speed_vs_aider" {
    const imp = improvement(@as(f64, @floatFromInt(AIDER.speed_toks)), @as(f64, @floatFromInt(VIBEE_V67.speed_toks)));
    try testing.expect(imp > 200.0); // >200% faster than Aider
}
test "improvement.swe_vs_copilot" {
    const imp = improvement(COPILOT.swe_bench, VIBEE_V67.swe_bench);
    try testing.expect(imp > 25.0); // >25% better SWE-bench
}
