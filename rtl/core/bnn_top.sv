module bnn_top (
    input  logic        clk,
    input  logic        rst_n,

    // Stream hình ảnh ngõ vào
    input  logic        img_valid,
    input  logic        img_data, 
    
    // Kết quả phân loại toàn hệ thống (0 -> 9)
    output logic        sys_valid,
    output logic [3:0]  class_out    
);

    // -------------------------------------------------------------
    // Internal Interconnect Signals
    // -------------------------------------------------------------
    logic        mcp_valid;
    logic [2:0]  mcp_data;
    
    logic        dw_valid;
    logic [14:0] dw_data;
    
    logic        pw_valid;
    logic [17:0] pw_data;
    
    logic        fc1_valid;
    logic [63:0] fc1_data; // SỬA: Sửa từ 64-bit thành 32-bit để khớp u_fc1 và u_fc2

    // -------------------------------------------------------------
    // 1. Merged Conv-Pool Layer (MCP)
    // -------------------------------------------------------------
    mcp_top u_mcp (
        .clk          (clk),
        .rst_n        (rst_n),
        .img_valid    (img_valid),
        .img_data     (img_data),
        .mcp_valid    (mcp_valid),
        .mcp_data_out (mcp_data)
    );

    // -------------------------------------------------------------
    // 2. Depthwise Conv Layer (DW)
    // -------------------------------------------------------------
    dw_top u_dw (
        .clk          (clk),
        .rst_n        (rst_n),
        .mcp_valid    (mcp_valid),
        .mcp_data     (mcp_data),
        .dw_valid     (dw_valid),
        .dw_data_out  (dw_data)
    );

    // -------------------------------------------------------------
    // 3. Pointwise Conv Layer (PW)
    // -------------------------------------------------------------
    pw_top u_pw (
        .clk          (clk),
        .rst_n        (rst_n),
        .dw_valid     (dw_valid),
        .dw_data      (dw_data),
        .pw_valid     (pw_valid),
        .pw_data_out  (pw_data)
    );

    // -------------------------------------------------------------
    // 4. Fully-Connected Layer 1 (FC1 - Folded 32 Neurons)
    // -------------------------------------------------------------
    fc1_top u_fc1 (
        .clk          (clk),
        .rst_n        (rst_n),
        .pw_valid     (pw_valid),
        .pw_data      (pw_data),
        .fc1_valid    (fc1_valid),
        .fc1_data_out (fc1_data)   // Output 64-bit
    );

    // -------------------------------------------------------------
    // 5. Fully-Connected Layer 2 (FC2 - Pure BNN Classifier)
    // -------------------------------------------------------------
    fc2_top u_fc2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .fc1_valid    (fc1_valid),
        .fc1_data_in  (fc1_data),   // Input 64-bit
        .fc2_valid    (sys_valid),
        .class_out    (class_out)  // Output 4-bit (Class 0 -> 9)
    );

endmodule