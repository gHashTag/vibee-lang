// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - prototype_explanation_v16850 v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module prototype_explanation_v16850 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] Prototype_id_in,
  output reg  [255:0] Prototype_id_out,
  input  wire [255:0] Prototype_representation_in,
  output reg  [255:0] Prototype_representation_out,
  input  wire [255:0] Prototype_class_label_in,
  output reg  [255:0] Prototype_class_label_out,
  input  wire [255:0] PrototypeNetwork_prototypes_in,
  output reg  [255:0] PrototypeNetwork_prototypes_out,
  input  wire [255:0] PrototypeNetwork_encoder_in,
  output reg  [255:0] PrototypeNetwork_encoder_out,
  input  wire [255:0] PrototypeExplanation_instance_in,
  output reg  [255:0] PrototypeExplanation_instance_out,
  input  wire [255:0] PrototypeExplanation_nearest_prototypes_in,
  output reg  [255:0] PrototypeExplanation_nearest_prototypes_out,
  input  wire [255:0] PrototypeExplanation_similarities_in,
  output reg  [255:0] PrototypeExplanation_similarities_out,
  input  wire [63:0] PrototypeConfig_num_prototypes_in,
  output reg  [63:0] PrototypeConfig_num_prototypes_out,
  input  wire [63:0] PrototypeConfig_projection_dim_in,
  output reg  [63:0] PrototypeConfig_projection_dim_out,
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
      Prototype_id_out <= 256'd0;
      Prototype_representation_out <= 256'd0;
      Prototype_class_label_out <= 256'd0;
      PrototypeNetwork_prototypes_out <= 256'd0;
      PrototypeNetwork_encoder_out <= 256'd0;
      PrototypeExplanation_instance_out <= 256'd0;
      PrototypeExplanation_nearest_prototypes_out <= 256'd0;
      PrototypeExplanation_similarities_out <= 256'd0;
      PrototypeConfig_num_prototypes_out <= 64'd0;
      PrototypeConfig_projection_dim_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          Prototype_id_out <= Prototype_id_in;
          Prototype_representation_out <= Prototype_representation_in;
          Prototype_class_label_out <= Prototype_class_label_in;
          PrototypeNetwork_prototypes_out <= PrototypeNetwork_prototypes_in;
          PrototypeNetwork_encoder_out <= PrototypeNetwork_encoder_in;
          PrototypeExplanation_instance_out <= PrototypeExplanation_instance_in;
          PrototypeExplanation_nearest_prototypes_out <= PrototypeExplanation_nearest_prototypes_in;
          PrototypeExplanation_similarities_out <= PrototypeExplanation_similarities_in;
          PrototypeConfig_num_prototypes_out <= PrototypeConfig_num_prototypes_in;
          PrototypeConfig_projection_dim_out <= PrototypeConfig_projection_dim_in;
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
  // - learn_prototypes
  // - explain_with_prototypes
  // - visualize_prototypes

endmodule
