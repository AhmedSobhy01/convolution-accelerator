`timescale 1ns/1ps
`define USE_POWER_PINS

module tb_loader;

  reg clk;
  reg rst_n;

  // dummy power pins for sim
  wire vccd1 = 1'b1;
  wire vssd1 = 1'b0;

  // ----------------------------
  // dl_dma_rx <-> stream
  // ----------------------------
  reg        cmd_valid;
  wire       cmd_ready;
  reg [15:0] cmd_base_byte;
  reg [15:0] cmd_len_bytes;
  wire       cmd_done;

  reg  [31:0] rx_data;
  reg         rx_valid;
  wire        rx_ready;

  // dl_dma_rx -> sram0 port0
  wire        sram0_p0_en;
  wire        sram0_p0_we;
  wire [9:0]  sram0_p0_addr;
  wire [63:0] sram0_p0_wdata;
  wire [7:0]  sram0_p0_wmask;

  // ----------------------------
  // SRAM0 read port1 (TB)
  // ----------------------------
  reg         sram0_p1_en;
  reg  [9:0]  sram0_p1_addr;
  wire [63:0] sram0_p1_rdata;

  // (unused) sram0 port0 rdata
  wire [63:0] sram0_p0_rdata;

  // ----------------------------
  // SRAM1 (32-bit) for sanity test
  // ----------------------------
  reg         sram1_p0_en;
  reg         sram1_p0_we;
  reg  [11:0] sram1_p0_addr;
  reg  [31:0] sram1_p0_wdata;
  reg  [3:0]  sram1_p0_wmask;
  wire [31:0] sram1_p0_rdata;

  reg         sram1_p1_en;
  reg  [11:0] sram1_p1_addr;
  wire [31:0] sram1_p1_rdata;

  // ----------------------------
  // DUT: dl_dma_rx
  // ----------------------------
  dl_dma_rx #(.ADDR_W(10)) u_dl (
    .clk(clk),
    .rst_n(rst_n),

    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_base_byte(cmd_base_byte),
    .cmd_len_bytes(cmd_len_bytes),
    .cmd_done(cmd_done),

    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),

    .sram0_p0_en(sram0_p0_en),
    .sram0_p0_we(sram0_p0_we),
    .sram0_p0_addr(sram0_p0_addr),
    .sram0_p0_wdata(sram0_p0_wdata),
    .sram0_p0_wmask(sram0_p0_wmask)
  );

  // ----------------------------
  // SRAM0 instance (generated macro through wrapper)
  // ----------------------------
  sram0_1rw1r_64x1024_wrapper u_sram0 (
    .clk(clk),
    .vccd1(vccd1),
    .vssd1(vssd1),

    .p0_en(sram0_p0_en),
    .p0_we(sram0_p0_we),
    .p0_addr(sram0_p0_addr),
    .p0_wdata(sram0_p0_wdata),
    .p0_wmask(sram0_p0_wmask),
    .p0_rdata(sram0_p0_rdata),

    .p1_en(sram0_p1_en),
    .p1_addr(sram0_p1_addr),
    .p1_rdata(sram0_p1_rdata)
  );

  // ----------------------------
  // SRAM1 instance (generated macro through wrapper)
  // ----------------------------
  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    .vccd1(vccd1),
    .vssd1(vssd1),

    .p0_en(sram1_p0_en),
    .p0_we(sram1_p0_we),
    .p0_addr(sram1_p0_addr),
    .p0_wdata(sram1_p0_wdata),
    .p0_wmask(sram1_p0_wmask),
    .p0_rdata(sram1_p0_rdata),

    .p1_en(sram1_p1_en),
    .p1_addr(sram1_p1_addr),
    .p1_rdata(sram1_p1_rdata)
  );

  // ----------------------------
  // Clock
  // ----------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // ----------------------------
  // Tasks
  // ----------------------------
  task issue_cmd;
    input [15:0] base_b;
    input [15:0] len_b;
    begin
      cmd_base_byte = base_b;
      cmd_len_bytes = len_b;
      cmd_valid     = 1'b1;
      while (!cmd_ready) @(posedge clk);
      @(posedge clk);
      cmd_valid = 1'b0;
    end
  endtask

  task send_beat;
    input [31:0] d;
    begin
      rx_data  = d;
      rx_valid = 1'b1;
      while (!rx_ready) @(posedge clk);
      @(posedge clk);
      rx_valid = 1'b0;
    end
  endtask

  task rd64;
    input  [9:0]  a;
    output [63:0] d;
    begin
      sram0_p1_en   = 1'b1;
      sram0_p1_addr = a;
      @(posedge clk);       // present address, enable
      sram0_p1_en   = 1'b0;

      @(posedge clk);       // wait 1
      @(posedge clk);       // wait 2 (generator adds extra reg stage)

      d = sram0_p1_rdata;
    end
  endtask

  task expect64;
    input [9:0]  a;
    input [63:0] exp;
    reg   [63:0] got;
    begin
      rd64(a, got);
      if (got !== exp) begin
        $display("SRAM0 MISMATCH @word %0d got=%016h exp=%016h", a, got, exp);
        $stop;
      end
    end
  endtask

  task sram1_wr32;
    input [11:0] a;
    input [31:0] w;
    input [3:0]  m;
    begin
      sram1_p0_en    = 1'b1;
      sram1_p0_we    = 1'b1;
      sram1_p0_addr  = a;
      sram1_p0_wdata = w;
      sram1_p0_wmask = m;
      @(posedge clk);
      sram1_p0_en    = 1'b0;
      sram1_p0_we    = 1'b0;
      sram1_p0_wmask = 4'b0000;
    end
  endtask

  task rd32;
    input  [11:0] a;
    output [31:0] d;
    begin
      sram1_p1_en   = 1'b1;
      sram1_p1_addr = a;
      @(posedge clk);
      sram1_p1_en   = 1'b0;
      @(posedge clk);       // assume 1-cycle latency typical [file:1]
      d = sram1_p1_rdata;
    end
  endtask

  task expect32_masked;
    input [11:0] a;
    input [31:0] exp_masked;  // compare full word; use known initial state to build expected
    reg   [31:0] got;
    begin
      rd32(a, got);
      if (got !== exp_masked) begin
        $display("SRAM1 MISMATCH @word %0d got=%08h exp=%08h", a, got, exp_masked);
        $stop;
      end
    end
  endtask

  // ----------------------------
  // Test sequence
  // ----------------------------
  initial begin
    // init signals
    rst_n = 1'b0;

    cmd_valid = 1'b0;
    cmd_base_byte = 16'd0;
    cmd_len_bytes = 16'd0;

    rx_valid = 1'b0;
    rx_data  = 32'd0;

    sram0_p1_en   = 1'b0;
    sram0_p1_addr = 10'd0;

    sram1_p0_en = 1'b0;
    sram1_p0_we = 1'b0;
    sram1_p0_addr = 12'd0;
    sram1_p0_wdata = 32'd0;
    sram1_p0_wmask = 4'd0;

    sram1_p1_en = 1'b0;
    sram1_p1_addr = 12'd0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    // ------------------------------------------------------------
    // TESTCASE 1: 16 bytes at base 0x0000 -> word0 + word1 full
    // expected word0 = A7..A0, word1 = AF..A8 (byte lane 0 is lowest)
    // ------------------------------------------------------------
    issue_cmd(16'h0000, 16);

    send_beat({8'hA3,8'hA2,8'hA1,8'hA0});
    send_beat({8'hA7,8'hA6,8'hA5,8'hA4});
    send_beat({8'hAB,8'hAA,8'hA9,8'hA8});
    send_beat({8'hAF,8'hAE,8'hAD,8'hAC});

    while (!cmd_done) @(posedge clk);

    expect64(10'd0, 64'hA7A6A5A4A3A2A1A0);
    expect64(10'd1, 64'hAFAEADACABAAA9A8);

    // ------------------------------------------------------------
    // TESTCASE 2: 10 bytes at base 0x0040 (aligned) -> one full word + one partial (2 bytes)
    // base byte 0x40 => word address = 0x40 >> 3 = 8
    // word8 full = 55..5C, word9 low2 bytes = 5D,5E
    // ------------------------------------------------------------
    issue_cmd(16'h0040, 10);

    send_beat({8'h58,8'h57,8'h56,8'h55});
    send_beat({8'h5C,8'h5B,8'h5A,8'h59});
    send_beat({8'h00,8'h00,8'h5E,8'h5D});
    send_beat(32'h00000000);

    while (!cmd_done) @(posedge clk);

    expect64(10'd8, 64'h5C5B5A5958575655);

    // For word9: only low2 bytes are guaranteed written; other bytes depend on initial SRAM contents.
    // If your SRAM initializes to X, you can only check the low bytes by masking:
    // Here we read and only verify byte[0]=5D, byte[1]=5E.
    begin : PARTIAL_CHECK
      reg [63:0] got;
      rd64(10'd9, got);
      if (got[7:0]  !== 8'h5D || got[15:8] !== 8'h5E) begin
        $display("SRAM0 partial mismatch @word9 got=%016h (expect .. .. .. .. .. .. 5E 5D)", got);
        $stop;
      end
    end

    // ------------------------------------------------------------
    // TESTCASE 3: SRAM1 byte-mask sanity (write only lane0 then lane1)
    // This validates your 4-byte word SRAM1 mask behavior used later for packed partials [file:1]
    // ------------------------------------------------------------
    // Write lane0 only with 0x11
    sram1_wr32(12'd3, 32'h00000011, 4'b0001);
    // Write lane1 only with 0x22 (byte[15:8])
    sram1_wr32(12'd3, 32'h00002200, 4'b0010);

    // Read back and check that at least those lanes match.
    begin : SRAM1_MASK_CHECK
      reg [31:0] got32;
      rd32(12'd3, got32);
      if (got32[7:0]   !== 8'h11 || got32[15:8] !== 8'h22) begin
        $display("SRAM1 mask mismatch got=%08h exp lanes: b0=11 b1=22", got32);
        $stop;
      end
    end

    $display("ALL TESTCASES PASSED");
    $finish;
  end

endmodule
