`timescale 1ns/1ps

module sram1_1rw1r_32x4096_wrapper (
  input  wire         clk,

  `ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
  `endif

  // Port0 RW
  input  wire         p0_en,
  input  wire         p0_we,        // 1=write, 0=read
  input  wire [11:0]  p0_addr,      // 4096 words -> 12 bits
  input  wire [31:0]  p0_wdata,
  input  wire [3:0]   p0_wmask,     // 1 bit per byte
  output wire [31:0]  p0_rdata,

  // Port1 R
  input  wire         p1_en,
  input  wire [11:0]  p1_addr,
  output wire [31:0]  p1_rdata
);

  wire csb0 = ~p0_en;
  wire web0 = ~p0_we;     // macro: 0=write, 1=read [file:1]
  wire csb1 = ~p1_en;

  memory_generator_sky130_32_4096_1 u_sram1 (
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif

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
