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
  
  // Response interface (combinational)
  output wire         resp_valid,
  output wire [63:0]  resp_data
);

  // SRAM ports - direct connections
  wire [63:0] p0_rdata;
  wire [63:0] p1_rdata;
  
  // Address decode (combinational)
  wire [9:0] word_addr = byte_addr[9:3];
  wire [2:0] byte_offset = byte_addr[2:0];
  
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
  
  // Combinational logic to extract bytes
  wire [127:0] combined = {p1_rdata, p0_rdata};
  wire [7:0] shift_bits = {byte_offset, 3'b000};  // byte_offset * 8
  
  // Mask generation
  wire [63:0] mask = (len_bytes == 3'd1) ? 64'h00000000000000FF :
                     (len_bytes == 3'd2) ? 64'h000000000000FFFF :
                     (len_bytes == 3'd3) ? 64'h0000000000FFFFFF :
                     (len_bytes == 3'd4) ? 64'h00000000FFFFFFFF :
                     (len_bytes == 3'd5) ? 64'h000000FFFFFFFFFF :
                     (len_bytes == 3'd6) ? 64'h0000FFFFFFFFFFFF :
                     (len_bytes == 3'd7) ? 64'h00FFFFFFFFFFFFFF :
                                           64'hFFFFFFFFFFFFFFFF;
  
  // Output (combinational)
  assign resp_valid = req_valid;  // Ready same cycle if SRAM is combinational
  assign resp_data = (combined >> shift_bits) & mask;
  assign req_ready = 1'b1;  // Always ready

endmodule