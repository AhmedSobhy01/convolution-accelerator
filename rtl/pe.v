module pe #(parameter DATA_WIDTH = 32, parameter INPUT_WIDTH = 8)
(
    input wire clk,
    input wire rst,
    input wire load_kernel_signal,
    input wire [INPUT_WIDTH-1:0] in_input,
    input wire [INPUT_WIDTH-1:0] in_kernel,
    input wire [DATA_WIDTH-1:0] in_psum,
    output wire [DATA_WIDTH-1:0] out_psum,
    output wire [INPUT_WIDTH-1:0] out_input,
    output wire [INPUT_WIDTH-1:0] out_kernel
);
    reg [DATA_WIDTH-1:0] partial_sum = 0;
    reg [INPUT_WIDTH-1:0] top_reg;
    reg [INPUT_WIDTH-1:0] left_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            top_reg       <= 0;
            left_reg      <= 0;
        end else if (load_kernel_signal) begin
            top_reg     <= in_input;
            left_reg    <= in_kernel;
        end else begin
            top_reg       <= in_input;
            partial_sum   <= (left_reg * in_input) + in_psum;
        end
    end

    assign out_psum = partial_sum;
    assign out_input    = top_reg;
    assign out_kernel   = left_reg;

endmodule
