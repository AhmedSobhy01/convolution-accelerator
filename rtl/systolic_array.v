module systolic_array #(parameter DATA_WIDTH = 32,
                        parameter ARRAY_SIZE = 4,
                        parameter INPUT_WIDTH = 8)
                       (input wire clk,
                        input wire rst,
                        input wire load_kernel_signal,
                        input wire [INPUT_WIDTH-1:0] input_in [0:ARRAY_SIZE-1],
                        input wire [INPUT_WIDTH-1:0] kernel_in [0:ARRAY_SIZE-1],
                        output wire [DATA_WIDTH-1:0] out_data);
    
    reg [DATA_WIDTH-1:0] out_data_reg;
    wire [INPUT_WIDTH-1:0] pe_left_out [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [INPUT_WIDTH-1:0] pe_out [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    wire [DATA_WIDTH-1:0] pe_out_partials [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    
    genvar i, j;
    generate
    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : row
    for (j = 0; j < ARRAY_SIZE; j = j + 1) begin : col
    
    if (i == 0 && j == 0) begin : pe_00
    
    pe #(.DATA_WIDTH(DATA_WIDTH)) pe_inst (
    .clk(clk),
    .rst(rst),
    .load_kernel_signal(load_kernel_signal),
    .in_top(input_in[j]),
    .in_left(kernel_in[i]),
    .out_partial(pe_out_partials[i][j]),
    .out_down(pe_out[i][j]),
    .out_right(pe_left_out[i][j])
    );
    
    end else if (i == 0) begin : pe_top_row
    
    pe #(.DATA_WIDTH(DATA_WIDTH)) pe_inst (
    .clk(clk),
    .rst(rst),
    .load_kernel_signal(load_kernel_signal),
    .in_top(input_in[j]),
    .in_left(pe_left_out[i][j-1]),
    .out_partial(pe_out_partials[i][j]),
    .out_down(pe_out[i][j]),
    .out_right(pe_left_out[i][j])
    );
    
    end else if (j == 0) begin : pe_left_col
    
    pe #(.DATA_WIDTH(DATA_WIDTH)) pe_inst (
    .clk(clk),
    .rst(rst),
    .load_kernel_signal(load_kernel_signal),
    .in_top(
    .in_left(kernel_in[i]),
    .out_partial(pe_out_partials[i][j]),
    .out_down(pe_out[i][j]),
    .out_right(pe_left_out[i][j])
    );
    
    end else begin : pe_inner
    
    pe #(.DATA_WIDTH(DATA_WIDTH)) pe_inst (
    .clk(clk),
    .rst(rst),
    .load_kernel_signal(load_kernel_signal),
    .in_top(input_in[j]),
    .in_left(pe_left_out[i][j-1]),
    .out_partial(pe_out_partials[i][j]),
    .out_down(pe_out[i][j]),
    .out_right(pe_left_out[i][j])
    );
    
    end
    end
    end
    endgenerate
    
    assign out_data = out_data_reg;
endmodule
