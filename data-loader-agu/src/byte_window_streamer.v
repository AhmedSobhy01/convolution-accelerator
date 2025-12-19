`timescale 1ns/1ps
`define USE_POWER_PINS

module unaligned_memory_reader (
  input  wire         clk,
  input  wire         rst_n,
  
  `ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
  `endif
  
  // Request interface
  input  wire         req_valid,
  input  wire [9:0]   byte_addr,
  input  wire [2:0]   len_bytes,
  output wire         req_ready,
  
  // Response interface
  output reg          resp_valid,
  output reg [63:0]   resp_data
);

  // Pipeline stage 1: SRAM address decode
  reg         stage1_valid;
  reg [2:0]   stage1_len_bytes;
  reg [2:0]   stage1_byte_offset;
  
  // SRAM ports
  wire [63:0] p0_rdata;
  wire [63:0] p1_rdata;
  
  // Address decode (combinational)
  wire [9:0] word_addr = byte_addr[9:3];
  wire [2:0] byte_offset = byte_addr[2:0];
  
  // Pipeline can always accept new requests
  assign req_ready = 1'b1;
  
  // SRAM instance
  sram0_1rw1r_64x1024_wrapper u_sram (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    
    // Port 0 - Read first word
    .p0_en(req_valid),
    .p0_we(1'b0),
    .p0_addr(word_addr),
    .p0_wdata(64'd0),
    .p0_wmask(8'd0),
    .p0_rdata(p0_rdata),
    
    // Port 1 - Read second word
    .p1_en(req_valid),
    .p1_addr(word_addr + 10'd1),
    .p1_rdata(p1_rdata)
  );
  
  // Pipeline Stage 1: Register SRAM access info
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage1_valid <= 1'b0;
      stage1_len_bytes <= 3'd0;
      stage1_byte_offset <= 3'd0;
    end else begin
      stage1_valid <= req_valid;
      stage1_len_bytes <= len_bytes;
      stage1_byte_offset <= byte_offset;
    end
  end
  
  // Pipeline Stage 2: Compute result from SRAM output
  wire [127:0] combined = {p1_rdata, p0_rdata};
  wire [7:0] shift_bits = {stage1_byte_offset, 3'b000};  // byte_offset * 8
  
  // Mask generation (combinational)
  wire [63:0] mask = (stage1_len_bytes == 3'd1) ? 64'h00000000000000FF :
                     (stage1_len_bytes == 3'd2) ? 64'h000000000000FFFF :
                     (stage1_len_bytes == 3'd3) ? 64'h0000000000FFFFFF :
                     (stage1_len_bytes == 3'd4) ? 64'h00000000FFFFFFFF :
                     (stage1_len_bytes == 3'd5) ? 64'h000000FFFFFFFFFF :
                     (stage1_len_bytes == 3'd6) ? 64'h0000FFFFFFFFFFFF :
                     (stage1_len_bytes == 3'd7) ? 64'h00FFFFFFFFFFFFFF :
                                                   64'hFFFFFFFFFFFFFFFF;
  
  // Compute shifted and masked result (combinational)
  wire [63:0] result = (combined >> shift_bits) & mask;
  
  // Output register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_valid <= 1'b0;
      resp_data <= 64'd0;
    end else begin
      resp_valid <= stage1_valid;
      resp_data <= result;
    end
  end

endmodule