// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - zig_prompt_template v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module zig_prompt_template (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [31:0] PromptMessage_role_in,
  output reg  [31:0] PromptMessage_role_out,
  input  wire [255:0] PromptMessage_content_in,
  output reg  [255:0] PromptMessage_content_out,
  input  wire [255:0] PromptTemplate_name_in,
  output reg  [255:0] PromptTemplate_name_out,
  input  wire [255:0] PromptTemplate_system_prompt_in,
  output reg  [255:0] PromptTemplate_system_prompt_out,
  input  wire [511:0] PromptTemplate_few_shot_examples_in,
  output reg  [511:0] PromptTemplate_few_shot_examples_out,
  input  wire [255:0] PromptTemplate_output_format_in,
  output reg  [255:0] PromptTemplate_output_format_out,
  input  wire [255:0] PromptContext_task_intent_in,
  output reg  [255:0] PromptContext_task_intent_out,
  input  wire [255:0] PromptContext_current_url_in,
  output reg  [255:0] PromptContext_current_url_out,
  input  wire [255:0] PromptContext_observation_in,
  output reg  [255:0] PromptContext_observation_out,
  input  wire [511:0] PromptContext_history_in,
  output reg  [511:0] PromptContext_history_out,
  input  wire [511:0] PromptContext_available_actions_in,
  output reg  [511:0] PromptContext_available_actions_out,
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
      PromptMessage_role_out <= 32'd0;
      PromptMessage_content_out <= 256'd0;
      PromptTemplate_name_out <= 256'd0;
      PromptTemplate_system_prompt_out <= 256'd0;
      PromptTemplate_few_shot_examples_out <= 512'd0;
      PromptTemplate_output_format_out <= 256'd0;
      PromptContext_task_intent_out <= 256'd0;
      PromptContext_current_url_out <= 256'd0;
      PromptContext_observation_out <= 256'd0;
      PromptContext_history_out <= 512'd0;
      PromptContext_available_actions_out <= 512'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          PromptMessage_role_out <= PromptMessage_role_in;
          PromptMessage_content_out <= PromptMessage_content_in;
          PromptTemplate_name_out <= PromptTemplate_name_in;
          PromptTemplate_system_prompt_out <= PromptTemplate_system_prompt_in;
          PromptTemplate_few_shot_examples_out <= PromptTemplate_few_shot_examples_in;
          PromptTemplate_output_format_out <= PromptTemplate_output_format_in;
          PromptContext_task_intent_out <= PromptContext_task_intent_in;
          PromptContext_current_url_out <= PromptContext_current_url_in;
          PromptContext_observation_out <= PromptContext_observation_in;
          PromptContext_history_out <= PromptContext_history_in;
          PromptContext_available_actions_out <= PromptContext_available_actions_in;
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
  // - build_system_prompt
  // - build_user_prompt
  // - parse_response
  // - add_few_shot
  // - format_observation

endmodule
