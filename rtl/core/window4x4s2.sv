`timescale 1ns/1ps

module window4x4s2 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        din_valid,
    input  logic        din,         // 1 raw image pixel bit
    
    output logic        dout_valid,
    output logic [15:0] dout_window  // Flattened 4x4 window
);

    // 3 line buffers, 32 pixels per row
    logic [31:0] row1, row2, row3;
    logic [15:0] window;
    
    // 32x32 image coordinate counters
    logic [4:0]  col_cnt; 
    logic [4:0]  row_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row1       <= '0; 
            row2       <= '0; 
            row3       <= '0;
            window     <= '0;
            col_cnt    <= '0; 
            row_cnt    <= '0;
            dout_valid <= 1'b0;
        end else begin
            dout_valid <= 1'b0; 
            
            if (din_valid) begin
                // Coordinate Management (Left-to-Right, Top-to-Bottom)
                if (col_cnt == 5'd31) begin
                    col_cnt <= 5'd0;
                    if (row_cnt == 5'd31) begin
                        row_cnt <= 5'd0; // Explicit frame boundary reset
                    end else begin
                        row_cnt <= row_cnt + 1'b1;
                    end
                end else begin
                    col_cnt <= col_cnt + 1'b1;
                end

                // Shift data into line buffers
                row1 <= {row1[30:0], din};
                row2 <= {row2[30:0], row1[31]};
                row3 <= {row3[30:0], row2[31]};

                // Update 4x4 window (Shift left, append rightmost pixel)
                window[15:13] <= window[14:12]; window[12] <= row3[31]; 
                window[11:9]  <= window[10:8];  window[8]  <= row2[31]; 
                window[7:5]   <= window[6:4];   window[4]  <= row1[31]; 
                window[3:1]   <= window[2:0];   window[0]  <= din;      

                // Valid Logic (Stride = 2)
                // Window is valid when row >= 3 and col >= 3 on odd indices (3, 5, 7 ... 31)
                if (row_cnt >= 5'd3 && col_cnt >= 5'd3 && row_cnt[0] == 1'b1 && col_cnt[0] == 1'b1) begin
                    dout_valid <= 1'b1;
                end
            end
        end
    end

    // Reverse bit order so top-left pixel maps to LSB for PyTorch alignment
    assign dout_window = {window[0],  window[1],  window[2],  window[3],
                          window[4],  window[5],  window[6],  window[7],
                          window[8],  window[9],  window[10], window[11],
                          window[12], window[13], window[14], window[15]};

endmodule