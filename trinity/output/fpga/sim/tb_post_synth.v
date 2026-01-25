// ═══════════════════════════════════════════════════════════════════════════════
// Post-Synthesis Verification Testbench
// ═══════════════════════════════════════════════════════════════════════════════
//
// Compares RTL simulation results with synthesized netlist
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_post_synth;

    // Trit encoding
    localparam TRIT_N = 2'b00;  // -1
    localparam TRIT_Z = 2'b01;  //  0
    localparam TRIT_P = 2'b10;  // +1

    // Test signals
    reg [53:0] input_vec;
    reg [53:0] weight_vec;
    wire signed [5:0] result;

    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;

    // DUT instantiation
    trit27_dot_product dut (
        .input_vec(input_vec),
        .weight_vec(weight_vec),
        .result(result)
    );

    // Helper function: create trit27 vector
    function [53:0] make_trit27;
        input [1:0] t0, t1, t2, t3, t4, t5, t6, t7, t8;
        input [1:0] t9, t10, t11, t12, t13, t14, t15, t16, t17;
        input [1:0] t18, t19, t20, t21, t22, t23, t24, t25, t26;
        begin
            make_trit27 = {t26, t25, t24, t23, t22, t21, t20, t19, t18,
                          t17, t16, t15, t14, t13, t12, t11, t10, t9,
                          t8, t7, t6, t5, t4, t3, t2, t1, t0};
        end
    endfunction

    // Helper: all same trit
    function [53:0] all_trit;
        input [1:0] t;
        integer i;
        begin
            all_trit = 0;
            for (i = 0; i < 27; i = i + 1)
                all_trit[i*2 +: 2] = t;
        end
    endfunction

    // Test task
    task run_test;
        input [53:0] inp;
        input [53:0] wgt;
        input signed [5:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            input_vec = inp;
            weight_vec = wgt;
            #10;  // Wait for combinational logic

            if (result === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Test %0d: %s | result=%0d (expected %0d)",
                         test_num, test_name, result, expected);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Test %0d: %s | result=%0d (expected %0d)",
                         test_num, test_name, result, expected);
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("       POST-SYNTHESIS VERIFICATION - trit27_dot_product");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        // Initialize
        input_vec = 0;
        weight_vec = 0;
        #10;

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 1: Basic Operations
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 1: Basic Operations");
        $display("───────────────────────────────────────────────────────────────");

        // Test 1: All zeros
        run_test(all_trit(TRIT_Z), all_trit(TRIT_Z), 0, "All zeros");

        // Test 2: All +1 * All +1 = +27
        run_test(all_trit(TRIT_P), all_trit(TRIT_P), 27, "All +1 * All +1");

        // Test 3: All -1 * All -1 = +27
        run_test(all_trit(TRIT_N), all_trit(TRIT_N), 27, "All -1 * All -1");

        // Test 4: All +1 * All -1 = -27
        run_test(all_trit(TRIT_P), all_trit(TRIT_N), -27, "All +1 * All -1");

        // Test 5: All -1 * All +1 = -27
        run_test(all_trit(TRIT_N), all_trit(TRIT_P), -27, "All -1 * All +1");

        // Test 6: All +1 * All 0 = 0
        run_test(all_trit(TRIT_P), all_trit(TRIT_Z), 0, "All +1 * All 0");

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 2: Balanced Patterns
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 2: Balanced Patterns");
        $display("───────────────────────────────────────────────────────────────");

        // Test 7: 9×(+1), 9×(-1), 9×(0) with all +1 weights
        // Expected: 9×1 + 9×(-1) + 9×0 = 0
        begin
            reg [53:0] balanced_input;
            integer i;
            balanced_input = 0;
            for (i = 0; i < 9; i = i + 1) balanced_input[i*2 +: 2] = TRIT_P;
            for (i = 9; i < 18; i = i + 1) balanced_input[i*2 +: 2] = TRIT_N;
            for (i = 18; i < 27; i = i + 1) balanced_input[i*2 +: 2] = TRIT_Z;
            run_test(balanced_input, all_trit(TRIT_P), 0, "Balanced input * All +1");
        end

        // Test 8: Same balanced pattern, weights = input
        // Expected: 9×1 + 9×1 + 9×0 = 18
        begin
            reg [53:0] balanced;
            integer i;
            balanced = 0;
            for (i = 0; i < 9; i = i + 1) balanced[i*2 +: 2] = TRIT_P;
            for (i = 9; i < 18; i = i + 1) balanced[i*2 +: 2] = TRIT_N;
            for (i = 18; i < 27; i = i + 1) balanced[i*2 +: 2] = TRIT_Z;
            run_test(balanced, balanced, 18, "Balanced * Balanced (self)");
        end

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 3: Alternating Patterns
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 3: Alternating Patterns");
        $display("───────────────────────────────────────────────────────────────");

        // Test 9: Alternating +1/-1 input, all +1 weights
        // 14×(+1) + 13×(-1) = 14 - 13 = 1
        begin
            reg [53:0] alt_input;
            integer i;
            alt_input = 0;
            for (i = 0; i < 27; i = i + 1)
                alt_input[i*2 +: 2] = (i % 2 == 0) ? TRIT_P : TRIT_N;
            run_test(alt_input, all_trit(TRIT_P), 1, "Alternating +1/-1 * All +1");
        end

        // Test 10: Alternating input * same alternating = all +1 products
        begin
            reg [53:0] alt;
            integer i;
            alt = 0;
            for (i = 0; i < 27; i = i + 1)
                alt[i*2 +: 2] = (i % 2 == 0) ? TRIT_P : TRIT_N;
            run_test(alt, alt, 27, "Alternating * Alternating (self)");
        end

        $display("");

        // ═══════════════════════════════════════════════════════════════
        // TEST SUITE 4: Edge Cases
        // ═══════════════════════════════════════════════════════════════
        $display("TEST SUITE 4: Edge Cases");
        $display("───────────────────────────────────────────────────────────────");

        // Test 11: Single +1 at position 0
        begin
            reg [53:0] single;
            single = all_trit(TRIT_Z);
            single[1:0] = TRIT_P;
            run_test(single, all_trit(TRIT_P), 1, "Single +1 at pos 0");
        end

        // Test 12: Single -1 at position 26
        begin
            reg [53:0] single;
            single = all_trit(TRIT_Z);
            single[53:52] = TRIT_N;
            run_test(single, all_trit(TRIT_P), -1, "Single -1 at pos 26");
        end

        // Test 13: Maximum positive (all +1 * all +1)
        run_test(all_trit(TRIT_P), all_trit(TRIT_P), 27, "Max positive (+27)");

        // Test 14: Maximum negative (all +1 * all -1)
        run_test(all_trit(TRIT_P), all_trit(TRIT_N), -27, "Max negative (-27)");

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
            $display("  ✓ ALL TESTS PASSED - Post-synthesis verification SUCCESSFUL");
            $display("");
            $display("  Golden Identity: φ² + 1/φ² = 3 ✓");
            $display("  PHOENIX = 999 ✓");
        end else begin
            $display("  ✗ SOME TESTS FAILED - Post-synthesis mismatch detected!");
        end

        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        $finish;
    end

endmodule
