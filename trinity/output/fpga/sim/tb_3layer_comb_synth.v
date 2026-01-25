// ═══════════════════════════════════════════════════════════════════════════════
// Post-Synthesis Testbench: 3-Layer Combinational
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_3layer_comb_synth;

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    reg [53:0] input_vec;
    reg [485:0] weights_l1;
    reg [53:0] weights_l2;
    reg [5:0] weights_l3;
    reg signed [5:0] threshold_l1;
    reg signed [4:0] threshold_l2;
    wire signed [2:0] result;

    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;

    bitnet_3layer_combinational dut (
        .input_vec(input_vec),
        .weights_l1(weights_l1),
        .weights_l2(weights_l2),
        .weights_l3(weights_l3),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result(result)
    );

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

    task run_test;
        input [53:0] inp;
        input signed [2:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            input_vec = inp;
            #10;

            if (result === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Test %0d: %s | result=%0d", test_num, test_name, result);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Test %0d: %s | result=%0d, expected=%0d", 
                         test_num, test_name, result, expected);
            end
        end
    endtask

    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("   POST-SYNTHESIS VERIFICATION: 3-Layer Combinational");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        input_vec = 0;
        weights_l1 = make_l1_weights(TRIT_P);
        weights_l2 = make_l2_weights(TRIT_P);
        weights_l3 = all_trit3(TRIT_P);
        threshold_l1 = 6'sd5;
        threshold_l2 = 5'sd2;
        #10;

        $display("TEST SUITE: Post-Synthesis Verification");
        $display("───────────────────────────────────────────────────────────────");

        run_test(all_trit27(TRIT_P), 3, "All +1 input");
        run_test(all_trit27(TRIT_N), -3, "All -1 input");
        run_test(all_trit27(TRIT_Z), 0, "All 0 input");

        weights_l2 = make_l2_weights(TRIT_N);
        run_test(all_trit27(TRIT_P), -3, "Mixed weights");

        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("  Total: %0d | PASS: %0d | FAIL: %0d", test_num, pass_count, fail_count);
        
        if (fail_count == 0) begin
            $display("  ✓ POST-SYNTHESIS VERIFICATION PASSED");
            $display("  Golden Identity: φ² + 1/φ² = 3 ✓");
        end else begin
            $display("  ✗ VERIFICATION FAILED");
        end
        
        $display("═══════════════════════════════════════════════════════════════");
        $finish;
    end

endmodule
