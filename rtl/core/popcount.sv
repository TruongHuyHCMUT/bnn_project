module popcount #(
    parameter int WIDTH = 9
) (
    input logic [WIDTH - 1: 0]  i_data, 
    output logic [$clog2(WIDTH+1)-1:0] o_count 
);
    logic [$clog2(WIDTH+1)-1:0] temp_sum;
    integer i;

    always_comb begin
        temp_sum = '0; 

        for (i = 0; i < WIDTH; i = i + 1) begin
            temp_sum = temp_sum + i_data[i];
        end
        o_count = temp_sum;
    end
endmodule 