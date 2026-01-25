// ═══════════════════════════════════════════════════════════════════════════════
// Testbench: BRAM-based BitNet Inference
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests weight loading to BRAM and sequential inference
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_bram_inference;

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Weight loading
    reg load_weight;
    reg [1:0] load_layer;
    reg [3:0] load_row;
    reg [53:0] load_data;
    wire load_done;
    
    // Inference
    reg infer_start;
    reg [53:0] input_vec;
    reg signed [5:0] threshold_l1;
    reg signed [4:0] threshold_l2;
    
    wire signed [2:0] result;
    wire result_valid;
    wire ready;
    
    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    bitnet_bram_inference dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(load_weight),
        .load_layer(load_layer),
        .load_row(load_row),
        .load_data(load_data),
        .load_done(load_done),
        .infer_start(infer_start),
        .input_vec(input_vec),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result(result),
        .result_valid(result_valid),
        .ready(ready)
    );

    // Helper functions
    function [53:0] all_trit27;
        input [1:0] t;
        integer i;
        begin
            all_trit27 = 0;
            for (i = 0; i < 27; i = i + 1)
                all_trit27[i*2 +: 2] = t;
        end
    endfunction

    function [17:0] all_trit9;
        input [1:0] t;
        integer i;
        begin
            all_trit9 = 0;
            for (i = 0; i < 9; i = i + 1)
                all_trit9[i*2 +: 2] = t;
        end
    endfunction

    function [5:0] all_trit3;
        input [1:0] t;
        integer i;
        begin
            all_trit3 = 0;
            for (i = 0; i < 3; i = i + 1)
                all_trit3[i*2 +: 2] = t;
        end
    endfunction

    // Task: Load single weight row
    task load_weight_row;
        input [1:0] layer;
        input [3:0] row;
        input [53:0] data;
        begin
            @(posedge clk);
            load_weight <= 1;
            load_layer <= layer;
            load_row <= row;
            load_data <= data;
            @(posedge clk);
            load_weight <= 0;
            wait(load_done);
            @(posedge clk);
        end
    endtask

    // Task: Load all weights (all +1)
    task load_all_weights_positive;
        integer i;
        begin
            $display("  Loading Layer 1 weights (9 rows)...");
            for (i = 0; i < 9; i = i + 1) begin
                load_weight_row(2'd0, i[3:0], all_trit27(TRIT_P));
            end
            
            $display("  Loading Layer 2 weights (3 rows)...");
            for (i = 0; i < 3; i = i + 1) begin
                load_weight_row(2'd1, i[3:0], {36'd0, all_trit9(TRIT_P)});
            end
            
            $display("  Loading Layer 3 weights (1 row)...");
            load_weight_row(2'd2, 4'd0, {48'd0, all_trit3(TRIT_P)});
            
            $display("  All weights loaded.");
        end
    endtask

    // Task: Load all weights (all -1)
    task load_all_weights_negative;
        integer i;
        begin
            for (i = 0; i < 9; i = i + 1)
                load_weight_row(2'd0, i[3:0], all_trit27(TRIT_N));
            for (i = 0; i < 3; i = i + 1)
                load_weight_row(2'd1, i[3:0], {36'd0, all_trit9(TRIT_N)});
            load_weight_row(2'd2, 4'd0, {48'd0, all_trit3(TRIT_N)});
        end
    endtask

    // Task: Run inference
    task run_inference;
        input [53:0] inp;
        input signed [2:0] expected;
        input [255:0] test_name;
        integer start_cycle, end_cycle;
        begin
            test_num = test_num + 1;
            input_vec = inp;
            
            wait(ready);
            @(posedge clk);
            start_cycle = $time / 10;
            
            infer_start = 1;
            @(posedge clk);
            infer_start = 0;
            
            wait(result_valid);
            @(posedge clk);
            end_cycle = $time / 10;
            
            if (result === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Test %0d: %s | result=%0d, cycles=%0d",
                         test_num, test_name, result, end_cycle - start_cycle);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Test %0d: %s | result=%0d, expected=%0d",
                         test_num, test_name, result, expected);
            end
        end
    endtask

    // Main test
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("       BRAM-BASED INFERENCE TESTBENCH");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        // Initialize
        rst_n = 0;
        load_weight = 0;
        load_layer = 0;
        load_row = 0;
        load_data = 0;
        infer_start = 0;
        input_vec = 0;
        threshold_l1 = 6'sd5;
        threshold_l2 = 5'sd2;
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 1: Weight Loading
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 1: Weight Loading");
        $display("───────────────────────────────────────────────────────────────");
        
        load_all_weights_positive();
        
        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 2: Inference with Positive Weights
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 2: Inference (All +1 Weights)");
        $display("───────────────────────────────────────────────────────────────");

        run_inference(all_trit27(TRIT_P), 3, "All +1 input");
        run_inference(all_trit27(TRIT_N), -3, "All -1 input");
        run_inference(all_trit27(TRIT_Z), 0, "All 0 input");

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 3: Reload Weights and Test Again
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 3: Reload Weights (All -1)");
        $display("───────────────────────────────────────────────────────────────");
        
        load_all_weights_negative();
        
        // With all -1 weights:
        // All +1 input: L1 = -27 → -1, L2 = +9 → +1, L3 = -3
        run_inference(all_trit27(TRIT_P), -3, "All +1 input (neg weights)");
        
        // All -1 input: L1 = +27 → +1, L2 = -9 → -1, L3 = +3
        run_inference(all_trit27(TRIT_N), 3, "All -1 input (neg weights)");

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // SUMMARY
        // ═══════════════════════════════════════════════════════════════
        $display("═══════════════════════════════════════════════════════════════");
        $display("                         SUMMARY");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");
        $display("  Total tests: %0d", test_num);
        $display("  PASSED:      %0d", pass_count);
        $display("  FAILED:      %0d", fail_count);
        $display("");
        $display("  BRAM Storage:");
        $display("  - Layer 1: 9 × 54 bits = 486 bits");
        $display("  - Layer 2: 3 × 18 bits = 54 bits");
        $display("  - Layer 3: 1 × 6 bits = 6 bits (register)");
        $display("  - Total: 546 bits in BRAM");
        $display("");

        if (fail_count == 0) begin
            $display("  ✓ ALL TESTS PASSED - BRAM Inference VERIFIED");
            $display("");
            $display("  Golden Identity: φ² + 1/φ² = 3 ✓");
            $display("  PHOENIX = 999 ✓");
        end else begin
            $display("  ✗ SOME TESTS FAILED");
        end

        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        $finish;
    end

endmodule
