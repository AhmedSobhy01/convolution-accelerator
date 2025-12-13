module pe #(parameter DATA_WIDTH = 32, parameter INPUT_WIDTH = 8)
(
    input wire clk,
    input wire rst,
    input wire load_kernel_signal,
    input wire [INPUT_WIDTH-1:0] in_input,
    input wire [INPUT_WIDTH-1:0] in_kernel,
    output wire [DATA_WIDTH-1:0] out_psum,
    output wire [INPUT_WIDTH-1:0] out_input,
    output wire [INPUT_WIDTH-1:0] out_kernel,
);
    reg [DATA_WIDTH-1:0] partial_sum;
    reg [INPUT_WIDTH-1:0] kernel_reg;
    reg [INPUT_WIDTH-1:0] top_reg;
    reg [INPUT_WIDTH-1:0] left_reg;
    reg kernel_loaded;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            partial_sum   <= 0;
            kernel_reg    <= 0;
            top_reg       <= 0;
            left_reg      <= 0;
            kernel_loaded <= 0;
        end else if (load_kernel_signal) begin
            if (!kernel_loaded && (in_kernel != 0)) begin
                kernel_reg    <= in_kernel;
                kernel_loaded <= 1;
            end
            top_reg     <= in_input;
            left_reg    <= in_kernel;
            partial_sum <= partial_sum + kernel_reg * in_input;
        end else begin
            partial_sum   <= partial_sum + kernel_reg * in_input;
            top_reg       <= in_input;
            kernel_loaded <= 0;
        end
    end

    assign out_psum = partial_sum;
    assign out_input    = top_reg;
    assign out_kernel   = left_reg;

endmodule
