`timescale 1ns/1ps

import fc1_constants::*;

module tb_fc1_top;

    // -------------------------------------------------------------
    // 1. Parameter & Signal Declarations
    // -------------------------------------------------------------
    localparam CLK_PERIOD = 20;  // 50 MHz Clock Period
    localparam NUM_PIXELS = 169; // 13x13 Feature Map Size

    logic        clk;
    logic        rst_n;

    // Input Interface Signals (from PW Layer)
    logic        pw_valid;
    logic [17:0] pw_data;

    // Output Interface Signals (to FC2 Layer)
    logic        pw_valid_out; // Valid out from top
    logic        fc1_valid;
    logic [63:0] fc1_data_out;

    // -------------------------------------------------------------
    // 2. Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------
    fc1_top u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .pw_valid     (pw_valid),
        .pw_data      (pw_data),
        .fc1_valid    (fc1_valid),
        .fc1_data_out (fc1_data_out)
    );

    // -------------------------------------------------------------
    // 3. Clock Generation (50 MHz)
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    // -------------------------------------------------------------
    // 4. Golden Model Math & Queue
    // -------------------------------------------------------------
    logic [63:0] expected_fc1_queue [$];

    // Computes the exact BNN response across all 64 neurons for 1 full image frame
    function automatic logic [63:0] calculate_golden_fc1(
        input logic [17:0] frame_data [0:168]
    );
        logic [63:0] golden_vector;
        logic [11:0] pop_acc;
        logic [17:0] xnor_res;
        logic signed [12:0] sum_bipolar;
        logic signed [15:0] sum_extended;
        logic polarity;
        logic signed [15:0] thresh_val;

        for (int n = 0; n < 64; n++) begin
            pop_acc = 12'd0;
            // 1. Accumulate Popcount across 169 pixels
            for (int p = 0; p < NUM_PIXELS; p++) begin
                xnor_res = ~(frame_data[p] ^ FC1_WEIGHTS[n][p * 18 +: 18]);
                pop_acc  = pop_acc + $countones(xnor_res);
            end

            // 2. Convert to Bipolar Math: Sum = 2*P - 3042
            sum_bipolar  = $signed({1'b0, pop_acc} << 1) - 13'sd3042;
            sum_extended = $signed({{3{sum_bipolar[12]}}, sum_bipolar});

            // 3. Evaluate Polarity Bit & Threshold Comparison
            polarity   = FC1_THRESH[n][16];
            thresh_val = $signed(FC1_THRESH[n][15:0]);

            if (polarity)
                golden_vector[n] = (sum_extended >= thresh_val) ? 1'b1 : 1'b0;
            else
                golden_vector[n] = (sum_extended <= thresh_val) ? 1'b1 : 1'b0;
        end
        return golden_vector;
    endfunction

    // -------------------------------------------------------------
    // 5. Driver Task
    // -------------------------------------------------------------
    task send_image_frame();
        logic [17:0] current_frame [0:168];
        logic [17:0] rand_pw;

        for (int p = 0; p < NUM_PIXELS; p++) begin
            rand_pw = $urandom() & 18'h3FFFF; // Random 18-bit binary channel
            current_frame[p] = rand_pw;

            @(negedge clk);
            pw_valid <= 1'b1;
            pw_data  <= rand_pw;
        end

        // Push calculated golden response of the entire image to queue
        expected_fc1_queue.push_back(calculate_golden_fc1(current_frame));

        @(negedge clk);
        pw_valid <= 1'b0;
        pw_data  <= 18'b0;
    endtask

    // -------------------------------------------------------------
    // 6. Main Test Scenario
    // -------------------------------------------------------------
    int total_images = 0;
    int pass_cnt     = 0;
    int fail_cnt     = 0;

    initial begin
        pw_valid <= 1'b0;
        pw_data  <= 18'b0;
        rst_n    <= 1'b0;

        // Hold Reset for 5 Clock Cycles
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING FC1_TOP LAYER SIMULATION");
        $display("==================================================");

        // Stream 10 complete image frames (10 x 169 = 1690 streaming cycles)
        for (int img = 0; img < 10; img++) begin
            $display("[TEST] Streaming Image Frame #%0d (169 Pixels)...", img + 1);
            send_image_frame();
            repeat(5) @(posedge clk); // Gap between images
        end

        // Allow Extra Cycles for Final Accumulator Pipeline Register
        repeat(20) @(posedge clk);

        $display("\n==================================================");
        $display("   FC1_TOP SIMULATION SUMMARY REPORT");
        $display("==================================================");
        $display(" Total Image Vectors Evaluated : %0d (Expected: 10)", total_images);
        $display(" Passed Matches                : %0d", pass_cnt);
        $display(" Failed Mismatches             : %0d", fail_cnt);

        if (fail_cnt == 0 && total_images == 10)
            $display("\n ==> SUCCESS: FC1_TOP Output Matches Golden BNN Math Perfectly!");
        else
            $display("\n ==> ERROR: Math or Pipeline Mismatch Detected in FC1_TOP!");

        $finish;
    end

    // -------------------------------------------------------------
    // 7. Self-Checking Monitor
    // -------------------------------------------------------------
    logic [63:0] exp_vector;

    always @(posedge clk) begin
        if (rst_n && fc1_valid) begin
            total_images++;
            exp_vector = expected_fc1_queue.pop_front();

            if (fc1_data_out === exp_vector) begin
                pass_cnt++;
                $display("[PASS] Image #%0d | Output = 64'h%16X (Matches Golden)", total_images, fc1_data_out);
            end else begin
                fail_cnt++;
                $display("[FAIL] Image #%0d | HW: 64'h%16X | Exp: 64'h%16X <--- MISMATCH!", 
                         total_images, fc1_data_out, exp_vector);
            end
        end
    end

endmodule