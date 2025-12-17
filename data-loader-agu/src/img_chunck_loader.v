// img_chunk_stream_dp
// Pipeline: 1 cycle from byte address to 8-pixel chunk.
// Throughput: 1 chunk/cycle once pipeline is full.
//
// Assumes SRAM macro is synchronous, 1-cycle read latency.
// Uses Port0 + Port1 in parallel (both as read ports).
module img_chunk_stream_dp #(
  parameter ADDR_W = 12
)(
  input  wire              clk,
  input  wire              rst_n,

  // From AGU: "give me 8 pixels starting at this byte address"
  // In steady state, drive req_valid=1 every cycle with next byte address.
  input  wire              req_valid,
  input  wire [ADDR_W+2:0] req_byte_addr,  // byte index into image

  // SRAM0 dual-port (both used for READ during compute)
  output reg               sram_p0_en,
  output reg [ADDR_W-1:0]  sram_p0_addr,
  input  wire [63:0]       sram_p0_rdata,

  output reg               sram_p1_en,
  output reg [ADDR_W-1:0]  sram_p1_addr,
  input  wire [63:0]       sram_p1_rdata,

  // Toward Systolic Array: 8 pixels per cycle after initial latency
  output reg               out_valid,
  output reg [63:0]        out_data
);

  // Pipeline registers for metadata that must be delayed 1 cycle
  reg        valid_d;                 // delayed req_valid
  reg [2:0]  byte_off_d;              // delayed offset within first word

  // Combinational decode of current request
  wire [ADDR_W-1:0] word_addr0 = req_byte_addr[ADDR_W+2:3];      // floor(/8)
  wire [ADDR_W-1:0] word_addr1 = word_addr0 + 1'b1;              // next word
  wire [2:0]        byte_off   = req_byte_addr[2:0];             // %8

  // Drive SRAM ports directly from current request
  always @(*) begin
    sram_p0_en   = req_valid;
    sram_p1_en   = req_valid;
    sram_p0_addr = word_addr0;
    sram_p1_addr = word_addr1;
  end

  // Sequential pipeline: capture control, then use next-cycle data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_d    <= 1'b0;
      byte_off_d <= 3'd0;
      out_valid  <= 1'b0;
      out_data   <= 64'd0;
    end else begin
      // Stage 0 → Stage 1 pipeline
      valid_d    <= req_valid;
      byte_off_d <= byte_off;

      // Stage 1: SRAM data from previous cycle is now valid
      out_valid <= valid_d;

      if (valid_d) begin
        if (byte_off_d == 3'd0) begin
          // Aligned to byte 0 of word0: just pass Port0 word
          out_data <= sram_p0_rdata;
        end else begin
          // Concatenate word1:word0 and shift right by byte_off_d*8 bits
          out_data <= ({sram_p1_rdata, sram_p0_rdata} >> (byte_off_d * 8));
        end
      end
    end
  end

endmodule
