// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - docs_examples_v19930 v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module docs_examples_v19930 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] Example_name_in,
  output reg  [255:0] Example_name_out,
  input  wire [255:0] Example_description_in,
  output reg  [255:0] Example_description_out,
  input  wire [255:0] Example_code_in,
  output reg  [255:0] Example_code_out,
  input  wire [255:0] Example_output_in,
  output reg  [255:0] Example_output_out,
  input  wire [511:0] Example_tags_in,
  output reg  [511:0] Example_tags_out,
  input  wire [511:0] ExampleCollection_examples_in,
  output reg  [511:0] ExampleCollection_examples_out,
  input  wire [511:0] ExampleCollection_categories_in,
  output reg  [511:0] ExampleCollection_categories_out,
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
      Example_name_out <= 256'd0;
      Example_description_out <= 256'd0;
      Example_code_out <= 256'd0;
      Example_output_out <= 256'd0;
      Example_tags_out <= 512'd0;
      ExampleCollection_examples_out <= 512'd0;
      ExampleCollection_categories_out <= 512'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          Example_name_out <= Example_name_in;
          Example_description_out <= Example_description_in;
          Example_code_out <= Example_code_in;
          Example_output_out <= Example_output_in;
          Example_tags_out <= Example_tags_in;
          ExampleCollection_examples_out <= ExampleCollection_examples_in;
          ExampleCollection_categories_out <= ExampleCollection_categories_in;
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
  // - example_extract
  // - example_test
  // - example_render

endmodule
