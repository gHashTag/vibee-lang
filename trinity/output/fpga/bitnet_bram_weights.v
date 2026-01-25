// ═══════════════════════════════════════════════════════════════════════════════
// bitnet_bram_weights v1.0.0 - BRAM-based Weight Storage for BitNet
// ═══════════════════════════════════════════════════════════════════════════════
//
// Stores weights in Block RAM instead of distributed RAM/registers
// Enables scaling to larger models (>10K weights)
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE DUAL-PORT BRAM (inferred by synthesis tools)
// ═══════════════════════════════════════════════════════════════════════════════
module simple_dual_port_bram #(
    parameter DATA_WIDTH = 54,      // Width of data
    parameter ADDR_WIDTH = 4,       // Address width (2^4 = 16 entries)
    parameter DEPTH = 16            // Number of entries
)(
    input  wire                    clk,
    
    // Write port
    input  wire                    wr_en,
    input  wire [ADDR_WIDTH-1:0]   wr_addr,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    
    // Read port
    input  wire                    rd_en,
    input  wire [ADDR_WIDTH-1:0]   rd_addr,
    output reg  [DATA_WIDTH-1:0]   rd_data
);

    // Memory array (will be inferred as BRAM)
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Write logic
    always @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
    // Read logic (synchronous read for BRAM)
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 1 WEIGHT BRAM - 9 rows × 54 bits (27 trits per row)
// ═══════════════════════════════════════════════════════════════════════════════
module layer1_weight_bram (
    input  wire        clk,
    
    // Write interface (for loading weights)
    input  wire        wr_en,
    input  wire [3:0]  wr_row,      // 0-8 (9 rows)
    input  wire [53:0] wr_data,     // 27 trits
    
    // Read interface (for inference)
    input  wire        rd_en,
    input  wire [3:0]  rd_row,
    output wire [53:0] rd_data
);

    simple_dual_port_bram #(
        .DATA_WIDTH(54),
        .ADDR_WIDTH(4),
        .DEPTH(9)
    ) bram (
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_row),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_row),
        .rd_data(rd_data)
    );

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 2 WEIGHT BRAM - 3 rows × 18 bits (9 trits per row)
// ═══════════════════════════════════════════════════════════════════════════════
module layer2_weight_bram (
    input  wire        clk,
    
    input  wire        wr_en,
    input  wire [1:0]  wr_row,      // 0-2 (3 rows)
    input  wire [17:0] wr_data,     // 9 trits
    
    input  wire        rd_en,
    input  wire [1:0]  rd_row,
    output wire [17:0] rd_data
);

    simple_dual_port_bram #(
        .DATA_WIDTH(18),
        .ADDR_WIDTH(2),
        .DEPTH(3)
    ) bram (
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_row),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_row),
        .rd_data(rd_data)
    );

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 3 WEIGHT REGISTER - 1 row × 6 bits (3 trits) - too small for BRAM
// ═══════════════════════════════════════════════════════════════════════════════
module layer3_weight_reg (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        wr_en,
    input  wire [5:0]  wr_data,     // 3 trits
    
    output reg  [5:0]  rd_data
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= 6'd0;
        else if (wr_en)
            rd_data <= wr_data;
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// WEIGHT CONTROLLER - Manages weight loading and fetching
// ═══════════════════════════════════════════════════════════════════════════════
module weight_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Weight loading interface
    input  wire        load_start,
    input  wire [1:0]  load_layer,      // 0=L1, 1=L2, 2=L3
    input  wire [3:0]  load_row,
    input  wire [53:0] load_data,       // Max width (L1)
    output reg         load_done,
    
    // Inference control
    input  wire        infer_start,
    output reg         weights_ready,
    
    // Weight outputs for inference
    output wire [53:0] l1_weight_row,
    output wire [17:0] l2_weight_row,
    output wire [5:0]  l3_weights,
    
    // Row selection for sequential inference
    input  wire [3:0]  l1_row_sel,
    input  wire [1:0]  l2_row_sel
);

    // State machine
    localparam IDLE = 2'd0;
    localparam LOADING = 2'd1;
    localparam READY = 2'd2;
    
    reg [1:0] state;
    
    // BRAM write enables
    reg l1_wr_en, l2_wr_en, l3_wr_en;
    
    // Layer 1 BRAM
    layer1_weight_bram l1_bram (
        .clk(clk),
        .wr_en(l1_wr_en),
        .wr_row(load_row),
        .wr_data(load_data[53:0]),
        .rd_en(1'b1),
        .rd_row(l1_row_sel),
        .rd_data(l1_weight_row)
    );
    
    // Layer 2 BRAM
    layer2_weight_bram l2_bram (
        .clk(clk),
        .wr_en(l2_wr_en),
        .wr_row(load_row[1:0]),
        .wr_data(load_data[17:0]),
        .rd_en(1'b1),
        .rd_row(l2_row_sel),
        .rd_data(l2_weight_row)
    );
    
    // Layer 3 register
    layer3_weight_reg l3_reg (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(l3_wr_en),
        .wr_data(load_data[5:0]),
        .rd_data(l3_weights)
    );
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_done <= 1'b0;
            weights_ready <= 1'b0;
            l1_wr_en <= 1'b0;
            l2_wr_en <= 1'b0;
            l3_wr_en <= 1'b0;
        end else begin
            load_done <= 1'b0;
            l1_wr_en <= 1'b0;
            l2_wr_en <= 1'b0;
            l3_wr_en <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (load_start) begin
                        state <= LOADING;
                        case (load_layer)
                            2'd0: l1_wr_en <= 1'b1;
                            2'd1: l2_wr_en <= 1'b1;
                            2'd2: l3_wr_en <= 1'b1;
                        endcase
                    end else if (infer_start) begin
                        state <= READY;
                        weights_ready <= 1'b1;
                    end
                end
                
                LOADING: begin
                    load_done <= 1'b1;
                    state <= IDLE;
                end
                
                READY: begin
                    weights_ready <= 1'b1;
                    if (!infer_start) begin
                        state <= IDLE;
                        weights_ready <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// BRAM-BASED INFERENCE ENGINE
// Sequential processing with BRAM weight fetching
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_bram_inference (
    input  wire        clk,
    input  wire        rst_n,
    
    // Weight loading interface
    input  wire        load_weight,
    input  wire [1:0]  load_layer,
    input  wire [3:0]  load_row,
    input  wire [53:0] load_data,
    output wire        load_done,
    
    // Inference interface
    input  wire        infer_start,
    input  wire [53:0] input_vec,
    input  wire signed [5:0] threshold_l1,
    input  wire signed [4:0] threshold_l2,
    
    output reg  signed [2:0] result,
    output reg         result_valid,
    output wire        ready
);

    // Trit encoding
    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // State machine
    localparam S_IDLE = 4'd0;
    localparam S_L1_FETCH = 4'd1;
    localparam S_L1_COMPUTE = 4'd2;
    localparam S_L1_NEXT = 4'd3;
    localparam S_L2_FETCH = 4'd4;
    localparam S_L2_COMPUTE = 4'd5;
    localparam S_L2_NEXT = 4'd6;
    localparam S_L3_COMPUTE = 4'd7;
    localparam S_DONE = 4'd8;
    
    reg [3:0] state;
    reg [3:0] neuron_idx;
    
    // Weight controller
    wire [53:0] l1_weight_row;
    wire [17:0] l2_weight_row;
    wire [5:0]  l3_weights;
    wire weights_ready;
    
    reg [3:0] l1_row_sel;
    reg [1:0] l2_row_sel;
    
    weight_controller wctrl (
        .clk(clk),
        .rst_n(rst_n),
        .load_start(load_weight),
        .load_layer(load_layer),
        .load_row(load_row),
        .load_data(load_data),
        .load_done(load_done),
        .infer_start(state != S_IDLE),
        .weights_ready(weights_ready),
        .l1_weight_row(l1_weight_row),
        .l2_weight_row(l2_weight_row),
        .l3_weights(l3_weights),
        .l1_row_sel(l1_row_sel),
        .l2_row_sel(l2_row_sel)
    );
    
    // Intermediate results
    reg [17:0] l1_output;  // 9 trits
    reg [5:0]  l2_output;  // 3 trits
    
    // Dot product results
    wire signed [5:0] l1_dot;
    wire signed [4:0] l2_dot;
    wire signed [2:0] l3_dot;
    
    // Layer 1 dot product (27 trits)
    trit27_dot_product_v2 l1_dp (
        .input_vec(input_vec),
        .weight_vec(l1_weight_row),
        .result(l1_dot)
    );
    
    // Layer 2 dot product (9 trits)
    trit9_dot_product l2_dp (
        .input_vec(l1_output),
        .weight_vec(l2_weight_row),
        .result(l2_dot)
    );
    
    // Layer 3 dot product (3 trits)
    trit3_dot_product l3_dp (
        .input_vec(l2_output),
        .weight_vec(l3_weights),
        .result(l3_dot)
    );
    
    // Activation functions
    wire [1:0] l1_act = (l1_dot > threshold_l1)  ? TRIT_P :
                        (l1_dot < -threshold_l1) ? TRIT_N : TRIT_Z;
    
    wire [1:0] l2_act = (l2_dot > $signed({1'b0, threshold_l2}))  ? TRIT_P :
                        (l2_dot < -$signed({1'b0, threshold_l2})) ? TRIT_N : TRIT_Z;
    
    assign ready = (state == S_IDLE);
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            neuron_idx <= 4'd0;
            l1_row_sel <= 4'd0;
            l2_row_sel <= 2'd0;
            l1_output <= 18'd0;
            l2_output <= 6'd0;
            result <= 3'sd0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (infer_start && !load_weight) begin
                        state <= S_L1_FETCH;
                        neuron_idx <= 4'd0;
                        l1_row_sel <= 4'd0;
                        l1_output <= 18'd0;
                    end
                end
                
                // Layer 1: Process 9 neurons sequentially
                S_L1_FETCH: begin
                    // Wait one cycle for BRAM read
                    state <= S_L1_COMPUTE;
                end
                
                S_L1_COMPUTE: begin
                    // Store activation result
                    l1_output[neuron_idx[2:0]*2 +: 2] <= l1_act;
                    state <= S_L1_NEXT;
                end
                
                S_L1_NEXT: begin
                    if (neuron_idx == 4'd8) begin
                        // Done with Layer 1
                        state <= S_L2_FETCH;
                        neuron_idx <= 4'd0;
                        l2_row_sel <= 2'd0;
                        l2_output <= 6'd0;
                    end else begin
                        neuron_idx <= neuron_idx + 1;
                        l1_row_sel <= l1_row_sel + 1;
                        state <= S_L1_FETCH;
                    end
                end
                
                // Layer 2: Process 3 neurons sequentially
                S_L2_FETCH: begin
                    state <= S_L2_COMPUTE;
                end
                
                S_L2_COMPUTE: begin
                    l2_output[neuron_idx[1:0]*2 +: 2] <= l2_act;
                    state <= S_L2_NEXT;
                end
                
                S_L2_NEXT: begin
                    if (neuron_idx == 4'd2) begin
                        state <= S_L3_COMPUTE;
                    end else begin
                        neuron_idx <= neuron_idx + 1;
                        l2_row_sel <= l2_row_sel + 1;
                        state <= S_L2_FETCH;
                    end
                end
                
                // Layer 3: Single computation
                S_L3_COMPUTE: begin
                    result <= l3_dot;
                    state <= S_DONE;
                end
                
                S_DONE: begin
                    result_valid <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// SCALABLE BRAM INFERENCE - Parameterized for larger models
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_scalable_bram #(
    parameter L1_INPUTS = 27,
    parameter L1_OUTPUTS = 9,
    parameter L2_INPUTS = 9,
    parameter L2_OUTPUTS = 3,
    parameter L3_INPUTS = 3,
    parameter L3_OUTPUTS = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI-like weight loading interface
    input  wire        s_axis_weight_valid,
    input  wire [63:0] s_axis_weight_data,
    input  wire [7:0]  s_axis_weight_dest,  // Layer + row encoding
    output wire        s_axis_weight_ready,
    
    // Inference interface
    input  wire        infer_valid,
    input  wire [L1_INPUTS*2-1:0] infer_data,
    output wire        infer_ready,
    
    output wire signed [2:0] result_data,
    output wire        result_valid
);

    // Weight storage dimensions
    localparam L1_WEIGHT_BITS = L1_INPUTS * 2;  // 54 bits
    localparam L2_WEIGHT_BITS = L2_INPUTS * 2;  // 18 bits
    localparam L3_WEIGHT_BITS = L3_INPUTS * 2;  // 6 bits
    
    // Instantiate BRAM inference engine
    bitnet_bram_inference engine (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(s_axis_weight_valid),
        .load_layer(s_axis_weight_dest[5:4]),
        .load_row(s_axis_weight_dest[3:0]),
        .load_data(s_axis_weight_data[53:0]),
        .load_done(s_axis_weight_ready),
        .infer_start(infer_valid),
        .input_vec(infer_data),
        .threshold_l1(6'sd5),
        .threshold_l2(5'sd2),
        .result(result_data),
        .result_valid(result_valid),
        .ready(infer_ready)
    );

endmodule
