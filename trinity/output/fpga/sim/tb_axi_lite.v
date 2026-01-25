// ═══════════════════════════════════════════════════════════════════════════════
// Testbench: AXI-Lite BitNet Accelerator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests full CPU integration flow:
// 1. Read VERSION and PHOENIX registers
// 2. Load weights via AXI writes
// 3. Run inference via AXI
// 4. Read results
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_axi_lite;

    // Parameters
    localparam C_S_AXI_DATA_WIDTH = 32;
    localparam C_S_AXI_ADDR_WIDTH = 6;
    
    // Register addresses
    localparam ADDR_CTRL      = 6'h00;
    localparam ADDR_STATUS    = 6'h04;
    localparam ADDR_INPUT_LO  = 6'h08;
    localparam ADDR_INPUT_HI  = 6'h0C;
    localparam ADDR_WEIGHT_LO = 6'h10;
    localparam ADDR_WEIGHT_HI = 6'h14;
    localparam ADDR_THRESHOLD = 6'h18;
    localparam ADDR_RESULT    = 6'h1C;
    localparam ADDR_VERSION   = 6'h20;
    localparam ADDR_PHOENIX   = 6'h24;
    
    // Trit encoding
    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Clock and reset
    reg aclk;
    reg aresetn;
    
    // AXI-Lite signals
    reg  [C_S_AXI_ADDR_WIDTH-1:0] awaddr;
    reg  [2:0] awprot;
    reg  awvalid;
    wire awready;
    reg  [C_S_AXI_DATA_WIDTH-1:0] wdata;
    reg  [C_S_AXI_DATA_WIDTH/8-1:0] wstrb;
    reg  wvalid;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg  bready;
    reg  [C_S_AXI_ADDR_WIDTH-1:0] araddr;
    reg  [2:0] arprot;
    reg  arvalid;
    wire arready;
    wire [C_S_AXI_DATA_WIDTH-1:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg  rready;
    
    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;
    
    // Read data capture
    reg [31:0] read_data;

    // Clock generation
    initial aclk = 0;
    always #5 aclk = ~aclk;

    // DUT
    bitnet_axi_lite #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .S_AXI_ACLK(aclk),
        .S_AXI_ARESETN(aresetn),
        .S_AXI_AWADDR(awaddr),
        .S_AXI_AWPROT(awprot),
        .S_AXI_AWVALID(awvalid),
        .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),
        .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),
        .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),
        .S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr),
        .S_AXI_ARPROT(arprot),
        .S_AXI_ARVALID(arvalid),
        .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata),
        .S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready)
    );

    // AXI Write task (simplified)
    task axi_write;
        input [5:0] addr;
        input [31:0] data;
        integer timeout;
        begin
            @(posedge aclk);
            awaddr <= addr;
            awprot <= 3'b000;
            awvalid <= 1;
            wdata <= data;
            wstrb <= 4'hF;
            wvalid <= 1;
            bready <= 1;
            
            // Wait for handshake with timeout
            timeout = 0;
            while (!(awready && wready) && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            @(posedge aclk);
            awvalid <= 0;
            wvalid <= 0;
            
            // Wait for response with timeout
            timeout = 0;
            while (!bvalid && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            @(posedge aclk);
            bready <= 0;
            @(posedge aclk);
        end
    endtask

    // AXI Read task (simplified)
    task axi_read;
        input [5:0] addr;
        output [31:0] data;
        integer timeout;
        begin
            @(posedge aclk);
            araddr <= addr;
            arprot <= 3'b000;
            arvalid <= 1;
            rready <= 1;
            
            // Wait for address ready with timeout
            timeout = 0;
            while (!arready && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            @(posedge aclk);
            arvalid <= 0;
            
            // Wait for data valid with timeout
            timeout = 0;
            while (!rvalid && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            data = rdata;
            @(posedge aclk);
            rready <= 0;
            @(posedge aclk);
        end
    endtask

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

    // Load weight row via AXI
    task load_weight;
        input [1:0] layer;
        input [3:0] row;
        input [53:0] weight;
        reg [31:0] ctrl;
        begin
            // Write weight data first
            axi_write(ADDR_WEIGHT_LO, weight[31:0]);
            axi_write(ADDR_WEIGHT_HI, {10'd0, weight[53:32]});
            
            // Write control: LOAD_EN=1, layer in [5:4], row in [11:8]
            // Format: [11:8]=row, [5:4]=layer, [1]=LOAD_EN
            ctrl = 32'd0;
            ctrl[1] = 1'b1;           // LOAD_EN
            ctrl[5:4] = layer;        // Layer
            ctrl[11:8] = row;         // Row
            axi_write(ADDR_CTRL, ctrl);
            
            // Wait for load done
            repeat(5) @(posedge aclk);
        end
    endtask

    // Run inference via AXI
    task run_inference;
        input [53:0] input_vec;
        output signed [2:0] result;
        reg [31:0] status;
        reg [31:0] result_reg;
        integer timeout;
        begin
            // Write input
            axi_write(ADDR_INPUT_LO, input_vec[31:0]);
            axi_write(ADDR_INPUT_HI, {10'd0, input_vec[53:32]});
            
            // Start inference
            axi_write(ADDR_CTRL, 32'h0000_0001);  // START=1
            
            // Poll status until VALID with timeout
            status = 0;
            timeout = 0;
            while (!(status & 32'h2) && timeout < 200) begin  // bit[1] = VALID
                axi_read(ADDR_STATUS, status);
                timeout = timeout + 1;
            end
            
            // Read result
            axi_read(ADDR_RESULT, result_reg);
            result = result_reg[2:0];
        end
    endtask

    // Main test
    initial begin
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("       AXI-LITE BITNET ACCELERATOR TESTBENCH");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");

        // Initialize
        aresetn = 0;
        awaddr = 0; awprot = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0;
        araddr = 0; arprot = 0; arvalid = 0;
        rready = 0;
        
        // Reset
        repeat(10) @(posedge aclk);
        aresetn = 1;
        repeat(5) @(posedge aclk);

        // ═══════════════════════════════════════════════════════════════
        // TEST 1: Read VERSION register
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 1: Read VERSION register");
        test_num = test_num + 1;
        axi_read(ADDR_VERSION, read_data);
        if (read_data == 32'h0001_0000) begin
            pass_count = pass_count + 1;
            $display("  [PASS] VERSION = 0x%08X (v1.0)", read_data);
        end else begin
            fail_count = fail_count + 1;
            $display("  [FAIL] VERSION = 0x%08X, expected 0x00010000", read_data);
        end

        // ═══════════════════════════════════════════════════════════════
        // TEST 2: Read PHOENIX register
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 2: Read PHOENIX register");
        test_num = test_num + 1;
        axi_read(ADDR_PHOENIX, read_data);
        if (read_data == 32'd999) begin
            pass_count = pass_count + 1;
            $display("  [PASS] PHOENIX = %0d", read_data);
        end else begin
            fail_count = fail_count + 1;
            $display("  [FAIL] PHOENIX = %0d, expected 999", read_data);
        end

        // ═══════════════════════════════════════════════════════════════
        // TEST 3: Load weights and run inference
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 3: Load weights (all +1)");
        
        // Load Layer 1 weights (9 rows)
        begin
            integer i;
            for (i = 0; i < 9; i = i + 1) begin
                load_weight(2'd0, i[3:0], all_trit27(TRIT_P));
            end
        end
        
        // Load Layer 2 weights (3 rows)
        begin
            integer i;
            for (i = 0; i < 3; i = i + 1) begin
                load_weight(2'd1, i[3:0], {36'd0, all_trit9(TRIT_P)});
            end
        end
        
        // Load Layer 3 weights (1 row)
        load_weight(2'd2, 4'd0, {48'd0, all_trit3(TRIT_P)});
        
        $display("  Weights loaded.");

        // ═══════════════════════════════════════════════════════════════
        // TEST 4: Run inference with all +1 input
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 4: Inference (all +1 input)");
        test_num = test_num + 1;
        begin
            reg signed [2:0] result;
            run_inference(all_trit27(TRIT_P), result);
            if (result == 3'sd3) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Result = %0d (expected +3)", result);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Result = %0d, expected +3", result);
            end
        end

        // ═══════════════════════════════════════════════════════════════
        // TEST 5: Run inference with all -1 input
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 5: Inference (all -1 input)");
        test_num = test_num + 1;
        begin
            reg signed [2:0] result;
            run_inference(all_trit27(TRIT_N), result);
            if (result == -3'sd3) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Result = %0d (expected -3)", result);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Result = %0d, expected -3", result);
            end
        end

        // ═══════════════════════════════════════════════════════════════
        // TEST 6: Run inference with all 0 input
        // ═══════════════════════════════════════════════════════════════
        $display("TEST 6: Inference (all 0 input)");
        test_num = test_num + 1;
        begin
            reg signed [2:0] result;
            run_inference(all_trit27(TRIT_Z), result);
            if (result == 3'sd0) begin
                pass_count = pass_count + 1;
                $display("  [PASS] Result = %0d (expected 0)", result);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] Result = %0d, expected 0", result);
            end
        end

        // ═══════════════════════════════════════════════════════════════
        // SUMMARY
        // ═══════════════════════════════════════════════════════════════
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("                         SUMMARY");
        $display("═══════════════════════════════════════════════════════════════");
        $display("");
        $display("  Total tests: %0d", test_num);
        $display("  PASSED:      %0d", pass_count);
        $display("  FAILED:      %0d", fail_count);
        $display("");

        if (fail_count == 0) begin
            $display("  ✓ ALL TESTS PASSED - AXI-Lite Interface VERIFIED");
            $display("");
            $display("  CPU Integration Ready!");
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
