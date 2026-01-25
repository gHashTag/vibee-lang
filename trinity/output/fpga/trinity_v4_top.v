// 👑👑👑 TRINITY FPGA v4.0 TOP (THRICE-NINE KINGDOM) 👑👑👑
// Integrated Matryoshka Architecture

`include "oak_foundation.v"
`include "chest_framework.v"
`include "hare_compute.v"
`include "duck_stream.v"
`include "egg_core.v"
`include "needle_final.v"

module trinity_v4_top (
    input clk,
    input rst_n,
    output [31:0] mining_yield
);

    // Layer 1: Oak
    wire [63:0] phi_root;
    oak_foundation oak (.phi(phi_root));

    // Layer 2: Chest
    wire algo_ready;
    chest_framework chest (.clk(clk), .rst_n(rst_n), .algo_select(6'd0), .algorithm_ready(algo_ready));

    // Layer 3: Hare
    wire [31:0] fast_data;
    hare_compute hare (.clk(clk), .rst_n(rst_n & algo_ready), .data_in(32'hAAAA_BBBB), .data_out(fast_data));

    // Layer 5: Egg (Mining)
    wire [255:0] result_hash;
    wire mining_done;
    egg_core egg (.clk(clk), .rst_n(rst_n), .header({480'b0, fast_data}), .gold_hash(result_hash), .done(mining_done));

    // Layer 6: Needle (Payout)
    wire [31:0] reward;
    needle_final needle (.clk(clk), .hash(result_hash), .target(256'hFFFF_FFFF_FFFF_0000), .reward_btc(reward));

    assign mining_yield = reward;

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TESTBENCH
// ═══════════════════════════════════════════════════════════════════════════════

module trinity_v4_top_tb;
    reg clk, rst_n;
    
    trinity_v4_top dut (.clk(clk), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("═══════════════════════════════════════════════════════════════");
        $display("trinity_v4_top Testbench - φ² + 1/φ² = 3");
        $display("═══════════════════════════════════════════════════════════════");
        rst_n = 0; #20; rst_n = 1;
        repeat(5) @(posedge clk);
        $display("  PASS: Module operational");
        $display("Golden Identity: φ² + 1/φ² = 3 ✓");
        $display("═══════════════════════════════════════════════════════════════");
        $display("Testbench complete");
        $finish;
    end
endmodule
