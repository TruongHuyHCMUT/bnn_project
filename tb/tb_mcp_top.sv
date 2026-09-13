// ============================================================================
// File Name   : tb_mcp_top.sv
// Description : Complete self-checking testbench for mcp_top module.
//               Verifies window extraction (window4x4s2) integrated with 3
//               parallel processing elements across multiple image frames.
// IEEE Std    : 1800-2017 compliant
// ============================================================================

`timescale 1ns/1ps

module tb_mcp_top;

    // ------------------------------------------------------------------------
    // Parameters & Signals
    // ------------------------------------------------------------------------
    localparam time CLK_PERIOD = 20ns; // 50 MHz
    localparam int  IMG_WIDTH  = 32;
    localparam int  IMG_HEIGHT = 32;
    localparam int  IMG_PIXELS = IMG_WIDTH * IMG_HEIGHT; // 1024 bits

    logic        clk;
    logic        rst_n;
    logic        img_valid;
    logic        img_data;

    logic        mcp_valid;
    logic [2:0]  mcp_data_out;

    // Golden Reference Model Transaction
    typedef struct {
        logic [2:0] expected_data;
    } mcp_transaction_t;

    mcp_transaction_t exp_queue[$];

    // Verification Statistics
    int test_cases_run    = 0;
    int test_cases_passed = 0;
    int test_cases_failed = 0;

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------------------
    mcp_top dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .img_valid    (img_valid),
        .img_data     (img_data),
        .mcp_valid    (mcp_valid),
        .mcp_data_out (mcp_data_out)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Golden Reference Model Functions
    // ------------------------------------------------------------------------
    
    function automatic logic [4:0] compute_popcount(input logic [15:0] val);
        logic [4:0] count = '0;
        for (int b = 0; b < 16; b++) begin
            count += val[b];
        end
        return count;
    endfunction

    // Behavioral calculation matching mcp_pe logic
    function automatic logic compute_pe_out(
        input logic [15:0] win,
        input logic [15:0] wgt,
        input logic [16:0] thr
    );
        logic [15:0]        xnor_val;
        logic [4:0]         pop_cnt;
        logic               polarity;
        logic signed [15:0] thresh_val;
        logic signed [15:0] sum_signed;

        xnor_val   = ~(win ^ wgt);
        pop_cnt    = compute_popcount(xnor_val);
        polarity   = thr[16];
        thresh_val = thr[15:0];
        sum_signed = $signed({11'b0, pop_cnt});

        if (polarity) return (sum_signed >= thresh_val);
        else          return (sum_signed <= thresh_val);
    endfunction

    // Simulates window extraction and generates expected 3-bit outputs
    task automatic generate_golden_frame(input logic frame_pixels [0:1023]);
        logic [31:0] row1, row2, row3;
        logic [15:0] window;
        logic [15:0] formatted_window;
        int          col_cnt, row_cnt;

        row1 = '0; row2 = '0; row3 = '0; window = '0;
        col_cnt = 0; row_cnt = 0;

        for (int p = 0; p < IMG_PIXELS; p++) begin
            logic din = frame_pixels[p];

            // Update line buffers
            row1 = {row1[30:0], din};
            row2 = {row2[30:0], row1[31]};
            row3 = {row3[30:0], row2[31]};

            // Update 4x4 window
            window[15:13] = window[14:12]; window[12] = row3[31];
            window[11:9]  = window[10:8];  window[8]  = row2[31];
            window[7:5]   = window[6:4];   window[4]  = row1[31];
            window[3:1]   = window[2:0];   window[0]  = din;

            // Format window (Bit reversal matching PyTorch flatten alignment)
            formatted_window = {window[0],  window[1],  window[2],  window[3],
                                window[4],  window[5],  window[6],  window[7],
                                window[8],  window[9],  window[10], window[11],
                                window[12], window[13], window[14], window[15]};

            // Valid window logic (stride = 2)
            if (row_cnt >= 3 && col_cnt >= 3 && row_cnt[0] == 1'b1 && col_cnt[0] == 1'b1) begin
                mcp_transaction_t tr;
                tr.expected_data[0] = compute_pe_out(formatted_window, dut.mcp_weight[0], dut.mcp_thresh[0]);
                tr.expected_data[1] = compute_pe_out(formatted_window, dut.mcp_weight[1], dut.mcp_thresh[1]);
                tr.expected_data[2] = compute_pe_out(formatted_window, dut.mcp_weight[2], dut.mcp_thresh[2]);
                exp_queue.push_back(tr);
            end

            // Coordinate increment
            if (col_cnt == 31) begin
                col_cnt = 0;
                if (row_cnt == 31) row_cnt = 0;
                else               row_cnt++;
            end else begin
                col_cnt++;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Reusable Stimulus Tasks
    // ------------------------------------------------------------------------

    task automatic apply_reset();
        rst_n     <= 1'b0;
        img_valid <= 1'b0;
        img_data  <= 1'b0;
        repeat (5) @(posedge clk);
        #1ps;
        rst_n     <= 1'b1;
        repeat (2) @(posedge clk);
    endtask

    // Drives a full 1024-bit image frame into the DUT
    task automatic drive_image_frame(input logic frame_pixels [0:1023]);
        // Generate expected golden queue first
        generate_golden_frame(frame_pixels);

        for (int p = 0; p < IMG_PIXELS; p++) begin
            @(posedge clk);
            #1ps;
            img_valid <= 1'b1;
            img_data  <= frame_pixels[p];
        end

        @(posedge clk);
        #1ps;
        img_valid <= 1'b0;
        img_data  <= 1'b0;
    endtask

    // ------------------------------------------------------------------------
    // Self-Checking Monitor
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n && mcp_valid) begin
            automatic mcp_transaction_t tr;
            test_cases_run++;

            if (exp_queue.size() == 0) begin
                $error("[TB ERROR] Unexpected mcp_valid asserted without golden data!");
                test_cases_failed++;
            end else begin
                tr = exp_queue.pop_front();
                if (mcp_data_out === tr.expected_data) begin
                    $display("[PASS] Sample #%0d | Expected 3-bit: 3'b%03b, Got: 3'b%03b", 
                             test_cases_run, tr.expected_data, mcp_data_out);
                    test_cases_passed++;
                end else begin
                    $error("[FAIL] Sample #%0d | Expected 3-bit: 3'b%03b, Got: 3'b%03b (MISMATCH!)", 
                           test_cases_run, tr.expected_data, mcp_data_out);
                    test_cases_failed++;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Main Test Stimulus Sequence
    // ------------------------------------------------------------------------
    initial begin : main_proc
        automatic logic sample_frame [0:1023];

        $display("==========================================================");
        $display("   Starting Verification Environment for Module: mcp_top ");
        $display("==========================================================");

        apply_reset();

        // 1. All Zeros Frame
        $display("\n[TEST] 1. Driving All Zeros Image Frame");
        for (int i = 0; i < 1024; i++) sample_frame[i] = 1'b0;
        drive_image_frame(sample_frame);
        repeat (20) @(posedge clk);

        // 2. All Ones Frame
        $display("\n[TEST] 2. Driving All Ones Image Frame");
        for (int i = 0; i < 1024; i++) sample_frame[i] = 1'b1;
        drive_image_frame(sample_frame);
        repeat (20) @(posedge clk);

        // 3. Multi-Frame Consecutive Streaming Test
        $display("\n[TEST] 3. Driving 5 Consecutive Randomized Image Frames");
        for (int f = 0; f < 5; f++) begin
            $display("   --> Streaming Frame #%0d", f + 1);
            for (int i = 0; i < 1024; i++) sample_frame[i] = $urandom_range(0, 1);
            drive_image_frame(sample_frame);
            repeat ($urandom_range(5, 15)) @(posedge clk); // Variable inter-frame delay
        end

        // Wait for pipeline drain
        repeat (50) @(posedge clk);

        // Final Verification Summary Report
        $display("\n==========================================================");
        $display("                   SIMULATION SUMMARY                     ");
        $display("==========================================================");
        $display(" Total Valid Outputs Checked : %0d", test_cases_run);
        $display(" Tests Passed                : %0d", test_cases_passed);
        $display(" Tests Failed                : %0d", test_cases_failed);
        $display("==========================================================");

        if (test_cases_failed == 0 && test_cases_run > 0) begin
            $display(" RESULT: ALL TESTS PASSED SUCCESSFULLY!");
        end else begin
            $error(" RESULT: TESTBENCH FAILED WITH %0d ERRORS!", test_cases_failed);
        end

        $finish;
    end

endmodule