// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - TOP LEVEL
// Matryoshka Architecture: Kingdom -> Tower -> Chamber -> Treasury -> Vault
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

`include "kingdom_sacred_constants.v"
`include "tower_su3_core.v"
`include "chamber_phi_sha256.v"
`include "treasury_parallel_blocks.v"
`include "vault_mining_core.v"

module trinity_fpga_top (
    input wire clk_in_p,  // 100 MHz differential
    input wire clk_in_n,
    input wire rst_in,
    input wire [7:0] uart_rx, // Pool connection
    output wire [7:0] uart_tx,
    output wire [3:0] leds    // Status
);

    // Clock generation (Mock)
    wire sys_clk = clk_in_p;
    wire sys_rst_n = !rst_in;
    
    // Kingdom Layer: Axiom Check
    wire sacred_verified;
    kingdom_golden_identity_check kgic (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .identity_verified(sacred_verified)
    );
    
    // Vault Layer: Mining Core
    // Only runs if Kingdom logic is verified
    wire [639:0] work_data = {640{1'b0}}; // Placeholder for Stratum work
    wire [31:0] found_nonce;
    wire [31:0] hashrate;
    
    vault_mining_core vmc (
        .clk(sys_clk),
        .rst_n(sys_rst_n & sacred_verified),
        .work_package(work_data),
        .golden_nonce(found_nonce),
        .hashrate_display(hashrate)
    );
    
    // Status LEDs
    assign leds[0] = sacred_verified;
    assign leds[1] = (hashrate > 32'd40000000); // High hashrate indicator
    assign leds[2] = (found_nonce != 0);        // Nonce found
    assign leds[3] = sys_rst_n;                 // Heartbeat

endmodule
