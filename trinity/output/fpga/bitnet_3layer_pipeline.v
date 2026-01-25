// ═══════════════════════════════════════════════════════════════════════════════
// bitnet_3layer_pipeline v1.0.0 - 3-Layer BitNet Inference Pipeline
// ═══════════════════════════════════════════════════════════════════════════════
//
// Architecture: 27 → 9 → 3 → 1
// Layer 1: 27 inputs → 9 neurons (trit27_dot_product × 9)
// Layer 2: 9 inputs → 3 neurons (trit9_dot_product × 3)
// Layer 3: 3 inputs → 1 neuron (trit3_dot_product × 1)
//
// Total weights: 243 + 27 + 3 = 273 ternary weights
//
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT ENCODING
// ═══════════════════════════════════════════════════════════════════════════════
// TRIT_N = 2'b00 = -1
// TRIT_Z = 2'b01 =  0
// TRIT_P = 2'b10 = +1

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT3 DOT PRODUCT - 3 trits
// ═══════════════════════════════════════════════════════════════════════════════
module trit3_dot_product (
    input  wire [5:0] input_vec,   // 3 trits
    input  wire [5:0] weight_vec,  // 3 trits
    output wire signed [2:0] result // -3 to +3
);

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Multiply each trit pair
    wire [1:0] prod [0:2];
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : mult
            wire [1:0] a = input_vec[i*2 +: 2];
            wire [1:0] b = weight_vec[i*2 +: 2];
            wire a_zero = (a == TRIT_Z);
            wire b_zero = (b == TRIT_Z);
            wire same_sign = (a == b);
            assign prod[i] = (a_zero || b_zero) ? TRIT_Z :
                             same_sign ? TRIT_P : TRIT_N;
        end
    endgenerate

    // Convert to signed and sum
    wire signed [1:0] val [0:2];
    generate
        for (i = 0; i < 3; i = i + 1) begin : conv
            assign val[i] = (prod[i] == TRIT_N) ? -2'sd1 :
                            (prod[i] == TRIT_P) ?  2'sd1 : 2'sd0;
        end
    endgenerate

    assign result = $signed(val[0]) + $signed(val[1]) + $signed(val[2]);

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT9 DOT PRODUCT - 9 trits
// ═══════════════════════════════════════════════════════════════════════════════
module trit9_dot_product (
    input  wire [17:0] input_vec,  // 9 trits
    input  wire [17:0] weight_vec, // 9 trits
    output wire signed [4:0] result // -9 to +9
);

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Multiply each trit pair
    wire [1:0] prod [0:8];
    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin : mult
            wire [1:0] a = input_vec[i*2 +: 2];
            wire [1:0] b = weight_vec[i*2 +: 2];
            wire a_zero = (a == TRIT_Z);
            wire b_zero = (b == TRIT_Z);
            wire same_sign = (a == b);
            assign prod[i] = (a_zero || b_zero) ? TRIT_Z :
                             same_sign ? TRIT_P : TRIT_N;
        end
    endgenerate

    // Convert to signed
    wire signed [1:0] val [0:8];
    generate
        for (i = 0; i < 9; i = i + 1) begin : conv
            assign val[i] = (prod[i] == TRIT_N) ? -2'sd1 :
                            (prod[i] == TRIT_P) ?  2'sd1 : 2'sd0;
        end
    endgenerate

    // 3-level adder tree: 9 → 3 → 1
    wire signed [2:0] l1 [0:2];
    assign l1[0] = $signed(val[0]) + $signed(val[1]) + $signed(val[2]);
    assign l1[1] = $signed(val[3]) + $signed(val[4]) + $signed(val[5]);
    assign l1[2] = $signed(val[6]) + $signed(val[7]) + $signed(val[8]);

    assign result = $signed(l1[0]) + $signed(l1[1]) + $signed(l1[2]);

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT27 DOT PRODUCT - 27 trits (reuse from bitnet_simd_core)
// ═══════════════════════════════════════════════════════════════════════════════
module trit27_dot_product_v2 (
    input  wire [53:0] input_vec,   // 27 trits
    input  wire [53:0] weight_vec,  // 27 trits
    output wire signed [5:0] result // -27 to +27
);

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    // Multiply each trit pair
    wire [1:0] prod [0:26];
    genvar i;
    generate
        for (i = 0; i < 27; i = i + 1) begin : mult
            wire [1:0] a = input_vec[i*2 +: 2];
            wire [1:0] b = weight_vec[i*2 +: 2];
            wire a_zero = (a == TRIT_Z);
            wire b_zero = (b == TRIT_Z);
            wire same_sign = (a == b);
            assign prod[i] = (a_zero || b_zero) ? TRIT_Z :
                             same_sign ? TRIT_P : TRIT_N;
        end
    endgenerate

    // Convert to signed
    wire signed [1:0] val [0:26];
    generate
        for (i = 0; i < 27; i = i + 1) begin : conv
            assign val[i] = (prod[i] == TRIT_N) ? -2'sd1 :
                            (prod[i] == TRIT_P) ?  2'sd1 : 2'sd0;
        end
    endgenerate

    // 3-level adder tree: 27 → 9 → 3 → 1
    wire signed [2:0] l1 [0:8];
    generate
        for (i = 0; i < 9; i = i + 1) begin : level1
            assign l1[i] = $signed(val[i*3]) + $signed(val[i*3+1]) + $signed(val[i*3+2]);
        end
    endgenerate

    wire signed [4:0] l2 [0:2];
    assign l2[0] = $signed(l1[0]) + $signed(l1[1]) + $signed(l1[2]);
    assign l2[1] = $signed(l1[3]) + $signed(l1[4]) + $signed(l1[5]);
    assign l2[2] = $signed(l1[6]) + $signed(l1[7]) + $signed(l1[8]);

    assign result = $signed(l2[0]) + $signed(l2[1]) + $signed(l2[2]);

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY ACTIVATION - Threshold-based
// ═══════════════════════════════════════════════════════════════════════════════
module ternary_activation #(
    parameter WIDTH = 6
)(
    input  wire signed [WIDTH-1:0] pre_act,
    input  wire signed [WIDTH-1:0] threshold,
    output wire [1:0] result
);

    localparam TRIT_N = 2'b00;
    localparam TRIT_Z = 2'b01;
    localparam TRIT_P = 2'b10;

    assign result = (pre_act > threshold)  ? TRIT_P :
                    (pre_act < -threshold) ? TRIT_N :
                    TRIT_Z;

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 1: 27 → 9 (9 parallel dot products)
// ═══════════════════════════════════════════════════════════════════════════════
module layer1_forward (
    input  wire [53:0] input_vec,           // 27 trits input
    input  wire [485:0] weights,            // 9 rows × 54 bits = 486 bits
    input  wire signed [5:0] threshold,     // Activation threshold
    output wire [17:0] output_vec           // 9 trits output
);

    genvar n;
    generate
        for (n = 0; n < 9; n = n + 1) begin : neuron
            wire [53:0] weight_row = weights[n*54 +: 54];
            wire signed [5:0] pre_act;
            
            trit27_dot_product_v2 dot (
                .input_vec(input_vec),
                .weight_vec(weight_row),
                .result(pre_act)
            );
            
            ternary_activation #(.WIDTH(6)) act (
                .pre_act(pre_act),
                .threshold(threshold),
                .result(output_vec[n*2 +: 2])
            );
        end
    endgenerate

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 2: 9 → 3 (3 parallel dot products)
// ═══════════════════════════════════════════════════════════════════════════════
module layer2_forward (
    input  wire [17:0] input_vec,           // 9 trits input
    input  wire [53:0] weights,             // 3 rows × 18 bits = 54 bits
    input  wire signed [4:0] threshold,     // Activation threshold
    output wire [5:0] output_vec            // 3 trits output
);

    genvar n;
    generate
        for (n = 0; n < 3; n = n + 1) begin : neuron
            wire [17:0] weight_row = weights[n*18 +: 18];
            wire signed [4:0] pre_act;
            
            trit9_dot_product dot (
                .input_vec(input_vec),
                .weight_vec(weight_row),
                .result(pre_act)
            );
            
            ternary_activation #(.WIDTH(5)) act (
                .pre_act(pre_act),
                .threshold(threshold),
                .result(output_vec[n*2 +: 2])
            );
        end
    endgenerate

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 3: 3 → 1 (1 dot product, no activation)
// ═══════════════════════════════════════════════════════════════════════════════
module layer3_forward (
    input  wire [5:0] input_vec,            // 3 trits input
    input  wire [5:0] weights,              // 1 row × 6 bits
    output wire signed [2:0] output_val     // Final result (-3 to +3)
);

    trit3_dot_product dot (
        .input_vec(input_vec),
        .weight_vec(weights),
        .result(output_val)
    );

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// 3-LAYER PIPELINE TOP MODULE
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_3layer_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [53:0] input_vec,           // 27 trits input
    
    // Weights (can be loaded from BRAM in real design)
    input  wire [485:0] weights_l1,         // Layer 1: 9×27 = 243 weights
    input  wire [53:0]  weights_l2,         // Layer 2: 3×9 = 27 weights
    input  wire [5:0]   weights_l3,         // Layer 3: 1×3 = 3 weights
    
    // Thresholds
    input  wire signed [5:0] threshold_l1,
    input  wire signed [4:0] threshold_l2,
    
    // Output
    output reg  signed [2:0] result,
    output reg         valid,
    output wire        ready
);

    // Pipeline registers
    reg [53:0] input_reg;
    reg [17:0] l1_output_reg;
    reg [5:0]  l2_output_reg;
    
    // Pipeline valid signals
    reg valid_s1, valid_s2, valid_s3;
    
    // Combinational layer outputs
    wire [17:0] l1_output;
    wire [5:0]  l2_output;
    wire signed [2:0] l3_output;
    
    // Layer 1: 27 → 9
    layer1_forward layer1 (
        .input_vec(input_reg),
        .weights(weights_l1),
        .threshold(threshold_l1),
        .output_vec(l1_output)
    );
    
    // Layer 2: 9 → 3
    layer2_forward layer2 (
        .input_vec(l1_output_reg),
        .weights(weights_l2),
        .threshold(threshold_l2),
        .output_vec(l2_output)
    );
    
    // Layer 3: 3 → 1
    layer3_forward layer3 (
        .input_vec(l2_output_reg),
        .weights(weights_l3),
        .output_val(l3_output)
    );
    
    // Ready when not processing
    assign ready = ~valid_s1 & ~valid_s2 & ~valid_s3;
    
    // Pipeline control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_reg <= 54'd0;
            l1_output_reg <= 18'd0;
            l2_output_reg <= 6'd0;
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            valid_s3 <= 1'b0;
            result <= 3'sd0;
            valid <= 1'b0;
        end else begin
            // Stage 1: Capture input
            if (start && ready) begin
                input_reg <= input_vec;
                valid_s1 <= 1'b1;
            end else begin
                valid_s1 <= 1'b0;
            end
            
            // Stage 2: Layer 1 → Layer 2
            if (valid_s1) begin
                l1_output_reg <= l1_output;
                valid_s2 <= 1'b1;
            end else begin
                valid_s2 <= 1'b0;
            end
            
            // Stage 3: Layer 2 → Layer 3
            if (valid_s2) begin
                l2_output_reg <= l2_output;
                valid_s3 <= 1'b1;
            end else begin
                valid_s3 <= 1'b0;
            end
            
            // Output stage
            if (valid_s3) begin
                result <= l3_output;
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// COMBINATIONAL VERSION (for synthesis analysis)
// ═══════════════════════════════════════════════════════════════════════════════
module bitnet_3layer_combinational (
    input  wire [53:0] input_vec,           // 27 trits input
    input  wire [485:0] weights_l1,         // Layer 1 weights
    input  wire [53:0]  weights_l2,         // Layer 2 weights
    input  wire [5:0]   weights_l3,         // Layer 3 weights
    input  wire signed [5:0] threshold_l1,
    input  wire signed [4:0] threshold_l2,
    output wire signed [2:0] result         // Final output
);

    wire [17:0] l1_output;
    wire [5:0]  l2_output;
    
    layer1_forward layer1 (
        .input_vec(input_vec),
        .weights(weights_l1),
        .threshold(threshold_l1),
        .output_vec(l1_output)
    );
    
    layer2_forward layer2 (
        .input_vec(l1_output),
        .weights(weights_l2),
        .threshold(threshold_l2),
        .output_vec(l2_output)
    );
    
    layer3_forward layer3 (
        .input_vec(l2_output),
        .weights(weights_l3),
        .output_val(result)
    );

endmodule
