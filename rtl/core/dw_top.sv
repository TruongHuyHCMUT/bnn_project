module dw_top (
    input  logic        clk,
    input  logic        rst_n,

    // Input streams from MCP Top
    input  logic        mcp_valid,
    input  logic [2:0]  mcp_data,    // 3 channels from MCP Layer    

    // Output streams to PW (Pointwise Conv)
    output logic        dw_valid,
    output logic [14:0] dw_data_out  // 15 bits total (3 channels x 5-bit signed)
);

    // -------------------------------------------------------------
    // Window Extractor (3x3, Stride 1, Data Width = 3 bits)
    // -------------------------------------------------------------
    logic        win_valid;
    logic [26:0] win_data; // 9 positions x 3 channels = 27 bits

    window3x3s1 #(
        .DATA_WIDTH(3), 
        .IMG_WIDTH(15)      
    ) u_window (
        .clk         (clk),
        .rst_n       (rst_n),
        .din_valid   (mcp_valid),
        .din         (mcp_data),
        .dout_valid  (win_valid),
        .dout_window (win_data)
    );

    // -------------------------------------------------------------
    // Weights for 3 Channels (3x3 Binary Weights = 9 bits each)
    // -------------------------------------------------------------
    localparam logic [8:0] dw_weights [0:2] = '{
        9'h1fb, // Channel 0 Weight
        9'h193, // Channel 1 Weight
        9'h004 // Channel 2 Weight
    };

    // -------------------------------------------------------------
    // Untangle Window Data: Tách win_data (27 bits) thành 3 channel 9-bit
    // -------------------------------------------------------------
    logic [8:0] ch_win0, ch_win1, ch_win2;
    
    genvar i;
    generate 
        for (i = 0; i < 9; i++) begin : gen_untangle
            assign ch_win0[i] = win_data[i * 3 + 0];
            assign ch_win1[i] = win_data[i * 3 + 1];
            assign ch_win2[i] = win_data[i * 3 + 2];
        end 
    endgenerate

    // -------------------------------------------------------------
    // Instantiate 3 DW PE Cores in Parallel
    // -------------------------------------------------------------
    logic              valid_out_arr [0:2];
    logic signed [4:0] data_out_arr  [0:2]; // Each channel output is 5-bit signed [-9, +9]

    dw_pe u_dw_pe_0 (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_valid  (win_valid),
        .i_window (ch_win0),
        .i_weight (dw_weights[0]),
        .o_valid  (valid_out_arr[0]),
        .o_data   (data_out_arr[0])
    );

    dw_pe u_dw_pe_1 (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_valid  (win_valid),
        .i_window (ch_win1),
        .i_weight (dw_weights[1]),
        .o_valid  (valid_out_arr[1]),
        .o_data   (data_out_arr[1])
    );

    dw_pe u_dw_pe_2 (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_valid  (win_valid),
        .i_window (ch_win2),
        .i_weight (dw_weights[2]),
        .o_valid  (valid_out_arr[2]),
        .o_data   (data_out_arr[2])
    );

    // -------------------------------------------------------------
    // Output Assignment
    // -------------------------------------------------------------
    assign dw_valid    = valid_out_arr[0];
    
    // Concatenate 3 signed 5-bit outputs into a 15-bit vector
    // Format: [Channel 2 (14:10) | Channel 1 (9:5) | Channel 0 (4:0)]
    assign dw_data_out = {data_out_arr[2], data_out_arr[1], data_out_arr[0]};

endmodule