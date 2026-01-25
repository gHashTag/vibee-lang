// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - training_data_generator v11.5.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module training_data_generator (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] TrainingExample_instruction_in,
  output reg  [255:0] TrainingExample_instruction_out,
  input  wire [255:0] TrainingExample_input_spec_in,
  output reg  [255:0] TrainingExample_input_spec_out,
  input  wire [255:0] TrainingExample_output_code_in,
  output reg  [255:0] TrainingExample_output_code_out,
  input  wire [255:0] TrainingExample_target_lang_in,
  output reg  [255:0] TrainingExample_target_lang_out,
  input  wire [63:0] TrainingExample_quality_score_in,
  output reg  [63:0] TrainingExample_quality_score_out,
  input  wire [63:0] DatasetConfig_max_examples_in,
  output reg  [63:0] DatasetConfig_max_examples_out,
  input  wire [511:0] DatasetConfig_languages_in,
  output reg  [511:0] DatasetConfig_languages_out,
  input  wire [63:0] DatasetConfig_augmentation_factor_in,
  output reg  [63:0] DatasetConfig_augmentation_factor_out,
  input  wire [63:0] DatasetConfig_sacred_weight_in,
  output reg  [63:0] DatasetConfig_sacred_weight_out,
  input  wire [511:0] GeneratedDataset_examples_in,
  output reg  [511:0] GeneratedDataset_examples_out,
  input  wire [63:0] GeneratedDataset_total_tokens_in,
  output reg  [63:0] GeneratedDataset_total_tokens_out,
  input  wire [1023:0] GeneratedDataset_language_distribution_in,
  output reg  [1023:0] GeneratedDataset_language_distribution_out,
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
      TrainingExample_instruction_out <= 256'd0;
      TrainingExample_input_spec_out <= 256'd0;
      TrainingExample_output_code_out <= 256'd0;
      TrainingExample_target_lang_out <= 256'd0;
      TrainingExample_quality_score_out <= 64'd0;
      DatasetConfig_max_examples_out <= 64'd0;
      DatasetConfig_languages_out <= 512'd0;
      DatasetConfig_augmentation_factor_out <= 64'd0;
      DatasetConfig_sacred_weight_out <= 64'd0;
      GeneratedDataset_examples_out <= 512'd0;
      GeneratedDataset_total_tokens_out <= 64'd0;
      GeneratedDataset_language_distribution_out <= 1024'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          TrainingExample_instruction_out <= TrainingExample_instruction_in;
          TrainingExample_input_spec_out <= TrainingExample_input_spec_in;
          TrainingExample_output_code_out <= TrainingExample_output_code_in;
          TrainingExample_target_lang_out <= TrainingExample_target_lang_in;
          TrainingExample_quality_score_out <= TrainingExample_quality_score_in;
          DatasetConfig_max_examples_out <= DatasetConfig_max_examples_in;
          DatasetConfig_languages_out <= DatasetConfig_languages_in;
          DatasetConfig_augmentation_factor_out <= DatasetConfig_augmentation_factor_in;
          DatasetConfig_sacred_weight_out <= DatasetConfig_sacred_weight_in;
          GeneratedDataset_examples_out <= GeneratedDataset_examples_in;
          GeneratedDataset_total_tokens_out <= GeneratedDataset_total_tokens_in;
          GeneratedDataset_language_distribution_out <= GeneratedDataset_language_distribution_in;
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
  // - generate_instruction_pairs
  // - test_pairs
  // - apply_sacred_weighting
  // - test_weight
  // - balance_languages
  // - test_balance
  // - export_jsonl
  // - test_export

endmodule
