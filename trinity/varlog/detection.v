// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - detection v3.1.9
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module detection (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] BoundingBox_x_in,
  output reg  [63:0] BoundingBox_x_out,
  input  wire [63:0] BoundingBox_y_in,
  output reg  [63:0] BoundingBox_y_out,
  input  wire [63:0] BoundingBox_width_in,
  output reg  [63:0] BoundingBox_width_out,
  input  wire [63:0] BoundingBox_height_in,
  output reg  [63:0] BoundingBox_height_out,
  input  wire [63:0] Detection_class_id_in,
  output reg  [63:0] Detection_class_id_out,
  input  wire [255:0] Detection_class_name_in,
  output reg  [255:0] Detection_class_name_out,
  input  wire [63:0] Detection_confidence_in,
  output reg  [63:0] Detection_confidence_out,
  input  wire [31:0] Detection_bbox_in,
  output reg  [31:0] Detection_bbox_out,
  input  wire [31:0] DetectionConfig_detector_in,
  output reg  [31:0] DetectionConfig_detector_out,
  input  wire [63:0] DetectionConfig_confidence_threshold_in,
  output reg  [63:0] DetectionConfig_confidence_threshold_out,
  input  wire [63:0] DetectionConfig_nms_threshold_in,
  output reg  [63:0] DetectionConfig_nms_threshold_out,
  input  wire [63:0] DetectionConfig_max_detections_in,
  output reg  [63:0] DetectionConfig_max_detections_out,
  input  wire [63:0] Anchor_width_in,
  output reg  [63:0] Anchor_width_out,
  input  wire [63:0] Anchor_height_in,
  output reg  [63:0] Anchor_height_out,
  input  wire [63:0] Anchor_aspect_ratio_in,
  output reg  [63:0] Anchor_aspect_ratio_out,
  input  wire [63:0] FeatureMap_width_in,
  output reg  [63:0] FeatureMap_width_out,
  input  wire [63:0] FeatureMap_height_in,
  output reg  [63:0] FeatureMap_height_out,
  input  wire [63:0] FeatureMap_channels_in,
  output reg  [63:0] FeatureMap_channels_out,
  input  wire [511:0] FeatureMap_data_in,
  output reg  [511:0] FeatureMap_data_out,
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
      BoundingBox_x_out <= 64'd0;
      BoundingBox_y_out <= 64'd0;
      BoundingBox_width_out <= 64'd0;
      BoundingBox_height_out <= 64'd0;
      Detection_class_id_out <= 64'd0;
      Detection_class_name_out <= 256'd0;
      Detection_confidence_out <= 64'd0;
      Detection_bbox_out <= 32'd0;
      DetectionConfig_detector_out <= 32'd0;
      DetectionConfig_confidence_threshold_out <= 64'd0;
      DetectionConfig_nms_threshold_out <= 64'd0;
      DetectionConfig_max_detections_out <= 64'd0;
      Anchor_width_out <= 64'd0;
      Anchor_height_out <= 64'd0;
      Anchor_aspect_ratio_out <= 64'd0;
      FeatureMap_width_out <= 64'd0;
      FeatureMap_height_out <= 64'd0;
      FeatureMap_channels_out <= 64'd0;
      FeatureMap_data_out <= 512'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          BoundingBox_x_out <= BoundingBox_x_in;
          BoundingBox_y_out <= BoundingBox_y_in;
          BoundingBox_width_out <= BoundingBox_width_in;
          BoundingBox_height_out <= BoundingBox_height_in;
          Detection_class_id_out <= Detection_class_id_in;
          Detection_class_name_out <= Detection_class_name_in;
          Detection_confidence_out <= Detection_confidence_in;
          Detection_bbox_out <= Detection_bbox_in;
          DetectionConfig_detector_out <= DetectionConfig_detector_in;
          DetectionConfig_confidence_threshold_out <= DetectionConfig_confidence_threshold_in;
          DetectionConfig_nms_threshold_out <= DetectionConfig_nms_threshold_in;
          DetectionConfig_max_detections_out <= DetectionConfig_max_detections_in;
          Anchor_width_out <= Anchor_width_in;
          Anchor_height_out <= Anchor_height_in;
          Anchor_aspect_ratio_out <= Anchor_aspect_ratio_in;
          FeatureMap_width_out <= FeatureMap_width_in;
          FeatureMap_height_out <= FeatureMap_height_in;
          FeatureMap_channels_out <= FeatureMap_channels_in;
          FeatureMap_data_out <= FeatureMap_data_in;
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
  // - detect
  // - test_detect
  // - nms
  // - test_nms
  // - extract_features
  // - test_features
  // - decode_predictions
  // - test_decode
  // - batch_detect
  // - test_batch
  // - visualize
  // - test_viz

endmodule
