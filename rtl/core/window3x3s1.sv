`timescale 1ns/1ps

module window3x3s1 #(
    parameter int DATA_WIDTH = 8, // Pixel bit-width
    parameter int IMG_WIDTH  = 4  // Input image width (IMG_WIDTH x IMG_WIDTH)
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    din_valid,
    input  logic [DATA_WIDTH-1:0]   din,

    output logic                    dout_valid,
    output logic [9*DATA_WIDTH-1:0] dout_window  // Flattened 1D array output
);

    // Coordinate counters with safe width allocation
    logic [$clog2(IMG_WIDTH+1)-1:0] col_index;
    logic [$clog2(IMG_WIDTH+1)-1:0] row_index;

    // Line buffers for previous 2 rows
    logic [DATA_WIDTH-1:0] buff_row1 [0:IMG_WIDTH-1];
    logic [DATA_WIDTH-1:0] buff_row2 [0:IMG_WIDTH-1];

    // 3x3 spatial window registers
    logic [DATA_WIDTH-1:0] temp [0:8];

    // Map 3x3 window array to flat output vector
    assign dout_window = {temp[8], temp[7], temp[6], 
                          temp[5], temp[4], temp[3], 
                          temp[2], temp[1], temp[0]};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_index  <= '0;
            row_index  <= '0;
            dout_valid <= 1'b0;

            for (int i = 0; i < IMG_WIDTH; i++) begin
                buff_row1[i] <= '0;
                buff_row2[i] <= '0;
            end

            for (int i = 0; i < 9; i++) begin
                temp[i] <= '0;
            end
        end 
        else if (din_valid) begin
            // -------------------------------------------------------------
            // 1. Shift Line Buffers
            // -------------------------------------------------------------
            for (int i = IMG_WIDTH - 1; i > 0; i--) begin
                buff_row1[i] <= buff_row1[i-1];
                buff_row2[i] <= buff_row2[i-1];
            end

            buff_row1[0] <= din;
            buff_row2[0] <= buff_row1[IMG_WIDTH-1];

            // -------------------------------------------------------------
            // 2. Update 3x3 Window Registers
            // -------------------------------------------------------------
            // Row 3 (Current Row)
            temp[8] <= din;
            temp[7] <= temp[8];
            temp[6] <= temp[7];

            // Row 2 (Previous Row)
            temp[5] <= buff_row1[IMG_WIDTH-1];
            temp[4] <= temp[5];
            temp[3] <= temp[4];

            // Row 1 (Oldest Row)
            temp[2] <= buff_row2[IMG_WIDTH-1];
            temp[1] <= temp[2];
            temp[0] <= temp[1];

            // -------------------------------------------------------------
            // 3. Coordinate Management & Frame Boundary Handling
            // -------------------------------------------------------------
            if (col_index == IMG_WIDTH - 1) begin
                col_index <= '0;
                if (row_index == IMG_WIDTH - 1) begin
                    row_index <= '0; // Clear frame counter at image boundary
                end else begin
                    row_index <= row_index + 1'b1;
                end
            end else begin
                col_index <= col_index + 1'b1;
            end

            // -------------------------------------------------------------
            // 4. Valid Output Signal Generation
            // -------------------------------------------------------------
            // Window is fully valid when row >= 2 and col >= 2
            if (row_index >= 2 && col_index >= 2) begin
                dout_valid <= 1'b1;
            end else begin
                dout_valid <= 1'b0;
            end
        end 
        else begin
            dout_valid <= 1'b0;
        end
    end

endmodule