// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - segmentation v3.2.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module segmentation (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] SegmentationMask_width_in,
  output reg  [63:0] SegmentationMask_width_out,
  input  wire [63:0] SegmentationMask_height_in,
  output reg  [63:0] SegmentationMask_height_out,
  input  wire [511:0] SegmentationMask_mask_in,
  output reg  [511:0] SegmentationMask_mask_out,
  input  wire [63:0] SegmentationMask_num_classes_in,
  output reg  [63:0] SegmentationMask_num_classes_out,
  input  wire [63:0] InstanceMask_instance_id_in,
  output reg  [63:0] InstanceMask_instance_id_out,
  input  wire [63:0] InstanceMask_class_id_in,
  output reg  [63:0] InstanceMask_class_id_out,
  input  wire [511:0] InstanceMask_mask_in,
  output reg  [511:0] InstanceMask_mask_out,
  input  wire [63:0] InstanceMask_score_in,
  output reg  [63:0] InstanceMask_score_out,
  input  wire [31:0] SegmentationConfig_seg_type_in,
  output reg  [31:0] SegmentationConfig_seg_type_out,
  input  wire [63:0] SegmentationConfig_num_classes_in,
  output reg  [63:0] SegmentationConfig_num_classes_out,
  input  wire [63:0] SegmentationConfig_threshold_in,
  output reg  [63:0] SegmentationConfig_threshold_out,
  input  wire [31:0] SAMPrompt_prompt_type_in,
  output reg  [31:0] SAMPrompt_prompt_type_out,
  input  wire [511:0] SAMPrompt_coordinates_in,
  output reg  [511:0] SAMPrompt_coordinates_out,
  input  wire [511:0] SAMPrompt_labels_in,
  output reg  [511:0] SAMPrompt_labels_out,
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
      SegmentationMask_width_out <= 64'd0;
      SegmentationMask_height_out <= 64'd0;
      SegmentationMask_mask_out <= 512'd0;
      SegmentationMask_num_classes_out <= 64'd0;
      InstanceMask_instance_id_out <= 64'd0;
      InstanceMask_class_id_out <= 64'd0;
      InstanceMask_mask_out <= 512'd0;
      InstanceMask_score_out <= 64'd0;
      SegmentationConfig_seg_type_out <= 32'd0;
      SegmentationConfig_num_classes_out <= 64'd0;
      SegmentationConfig_threshold_out <= 64'd0;
      SAMPrompt_prompt_type_out <= 32'd0;
      SAMPrompt_coordinates_out <= 512'd0;
      SAMPrompt_labels_out <= 512'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SegmentationMask_width_out <= SegmentationMask_width_in;
          SegmentationMask_height_out <= SegmentationMask_height_in;
          SegmentationMask_mask_out <= SegmentationMask_mask_in;
          SegmentationMask_num_classes_out <= SegmentationMask_num_classes_in;
          InstanceMask_instance_id_out <= InstanceMask_instance_id_in;
          InstanceMask_class_id_out <= InstanceMask_class_id_in;
          InstanceMask_mask_out <= InstanceMask_mask_in;
          InstanceMask_score_out <= InstanceMask_score_in;
          SegmentationConfig_seg_type_out <= SegmentationConfig_seg_type_in;
          SegmentationConfig_num_classes_out <= SegmentationConfig_num_classes_in;
          SegmentationConfig_threshold_out <= SegmentationConfig_threshold_in;
          SAMPrompt_prompt_type_out <= SAMPrompt_prompt_type_in;
          SAMPrompt_coordinates_out <= SAMPrompt_coordinates_in;
          SAMPrompt_labels_out <= SAMPrompt_labels_in;
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
  // - segment
  // - test_segment
  // - segment_with_prompt
  // - test_prompt
  // - instance_segment
  // - test_instance
  // - panoptic_segment
  // - test_panoptic
  // - refine_mask
  // - test_refine
  // - merge_masks
  // - test_merge

endmodule
