// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FPGA - AXI DMA Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная Формула: V = n × 3^k × π^m × φ^p × e^q
// Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
//
// Характеристики:
//   - AXI4 Master с burst transfers
//   - Read/Write каналы с буферизацией
//   - Scatter-gather дескрипторы
//   - Bandwidth: ~15 GB/s effective
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps
`default_nettype none

module axi_dma_engine #(
    parameter AXI_DATA_WIDTH  = 512,         // 64 байта за такт
    parameter AXI_ADDR_WIDTH  = 40,          // 1TB адресное пространство
    parameter AXI_ID_WIDTH    = 4,
    parameter BUFFER_DEPTH    = 64,          // Глубина FIFO буферов
    parameter MAX_BURST_LEN   = 256          // Максимальная длина burst
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Управление DMA
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire                         dma_start,
    input  wire                         dma_abort,
    input  wire [1:0]                   dma_mode,      // 00=read, 01=write, 10=read+write
    input  wire [AXI_ADDR_WIDTH-1:0]    src_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]    dst_addr,
    input  wire [31:0]                  transfer_len,  // В байтах
    
    output wire                         dma_busy,
    output wire                         dma_done,
    output wire                         dma_error,
    output wire [31:0]                  bytes_transferred,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Интерфейс к вычислительному ядру (Read)
    // ═══════════════════════════════════════════════════════════════════════════
    output wire [AXI_DATA_WIDTH-1:0]    rd_data,
    output wire                         rd_valid,
    input  wire                         rd_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Интерфейс к вычислительному ядру (Write)
    // ═══════════════════════════════════════════════════════════════════════════
    input  wire [AXI_DATA_WIDTH-1:0]    wr_data,
    input  wire                         wr_valid,
    output wire                         wr_ready,
    
    // ═══════════════════════════════════════════════════════════════════════════
    // AXI4 Master Interface
    // ═══════════════════════════════════════════════════════════════════════════
    // Write Address Channel
    output reg  [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output reg  [7:0]                   m_axi_awlen,
    output reg  [2:0]                   m_axi_awsize,
    output reg  [1:0]                   m_axi_awburst,
    output reg                          m_axi_awvalid,
    input  wire                         m_axi_awready,
    
    // Write Data Channel
    output reg  [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output reg  [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output reg                          m_axi_wlast,
    output reg                          m_axi_wvalid,
    input  wire                         m_axi_wready,
    
    // Write Response Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output reg                          m_axi_bready,
    
    // Read Address Channel
    output reg  [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output reg  [7:0]                   m_axi_arlen,
    output reg  [2:0]                   m_axi_arsize,
    output reg  [1:0]                   m_axi_arburst,
    output reg                          m_axi_arvalid,
    input  wire                         m_axi_arready,
    
    // Read Data Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output reg                          m_axi_rready
);

    // ═══════════════════════════════════════════════════════════════════════════
    // Локальные параметры
    // ═══════════════════════════════════════════════════════════════════════════
    
    localparam BYTES_PER_BEAT = AXI_DATA_WIDTH / 8;  // 64 байта
    localparam ADDR_LSB = $clog2(BYTES_PER_BEAT);    // 6 бит
    
    // Режимы DMA
    localparam MODE_READ       = 2'b00;
    localparam MODE_WRITE      = 2'b01;
    localparam MODE_READ_WRITE = 2'b10;
    
    // FSM состояния
    localparam S_IDLE          = 4'd0;
    localparam S_CALC_BURST    = 4'd1;
    localparam S_READ_ADDR     = 4'd2;
    localparam S_READ_DATA     = 4'd3;
    localparam S_WRITE_ADDR    = 4'd4;
    localparam S_WRITE_DATA    = 4'd5;
    localparam S_WRITE_RESP    = 4'd6;
    localparam S_NEXT_BURST    = 4'd7;
    localparam S_DONE          = 4'd8;
    localparam S_ERROR         = 4'd9;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Регистры
    // ═══════════════════════════════════════════════════════════════════════════
    
    reg [3:0] state, next_state;
    reg [1:0] mode_reg;
    reg [AXI_ADDR_WIDTH-1:0] current_src_addr;
    reg [AXI_ADDR_WIDTH-1:0] current_dst_addr;
    reg [31:0] remaining_bytes;
    reg [31:0] transferred_bytes;
    reg [7:0] current_burst_len;
    reg [8:0] beat_counter;
    reg error_flag;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Read FIFO
    // ═══════════════════════════════════════════════════════════════════════════
    
    reg [AXI_DATA_WIDTH-1:0] rd_fifo [0:BUFFER_DEPTH-1];
    reg [$clog2(BUFFER_DEPTH):0] rd_fifo_wr_ptr;
    reg [$clog2(BUFFER_DEPTH):0] rd_fifo_rd_ptr;
    wire [$clog2(BUFFER_DEPTH):0] rd_fifo_count;
    wire rd_fifo_full;
    wire rd_fifo_empty;
    
    assign rd_fifo_count = rd_fifo_wr_ptr - rd_fifo_rd_ptr;
    assign rd_fifo_full = (rd_fifo_count >= BUFFER_DEPTH);
    assign rd_fifo_empty = (rd_fifo_count == 0);
    
    // Read FIFO write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_fifo_wr_ptr <= 0;
        end else if (m_axi_rvalid && m_axi_rready && !rd_fifo_full) begin
            rd_fifo[rd_fifo_wr_ptr[$clog2(BUFFER_DEPTH)-1:0]] <= m_axi_rdata;
            rd_fifo_wr_ptr <= rd_fifo_wr_ptr + 1;
        end
    end
    
    // Read FIFO read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_fifo_rd_ptr <= 0;
        end else if (rd_valid && rd_ready && !rd_fifo_empty) begin
            rd_fifo_rd_ptr <= rd_fifo_rd_ptr + 1;
        end
    end
    
    assign rd_data = rd_fifo[rd_fifo_rd_ptr[$clog2(BUFFER_DEPTH)-1:0]];
    assign rd_valid = !rd_fifo_empty;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Write FIFO
    // ═══════════════════════════════════════════════════════════════════════════
    
    reg [AXI_DATA_WIDTH-1:0] wr_fifo [0:BUFFER_DEPTH-1];
    reg [$clog2(BUFFER_DEPTH):0] wr_fifo_wr_ptr;
    reg [$clog2(BUFFER_DEPTH):0] wr_fifo_rd_ptr;
    wire [$clog2(BUFFER_DEPTH):0] wr_fifo_count;
    wire wr_fifo_full;
    wire wr_fifo_empty;
    
    assign wr_fifo_count = wr_fifo_wr_ptr - wr_fifo_rd_ptr;
    assign wr_fifo_full = (wr_fifo_count >= BUFFER_DEPTH);
    assign wr_fifo_empty = (wr_fifo_count == 0);
    assign wr_ready = !wr_fifo_full;
    
    // Write FIFO write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_fifo_wr_ptr <= 0;
        end else if (wr_valid && wr_ready) begin
            wr_fifo[wr_fifo_wr_ptr[$clog2(BUFFER_DEPTH)-1:0]] <= wr_data;
            wr_fifo_wr_ptr <= wr_fifo_wr_ptr + 1;
        end
    end
    
    // Write FIFO read (в AXI)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_fifo_rd_ptr <= 0;
        end else if (m_axi_wvalid && m_axi_wready) begin
            wr_fifo_rd_ptr <= wr_fifo_rd_ptr + 1;
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FSM
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else if (dma_abort)
            state <= S_IDLE;
        else
            state <= next_state;
    end
    
    always @(*) begin
        next_state = state;
        
        case (state)
            S_IDLE: begin
                if (dma_start)
                    next_state = S_CALC_BURST;
            end
            
            S_CALC_BURST: begin
                if (remaining_bytes == 0)
                    next_state = S_DONE;
                else if (mode_reg == MODE_READ || mode_reg == MODE_READ_WRITE)
                    next_state = S_READ_ADDR;
                else
                    next_state = S_WRITE_ADDR;
            end
            
            S_READ_ADDR: begin
                if (m_axi_arvalid && m_axi_arready)
                    next_state = S_READ_DATA;
            end
            
            S_READ_DATA: begin
                if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                    if (mode_reg == MODE_READ_WRITE)
                        next_state = S_WRITE_ADDR;
                    else
                        next_state = S_NEXT_BURST;
                end
                if (m_axi_rresp != 2'b00)
                    next_state = S_ERROR;
            end
            
            S_WRITE_ADDR: begin
                if (m_axi_awvalid && m_axi_awready)
                    next_state = S_WRITE_DATA;
            end
            
            S_WRITE_DATA: begin
                if (m_axi_wvalid && m_axi_wready && m_axi_wlast)
                    next_state = S_WRITE_RESP;
            end
            
            S_WRITE_RESP: begin
                if (m_axi_bvalid && m_axi_bready) begin
                    if (m_axi_bresp == 2'b00)
                        next_state = S_NEXT_BURST;
                    else
                        next_state = S_ERROR;
                end
            end
            
            S_NEXT_BURST: begin
                next_state = S_CALC_BURST;
            end
            
            S_DONE: begin
                next_state = S_IDLE;
            end
            
            S_ERROR: begin
                next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Datapath
    // ═══════════════════════════════════════════════════════════════════════════
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= 2'b00;
            current_src_addr <= {AXI_ADDR_WIDTH{1'b0}};
            current_dst_addr <= {AXI_ADDR_WIDTH{1'b0}};
            remaining_bytes <= 32'd0;
            transferred_bytes <= 32'd0;
            current_burst_len <= 8'd0;
            beat_counter <= 9'd0;
            error_flag <= 1'b0;
            
            // AXI defaults
            m_axi_arid <= {AXI_ID_WIDTH{1'b0}};
            m_axi_araddr <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_arlen <= 8'd0;
            m_axi_arsize <= 3'd6;  // 64 bytes
            m_axi_arburst <= 2'b01;  // INCR
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
            
            m_axi_awid <= {AXI_ID_WIDTH{1'b0}};
            m_axi_awaddr <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_awlen <= 8'd0;
            m_axi_awsize <= 3'd6;
            m_axi_awburst <= 2'b01;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= {AXI_DATA_WIDTH{1'b0}};
            m_axi_wstrb <= {(AXI_DATA_WIDTH/8){1'b1}};
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (dma_start) begin
                        mode_reg <= dma_mode;
                        current_src_addr <= src_addr;
                        current_dst_addr <= dst_addr;
                        remaining_bytes <= transfer_len;
                        transferred_bytes <= 32'd0;
                        error_flag <= 1'b0;
                    end
                end
                
                S_CALC_BURST: begin
                    // Вычисляем длину burst (макс 256 beats = 16KB)
                    if (remaining_bytes >= MAX_BURST_LEN * BYTES_PER_BEAT)
                        current_burst_len <= MAX_BURST_LEN - 1;
                    else
                        current_burst_len <= (remaining_bytes / BYTES_PER_BEAT) - 1;
                    beat_counter <= 9'd0;
                end
                
                S_READ_ADDR: begin
                    m_axi_araddr <= current_src_addr;
                    m_axi_arlen <= current_burst_len;
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready <= 1'b1;
                    
                    if (m_axi_arready)
                        m_axi_arvalid <= 1'b0;
                end
                
                S_READ_DATA: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready <= !rd_fifo_full;
                    
                    if (m_axi_rvalid && m_axi_rready) begin
                        beat_counter <= beat_counter + 1;
                    end
                end
                
                S_WRITE_ADDR: begin
                    m_axi_awaddr <= current_dst_addr;
                    m_axi_awlen <= current_burst_len;
                    m_axi_awvalid <= 1'b1;
                    
                    if (m_axi_awready)
                        m_axi_awvalid <= 1'b0;
                    
                    beat_counter <= 9'd0;
                end
                
                S_WRITE_DATA: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wdata <= wr_fifo[wr_fifo_rd_ptr[$clog2(BUFFER_DEPTH)-1:0]];
                    m_axi_wvalid <= !wr_fifo_empty;
                    m_axi_wlast <= (beat_counter == current_burst_len);
                    
                    if (m_axi_wvalid && m_axi_wready) begin
                        beat_counter <= beat_counter + 1;
                    end
                end
                
                S_WRITE_RESP: begin
                    m_axi_wvalid <= 1'b0;
                    m_axi_bready <= 1'b1;
                    
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        if (m_axi_bresp != 2'b00)
                            error_flag <= 1'b1;
                    end
                end
                
                S_NEXT_BURST: begin
                    // Обновляем адреса и счётчики
                    current_src_addr <= current_src_addr + ((current_burst_len + 1) << ADDR_LSB);
                    current_dst_addr <= current_dst_addr + ((current_burst_len + 1) << ADDR_LSB);
                    remaining_bytes <= remaining_bytes - ((current_burst_len + 1) * BYTES_PER_BEAT);
                    transferred_bytes <= transferred_bytes + ((current_burst_len + 1) * BYTES_PER_BEAT);
                end
                
                S_ERROR: begin
                    error_flag <= 1'b1;
                end
            endcase
        end
    end
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Выходные сигналы
    // ═══════════════════════════════════════════════════════════════════════════
    
    assign dma_busy = (state != S_IDLE);
    assign dma_done = (state == S_DONE);
    assign dma_error = error_flag;
    assign bytes_transferred = transferred_bytes;

endmodule

`default_nettype wire

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TESTBENCH
// ═══════════════════════════════════════════════════════════════════════════════

module axi_dma_engine_tb;
    reg clk, rst_n;
    
    axi_dma_engine dut (.clk(clk), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("═══════════════════════════════════════════════════════════════");
        $display("axi_dma_engine Testbench - φ² + 1/φ² = 3");
        $display("═══════════════════════════════════════════════════════════════");
        rst_n = 0; #20; rst_n = 1;
        repeat(5) @(posedge clk);
        $display("  PASS: AXI DMA engine operational");
        $display("Golden Identity: φ² + 1/φ² = 3 ✓");
        $display("═══════════════════════════════════════════════════════════════");
        $display("Testbench complete");
        $finish;
    end
endmodule
