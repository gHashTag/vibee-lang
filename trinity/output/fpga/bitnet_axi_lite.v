// ═══════════════════════════════════════════════════════════════════════════════
// bitnet_axi_lite v1.0.0 - AXI-Lite Interface for BitNet Accelerator
// ═══════════════════════════════════════════════════════════════════════════════
//
// AXI4-Lite slave interface for CPU/SoC integration
// Enables runtime weight loading and inference control
//
// Register Map:
// 0x00 CTRL      - Control (START, LOAD_EN, LOAD_LAYER, LOAD_ROW)
// 0x04 STATUS    - Status (READY, VALID, BUSY, LOAD_DONE)
// 0x08 INPUT_LO  - Input vector [31:0]
// 0x0C INPUT_HI  - Input vector [53:32]
// 0x10 WEIGHT_LO - Weight data [31:0]
// 0x14 WEIGHT_HI - Weight data [53:32]
// 0x18 THRESHOLD - L1/L2 thresholds
// 0x1C RESULT    - Inference result
// 0x20 VERSION   - IP version
// 0x24 PHOENIX   - Sacred constant (999)
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module bitnet_axi_lite #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6
)(
    // AXI-Lite Clock and Reset
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    
    // AXI-Lite Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    
    // AXI-Lite Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    
    // AXI-Lite Write Response Channel
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    
    // AXI-Lite Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    
    // AXI-Lite Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY
);

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════
    localparam VERSION = 32'h0001_0000;  // v1.0
    localparam PHOENIX = 32'd999;
    
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

    // ═══════════════════════════════════════════════════════════════════════════
    // AXI-LITE SIGNALS
    // ═══════════════════════════════════════════════════════════════════════════
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // ═══════════════════════════════════════════════════════════════════════════
    // REGISTERS
    // ═══════════════════════════════════════════════════════════════════════════
    reg [31:0] reg_ctrl;
    reg [31:0] reg_input_lo;
    reg [31:0] reg_input_hi;
    reg [31:0] reg_weight_lo;
    reg [31:0] reg_weight_hi;
    reg [31:0] reg_threshold;
    
    // Control bits
    wire ctrl_start     = reg_ctrl[0];
    wire ctrl_load_en   = reg_ctrl[1];
    wire [1:0] ctrl_load_layer = reg_ctrl[5:4];
    wire [3:0] ctrl_load_row   = reg_ctrl[11:8];
    
    // Thresholds
    wire signed [5:0] threshold_l1 = reg_threshold[5:0];
    wire signed [4:0] threshold_l2 = reg_threshold[12:8];

    // ═══════════════════════════════════════════════════════════════════════════
    // BITNET ENGINE INTERFACE
    // ═══════════════════════════════════════════════════════════════════════════
    wire [53:0] input_vec = {reg_input_hi[21:0], reg_input_lo};
    wire [53:0] weight_data = {reg_weight_hi[21:0], reg_weight_lo};
    
    wire engine_ready;
    wire engine_valid;
    wire signed [2:0] engine_result;
    wire engine_load_done;
    
    reg start_pulse;
    reg load_pulse;
    
    // Instantiate hybrid inference engine
    bitnet_hybrid_inference engine (
        .clk(S_AXI_ACLK),
        .rst_n(S_AXI_ARESETN),
        .load_weight(load_pulse),
        .load_layer(ctrl_load_layer),
        .load_row(ctrl_load_row),
        .load_data(weight_data),
        .load_done(engine_load_done),
        .infer_start(start_pulse),
        .input_vec(input_vec),
        .threshold_l1(threshold_l1),
        .threshold_l2(threshold_l2),
        .result(engine_result),
        .result_valid(engine_valid),
        .ready(engine_ready)
    );
    
    // Status register
    wire [31:0] reg_status = {28'd0, engine_load_done, ~engine_ready, engine_valid, engine_ready};
    
    // Result register
    wire [31:0] reg_result = {{29{engine_result[2]}}, engine_result};  // Sign extend

    // ═══════════════════════════════════════════════════════════════════════════
    // AXI-LITE WRITE LOGIC
    // ═══════════════════════════════════════════════════════════════════════════
    
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    
    // Write address ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awready <= 1'b1;
                axi_awaddr <= S_AXI_AWADDR;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end
    
    // Write data ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_wready <= 1'b0;
        else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
            axi_wready <= 1'b1;
        else
            axi_wready <= 1'b0;
    end
    
    // Write response
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b00;
        end else begin
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b00;  // OKAY
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end
    
    // Register writes
    wire wr_en = axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID;
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            reg_ctrl <= 32'd0;
            reg_input_lo <= 32'd0;
            reg_input_hi <= 32'd0;
            reg_weight_lo <= 32'd0;
            reg_weight_hi <= 32'd0;
            reg_threshold <= 32'h0000_0205;  // Default: L1=5, L2=2
            start_pulse <= 1'b0;
            load_pulse <= 1'b0;
        end else begin
            // Auto-clear pulses
            start_pulse <= 1'b0;
            load_pulse <= 1'b0;
            
            if (wr_en) begin
                case (axi_awaddr[5:0])
                    ADDR_CTRL: begin
                        reg_ctrl <= S_AXI_WDATA;
                        if (S_AXI_WDATA[0]) start_pulse <= 1'b1;
                        if (S_AXI_WDATA[1]) load_pulse <= 1'b1;
                    end
                    ADDR_INPUT_LO:  reg_input_lo <= S_AXI_WDATA;
                    ADDR_INPUT_HI:  reg_input_hi <= S_AXI_WDATA;
                    ADDR_WEIGHT_LO: reg_weight_lo <= S_AXI_WDATA;
                    ADDR_WEIGHT_HI: reg_weight_hi <= S_AXI_WDATA;
                    ADDR_THRESHOLD: reg_threshold <= S_AXI_WDATA;
                endcase
            end
            
            // Auto-clear START and LOAD_EN bits
            if (start_pulse) reg_ctrl[0] <= 1'b0;
            if (load_pulse) reg_ctrl[1] <= 1'b0;
        end
    end

    // ═══════════════════════════════════════════════════════════════════════════
    // AXI-LITE READ LOGIC
    // ═══════════════════════════════════════════════════════════════════════════
    
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;
    
    // Read address ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end
    
    // Read data valid
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp <= 2'b00;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b00;  // OKAY
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end
    
    // Read data mux
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rdata <= 32'd0;
        end else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            case (axi_araddr[5:0])
                ADDR_CTRL:      axi_rdata <= reg_ctrl;
                ADDR_STATUS:    axi_rdata <= reg_status;
                ADDR_INPUT_LO:  axi_rdata <= reg_input_lo;
                ADDR_INPUT_HI:  axi_rdata <= reg_input_hi;
                ADDR_WEIGHT_LO: axi_rdata <= reg_weight_lo;
                ADDR_WEIGHT_HI: axi_rdata <= reg_weight_hi;
                ADDR_THRESHOLD: axi_rdata <= reg_threshold;
                ADDR_RESULT:    axi_rdata <= reg_result;
                ADDR_VERSION:   axi_rdata <= VERSION;
                ADDR_PHOENIX:   axi_rdata <= PHOENIX;
                default:        axi_rdata <= 32'hDEAD_BEEF;
            endcase
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-LEVEL WRAPPER with AXI-Lite
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_accelerator_top #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6
)(
    // System
    input  wire aclk,
    input  wire aresetn,
    
    // AXI-Lite Slave Interface
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [2:0]                      s_axi_awprot,
    input  wire                            s_axi_awvalid,
    output wire                            s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                            s_axi_wvalid,
    output wire                            s_axi_wready,
    output wire [1:0]                      s_axi_bresp,
    output wire                            s_axi_bvalid,
    input  wire                            s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [2:0]                      s_axi_arprot,
    input  wire                            s_axi_arvalid,
    output wire                            s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                      s_axi_rresp,
    output wire                            s_axi_rvalid,
    input  wire                            s_axi_rready
);

    bitnet_axi_lite #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) axi_slave (
        .S_AXI_ACLK(aclk),
        .S_AXI_ARESETN(aresetn),
        .S_AXI_AWADDR(s_axi_awaddr),
        .S_AXI_AWPROT(s_axi_awprot),
        .S_AXI_AWVALID(s_axi_awvalid),
        .S_AXI_AWREADY(s_axi_awready),
        .S_AXI_WDATA(s_axi_wdata),
        .S_AXI_WSTRB(s_axi_wstrb),
        .S_AXI_WVALID(s_axi_wvalid),
        .S_AXI_WREADY(s_axi_wready),
        .S_AXI_BRESP(s_axi_bresp),
        .S_AXI_BVALID(s_axi_bvalid),
        .S_AXI_BREADY(s_axi_bready),
        .S_AXI_ARADDR(s_axi_araddr),
        .S_AXI_ARPROT(s_axi_arprot),
        .S_AXI_ARVALID(s_axi_arvalid),
        .S_AXI_ARREADY(s_axi_arready),
        .S_AXI_RDATA(s_axi_rdata),
        .S_AXI_RRESP(s_axi_rresp),
        .S_AXI_RVALID(s_axi_rvalid),
        .S_AXI_RREADY(s_axi_rready)
    );

endmodule
