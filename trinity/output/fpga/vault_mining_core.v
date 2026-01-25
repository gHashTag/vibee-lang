// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - VAULT LAYER
// Generated from: specs/fpga/сокровищница/mining_core.vibee
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module vault_mining_core (
    input wire clk,
    input wire rst_n,
    input wire [639:0] work_package,
    output wire [31:0] golden_nonce,
    output wire [31:0] hashrate_display
);

    // The Inner Core
    
    // Connect to Treasury
    wire success;
    wire [31:0] nonce;
    
    treasury_parallel_blocks treasury (
        .clk(clk),
        .rst_n(rst_n),
        .block_header(work_package),
        .found_nonce(nonce),
        .success(success)
    );
    
    // Reward Tracker logic
    reg [31:0] hashes_per_sec;
    assign hashrate_display = hashes_per_sec;
    assign golden_nonce = success ? nonce : 32'h00000000;
    
    always @(posedge clk) begin
        if (rst_n) begin
            hashes_per_sec <= 45000000; // Mock 45 MH/s
        end
    end

endmodule
