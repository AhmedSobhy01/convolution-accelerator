`timescale 1ns/1ps

module sram0_1rw1r_64x1024_wrapper (
  input  wire         clk,

  inout vccd1,
  inout vssd1,

  // Port0 RW (active-high enables in your RTL)
  input  wire         p0_en,
  input  wire         p0_we,        // 1=write, 0=read  (RTL convention)
  input  wire [9:0]   p0_addr,      // 1024 words -> 10 bits
  input  wire [63:0]  p0_wdata,
  input  wire [7:0]   p0_wmask,     // 1 bit per byte
  output wire [63:0]  p0_rdata,

  // Port1 R
  input  wire         p1_en,
  input  wire [9:0]   p1_addr,
  output wire [63:0]  p1_rdata
);

  // Generated SRAM uses active-low control (as in course doc) [file:1]
  wire csb0 = ~p0_en;
  wire web0 = ~p0_we;      // macro: 0=write, 1=read [file:1]
  wire csb1 = ~p1_en;

  memory_generator_sky130_64_1024_2 u_sram0 (
    .vccd1(vccd1),
    .vssd1(vssd1),

    .clk0(clk),
    .csb0(csb0),
    .web0(web0),
    .wmask0(p0_wmask),
    .port0_address(p0_addr),
    .port0_datain(p0_wdata),
    .port0_dataout(p0_rdata),

    .clk1(clk),
    .csb1(csb1),
    .port1_address(p1_addr),
    .port1_dataout(p1_rdata)
  );

endmodule
