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
                .out_psum(32'd0),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else if (i == 0) begin : pe_top_row
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(input_in[j*INPUT_WIDTH +: INPUT_WIDTH]),
                .in_kernel(32'd0),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else if (j == 0) begin : pe_left_col
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_input[i-1][ARRAY_SIZE-1]),
                .in_kernel(kernel_in[i*INPUT_WIDTH +: INPUT_WIDTH]),
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
                .in_kernel(pe_kernel_out[i-1][j]),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end else begin : pe_inner
                pe #(.DATA_WIDTH(DATA_WIDTH), .INPUT_WIDTH(INPUT_WIDTH)) pe_inst (
                .clk(clk),
                .rst(rst),
                .load_kernel_signal(load_kernel_signal),
                .in_input(pe_input[i-1][j-1]),
                .in_kernel(pe_kernel_out[i-1][j]),
                .out_psum(pe_out_psum[i][j]),
                .out_input(pe_input[i][j]),
                .out_kernel(pe_kernel_out[i][j])
                );
            end
        end
    end
    endgenerate

    genvar i;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] last_row_flat;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] sum_partials;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            assign last_row_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = pe_out_psum[ARRAY_SIZE-1][i];
        end
    endgenerate


    shift_register #(.SHIFT_SIZE(ARRAY_SIZE), .DATA_WIDTH(INPUT_WIDTH)) input_shift_reg (
        .clk(clk),
        .rst(rst),
        .in_data(last_row_flat),
        .out_data(sum_partials)
    );

    // split sum_partials to 3 DATA_WIDTH parts and sum them
    genvar k;
    wire [DATA_WIDTH-1:0] final_sum;
    generate
        for (k = 0; k < ARRAY_SIZE; k = k + 1) begin : sum_loop
            assign final_sum = final_sum + sum_partials[(k+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    assign out_data = rst ? {DATA_WIDTH{1'b0}} : sum_partials;
endmodule
