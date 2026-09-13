module pw_top (
    input  logic        clk,
    input  logic        rst_n,

    // Input streams from DW Layer (15-bit = 3 channels x 5-bit Signed)
    input  logic        dw_valid,
    input  logic [14:0] dw_data,

    // Output streams to FC1 Layer (18-bit = 18 binary output channels)
    output logic        pw_valid,
    output logic [17:0] pw_data_out
);

    // -------------------------------------------------------------
    // Parameters for 18 Pointwise Filters (3-bit Weights & 16-bit Signed Thresholds)
    // -------------------------------------------------------------
    // 3-bit BNN Weights for each of the 18 filters (Format: 1 = +1, 0 = -1)
    localparam logic [2:0] pw_weights [0:17] = '{
        3'd0,
        3'd1,
        3'd5,
        3'd1,
        3'd2,
        3'd5,
        3'd5,
        3'd2,
        3'd3,
        3'd5,
        3'd2,
        3'd2,
        3'd4,
        3'd2,
        3'd2,
        3'd7,
        3'd7,
        3'd5
    };

    // 16-bit Signed Thresholds extracted from PyTorch BNN Model
    // Thay thế các giá trị 17'h10001 bằng giá trị signed 16-bit thực tế từ Python
    localparam logic [16:0] pw_thresh [0:17] = '{
        17'h1000c, 
        17'h10005, 
        17'h1fffa, 
        17'h1ffff, 
        17'h1fff6, 
        17'h1000b, 
        17'h1fff6, 
        17'h1000e, 
        17'h1fffd, 
        17'h10000, 
        17'h1fffb, 
        17'h10000, 
        17'h0fffd,
        17'h1fff8, 
        17'h10005, 
        17'h10002, 
        17'h1fff4, 
        17'h1fff2  
    };

    // Internal valid array for 18 PW PE cores
    logic [17:0] valid_out_arr;

    // -------------------------------------------------------------
    // Generate 18 Pointwise Processing Elements in Parallel
    // -------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 18; i++) begin : gen_pw_neurons
            pw_pe u_pe (
                .clk         (clk),
                .rst_n       (rst_n),
                .i_valid     (dw_valid),

                // Slice 15-bit input into three 5-bit signed channels
                .i_dw_out_0  (dw_data[4:0]),    // Channel 0 (bits 4:0)
                .i_dw_out_1  (dw_data[9:5]),    // Channel 1 (bits 9:5)
                .i_dw_out_2  (dw_data[14:10]), // Channel 2 (bits 14:10)

                .i_weight    (pw_weights[i]),
                .i_threshold (pw_thresh[i]),
                .o_valid     (valid_out_arr[i]),
                .o_data      (pw_data_out[i])
            );
        end
    endgenerate

    // Đồng bộ tín hiệu valid (Lấy valid của core 0 vì cả 18 core chạy song song)
    assign pw_valid = valid_out_arr[0];

endmodule