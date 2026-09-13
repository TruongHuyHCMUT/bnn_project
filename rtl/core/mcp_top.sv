module mcp_top (
    input  logic        clk, 
    input  logic        rst_n,
    input  logic        img_valid, 
    input  logic        img_data,

    output logic        mcp_valid,
    output logic [2:0]  mcp_data_out
);
    // Signals from Window Extractor (4x4, Stride 2)
    logic        win_valid;
    logic [15:0] win_data;

    window4x4s2 u_window (
        .clk        (clk), 
        .rst_n      (rst_n),
        .din_valid  (img_valid),
        .din        (img_data),
        .dout_valid (win_valid),
        .dout_window(win_data)
    );

// -------------------------------------------------------------
// Parameters for 3 Filters (Weights & Thresholds)
// -------------------------------------------------------------
    // 16-bit Binary Weights for 3 filters (Format: 1 = +1, 0 = -1)
    localparam logic [15:0] mcp_weight [0:2] = '{
        16'h7ffe,
        16'h0808,
        16'h1009
    };

    // 17-bit Thresholds cho 3 filters (Bit [16] = Polarity, Bits [15:0] = Threshold Value)
    // Giá trị tạm thời: 17'h10008 = Polarity '1' (>=) và Threshold = 8
    localparam logic [16:0] mcp_thresh [0:2] = '{
        17'h10004, 
        17'h1000e, 
        17'h1000b  
    };

    // Internal Valid array for 3 PE cores
    logic [2:0] valid_out_arr;

// -------------------------------------------------------------
// Generate 3 MCP Processing Elements in Parallel
// -------------------------------------------------------------
    genvar i; 
    generate 
        for (i = 0; i < 3; i++) begin : gen_mcp_filters
            mcp_pe u_pe (
                .clk       (clk),
                .rst_n     (rst_n),
                .valid_in  (win_valid),
                .window_in (win_data),
                .weight_in (mcp_weight[i]),
                .thresh_in (mcp_thresh[i]),
                .valid_out (valid_out_arr[i]),
                .data_out  (mcp_data_out[i])
            );
        end
    endgenerate 

    assign mcp_valid = valid_out_arr[0];

endmodule