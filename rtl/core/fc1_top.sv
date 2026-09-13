// Import package chứa bộ Trọng số và Ngưỡng ở phạm vi bên ngoài Module
import fc1_constants::*;

module fc1_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input streams from PW Layer
    input  logic        pw_valid,
    input  logic [17:0] pw_data,      // 18-bit binary stream
    
    // Output streams to FC2 Layer (64-bit output vector cho 64 neurons)
    output logic        fc1_valid,
    output logic [63:0] fc1_data_out  
);

    // -------------------------------------------------------------
    // 1. Pixel Counter (Scans 0 -> 168, total 169 pixels per image)
    // -------------------------------------------------------------
    logic [7:0] pixel_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt <= 8'd0;
        end else if (pw_valid) begin
            if (pixel_cnt == 8'd168)
                pixel_cnt <= 8'd0; // Reset counter for the next image
            else
                pixel_cnt <= pixel_cnt + 8'd1;
        end
    end

    // -------------------------------------------------------------
    // 2. Instantiate 64 Folded Neurons in Parallel
    // -------------------------------------------------------------
    logic [63:0] valid_out_arr;
    logic [17:0] current_weight_fm [0:63];

    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : gen_fc1_neurons 
            
            // Slice 18-bit chunk per pixel (Lấy 3042 bits, tự động bỏ 6 bits padding)
            assign current_weight_fm[i] = FC1_WEIGHTS[i][(168 - pixel_cnt) * 18 +: 18];

            fc1_neuron u_neuron (
                .clk        (clk),
                .rst_n      (rst_n),
                .pw_valid   (pw_valid),
                .pixel_cnt  (pixel_cnt),
                .pw_data    (pw_data),
                .weight_fm  (current_weight_fm[i]),
                .thresh_in  (FC1_THRESH[i]), // Truyền đủ 17-bit (bao gồm Polarity bit [16])
                .valid_out  (valid_out_arr[i]),
                .data_out   (fc1_data_out[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------
    // 3. Output Valid Generation
    // -------------------------------------------------------------
    // Lấy valid của neuron 0 vì cả 64 neurons hoàn tất cùng lúc ở pixel 168
    assign fc1_valid = valid_out_arr[0];

endmodule