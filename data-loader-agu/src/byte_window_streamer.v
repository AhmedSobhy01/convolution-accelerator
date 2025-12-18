`timescale 1ns/1ps

module byte_window_streamer #(
  parameter ADDR_W = 10
)(
  input  wire              clk,
  input  wire              rst_n,

  // Request: one per cycle in steady state if req_ready=1
  input  wire              req_valid,
  output wire              req_ready,
  input  wire [15:0]       req_base_byte,
  input  wire [3:0]        req_len,        // 0..8 (0 => all zeros)

  // SRAM0 dual-port (both used for READ)
  output reg               sram_p0_en,
  output reg               sram_p0_we,      // 0=read
  output reg  [ADDR_W-1:0] sram_p0_addr,
  output reg  [63:0]       sram_p0_wdata,
  output reg  [7:0]        sram_p0_wmask,
  input  wire [63:0]       sram_p0_rdata,

  output reg               sram_p1_en,
  output reg  [ADDR_W-1:0] sram_p1_addr,
  input  wire [63:0]       sram_p1_rdata,

  // Response (1-cycle latency from accepted request)
  output reg               out_valid,
  input  wire              out_ready,
  output reg  [63:0]       out_data
);

  // Accept a new request only if output stage is free or being consumed
  assign req_ready = (~out_valid) | out_ready;
  wire fire = req_valid & req_ready;

  // stage0 metadata (delayed 1 cycle to match SRAM rdata)
  reg        fire_d;
  reg [2:0]  off_d;
  reg [3:0]  len_d;

  wire [ADDR_W-1:0] word_addr0 = req_base_byte[15:3];
  wire [ADDR_W-1:0] word_addr1 = word_addr0 + {{(ADDR_W-1){1'b0}}, 1'b1};
  wire [2:0]         byte_off  = req_base_byte[2:0];

  // Drive SRAM ports from accepted request
  always @(*) begin
    sram_p0_en    = fire;
    sram_p0_we    = 1'b0;      // read
    sram_p0_addr  = word_addr0;
    sram_p0_wdata = 64'd0;
    sram_p0_wmask = 8'h00;

    sram_p1_en    = fire;
    sram_p1_addr  = word_addr1;
  end

  // Build aligned 8-byte window from returned data
  wire [6:0] shamt = {off_d, 3'b000};  // off*8
  wire [127:0] wide = {sram_p1_rdata, sram_p0_rdata};
  wire [63:0]  aligned64 = (off_d == 3'd0) ? sram_p0_rdata : (wide >> shamt);

  // Apply len padding (Verilog-2001 safe)
  wire [63:0] padded64 =
    { (len_d > 7) ? aligned64[63:56] : 8'h00,
      (len_d > 6) ? aligned64[55:48] : 8'h00,
      (len_d > 5) ? aligned64[47:40] : 8'h00,
      (len_d > 4) ? aligned64[39:32] : 8'h00,
      (len_d > 3) ? aligned64[31:24] : 8'h00,
      (len_d > 2) ? aligned64[23:16] : 8'h00,
      (len_d > 1) ? aligned64[15:8]  : 8'h00,
      (len_d > 0) ? aligned64[7:0]   : 8'h00 };

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fire_d  <= 1'b0;
      off_d   <= 3'd0;
      len_d   <= 4'd0;
      out_valid <= 1'b0;
      out_data  <= 64'd0;
    end else begin
      // stage0 -> stage1 metadata
      fire_d <= fire;
      if (fire) begin
        off_d <= byte_off;
        len_d <= req_len;
      end

      // output register with backpressure
      if (out_ready || !out_valid) begin
        out_valid <= fire_d;
        if (fire_d)
          out_data <= padded64;
      end
    end
  end

endmodule
