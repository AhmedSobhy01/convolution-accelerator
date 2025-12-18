module shift_register #(parameter SHIFT_SIZE = 4, DATA_WIDTH = 32)
(
    input wire clk,
    input wire rst,
    input wire [(SHIFT_SIZE*DATA_WIDTH)-1:0] in_data,
    output wire [(SHIFT_SIZE*DATA_WIDTH)-1:0] out_data
);

    localparam X = SHIFT_SIZE*DATA_WIDTH*(SHIFT_SIZE-1);
    reg [(SHIFT_SIZE*SHIFT_SIZE*DATA_WIDTH)-1:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg <= 0;
        end else begin
            shift_reg <= {shift_reg[X-1:0], in_data};
        end
    end

    // 0, 4, 8, ...
    // 0*SHIFT_SIZE + 0*DATA_WIDTH
    // 1*SHIFT_SIZE + 1*DATA_WIDTH
    // 2*SHIFT_SIZE + 2*DATA_WIDTH
    genvar k;
    generate
        for (k = 0; k < SHIFT_SIZE; k = k + 1) begin : out_gen
            assign out_data[k*DATA_WIDTH +: DATA_WIDTH] = shift_reg[(((SHIFT_SIZE - 1 - k) * SHIFT_SIZE + k) * DATA_WIDTH) +: DATA_WIDTH];
        end
    endgenerate

endmodule
