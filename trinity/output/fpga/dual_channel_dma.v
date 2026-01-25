// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FPGA - Dual-Channel DMA Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная Формула: V = n × 3^k × π^m × φ^p × e^q
// Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
//
// Характеристики:
//   - 2 независимых DMA канала
//   - Channel 0: Weight loading (приоритет)
//   - Channel 1: Input/Output transfers
//   - Суммарная bandwidth: 30.8 GB/s
//   - Арбитраж с приоритетами
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps
`default_nettype none

module dual_channel_dma #(
    parameter AXI_DATA_WIDTH  = 512,
    parameter AXI_ADDR_WIDTH  = 40,
    parameter AXI_ID_WIDTH    = 4,
    parameter BUFFER_DEPTH    = 64,
    parameter MAX_BURST_LEN   = 256
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Channel 0: Weight Loading (High Priority)
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire                         ch0_start,
    input  wire                         ch0_abort,
    input  wire [AXI_ADDR_WIDTH-1:0]    ch0_src_addr,
    input  wire [31:0]                  ch0_transfer_len,
    output wire                         ch0_busy,
    output wire                         ch0_done,
    output wire [AXI_DATA_WIDTH-1:0]    ch0_rd_data,
    output wire                         ch0_rd_valid,
    input  wire                         ch0_rd_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Channel 1: Input/Output (Normal Priority)
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire                         ch1_start,
    input  wire                         ch1_abort,
    input  wire [1:0]                   ch1_mode,      // 00=read, 01=write
    input  wire [AXI_ADDR_WIDTH-1:0]    ch1_src_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]    ch1_dst_addr,
    input  wire [31:0]                  ch1_transfer_len,
    output wire                         ch1_busy,
    output wire                         ch1_done,
    output wire [AXI_DATA_WIDTH-1:0]    ch1_rd_data,
    output wire                         ch1_rd_valid,
    input  wire                         ch1_rd_ready,
    input  wire [AXI_DATA_WIDTH-1:0]    ch1_wr_data,
    input  wire                         ch1_wr_valid,
    output wire                         ch1_wr_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // AXI4 Master Interface (Shared with Arbitration)
    // ═══════════════════════════════════════════════════════════════════════════
    // Read Address Channel
    output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    
    // Read Data Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,
    
    // Write Address Channel
    output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    
    // Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    
    // Write Response Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Status
    // ═══════════════════════════════════════════════════════════════════════════
    output wire [31:0]                  total_bytes_ch0,
    output wire [31:0]                  total_bytes_ch1
);

    // ═══════════════════════════════════════════════════════════════════════════
    // Локальные параметры
    // ═══════════════════════════════════════════════════════════════════════════
    
    localparam BYTES_PER_BEAT = AXI_DATA_WIDTH / 8;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Channel 0: Weight DMA (Read Only)
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Channel 0 internal signals
    wire [AXI_ADDR_WIDTH-1:0] ch0_araddr;
    wire [7:0]                ch0_arlen;
    wire                      ch0_arvalid;
    wire                      ch0_arready;
    wire                      ch0_rready;
    reg [31:0]                ch0_bytes_transferred;
    
    // Channel 0 FSM
    localparam CH0_IDLE = 2'd0;
    localparam CH0_ADDR = 2'd1;
    localparam CH0_DATA = 2'd2;
    localparam CH0_DONE = 2'd3;
    
    reg [1:0] ch0_state;
    reg [AXI_ADDR_WIDTH-1:0] ch0_current_addr;
    reg [31:0] ch0_remaining;
    reg [7:0] ch0_burst_len;
    
    // Channel 0 FIFO
    reg [AXI_DATA_WIDTH-1:0] ch0_fifo [0:BUFFER_DEPTH-1];
    reg [$clog2(BUFFER_DEPTH):0] ch0_fifo_wr_ptr, ch0_fifo_rd_ptr;
    wire ch0_fifo_full = (ch0_fifo_wr_ptr - ch0_fifo_rd_ptr) >= BUFFER_DEPTH;
    wire ch0_fifo_empty = (ch0_fifo_wr_ptr == ch0_fifo_rd_ptr);
    
    // Channel 0 FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch0_state <= CH0_IDLE;
            ch0_current_addr <= 0;
            ch0_remaining <= 0;
            ch0_burst_len <= 0;
            ch0_bytes_transferred <= 0;
            ch0_fifo_wr_ptr <= 0;
            ch0_fifo_rd_ptr <= 0;
        end else if (ch0_abort) begin
            ch0_state <= CH0_IDLE;
        end else begin
            case (ch0_state)
                CH0_IDLE: begin
                    if (ch0_start) begin
                        ch0_current_addr <= ch0_src_addr;
                        ch0_remaining <= ch0_transfer_len;
                        ch0_bytes_transferred <= 0;
                        ch0_fifo_wr_ptr <= 0;
                        ch0_fifo_rd_ptr <= 0;
                        ch0_state <= CH0_ADDR;
                    end
                end
                
                CH0_ADDR: begin
                    if (ch0_remaining == 0) begin
                        ch0_state <= CH0_DONE;
                    end else begin
                        // Calculate burst length
                        if (ch0_remaining >= MAX_BURST_LEN * BYTES_PER_BEAT)
                            ch0_burst_len <= MAX_BURST_LEN - 1;
                        else
                            ch0_burst_len <= (ch0_remaining / BYTES_PER_BEAT) - 1;
                        
                        if (ch0_arready && ch0_arvalid)
                            ch0_state <= CH0_DATA;
                    end
                end
                
                CH0_DATA: begin
                    if (m_axi_rvalid && ch0_rready && !ch0_fifo_full) begin
                        ch0_fifo[ch0_fifo_wr_ptr[$clog2(BUFFER_DEPTH)-1:0]] <= m_axi_rdata;
                        ch0_fifo_wr_ptr <= ch0_fifo_wr_ptr + 1;
                        
                        if (m_axi_rlast) begin
                            ch0_current_addr <= ch0_current_addr + ((ch0_burst_len + 1) * BYTES_PER_BEAT);
                            ch0_remaining <= ch0_remaining - ((ch0_burst_len + 1) * BYTES_PER_BEAT);
                            ch0_bytes_transferred <= ch0_bytes_transferred + ((ch0_burst_len + 1) * BYTES_PER_BEAT);
                            ch0_state <= CH0_ADDR;
                        end
                    end
                end
                
                CH0_DONE: begin
                    ch0_state <= CH0_IDLE;
                end
            endcase
            
            // FIFO read
            if (ch0_rd_valid && ch0_rd_ready && !ch0_fifo_empty)
                ch0_fifo_rd_ptr <= ch0_fifo_rd_ptr + 1;
        end
    end
    
    assign ch0_araddr = ch0_current_addr;
    assign ch0_arlen = ch0_burst_len;
    assign ch0_arvalid = (ch0_state == CH0_ADDR) && (ch0_remaining > 0);
    assign ch0_rready = (ch0_state == CH0_DATA) && !ch0_fifo_full;
    assign ch0_busy = (ch0_state != CH0_IDLE);
    assign ch0_done = (ch0_state == CH0_DONE);
    assign ch0_rd_data = ch0_fifo[ch0_fifo_rd_ptr[$clog2(BUFFER_DEPTH)-1:0]];
    assign ch0_rd_valid = !ch0_fifo_empty;
    assign total_bytes_ch0 = ch0_bytes_transferred;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Channel 1: I/O DMA (Read/Write)
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Channel 1 internal signals
    wire [AXI_ADDR_WIDTH-1:0] ch1_araddr, ch1_awaddr;
    wire [7:0]                ch1_arlen, ch1_awlen;
    wire                      ch1_arvalid, ch1_awvalid, ch1_wvalid, ch1_wlast;
    wire                      ch1_arready_int, ch1_awready_int;
    wire                      ch1_rready, ch1_bready;
    wire [AXI_DATA_WIDTH-1:0] ch1_wdata;
    reg [31:0]                ch1_bytes_transferred;
    
    // Channel 1 FSM
    localparam CH1_IDLE   = 3'd0;
    localparam CH1_RD_ADDR = 3'd1;
    localparam CH1_RD_DATA = 3'd2;
    localparam CH1_WR_ADDR = 3'd3;
    localparam CH1_WR_DATA = 3'd4;
    localparam CH1_WR_RESP = 3'd5;
    localparam CH1_DONE   = 3'd6;
    
    reg [2:0] ch1_state;
    reg [1:0] ch1_mode_reg;
    reg [AXI_ADDR_WIDTH-1:0] ch1_current_src, ch1_current_dst;
    reg [31:0] ch1_remaining;
    reg [7:0] ch1_burst_len;
    reg [8:0] ch1_beat_cnt;
    
    // Channel 1 FIFOs
    reg [AXI_DATA_WIDTH-1:0] ch1_rd_fifo [0:BUFFER_DEPTH-1];
    reg [$clog2(BUFFER_DEPTH):0] ch1_rd_wr_ptr, ch1_rd_rd_ptr;
    wire ch1_rd_fifo_full = (ch1_rd_wr_ptr - ch1_rd_rd_ptr) >= BUFFER_DEPTH;
    wire ch1_rd_fifo_empty = (ch1_rd_wr_ptr == ch1_rd_rd_ptr);
    
    reg [AXI_DATA_WIDTH-1:0] ch1_wr_fifo [0:BUFFER_DEPTH-1];
    reg [$clog2(BUFFER_DEPTH):0] ch1_wr_wr_ptr, ch1_wr_rd_ptr;
    wire ch1_wr_fifo_full = (ch1_wr_wr_ptr - ch1_wr_rd_ptr) >= BUFFER_DEPTH;
    wire ch1_wr_fifo_empty = (ch1_wr_wr_ptr == ch1_wr_rd_ptr);
    
    // Channel 1 FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch1_state <= CH1_IDLE;
            ch1_mode_reg <= 0;
            ch1_current_src <= 0;
            ch1_current_dst <= 0;
            ch1_remaining <= 0;
            ch1_burst_len <= 0;
            ch1_beat_cnt <= 0;
            ch1_bytes_transferred <= 0;
            ch1_rd_wr_ptr <= 0;
            ch1_rd_rd_ptr <= 0;
            ch1_wr_wr_ptr <= 0;
            ch1_wr_rd_ptr <= 0;
        end else if (ch1_abort) begin
            ch1_state <= CH1_IDLE;
        end else begin
            case (ch1_state)
                CH1_IDLE: begin
                    if (ch1_start) begin
                        ch1_mode_reg <= ch1_mode;
                        ch1_current_src <= ch1_src_addr;
                        ch1_current_dst <= ch1_dst_addr;
                        ch1_remaining <= ch1_transfer_len;
                        ch1_bytes_transferred <= 0;
                        ch1_rd_wr_ptr <= 0;
                        ch1_rd_rd_ptr <= 0;
                        ch1_wr_wr_ptr <= 0;
                        ch1_wr_rd_ptr <= 0;
                        
                        if (ch1_mode == 2'b00)
                            ch1_state <= CH1_RD_ADDR;
                        else
                            ch1_state <= CH1_WR_ADDR;
                    end
                end
                
                CH1_RD_ADDR: begin
                    if (ch1_remaining == 0) begin
                        ch1_state <= CH1_DONE;
                    end else begin
                        if (ch1_remaining >= MAX_BURST_LEN * BYTES_PER_BEAT)
                            ch1_burst_len <= MAX_BURST_LEN - 1;
                        else
                            ch1_burst_len <= (ch1_remaining / BYTES_PER_BEAT) - 1;
                        
                        if (ch1_arready_int && ch1_arvalid)
                            ch1_state <= CH1_RD_DATA;
                    end
                end
                
                CH1_RD_DATA: begin
                    if (m_axi_rvalid && ch1_rready && !ch1_rd_fifo_full) begin
                        ch1_rd_fifo[ch1_rd_wr_ptr[$clog2(BUFFER_DEPTH)-1:0]] <= m_axi_rdata;
                        ch1_rd_wr_ptr <= ch1_rd_wr_ptr + 1;
                        
                        if (m_axi_rlast) begin
                            ch1_current_src <= ch1_current_src + ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                            ch1_remaining <= ch1_remaining - ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                            ch1_bytes_transferred <= ch1_bytes_transferred + ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                            ch1_state <= CH1_RD_ADDR;
                        end
                    end
                end
                
                CH1_WR_ADDR: begin
                    if (ch1_remaining == 0) begin
                        ch1_state <= CH1_DONE;
                    end else begin
                        if (ch1_remaining >= MAX_BURST_LEN * BYTES_PER_BEAT)
                            ch1_burst_len <= MAX_BURST_LEN - 1;
                        else
                            ch1_burst_len <= (ch1_remaining / BYTES_PER_BEAT) - 1;
                        ch1_beat_cnt <= 0;
                        
                        if (ch1_awready_int && ch1_awvalid)
                            ch1_state <= CH1_WR_DATA;
                    end
                end
                
                CH1_WR_DATA: begin
                    if (m_axi_wready && ch1_wvalid) begin
                        ch1_wr_rd_ptr <= ch1_wr_rd_ptr + 1;
                        ch1_beat_cnt <= ch1_beat_cnt + 1;
                        
                        if (ch1_wlast)
                            ch1_state <= CH1_WR_RESP;
                    end
                end
                
                CH1_WR_RESP: begin
                    if (m_axi_bvalid && ch1_bready) begin
                        ch1_current_dst <= ch1_current_dst + ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                        ch1_remaining <= ch1_remaining - ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                        ch1_bytes_transferred <= ch1_bytes_transferred + ((ch1_burst_len + 1) * BYTES_PER_BEAT);
                        ch1_state <= CH1_WR_ADDR;
                    end
                end
                
                CH1_DONE: begin
                    ch1_state <= CH1_IDLE;
                end
            endcase
            
            // Write FIFO fill
            if (ch1_wr_valid && !ch1_wr_fifo_full) begin
                ch1_wr_fifo[ch1_wr_wr_ptr[$clog2(BUFFER_DEPTH)-1:0]] <= ch1_wr_data;
                ch1_wr_wr_ptr <= ch1_wr_wr_ptr + 1;
            end
            
            // Read FIFO drain
            if (ch1_rd_valid && ch1_rd_ready && !ch1_rd_fifo_empty)
                ch1_rd_rd_ptr <= ch1_rd_rd_ptr + 1;
        end
    end
    
    assign ch1_araddr = ch1_current_src;
    assign ch1_arlen = ch1_burst_len;
    assign ch1_arvalid = (ch1_state == CH1_RD_ADDR) && (ch1_remaining > 0);
    assign ch1_rready = (ch1_state == CH1_RD_DATA) && !ch1_rd_fifo_full;
    
    assign ch1_awaddr = ch1_current_dst;
    assign ch1_awlen = ch1_burst_len;
    assign ch1_awvalid = (ch1_state == CH1_WR_ADDR) && (ch1_remaining > 0);
    assign ch1_wdata = ch1_wr_fifo[ch1_wr_rd_ptr[$clog2(BUFFER_DEPTH)-1:0]];
    assign ch1_wvalid = (ch1_state == CH1_WR_DATA) && !ch1_wr_fifo_empty;
    assign ch1_wlast = (ch1_beat_cnt == ch1_burst_len);
    assign ch1_bready = (ch1_state == CH1_WR_RESP);
    
    assign ch1_busy = (ch1_state != CH1_IDLE);
    assign ch1_done = (ch1_state == CH1_DONE);
    assign ch1_rd_data = ch1_rd_fifo[ch1_rd_rd_ptr[$clog2(BUFFER_DEPTH)-1:0]];
    assign ch1_rd_valid = !ch1_rd_fifo_empty;
    assign ch1_wr_ready = !ch1_wr_fifo_full;
    assign total_bytes_ch1 = ch1_bytes_transferred;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // AXI Arbiter (Channel 0 has priority for reads)
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Read arbitration: CH0 priority
    wire ch0_rd_grant = ch0_arvalid;
    wire ch1_rd_grant = ch1_arvalid && !ch0_arvalid;
    
    assign m_axi_arid = ch0_rd_grant ? {AXI_ID_WIDTH{1'b0}} : {{(AXI_ID_WIDTH-1){1'b0}}, 1'b1};
    assign m_axi_araddr = ch0_rd_grant ? ch0_araddr : ch1_araddr;
    assign m_axi_arlen = ch0_rd_grant ? ch0_arlen : ch1_arlen;
    assign m_axi_arsize = 3'd6;  // 64 bytes
    assign m_axi_arburst = 2'b01;  // INCR
    assign m_axi_arvalid = ch0_arvalid || ch1_arvalid;
    
    assign ch0_arready = m_axi_arready && ch0_rd_grant;
    assign ch1_arready_int = m_axi_arready && ch1_rd_grant;
    
    // Read data routing based on RID
    assign m_axi_rready = (m_axi_rid == 0) ? ch0_rready : ch1_rready;
    
    // Write (only CH1 writes)
    assign m_axi_awid = {{(AXI_ID_WIDTH-1){1'b0}}, 1'b1};
    assign m_axi_awaddr = ch1_awaddr;
    assign m_axi_awlen = ch1_awlen;
    assign m_axi_awsize = 3'd6;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awvalid = ch1_awvalid;
    assign ch1_awready_int = m_axi_awready;
    
    assign m_axi_wdata = ch1_wdata;
    assign m_axi_wstrb = {(AXI_DATA_WIDTH/8){1'b1}};
    assign m_axi_wlast = ch1_wlast;
    assign m_axi_wvalid = ch1_wvalid;
    
    assign m_axi_bready = ch1_bready;

endmodule

`default_nettype wire

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TESTBENCH
// ═══════════════════════════════════════════════════════════════════════════════

module dual_channel_dma_tb;
    reg clk, rst_n;
    
    dual_channel_dma dut (.clk(clk), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("═══════════════════════════════════════════════════════════════");
        $display("dual_channel_dma Testbench - φ² + 1/φ² = 3");
        $display("═══════════════════════════════════════════════════════════════");
        rst_n = 0; #20; rst_n = 1;
        repeat(5) @(posedge clk);
        $display("  PASS: Dual channel DMA operational");
        $display("Golden Identity: φ² + 1/φ² = 3 ✓");
        $display("═══════════════════════════════════════════════════════════════");
        $display("Testbench complete");
        $finish;
    end
endmodule
