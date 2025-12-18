module systolic_array #(parameter DATA_WIDTH = 32, parameter ARRAY_SIZE = 4, parameter INPUT_WIDTH = 8)
(
    input wire clk,
    input wire rst,
    input wire load_kernel_signal,
    input wire [(INPUT_WIDTH*ARRAY_SIZE)-1:0] input_in,
    input wire [(INPUT_WIDTH*ARRAY_SIZE)-1:0] kernel_in,
    output wire [DATA_WIDTH-1:0] out_data
);

    wire [INPUT_WIDTH-1:0] pe_kernel_out [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [INPUT_WIDTH-1:0] pe_input [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [DATA_WIDTH-1:0] pe_out_psum [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

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
                .in_psum(0),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else if (i == 0) begin : pe_top_row
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(input_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_kernel(pe_kernel_out[i][j-1]),
                .in_psum(0),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else if (j == 0) begin : pe_left_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_input[i-1][j+1]),
                .in_kernel(kernel_in[i*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_psum(pe_out_psum[i-1][j]),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else if (j == ARRAY_SIZE-1) begin : pe_right_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_input[i-1][0]),
                .in_kernel(pe_kernel_out[i][j-1]),
                .in_psum(pe_out_psum[i-1][j]),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else begin : pe_inner
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_input[i-1][j+1]),
                .in_kernel(pe_kernel_out[i][j-1]),
                .in_psum(pe_out_psum[i-1][j]),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end
        end
    end
    endgenerate

    wire [ARRAY_SIZE*DATA_WIDTH-1:0] last_row_flat;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] sum_partials;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            assign last_row_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = pe_out_psum[ARRAY_SIZE-1][i];
        end
    endgenerate


    shift_register #(.SHIFT_SIZE(ARRAY_SIZE), .DATA_WIDTH(DATA_WIDTH)) input_shift_reg (
        .clk(clk),
        .rst(rst),
        .in_data(last_row_flat),
        .out_data(sum_partials)
    );

    // sum_partials now is DATA_WIDTH*ARRAY_SIZE bits
    // We need to sum every DATA_WIDTH bits together
    reg [DATA_WIDTH-1:0] sum_reg;
    integer k;
    always @(*) begin
        sum_reg = 0;
        for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
            sum_reg = sum_reg + sum_partials[k*DATA_WIDTH +: DATA_WIDTH];
        end
    end

    assign out_data = rst ? {DATA_WIDTH{1'b0}} : sum_reg;
endmodule
