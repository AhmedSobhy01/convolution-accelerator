`timescale 1ns/1ps

module sram0_mux_load_tb_or_stream #(
  parameter ADDR_W = 10
)(
  input  wire mode_stream, // 0: loader owns p0, TB owns p1.  1: streamer owns p0+p1.

  // --- Loader drives Port0 (RW) ---
  input  wire              l_p0_en,
  input  wire              l_p0_we,
  input  wire [ADDR_W-1:0] l_p0_addr,
  input  wire [63:0]       l_p0_wdata,
  input  wire [7:0]        l_p0_wmask,

  // --- TB readback drives Port1 (R-only) ---
  input  wire              tb_p1_en,
  input  wire [ADDR_W-1:0] tb_p1_addr,

  // --- Streamer drives Port0+Port1 (both READ) ---
  input  wire              s_p0_en,
  input  wire              s_p0_we,
  input  wire [ADDR_W-1:0] s_p0_addr,
  input  wire [63:0]       s_p0_wdata,
  input  wire [7:0]        s_p0_wmask,

  input  wire              s_p1_en,
  input  wire [ADDR_W-1:0] s_p1_addr,

  // --- To SRAM wrapper ---
  output reg               m_p0_en,
  output reg               m_p0_we,
  output reg  [ADDR_W-1:0] m_p0_addr,
  output reg  [63:0]       m_p0_wdata,
  output reg  [7:0]        m_p0_wmask,

  output reg               m_p1_en,
  output reg  [ADDR_W-1:0] m_p1_addr
);

  always @(*) begin
    // defaults
    m_p0_en    = 1'b0;
    m_p0_we    = 1'b0;
    m_p0_addr  = {ADDR_W{1'b0}};
    m_p0_wdata = 64'd0;
    m_p0_wmask = 8'h00;

    m_p1_en    = 1'b0;
    m_p1_addr  = {ADDR_W{1'b0}};

    if (!mode_stream) begin
      // mode 0: loader writes via p0, TB reads via p1
      m_p0_en    = l_p0_en;
      m_p0_we    = l_p0_we;
      m_p0_addr  = l_p0_addr;
      m_p0_wdata = l_p0_wdata;
      m_p0_wmask = l_p0_wmask;

      m_p1_en    = tb_p1_en;
      m_p1_addr  = tb_p1_addr;
    end else begin
      // mode 1: streamer uses both ports (reads)
      m_p0_en    = s_p0_en;
      m_p0_we    = s_p0_we;
      m_p0_addr  = s_p0_addr;
      m_p0_wdata = s_p0_wdata;
      m_p0_wmask = s_p0_wmask;

      m_p1_en    = s_p1_en;
      m_p1_addr  = s_p1_addr;
    end
  end

endmodule
