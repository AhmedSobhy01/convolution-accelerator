`timescale 1ns/1ps

module tb_load_image_to_sram;

  // -------------------------
  // clock / reset
  // -------------------------
  reg clk;
  reg rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz
  end

  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

  // -------------------------
  // config
  // -------------------------
  reg start;
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;

  // -------------------------
  // DRAM stream
  // -------------------------
  reg  [31:0] rx_data;
  reg         rx_valid;
  wire        rx_ready;

  // -------------------------
  // SRAM signals (to wrapper)
  // -------------------------
  wire        sram_p0_en;
  wire        sram_p0_we;
  wire [11:0] sram_p0_addr;
  wire [63:0] sram_p0_wdata;
  wire [7:0]  sram_p0_wmask;
  wire [63:0] sram_p0_rdata;

  // We will use Port1 to read back (simpler)
  reg         sram_p1_en;
  reg  [10:0] sram_p1_addr;
  wire [63:0] sram_p1_rdata;

  // power nets for macros
  supply1 vccd1;
  supply0 vssd1;

  // done from loader
  wire done;

  // -------------------------
  // DUT: data loader (padded stream expected)
  // -------------------------
  data_loader_padded_calc #(
    .ADDR_W(11),
    .KER_BASE_BYTE(16'd4096)
  ) u_loader (
    .clk(clk),
    .rst_n(rst_n),

    .start(start),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    .done(done),

    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),

    .sram0_en(sram_p0_en),
    .sram0_we(sram_p0_we),
    .sram0_addr(sram_p0_addr),
    .sram0_wdata(sram_p0_wdata),
    .sram0_wmask(sram_p0_wmask)
  );

  // -------------------------
  // DUT: SRAM wrapper (replace macro name inside wrapper to your actual one)
  // -------------------------
  sram_1rw1r_64b_wrapper #(
    .ADDR_W(12)
  ) u_sram (
    .clk(clk),
    .vccd1(vccd1),
    .vssd1(vssd1),

    .p0_en(sram_p0_en),
    .p0_we(sram_p0_we),
    .p0_addr(sram_p0_addr),
    .p0_wdata(sram_p0_wdata),
    .p0_wmask(sram_p0_wmask),
    .p0_rdata(sram_p0_rdata),

    .p1_en(sram_p1_en),
    .p1_addr(sram_p1_addr),
    .p1_rdata(sram_p1_rdata)
  );

  // Monitor for SRAM writes
  always @(posedge clk) begin
    if (sram_p0_en && sram_p0_we) begin
      $display("[TB] SRAM WRITE: addr=%0d (0x%0h) data=0x%016h at time=%0t", sram_p0_addr, sram_p0_addr, sram_p0_wdata, $time);
    end
  end

  // -------------------------
  // helpers
  // -------------------------
  function [31:0] pack4;
    input [7:0] b0, b1, b2, b3;
    begin
      // byte0 goes to [7:0]
      pack4 = {b3,b2,b1,b0};
    end
  endfunction

  // Track how many beats we've sent
  integer beat_count = 0;

  task send_word32;
    input [31:0] w;
    begin
      // wait until ready
      while (!rx_ready) @(posedge clk);
      rx_data  <= w;
      rx_valid <= 1'b1;
      beat_count = beat_count + 1;
      @(posedge clk);
      // handshake happens if rx_ready high (it is)
      rx_valid <= 1'b0;
      rx_data  <= 32'd0;
    end
  endtask

  // read a word from SRAM port1 (assumes 1-cycle latency)
  task read_sram_word;
    input [11:0] addr;
    output [63:0] data;
    begin
      sram_p1_addr = addr;      // set address
      @(posedge clk);            // let address register
      sram_p1_en   = 1'b1;       // enable read
      @(posedge clk);
      sram_p1_en   = 1'b0;
      @(posedge clk);            // data valid
      data = sram_p1_rdata;
    end
  endtask

  task expect_eq64;
    input [63:0] got;
    input [63:0] exp;
    input [255:0] msg;
    begin
      if (got !== exp) begin
        $display("FAIL: %s", msg);
        $display("  got = 0x%016h", got);
        $display("  exp = 0x%016h", exp);
        $stop;
      end else begin
        $display("PASS: %s  (0x%016h)", msg, got);
      end
    end
  endtask

  // -------------------------
  // Test
  // -------------------------
  integer i;
  reg [63:0] rdata;

  initial begin
    // init
    start = 0;
    cfg_N = 0;
    cfg_K = 0;
    rx_data = 0;
    rx_valid = 0;
    sram_p1_en = 0;
    sram_p1_addr = 0;

    // wait reset release
    @(posedge rst_n);
    @(posedge clk);

    // Choose an easy case first:
    // N=16 -> row_bytes=16 (already multiple of 8)
    // K=5  -> col_bytes=8  (padded)
    cfg_N <= 7'd16;
    cfg_K <= 5'd5;

    // start loader
    $display("\n=== Starting Data Loader Test ===");
    $display("Config: N=%0d, K=%0d", cfg_N, cfg_K);
    $display("Expected: %0d image bytes, %0d kernel bytes\n", 256, 40);
    
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    beat_count = 0;
    $display("[TB] Streaming IMAGE data (256 bytes = 64 beats)...");
    // Stream IMAGE padded bytes.
    // Since N=16 and row_bytes=16 => img_bytes_padded=256 bytes (no extra pad beyond row itself).
    // DRAM must send exactly 256 bytes for image, packed into 32-bit beats => 64 beats.
    // We'll send pixels = 0..255.
    for (i = 0; i < 256; i = i + 4) begin
      send_word32(pack4(i & 8'hFF, (i+1) & 8'hFF, (i+2) & 8'hFF, (i+3) & 8'hFF));
    end

    // Stream KERNEL padded bytes, column-padded.
    // K=5, col_bytes=8 => ker_bytes_padded = 5*8 = 40 bytes => 10 beats.
    // We will send a simple pattern 0xA0.. for visibility:
    // 40 bytes = 0xA0..0xC7 (just sequential)
    for (i = 0; i < 40; i = i + 4) begin
      send_word32(pack4((8'hA0 + i) & 8'hFF,
                        (8'hA0 + (i+1)) & 8'hFF,
                        (8'hA0 + (i+2)) & 8'hFF,
                        (8'hA0 + (i+3)) & 8'hFF));
    end
    $display("[TB] Sent %0d kernel beats (40 bytes)\n", beat_count);

    // wait done
    while (!done) @(posedge clk);
    $display("[TB] Loader finished - 'done' signal asserted\n");

    // ---------------------------------------
    // READ BACK and CHECK a few SRAM words
    // ---------------------------------------
    $display("=== Verifying SRAM Contents ===");
    
    // Image starts at byte 0, so word0 should contain bytes 0..7
    read_sram_word(12'd0, rdata);
    // expected word bytes lane0..7 = 00 01 02 03 04 05 06 07
    expect_eq64(rdata, 64'h0706050403020100, "IMG word0 bytes 0..7");

    // word1 should be bytes 8..15
    read_sram_word(12'd1, rdata);
    expect_eq64(rdata, 64'h0F0E0D0C0B0A0908, "IMG word1 bytes 8..15");

    // Kernel base is byte 4096 => word address 4096/8 = 512
    // We wrote sequential bytes starting at 0xA0, so first kernel word should be A0..A7
    read_sram_word(12'd512, rdata);
    expect_eq64(rdata, 64'hA7A6A5A4A3A2A1A0, "KER word0 at 4KB (A0..A7)");

    $display("\n=== ALL TESTS PASSED ===");
    $stop;
  end

endmodule
