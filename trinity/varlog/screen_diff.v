// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - screen_diff v13347.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module screen_diff (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] DiffConfig_threshold_in,
  output reg  [63:0] DiffConfig_threshold_out,
  input  wire [255:0] DiffConfig_ignore_regions_in,
  output reg  [255:0] DiffConfig_ignore_regions_out,
  input  wire [255:0] DiffConfig_highlight_color_in,
  output reg  [255:0] DiffConfig_highlight_color_out,
  input  wire [63:0] DiffRegion_x_in,
  output reg  [63:0] DiffRegion_x_out,
  input  wire [63:0] DiffRegion_y_in,
  output reg  [63:0] DiffRegion_y_out,
  input  wire [63:0] DiffRegion_width_in,
  output reg  [63:0] DiffRegion_width_out,
  input  wire [63:0] DiffRegion_height_in,
  output reg  [63:0] DiffRegion_height_out,
  input  wire [63:0] DiffRegion_diff_percent_in,
  output reg  [63:0] DiffRegion_diff_percent_out,
  input  wire  DiffResult_identical_in,
  output reg   DiffResult_identical_out,
  input  wire [63:0] DiffResult_diff_percent_in,
  output reg  [63:0] DiffResult_diff_percent_out,
  input  wire [255:0] DiffResult_regions_in,
  output reg  [255:0] DiffResult_regions_out,
  input  wire [255:0] DiffResult_diff_image_in,
  output reg  [255:0] DiffResult_diff_image_out,
  input  wire [63:0] DiffMetrics_comparison_time_ns_in,
  output reg  [63:0] DiffMetrics_comparison_time_ns_out,
  input  wire [63:0] DiffMetrics_pixels_compared_in,
  output reg  [63:0] DiffMetrics_pixels_compared_out,
  input  wire [63:0] DiffMetrics_pixels_different_in,
  output reg  [63:0] DiffMetrics_pixels_different_out,
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
      DiffConfig_threshold_out <= 64'd0;
      DiffConfig_ignore_regions_out <= 256'd0;
      DiffConfig_highlight_color_out <= 256'd0;
      DiffRegion_x_out <= 64'd0;
      DiffRegion_y_out <= 64'd0;
      DiffRegion_width_out <= 64'd0;
      DiffRegion_height_out <= 64'd0;
      DiffRegion_diff_percent_out <= 64'd0;
      DiffResult_identical_out <= 1'b0;
      DiffResult_diff_percent_out <= 64'd0;
      DiffResult_regions_out <= 256'd0;
      DiffResult_diff_image_out <= 256'd0;
      DiffMetrics_comparison_time_ns_out <= 64'd0;
      DiffMetrics_pixels_compared_out <= 64'd0;
      DiffMetrics_pixels_different_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          DiffConfig_threshold_out <= DiffConfig_threshold_in;
          DiffConfig_ignore_regions_out <= DiffConfig_ignore_regions_in;
          DiffConfig_highlight_color_out <= DiffConfig_highlight_color_in;
          DiffRegion_x_out <= DiffRegion_x_in;
          DiffRegion_y_out <= DiffRegion_y_in;
          DiffRegion_width_out <= DiffRegion_width_in;
          DiffRegion_height_out <= DiffRegion_height_in;
          DiffRegion_diff_percent_out <= DiffRegion_diff_percent_in;
          DiffResult_identical_out <= DiffResult_identical_in;
          DiffResult_diff_percent_out <= DiffResult_diff_percent_in;
          DiffResult_regions_out <= DiffResult_regions_in;
          DiffResult_diff_image_out <= DiffResult_diff_image_in;
          DiffMetrics_comparison_time_ns_out <= DiffMetrics_comparison_time_ns_in;
          DiffMetrics_pixels_compared_out <= DiffMetrics_pixels_compared_in;
          DiffMetrics_pixels_different_out <= DiffMetrics_pixels_different_in;
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
  // - compare_screenshots
  // - find_diff_regions
  // - generate_diff_image
  // - set_baseline
  // - compare_to_baseline
  // - get_diff_metrics

endmodule
