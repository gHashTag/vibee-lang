// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - linear_backward v6.6.2
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module linear_backward (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [31:0] LinearLayer_weight_in,
  output reg  [31:0] LinearLayer_weight_out,
  input  wire [31:0] LinearLayer_bias_in,
  output reg  [31:0] LinearLayer_bias_out,
  input  wire [31:0] LinearLayer_weight_grad_in,
  output reg  [31:0] LinearLayer_weight_grad_out,
  input  wire [31:0] LinearLayer_bias_grad_in,
  output reg  [31:0] LinearLayer_bias_grad_out,
  input  wire [63:0] LinearLayer_in_features_in,
  output reg  [63:0] LinearLayer_in_features_out,
  input  wire [63:0] LinearLayer_out_features_in,
  output reg  [63:0] LinearLayer_out_features_out,
  input  wire [31:0] LinearCache_input_in,
  output reg  [31:0] LinearCache_input_out,
  input  wire [63:0] LinearCache_batch_size_in,
  output reg  [63:0] LinearCache_batch_size_out,
  input  wire [31:0] LinearGrads_d_weight_in,
  output reg  [31:0] LinearGrads_d_weight_out,
  input  wire [31:0] LinearGrads_d_bias_in,
  output reg  [31:0] LinearGrads_d_bias_out,
  input  wire [31:0] LinearGrads_d_input_in,
  output reg  [31:0] LinearGrads_d_input_out,
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
      LinearLayer_weight_out <= 32'd0;
      LinearLayer_bias_out <= 32'd0;
      LinearLayer_weight_grad_out <= 32'd0;
      LinearLayer_bias_grad_out <= 32'd0;
      LinearLayer_in_features_out <= 64'd0;
      LinearLayer_out_features_out <= 64'd0;
      LinearCache_input_out <= 32'd0;
      LinearCache_batch_size_out <= 64'd0;
      LinearGrads_d_weight_out <= 32'd0;
      LinearGrads_d_bias_out <= 32'd0;
      LinearGrads_d_input_out <= 32'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          LinearLayer_weight_out <= LinearLayer_weight_in;
          LinearLayer_bias_out <= LinearLayer_bias_in;
          LinearLayer_weight_grad_out <= LinearLayer_weight_grad_in;
          LinearLayer_bias_grad_out <= LinearLayer_bias_grad_in;
          LinearLayer_in_features_out <= LinearLayer_in_features_in;
          LinearLayer_out_features_out <= LinearLayer_out_features_in;
          LinearCache_input_out <= LinearCache_input_in;
          LinearCache_batch_size_out <= LinearCache_batch_size_in;
          LinearGrads_d_weight_out <= LinearGrads_d_weight_in;
          LinearGrads_d_bias_out <= LinearGrads_d_bias_in;
          LinearGrads_d_input_out <= LinearGrads_d_input_in;
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
  // - linear_init
  // - linear_forward
  // - linear_backward
  // - linear_zero_grad
  // - linear_num_params
  // - matmul_forward
  // - matmul_backward_a
  // - matmul_backward_b

endmodule
