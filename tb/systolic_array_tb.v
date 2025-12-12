`timescale 1ns/1ps

module systolic_array_tb; localparam integer DATA_WIDTH = 32; localparam integer ARRAY_SIZE = 3; localparam integer INPUT_WIDTH = 8; localparam integer INPUT_DEPTH = ARRAY_SIZE*ARRAY_SIZE; reg clk; reg rst; reg load_kernel_signal; reg [INPUT_WIDTH * ARRAY_SIZE -1:0] input_in; reg [INPUT_WIDTH * ARRAY_SIZE -1:0] kernel_in; wire [DATA_WIDTH-1:0] out_data; systolic_array #(.DATA_WIDTH(DATA_WIDTH)
                                                                                                                                                                                                                                                                                                                                                                                   , .ARRAY_SIZE(ARRAY_SIZE), .INPUT_WIDTH(INPUT_WIDTH)) dut (.clk(clk), .rst(rst), .load_kernel_signal(load_kernel_signal), .input_in(input_in), .kernel_in(kernel_in), .out_data(out_data));
    
    reg [INPUT_WIDTH * ARRAY_SIZE -1:0] kernel_vectors [0:ARRAY_SIZE-1];
    reg [INPUT_WIDTH * ARRAY_SIZE -1:0] input_vectors  [0:INPUT_DEPTH-1];
    
    integer idx;
    
    initial begin
        clk            = 1'b0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        kernel_vectors[0] = 21'h00095; // decimal: 149
        kernel_vectors[1] = 21'h0012A; // decimal: 298
        kernel_vectors[2] = 21'h001B4; // decimal: 436
        kernel_vectors[3] = 21'h0023C; // decimal: 572
        
        input_vectors[0] = 21'h00033;  // decimal: 51
        input_vectors[1] = 21'h00055;  // decimal: 85
        input_vectors[2] = 21'h00077;  // decimal: 119
        input_vectors[3] = 21'h00099;  // decimal: 153
        input_vectors[4] = 21'h000BB;  // decimal: 187
        input_vectors[5] = 21'h000DD;  // decimal: 221
        input_vectors[6] = 21'h000F0;  // decimal: 240
        input_vectors[7] = 21'h00111;  // decimal: 273
        input_vectors[8] = 21'h00133;  // decimal: 307
    end
    
    initial begin
        rst                = 1'b1;
        load_kernel_signal = 1'b0;
        input_in           = {(INPUT_WIDTH * ARRAY_SIZE -1){1'b0}};
        kernel_in          = {(INPUT_WIDTH * ARRAY_SIZE -1){1'b0}};
        
        repeat (3) @(posedge clk);
        rst = 1'b0;
        
        @(posedge clk);
        load_kernel_signal = 1'b1;
        @(posedge clk);
        for (idx = 0; idx < ARRAY_SIZE; idx = idx + 1) begin
            kernel_in = kernel_vectors[idx];
            @(posedge clk);
        end
        @(posedge clk);
        load_kernel_signal = 1'b0;
        
        for (idx = 0; idx < INPUT_DEPTH; idx = idx + 1) begin
            input_in = input_vectors[idx];
            @(posedge clk);
        end
        
        repeat (ARRAY_SIZE*2) @(posedge clk);
        // $finish;
    end
    
    always @(posedge clk) begin
        $display("%0t | load = %0b in = %0h kernel = %0h -> out = %0h", $time, load_kernel_signal, input_in, kernel_in, out_data);
    end
    
    // initial begin
    //     $dumpfile("systolic_array_tb.vcd");
    //     $dumpvars(0, systolic_array_tb);
    // end
endmodule
