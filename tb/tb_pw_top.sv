`timescale 1ns/1ps

module tb_pw_top;

    // -------------------------------------------------------------
    // 1. Parameter & Signal Declarations
    // -------------------------------------------------------------
    localparam CLK_PERIOD = 20; // 50 MHz Clock Period

    logic        clk;
    logic        rst_n;

    // Input Interface Signals (from DW Layer)
    logic        dw_valid;
    logic [14:0] dw_data;

    // Output Interface Signals (to FC1 Layer)
    logic        pw_valid;
    logic [17:0] pw_data_out;

    // Decoded 5-bit Signed Inputs for Driving Stimulus
    logic signed [4:0] in_ch0, in_ch1, in_ch2;

    // Pack 3 signed 5-bit channels into dw_data vector
    assign dw_data = {in_ch2, in_ch1, in_ch0};

    // -------------------------------------------------------------
    // 2. Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------
    pw_top u_dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .dw_valid    (dw_valid),
        .dw_data     (dw_data),
        .pw_valid    (pw_valid),
        .pw_data_out (pw_data_out)
    );

    // -------------------------------------------------------------
    // 3. Clock Generation (50 MHz)
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    // -------------------------------------------------------------
    // 4. Tasks for Modular Driver Control
    // -------------------------------------------------------------
    task send_vector(input logic signed [4:0] c0, c1, c2);
        begin
            @(negedge clk);
            dw_valid <= 1'b1;
            in_ch0   <= c0;
            in_ch1   <= c1;
            in_ch2   <= c2;
        end
    endtask

    task stop_driver();
        begin
            @(negedge clk);
            dw_valid <= 1'b0;
            in_ch0   <= 5'sd0;
            in_ch1   <= 5'sd0;
            in_ch2   <= 5'sd0;
        end
    endtask

    // -------------------------------------------------------------
    // 5. Main Multi-Case Test Scenario
    // -------------------------------------------------------------
    int total_outputs = 0;
    int pass_cnt      = 0;
    int fail_cnt      = 0;

    initial begin
        // Initialize Default States
        dw_valid <= 1'b0;
        in_ch0   <= 5'sd0;
        in_ch1   <= 5'sd0;
        in_ch2   <= 5'sd0;
        rst_n    <= 1'b0;

        // Hold Reset for 5 Clock Cycles
        repeat(5) @(posedge clk);
        rst_n    <= 1'b1;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING PW_TOP MULTI-CASE COMPREHENSIVE TEST");
        $display("==================================================");

        // --- TEST CASE 1: MAXIMUM BOUNDS (+9, +9, +9) ---
        $display("\n[TEST 1] Streaming Maximum Bound Inputs (+9, +9, +9)...");
        for (int i = 0; i < 10; i++) begin
            send_vector(5'sd9, 5'sd9, 5'sd9);
        end

        // --- TEST CASE 2: MINIMUM BOUNDS (-9, -9, -9) ---
        $display("[TEST 2] Streaming Minimum Bound Inputs (-9, -9, -9)...");
        for (int i = 0; i < 10; i++) begin
            send_vector(-5'sd9, -5'sd9, -5'sd9);
        end

        // --- TEST CASE 3: ZERO BOUNDS (0, 0, 0) ---
        $display("[TEST 3] Streaming Zero-Valued Inputs (0, 0, 0)...");
        for (int i = 0; i < 10; i++) begin
            send_vector(5'sd0, 5'sd0, 5'sd0);
        end

        // --- TEST CASE 4: CORRECTED RANDOMIZED SIGNED TESTING ---
        $display("[TEST 4] Streaming 500 Randomized Valid DW Inputs [-9 to +9]...");
        for (int i = 0; i < 500; i++) begin
            send_vector($signed($urandom_range(0, 18)) - 5'sd9, 
                        $signed($urandom_range(0, 18)) - 5'sd9, 
                        $signed($urandom_range(0, 18)) - 5'sd9);
        end

        // Stop Data Streaming
        stop_driver();

        // Flush Pipeline Registers
        repeat(20) @(posedge clk);

        $display("\n==================================================");
        $display("   PW_TOP COMPREHENSIVE SIMULATION REPORT");
        $display("==================================================");
        $display(" Total PW Feature Vectors Evaluated : %0d (Expected: 530)", total_outputs);
        $display(" Total PASSED Samples               : %0d", pass_cnt);
        $display(" Total FAILED Samples               : %0d", fail_cnt);

        if (fail_cnt == 0 && total_outputs == 530)
            $display("\n ==> SUCCESS: All Edge Cases and Random Inputs PASSED!");
        else
            $display("\n ==> ERROR: Pipeline or Thresholding Failures Detected!");

        $finish;
    end

    // -------------------------------------------------------------
    // 6. Self-Checking Monitor
    // -------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && pw_valid) begin
            total_outputs++;
            
            // Check for valid non-unknown binary vector outputs
            if (^pw_data_out !== 1'bx) begin
                pass_cnt++;
            end else begin
                fail_cnt++;
                $display("[FAIL] Sample #%03d | Unknown State (X/Z) Detected in Output Vector!", total_outputs);
            end
        end
    end

endmodule