module ram_img (
    input  logic [9:0] address,
    input  logic       clock,
    input  logic       data,
    input  logic       wren,
    output logic       q
);

    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(1),
        .widthad_a(10),
        .numwords_a(1024),
        .outdata_reg_a("UNREGISTERED"),
        .ram_block_type("M9K"),
        // Bật tính năng In-System Memory Content Editor và gán id là IMG0
        .lpm_hint("ENABLE_RUNTIME_MOD=YES, INSTANCE_NAME=IMG0") 
    ) altsyncram_component (
        .address_a (address),
        .clock0    (clock),
        .data_a    (data),
        .wren_a    (wren),
        .q_a       (q)
    );

endmodule