module systolic_array #(parameter DATA_WIDTH = 32, parameter ARRAY_SIZE = 4, parameter INPUT_WIDTH = 8)
(
    input wire clk,
    input wire rst,
    input wire load_kernel_signal,
    input wire [(INPUT_WIDTH*ARRAY_SIZE)-1:0] input_in,
    input wire [(INPUT_WIDTH*ARRAY_SIZE)-1:0] kernel_in,
    output wire [DATA_WIDTH-1:0] out_data
);

    wire [INPUT_WIDTH-1:0] pe_left_out [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [INPUT_WIDTH-1:0] pe_out [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [DATA_WIDTH-1:0] pe_out_partials [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    genvar i, j;
    generate
    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : row
        for (j = 0; j < ARRAY_SIZE; j = j + 1) begin : col
            if (i == 0 && j == 0) begin : pe_00
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(input_in[0 +: INPUT_WIDTH]),
                .in_kernel(kernel_in[0 +: INPUT_WIDTH]),
                .in_psum(pe_out_partials[i][j+1]),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end else if (i == 0 && j == ARRAY_SIZE - 1) begin : pe_top_right
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(input_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_kernel(kernel_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_psum({DATA_WIDTH{1'b0}}),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end else if (i == 0) begin : pe_top_row
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(input_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_kernel(kernel_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_psum(pe_out_partials[i][j+1]),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end else if (j == 0) begin : pe_left_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_out[i-1][j]),
                .in_kernel(pe_left_out[i-1][j]),
                .in_psum(pe_out_partials[i][j+1]),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end else if (j == ARRAY_SIZE - 1) begin : pe_right_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_out[i-1][j]),
                .in_kernel(pe_left_out[i-1][j]),
                .in_psum({DATA_WIDTH{1'b0}}),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end else begin : pe_inner
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_out[i-1][j]),
                .in_kernel(pe_left_out[i-1][j]),
                .in_psum(pe_out_partials[i][j+1]),
                .out_psum(pe_out_partials[i][j]),
                .out_input(pe_out[i][j]),
                .out_kernel(pe_left_out[i][j])
                );
            end
        end
    end
    endgenerate

    reg [DATA_WIDTH-1:0] sum_partials;
    integer n;
    always @(*) begin
        sum_partials = {DATA_WIDTH{1'b0}};
        for (n = 0; n < ARRAY_SIZE; n = n + 1) begin
            sum_partials = sum_partials + pe_out_partials[n][0];
        end
    end

    assign out_data = rst ? {DATA_WIDTH{1'b0}} : sum_partials;
endmodule
