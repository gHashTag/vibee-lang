// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - backward_pass v6.0.1
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module backward_pass (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [31:0] BackwardContext_input_cache_in,
  output reg  [31:0] BackwardContext_input_cache_out,
  input  wire [31:0] BackwardContext_weight_cache_in,
  output reg  [31:0] BackwardContext_weight_cache_out,
  input  wire [31:0] BackwardContext_output_cache_in,
  output reg  [31:0] BackwardContext_output_cache_out,
  input  wire [31:0] LinearGrad_input_grad_in,
  output reg  [31:0] LinearGrad_input_grad_out,
  input  wire [31:0] LinearGrad_weight_grad_in,
  output reg  [31:0] LinearGrad_weight_grad_out,
  input  wire [31:0] LinearGrad_bias_grad_in,
  output reg  [31:0] LinearGrad_bias_grad_out,
  input  wire [31:0] AttentionGrad_query_grad_in,
  output reg  [31:0] AttentionGrad_query_grad_out,
  input  wire [31:0] AttentionGrad_key_grad_in,
  output reg  [31:0] AttentionGrad_key_grad_out,
  input  wire [31:0] AttentionGrad_value_grad_in,
  output reg  [31:0] AttentionGrad_value_grad_out,
  input  wire [31:0] AttentionGrad_attn_grad_in,
  output reg  [31:0] AttentionGrad_attn_grad_out,
  input  wire [31:0] ActivationGrad_input_grad_in,
  output reg  [31:0] ActivationGrad_input_grad_out,
  input  wire [31:0] LossGrad_predictions_grad_in,
  output reg  [31:0] LossGrad_predictions_grad_out,
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
      BackwardContext_input_cache_out <= 32'd0;
      BackwardContext_weight_cache_out <= 32'd0;
      BackwardContext_output_cache_out <= 32'd0;
      LinearGrad_input_grad_out <= 32'd0;
      LinearGrad_weight_grad_out <= 32'd0;
      LinearGrad_bias_grad_out <= 32'd0;
      AttentionGrad_query_grad_out <= 32'd0;
      AttentionGrad_key_grad_out <= 32'd0;
      AttentionGrad_value_grad_out <= 32'd0;
      AttentionGrad_attn_grad_out <= 32'd0;
      ActivationGrad_input_grad_out <= 32'd0;
      LossGrad_predictions_grad_out <= 32'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          BackwardContext_input_cache_out <= BackwardContext_input_cache_in;
          BackwardContext_weight_cache_out <= BackwardContext_weight_cache_in;
          BackwardContext_output_cache_out <= BackwardContext_output_cache_in;
          LinearGrad_input_grad_out <= LinearGrad_input_grad_in;
          LinearGrad_weight_grad_out <= LinearGrad_weight_grad_in;
          LinearGrad_bias_grad_out <= LinearGrad_bias_grad_in;
          AttentionGrad_query_grad_out <= AttentionGrad_query_grad_in;
          AttentionGrad_key_grad_out <= AttentionGrad_key_grad_in;
          AttentionGrad_value_grad_out <= AttentionGrad_value_grad_in;
          AttentionGrad_attn_grad_out <= AttentionGrad_attn_grad_in;
          ActivationGrad_input_grad_out <= ActivationGrad_input_grad_in;
          LossGrad_predictions_grad_out <= LossGrad_predictions_grad_in;
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
  // - linear_backward
  // - matmul_backward
  // - gelu_backward
  // - relu_backward
  // - softmax_backward
  // - attention_backward
  // - cross_entropy_backward
  // - layer_norm_backward

endmodule
