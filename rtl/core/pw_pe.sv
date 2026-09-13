`timescale 1ns/1ps

// ============================================================================
// File Name   : pw_pe.sv
// Description : Pointwise Convolution Processing Element receiving 3 signed 
//               inputs from DW layer, performing Bipolar Multiplication, 
//               Accumulation [-27, +27], and Dynamic Polarity Thresholding.
// IEEE Std    : 1800-2017 compliant
// ============================================================================

module pw_pe (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_valid,
    // 3 Signed inputs from DW Layer (5-bit Signed: -9 to +9)
    input  logic signed [4:0]  i_dw_out_0, 
    input  logic signed [4:0]  i_dw_out_1, 
    input  logic signed [4:0]  i_dw_out_2, 

    input  logic [2:0]  i_weight,     // 3-bit BNN Weights (1 = +1, 0 = -1)
    input  logic [16:0] i_threshold,  // 17-bit Threshold (Bit [16] = Polarity)

    output logic        o_valid,
    output logic        o_data   
);

    // -------------------------------------------------------------
    // Stage 1: Bipolar Multiplication (Weight * DW_Out) & Accumulation
    // -------------------------------------------------------------
    // Extend 5-bit signed inputs to 7-bit Signed to prevent overflow [-27, +27]
    logic signed [6:0] dw0_ext, dw1_ext, dw2_ext;
    logic signed [6:0] term0, term1, term2;

    assign dw0_ext = 7'(i_dw_out_0);
    assign dw1_ext = 7'(i_dw_out_1);
    assign dw2_ext = 7'(i_dw_out_2);

    // Bipolar Multiply: Weight = 1 -> +1, Weight = 0 -> -1
    assign term0 = i_weight[0] ? dw0_ext : -dw0_ext;
    assign term1 = i_weight[1] ? dw1_ext : -dw1_ext;
    assign term2 = i_weight[2] ? dw2_ext : -dw2_ext;

    logic signed [6:0]  sum_pw_r;
    logic               valid1;
    logic [16:0]        thresh1; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thresh1  <= 17'd0;
            valid1   <= 1'b0;
            sum_pw_r <= 7'sd0;
        end else begin
            valid1 <= i_valid; 
            if (i_valid) begin
                thresh1  <= i_threshold;
                sum_pw_r <= term0 + term1 + term2; // Sum range: [-27, +27]
            end
        end
    end

    // -------------------------------------------------------------
    // Stage 2: Thresholding Comparison (With Polarity Support)
    // -------------------------------------------------------------
    logic               polarity;
    logic signed [15:0] thresh_value;
    logic signed [15:0] sum_extended;
    logic               data_out_t;

    assign polarity     = thresh1[16];
    assign thresh_value = $signed(thresh1[15:0]);
    assign sum_extended = 16'(sum_pw_r); // Sign-extend 7-bit to 16-bit for comparison

    // Flexible comparison based on Polarity bit
    assign data_out_t = polarity ? (sum_extended >= thresh_value) 
                                 : (sum_extended <= thresh_value);

    // -------------------------------------------------------------
    // Output Stage
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid <= 1'b0;
            o_data  <= 1'b0;
        end else begin
            o_valid <= valid1; 
            if (valid1) begin
                o_data <= data_out_t;
            end
        end
    end

endmodule