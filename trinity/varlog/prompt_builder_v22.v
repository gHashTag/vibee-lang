// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - prompt_builder_v22 v22.1.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module prompt_builder_v22 (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] PromptConfig_system_prompt_in,
  output reg  [255:0] PromptConfig_system_prompt_out,
  input  wire [63:0] PromptConfig_max_tokens_in,
  output reg  [63:0] PromptConfig_max_tokens_out,
  input  wire [63:0] PromptConfig_temperature_in,
  output reg  [63:0] PromptConfig_temperature_out,
  input  wire  PromptConfig_include_history_in,
  output reg   PromptConfig_include_history_out,
  input  wire  PromptConfig_include_observation_in,
  output reg   PromptConfig_include_observation_out,
  input  wire  PromptConfig_include_goal_in,
  output reg   PromptConfig_include_goal_out,
  input  wire [255:0] PromptTemplate_name_in,
  output reg  [255:0] PromptTemplate_name_out,
  input  wire [255:0] PromptTemplate_template_in,
  output reg  [255:0] PromptTemplate_template_out,
  input  wire [511:0] PromptTemplate_variables_in,
  output reg  [511:0] PromptTemplate_variables_out,
  input  wire [255:0] PromptTemplate_version_in,
  output reg  [255:0] PromptTemplate_version_out,
  input  wire [255:0] ConversationMessage_role_in,
  output reg  [255:0] ConversationMessage_role_out,
  input  wire [255:0] ConversationMessage_content_in,
  output reg  [255:0] ConversationMessage_content_out,
  input  wire [31:0] ConversationMessage_timestamp_in,
  output reg  [31:0] ConversationMessage_timestamp_out,
  input  wire [255:0] PromptContext_goal_in,
  output reg  [255:0] PromptContext_goal_out,
  input  wire [255:0] PromptContext_observation_in,
  output reg  [255:0] PromptContext_observation_out,
  input  wire [511:0] PromptContext_history_in,
  output reg  [511:0] PromptContext_history_out,
  input  wire [511:0] PromptContext_available_actions_in,
  output reg  [511:0] PromptContext_available_actions_out,
  input  wire [511:0] PromptContext_constraints_in,
  output reg  [511:0] PromptContext_constraints_out,
  input  wire [255:0] BuiltPrompt_system_in,
  output reg  [255:0] BuiltPrompt_system_out,
  input  wire [255:0] BuiltPrompt_user_in,
  output reg  [255:0] BuiltPrompt_user_out,
  input  wire [63:0] BuiltPrompt_total_tokens_in,
  output reg  [63:0] BuiltPrompt_total_tokens_out,
  input  wire  BuiltPrompt_truncated_in,
  output reg   BuiltPrompt_truncated_out,
  input  wire [31:0] PromptBuilder_config_in,
  output reg  [31:0] PromptBuilder_config_out,
  input  wire [511:0] PromptBuilder_templates_in,
  output reg  [511:0] PromptBuilder_templates_out,
  input  wire [511:0] PromptBuilder_history_in,
  output reg  [511:0] PromptBuilder_history_out,
  input  wire [63:0] PromptBuilder_phi_ratio_in,
  output reg  [63:0] PromptBuilder_phi_ratio_out,
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
      PromptConfig_system_prompt_out <= 256'd0;
      PromptConfig_max_tokens_out <= 64'd0;
      PromptConfig_temperature_out <= 64'd0;
      PromptConfig_include_history_out <= 1'b0;
      PromptConfig_include_observation_out <= 1'b0;
      PromptConfig_include_goal_out <= 1'b0;
      PromptTemplate_name_out <= 256'd0;
      PromptTemplate_template_out <= 256'd0;
      PromptTemplate_variables_out <= 512'd0;
      PromptTemplate_version_out <= 256'd0;
      ConversationMessage_role_out <= 256'd0;
      ConversationMessage_content_out <= 256'd0;
      ConversationMessage_timestamp_out <= 32'd0;
      PromptContext_goal_out <= 256'd0;
      PromptContext_observation_out <= 256'd0;
      PromptContext_history_out <= 512'd0;
      PromptContext_available_actions_out <= 512'd0;
      PromptContext_constraints_out <= 512'd0;
      BuiltPrompt_system_out <= 256'd0;
      BuiltPrompt_user_out <= 256'd0;
      BuiltPrompt_total_tokens_out <= 64'd0;
      BuiltPrompt_truncated_out <= 1'b0;
      PromptBuilder_config_out <= 32'd0;
      PromptBuilder_templates_out <= 512'd0;
      PromptBuilder_history_out <= 512'd0;
      PromptBuilder_phi_ratio_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          PromptConfig_system_prompt_out <= PromptConfig_system_prompt_in;
          PromptConfig_max_tokens_out <= PromptConfig_max_tokens_in;
          PromptConfig_temperature_out <= PromptConfig_temperature_in;
          PromptConfig_include_history_out <= PromptConfig_include_history_in;
          PromptConfig_include_observation_out <= PromptConfig_include_observation_in;
          PromptConfig_include_goal_out <= PromptConfig_include_goal_in;
          PromptTemplate_name_out <= PromptTemplate_name_in;
          PromptTemplate_template_out <= PromptTemplate_template_in;
          PromptTemplate_variables_out <= PromptTemplate_variables_in;
          PromptTemplate_version_out <= PromptTemplate_version_in;
          ConversationMessage_role_out <= ConversationMessage_role_in;
          ConversationMessage_content_out <= ConversationMessage_content_in;
          ConversationMessage_timestamp_out <= ConversationMessage_timestamp_in;
          PromptContext_goal_out <= PromptContext_goal_in;
          PromptContext_observation_out <= PromptContext_observation_in;
          PromptContext_history_out <= PromptContext_history_in;
          PromptContext_available_actions_out <= PromptContext_available_actions_in;
          PromptContext_constraints_out <= PromptContext_constraints_in;
          BuiltPrompt_system_out <= BuiltPrompt_system_in;
          BuiltPrompt_user_out <= BuiltPrompt_user_in;
          BuiltPrompt_total_tokens_out <= BuiltPrompt_total_tokens_in;
          BuiltPrompt_truncated_out <= BuiltPrompt_truncated_in;
          PromptBuilder_config_out <= PromptBuilder_config_in;
          PromptBuilder_templates_out <= PromptBuilder_templates_in;
          PromptBuilder_history_out <= PromptBuilder_history_in;
          PromptBuilder_phi_ratio_out <= PromptBuilder_phi_ratio_in;
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
  // - create_builder
  // - build_system_prompt
  // - build_user_prompt
  // - add_template
  // - render_template
  // - add_history
  // - truncate_to_tokens
  // - build_full_prompt
  // - estimate_tokens
  // - format_actions
  // - phi_optimize

endmodule
