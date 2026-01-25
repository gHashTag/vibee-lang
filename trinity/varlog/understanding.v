// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - understanding v3.2.9
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module understanding (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] Entity_text_in,
  output reg  [255:0] Entity_text_out,
  input  wire [255:0] Entity_label_in,
  output reg  [255:0] Entity_label_out,
  input  wire [63:0] Entity_start_in,
  output reg  [63:0] Entity_start_out,
  input  wire [63:0] Entity_end_in,
  output reg  [63:0] Entity_end_out,
  input  wire [63:0] Entity_confidence_in,
  output reg  [63:0] Entity_confidence_out,
  input  wire [255:0] ClassificationResult_label_in,
  output reg  [255:0] ClassificationResult_label_out,
  input  wire [63:0] ClassificationResult_score_in,
  output reg  [63:0] ClassificationResult_score_out,
  input  wire [511:0] ClassificationResult_all_scores_in,
  output reg  [511:0] ClassificationResult_all_scores_out,
  input  wire [255:0] QAResult_answer_in,
  output reg  [255:0] QAResult_answer_out,
  input  wire [63:0] QAResult_start_in,
  output reg  [63:0] QAResult_start_out,
  input  wire [63:0] QAResult_end_in,
  output reg  [63:0] QAResult_end_out,
  input  wire [63:0] QAResult_score_in,
  output reg  [63:0] QAResult_score_out,
  input  wire [255:0] SentimentResult_sentiment_in,
  output reg  [255:0] SentimentResult_sentiment_out,
  input  wire [63:0] SentimentResult_score_in,
  output reg  [63:0] SentimentResult_score_out,
  input  wire [511:0] SentimentResult_aspects_in,
  output reg  [511:0] SentimentResult_aspects_out,
  input  wire [255:0] EntailmentResult_label_in,
  output reg  [255:0] EntailmentResult_label_out,
  input  wire [63:0] EntailmentResult_score_in,
  output reg  [63:0] EntailmentResult_score_out,
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
      Entity_text_out <= 256'd0;
      Entity_label_out <= 256'd0;
      Entity_start_out <= 64'd0;
      Entity_end_out <= 64'd0;
      Entity_confidence_out <= 64'd0;
      ClassificationResult_label_out <= 256'd0;
      ClassificationResult_score_out <= 64'd0;
      ClassificationResult_all_scores_out <= 512'd0;
      QAResult_answer_out <= 256'd0;
      QAResult_start_out <= 64'd0;
      QAResult_end_out <= 64'd0;
      QAResult_score_out <= 64'd0;
      SentimentResult_sentiment_out <= 256'd0;
      SentimentResult_score_out <= 64'd0;
      SentimentResult_aspects_out <= 512'd0;
      EntailmentResult_label_out <= 256'd0;
      EntailmentResult_score_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          Entity_text_out <= Entity_text_in;
          Entity_label_out <= Entity_label_in;
          Entity_start_out <= Entity_start_in;
          Entity_end_out <= Entity_end_in;
          Entity_confidence_out <= Entity_confidence_in;
          ClassificationResult_label_out <= ClassificationResult_label_in;
          ClassificationResult_score_out <= ClassificationResult_score_in;
          ClassificationResult_all_scores_out <= ClassificationResult_all_scores_in;
          QAResult_answer_out <= QAResult_answer_in;
          QAResult_start_out <= QAResult_start_in;
          QAResult_end_out <= QAResult_end_in;
          QAResult_score_out <= QAResult_score_in;
          SentimentResult_sentiment_out <= SentimentResult_sentiment_in;
          SentimentResult_score_out <= SentimentResult_score_in;
          SentimentResult_aspects_out <= SentimentResult_aspects_in;
          EntailmentResult_label_out <= EntailmentResult_label_in;
          EntailmentResult_score_out <= EntailmentResult_score_in;
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
  // - classify
  // - test_classify
  // - extract_entities
  // - test_ner
  // - answer_question
  // - test_qa
  // - analyze_sentiment
  // - test_sentiment
  // - check_entailment
  // - test_entail
  // - summarize
  // - test_summarize

endmodule
