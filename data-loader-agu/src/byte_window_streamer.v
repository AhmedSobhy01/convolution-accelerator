`timescale 1ns/1ps

/**
 * unaligned_memory_reader
 * Aligned with top_module.v requirements.
 * Implements N-stage pipeline where N = SRAM_LATENCY.
 */
module unaligned_memory_reader#(
  parameter ADDR_W = 13,   // Interpret as Byte Address Width (8KB = 13 bits)
  parameter SRAM_LATENCY = 3
)(
  input  wire         clk,
  input  wire         rst_n,
  
  // Request interface
  input  wire         req_valid,
  input  wire [ADDR_W - 1:0]   byte_addr, 
  input  wire [2:0]   len_bytes,
  output wire         req_ready,
  
  // Response interface
  output reg          resp_valid,
  output reg [63:0]   resp_data,

  // Output to the sram (SRAM expects Word Address):
  output wire         sram_p0_en,
  output wire [ADDR_W - 4:0]   sram_p0_addr, // e.g., 13-4=9, so [9:0] is 10 bits
  input  wire [63:0]  sram_p0_rdata,
  
  output wire         sram_p1_en,
  output wire [ADDR_W - 4:0]   sram_p1_addr,
  input  wire [63:0]  sram_p1_rdata
);

  // Address decode (combinational)
  wire [ADDR_W - 4:0] word_addr    = byte_addr[ADDR_W - 1:3];
  wire [2:0]          byte_offset  = byte_addr[2:0];
  
  assign req_ready = 1'b1;

  assign sram_p0_en   = req_valid;
  assign sram_p0_addr = word_addr;
  assign sram_p1_en   = req_valid;
  assign sram_p1_addr = word_addr + {{(ADDR_W-4){1'b0}}, 1'b1};
  
  // Metadata Pipeline (N-stage)
  reg [SRAM_LATENCY-1:0] vld_pipe;
  reg [2:0] off_pipe [SRAM_LATENCY-1:0];
  reg [2:0] len_pipe [SRAM_LATENCY-1:0];
  
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vld_pipe <= 0;
      for (i=0; i<SRAM_LATENCY; i=i+1) begin
        off_pipe[i] <= 0;
        len_pipe[i] <= 0;
      end
    end else begin
      vld_pipe <= {vld_pipe[SRAM_LATENCY-2:0], req_valid};
      off_pipe[0] <= byte_offset;
      len_pipe[0] <= len_bytes;
      for (i=1; i<SRAM_LATENCY; i=i+1) begin
        off_pipe[i] <= off_pipe[i-1];
        len_pipe[i] <= len_pipe[i-1];
      end
    end
  end
  
  // Alignment Logic at the end of the pipe
  wire [2:0] cur_off = off_pipe[SRAM_LATENCY-1];
  wire [2:0] cur_len = len_pipe[SRAM_LATENCY-1];
  
  wire [127:0] combined = {sram_p1_rdata, sram_p0_rdata};
  wire [63:0]  shifted  = (cur_off == 3'd0) ? sram_p0_rdata : (combined >> (cur_off * 8));

  // Masking logic
  reg [63:0] mask;
  always @(*) begin
    case (cur_len)
      3'd1: mask = 64'h00000000000000FF;
      3'd2: mask = 64'h000000000000FFFF;
      3'd3: mask = 64'h0000000000FFFFFF;
      3'd4: mask = 64'h00000000FFFFFFFF;
      3'd5: mask = 64'h000000FFFFFFFFFF;
      3'd6: mask = 64'h0000FFFFFFFFFFFF;
      3'd7: mask = 64'h00FFFFFFFFFFFFFF;
      3'd0: mask = 64'hFFFFFFFFFFFFFFFF;
      default: mask = 64'h0;
    endcase
  end

  // Final Output Synchronized with Metadata Pipe
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_valid <= 1'b0;
      resp_data <= 64'd0;
    end else begin
      resp_valid <= vld_pipe[SRAM_LATENCY-1];
      if (vld_pipe[SRAM_LATENCY-1])
          resp_data <= (shifted & mask);
    end
  end

endmodule


// =============================================================================
// Backward Compatibility Wrapper for agu_top.v
// =============================================================================
module byte_window_streamer #(
  parameter ADDR_W = 10 // Word address width
)(
  input  wire         clk,
  input  wire         rst_n,
  
  input  wire         req_valid,
  output wire         req_ready,
  input  wire [15:0]  req_base_byte,
  input  wire [3:0]   req_len,
  
  output wire         out_valid,
  input  wire         out_ready,
  output wire [63:0]  out_data,

  output wire         sram_p0_en,
  output wire         sram_p0_we,
  output wire [ADDR_W-1:0] sram_p0_addr,
  output wire [63:0]  sram_p0_wdata,
  output wire [7:0]   sram_p0_wmask,
  input  wire [63:0]  sram_p0_rdata,
  
  output wire         sram_p1_en,
  output wire [ADDR_W-1:0] sram_p1_addr,
  input  wire [63:0]  sram_p1_rdata
);

  assign sram_p0_we = 1'b0;
  assign sram_p0_wdata = 64'd0;
  assign sram_p0_wmask = 8'h00;

  unaligned_memory_reader #(
    .ADDR_W(ADDR_W+3), // e.g., 10+3=13
    .SRAM_LATENCY(3)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .req_valid(req_valid),
    .byte_addr(req_base_byte[ADDR_W+2:0]),
    .len_bytes(req_len[2:0]),
    .req_ready(req_ready),
    .resp_valid(out_valid),
    .resp_data(out_data),
    .sram_p0_en(sram_p0_en),
    .sram_p0_addr(sram_p0_addr),
    .sram_p0_rdata(sram_p0_rdata),
    .sram_p1_en(sram_p1_en),
    .sram_p1_addr(sram_p1_addr),
    .sram_p1_rdata(sram_p1_rdata)
  );

endmodule