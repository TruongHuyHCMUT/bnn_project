// ============================================================================
// File Name   : tb_mcp_pe.sv
// Description : Complete self-checking testbench for mcp_pe processing element
//               module. Verifies XNOR, Popcount, Dynamic Polarity Comparator,
//               and 2-stage pipeline latency.
// IEEE Std    : 1800-2017 compliant
// ============================================================================

`timescale 1ns/1ps

module tb_mcp_pe;

    // ------------------------------------------------------------------------
    // Clock & Reset Parameters
    // ------------------------------------------------------------------------
    localparam time CLK_PERIOD = 10ns;
    localparam int  LATENCY    = 2; // Pipeline latency: Stage 1 -> Stage 3

    // ------------------------------------------------------------------------
    // Signal Declarations
    // ------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    
    logic        valid_in;
    logic [15:0] window_in;
    logic [15:0] weight_in;
    logic [16:0] thresh_in;
    
    logic        valid_out;
    logic        data_out;

    // Transaction structure for reference queue
    typedef struct {
        logic [15:0] window;
        logic [15:0] weight;
        logic [16:0] thresh;
        logic        expected_data;
    } transaction_t;

    transaction_t exp_queue[$];

    // Verification Statistics
    int test_cases_run    = 0;
    int test_cases_passed = 0;
    int test_cases_failed = 0;

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------------------
    mcp_pe dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .window_in (window_in),
        .weight_in (weight_in),
        .thresh_in (thresh_in),
        .valid_out (valid_out),
        .data_out  (data_out)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Reference Model Functions
    // ------------------------------------------------------------------------
    
    // Calculates population count of 16-bit vector
    function automatic logic [4:0] compute_popcount(input logic [15:0] val);
        logic [4:0] count = '0;
        for (int b = 0; b < 16; b++) begin
            count += val[b];
        end
        return count;
    endfunction

    // Behavioral implementation of mcp_pe calculation logic
    function automatic logic compute_golden_output(
        input logic [15:0] win,
        input logic [15:0] wgt,
        input logic [16:0] thr
    );
        logic [15:0]        xnor_val;
        logic [4:0]         pop_cnt;
        logic               polarity;
        logic signed [15:0] thresh_val;
        logic signed [15:0] sum_signed;

        xnor_val   = ~(win ^ wgt); // Bitwise XNOR
        pop_cnt    = compute_popcount(xnor_val);
        polarity   = thr[16];
        thresh_val = thr[15:0];
        sum_signed = $signed({11'b0, pop_cnt});

        if (polarity) begin
            return (sum_signed >= thresh_val);
        end else begin
            return (sum_signed <= thresh_val);
        end
    endfunction

    // ------------------------------------------------------------------------
    // Reusable Stimulus Tasks
    // ------------------------------------------------------------------------
    
    // Asynchronous Reset Task
    task automatic apply_reset();
        rst_n     <= 1'b0;
        valid_in  <= 1'b0;
        window_in <= '0;
        weight_in <= '0;
        thresh_in <= '0;
        repeat (3) @(posedge clk);
        #1ps;
        rst_n     <= 1'b1;
        repeat (2) @(posedge clk);
    endtask

    // Drives a single test sample into the pipeline
    task automatic drive_sample(
        input logic [15:0] win,
        input logic [15:0] wgt,
        input logic [16:0] thr
    );
        transaction_t tr;

        @(posedge clk);
        #1ps; // Avoid hold time issues in simulation
        valid_in  <= 1'b1;
        window_in <= win;
        weight_in <= wgt;
        thresh_in <= thr;

        tr.window        = win;
        tr.weight        = wgt;
        tr.thresh        = thr;
        tr.expected_data = compute_golden_output(win, wgt, thr);
        exp_queue.push_back(tr);

        @(posedge clk);
        #1ps;
        valid_in  <= 1'b0;
        window_in <= '0;
        weight_in <= '0;
        thresh_in <= '0;
    endtask

    // ------------------------------------------------------------------------
    // Self-Checking Monitor
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n && valid_out) begin
            transaction_t tr;
            test_cases_run++;

            if (exp_queue.size() == 0) begin
                $error("[TB ERROR] Unexpected valid_out asserted without matching input!");
                test_cases_failed++;
            end else begin
                tr = exp_queue.pop_front();
                if (data_out === tr.expected_data) begin
                    $display("[PASS] Sample #%0d | Win: 0x%04X, Wgt: 0x%04X, Thr: 0x%05X | Expected: %0b, Got: %0b",
                             test_cases_run, tr.window, tr.weight, tr.thresh, tr.expected_data, data_out);
                    test_cases_passed++;
                end else begin
                    $error("[FAIL] Sample #%0d | Win: 0x%04X, Wgt: 0x%04X, Thr: 0x%05X | Expected: %0b, Got: %0b (MISMATCH!)",
                           test_cases_run, tr.window, tr.weight, tr.thresh, tr.expected_data, data_out);
                    test_cases_failed++;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // SystemVerilog Assertions (SVA)
    // ------------------------------------------------------------------------
    
    // Assertion 1: Valid pipeline latency check (2 clock cycles from valid_in to valid_out)
    property p_valid_latency;
        @(posedge clk) disable iff (!rst_n)
        valid_in |-> ##LATENCY valid_out;
    endproperty
    a_valid_latency: assert property (p_valid_latency)
        else $error("[ASSERTION FAILED] Pipeline latency mismatch! valid_out expected after %0d cycles.", LATENCY);

    // Assertion 2: Output data must not be 'X' or 'Z' when valid_out is active
    property p_no_unknown_out;
        @(posedge clk) disable iff (!rst_n)
        valid_out |-> !$isunknown(data_out);
    endproperty
    a_no_unknown_out: assert property (p_no_unknown_out)
        else $error("[ASSERTION FAILED] data_out contains unknown ('x' or 'z') state when valid_out is high!");

    // Assertion 3: Reset clears valid_out and data_out
    property p_reset_state;
        @(posedge clk) !rst_n |-> (valid_out == 1'b0 && data_out == 1'b0);
    endproperty
    a_reset_state: assert property (p_reset_state)
        else $error("[ASSERTION FAILED] Reset did not force valid_out and data_out to low!");

    // ------------------------------------------------------------------------
    // Main Test Stimulus Sequence
    // ------------------------------------------------------------------------
    initial begin
        $display("==========================================================");
        $display("   Starting Verification Environment for Module: mcp_pe  ");
        $display("==========================================================");

        apply_reset();

        // 1. Boundary Condition Tests
        $display("\n[TEST] 1. Boundary & Corner Cases");
        drive_sample(16'h0000, 16'h0000, 17'h10008); 
        drive_sample(16'hFFFF, 16'h0000, 17'h10008); 
        drive_sample(16'hAAAA, 16'h5555, 17'h10000); 

        // 2. Polarity Bit Testing
        $display("\n[TEST] 2. Dynamic Polarity Control");
        drive_sample(16'h00FF, 16'h00FF, {1'b1, 16'd10}); 
        drive_sample(16'h00FF, 16'h00FF, {1'b0, 16'd10}); 

        // 3. Exact Threshold Matching Tests
        $display("\n[TEST] 3. Exact Threshold Matching");
        drive_sample(16'hFF00, 16'hFFFF, {1'b1, 16'd8});
        drive_sample(16'hFF00, 16'hFFFF, {1'b1, 16'd9});

        // 4. Back-to-Back Pipeline Streaming Test
        $display("\n[TEST] 4. Back-to-Back Pipeline Streaming");
        for (int i = 0; i < 10; i++) begin
            automatic transaction_t tr;
            automatic logic [15:0] win_r = $urandom();
            automatic logic [15:0] wgt_r = $urandom();
            automatic logic [16:0] thr_r = {$urandom_range(0,1), 16'($urandom_range(0,16))};

            @(posedge clk);
            #1ps;
            valid_in  <= 1'b1;
            window_in <= win_r;
            weight_in <= wgt_r;
            thresh_in <= thr_r;

            tr.window        = win_r;
            tr.weight        = wgt_r;
            tr.thresh        = thr_r;
            tr.expected_data = compute_golden_output(win_r, wgt_r, thr_r);
            exp_queue.push_back(tr);
        end
        
        @(posedge clk);
        #1ps;
        valid_in  <= 1'b0;
        window_in <= '0;
        weight_in <= '0;
        thresh_in <= '0;

        // Wait for pipeline drain
        repeat (5) @(posedge clk);

        // 5. Mid-Operation Reset Testing
        $display("\n[TEST] 5. Mid-Operation Asynchronous Reset");
        drive_sample(16'h1234, 16'h5678, 17'h10004);
        repeat (1) @(posedge clk);
        apply_reset();
        exp_queue.delete(); // Flush expected queue due to reset action

        // Post-reset recovery test
        drive_sample(16'hABCD, 16'hABCD, 17'h1000A);
        repeat (5) @(posedge clk);

        // 6. Randomized Testing
        $display("\n[TEST] 6. Randomized Testing (50 Random Vectors)");
        repeat (50) begin
            automatic logic [15:0] win_rnd = $urandom();
            automatic logic [15:0] wgt_rnd = $urandom();
            automatic logic [16:0] thr_rnd = {$urandom_range(0,1), 16'($urandom_range(0,16))};
            
            drive_sample(win_rnd, wgt_rnd, thr_rnd);
            repeat ($urandom_range(0, 2)) @(posedge clk);
        end

        // Wait for final response drain
        repeat (10) @(posedge clk);

        // Final Report
        $display("\n==========================================================");
        $display("                   SIMULATION SUMMARY                     ");
        $display("==========================================================");
        $display(" Total Tests Executed : %0d", test_cases_run);
        $display(" Tests Passed         : %0d", test_cases_passed);
        $display(" Tests Failed         : %0d", test_cases_failed);
        $display("==========================================================");

        if (test_cases_failed == 0 && test_cases_run > 0) begin
            $display(" RESULT: ALL TESTS PASSED SUCCESSFULLY!");
        end else begin
            $error(" RESULT: TESTBENCH FAILED WITH %0d ERRORS!", test_cases_failed);
        end

        $finish;
    end

endmodule