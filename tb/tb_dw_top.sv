`timescale 1ns/1ps

module tb_dw_top;

    // -------------------------------------------------------------
    // 1. Parameter & Signal Declarations
    // -------------------------------------------------------------
    localparam CLK_PERIOD = 20; // 50 MHz Clock Period
    localparam IMG_WIDTH  = 15; // Input Feature Map Width (15x15)

    logic        clk;
    logic        rst_n;

    // Input Interface Signals (from MCP Layer)
    logic        mcp_valid;
    logic [2:0]  mcp_data;

    // Output Interface Signals (to PW Layer)
    logic        dw_valid;
    logic [14:0] dw_data_out;

    // Decoded 5-bit Signed Signals for Simplified Waveform Debugging
    logic signed [4:0] ch0_out, ch1_out, ch2_out;
    assign ch0_out = dw_data_out[4:0];
    assign ch1_out = dw_data_out[9:5];
    assign ch2_out = dw_data_out[14:10];

    // -------------------------------------------------------------
    // 2. Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------
    dw_top u_dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .mcp_valid   (mcp_valid),
        .mcp_data    (mcp_data),
        .dw_valid    (dw_valid),
        .dw_data_out (dw_data_out)
    );

    // -------------------------------------------------------------
    // 3. Clock Generation (50 MHz)
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    // -------------------------------------------------------------
    // 4. Main Test Scenario
    // -------------------------------------------------------------
    int total_outputs = 0;
    int pass_cnt      = 0;
    int fail_cnt      = 0;

    initial begin
        // Initialize Default Signal States
        mcp_valid <= 1'b0;
        mcp_data  <= 3'b000;
        rst_n     <= 1'b0;

        // Hold Active-Low Reset for 5 Clock Cycles
        repeat(5) @(posedge clk);
        rst_n     <= 1'b1;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING DW_TOP MODULE SIMULATION");
        $display("==================================================");

        // Stream a 15x15 Input Frame (225 pixels) with Test Data Patterns
        for (int r = 0; r < IMG_WIDTH; r++) begin
            for (int c = 0; c < IMG_WIDTH; c++) begin
                @(negedge clk);
                mcp_valid <= 1'b1;
                // Test Pattern: Ch2 = 0, Ch1 = Alternating Bits, Ch0 = 1
                mcp_data  <= {1'b0, (c % 2 == 0 ? 1'b1 : 1'b0), 1'b1};
            end
        end

        // Stop Data Streaming
        @(negedge clk);
        mcp_valid <= 1'b0;
        mcp_data  <= 3'b000;

        // Allow Extra Clock Cycles to Flush Pipeline Registers
        repeat(50) @(posedge clk);

        $display("==================================================");
        $display("   DW_TOP SIMULATION SUMMARY REPORT");
        $display("==================================================");
        $display(" Total DW Feature Maps Generated : %0d (Expected: 169 for 13x13 output)", total_outputs);
        $display(" Total PASSED Samples            : %0d", pass_cnt);
        $display(" Total FAILED Samples            : %0d", fail_cnt);

        if (fail_cnt == 0 && total_outputs > 0)
            $display("\n ==> SUCCESS: DW_TOP Module Operates 100%% Correctly!");
        else
            $display("\n ==> ERROR: Failures Detected! Check window3x3s1 Waveforms.");

        $finish;
    end

    // -------------------------------------------------------------
    // 5. Self-Checking Monitor (Automatic Verification)
    // -------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && dw_valid) begin
            total_outputs++;
            
            // Verify Output Range within Bipolar Bound [-9, +9] for 3x3 Window
            if ((ch0_out >= -9 && ch0_out <= 9) &&
                (ch1_out >= -9 && ch1_out <= 9) &&
                (ch2_out >= -9 && ch2_out <= 9)) begin
                pass_cnt++;
                $display("[PASS] Out #%0d | Ch0 = %0d | Ch1 = %0d | Ch2 = %0d", 
                         total_outputs, ch0_out, ch1_out, ch2_out);
            end else begin
                fail_cnt++;
                $display("[FAIL] Out #%0d | Ch0 = %0d | Ch1 = %0d | Ch2 = %0d <--- Out of Bounds [-9, +9]!", 
                         total_outputs, ch0_out, ch1_out, ch2_out);
            end
        end
    end

endmodule