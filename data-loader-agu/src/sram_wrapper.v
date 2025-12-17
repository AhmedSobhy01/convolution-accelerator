module sram_1rw1r_64b_wrapper #(
  parameter ADDR_W = 11  // 2048 words -> 11 bits
)(
  input  wire             clk,

  // Power pins (forwarded to instantiated macros when used)
  `ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
  `endif

  // Port0: RW
  input  wire             p0_en,
  input  wire             p0_we,      // 1=write, 0=read
  input  wire [ADDR_W-1:0]p0_addr,
  input  wire [63:0]      p0_wdata,
  input  wire [7:0]       p0_wmask,   // 1 bit per byte
  output wire [63:0]      p0_rdata,

  // Port1: R
  input  wire             p1_en,
  input  wire [ADDR_W-1:0]p1_addr,
  output wire [63:0]      p1_rdata
);

  // Active-low macro signals (as in doc) [file:1]
  wire csb0 = ~p0_en;
  wire web0 = ~p0_we;          // macro: 0=write, 1=read [file:1]
  wire [7:0] wmask0 = p0_wmask; // depending on macro polarity; adjust to your macro
  wire csb1 = ~p1_en;

  // ---- Instantiate memory generator macro (match its port names) ----
  memory_generator_sky130 u_mem (
    `ifdef USE_POWER_PINS
      .vccd1  (vccd1),
      .vssd1  (vssd1),
    `endif
    .clk0      (clk),
    .csb0      (csb0),
    .web0      (web0),
    .wmask0    (wmask0),
    .port0_address (p0_addr),
    .port0_datain  (p0_wdata),
    .port0_dataout (p0_rdata),

    .clk1      (clk),
    .csb1      (csb1),
    .port1_address (p1_addr),
    .port1_dataout (p1_rdata)
  );

endmodule