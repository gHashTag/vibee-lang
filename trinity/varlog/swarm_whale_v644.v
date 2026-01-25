// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - swarm_whale_v644 v5.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module swarm_whale_v644 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] Whale_position_in,
  output reg  [255:0] Whale_position_out,
  input  wire [63:0] Whale_fitness_in,
  output reg  [63:0] Whale_fitness_out,
  input  wire [63:0] Whale_a_coefficient_in,
  output reg  [63:0] Whale_a_coefficient_out,
  input  wire [63:0] WhaleConfig_population_in,
  output reg  [63:0] WhaleConfig_population_out,
  input  wire [63:0] WhaleConfig_max_iterations_in,
  output reg  [63:0] WhaleConfig_max_iterations_out,
  input  wire [63:0] WhaleConfig_a_decrease_in,
  output reg  [63:0] WhaleConfig_a_decrease_out,
  input  wire [63:0] WhaleConfig_b_constant_in,
  output reg  [63:0] WhaleConfig_b_constant_out,
  input  wire [255:0] WhaleState_best_whale_in,
  output reg  [255:0] WhaleState_best_whale_out,
  input  wire [63:0] WhaleState_best_fitness_in,
  output reg  [63:0] WhaleState_best_fitness_out,
  input  wire [63:0] WhaleState_iteration_in,
  output reg  [63:0] WhaleState_iteration_out,
  input  wire [63:0] WhaleMetrics_encircling_moves_in,
  output reg  [63:0] WhaleMetrics_encircling_moves_out,
  input  wire [63:0] WhaleMetrics_spiral_moves_in,
  output reg  [63:0] WhaleMetrics_spiral_moves_out,
  input  wire [63:0] WhaleMetrics_search_moves_in,
  output reg  [63:0] WhaleMetrics_search_moves_out,
  input  wire [63:0] WhaleMetrics_convergence_in,
  output reg  [63:0] WhaleMetrics_convergence_out,
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
      Whale_position_out <= 256'd0;
      Whale_fitness_out <= 64'd0;
      Whale_a_coefficient_out <= 64'd0;
      WhaleConfig_population_out <= 64'd0;
      WhaleConfig_max_iterations_out <= 64'd0;
      WhaleConfig_a_decrease_out <= 64'd0;
      WhaleConfig_b_constant_out <= 64'd0;
      WhaleState_best_whale_out <= 256'd0;
      WhaleState_best_fitness_out <= 64'd0;
      WhaleState_iteration_out <= 64'd0;
      WhaleMetrics_encircling_moves_out <= 64'd0;
      WhaleMetrics_spiral_moves_out <= 64'd0;
      WhaleMetrics_search_moves_out <= 64'd0;
      WhaleMetrics_convergence_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          Whale_position_out <= Whale_position_in;
          Whale_fitness_out <= Whale_fitness_in;
          Whale_a_coefficient_out <= Whale_a_coefficient_in;
          WhaleConfig_population_out <= WhaleConfig_population_in;
          WhaleConfig_max_iterations_out <= WhaleConfig_max_iterations_in;
          WhaleConfig_a_decrease_out <= WhaleConfig_a_decrease_in;
          WhaleConfig_b_constant_out <= WhaleConfig_b_constant_in;
          WhaleState_best_whale_out <= WhaleState_best_whale_in;
          WhaleState_best_fitness_out <= WhaleState_best_fitness_in;
          WhaleState_iteration_out <= WhaleState_iteration_in;
          WhaleMetrics_encircling_moves_out <= WhaleMetrics_encircling_moves_in;
          WhaleMetrics_spiral_moves_out <= WhaleMetrics_spiral_moves_in;
          WhaleMetrics_search_moves_out <= WhaleMetrics_search_moves_in;
          WhaleMetrics_convergence_out <= WhaleMetrics_convergence_in;
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
  // - initialize_whales
  // - encircle_prey
  // - spiral_update
  // - search_prey
  // - update_a_coefficient
  // - choose_mechanism
  // - update_best
  // - bubble_net_attack

endmodule
