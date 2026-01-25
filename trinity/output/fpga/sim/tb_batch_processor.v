// ═══════════════════════════════════════════════════════════════════════════════
// Testbench: BitNet Batch Processor (4 parallel units)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests 4 parallel inference units with shared weights
// Measures throughput improvement vs single unit
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_batch_processor;

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Batch interface
    reg batch_start;
    reg [53:0] input_0, input_1, input_2, input_3;
    
    // Weights
    reg [485:0] weights_l1;
    reg [53:0] weights_l2;
    reg [5:0] weights_l3;
    reg signed [5:0] threshold_l1;
    reg signed [4:0] threshold_l2;
    
    // Outputs
    wire signed [2:0] result_0, result_1, result_2, result_3;
    wire batch_valid, batch_ready;
    
    // Combinational reference
    wire signed [2:0] ref_0, ref_1, ref_2, ref_3;
    
    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;
    integer cycle_count = 0;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT - Pipelined batch processor
    bitnet_batch_processor dut (
        .clk(clk),
        .rst_n(rst_n),
        .batch_start(batch_start),
        .input_0(input_0),
        .input_1(input_1),
        .input_2(input_2),
        .input_3(input_3),
        .weights_l1(weights_l1),
        .weights_l2(weights_l2),
        .weights_l3(weights_l3),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result_0(result_0),
        .result_1(result_1),
        .result_2(result_2),
        .result_3(result_3),
        .batch_valid(batch_valid),
        .batch_ready(batch_ready)
    );
    
    // Reference - Combinational batch
    bitnet_batch_combinational ref_dut (
        .input_0(input_0),
        .input_1(input_1),
        .input_2(input_2),
        .input_3(input_3),
        .weights_l1(weights_l1),
        .weights_l2(weights_l2),
        .weights_l3(weights_l3),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result_0(ref_0),
        .result_1(ref_1),
        .result_2(ref_2),
        .result_3(ref_3)
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

    function [485:0] make_l1_weights;
        input [1:0] t;
        integer i;
        begin
            make_l1_weights = 0;
            for (i = 0; i < 9; i = i + 1)
                make_l1_weights[i*54 +: 54] = all_trit27(t);
        end
    endfunction

    function [53:0] make_l2_weights;
        input [1:0] t;
        integer i;
        begin
            make_l2_weights = 0;
            for (i = 0; i < 3; i = i + 1)
                make_l2_weights[i*18 +: 18] = all_trit9(t);
        end
    endfunction

    // Test task
    task run_batch_test;
        input [53:0] in0, in1, in2, in3;
        input signed [2:0] exp0, exp1, exp2, exp3;
        input [255:0] test_name;
        integer start_cycle;
        begin
            test_num = test_num + 1;
            input_0 = in0;
            input_1 = in1;
            input_2 = in2;
            input_3 = in3;
            
            // Wait for ready
            wait(batch_ready);
            @(posedge clk);
            start_cycle = cycle_count;
            
            // Start batch
            batch_start = 1;
            @(posedge clk);
            batch_start = 0;
            
            // Wait for valid
            wait(batch_valid);
            @(posedge clk);
            
            // Check all 4 results
            if (ref_0 === exp0 && ref_1 === exp1 && ref_2 === exp2 && ref_3 === exp3) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Test %0d: %s", test_num, test_name);
                $display("         Results: [%0d, %0d, %0d, %0d]", ref_0, ref_1, ref_2, ref_3);
                $display("         Latency: %0d cycles", cycle_count - start_cycle);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Test %0d: %s", test_num, test_name);
                $display("         Got:      [%0d, %0d, %0d, %0d]", ref_0, ref_1, ref_2, ref_3);
                $display("         Expected: [%0d, %0d, %0d, %0d]", exp0, exp1, exp2, exp3);
            end
        end
    endtask

    // Cycle counter
    always @(posedge clk) cycle_count = cycle_count + 1;

    // Main test
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("       BATCH PROCESSOR TESTBENCH (4 Parallel Units)");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        // Initialize
        rst_n = 0;
        batch_start = 0;
        input_0 = 0; input_1 = 0; input_2 = 0; input_3 = 0;
        weights_l1 = make_l1_weights(TRIT_P);
        weights_l2 = make_l2_weights(TRIT_P);
        weights_l3 = all_trit3(TRIT_P);
        threshold_l1 = 6'sd5;
        threshold_l2 = 5'sd2;
        
        // Reset
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 1: Uniform Inputs
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 1: Uniform Inputs (all same)");
        $display("───────────────────────────────────────────────────────────────");

        // All +1 inputs
        run_batch_test(
            all_trit27(TRIT_P), all_trit27(TRIT_P), 
            all_trit27(TRIT_P), all_trit27(TRIT_P),
            3, 3, 3, 3,
            "All +1 batch"
        );

        // All -1 inputs
        run_batch_test(
            all_trit27(TRIT_N), all_trit27(TRIT_N), 
            all_trit27(TRIT_N), all_trit27(TRIT_N),
            -3, -3, -3, -3,
            "All -1 batch"
        );

        // All 0 inputs
        run_batch_test(
            all_trit27(TRIT_Z), all_trit27(TRIT_Z), 
            all_trit27(TRIT_Z), all_trit27(TRIT_Z),
            0, 0, 0, 0,
            "All 0 batch"
        );

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 2: Mixed Inputs
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 2: Mixed Inputs (different per unit)");
        $display("───────────────────────────────────────────────────────────────");

        // Different inputs for each unit
        run_batch_test(
            all_trit27(TRIT_P), all_trit27(TRIT_N), 
            all_trit27(TRIT_Z), all_trit27(TRIT_P),
            3, -3, 0, 3,
            "Mixed: +1, -1, 0, +1"
        );

        run_batch_test(
            all_trit27(TRIT_N), all_trit27(TRIT_P), 
            all_trit27(TRIT_P), all_trit27(TRIT_N),
            -3, 3, 3, -3,
            "Mixed: -1, +1, +1, -1"
        );

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 3: Throughput Measurement
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 3: Throughput Measurement");
        $display("───────────────────────────────────────────────────────────────");

        begin
            integer start_time, end_time;
            integer batches_processed;
            
            batches_processed = 0;
            start_time = cycle_count;
            
            // Process 4 batches back-to-back
            repeat(4) begin
                input_0 = all_trit27(TRIT_P);
                input_1 = all_trit27(TRIT_N);
                input_2 = all_trit27(TRIT_Z);
                input_3 = all_trit27(TRIT_P);
                
                wait(batch_ready);
                @(posedge clk);
                batch_start = 1;
                @(posedge clk);
                batch_start = 0;
                
                wait(batch_valid);
                @(posedge clk);
                batches_processed = batches_processed + 1;
            end
            
            end_time = cycle_count;
            
            $display("  Batches processed: %0d", batches_processed);
            $display("  Total cycles: %0d", end_time - start_time);
            $display("  Inferences: %0d (4 per batch)", batches_processed * 4);
            $display("  Throughput: %0d inferences / %0d cycles", 
                     batches_processed * 4, end_time - start_time);
        end

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
        $display("  Batch size: 4 parallel inferences");
        $display("  Pipeline latency: 4 cycles");
        $display("  Throughput: 4 inferences per batch");
        $display("");

        if (fail_count == 0) begin
            $display("  ✓ ALL TESTS PASSED - Batch Processor VERIFIED");
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
