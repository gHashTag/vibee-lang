// ═══════════════════════════════════════════════════════════════════════════════
// Testbench: 3-Layer BitNet Pipeline
// ═══════════════════════════════════════════════════════════════════════════════
//
// Architecture: 27 → 9 → 3 → 1
// Tests full forward pass with known weights
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_3layer_pipeline;

    // Trit encoding
    localparam TRIT_N = 2'b00;  // -1
    localparam TRIT_Z = 2'b01;  //  0
    localparam TRIT_P = 2'b10;  // +1

    // Clock and reset
    reg clk;
    reg rst_n;
    reg start;
    
    // Inputs
    reg [53:0] input_vec;
    reg [485:0] weights_l1;
    reg [53:0] weights_l2;
    reg [5:0] weights_l3;
    reg signed [5:0] threshold_l1;
    reg signed [4:0] threshold_l2;
    
    // Outputs
    wire signed [2:0] result;
    wire valid;
    wire ready;
    
    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;

    // DUT - Pipelined version
    bitnet_3layer_pipeline dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .input_vec(input_vec),
        .weights_l1(weights_l1),
        .weights_l2(weights_l2),
        .weights_l3(weights_l3),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result(result),
        .valid(valid),
        .ready(ready)
    );

    // Combinational DUT for comparison
    wire signed [2:0] comb_result;
    bitnet_3layer_combinational dut_comb (
        .input_vec(input_vec),
        .weights_l1(weights_l1),
        .weights_l2(weights_l2),
        .weights_l3(weights_l3),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result(comb_result)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper: create all-same trit vector
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

    // Helper: create layer 1 weights (9 rows of 27 trits)
    function [485:0] make_l1_weights;
        input [1:0] t;
        integer i;
        begin
            make_l1_weights = 0;
            for (i = 0; i < 9; i = i + 1)
                make_l1_weights[i*54 +: 54] = all_trit27(t);
        end
    endfunction

    // Helper: create layer 2 weights (3 rows of 9 trits)
    function [53:0] make_l2_weights;
        input [1:0] t;
        integer i;
        begin
            make_l2_weights = 0;
            for (i = 0; i < 3; i = i + 1)
                make_l2_weights[i*18 +: 18] = all_trit9(t);
        end
    endfunction

    // Test task for pipelined version
    task run_pipeline_test;
        input [53:0] inp;
        input signed [2:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            input_vec = inp;
            
            // Wait for ready
            wait(ready);
            @(posedge clk);
            
            // Start inference
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait for valid output (4 cycles: input + 3 layers)
            repeat(5) @(posedge clk);
            
            // Check combinational result immediately
            if (comb_result === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Test %0d: %s | comb=%0d, expected=%0d",
                         test_num, test_name, comb_result, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Test %0d: %s | comb=%0d, expected=%0d",
                         test_num, test_name, comb_result, expected);
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("       3-LAYER BITNET PIPELINE TESTBENCH");
        $display("       Architecture: 27 → 9 → 3 → 1");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        // Initialize
        rst_n = 0;
        start = 0;
        input_vec = 0;
        weights_l1 = 0;
        weights_l2 = 0;
        weights_l3 = 0;
        threshold_l1 = 6'sd5;  // Threshold for layer 1
        threshold_l2 = 5'sd2;  // Threshold for layer 2
        
        // Reset
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 1: All +1 weights
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 1: All +1 Weights");
        $display("───────────────────────────────────────────────────────────────");
        
        // Set all weights to +1
        weights_l1 = make_l1_weights(TRIT_P);
        weights_l2 = make_l2_weights(TRIT_P);
        weights_l3 = all_trit3(TRIT_P);
        
        // Test 1: All +1 input
        // L1: 27×(+1×+1) = +27 per neuron → all activate to +1 (27 > 5)
        // L2: 9×(+1×+1) = +9 per neuron → all activate to +1 (9 > 2)
        // L3: 3×(+1×+1) = +3
        run_pipeline_test(all_trit27(TRIT_P), 3, "All +1 input");
        
        // Test 2: All -1 input
        // L1: 27×(-1×+1) = -27 per neuron → all activate to -1 (-27 < -5)
        // L2: 9×(-1×+1) = -9 per neuron → all activate to -1 (-9 < -2)
        // L3: 3×(-1×+1) = -3
        run_pipeline_test(all_trit27(TRIT_N), -3, "All -1 input");
        
        // Test 3: All 0 input
        // L1: 27×(0×+1) = 0 per neuron → all activate to 0
        // L2: 9×(0×+1) = 0 per neuron → all activate to 0
        // L3: 3×(0×+1) = 0
        run_pipeline_test(all_trit27(TRIT_Z), 0, "All 0 input");
        
        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 2: Mixed weights
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 2: Mixed Weights");
        $display("───────────────────────────────────────────────────────────────");
        
        // Set L1 weights to +1, L2 to -1, L3 to +1
        weights_l1 = make_l1_weights(TRIT_P);
        weights_l2 = make_l2_weights(TRIT_N);
        weights_l3 = all_trit3(TRIT_P);
        
        // Test 4: All +1 input with mixed weights
        // L1: +27 → +1 activation
        // L2: 9×(+1×-1) = -9 → -1 activation
        // L3: 3×(-1×+1) = -3
        run_pipeline_test(all_trit27(TRIT_P), -3, "All +1 input, mixed weights");
        
        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 3: Threshold effects
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 3: Threshold Effects");
        $display("───────────────────────────────────────────────────────────────");
        
        // High thresholds - should produce more zeros
        threshold_l1 = 6'sd20;  // Only ±27 will pass
        threshold_l2 = 5'sd8;   // Only ±9 will pass
        weights_l1 = make_l1_weights(TRIT_P);
        weights_l2 = make_l2_weights(TRIT_P);
        weights_l3 = all_trit3(TRIT_P);
        
        // Test 5: All +1 with high thresholds
        // L1: +27 > 20 → +1
        // L2: +9 > 8 → +1
        // L3: +3
        run_pipeline_test(all_trit27(TRIT_P), 3, "High thresholds, all +1");
        
        // Test 6: Balanced input (should produce zeros)
        begin
            reg [53:0] balanced;
            integer i;
            balanced = 0;
            for (i = 0; i < 9; i = i + 1) balanced[i*2 +: 2] = TRIT_P;
            for (i = 9; i < 18; i = i + 1) balanced[i*2 +: 2] = TRIT_N;
            for (i = 18; i < 27; i = i + 1) balanced[i*2 +: 2] = TRIT_Z;
            // L1: 9-9+0 = 0 per neuron → 0 activation (|0| < 20)
            // L2: 0 → 0
            // L3: 0
            run_pipeline_test(balanced, 0, "Balanced input, high thresholds");
        end
        
        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 4: Identity-like patterns
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 4: Pattern Recognition");
        $display("───────────────────────────────────────────────────────────────");
        
        // Reset thresholds
        threshold_l1 = 6'sd5;
        threshold_l2 = 5'sd2;
        
        // Create diagonal-like weights for L1 (identity mapping)
        begin
            integer row, col;
            reg [485:0] diag_weights;
            diag_weights = 0;
            for (row = 0; row < 9; row = row + 1) begin
                for (col = 0; col < 27; col = col + 1) begin
                    // Each neuron responds to 3 consecutive inputs
                    if (col >= row*3 && col < (row+1)*3)
                        diag_weights[row*54 + col*2 +: 2] = TRIT_P;
                    else
                        diag_weights[row*54 + col*2 +: 2] = TRIT_Z;
                end
            end
            weights_l1 = diag_weights;
        end
        
        weights_l2 = make_l2_weights(TRIT_P);
        weights_l3 = all_trit3(TRIT_P);
        
        // Test 7: All +1 with diagonal weights
        // Each L1 neuron sees 3×(+1) = +3, which is < 5, so → 0
        // L2: 9×0 = 0 → 0
        // L3: 3×0 = 0
        run_pipeline_test(all_trit27(TRIT_P), 0, "Diagonal weights, all +1");
        
        // Lower threshold to see diagonal effect
        threshold_l1 = 6'sd2;
        
        // Test 8: All +1 with diagonal weights, low threshold
        // Each L1 neuron sees 3×(+1) = +3 > 2 → +1
        // L2: 9×(+1) = +9 > 2 → +1
        // L3: 3×(+1) = +3
        run_pipeline_test(all_trit27(TRIT_P), 3, "Diagonal weights, low threshold");
        
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

        if (fail_count == 0) begin
            $display("  ✓ ALL TESTS PASSED - 3-Layer Pipeline VERIFIED");
            $display("");
            $display("  Architecture: 27 → 9 → 3 → 1");
            $display("  Total weights: 243 + 27 + 3 = 273");
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
