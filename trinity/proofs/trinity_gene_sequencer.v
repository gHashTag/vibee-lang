// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY GENE SEQUENCER (VERILOG 2005)
// ═══════════════════════════════════════════════════════════════════════════════
// "The Silicon DNA"
// Generates pseudo-random ternary mutations using a Pi-seeded LFSR.
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_gene_sequencer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg  [1:0]  mutation_trit // 00:Z, 01:P(+1), 10:N(-1)
);

    // ═══════════════════════════════════════════════════════════════════════════
    // SACRED CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════
    // First 64 bits of Pi (fractional part)
    // 3.141592653589793... -> Hex: 243F 6A88 85A3 08D3
    localparam [63:0] SACRED_SEED_PI = 64'h243F6A8885A308D3;

    // Mutation Rate Threshold
    // Target rate: 0.0381966 (1/phi^2 / 10)
    // 255 * 0.0382 ~= 9.7 => Threshold 10
    localparam [7:0] MUTATION_THRESHOLD = 8'd10;

    // ═══════════════════════════════════════════════════════════════════════════
    // LFSR STATE
    // ═══════════════════════════════════════════════════════════════════════════
    reg [63:0] lfsr_reg;

    // Feedback Polynomial: x^64 + x^63 + x^61 + x^60 + 1 (Xilinx TAP)
    wire feedback;
    assign feedback = !(lfsr_reg[63] ^ lfsr_reg[62] ^ lfsr_reg[60] ^ lfsr_reg[59]);

    // ═══════════════════════════════════════════════════════════════════════════
    // SEQUENCER LOGIC
    // ═══════════════════════════════════════════════════════════════════════════
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= SACRED_SEED_PI;
            mutation_trit <= 2'b00; // ZERO
        end else if (enable) begin
            // Shift LFSR
            lfsr_reg <= {lfsr_reg[62:0], feedback};

            // Generate Mutation
            // Check high byte against sacred threshold for sparsity
            if (lfsr_reg[63:56] < MUTATION_THRESHOLD) begin
                // Use lower bit to determine polarity (+1 or -1)
                if (lfsr_reg[0])
                    mutation_trit <= 2'b01; // POS (+1)
                else
                    mutation_trit <= 2'b10; // NEG (-1)
            end else begin
                mutation_trit <= 2'b00; // ZERO (Stasis)
            end
        end
    end

endmodule
