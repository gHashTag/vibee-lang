// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - grover_search v3.3.1
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module grover_search (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] GroverConfig_num_elements_in,
  output reg  [63:0] GroverConfig_num_elements_out,
  input  wire [63:0] GroverConfig_num_targets_in,
  output reg  [63:0] GroverConfig_num_targets_out,
  input  wire [63:0] GroverConfig_amplification_factor_in,
  output reg  [63:0] GroverConfig_amplification_factor_out,
  input  wire [31:0] AmplitudeState_amplitudes_in,
  output reg  [31:0] AmplitudeState_amplitudes_out,
  input  wire [63:0] AmplitudeState_num_iterations_in,
  output reg  [63:0] AmplitudeState_num_iterations_out,
  input  wire [63:0] SearchResult_found_index_in,
  output reg  [63:0] SearchResult_found_index_out,
  input  wire [63:0] SearchResult_probability_in,
  output reg  [63:0] SearchResult_probability_out,
  input  wire [63:0] SearchResult_iterations_used_in,
  output reg  [63:0] SearchResult_iterations_used_out,
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
      GroverConfig_num_elements_out <= 64'd0;
      GroverConfig_num_targets_out <= 64'd0;
      GroverConfig_amplification_factor_out <= 64'd0;
      AmplitudeState_amplitudes_out <= 32'd0;
      AmplitudeState_num_iterations_out <= 64'd0;
      SearchResult_found_index_out <= 64'd0;
      SearchResult_probability_out <= 64'd0;
      SearchResult_iterations_used_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          GroverConfig_num_elements_out <= GroverConfig_num_elements_in;
          GroverConfig_num_targets_out <= GroverConfig_num_targets_in;
          GroverConfig_amplification_factor_out <= GroverConfig_amplification_factor_in;
          AmplitudeState_amplitudes_out <= AmplitudeState_amplitudes_in;
          AmplitudeState_num_iterations_out <= AmplitudeState_num_iterations_in;
          SearchResult_found_index_out <= SearchResult_found_index_in;
          SearchResult_probability_out <= SearchResult_probability_in;
          SearchResult_iterations_used_out <= SearchResult_iterations_used_in;
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
  // - init_superposition
  // - oracle_mark
  // - diffusion_operator
  // - grover_iteration
  // - optimal_iterations
  // - grover_search
  // - amplitude_estimation

endmodule
