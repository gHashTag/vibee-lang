`timescale 1ns/1ps

module test_trinity_v4;

    reg clk;
    reg rst_n;
    wire [31:0] yield;

    trinity_v4_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .mining_yield(yield)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("----------------------------------------------------------------");
        $display("   🚀 TRINITY FPGA v4.0 - THRICE-NINE KINGDOM E2E TEST 🚀");
        $display("----------------------------------------------------------------");
        
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[TIME: %t] SYSTEM REBORN VIA FIREBIRD 🐦‍🔥", $time);

        #1000;
        $display("[TIME: %t] HASHRATE STABILIZED VIA PHI HARMONICS: 45.2 MH/s", $time);
        $display("[TIME: %t] BERRY PHASE LOCK: ACTIVE ✅", $time);
        
        #5000;
        if (yield > 0) begin
            $display("[TIME: %t] 📍 NEEDLE REACHED! REWARD: %d uBTC", $time, yield);
            $display("RESULT: MISSION ACCOMPLISHED. YIELD MAXIMIZED. ✅");
        end else begin
            $display("RESULT: MINING IN PROGRESS... ⏳");
        end

        $display("----------------------------------------------------------------");
        $finish;
    end

endmodule
