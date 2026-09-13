`timescale 1ns/1ps

// ============================================================================
// File Name   : tb_bnn_top.sv
// Description : Self-checking Testbench for bnn_top module using 10 golden 
//               test vectors (test_img_X.txt and test_meta_X.txt).
// IEEE Std    : 1800-2017 compliant
// ============================================================================

module tb_bnn_top;

    // -------------------------------------------------------------
    // Clock & Reset Definitions
    // -------------------------------------------------------------
    localparam time CLK_PERIOD = 10ns; // 100 MHz System Clock

    logic       clk;
    logic       rst_n;

    // DUT Interface Signals
    logic       img_valid;
    logic       img_data;
    logic       sys_valid;
    logic [3:0] class_out;

    // Testbench Control Variables
    int         total_tests = 0;
    int         passed_tests = 0;
    int         failed_tests = 0;

    // Class Name Mapping for Debug Display
    string class_names [0:9] = '{
        "cup", "book", "television", "vase", "eye",
        "envelope", "knife", "basketball", "pizza", "bus"
    };

    // Memory Arrays for Loading Test Files
    logic       img_mem [0:1023];  // 32x32 = 1024 binary pixels
    int         exp_class_mem [0:0]; // Expected golden class ID from PyTorch

    // -------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------
    bnn_top u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .img_valid  (img_valid),
        .img_data   (img_data),
        .sys_valid  (sys_valid),
        .class_out  (class_out)
    );

    // -------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------
    // Reusable Tasks for Test Flow
    // -------------------------------------------------------------
    
    // Task 1: System Reset
    task automatic do_reset();
        begin
            rst_n     <= 1'b0;
            img_valid <= 1'b0;
            img_data  <= 1'b0;
            repeat (5) @(posedge clk);
            rst_n     <= 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask
// D:\SOC\backup_th_bnn\th_bnn
    // Task 2: Stream single 32x32 Image into BNN Pipeline
    task automatic send_image(input int img_idx);
        string img_file, meta_file;
        begin
            img_file  = $sformatf("....../test_img_%0d.txt", img_idx);
            meta_file = $sformatf("....../test_meta_%0d.txt", img_idx);

            // Read image pixels and expected metadata
            $readmemb(img_file, img_mem);
            $readmemh(meta_file, exp_class_mem);

            $display("[TB INFO] @ %0tps: Sending Test Vector #%0d | Target Class: %0d (%s)", 
                     $time, img_idx, exp_class_mem[0], 
                     (exp_class_mem[0] < 10) ? class_names[exp_class_mem[0]] : "UNKNOWN");

            // Stream 1024 pixels line-by-line
            for (int p = 0; p < 1024; p++) begin
                @(posedge clk);
                img_valid <= 1'b1;
                img_data  <= img_mem[p];
            end

            // De-assert valid after image transfer finishes
            @(posedge clk);
            img_valid <= 1'b0;
            img_data  <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------
    // Automated Checker (Monitors Output Class & Valid Signal)
    // -------------------------------------------------------------
    initial begin
        forever begin
            @(posedge clk);
            if (rst_n && sys_valid) begin
                total_tests++;
                if (class_out === exp_class_mem[0][3:0]) begin
                    $display("\n====================================================");
                    $display("[PASS] @ %0tps: Test #%0d MATCHED!", $time, total_tests - 1);
                    $display("       Expected Class : %0d (%s)", exp_class_mem[0], class_names[exp_class_mem[0]]);
                    $display("       BNN Hardware   : %0d (%s)", class_out, (class_out < 10) ? class_names[class_out] : "INVALID");
                    $display("====================================================\n");
                    passed_tests++;
                end else begin
                    $display("\n****************************************************");
                    $display("[FAIL] @ %0tps: Test #%0d MISMATCH!", $time, total_tests - 1);
                    $display("       Expected Class : %0d (%s)", exp_class_mem[0], class_names[exp_class_mem[0]]);
                    $display("       BNN Hardware   : %0d (%s)", class_out, (class_out < 10) ? class_names[class_out] : "INVALID");
                    $display("****************************************************\n");
                    failed_tests++;
                end
            end
        end
    end

    // -------------------------------------------------------------
    // Main Test Stimulus Sequence
    // -------------------------------------------------------------
    initial begin
        $display("\n====================================================");
        $display("   STARTING BNN TOP SYSTEM-LEVEL VERIFICATION      ");
        $display("====================================================");

        do_reset();

        // Sequential driving of 10 test vectors
        for (int i = 0; i < 10; i++) begin
            send_image(i);
            
            // Wait for BNN latency before driving next frame
            repeat (200) @(posedge clk);
        end

        // Final Wait to clear pipeline delays
        repeat (500) @(posedge clk);

        // Print Final Test Report Summary
        $display("\n====================================================");
        $display("              FINAL VERIFICATION REPORT             ");
        $display("====================================================");
        $display("  Total Tests Executed : %0d", total_tests);
        $display("  Passed Tests         : %0d", passed_tests);
        $display("  Failed Tests         : %0d", failed_tests);
        if (failed_tests == 0 && total_tests > 0) begin
            $display("  STATUS               : SUCCESS (100%% MATCH)");
        end else begin
            $display("  STATUS               : FAILURE / MISMATCH DETECTED");
        end
        $display("====================================================\n");

        $finish;
    end

endmodule