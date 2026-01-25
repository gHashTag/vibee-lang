// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - swarm_particle_v640 v5.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module swarm_particle_v640 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] Particle_position_in,
  output reg  [255:0] Particle_position_out,
  input  wire [255:0] Particle_velocity_in,
  output reg  [255:0] Particle_velocity_out,
  input  wire [255:0] Particle_personal_best_in,
  output reg  [255:0] Particle_personal_best_out,
  input  wire [63:0] Particle_personal_best_fitness_in,
  output reg  [63:0] Particle_personal_best_fitness_out,
  input  wire [63:0] SwarmConfig_particles_in,
  output reg  [63:0] SwarmConfig_particles_out,
  input  wire [63:0] SwarmConfig_dimensions_in,
  output reg  [63:0] SwarmConfig_dimensions_out,
  input  wire [63:0] SwarmConfig_inertia_in,
  output reg  [63:0] SwarmConfig_inertia_out,
  input  wire [63:0] SwarmConfig_cognitive_in,
  output reg  [63:0] SwarmConfig_cognitive_out,
  input  wire [63:0] SwarmConfig_social_in,
  output reg  [63:0] SwarmConfig_social_out,
  input  wire [255:0] SwarmState_global_best_in,
  output reg  [255:0] SwarmState_global_best_out,
  input  wire [63:0] SwarmState_global_best_fitness_in,
  output reg  [63:0] SwarmState_global_best_fitness_out,
  input  wire [63:0] SwarmState_iteration_in,
  output reg  [63:0] SwarmState_iteration_out,
  input  wire  SwarmState_converged_in,
  output reg   SwarmState_converged_out,
  input  wire [63:0] SwarmMetrics_iterations_in,
  output reg  [63:0] SwarmMetrics_iterations_out,
  input  wire [63:0] SwarmMetrics_evaluations_in,
  output reg  [63:0] SwarmMetrics_evaluations_out,
  input  wire [63:0] SwarmMetrics_convergence_rate_in,
  output reg  [63:0] SwarmMetrics_convergence_rate_out,
  input  wire [63:0] SwarmMetrics_diversity_in,
  output reg  [63:0] SwarmMetrics_diversity_out,
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
      Particle_position_out <= 256'd0;
      Particle_velocity_out <= 256'd0;
      Particle_personal_best_out <= 256'd0;
      Particle_personal_best_fitness_out <= 64'd0;
      SwarmConfig_particles_out <= 64'd0;
      SwarmConfig_dimensions_out <= 64'd0;
      SwarmConfig_inertia_out <= 64'd0;
      SwarmConfig_cognitive_out <= 64'd0;
      SwarmConfig_social_out <= 64'd0;
      SwarmState_global_best_out <= 256'd0;
      SwarmState_global_best_fitness_out <= 64'd0;
      SwarmState_iteration_out <= 64'd0;
      SwarmState_converged_out <= 1'b0;
      SwarmMetrics_iterations_out <= 64'd0;
      SwarmMetrics_evaluations_out <= 64'd0;
      SwarmMetrics_convergence_rate_out <= 64'd0;
      SwarmMetrics_diversity_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          Particle_position_out <= Particle_position_in;
          Particle_velocity_out <= Particle_velocity_in;
          Particle_personal_best_out <= Particle_personal_best_in;
          Particle_personal_best_fitness_out <= Particle_personal_best_fitness_in;
          SwarmConfig_particles_out <= SwarmConfig_particles_in;
          SwarmConfig_dimensions_out <= SwarmConfig_dimensions_in;
          SwarmConfig_inertia_out <= SwarmConfig_inertia_in;
          SwarmConfig_cognitive_out <= SwarmConfig_cognitive_in;
          SwarmConfig_social_out <= SwarmConfig_social_in;
          SwarmState_global_best_out <= SwarmState_global_best_in;
          SwarmState_global_best_fitness_out <= SwarmState_global_best_fitness_in;
          SwarmState_iteration_out <= SwarmState_iteration_in;
          SwarmState_converged_out <= SwarmState_converged_in;
          SwarmMetrics_iterations_out <= SwarmMetrics_iterations_in;
          SwarmMetrics_evaluations_out <= SwarmMetrics_evaluations_in;
          SwarmMetrics_convergence_rate_out <= SwarmMetrics_convergence_rate_in;
          SwarmMetrics_diversity_out <= SwarmMetrics_diversity_in;
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
  // - initialize_swarm
  // - evaluate_fitness
  // - update_personal_best
  // - update_global_best
  // - update_velocity
  // - update_position
  // - check_convergence
  // - adapt_parameters

endmodule
