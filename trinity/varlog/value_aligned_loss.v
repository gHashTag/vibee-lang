// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - value_aligned_loss v6.5.2
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module value_aligned_loss (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] ValueLossConfig_task_loss_weight_in,
  output reg  [63:0] ValueLossConfig_task_loss_weight_out,
  input  wire [63:0] ValueLossConfig_value_loss_weight_in,
  output reg  [63:0] ValueLossConfig_value_loss_weight_out,
  input  wire [63:0] ValueLossConfig_harm_penalty_weight_in,
  output reg  [63:0] ValueLossConfig_harm_penalty_weight_out,
  input  wire [63:0] ValueLoss_task_loss_in,
  output reg  [63:0] ValueLoss_task_loss_out,
  input  wire [63:0] ValueLoss_value_alignment_loss_in,
  output reg  [63:0] ValueLoss_value_alignment_loss_out,
  input  wire [63:0] ValueLoss_harm_penalty_in,
  output reg  [63:0] ValueLoss_harm_penalty_out,
  input  wire [63:0] ValueLoss_total_loss_in,
  output reg  [63:0] ValueLoss_total_loss_out,
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
      ValueLossConfig_task_loss_weight_out <= 64'd0;
      ValueLossConfig_value_loss_weight_out <= 64'd0;
      ValueLossConfig_harm_penalty_weight_out <= 64'd0;
      ValueLoss_task_loss_out <= 64'd0;
      ValueLoss_value_alignment_loss_out <= 64'd0;
      ValueLoss_harm_penalty_out <= 64'd0;
      ValueLoss_total_loss_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          ValueLossConfig_task_loss_weight_out <= ValueLossConfig_task_loss_weight_in;
          ValueLossConfig_value_loss_weight_out <= ValueLossConfig_value_loss_weight_in;
          ValueLossConfig_harm_penalty_weight_out <= ValueLossConfig_harm_penalty_weight_in;
          ValueLoss_task_loss_out <= ValueLoss_task_loss_in;
          ValueLoss_value_alignment_loss_out <= ValueLoss_value_alignment_loss_in;
          ValueLoss_harm_penalty_out <= ValueLoss_harm_penalty_in;
          ValueLoss_total_loss_out <= ValueLoss_total_loss_in;
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
  // - compute_value_loss
  // - compute_harm_penalty
  // - combined_loss
  // - preference_loss
  // - constitutional_loss
  // - reward_model_loss

endmodule
