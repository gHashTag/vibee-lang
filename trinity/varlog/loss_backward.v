// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - loss_backward v6.6.6
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module loss_backward (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] LossResult_loss_in,
  output reg  [63:0] LossResult_loss_out,
  input  wire [31:0] LossResult_grad_in,
  output reg  [31:0] LossResult_grad_out,
  input  wire [31:0] SoftmaxOutput_probs_in,
  output reg  [31:0] SoftmaxOutput_probs_out,
  input  wire [255:0] CEConfig_reduction_in,
  output reg  [255:0] CEConfig_reduction_out,
  input  wire [63:0] CEConfig_label_smoothing_in,
  output reg  [63:0] CEConfig_label_smoothing_out,
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
      LossResult_loss_out <= 64'd0;
      LossResult_grad_out <= 32'd0;
      SoftmaxOutput_probs_out <= 32'd0;
      CEConfig_reduction_out <= 256'd0;
      CEConfig_label_smoothing_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          LossResult_loss_out <= LossResult_loss_in;
          LossResult_grad_out <= LossResult_grad_in;
          SoftmaxOutput_probs_out <= SoftmaxOutput_probs_in;
          CEConfig_reduction_out <= CEConfig_reduction_in;
          CEConfig_label_smoothing_out <= CEConfig_label_smoothing_in;
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
  // - softmax_forward
  // - cross_entropy_loss
  // - cross_entropy_backward
  // - batch_cross_entropy
  // - batch_ce_backward
  // - mse_loss
  // - mse_backward

endmodule
