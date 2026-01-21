const std = @import("std");

const igla_v8_benchmark = @import("igla_v8_benchmark.zig");
const igla_v8_constitutional = @import("igla_v8_constitutional.zig");
const igla_v8_core = @import("igla_v8_core.zig");
const igla_v8_deepseek_mla = @import("igla_v8_deepseek_mla.zig");
const igla_v8_dpo = @import("igla_v8_dpo.zig");
const igla_v8_gemma2 = @import("igla_v8_gemma2.zig");
const igla_v8_llama31 = @import("igla_v8_llama31.zig");
const igla_v8_moe_v2 = @import("igla_v8_moe_v2.zig");
const igla_v8_multimodal = @import("igla_v8_multimodal.zig");
const igla_v8_omniscient_fusion = @import("igla_v8_omniscient_fusion.zig");
const igla_v8_phi3 = @import("igla_v8_phi3.zig");
const igla_v8_qwen2 = @import("igla_v8_qwen2.zig");
const igla_v8_rlhf = @import("igla_v8_rlhf.zig");
const igla_v8_tool_use = @import("igla_v8_tool_use.zig");

comptime {
    _ = igla_v8_benchmark;
    _ = igla_v8_constitutional;
    _ = igla_v8_core;
    _ = igla_v8_deepseek_mla;
    _ = igla_v8_dpo;
    _ = igla_v8_gemma2;
    _ = igla_v8_llama31;
    _ = igla_v8_moe_v2;
    _ = igla_v8_multimodal;
    _ = igla_v8_omniscient_fusion;
    _ = igla_v8_phi3;
    _ = igla_v8_qwen2;
    _ = igla_v8_rlhf;
    _ = igla_v8_tool_use;
}
