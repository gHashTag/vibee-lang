// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - state_space_models v3.6.1
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module state_space_models (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] SSMConfig_d_model_in,
  output reg  [63:0] SSMConfig_d_model_out,
  input  wire [63:0] SSMConfig_d_state_in,
  output reg  [63:0] SSMConfig_d_state_out,
  input  wire [63:0] SSMConfig_d_conv_in,
  output reg  [63:0] SSMConfig_d_conv_out,
  input  wire [63:0] SSMConfig_expand_in,
  output reg  [63:0] SSMConfig_expand_out,
  input  wire [255:0] SSMConfig_dt_rank_in,
  output reg  [255:0] SSMConfig_dt_rank_out,
  input  wire [31:0] SSMState_hidden_state_in,
  output reg  [31:0] SSMState_hidden_state_out,
  input  wire [31:0] SSMState_conv_state_in,
  output reg  [31:0] SSMState_conv_state_out,
  input  wire [31:0] S4Params_A_in,
  output reg  [31:0] S4Params_A_out,
  input  wire [31:0] S4Params_B_in,
  output reg  [31:0] S4Params_B_out,
  input  wire [31:0] S4Params_C_in,
  output reg  [31:0] S4Params_C_out,
  input  wire [31:0] S4Params_D_in,
  output reg  [31:0] S4Params_D_out,
  input  wire [31:0] S4Params_delta_in,
  output reg  [31:0] S4Params_delta_out,
  input  wire [31:0] MambaBlock_in_proj_in,
  output reg  [31:0] MambaBlock_in_proj_out,
  input  wire [31:0] MambaBlock_conv1d_in,
  output reg  [31:0] MambaBlock_conv1d_out,
  input  wire [31:0] MambaBlock_x_proj_in,
  output reg  [31:0] MambaBlock_x_proj_out,
  input  wire [31:0] MambaBlock_dt_proj_in,
  output reg  [31:0] MambaBlock_dt_proj_out,
  input  wire [31:0] MambaBlock_out_proj_in,
  output reg  [31:0] MambaBlock_out_proj_out,
  input  wire [31:0] MambaBlock_A_log_in,
  output reg  [31:0] MambaBlock_A_log_out,
  input  wire [31:0] MambaBlock_D_in,
  output reg  [31:0] MambaBlock_D_out,
  input  wire [63:0] SelectiveScanConfig_d_inner_in,
  output reg  [63:0] SelectiveScanConfig_d_inner_out,
  input  wire [63:0] SelectiveScanConfig_dt_rank_in,
  output reg  [63:0] SelectiveScanConfig_dt_rank_out,
  input  wire  SelectiveScanConfig_use_fast_path_in,
  output reg   SelectiveScanConfig_use_fast_path_out,
  input  wire [31:0] ConvState_buffer_in,
  output reg  [31:0] ConvState_buffer_out,
  input  wire [63:0] ConvState_kernel_size_in,
  output reg  [63:0] ConvState_kernel_size_out,
  input  wire [31:0] DiscreteParams_A_bar_in,
  output reg  [31:0] DiscreteParams_A_bar_out,
  input  wire [31:0] DiscreteParams_B_bar_in,
  output reg  [31:0] DiscreteParams_B_bar_out,
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
      SSMConfig_d_model_out <= 64'd0;
      SSMConfig_d_state_out <= 64'd0;
      SSMConfig_d_conv_out <= 64'd0;
      SSMConfig_expand_out <= 64'd0;
      SSMConfig_dt_rank_out <= 256'd0;
      SSMState_hidden_state_out <= 32'd0;
      SSMState_conv_state_out <= 32'd0;
      S4Params_A_out <= 32'd0;
      S4Params_B_out <= 32'd0;
      S4Params_C_out <= 32'd0;
      S4Params_D_out <= 32'd0;
      S4Params_delta_out <= 32'd0;
      MambaBlock_in_proj_out <= 32'd0;
      MambaBlock_conv1d_out <= 32'd0;
      MambaBlock_x_proj_out <= 32'd0;
      MambaBlock_dt_proj_out <= 32'd0;
      MambaBlock_out_proj_out <= 32'd0;
      MambaBlock_A_log_out <= 32'd0;
      MambaBlock_D_out <= 32'd0;
      SelectiveScanConfig_d_inner_out <= 64'd0;
      SelectiveScanConfig_dt_rank_out <= 64'd0;
      SelectiveScanConfig_use_fast_path_out <= 1'b0;
      ConvState_buffer_out <= 32'd0;
      ConvState_kernel_size_out <= 64'd0;
      DiscreteParams_A_bar_out <= 32'd0;
      DiscreteParams_B_bar_out <= 32'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SSMConfig_d_model_out <= SSMConfig_d_model_in;
          SSMConfig_d_state_out <= SSMConfig_d_state_in;
          SSMConfig_d_conv_out <= SSMConfig_d_conv_in;
          SSMConfig_expand_out <= SSMConfig_expand_in;
          SSMConfig_dt_rank_out <= SSMConfig_dt_rank_in;
          SSMState_hidden_state_out <= SSMState_hidden_state_in;
          SSMState_conv_state_out <= SSMState_conv_state_in;
          S4Params_A_out <= S4Params_A_in;
          S4Params_B_out <= S4Params_B_in;
          S4Params_C_out <= S4Params_C_in;
          S4Params_D_out <= S4Params_D_in;
          S4Params_delta_out <= S4Params_delta_in;
          MambaBlock_in_proj_out <= MambaBlock_in_proj_in;
          MambaBlock_conv1d_out <= MambaBlock_conv1d_in;
          MambaBlock_x_proj_out <= MambaBlock_x_proj_in;
          MambaBlock_dt_proj_out <= MambaBlock_dt_proj_in;
          MambaBlock_out_proj_out <= MambaBlock_out_proj_in;
          MambaBlock_A_log_out <= MambaBlock_A_log_in;
          MambaBlock_D_out <= MambaBlock_D_in;
          SelectiveScanConfig_d_inner_out <= SelectiveScanConfig_d_inner_in;
          SelectiveScanConfig_dt_rank_out <= SelectiveScanConfig_dt_rank_in;
          SelectiveScanConfig_use_fast_path_out <= SelectiveScanConfig_use_fast_path_in;
          ConvState_buffer_out <= ConvState_buffer_in;
          ConvState_kernel_size_out <= ConvState_kernel_size_in;
          DiscreteParams_A_bar_out <= DiscreteParams_A_bar_in;
          DiscreteParams_B_bar_out <= DiscreteParams_B_bar_in;
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
  // - init_ssm
  // - discretize_ssm
  // - ssm_forward
  // - selective_scan
  // - conv1d_forward
  // - mamba_block_forward
  // - init_hidden_state
  // - step_ssm

endmodule
