// ═══════════════════════════════════════════════════════════════════════════════
// bitnet_hybrid_bram v1.0.0 - Hybrid BRAM + Parallel Compute
// ═══════════════════════════════════════════════════════════════════════════════
//
// Best of both worlds:
// - BRAM storage for runtime weight loading
// - Parallel compute for maximum throughput
//
// Wide BRAM read: All layer weights in single cycle
// Latency: 4 cycles (same as register version)
// Throughput: 1 inference/cycle
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

// ═══════════════════════════════════════════════════════════════════════════════
// WIDE BRAM - All Layer 1 weights in single read (486 bits)
// ═══════════════════════════════════════════════════════════════════════════════
module wide_bram_l1 (
    input  wire        clk,
    
    // Write interface (row-by-row loading)
    input  wire        wr_en,
    input  wire [3:0]  wr_row,      // 0-8
    input  wire [53:0] wr_data,     // 27 trits per row
    
    // Read interface (all rows at once)
    input  wire        rd_en,
    output reg  [485:0] rd_data     // All 9 rows = 486 bits
);

    // Storage for 9 rows
    (* ram_style = "block" *)
    reg [53:0] weights [0:8];
    
    // Write one row at a time
    always @(posedge clk) begin
        if (wr_en && wr_row < 4'd9) begin
            weights[wr_row] <= wr_data;
        end
    end
    
    // Read all rows simultaneously
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= {weights[8], weights[7], weights[6],
                       weights[5], weights[4], weights[3],
                       weights[2], weights[1], weights[0]};
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// WIDE BRAM - All Layer 2 weights in single read (54 bits)
// ═══════════════════════════════════════════════════════════════════════════════
module wide_bram_l2 (
    input  wire        clk,
    
    input  wire        wr_en,
    input  wire [1:0]  wr_row,      // 0-2
    input  wire [17:0] wr_data,     // 9 trits per row
    
    input  wire        rd_en,
    output reg  [53:0] rd_data      // All 3 rows = 54 bits
);

    (* ram_style = "block" *)
    reg [17:0] weights [0:2];
    
    always @(posedge clk) begin
        if (wr_en && wr_row < 2'd3) begin
            weights[wr_row] <= wr_data;
        end
    end
    
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= {weights[2], weights[1], weights[0]};
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 3 WEIGHT REGISTER (6 bits - too small for BRAM)
// ═══════════════════════════════════════════════════════════════════════════════
module weight_reg_l3 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [5:0]  wr_data,
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
// HYBRID WEIGHT CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
module hybrid_weight_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Weight loading interface
    input  wire        load_en,
    input  wire [1:0]  load_layer,  // 0=L1, 1=L2, 2=L3
    input  wire [3:0]  load_row,
    input  wire [53:0] load_data,
    output reg         load_done,
    
    // Wide read interface (for inference)
    input  wire        read_en,
    output wire [485:0] l1_weights,  // All 9 rows
    output wire [53:0]  l2_weights,  // All 3 rows
    output wire [5:0]   l3_weights   // 1 row
);

    // Write enables
    wire l1_wr_en = load_en && (load_layer == 2'd0);
    wire l2_wr_en = load_en && (load_layer == 2'd1);
    wire l3_wr_en = load_en && (load_layer == 2'd2);
    
    // Layer 1 Wide BRAM
    wide_bram_l1 l1_bram (
        .clk(clk),
        .wr_en(l1_wr_en),
        .wr_row(load_row),
        .wr_data(load_data),
        .rd_en(read_en),
        .rd_data(l1_weights)
    );
    
    // Layer 2 Wide BRAM
    wide_bram_l2 l2_bram (
        .clk(clk),
        .wr_en(l2_wr_en),
        .wr_row(load_row[1:0]),
        .wr_data(load_data[17:0]),
        .rd_en(read_en),
        .rd_data(l2_weights)
    );
    
    // Layer 3 Register
    weight_reg_l3 l3_reg (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(l3_wr_en),
        .wr_data(load_data[5:0]),
        .rd_data(l3_weights)
    );
    
    // Load done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            load_done <= 1'b0;
        else
            load_done <= load_en;
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID INFERENCE ENGINE - BRAM + Parallel Compute
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_hybrid_inference (
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

    // Pipeline stages
    localparam S_IDLE = 3'd0;
    localparam S_FETCH = 3'd1;    // BRAM read latency
    localparam S_L1 = 3'd2;       // Layer 1 compute
    localparam S_L2 = 3'd3;       // Layer 2 compute
    localparam S_L3 = 3'd4;       // Layer 3 compute
    localparam S_DONE = 3'd5;
    
    reg [2:0] state;
    
    // Weight controller
    wire [485:0] l1_weights;
    wire [53:0]  l2_weights;
    wire [5:0]   l3_weights;
    
    hybrid_weight_controller wctrl (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_weight),
        .load_layer(load_layer),
        .load_row(load_row),
        .load_data(load_data),
        .load_done(load_done),
        .read_en(1'b1),  // Always read weights
        .l1_weights(l1_weights),
        .l2_weights(l2_weights),
        .l3_weights(l3_weights)
    );
    
    // Pipeline registers
    reg [53:0] input_reg;
    reg [485:0] l1_weights_reg;
    reg [53:0] l2_weights_reg;
    reg [5:0] l3_weights_reg;
    reg [17:0] l1_output_reg;
    reg [5:0] l2_output_reg;
    
    // Layer 1: 9 parallel dot products
    wire [17:0] l1_output;
    genvar n;
    generate
        for (n = 0; n < 9; n = n + 1) begin : l1_neurons
            wire [53:0] weight_row = l1_weights_reg[n*54 +: 54];
            wire signed [5:0] dot_result;
            
            trit27_dot_product_v2 dp (
                .input_vec(input_reg),
                .weight_vec(weight_row),
                .result(dot_result)
            );
            
            // Activation
            wire [1:0] act = (dot_result > threshold_l1)  ? 2'b10 :  // +1
                            (dot_result < -threshold_l1) ? 2'b00 :  // -1
                            2'b01;                                   // 0
            
            assign l1_output[n*2 +: 2] = act;
        end
    endgenerate
    
    // Layer 2: 3 parallel dot products
    wire [5:0] l2_output;
    generate
        for (n = 0; n < 3; n = n + 1) begin : l2_neurons
            wire [17:0] weight_row = l2_weights_reg[n*18 +: 18];
            wire signed [4:0] dot_result;
            
            trit9_dot_product dp (
                .input_vec(l1_output_reg),
                .weight_vec(weight_row),
                .result(dot_result)
            );
            
            wire [1:0] act = (dot_result > $signed({1'b0, threshold_l2}))  ? 2'b10 :
                            (dot_result < -$signed({1'b0, threshold_l2})) ? 2'b00 :
                            2'b01;
            
            assign l2_output[n*2 +: 2] = act;
        end
    endgenerate
    
    // Layer 3: 1 dot product (no activation)
    wire signed [2:0] l3_output;
    trit3_dot_product l3_dp (
        .input_vec(l2_output_reg),
        .weight_vec(l3_weights_reg),
        .result(l3_output)
    );
    
    assign ready = (state == S_IDLE) && !load_weight;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            input_reg <= 54'd0;
            l1_weights_reg <= 486'd0;
            l2_weights_reg <= 54'd0;
            l3_weights_reg <= 6'd0;
            l1_output_reg <= 18'd0;
            l2_output_reg <= 6'd0;
            result <= 3'sd0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (infer_start && !load_weight) begin
                        input_reg <= input_vec;
                        state <= S_FETCH;
                    end
                end
                
                S_FETCH: begin
                    // BRAM read latency - capture weights
                    l1_weights_reg <= l1_weights;
                    l2_weights_reg <= l2_weights;
                    l3_weights_reg <= l3_weights;
                    state <= S_L1;
                end
                
                S_L1: begin
                    // Layer 1 compute (combinational)
                    l1_output_reg <= l1_output;
                    state <= S_L2;
                end
                
                S_L2: begin
                    // Layer 2 compute
                    l2_output_reg <= l2_output;
                    state <= S_L3;
                end
                
                S_L3: begin
                    // Layer 3 compute
                    result <= l3_output;
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
// STREAMING HYBRID ENGINE - Full pipeline, 1 inference/cycle
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_hybrid_streaming (
    input  wire        clk,
    input  wire        rst_n,
    
    // Weight loading (same interface)
    input  wire        load_weight,
    input  wire [1:0]  load_layer,
    input  wire [3:0]  load_row,
    input  wire [53:0] load_data,
    output wire        load_done,
    
    // Streaming inference
    input  wire        input_valid,
    input  wire [53:0] input_data,
    output wire        input_ready,
    
    input  wire signed [5:0] threshold_l1,
    input  wire signed [4:0] threshold_l2,
    
    output reg  signed [2:0] output_data,
    output reg         output_valid
);

    // Weight storage
    wire [485:0] l1_weights;
    wire [53:0]  l2_weights;
    wire [5:0]   l3_weights;
    
    // Continuous read enable
    wire weights_read_en = 1'b1;
    
    hybrid_weight_controller wctrl (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_weight),
        .load_layer(load_layer),
        .load_row(load_row),
        .load_data(load_data),
        .load_done(load_done),
        .read_en(weights_read_en),
        .l1_weights(l1_weights),
        .l2_weights(l2_weights),
        .l3_weights(l3_weights)
    );
    
    // Pipeline registers
    reg [53:0] p1_input;
    reg [485:0] p1_l1_weights;
    reg [53:0] p1_l2_weights;
    reg [5:0] p1_l3_weights;
    reg p1_valid;
    
    reg [17:0] p2_l1_out;
    reg [53:0] p2_l2_weights;
    reg [5:0] p2_l3_weights;
    reg p2_valid;
    
    reg [5:0] p3_l2_out;
    reg [5:0] p3_l3_weights;
    reg p3_valid;
    
    reg p4_valid;
    
    assign input_ready = !load_weight;
    
    // Layer 1: 9 parallel dot products (combinational)
    wire [17:0] l1_out;
    genvar n;
    generate
        for (n = 0; n < 9; n = n + 1) begin : l1_dp
            wire [53:0] w = p1_l1_weights[n*54 +: 54];
            wire signed [5:0] dot;
            trit27_dot_product_v2 dp (.input_vec(p1_input), .weight_vec(w), .result(dot));
            assign l1_out[n*2 +: 2] = (dot > threshold_l1) ? 2'b10 :
                                      (dot < -threshold_l1) ? 2'b00 : 2'b01;
        end
    endgenerate
    
    // Layer 2: 3 parallel dot products
    wire [5:0] l2_out;
    generate
        for (n = 0; n < 3; n = n + 1) begin : l2_dp
            wire [17:0] w = p2_l2_weights[n*18 +: 18];
            wire signed [4:0] dot;
            trit9_dot_product dp (.input_vec(p2_l1_out), .weight_vec(w), .result(dot));
            assign l2_out[n*2 +: 2] = (dot > $signed({1'b0, threshold_l2})) ? 2'b10 :
                                      (dot < -$signed({1'b0, threshold_l2})) ? 2'b00 : 2'b01;
        end
    endgenerate
    
    // Layer 3: 1 dot product
    wire signed [2:0] l3_out;
    trit3_dot_product l3_dp (.input_vec(p3_l2_out), .weight_vec(p3_l3_weights), .result(l3_out));
    
    // Pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p1_input <= 54'd0;
            p1_l1_weights <= 486'd0;
            p1_l2_weights <= 54'd0;
            p1_l3_weights <= 6'd0;
            p1_valid <= 1'b0;
            
            p2_l1_out <= 18'd0;
            p2_l2_weights <= 54'd0;
            p2_l3_weights <= 6'd0;
            p2_valid <= 1'b0;
            
            p3_l2_out <= 6'd0;
            p3_l3_weights <= 6'd0;
            p3_valid <= 1'b0;
            
            p4_valid <= 1'b0;
            output_data <= 3'sd0;
            output_valid <= 1'b0;
        end else begin
            // Stage 1: Capture input and weights
            if (input_valid && input_ready) begin
                p1_input <= input_data;
                p1_l1_weights <= l1_weights;
                p1_l2_weights <= l2_weights;
                p1_l3_weights <= l3_weights;
            end
            p1_valid <= input_valid && input_ready;
            
            // Stage 2: L1 → L2
            p2_l1_out <= l1_out;
            p2_l2_weights <= p1_l2_weights;
            p2_l3_weights <= p1_l3_weights;
            p2_valid <= p1_valid;
            
            // Stage 3: L2 → L3
            p3_l2_out <= l2_out;
            p3_l3_weights <= p2_l3_weights;
            p3_valid <= p2_valid;
            
            // Stage 4: Output
            output_data <= l3_out;
            output_valid <= p3_valid;
        end
    end

endmodule
