// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - igla_diskann_search v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module igla_diskann_search (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] SearchConfig_L_in,
  output reg  [63:0] SearchConfig_L_out,
  input  wire [63:0] SearchConfig_beam_width_in,
  output reg  [63:0] SearchConfig_beam_width_out,
  input  wire  SearchConfig_use_pq_rerank_in,
  output reg   SearchConfig_use_pq_rerank_out,
  input  wire [63:0] SearchConfig_num_threads_in,
  output reg  [63:0] SearchConfig_num_threads_out,
  input  wire [255:0] BeamState_candidates_in,
  output reg  [255:0] BeamState_candidates_out,
  input  wire [255:0] BeamState_visited_in,
  output reg  [255:0] BeamState_visited_out,
  input  wire [255:0] BeamState_best_so_far_in,
  output reg  [255:0] BeamState_best_so_far_out,
  input  wire [63:0] SectorRead_sector_id_in,
  output reg  [63:0] SectorRead_sector_id_out,
  input  wire [255:0] SectorRead_data_in,
  output reg  [255:0] SectorRead_data_out,
  input  wire [63:0] SectorRead_latency_us_in,
  output reg  [63:0] SectorRead_latency_us_out,
  input  wire [63:0] SearchResult_id_in,
  output reg  [63:0] SearchResult_id_out,
  input  wire [63:0] SearchResult_distance_in,
  output reg  [63:0] SearchResult_distance_out,
  input  wire  SearchResult_from_pq_in,
  output reg   SearchResult_from_pq_out,
  input  wire [63:0] IOStats_sectors_read_in,
  output reg  [63:0] IOStats_sectors_read_out,
  input  wire [63:0] IOStats_bytes_read_in,
  output reg  [63:0] IOStats_bytes_read_out,
  input  wire [63:0] IOStats_io_latency_ms_in,
  output reg  [63:0] IOStats_io_latency_ms_out,
  input  wire [63:0] CachedSector_sector_id_in,
  output reg  [63:0] CachedSector_sector_id_out,
  input  wire [255:0] CachedSector_data_in,
  output reg  [255:0] CachedSector_data_out,
  input  wire [63:0] CachedSector_last_access_in,
  output reg  [63:0] CachedSector_last_access_out,
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
      SearchConfig_L_out <= 64'd0;
      SearchConfig_beam_width_out <= 64'd0;
      SearchConfig_use_pq_rerank_out <= 1'b0;
      SearchConfig_num_threads_out <= 64'd0;
      BeamState_candidates_out <= 256'd0;
      BeamState_visited_out <= 256'd0;
      BeamState_best_so_far_out <= 256'd0;
      SectorRead_sector_id_out <= 64'd0;
      SectorRead_data_out <= 256'd0;
      SectorRead_latency_us_out <= 64'd0;
      SearchResult_id_out <= 64'd0;
      SearchResult_distance_out <= 64'd0;
      SearchResult_from_pq_out <= 1'b0;
      IOStats_sectors_read_out <= 64'd0;
      IOStats_bytes_read_out <= 64'd0;
      IOStats_io_latency_ms_out <= 64'd0;
      CachedSector_sector_id_out <= 64'd0;
      CachedSector_data_out <= 256'd0;
      CachedSector_last_access_out <= 64'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          SearchConfig_L_out <= SearchConfig_L_in;
          SearchConfig_beam_width_out <= SearchConfig_beam_width_in;
          SearchConfig_use_pq_rerank_out <= SearchConfig_use_pq_rerank_in;
          SearchConfig_num_threads_out <= SearchConfig_num_threads_in;
          BeamState_candidates_out <= BeamState_candidates_in;
          BeamState_visited_out <= BeamState_visited_in;
          BeamState_best_so_far_out <= BeamState_best_so_far_in;
          SectorRead_sector_id_out <= SectorRead_sector_id_in;
          SectorRead_data_out <= SectorRead_data_in;
          SectorRead_latency_us_out <= SectorRead_latency_us_in;
          SearchResult_id_out <= SearchResult_id_in;
          SearchResult_distance_out <= SearchResult_distance_in;
          SearchResult_from_pq_out <= SearchResult_from_pq_in;
          IOStats_sectors_read_out <= IOStats_sectors_read_in;
          IOStats_bytes_read_out <= IOStats_bytes_read_in;
          IOStats_io_latency_ms_out <= IOStats_io_latency_ms_in;
          CachedSector_sector_id_out <= CachedSector_sector_id_in;
          CachedSector_data_out <= CachedSector_data_in;
          CachedSector_last_access_out <= CachedSector_last_access_in;
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
  // - beam_search
  // - load_sector
  // - pq_distance
  // - rerank_with_full
  // - prefetch_sectors
  // - cache_sector
  // - batch_search
  // - phi_beam_width

endmodule
