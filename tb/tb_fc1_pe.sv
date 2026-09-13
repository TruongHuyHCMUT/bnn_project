`timescale 1ns/1ps

module tb_fc1_neuron;

    // -------------------------------------------------------------
    // 1. Signal Declarations
    // -------------------------------------------------------------
    logic        clk;
    logic        rst_n;

    logic        pw_valid;
    logic [7:0]  pixel_cnt;   // Quét từ 0 đến 168 (169 pixels)
    logic [17:0] pw_data;     // 18-bit binary input từ PW Layer
    logic [17:0] weight_fm;   // 18-bit Weight của pixel hiện tại
    logic [16:0] thresh_in;   // Bit [16] = Polarity, Bits [15:0] = Threshold

    logic        valid_out;
    logic        data_out;

    // -------------------------------------------------------------
    // 2. DUT Instantiation
    // -------------------------------------------------------------
    fc1_neuron u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .pw_valid   (pw_valid),
        .pixel_cnt  (pixel_cnt),
        .pw_data    (pw_data),
        .weight_fm  (weight_fm),
        .thresh_in  (thresh_in),
        .valid_out  (valid_out),
        .data_out   (data_out)
    );

    // -------------------------------------------------------------
    // 3. Clock Generation (50 MHz)
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk; // 20ns Clock Period
    end

    // -------------------------------------------------------------
    // 4. Golden Model Math & Queue
    // -------------------------------------------------------------
    logic expected_queue [$];

    // Hàm tính toán toán học BNN chính xác cho 1 neuron đơn lẻ qua 169 pixels
    function automatic logic calculate_golden_neuron(
        input logic [17:0] data_stream [0:168],
        input logic [17:0] weight_stream [0:168],
        input logic [16:0] th
    );
        logic [11:0] pop_acc = 12'd0;
        logic [17:0] xnor_res;
        logic signed [13:0] sum_bipolar;
        logic signed [15:0] sum_extended;
        logic polarity;
        logic signed [15:0] thresh_val;

        // 1. Tích lũy Popcount của phép XNOR qua 169 pixels
        for (int p = 0; p < 169; p++) begin
            xnor_res = ~(data_stream[p] ^ weight_stream[p]);
            pop_acc  = pop_acc + $countones(xnor_res);
        end

        // 2. Chuyển đổi Bipolar: Sum = 2*P - 3042
        sum_bipolar  = $signed({1'b0, pop_acc} << 1) - 14'sd3042;
        sum_extended = $signed({{2{sum_bipolar[13]}}, sum_bipolar});

        // 3. So sánh Ngưỡng có xét Polarity Bit
        polarity   = th[16];
        thresh_val = $signed(th[15:0]);

        if (polarity)
            return (sum_extended >= thresh_val) ? 1'b1 : 1'b0;
        else
            return (sum_extended <= thresh_val) ? 1'b1 : 1'b0;
    endfunction

    // Task bơm 1 khung ảnh (169 pixels) vào neuron
    task send_neuron_frame(
        input logic [16:0] test_thresh
    );
        logic [17:0] frame_data [0:168];
        logic [17:0] frame_weight [0:168];

        for (int p = 0; p < 169; p++) begin
            frame_data[p]   = $urandom() & 18'h3FFFF;
            frame_weight[p] = $urandom() & 18'h3FFFF;

            @(negedge clk);
            pw_valid  <= 1'b1;
            pixel_cnt <= p[7:0];
            pw_data   <= frame_data[p];
            weight_fm <= frame_weight[p];
            thresh_in <= test_thresh;
        end

        // Đẩy kết quả kỳ vọng vào FIFO queue
        expected_queue.push_back(calculate_golden_neuron(frame_data, frame_weight, test_thresh));

        @(negedge clk);
        pw_valid  <= 1'b0;
        pixel_cnt <= 8'd0;
    endtask

    // -------------------------------------------------------------
    // 5. Main Test Scenario
    // -------------------------------------------------------------
    int total_tests = 0;
    int pass_cnt    = 0;
    int fail_cnt    = 0;

    initial begin
        // Reset ngõ vào
        pw_valid  <= 1'b0;
        pixel_cnt <= 8'd0;
        pw_data   <= 18'b0;
        weight_fm <= 18'b0;
        thresh_in <= 17'b0;
        rst_n     <= 1'b0;

        // Giữ Reset trong 5 chu kỳ clock
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING UNIT TESTBENCH FOR FC1_NEURON");
        $display("==================================================");

        // --- SPECIAL CASE 1: Polarity = 1 (>= Threshold) ---
        $display("\n[TEST 1] Streaming Frame with Polarity 1 (>= Threshold)...");
        send_neuron_frame({1'b1, 16'sd100});

        // --- SPECIAL CASE 2: Polarity = 0 (<= Threshold) ---
        $display("[TEST 2] Streaming Frame with Polarity 0 (<= Threshold)...");
        send_neuron_frame({1'b0, -16'sd500});

        // --- RANDOM CASES: Bơm 20 khung ảnh ngẫu nhiên ---
        $display("\n[RANDOM TESTING] Running 20 Randomized Image Frames...");
        for (int i = 0; i < 20; i++) begin
            send_neuron_frame($urandom() & 17'h1FFFF);
            repeat(2) @(posedge clk); // Khoảng nghỉ giữa các ảnh
        end

        // Dừng bơm
        repeat(10) @(posedge clk);

        $display("\n==================================================");
        $display("   FC1_NEURON UNIT TEST SUMMARY REPORT");
        $display("==================================================");
        $display(" Total Frame Evaluations : %0d (Expected: 22)", total_tests);
        $display(" Passed Matches          : %0d", pass_cnt);
        $display(" Failed Mismatches       : %0d", fail_cnt);

        if (fail_cnt == 0 && total_tests == 22)
            $display("\n ==> SUCCESS: fc1_neuron matches Golden BNN Math Perfectly!");
        else
            $display("\n ==> ERROR: Math Mismatch Detected in fc1_neuron!");

        $finish;
    end

    // -------------------------------------------------------------
    // 6. Self-Checking Monitor
    // -------------------------------------------------------------
    logic exp_bit;

    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            total_tests++;
            exp_bit = queue.pop_front();

            if (data_out === exp_bit) begin
                pass_cnt++;
                $display("[PASS] Frame #%02d | Output = %b (Matches Golden Exp)", total_tests, data_out);
            end else begin
                fail_cnt++;
                $display("[FAIL] Frame #%02d | HW Out: %b | Golden Exp: %b <--- MISMATCH!", 
                         total_tests, data_out, exp_bit);
            end
        end
    end

endmodule