// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - igla_colbert_search v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module igla_colbert_search (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] SearchConfig_k_in,
  output reg  [63:0] SearchConfig_k_out,
  input  wire [63:0] SearchConfig_nprobe_in,
  output reg  [63:0] SearchConfig_nprobe_out,
  input  wire [63:0] SearchConfig_ncandidates_in,
  output reg  [63:0] SearchConfig_ncandidates_out,
  input  wire [63:0] MaxSimScore_doc_id_in,
  output reg  [63:0] MaxSimScore_doc_id_out,
  input  wire [63:0] MaxSimScore_score_in,
  output reg  [63:0] MaxSimScore_score_out,
  input  wire [255:0] MaxSimScore_token_scores_in,
  output reg  [255:0] MaxSimScore_token_scores_out,
  input  wire [63:0] CandidateDoc_doc_id_in,
  output reg  [63:0] CandidateDoc_doc_id_out,
  input  wire [63:0] CandidateDoc_candidate_score_in,
  output reg  [63:0] CandidateDoc_candidate_score_out,
  input  wire  CandidateDoc_needs_rerank_in,
  output reg   CandidateDoc_needs_rerank_out,
  input  wire [63:0] SearchResult_doc_id_in,
  output reg  [63:0] SearchResult_doc_id_out,
  input  wire [63:0] SearchResult_maxsim_score_in,
  output reg  [63:0] SearchResult_maxsim_score_out,
  input  wire [63:0] SearchResult_rank_in,
  output reg  [63:0] SearchResult_rank_out,
  input  wire [63:0] TokenMatch_query_token_in,
  output reg  [63:0] TokenMatch_query_token_out,
  input  wire [63:0] TokenMatch_doc_token_in,
  output reg  [63:0] TokenMatch_doc_token_out,
  input  wire [63:0] TokenMatch_similarity_in,
  output reg  [63:0] TokenMatch_similarity_out,
  input  wire [63:0] SearchStats_candidates_scored_in,
  output reg  [63:0] SearchStats_candidates_scored_out,
  input  wire [63:0] SearchStats_full_maxsim_computed_in,
  output reg  [63:0] SearchStats_full_maxsim_computed_out,
  input  wire [63:0] SearchStats_latency_ms_in,
  output reg  [63:0] SearchStats_latency_ms_out,
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
      SearchConfig_k_out <= 64'd0;
      SearchConfig_nprobe_out <= 64'd0;
      SearchConfig_ncandidates_out <= 64'd0;
      MaxSimScore_doc_id_out <= 64'd0;
      MaxSimScore_score_out <= 64'd0;
      MaxSimScore_token_scores_out <= 256'd0;
      CandidateDoc_doc_id_out <= 64'd0;
      CandidateDoc_candidate_score_out <= 64'd0;
      CandidateDoc_needs_rerank_out <= 1'b0;
      SearchResult_doc_id_out <= 64'd0;
      SearchResult_maxsim_score_out <= 64'd0;
      SearchResult_rank_out <= 64'd0;
      TokenMatch_query_token_out <= 64'd0;
      TokenMatch_doc_token_out <= 64'd0;
      TokenMatch_similarity_out <= 64'd0;
      SearchStats_candidates_scored_out <= 64'd0;
      SearchStats_full_maxsim_computed_out <= 64'd0;
      SearchStats_latency_ms_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SearchConfig_k_out <= SearchConfig_k_in;
          SearchConfig_nprobe_out <= SearchConfig_nprobe_in;
          SearchConfig_ncandidates_out <= SearchConfig_ncandidates_in;
          MaxSimScore_doc_id_out <= MaxSimScore_doc_id_in;
          MaxSimScore_score_out <= MaxSimScore_score_in;
          MaxSimScore_token_scores_out <= MaxSimScore_token_scores_in;
          CandidateDoc_doc_id_out <= CandidateDoc_doc_id_in;
          CandidateDoc_candidate_score_out <= CandidateDoc_candidate_score_in;
          CandidateDoc_needs_rerank_out <= CandidateDoc_needs_rerank_in;
          SearchResult_doc_id_out <= SearchResult_doc_id_in;
          SearchResult_maxsim_score_out <= SearchResult_maxsim_score_in;
          SearchResult_rank_out <= SearchResult_rank_in;
          TokenMatch_query_token_out <= TokenMatch_query_token_in;
          TokenMatch_doc_token_out <= TokenMatch_doc_token_in;
          TokenMatch_similarity_out <= TokenMatch_similarity_in;
          SearchStats_candidates_scored_out <= SearchStats_candidates_scored_in;
          SearchStats_full_maxsim_computed_out <= SearchStats_full_maxsim_computed_in;
          SearchStats_latency_ms_out <= SearchStats_latency_ms_in;
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
  // - compute_maxsim
  // - search_exhaustive
  // - search_approximate
  // - candidate_generation
  // - rerank_candidates
  // - batch_search
  // - explain_score
  // - phi_candidate_threshold

endmodule
