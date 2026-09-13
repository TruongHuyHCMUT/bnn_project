`timescale 1ns/1ps
// ============================================================================
// File Name   : mcp_pe.sv
// Description : Processing Element for MCP Layer using Bitwise XNOR (Bipolar),
//               Popcount, and Dynamic Polarity Threshold Comparator.
// ============================================================================

module mcp_pe (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        valid_in,
    input  logic [15:0] window_in, 
    input  logic [15:0] weight_in, 
    input  logic [16:0] thresh_in, 
    
    output logic        valid_out,
    output logic        data_out   
);
    
    // Internal Pipeline Register Signals
    logic [15:0] xnor_res;
    logic        valid1;
    logic [16:0] thresh1;

    // -------------------------------------------------------------
    // Stage 1: Bitwise XNOR Operation & Pipeline Registers
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xnor_res <= '0;
            valid1   <= 1'b0;
            thresh1  <= '0;
        end else begin
            valid1 <= valid_in; 
            if (valid_in) begin
                xnor_res <= ~(window_in ^ weight_in); // Bitwise XNOR (Bipolar matching)
                thresh1  <= thresh_in;
            end
        end
    end

    // -------------------------------------------------------------
    // Stage 2: Popcount & Dynamic Polarity Comparator
    // -------------------------------------------------------------
    logic [4:0] pop_cnt; 

    // Instantiate 16-bit Population Counter
    popcount #(16) u_pop (
        .i_data  (xnor_res), 
        .o_count (pop_cnt)
    );

    logic               polarity;
    logic signed [15:0] thresh_val;
    logic signed [5:0]  sum_signed; 
    logic               data_out_t;

    // Bit [16] determines Polarity: 1 for (Sum >= Thresh), 0 for (Sum <= Thresh)
    assign polarity   = thresh1[16];
    assign thresh_val = thresh1[15:0];
    
    // Zero-extend 5-bit popcount to 6-bit signed vector (Range: 0 to 16)
    assign sum_signed = {1'b0, pop_cnt}; 

    // Dynamic polarity evaluation
    assign data_out_t = polarity ? (sum_signed >= thresh_val) : (sum_signed <= thresh_val);

    // -------------------------------------------------------------
    // Stage 3: Output Pipeline Register
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            data_out  <= 1'b0;
        end else begin
            valid_out <= valid1;
            if (valid1) begin
                data_out <= data_out_t;
            end
        end
    end

endmodule