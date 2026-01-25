// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - igla_hnsw_search v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module igla_hnsw_search (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] SearchConfig_ef_in,
  output reg  [63:0] SearchConfig_ef_out,
  input  wire [63:0] SearchConfig_k_in,
  output reg  [63:0] SearchConfig_k_out,
  input  wire [255:0] SearchConfig_filter_in,
  output reg  [255:0] SearchConfig_filter_out,
  input  wire [63:0] SearchResult_id_in,
  output reg  [63:0] SearchResult_id_out,
  input  wire [63:0] SearchResult_distance_in,
  output reg  [63:0] SearchResult_distance_out,
  input  wire [255:0] SearchResult_vector_in,
  output reg  [255:0] SearchResult_vector_out,
  input  wire [255:0] SearchBatch_queries_in,
  output reg  [255:0] SearchBatch_queries_out,
  input  wire [63:0] SearchBatch_k_in,
  output reg  [63:0] SearchBatch_k_out,
  input  wire [255:0] SearchBatch_results_in,
  output reg  [255:0] SearchBatch_results_out,
  input  wire [255:0] VisitedSet_bits_in,
  output reg  [255:0] VisitedSet_bits_out,
  input  wire [63:0] VisitedSet_size_in,
  output reg  [63:0] VisitedSet_size_out,
  input  wire [255:0] CandidateQueue_candidates_in,
  output reg  [255:0] CandidateQueue_candidates_out,
  input  wire [63:0] CandidateQueue_max_size_in,
  output reg  [63:0] CandidateQueue_max_size_out,
  input  wire [63:0] SearchStats_distance_computations_in,
  output reg  [63:0] SearchStats_distance_computations_out,
  input  wire [63:0] SearchStats_nodes_visited_in,
  output reg  [63:0] SearchStats_nodes_visited_out,
  input  wire [63:0] SearchStats_latency_us_in,
  output reg  [63:0] SearchStats_latency_us_out,
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
      SearchConfig_ef_out <= 64'd0;
      SearchConfig_k_out <= 64'd0;
      SearchConfig_filter_out <= 256'd0;
      SearchResult_id_out <= 64'd0;
      SearchResult_distance_out <= 64'd0;
      SearchResult_vector_out <= 256'd0;
      SearchBatch_queries_out <= 256'd0;
      SearchBatch_k_out <= 64'd0;
      SearchBatch_results_out <= 256'd0;
      VisitedSet_bits_out <= 256'd0;
      VisitedSet_size_out <= 64'd0;
      CandidateQueue_candidates_out <= 256'd0;
      CandidateQueue_max_size_out <= 64'd0;
      SearchStats_distance_computations_out <= 64'd0;
      SearchStats_nodes_visited_out <= 64'd0;
      SearchStats_latency_us_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SearchConfig_ef_out <= SearchConfig_ef_in;
          SearchConfig_k_out <= SearchConfig_k_in;
          SearchConfig_filter_out <= SearchConfig_filter_in;
          SearchResult_id_out <= SearchResult_id_in;
          SearchResult_distance_out <= SearchResult_distance_in;
          SearchResult_vector_out <= SearchResult_vector_in;
          SearchBatch_queries_out <= SearchBatch_queries_in;
          SearchBatch_k_out <= SearchBatch_k_in;
          SearchBatch_results_out <= SearchBatch_results_in;
          VisitedSet_bits_out <= VisitedSet_bits_in;
          VisitedSet_size_out <= VisitedSet_size_in;
          CandidateQueue_candidates_out <= CandidateQueue_candidates_in;
          CandidateQueue_max_size_out <= CandidateQueue_max_size_in;
          SearchStats_distance_computations_out <= SearchStats_distance_computations_in;
          SearchStats_nodes_visited_out <= SearchStats_nodes_visited_in;
          SearchStats_latency_us_out <= SearchStats_latency_us_in;
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
  // - search_knn
  // - search_layer
  // - greedy_search
  // - search_batch
  // - search_with_filter
  // - range_search
  // - update_visited
  // - phi_ef_tuning

endmodule
