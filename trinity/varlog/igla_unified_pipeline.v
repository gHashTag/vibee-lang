// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - igla_unified_pipeline v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module igla_unified_pipeline (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [255:0] PipelineConfig_search_mode_in,
  output reg  [255:0] PipelineConfig_search_mode_out,
  input  wire  PipelineConfig_use_reranking_in,
  output reg   PipelineConfig_use_reranking_out,
  input  wire  PipelineConfig_use_cache_in,
  output reg   PipelineConfig_use_cache_out,
  input  wire [63:0] PipelineConfig_chunk_size_in,
  output reg  [63:0] PipelineConfig_chunk_size_out,
  input  wire [63:0] PipelineConfig_top_k_in,
  output reg  [63:0] PipelineConfig_top_k_out,
  input  wire [255:0] SearchMode_name_in,
  output reg  [255:0] SearchMode_name_out,
  input  wire [255:0] SearchMode_description_in,
  output reg  [255:0] SearchMode_description_out,
  input  wire [255:0] PipelineStage_name_in,
  output reg  [255:0] PipelineStage_name_out,
  input  wire  PipelineStage_enabled_in,
  output reg   PipelineStage_enabled_out,
  input  wire [63:0] PipelineStage_latency_ms_in,
  output reg  [63:0] PipelineStage_latency_ms_out,
  input  wire [255:0] PipelineResult_answer_in,
  output reg  [255:0] PipelineResult_answer_out,
  input  wire [255:0] PipelineResult_sources_in,
  output reg  [255:0] PipelineResult_sources_out,
  input  wire [63:0] PipelineResult_latency_ms_in,
  output reg  [63:0] PipelineResult_latency_ms_out,
  input  wire [255:0] PipelineResult_stages_used_in,
  output reg  [255:0] PipelineResult_stages_used_out,
  input  wire [255:0] IndexConfig_index_type_in,
  output reg  [255:0] IndexConfig_index_type_out,
  input  wire  IndexConfig_use_quantization_in,
  output reg   IndexConfig_use_quantization_out,
  input  wire [255:0] IndexConfig_persist_path_in,
  output reg  [255:0] IndexConfig_persist_path_out,
  input  wire [255:0] QueryConfig_search_mode_in,
  output reg  [255:0] QueryConfig_search_mode_out,
  input  wire  QueryConfig_rerank_in,
  output reg   QueryConfig_rerank_out,
  input  wire [63:0] QueryConfig_top_k_in,
  output reg  [63:0] QueryConfig_top_k_out,
  input  wire  QueryConfig_stream_in,
  output reg   QueryConfig_stream_out,
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
      PipelineConfig_search_mode_out <= 256'd0;
      PipelineConfig_use_reranking_out <= 1'b0;
      PipelineConfig_use_cache_out <= 1'b0;
      PipelineConfig_chunk_size_out <= 64'd0;
      PipelineConfig_top_k_out <= 64'd0;
      SearchMode_name_out <= 256'd0;
      SearchMode_description_out <= 256'd0;
      PipelineStage_name_out <= 256'd0;
      PipelineStage_enabled_out <= 1'b0;
      PipelineStage_latency_ms_out <= 64'd0;
      PipelineResult_answer_out <= 256'd0;
      PipelineResult_sources_out <= 256'd0;
      PipelineResult_latency_ms_out <= 64'd0;
      PipelineResult_stages_used_out <= 256'd0;
      IndexConfig_index_type_out <= 256'd0;
      IndexConfig_use_quantization_out <= 1'b0;
      IndexConfig_persist_path_out <= 256'd0;
      QueryConfig_search_mode_out <= 256'd0;
      QueryConfig_rerank_out <= 1'b0;
      QueryConfig_top_k_out <= 64'd0;
      QueryConfig_stream_out <= 1'b0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          PipelineConfig_search_mode_out <= PipelineConfig_search_mode_in;
          PipelineConfig_use_reranking_out <= PipelineConfig_use_reranking_in;
          PipelineConfig_use_cache_out <= PipelineConfig_use_cache_in;
          PipelineConfig_chunk_size_out <= PipelineConfig_chunk_size_in;
          PipelineConfig_top_k_out <= PipelineConfig_top_k_in;
          SearchMode_name_out <= SearchMode_name_in;
          SearchMode_description_out <= SearchMode_description_in;
          PipelineStage_name_out <= PipelineStage_name_in;
          PipelineStage_enabled_out <= PipelineStage_enabled_in;
          PipelineStage_latency_ms_out <= PipelineStage_latency_ms_in;
          PipelineResult_answer_out <= PipelineResult_answer_in;
          PipelineResult_sources_out <= PipelineResult_sources_in;
          PipelineResult_latency_ms_out <= PipelineResult_latency_ms_in;
          PipelineResult_stages_used_out <= PipelineResult_stages_used_in;
          IndexConfig_index_type_out <= IndexConfig_index_type_in;
          IndexConfig_use_quantization_out <= IndexConfig_use_quantization_in;
          IndexConfig_persist_path_out <= IndexConfig_persist_path_in;
          QueryConfig_search_mode_out <= QueryConfig_search_mode_in;
          QueryConfig_rerank_out <= QueryConfig_rerank_in;
          QueryConfig_top_k_out <= QueryConfig_top_k_in;
          QueryConfig_stream_out <= QueryConfig_stream_in;
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
  // - create_pipeline
  // - index_documents
  // - query_bm25
  // - query_dense
  // - query_hybrid
  // - query_colbert
  // - rerank_results
  // - generate_answer
  // - phi_pipeline_optimization

endmodule
