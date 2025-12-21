module pe #(parameter DATA_WIDTH = 32, parameter INPUT_WIDTH = 8)
(
    input wire clk,
    input wire rst,
    input wire pe_enable,
    input wire load_kernel_signal,
    input wire [INPUT_WIDTH-1:0] in_top,
    input wire [INPUT_WIDTH-1:0] in_left,
    output wire [DATA_WIDTH-1:0] out_partial,
    output wire [INPUT_WIDTH-1:0] out_down,
    output wire [INPUT_WIDTH-1:0] out_right
);
    reg [INPUT_WIDTH-1:0] top_reg;
    reg [INPUT_WIDTH-1:0] left_reg;

    always @(negedge clk) begin
        if (rst) begin
            top_reg       <= 0;
            left_reg      <= 0;
        end else if (pe_enable) begin
            if (load_kernel_signal) begin
                top_reg     <= in_top;
                left_reg    <= in_left;
            end else begin
                top_reg       <= in_top;
            end
        end
    end

    // Operand isolation: zero output when PE is idle to reduce switching power
    assign out_partial = pe_enable ? (left_reg * top_reg) : {DATA_WIDTH{1'b0}};
    assign out_down    = top_reg;
    assign out_right   = left_reg;

endmodule

