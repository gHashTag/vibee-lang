// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - data_loader v6.0.12
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module data_loader (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [31:0] DataLoader_data_in,
  output reg  [31:0] DataLoader_data_out,
  input  wire [63:0] DataLoader_batch_size_in,
  output reg  [63:0] DataLoader_batch_size_out,
  input  wire  DataLoader_shuffle_in,
  output reg   DataLoader_shuffle_out,
  input  wire [63:0] DataLoader_current_idx_in,
  output reg  [63:0] DataLoader_current_idx_out,
  input  wire [31:0] Batch_inputs_in,
  output reg  [31:0] Batch_inputs_out,
  input  wire [31:0] Batch_targets_in,
  output reg  [31:0] Batch_targets_out,
  input  wire [31:0] Batch_mask_in,
  output reg  [31:0] Batch_mask_out,
  input  wire [255:0] DataConfig_path_in,
  output reg  [255:0] DataConfig_path_out,
  input  wire [63:0] DataConfig_batch_size_in,
  output reg  [63:0] DataConfig_batch_size_out,
  input  wire [63:0] DataConfig_max_seq_len_in,
  output reg  [63:0] DataConfig_max_seq_len_out,
  input  wire  DataConfig_shuffle_in,
  output reg   DataConfig_shuffle_out,
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
      DataLoader_data_out <= 32'd0;
      DataLoader_batch_size_out <= 64'd0;
      DataLoader_shuffle_out <= 1'b0;
      DataLoader_current_idx_out <= 64'd0;
      Batch_inputs_out <= 32'd0;
      Batch_targets_out <= 32'd0;
      Batch_mask_out <= 32'd0;
      DataConfig_path_out <= 256'd0;
      DataConfig_batch_size_out <= 64'd0;
      DataConfig_max_seq_len_out <= 64'd0;
      DataConfig_shuffle_out <= 1'b0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          DataLoader_data_out <= DataLoader_data_in;
          DataLoader_batch_size_out <= DataLoader_batch_size_in;
          DataLoader_shuffle_out <= DataLoader_shuffle_in;
          DataLoader_current_idx_out <= DataLoader_current_idx_in;
          Batch_inputs_out <= Batch_inputs_in;
          Batch_targets_out <= Batch_targets_in;
          Batch_mask_out <= Batch_mask_in;
          DataConfig_path_out <= DataConfig_path_in;
          DataConfig_batch_size_out <= DataConfig_batch_size_in;
          DataConfig_max_seq_len_out <= DataConfig_max_seq_len_in;
          DataConfig_shuffle_out <= DataConfig_shuffle_in;
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
  // - loader_init
  // - next_batch
  // - reset_loader
  // - shuffle_data

endmodule
