// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - igla_flash_attention v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module igla_flash_attention (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] FlashAttentionConfig_head_dim_in,
  output reg  [63:0] FlashAttentionConfig_head_dim_out,
  input  wire [63:0] FlashAttentionConfig_num_heads_in,
  output reg  [63:0] FlashAttentionConfig_num_heads_out,
  input  wire [63:0] FlashAttentionConfig_block_size_in,
  output reg  [63:0] FlashAttentionConfig_block_size_out,
  input  wire  FlashAttentionConfig_use_causal_in,
  output reg   FlashAttentionConfig_use_causal_out,
  input  wire [63:0] FlashAttentionConfig_softmax_scale_in,
  output reg  [63:0] FlashAttentionConfig_softmax_scale_out,
  input  wire [255:0] AttentionInput_query_in,
  output reg  [255:0] AttentionInput_query_out,
  input  wire [255:0] AttentionInput_key_in,
  output reg  [255:0] AttentionInput_key_out,
  input  wire [255:0] AttentionInput_value_in,
  output reg  [255:0] AttentionInput_value_out,
  input  wire [255:0] AttentionInput_attention_mask_in,
  output reg  [255:0] AttentionInput_attention_mask_out,
  input  wire [255:0] AttentionOutput_output_in,
  output reg  [255:0] AttentionOutput_output_out,
  input  wire [255:0] AttentionOutput_softmax_lse_in,
  output reg  [255:0] AttentionOutput_softmax_lse_out,
  input  wire [63:0] BlockInfo_block_q_in,
  output reg  [63:0] BlockInfo_block_q_out,
  input  wire [63:0] BlockInfo_block_k_in,
  output reg  [63:0] BlockInfo_block_k_out,
  input  wire [63:0] BlockInfo_num_blocks_in,
  output reg  [63:0] BlockInfo_num_blocks_out,
  input  wire [255:0] FlashAttentionV2_version_in,
  output reg  [255:0] FlashAttentionV2_version_out,
  input  wire  FlashAttentionV2_supports_variable_len_in,
  output reg   FlashAttentionV2_supports_variable_len_out,
  input  wire  FlashAttentionV2_supports_alibi_in,
  output reg   FlashAttentionV2_supports_alibi_out,
  input  wire  FlashAttentionV2_supports_sliding_window_in,
  output reg   FlashAttentionV2_supports_sliding_window_out,
  input  wire [63:0] SlidingWindow_window_size_in,
  output reg  [63:0] SlidingWindow_window_size_out,
  input  wire [63:0] SlidingWindow_sink_tokens_in,
  output reg  [63:0] SlidingWindow_sink_tokens_out,
  input  wire [63:0] AttentionMetrics_total_flops_in,
  output reg  [63:0] AttentionMetrics_total_flops_out,
  input  wire [63:0] AttentionMetrics_memory_saved_mb_in,
  output reg  [63:0] AttentionMetrics_memory_saved_mb_out,
  input  wire [63:0] AttentionMetrics_speedup_vs_naive_in,
  output reg  [63:0] AttentionMetrics_speedup_vs_naive_out,
  input  wire [63:0] AttentionMetrics_avg_latency_ms_in,
  output reg  [63:0] AttentionMetrics_avg_latency_ms_out,
  output reg         done
);

  // Sacred constants (φ² + 1/φ² = 3)
  localparam [31:0] PHI = 32'd1618033;      // φ × 10^6
  localparam [31:0] PHI_INV = 32'd618033;   // 1/φ × 10^6
  localparam [31:0] TRINITY = 32'd3;        // φ² + 1/φ² = 3
  localparam [31:0] PHOENIX = 32'd999;      // Sacred number

  // State machine
  localparam IDLE = 2'b00, PROCESS = 2'b01, DONE = 2'b10;
  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      FlashAttentionConfig_head_dim_out <= 64'd0;
      FlashAttentionConfig_num_heads_out <= 64'd0;
      FlashAttentionConfig_block_size_out <= 64'd0;
      FlashAttentionConfig_use_causal_out <= 1'b0;
      FlashAttentionConfig_softmax_scale_out <= 64'd0;
      AttentionInput_query_out <= 256'd0;
      AttentionInput_key_out <= 256'd0;
      AttentionInput_value_out <= 256'd0;
      AttentionInput_attention_mask_out <= 256'd0;
      AttentionOutput_output_out <= 256'd0;
      AttentionOutput_softmax_lse_out <= 256'd0;
      BlockInfo_block_q_out <= 64'd0;
      BlockInfo_block_k_out <= 64'd0;
      BlockInfo_num_blocks_out <= 64'd0;
      FlashAttentionV2_version_out <= 256'd0;
      FlashAttentionV2_supports_variable_len_out <= 1'b0;
      FlashAttentionV2_supports_alibi_out <= 1'b0;
      FlashAttentionV2_supports_sliding_window_out <= 1'b0;
      SlidingWindow_window_size_out <= 64'd0;
      SlidingWindow_sink_tokens_out <= 64'd0;
      AttentionMetrics_total_flops_out <= 64'd0;
      AttentionMetrics_memory_saved_mb_out <= 64'd0;
      AttentionMetrics_speedup_vs_naive_out <= 64'd0;
      AttentionMetrics_avg_latency_ms_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          FlashAttentionConfig_head_dim_out <= FlashAttentionConfig_head_dim_in;
          FlashAttentionConfig_num_heads_out <= FlashAttentionConfig_num_heads_in;
          FlashAttentionConfig_block_size_out <= FlashAttentionConfig_block_size_in;
          FlashAttentionConfig_use_causal_out <= FlashAttentionConfig_use_causal_in;
          FlashAttentionConfig_softmax_scale_out <= FlashAttentionConfig_softmax_scale_in;
          AttentionInput_query_out <= AttentionInput_query_in;
          AttentionInput_key_out <= AttentionInput_key_in;
          AttentionInput_value_out <= AttentionInput_value_in;
          AttentionInput_attention_mask_out <= AttentionInput_attention_mask_in;
          AttentionOutput_output_out <= AttentionOutput_output_in;
          AttentionOutput_softmax_lse_out <= AttentionOutput_softmax_lse_in;
          BlockInfo_block_q_out <= BlockInfo_block_q_in;
          BlockInfo_block_k_out <= BlockInfo_block_k_in;
          BlockInfo_num_blocks_out <= BlockInfo_num_blocks_in;
          FlashAttentionV2_version_out <= FlashAttentionV2_version_in;
          FlashAttentionV2_supports_variable_len_out <= FlashAttentionV2_supports_variable_len_in;
          FlashAttentionV2_supports_alibi_out <= FlashAttentionV2_supports_alibi_in;
          FlashAttentionV2_supports_sliding_window_out <= FlashAttentionV2_supports_sliding_window_in;
          SlidingWindow_window_size_out <= SlidingWindow_window_size_in;
          SlidingWindow_sink_tokens_out <= SlidingWindow_sink_tokens_in;
          AttentionMetrics_total_flops_out <= AttentionMetrics_total_flops_in;
          AttentionMetrics_memory_saved_mb_out <= AttentionMetrics_memory_saved_mb_in;
          AttentionMetrics_speedup_vs_naive_out <= AttentionMetrics_speedup_vs_naive_in;
          AttentionMetrics_avg_latency_ms_out <= AttentionMetrics_avg_latency_ms_in;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Behaviors:
  // - flash_attention_forward
  // - flash_attention_backward
  // - compute_block_attention
  // - apply_causal_mask
  // - apply_alibi
  // - sliding_window_attention
  // - fused_softmax
  // - get_memory_savings
  // - get_metrics

endmodule
