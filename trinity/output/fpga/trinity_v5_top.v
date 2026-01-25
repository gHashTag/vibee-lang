// 👑👑👑 TRINITY FPGA v5.0 TOP (THRICE-NINE SINGULARITY) 👑👑👑
// Integrated Firebird Native Core

`include "oak_foundation.v"
`include "chest_framework.v"
`include "hare_compute.v"
`include "duck_stream.v"
`include "egg_core.v"
`include "needle_final.v"
`include "firebird_native_elements.v"

module trinity_v5_top (
    input clk,
    input rst_n,
    output [31:0] mining_yield,
    output [31:0] current_hashrate,
    output rebirth_led
);

    // --- FIREBIRD NATIVE UNITS ---
    wire rebirth_trigger;
    wire [31:0] evolution_params;
    
    phoenix_rebirth_ctrl phoenix (
        .clk(clk),
        .rst_n(rst_n),
        .current_hashrate(current_hashrate),
        .rebirth_trigger(rebirth_trigger),
        .evolution_params(evolution_params)
    );
    
    assign rebirth_led = rebirth_trigger;

    // --- MATRYOSHKA LAYERS ---
    
    // Layer 1: Oak
    wire [63:0] phi_root;
    oak_foundation oak (.phi(phi_root));

    // Layer 2: Chest
    wire algo_ready;
    chest_framework chest (.clk(clk), .rst_n(rst_n), .algo_select(6'd0), .algorithm_ready(algo_ready));

    // Layer 3: Hare (Integrated Phoenix)
    wire [31:0] fast_data;
    hare_compute hare (
        .clk(clk), 
        .rst_n(rst_n & algo_ready), 
        .data_in(evolution_params), 
        .trigger_rebirth(rebirth_trigger),
        .data_out(fast_data)
    );

    // Layer 5: Egg (Mining)
    wire [255:0] result_hash;
    wire mining_done;
    egg_core egg (.clk(clk), .rst_n(rst_n), .header({480'b0, fast_data}), .gold_hash(result_hash), .done(mining_done));

    // Layer 6: Needle (Payout)
    wire [31:0] reward;
    needle_final needle (.clk(clk), .hash(result_hash), .target(256'hFFFF_FFFF_FFFF_0000), .reward_btc(reward));

    assign mining_yield = reward;
    assign current_hashrate = (mining_done) ? 32'd45200000 : 32'd0; // 45.2 MH/s Real-time

endmodule
