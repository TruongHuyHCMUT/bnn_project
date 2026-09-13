`timescale 1ns/1ps

module tb_pw_pe_comprehensive;

    // -------------------------------------------------------------
    // 1. Signal Declarations
    // -------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    
    logic        i_valid;
    logic signed [4:0] i_dw_out_0, i_dw_out_1, i_dw_out_2; // 5-bit Signed (-9 to +9)
    logic [2:0]  i_weight;    // 3-bit BNN Weights (1 = +1, 0 = -1)
    logic [16:0] i_threshold; // Bit [16] = Polarity, Bits [15:0] = Threshold Value

    logic        o_valid;
    logic        o_data;

    // -------------------------------------------------------------
    // 2. DUT Instantiation
    // -------------------------------------------------------------
    pw_pe u_dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .i_valid     (i_valid),
        .i_dw_out_0  (i_dw_out_0),
        .i_dw_out_1  (i_dw_out_1),
        .i_dw_out_2  (i_dw_out_2),
        .i_weight    (i_weight),
        .i_threshold (i_threshold),
        .o_valid     (o_valid),
        .o_data      (o_data)
    );

    // -------------------------------------------------------------
    // 3. Clock Generation (50 MHz)
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk; // 20ns Clock Period
    end

    // -------------------------------------------------------------
    // 4. Golden Model Math Calculator & Pipeline Synchronization
    // -------------------------------------------------------------
    logic expected_queue [$];

    function automatic logic calculate_golden_pe(
        input logic signed [4:0] c0, c1, c2,
        input logic [2:0]  w,
        input logic [16:0] th
    );
        logic signed [6:0] term0, term1, term2, sum;
        logic polarity;
        logic signed [15:0] thresh_val;

        // Bipolar Multiply: Weight Bit = 1 -> +1, Weight Bit = 0 -> -1
        term0 = w[0] ? $signed(c0) : -$signed(c0);
        term1 = w[1] ? $signed(c1) : -$signed(c1);
        term2 = w[2] ? $signed(c2) : -$signed(c2);

        sum = term0 + term1 + term2;

        polarity   = th[16];
        thresh_val = $signed(th[15:0]);

        // Flexible comparison based on Polarity bit [16]
        if (polarity)
            return ($signed(sum) >= thresh_val) ? 1'b1 : 1'b0;
        else
            return ($signed(sum) <= thresh_val) ? 1'b1 : 1'b0;
    endfunction

    // Task to drive stimulus and automatically compute expected answer
    task send_pe_vector(
        input logic signed [4:0] c0, c1, c2,
        input logic [2:0]  w,
        input logic [16:0] th
    );
        begin
            @(negedge clk);
            i_valid     <= 1'b1;
            i_dw_out_0  <= c0;
            i_dw_out_1  <= c1;
            i_dw_out_2  <= c2;
            i_weight    <= w;
            i_threshold <= th;

            // Push calculated golden response to FIFO queue
            expected_queue.push_back(calculate_golden_pe(c0, c1, c2, w, th));
        end
    endtask

    // -------------------------------------------------------------
    // 5. Main Test Scenario (Special Cases + Random Cases)
    // -------------------------------------------------------------
    int total_tests = 0;
    int pass_cnt    = 0;
    int fail_cnt    = 0;

    initial begin
        // Reset Inputs
        i_valid     <= 1'b0;
        i_dw_out_0  <= 5'sd0;
        i_dw_out_1  <= 5'sd0;
        i_dw_out_2  <= 5'sd0;
        i_weight    <= 3'b0;
        i_threshold <= 17'b0;
        rst_n       <= 1'b0;

        // Hold Reset for 5 Clock Cycles
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING COMPREHENSIVE TESTBENCH FOR PW_PE");
        $display("==================================================");

        // --- SPECIAL CASE 1: Max Positive Bounds (+9, +9, +9), Sum = +27 ---
        $display("\n[SPECIAL CASE 1] Testing Max Positive Bounds (+9, +9, +9)...");
        send_pe_vector(5'sd9, 5'sd9, 5'sd9, 3'b111, {1'b1, 16'd20}); // 27 >= 20 -> Exp: 1
        send_pe_vector(5'sd9, 5'sd9, 5'sd9, 3'b111, {1'b1, 16'd30}); // 27 >= 30 -> Exp: 0

        // --- SPECIAL CASE 2: Min Negative Bounds (-9, -9, -9), Sum = -27 ---
        $display("[SPECIAL CASE 2] Testing Min Negative Bounds (-9, -9, -9)...");
        send_pe_vector(-5'sd9, -5'sd9, -5'sd9, 3'b111, {1'b1, -16'sd20}); // -27 >= -20 -> Exp: 0
        send_pe_vector(-5'sd9, -5'sd9, -5'sd9, 3'b000, {1'b1, 16'd20});  // Bipolar flip: +27 >= 20 -> Exp: 1

        // --- SPECIAL CASE 3: Polarity 0 (<= Threshold Comparison) ---
        $display("[SPECIAL CASE 3] Testing Polarity 0 (<= Threshold)...");
        send_pe_vector(5'sd4, 5'sd4, 5'sd4, 3'b111, {1'b0, 16'd15}); // 12 <= 15 -> Exp: 1
        send_pe_vector(5'sd4, 5'sd4, 5'sd4, 3'b111, {1'b0, 16'd10}); // 12 <= 10 -> Exp: 0

        // --- SPECIAL CASE 4: Zero Boundary Inputs (0, 0, 0) ---
        $display("[SPECIAL CASE 4] Testing Zero-Valued Inputs (0, 0, 0)...");
        send_pe_vector(5'sd0, 5'sd0, 5'sd0, 3'b101, {1'b1, 16'd0}); // 0 >= 0 -> Exp: 1

        // --- RANDOM CASES: 300 Randomized Stimuli ---
        $display("\n[RANDOM TESTING] Running 300 Randomized Test Vectors...");
        for (int i = 0; i < 300; i++) begin
            send_pe_vector(
                $signed($urandom_range(0, 18)) - 5'sd9, // Random -9 to +9
                $signed($urandom_range(0, 18)) - 5'sd9,
                $signed($urandom_range(0, 18)) - 5'sd9,
                $urandom_range(0, 7),                  // Random 3-bit Weight
                $urandom() & 17'h1FFFF                 // Random 17-bit Polarity + Threshold
            );
        end

        // Stop Driving Data
        @(negedge clk);
        i_valid <= 1'b0;

        // Flush Pipeline Registers
        repeat(10) @(posedge clk);

        $display("\n==================================================");
        $display("   PW_PE COMPREHENSIVE TEST SUMMARY REPORT");
        $display("==================================================");
        $display(" Total Vectors Evaluated : %0d (Expected: 307)", total_tests);
        $display(" Passed Matches          : %0d", pass_cnt);
        $display(" Failed Mismatches       : %0d", fail_cnt);

        if (fail_cnt == 0 && total_tests == 307)
            $display("\n ==> SUCCESS: pw_pe hardware matches Golden BNN Math perfectly across all Special & Random Cases!");
        else
            $display("\n ==> ERROR: Math Mismatch Detected in pw_pe!");

        $finish;
    end

    // -------------------------------------------------------------
    // 6. Self-Checking Output Monitor
    // -------------------------------------------------------------
    logic exp_bit;

    always @(posedge clk) begin
        if (rst_n && o_valid) begin
            total_tests++;
            exp_bit = expected_queue.pop_front();

            if (o_data === exp_bit) begin
                pass_cnt++;
                $display("[PASS] Vector #%03d | HW Out: %b | Golden Exp: %b", total_tests, o_data, exp_bit);
            end else begin
                fail_cnt++;
                $display("[FAIL] Vector #%03d | HW Out: %b | Golden Exp: %b <--- MISMATCH!", total_tests, o_data, exp_bit);
            end
        end
    end

endmodule