`timescale 1ns / 1ps

module trinity_gene_sequencer_tb;

    // Inputs
    reg clk;
    reg rst_n;
    reg enable;

    // Outputs
    wire [1:0] mutation_trit;

    // Instantiate the Unit Under Test (UUT)
    trinity_gene_sequencer uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .mutation_trit(mutation_trit)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Statistics vars
    integer mutation_count;
    integer pos_count;
    integer neg_count;
    integer zero_count;
    integer i;

    // Main Test Sequence
    initial begin
        // Initialize Inputs
        rst_n = 0;
        enable = 0;
        mutation_count = 0;
        pos_count = 0;
        neg_count = 0;
        zero_count = 0;

        // Wait 100 ns for global reset to finish
        #100;
        
        $display("---------------------------------------------------");
        $display("TRINITY GENE SEQUENCER SIMULATION START");
        $display("---------------------------------------------------");
        
        // Reset
        rst_n = 1;
        #10;
        
        // Enable
        enable = 1;
        
        // Run for 1000 cycles
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            #1; // Wait for output to settle after clock edge
            
            case (mutation_trit)
                2'b00: zero_count = zero_count + 1;
                2'b01: begin
                    pos_count = pos_count + 1;
                    mutation_count = mutation_count + 1;
                    // $display("Cycle %d: MUTATION POS (+)", i);
                end
                2'b10: begin
                    neg_count = neg_count + 1;
                    mutation_count = mutation_count + 1;
                    // $display("Cycle %d: MUTATION NEG (-)", i);
                end
                default: $display("Cycle %d: ERROR (Invalid Trit)", i);
            endcase
        end
        
        $display("---------------------------------------------------");
        $display("SIMULATION RESULTS (1000 cycles)");
        $display("---------------------------------------------------");
        $display("Total Mutations: %d", mutation_count);
        $display("Positive (+):    %d", pos_count);
        $display("Negative (-):    %d", neg_count);
        $display("Zeros (Stasis):  %d", zero_count);
        
        // Calculate rate (integer math workaround)
        $display("Mutation Rate:   %0d.%0d%%", (mutation_count * 100) / 1000, ((mutation_count * 1000) / 1000) % 10);
        $display("Target Rate:     3.8%");
        
        if (mutation_count > 0 && mutation_count < 100) begin
             $display("VERDICT: PASS (Sparsity Confirmed)");
        end else begin
             $display("VERDICT: FAIL (Rate Mismatch)");
        end
        
        $finish;
    end
      
endmodule
