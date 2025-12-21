`timescale 1ns/1ps

module unaligned_memory_reader#(
  parameter ADDR_W = 13
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

  // Output to the sram:
  output wire         sram_p0_en,
  output wire [ADDR_W - 4:0]   sram_p0_addr,
  input  wire [63:0]  sram_p0_rdata,
  output wire         sram_p1_en,
  output wire [ADDR_W - 4:0]   sram_p1_addr,
  input  wire [63:0]  sram_p1_rdata
);

  // SRAM ports
  wire [63:0] p0_rdata;
  wire [63:0] p1_rdata;

  // Address decode (combinational)
  wire [ADDR_W - 4:0] word_addr = byte_addr[ADDR_W - 1:3];
  wire [2:0] byte_offset = byte_addr[2:0];

  // Pipeline can always accept new requests
  assign req_ready = 1'b1;

  assign sram_p0_en   = req_valid;
  assign sram_p0_addr = word_addr;
  assign sram_p1_en   = req_valid;
  assign sram_p1_addr =word_addr + {{(ADDR_W-4){1'b0}}, 1'b1};
  assign p0_rdata     = sram_p0_rdata;
  assign p1_rdata     = sram_p1_rdata;

  // Register inputs for alignment with SRAM output
  reg         req_valid_d;
  reg [2:0]   len_bytes_d;
  reg [2:0]   byte_offset_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_valid_d <= 1'b0;
      len_bytes_d <= 3'd0;
      byte_offset_d <= 3'd0;
    end else begin
      req_valid_d <= req_valid;
      len_bytes_d <= len_bytes;
      byte_offset_d <= byte_offset;
    end
  end

  // Compute result (combinational based on SRAM output)
  wire [127:0] combined = {p1_rdata, p0_rdata};
  wire [7:0] shift_bits = {2'b00, byte_offset_d, 3'b000};  // byte_offset * 8

  // Mask generation (combinational)
  wire [63:0] mask = (len_bytes_d == 3'd1) ? 64'h00000000000000FF :
                     (len_bytes_d == 3'd2) ? 64'h000000000000FFFF :
                     (len_bytes_d == 3'd3) ? 64'h0000000000FFFFFF :
                     (len_bytes_d == 3'd4) ? 64'h00000000FFFFFFFF :
                     (len_bytes_d == 3'd5) ? 64'h000000FFFFFFFFFF :
                     (len_bytes_d == 3'd6) ? 64'h0000FFFFFFFFFFFF :
                     (len_bytes_d == 3'd7) ? 64'h00FFFFFFFFFFFFFF :
                                             64'hFFFFFFFFFFFFFFFF;

  // Compute shifted and masked result (combinational)
  wire [127:0] shifted_combined = combined >> shift_bits;
  wire [63:0] result = shifted_combined[63:0] & mask;

  // Output directly (no extra pipeline stage)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_valid <= 1'b0;
      resp_data <= 64'd0;
    end else begin
      resp_valid <= req_valid_d;
      resp_data <= result;
    end
  end

endmodule
