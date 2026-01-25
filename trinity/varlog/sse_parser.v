// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - sse_parser v1.7.5
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module sse_parser (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [31:0] SSEEvent_event_type_in,
  output reg  [31:0] SSEEvent_event_type_out,
  input  wire [255:0] SSEEvent_data_in,
  output reg  [255:0] SSEEvent_data_out,
  input  wire [31:0] SSEEvent_id_in,
  output reg  [31:0] SSEEvent_id_out,
  input  wire [31:0] SSEEvent_retry_in,
  output reg  [31:0] SSEEvent_retry_out,
  input  wire  ParseResult_success_in,
  output reg   ParseResult_success_out,
  input  wire [31:0] ParseResult_event_in,
  output reg  [31:0] ParseResult_event_out,
  input  wire [31:0] ParseResult_error_in,
  output reg  [31:0] ParseResult_error_out,
  input  wire [63:0] ParseResult_bytes_consumed_in,
  output reg  [63:0] ParseResult_bytes_consumed_out,
  input  wire [63:0] StreamStats_events_parsed_in,
  output reg  [63:0] StreamStats_events_parsed_out,
  input  wire [63:0] StreamStats_bytes_processed_in,
  output reg  [63:0] StreamStats_bytes_processed_out,
  input  wire [63:0] StreamStats_errors_in,
  output reg  [63:0] StreamStats_errors_out,
  input  wire [31:0] StreamStats_start_time_in,
  output reg  [31:0] StreamStats_start_time_out,
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
      SSEEvent_event_type_out <= 32'd0;
      SSEEvent_data_out <= 256'd0;
      SSEEvent_id_out <= 32'd0;
      SSEEvent_retry_out <= 32'd0;
      ParseResult_success_out <= 1'b0;
      ParseResult_event_out <= 32'd0;
      ParseResult_error_out <= 32'd0;
      ParseResult_bytes_consumed_out <= 64'd0;
      StreamStats_events_parsed_out <= 64'd0;
      StreamStats_bytes_processed_out <= 64'd0;
      StreamStats_errors_out <= 64'd0;
      StreamStats_start_time_out <= 32'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SSEEvent_event_type_out <= SSEEvent_event_type_in;
          SSEEvent_data_out <= SSEEvent_data_in;
          SSEEvent_id_out <= SSEEvent_id_in;
          SSEEvent_retry_out <= SSEEvent_retry_in;
          ParseResult_success_out <= ParseResult_success_in;
          ParseResult_event_out <= ParseResult_event_in;
          ParseResult_error_out <= ParseResult_error_in;
          ParseResult_bytes_consumed_out <= ParseResult_bytes_consumed_in;
          StreamStats_events_parsed_out <= StreamStats_events_parsed_in;
          StreamStats_bytes_processed_out <= StreamStats_bytes_processed_in;
          StreamStats_errors_out <= StreamStats_errors_in;
          StreamStats_start_time_out <= StreamStats_start_time_in;
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
  // - parse_line
  // - test_data_line
  // - test_event_line
  // - test_id_line
  // - test_comment
  // - parse_json_delta
  // - test_openai_format
  // - test_anthropic_format
  // - test_done_signal
  // - detect_provider
  // - test_openai
  // - test_anthropic
  // - test_deepseek
  // - handle_multiline_data
  // - test_multiline
  // - validate_event
  // - test_valid
  // - test_invalid
  // - reset_parser
  // - test_reset

endmodule
