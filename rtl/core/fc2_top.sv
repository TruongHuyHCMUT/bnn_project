module fc2_top (
    input  logic        clk,
    input  logic        rst_n,

    // Ngõ vào 64-bit từ FC1 (64 neurons)
    input  logic        fc1_valid,
    input  logic [63:0] fc1_data_in,

    // Ngõ ra kết quả phân loại (0 -> 9)
    output logic        fc2_valid,
    output logic [3:0]  class_out 
);

    // -------------------------------------------------------------
    // 1. Trọng số 10 classes x 64 bits
    // -------------------------------------------------------------
    localparam logic [63:0] fc2_weights [0:9] = '{
        64'hb5c6c0bd607b9574, 
        64'h43128078c69e595e,
        64'hf8b407ac3d60c63c,
        64'h3a2538892a22098b,
        64'h43e984c0fbbfd857,
        64'h27fdd044e3e5fbef,
        64'hfc1b3dfdfd176153,
        64'h6fd8ab921718272d,
        64'ha96c217ad49bb8a1,
        64'hdedb4ff3218d6eef
    };

    // -------------------------------------------------------------
    // 2. MAC Stage: XNOR + Popcount 64-bit
    // -------------------------------------------------------------
    logic [63:0] xnor_res  [0:9];
    logic [6:0]  pop_comb  [0:9]; // Popcount trả về 0 -> 64

    genvar i;
    generate
        for (i = 0; i < 10; i++) begin : gen_fc2_mac
            assign xnor_res[i] = ~(fc1_data_in ^ fc2_weights[i]);
            
            popcount #(
                .WIDTH(64)
            ) pc (
                .i_data  (xnor_res[i]), 
                .o_count(pop_comb[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------
    // 2.5. LUT SCORE (Giải Lượng Tử Hóa PyTorch cho 64 bits: 0 -> 64)
    // -------------------------------------------------------------
    // Khai báo bảng LUT gồm 65 phần tử [0:64] cho từng class từ file Python/Mentor
    // COPY ĐOẠN NÀY DÁN VÀO MỤC 2.5 CỦA FILE fc2_top.sv


    localparam logic signed [15:0] lut_c0 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h800D,
    16'h86FA,
    16'h8DE7,
    16'h94D3,
    16'h9BC0,
    16'hA2AD,
    16'hA99A,
    16'hB087,
    16'hB774,
    16'hBE60,
    16'hC54D,
    16'hCC3A,
    16'hD327,
    16'hDA14,
    16'hE101,
    16'hE7ED,
    16'hEEDA,
    16'hF5C7,
    16'hFCB4,
    16'h03A1,
    16'h0A8D,
    16'h117A,
    16'h1867,
    16'h1F54,
    16'h2641,
    16'h2D2E,
    16'h341A,
    16'h3B07,
    16'h41F4,
    16'h48E1,
    16'h4FCE,
    16'h56BB,
    16'h5DA7,
    16'h6494,
    16'h6B81,
    16'h726E,
    16'h795B,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c1 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8048,
    16'h85C0,
    16'h8B39,
    16'h90B1,
    16'h9629,
    16'h9BA2,
    16'hA11A,
    16'hA692,
    16'hAC0B,
    16'hB183,
    16'hB6FB,
    16'hBC74,
    16'hC1EC,
    16'hC764,
    16'hCCDD,
    16'hD255,
    16'hD7CE,
    16'hDD46,
    16'hE2BE,
    16'hE837,
    16'hEDAF,
    16'hF327,
    16'hF8A0,
    16'hFE18,
    16'h0390,
    16'h0909,
    16'h0E81,
    16'h13F9,
    16'h1972,
    16'h1EEA,
    16'h2463,
    16'h29DB,
    16'h2F53,
    16'h34CC,
    16'h3A44,
    16'h3FBC,
    16'h4535,
    16'h4AAD,
    16'h5025,
    16'h559E,
    16'h5B16,
    16'h608F,
    16'h6607,
    16'h6B7F,
    16'h70F8,
    16'h7670,
    16'h7BE8,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c2 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8150,
    16'h87D3,
    16'h8E56,
    16'h94D9,
    16'h9B5C,
    16'hA1DF,
    16'hA861,
    16'hAEE4,
    16'hB567,
    16'hBBEA,
    16'hC26D,
    16'hC8F0,
    16'hCF73,
    16'hD5F6,
    16'hDC79,
    16'hE2FC,
    16'hE97E,
    16'hF001,
    16'hF684,
    16'hFD07,
    16'h038A,
    16'h0A0D,
    16'h1090,
    16'h1713,
    16'h1D96,
    16'h2419,
    16'h2A9C,
    16'h311E,
    16'h37A1,
    16'h3E24,
    16'h44A7,
    16'h4B2A,
    16'h51AD,
    16'h5830,
    16'h5EB3,
    16'h6536,
    16'h6BB9,
    16'h723C,
    16'h78BE,
    16'h7F41,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c3 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8050,
    16'h86E6,
    16'h8D7C,
    16'h9412,
    16'h9AA8,
    16'hA13E,
    16'hA7D4,
    16'hAE6A,
    16'hB500,
    16'hBB96,
    16'hC22C,
    16'hC8C2,
    16'hCF58,
    16'hD5EE,
    16'hDC84,
    16'hE31A,
    16'hE9B0,
    16'hF046,
    16'hF6DC,
    16'hFD72,
    16'h0408,
    16'h0A9E,
    16'h1134,
    16'h17CA,
    16'h1E60,
    16'h24F6,
    16'h2B8C,
    16'h3222,
    16'h38B8,
    16'h3F4E,
    16'h45E4,
    16'h4C7A,
    16'h5310,
    16'h59A6,
    16'h603C,
    16'h66D2,
    16'h6D68,
    16'h73FE,
    16'h7A94,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c4 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8111,
    16'h869A,
    16'h8C23,
    16'h91AC,
    16'h9735,
    16'h9CBE,
    16'hA247,
    16'hA7D0,
    16'hAD59,
    16'hB2E2,
    16'hB86A,
    16'hBDF3,
    16'hC37C,
    16'hC905,
    16'hCE8E,
    16'hD417,
    16'hD9A0,
    16'hDF29,
    16'hE4B2,
    16'hEA3B,
    16'hEFC4,
    16'hF54C,
    16'hFAD5,
    16'h005E,
    16'h05E7,
    16'h0B70,
    16'h10F9,
    16'h1682,
    16'h1C0B,
    16'h2194,
    16'h271D,
    16'h2CA6,
    16'h322F,
    16'h37B7,
    16'h3D40,
    16'h42C9,
    16'h4852,
    16'h4DDB,
    16'h5364,
    16'h58ED,
    16'h5E76,
    16'h63FF,
    16'h6988,
    16'h6F11,
    16'h7499,
    16'h7A22,
    16'h7FAB,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c5 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8545,
    16'h8AE7,
    16'h9089,
    16'h962B,
    16'h9BCD,
    16'hA16F,
    16'hA711,
    16'hACB3,
    16'hB255,
    16'hB7F7,
    16'hBD99,
    16'hC33B,
    16'hC8DD,
    16'hCE7F,
    16'hD421,
    16'hD9C3,
    16'hDF65,
    16'hE507,
    16'hEAA9,
    16'hF04B,
    16'hF5ED,
    16'hFB8F,
    16'h0131,
    16'h06D3,
    16'h0C75,
    16'h1217,
    16'h17B9,
    16'h1D5B,
    16'h22FD,
    16'h289F,
    16'h2E41,
    16'h33E3,
    16'h3985,
    16'h3F27,
    16'h44C8,
    16'h4A6A,
    16'h500C,
    16'h55AE,
    16'h5B50,
    16'h60F2,
    16'h6694,
    16'h6C36,
    16'h71D8,
    16'h777A,
    16'h7D1C,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c6 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h853F,
    16'h8BC2,
    16'h9244,
    16'h98C7,
    16'h9F49,
    16'hA5CC,
    16'hAC4E,
    16'hB2D1,
    16'hB953,
    16'hBFD6,
    16'hC658,
    16'hCCDB,
    16'hD35E,
    16'hD9E0,
    16'hE063,
    16'hE6E5,
    16'hED68,
    16'hF3EA,
    16'hFA6D,
    16'h00EF,
    16'h0772,
    16'h0DF5,
    16'h1477,
    16'h1AFA,
    16'h217C,
    16'h27FF,
    16'h2E81,
    16'h3504,
    16'h3B86,
    16'h4209,
    16'h488C,
    16'h4F0E,
    16'h5591,
    16'h5C13,
    16'h6296,
    16'h6918,
    16'h6F9B,
    16'h761D,
    16'h7CA0,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c7 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8087,
    16'h8711,
    16'h8D9A,
    16'h9424,
    16'h9AAD,
    16'hA136,
    16'hA7C0,
    16'hAE49,
    16'hB4D3,
    16'hBB5C,
    16'hC1E5,
    16'hC86F,
    16'hCEF8,
    16'hD582,
    16'hDC0B,
    16'hE294,
    16'hE91E,
    16'hEFA7,
    16'hF631,
    16'hFCBA,
    16'h0343,
    16'h09CD,
    16'h1056,
    16'h16E0,
    16'h1D69,
    16'h23F2,
    16'h2A7C,
    16'h3105,
    16'h378F,
    16'h3E18,
    16'h44A1,
    16'h4B2B,
    16'h51B4,
    16'h583D,
    16'h5EC7,
    16'h6550,
    16'h6BDA,
    16'h7263,
    16'h78EC,
    16'h7F76,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c8 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h809D,
    16'h8764,
    16'h8E2B,
    16'h94F2,
    16'h9BB9,
    16'hA280,
    16'hA948,
    16'hB00F,
    16'hB6D6,
    16'hBD9D,
    16'hC464,
    16'hCB2B,
    16'hD1F2,
    16'hD8B9,
    16'hDF81,
    16'hE648,
    16'hED0F,
    16'hF3D6,
    16'hFA9D,
    16'h0164,
    16'h082B,
    16'h0EF2,
    16'h15B9,
    16'h1C81,
    16'h2348,
    16'h2A0F,
    16'h30D6,
    16'h379D,
    16'h3E64,
    16'h452B,
    16'h4BF2,
    16'h52BA,
    16'h5981,
    16'h6048,
    16'h670F,
    16'h6DD6,
    16'h749D,
    16'h7B64,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};

localparam logic signed [15:0] lut_c9 [0:64] = '{
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8000,
    16'h8382,
    16'h8826,
    16'h8CCA,
    16'h916F,
    16'h9613,
    16'h9AB7,
    16'h9F5C,
    16'hA400,
    16'hA8A4,
    16'hAD48,
    16'hB1ED,
    16'hB691,
    16'hBB35,
    16'hBFD9,
    16'hC47E,
    16'hC922,
    16'hCDC6,
    16'hD26B,
    16'hD70F,
    16'hDBB3,
    16'hE057,
    16'hE4FC,
    16'hE9A0,
    16'hEE44,
    16'hF2E8,
    16'hF78D,
    16'hFC31,
    16'h00D5,
    16'h057A,
    16'h0A1E,
    16'h0EC2,
    16'h1366,
    16'h180B,
    16'h1CAF,
    16'h2153,
    16'h25F8,
    16'h2A9C,
    16'h2F40,
    16'h33E4,
    16'h3889,
    16'h3D2D,
    16'h41D1,
    16'h4675,
    16'h4B1A,
    16'h4FBE,
    16'h5462,
    16'h5907,
    16'h5DAB,
    16'h624F,
    16'h66F3,
    16'h6B98,
    16'h703C,
    16'h74E0,
    16'h7984,
    16'h7E29,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF,
    16'h7FFF
};





    // Tra bảng LUT dựa vào popcount (0..64)
    logic signed [15:0] score_comb [0:9];
    assign score_comb[0] = lut_c0[pop_comb[0]];
    assign score_comb[1] = lut_c1[pop_comb[1]];
    assign score_comb[2] = lut_c2[pop_comb[2]];
    assign score_comb[3] = lut_c3[pop_comb[3]];
    assign score_comb[4] = lut_c4[pop_comb[4]];
    assign score_comb[5] = lut_c5[pop_comb[5]];
    assign score_comb[6] = lut_c6[pop_comb[6]];
    assign score_comb[7] = lut_c7[pop_comb[7]];
    assign score_comb[8] = lut_c8[pop_comb[8]];
    assign score_comb[9] = lut_c9[pop_comb[9]];

    // -------------------------------------------------------------
    // Pipeline Register Stage 1: Lưu kết quả ĐIỂM SCORE
    // -------------------------------------------------------------
    logic signed [15:0] score [0:9];
    logic               valid_stg1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int j = 0; j < 10; j++) score[j] <= 16'sd0;
            valid_stg1 <= 1'b0;
        end else begin
            valid_stg1 <= fc1_valid;
            if (fc1_valid) begin
                for (int j = 0; j < 10; j++) score[j] <= score_comb[j];
            end
        end
    end

    // -------------------------------------------------------------
    // 3. Argmax Tree: So sánh ĐIỂM SCORE (Pipeline 4 Stages)
    // -------------------------------------------------------------
    
    // Stage 1 Tree: 10 ứng viên -> 5 ứng viên
    logic signed [15:0] t1_val [0:4];
    logic [3:0]         t1_idx [0:4];
    logic               valid_t1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 5; k++) begin
                t1_val[k] <= 16'sd0;
                t1_idx[k] <= 4'd0;
            end
            valid_t1 <= 1'b0;
        end else begin
            valid_t1 <= valid_stg1;
            if (valid_stg1) begin
                for (int k = 0; k < 5; k++) begin
                    if (score[2*k] >= score[2*k+1]) begin
                        t1_val[k] <= score[2*k];
                        t1_idx[k] <= 4'(2*k);
                    end else begin
                        t1_val[k] <= score[2*k+1];
                        t1_idx[k] <= 4'(2*k+1);
                    end
                end
            end
        end
    end

    // Stage 2 Tree: 5 ứng viên -> 3 ứng viên
    logic signed [15:0] t2_val [0:2];
    logic [3:0]         t2_idx [0:2];
    logic               valid_t2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 3; k++) begin
                t2_val[k] <= 16'sd0;
                t2_idx[k] <= 4'd0;
            end
            valid_t2 <= 1'b0;
        end else begin
            valid_t2 <= valid_t1;
            if (valid_t1) begin
                // Cặp 1 (0 vs 1)
                if (t1_val[0] >= t1_val[1]) begin
                    t2_val[0] <= t1_val[0];
                    t2_idx[0] <= t1_idx[0];
                end else begin
                    t2_val[0] <= t1_val[1];
                    t2_idx[0] <= t1_idx[1];
                end

                // Cặp 2 (2 vs 3)
                if (t1_val[2] >= t1_val[3]) begin
                    t2_val[1] <= t1_val[2];
                    t2_idx[1] <= t1_idx[2];
                end else begin
                    t2_val[1] <= t1_val[3];
                    t2_idx[1] <= t1_idx[3];
                end

                // Nhánh lẻ (ứng viên thứ 5)
                t2_val[2] <= t1_val[4];
                t2_idx[2] <= t1_idx[4];
            end
        end
    end

    // Stage 3 Tree: 3 ứng viên -> 2 ứng viên
    logic signed [15:0] t3_val [0:1];
    logic [3:0]         t3_idx [0:1];
    logic               valid_t3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 2; k++) begin
                t3_val[k] <= 16'sd0;
                t3_idx[k] <= 4'd0;
            end
            valid_t3 <= 1'b0;
        end else begin
            valid_t3 <= valid_t2;
            if (valid_t2) begin
                if (t2_val[0] >= t2_val[1]) begin
                    t3_val[0] <= t2_val[0];
                    t3_idx[0] <= t2_idx[0];
                end else begin
                    t3_val[0] <= t2_val[1];
                    t3_idx[0] <= t2_idx[1];
                end

                t3_val[1] <= t2_val[2];
                t3_idx[1] <= t2_idx[2];
            end
        end
    end

    // Final Stage: Chọn Class có điểm số cao nhất
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            class_out <= 4'd0;
            fc2_valid <= 1'b0;
        end else begin
            fc2_valid <= valid_t3;
            if (valid_t3) begin
                if (t3_val[0] >= t3_val[1])
                    class_out <= t3_idx[0];
                else
                    class_out <= t3_idx[1];
            end
        end
    end

endmodule