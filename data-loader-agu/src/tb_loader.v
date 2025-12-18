`timescale 1ns/1ps
`define USE_POWER_PINS

module tb_loader;

  reg clk;
  reg rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

  // config
  reg start;
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;
  wire done;

  // DRAM stream
  reg  [31:0] rx_data;
  reg         rx_valid;
  wire        rx_ready;

  // ------------------------------------------------------------
  // Loader -> mux (SRAM port0)
  // ------------------------------------------------------------
  wire        l_p0_en;
  wire        l_p0_we;
  wire [9:0]  l_p0_addr;
  wire [63:0] l_p0_wdata;
  wire [7:0]  l_p0_wmask;

  // ------------------------------------------------------------
  // TB readback -> mux (SRAM port1)
  // ------------------------------------------------------------
  reg         tb_p1_en;
  reg  [9:0]  tb_p1_addr;

  // ------------------------------------------------------------
  // Streamer -> mux (SRAM port0 + port1)
  // ------------------------------------------------------------
  wire        st_p0_en;
  wire        st_p0_we;
  wire [9:0]  st_p0_addr;
  wire [63:0] st_p0_wdata;
  wire [7:0]  st_p0_wmask;

  wire        st_p1_en;
  wire [9:0]  st_p1_addr;

  // ------------------------------------------------------------
  // Mux -> SRAM wrapper (actual SRAM pins)
  // ------------------------------------------------------------
  wire        sram_p0_en;
  wire        sram_p0_we;
  wire [9:0]  sram_p0_addr;
  wire [63:0] sram_p0_wdata;
  wire [7:0]  sram_p0_wmask;
  wire [63:0] sram_p0_rdata;

  wire        sram_p1_en;
  wire [9:0]  sram_p1_addr;
  wire [63:0] sram_p1_rdata;

  // mux mode: 0 = loader owns p0, TB owns p1.  1 = streamer owns both p0+p1.
  reg mode_stream;

  // power
  wire vccd1 = 1'b1;
  wire vssd1 = 1'b0;

  // ------------------------------------------------------------
  // DUT loader
  // ------------------------------------------------------------
  dl_dma_rx #(
    .ADDR_W(10),
    .KER_BASE_BYTE(16'd4096)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),

    .start(start),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    .done(done),

    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),

    .sram0_en(l_p0_en),
    .sram0_we(l_p0_we),
    .sram0_addr(l_p0_addr),
    .sram0_wdata(l_p0_wdata),
    .sram0_wmask(l_p0_wmask),

    .sram1_en(),
    .sram1_we(),
    .sram1_addr(),
    .sram1_wdata(),
    .sram1_wmask()
  );

  // ------------------------------------------------------------
  // Byte window streamer (1-cycle SRAM latency version)
  // ------------------------------------------------------------
  reg         req_valid;
  wire        req_ready;
  reg  [15:0] req_base_byte;
  reg  [3:0]  req_len;

  wire        out_valid;
  reg         out_ready;
  wire [63:0] out_data;

  byte_window_streamer #(
    .ADDR_W(10)
  ) u_bwin (
    .clk(clk),
    .rst_n(rst_n),

    .req_valid(req_valid),
    .req_ready(req_ready),
    .req_base_byte(req_base_byte),
    .req_len(req_len),

    .sram_p0_en(st_p0_en),
    .sram_p0_we(st_p0_we),
    .sram_p0_addr(st_p0_addr),
    .sram_p0_wdata(st_p0_wdata),
    .sram_p0_wmask(st_p0_wmask),
    .sram_p0_rdata(sram_p0_rdata),

    .sram_p1_en(st_p1_en),
    .sram_p1_addr(st_p1_addr),
    .sram_p1_rdata(sram_p1_rdata),

    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_data(out_data)
  );

  // ------------------------------------------------------------
  // SRAM mux: loader/TB-readback vs streamer
  // (requires module sram0_mux_load_tb_or_stream in your rtl)
  // ------------------------------------------------------------
  sram0_mux_load_tb_or_stream #(
    .ADDR_W(10)
  ) u_mux (
    .mode_stream(mode_stream),

    .l_p0_en(l_p0_en),
    .l_p0_we(l_p0_we),
    .l_p0_addr(l_p0_addr),
    .l_p0_wdata(l_p0_wdata),
    .l_p0_wmask(l_p0_wmask),

    .tb_p1_en(tb_p1_en),
    .tb_p1_addr(tb_p1_addr),

    .s_p0_en(st_p0_en),
    .s_p0_we(st_p0_we),
    .s_p0_addr(st_p0_addr),
    .s_p0_wdata(st_p0_wdata),
    .s_p0_wmask(st_p0_wmask),

    .s_p1_en(st_p1_en),
    .s_p1_addr(st_p1_addr),

    .m_p0_en(sram_p0_en),
    .m_p0_we(sram_p0_we),
    .m_p0_addr(sram_p0_addr),
    .m_p0_wdata(sram_p0_wdata),
    .m_p0_wmask(sram_p0_wmask),

    .m_p1_en(sram_p1_en),
    .m_p1_addr(sram_p1_addr)
  );

  // ------------------------------------------------------------
  // SRAM0 wrapper
  // ------------------------------------------------------------
  sram0_1rw1r_64x1024_wrapper u_sram0 (
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

  // monitor writes (use muxed SRAM signals)
  always @(posedge clk) begin
    if (sram_p0_en && sram_p0_we) begin
      $display("[TB] SRAM WRITE addr=%0d data=%016h time=%0t", sram_p0_addr, sram_p0_wdata, $time);
    end
  end

  // helpers
  function [31:0] pack4;
    input [7:0] b0, b1, b2, b3;
    begin
      pack4 = {b3,b2,b1,b0};
    end
  endfunction

  task send_word32;
    input [31:0] w;
    begin
      while (!rx_ready) @(posedge clk);
      rx_data  <= w;
      rx_valid <= 1'b1;
      @(posedge clk);
      rx_valid <= 1'b0;
      rx_data  <= 32'd0;
    end
  endtask

  // read a word from SRAM port1 (keep your 2-cycle safe readback)
  task read_sram_word;
    input [9:0] addr;
    output [63:0] data;
    begin
      tb_p1_addr = addr;
      tb_p1_en   = 1'b1;
      @(posedge clk);
      tb_p1_en   = 1'b0;

      @(posedge clk);
      @(posedge clk);

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
        $finish;
      end else begin
        $display("PASS: %s (0x%016h)", msg, got);
      end
    end
  endtask

  // issue one byte-window request and collect response
  task bwin_req;
    input [15:0] base_b;
    input [3:0]  len_b;
    output [63:0] out;
    begin
      while (!req_ready) @(posedge clk);
      req_base_byte <= base_b;
      req_len       <= len_b;
      req_valid     <= 1'b1;
      @(posedge clk);
      req_valid     <= 1'b0;

      out_ready <= 1'b1;
      while (!out_valid) @(posedge clk);
      out = out_data;
      @(posedge clk);
      out_ready <= 1'b0;
    end
  endtask

  integer i;
  reg [63:0] rdata;
  reg [63:0] w;

  initial begin
    start = 0;
    cfg_N = 0;
    cfg_K = 0;
    rx_data = 0;
    rx_valid = 0;

    // mux defaults: loader + TB readback
    mode_stream = 1'b0;

    tb_p1_en = 1'b0;
    tb_p1_addr = 10'd0;

    // streamer req/resp defaults
    req_valid = 1'b0;
    req_base_byte = 16'd0;
    req_len = 4'd0;
    out_ready = 1'b0;

    @(posedge rst_n);
    @(posedge clk);

    // Example: N=16 => img_bytes_pad=256, K=5 => ker_bytes_pad=40
    cfg_N <= 7'd16;
    cfg_K <= 5'd5;

    $display("\n=== Starting Data Loader Test ===");
    $display("Config N=%0d K=%0d", cfg_N, cfg_K);

    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // IMAGE: 256 bytes => 64 beats
    for (i = 0; i < 256; i = i + 4) begin
      send_word32(pack4( (i     & 8'hFF),
                        ((i+1) & 8'hFF),
                        ((i+2) & 8'hFF),
                        ((i+3) & 8'hFF) ));
    end

    // KERNEL: 40 bytes => 10 beats
    for (i = 0; i < 40; i = i + 4) begin
      send_word32(pack4( ((8'hA0 + i)     & 8'hFF),
                        ((8'hA0 + (i+1)) & 8'hFF),
                        ((8'hA0 + (i+2)) & 8'hFF),
                        ((8'hA0 + (i+3)) & 8'hFF) ));
    end

    while (!done) @(posedge clk);
    $display("[TB] done asserted\n");

    // ---- keep your existing SRAM word checks (TB owns port1 here) ----
    read_sram_word(10'd0, rdata);
    expect_eq64(rdata, 64'h0706050403020100, "IMG word0 bytes 0..7");

    read_sram_word(10'd1, rdata);
    expect_eq64(rdata, 64'h0F0E0D0C0B0A0908, "IMG word1 bytes 8..15");

    read_sram_word(10'd512, rdata);
    expect_eq64(rdata, 64'hA7A6A5A4A3A2A1A0, "KER word0 at 4KB (A0..A7)");

    // ---- switch SRAM ownership to streamer (it uses BOTH ports) ----
    tb_p1_en <= 1'b0;         // TB must release port1
    mode_stream <= 1'b1;
    repeat (2) @(posedge clk);

    // aligned window at kernel base
    bwin_req(16'd4096, 4'd8, w);
    expect_eq64(w, 64'hA7A6A5A4A3A2A1A0, "STREAM base=4096 len=8");

    // boundary-cross: base=4096+5 len=5 => A5..A9 then zeros
    bwin_req(16'd4101, 4'd5, w);
    expect_eq64(w, 64'h000000A9A8A7A6A5, "STREAM base=4096+5 len=5");

    $display("\n=== ALL TESTS PASSED (loader + byte window streamer) ===");
    $finish;
  end

endmodule
