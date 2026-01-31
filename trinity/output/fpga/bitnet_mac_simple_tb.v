// ═══════════════════════════════════════════════════════════════════════════════
// BitNet Ternary MAC Unit - Simple Testbench
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY MAC UNIT
// ═══════════════════════════════════════════════════════════════════════════════

module ternary_mac (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  weight,      // 00=0, 01=+1, 10=-1
    input  wire signed [7:0]  activation,  // 8-bit signed
    input  wire        enable,
    input  wire        clear,
    output reg  signed [31:0] accumulator
);

    // Select operand based on weight
    wire signed [31:0] operand;
    assign operand = (weight == 2'b01) ? {{24{activation[7]}}, activation} :
                     (weight == 2'b10) ? -{{24{activation[7]}}, activation} :
                     32'sd0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            accumulator <= 32'sd0;
        else if (clear)
            accumulator <= 32'sd0;
        else if (enable)
            accumulator <= accumulator + operand;
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TESTBENCH
// ═══════════════════════════════════════════════════════════════════════════════

module bitnet_mac_simple_tb;

    reg clk;
    reg rst_n;
    reg [1:0] weight;
    reg signed [7:0] activation;
    reg enable;
    reg clear;
    wire signed [31:0] accumulator;
    
    integer tests_passed = 0;
    integer tests_failed = 0;
    
    ternary_mac dut (
        .clk(clk),
        .rst_n(rst_n),
        .weight(weight),
        .activation(activation),
        .enable(enable),
        .clear(clear),
        .accumulator(accumulator)
    );
    
    // Clock: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Helper task: do one MAC and wait
    task do_mac(input [1:0] w, input signed [7:0] a);
        begin
            weight = w;
            activation = a;
            enable = 1;
            @(posedge clk);
            #1;
            enable = 0;
        end
    endtask
    
    // Helper task: clear and wait
    task do_clear;
        begin
            clear = 1;
            @(posedge clk);
            #1;
            clear = 0;
        end
    endtask
    
    // Helper task: check result
    task check(input signed [31:0] expected, input [255:0] name);
        begin
            if (accumulator === expected) begin
                $display("  PASS: %s = %d", name, accumulator);
                tests_passed = tests_passed + 1;
            end else begin
                $display("  FAIL: %s - Expected %d, Got %d", name, expected, accumulator);
                tests_failed = tests_failed + 1;
            end
        end
    endtask
    
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════════════════════");
        $display("  BitNet Ternary MAC - Simple Testbench");
        $display("═══════════════════════════════════════════════════════════════════════════════");
        $display("");
        
        // Reset
        rst_n = 0;
        weight = 0;
        activation = 0;
        enable = 0;
        clear = 0;
        #20;
        rst_n = 1;
        #10;
        
        // TEST 1: w=0 (no-op)
        $display("TEST 1: Zero weight");
        do_clear;
        do_mac(2'b00, 8'd100);
        check(32'd0, "w=0, x=100");
        
        // TEST 2: w=+1 (add)
        $display("TEST 2: Plus one weight");
        do_clear;
        do_mac(2'b01, 8'd10);
        check(32'd10, "w=+1, x=10");
        
        // TEST 3: w=-1 (subtract)
        $display("TEST 3: Minus one weight");
        do_clear;
        do_mac(2'b10, 8'd10);
        check(-32'd10, "w=-1, x=10");
        
        // TEST 4: Accumulation
        $display("TEST 4: Accumulation");
        do_clear;
        do_mac(2'b01, 8'd5);   // +5
        do_mac(2'b10, 8'd3);   // -3
        do_mac(2'b01, 8'd7);   // +7
        check(32'd9, "5 - 3 + 7 = 9");
        
        // TEST 5: Negative activation
        $display("TEST 5: Negative activation");
        do_clear;
        do_mac(2'b01, -8'd10);  // w=+1, x=-10
        check(-32'd10, "w=+1, x=-10");
        
        // TEST 6: Double negative
        $display("TEST 6: Double negative");
        do_clear;
        do_mac(2'b10, -8'd10);  // w=-1, x=-10 = +10
        check(32'd10, "w=-1, x=-10 = +10");
        
        // TEST 7: Large accumulation
        $display("TEST 7: 100 MACs");
        do_clear;
        repeat(100) do_mac(2'b01, 8'd1);
        check(32'd100, "100 x (w=+1, x=1)");
        
        // Summary
        $display("");
        $display("═══════════════════════════════════════════════════════════════════════════════");
        $display("  RESULTS: %d passed, %d failed", tests_passed, tests_failed);
        $display("═══════════════════════════════════════════════════════════════════════════════");
        
        if (tests_failed == 0) begin
            $display("");
            $display("  ✓ ALL TESTS PASSED!");
            $display("  BitNet MAC ready for FPGA synthesis.");
            $display("  Key: NO MULTIPLIERS - just add/subtract!");
            $display("");
        end
        
        $finish;
    end

endmodule
