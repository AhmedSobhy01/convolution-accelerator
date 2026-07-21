`timescale 1ns/1ps

// Black box stub for sky130_sram_2kbyte_1rw1r_32x512_8
// 32-bit wide, 512 words, 1RW + 1R ports.
// Power pins are declared unconditionally so this model is used as the macro's
// synthesis netlist view (MACROS.nl); it lets USE_POWER_PINS-driven connections
// in the memory generator resolve, putting vccd1/vssd1 into the netlist.
(* blackbox *)
module sky130_sram_2kbyte_1rw1r_32x512_8(
    vccd1,
    vssd1,
    clk0, csb0, web0, wmask0, addr0, din0, dout0,
    clk1, csb1, addr1, dout1
);

    inout vccd1;
    inout vssd1;
    input  clk0;
    input  csb0;
    input  web0;
    input  [3:0] wmask0;
    input  [8:0] addr0;
    input  [31:0] din0;
    output [31:0] dout0;
    input  clk1;
    input  csb1;
    input  [8:0] addr1;
    output [31:0] dout1;

endmodule
