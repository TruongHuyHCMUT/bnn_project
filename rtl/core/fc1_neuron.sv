module fc1_neuron (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        pw_valid,
    input  logic [7:0]  pixel_cnt,    // Scan from 0 to 168 (169 pixels)
    input  logic [17:0] pw_data,      // 18 binary channels from PW Layer
    
    input  logic [17:0] weight_fm,    // 18-bit Weight for current pixel
    input  logic [16:0] thresh_in,    // 17-bit Threshold (Bit [16] = Polarity)
    
    output logic        valid_out,
    output logic        data_out      // 1-bit binary output result
);

    // -------------------------------------------------------------
    // 1. MAC Stage: XNOR + Popcount 18-bit
    // -------------------------------------------------------------
    logic [17:0] xnor_fm;
    logic [4:0]  pop_fm;

    // Bipolar multiplication: XNOR gate replaces AND
    assign xnor_fm = ~(pw_data ^ weight_fm);

    // 18-bit Popcount core (returns 0 to 18)
    popcount #(
        .WIDTH(18)
    ) pc_fm (
        .i_data  (xnor_fm),
        .o_count(pop_fm)
    );

    // -------------------------------------------------------------
    // 2. Accumulator Register (Accumulate P across 169 pixels)
    // -------------------------------------------------------------
    logic [11:0] acc; // Max value: 169 x 18 = 3042 (12 bits unsigned)
    logic        compute_done;
    logic [16:0] thresh_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc          <= 12'd0;
            compute_done <= 1'b0;
            thresh_reg   <= 17'd0;
        end else begin
            compute_done <= 1'b0;
            if (pw_valid) begin
                if (pixel_cnt == 8'd0) begin
                    acc <= {7'd0, pop_fm}; // Load first pixel count
                end else if (pixel_cnt == 8'd168) begin
                    acc          <= acc + pop_fm; // Final pixel count
                    compute_done <= 1'b1;         // Trigger completion
                    thresh_reg   <= thresh_in;
                end else begin
                    acc <= acc + pop_fm; // Accumulate pixel count
                end
            end
        end
    end

    // -------------------------------------------------------------
    // 3. Bipolar Conversion & Threshold Comparison (Fix Timing Mismatch)
    // -------------------------------------------------------------
    logic               polarity;
    logic signed [15:0] thresh_value;
    logic signed [13:0] sum_bipolar;
    logic signed [15:0] sum_extended;
    logic               data_out_t;

    assign polarity     = thresh_reg[16];
    assign thresh_value = $signed(thresh_reg[15:0]);

    // Sum = 2 * P - 3042 (Range: [-3042, +3042])
    assign sum_bipolar  = $signed({1'b0, acc} << 1) - 14'sd3042;
    assign sum_extended = $signed({{2{sum_bipolar[13]}}, sum_bipolar});

    // Flexible comparison based on Polarity bit
    assign data_out_t = polarity ? (sum_extended >= thresh_value) 
                                 : (sum_extended <= thresh_value);

    // -------------------------------------------------------------
    // Output Register Stage
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            data_out  <= 1'b0;
        end else begin
            valid_out <= compute_done;
            if (compute_done) begin
                data_out <= data_out_t;
            end
        end
    end

endmodule