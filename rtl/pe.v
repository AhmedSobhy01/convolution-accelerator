module pe #( DATA_WIDTH = 32, INPUT_WIDTH = 8 ) (
    input  wire  clk,
    input  wire  rst,
    input  wire  load_kernel_signal,
    input  wire[INPUT_WIDTH - 1: 0]  in_top,
    input  wire[INPUT_WIDTH - 1: 0]  in_left,
    output wire[DATA_WIDTH-1:0] out_partial,
    output wire[INPUT_WIDTH - 1: 0] out_down,
    output wire[INPUT_WIDTH - 1: 0] out_right
);
    
reg [DATA_WIDTH-1:0] product;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        product <= 0;
    end else if (load_kernel_signal) begin
        product <= in_left * in_top;
    end
end

assign out_partial = product;
assign out_down = in_top;
assign out_right = in_left;

endmodule
