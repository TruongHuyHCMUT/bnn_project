module dw_pe (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_valid,
    input  logic [8:0]  i_window, 
    input  logic [8:0]  i_weight, 

    // Output to Pointwise Conv (PW Layer)
    output logic        o_valid,
    output logic signed [4:0] o_data 
);

    // Stage 1 Registers
    logic [8:0] xnor_result;
    logic       valid1;

    // -------------------------------------------------------------
    // Stage 1: XNOR Operation
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xnor_result <= 9'b0;
            valid1      <= 1'b0;
        end else begin
            valid1 <= i_valid;
            if (i_valid) begin
                xnor_result <= ~(i_window ^ i_weight); 
            end
        end
    end

    // -------------------------------------------------------------
    // Stage 2: Popcount & Bipolar Conversion (Sum = 2P - 9)
    // -------------------------------------------------------------
    logic [3:0] pop_cnt;

    // Gọi Popcount cho 9 bits
    popcount #(
        .WIDTH(9)
    ) u_popcount (
        .i_data (xnor_result),
        .o_count(pop_cnt)
    );

    // Sum = P x (+1) + (9 - P) x (-1) = 2P - 9
    // Range: [-9, +9] -> 5-bit Signed
    logic signed [4:0] sum_bipolar;
    assign sum_bipolar = $signed({1'b0, pop_cnt} << 1) - 5'sd9;

    // -------------------------------------------------------------
    // Output Stage
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_data  <= 5'sd0;
            o_valid <= 1'b0;
        end else begin
            o_valid <= valid1;
            if (valid1) begin
                o_data <= sum_bipolar;
            end
        end
    end

endmodule