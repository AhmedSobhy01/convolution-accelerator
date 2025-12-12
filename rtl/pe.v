module pe #(parameter DATA_WIDTH = 32,
            parameter INPUT_WIDTH = 8)
           (input wire clk,
            input wire rst,
            input wire load_kernel_signal,
            input wire [INPUT_WIDTH-1:0] in_top,
            input wire [INPUT_WIDTH-1:0] in_left,
            output wire [DATA_WIDTH-1:0] out_partial,
            output wire [INPUT_WIDTH-1:0] out_down,
            output wire [INPUT_WIDTH-1:0] out_right);

    reg [DATA_WIDTH-1:0] partial_sum;
    reg [INPUT_WIDTH-1:0] kernel_reg;
    reg [INPUT_WIDTH-1:0] top_reg;
    reg [INPUT_WIDTH-1:0] left_reg;

    reg kernel_loaded;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            partial_sum      <= 0;
            kernel_reg       <= 0;
            top_reg          <= 0;
            left_reg         <= 0;
            kernel_loaded    <= 0;
        end else if (load_kernel_signal) begin
            if (!kernel_loaded && (in_left != 0)) begin
                kernel_reg    <= in_left;
                kernel_loaded <= 1;
            end
            left_reg         <= in_left;
        end else begin
            partial_sum      <= kernel_reg * in_top;
            top_reg          <= in_top;
            left_reg         <= in_left;
            kernel_loaded    <= 0;
        end
    end

    assign out_partial = partial_sum;
    assign out_down    = top_reg;
    assign out_right   = left_reg;

endmodule
