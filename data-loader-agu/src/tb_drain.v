`timescale 1ns/1ps

module tb_drain;

  // ===========================================================================
  // 1. SIGNAL DECLARATIONS
  // ===========================================================================
  `ifdef USE_POWER_PINS
    supply1 vccd1;
    supply0 vssd1;
  `endif
  reg clk;
  reg rst_n;

  // DUT Control Signals
  reg        start;
  reg [11:0] cfg_num_pixels;
  reg        cfg_split_mode;
  wire       done;
  
  // SRAM Interface
  wire        drain_en;
  wire [11:0] drain_addr;
  wire [31:0] sram_rdata_drain;
  
  // DRAM Interface
  wire        tx_valid;
  wire [31:0] tx_data;
  reg         tx_ready;

  // Testbench SRAM Write Port
  reg         tb_we;
  reg         tb_en;
  reg [11:0]  tb_addr;
  reg [31:0]  tb_wdata;
  reg [3:0]   tb_wmask;

  // Power Pins
  wire vccd1 = 1'b1;
  wire vssd1 = 1'b0;

  // ===========================================================================
  // 2. MODULE INSTANTIATION
  // ===========================================================================
  
  dl_drain_stream dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .cfg_num_pixels(cfg_num_pixels),
    .cfg_split_mode(cfg_split_mode),
    .done(done),
    .sram_en(drain_en),
    .sram_addr(drain_addr),
    .sram_rdata(sram_rdata_drain),
    .tx_valid(tx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready)
  );

  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    .p0_en(tb_en), .p0_we(tb_we), .p0_addr(tb_addr), .p0_wdata(tb_wdata), .p0_wmask(tb_wmask), .p0_rdata(),
    .p1_en(drain_en), .p1_addr(drain_addr), .p1_rdata(sram_rdata_drain)
  );

  // ===========================================================================
  // 3. HELPER TASKS
  // ===========================================================================

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task sys_reset;
    begin
      rst_n = 0;
      start = 0;
      cfg_num_pixels = 0;
      cfg_split_mode = 0;
      tx_ready = 1;
      tb_en = 0;
      tb_we = 0;
      #20 rst_n = 1;
      #10;
    end
  endtask

  task load_sram_word;
    input [11:0] addr;
    input [31:0] data;
    begin
      @(negedge clk);
      tb_en    <= 1'b1;
      tb_we    <= 1'b1;
      tb_addr  <= addr;
      tb_wdata <= data;
      tb_wmask <= 4'hF;
      @(negedge clk);
      tb_en    <= 1'b0;
      tb_we    <= 1'b0;
    end
  endtask

  task run_drain_sequence;
    input [11:0] count;
    input        mode;
    begin
      cfg_num_pixels <= count;
      cfg_split_mode <= mode;
      
      @(negedge clk);
      start <= 1'b1;
      $display("[TB] Starting Drain Sequence (Mode=%s, Count=%0d)...", (mode ? "SPLIT" : "SINGLE"), count);
      
      @(negedge clk);
      start <= 1'b0;
    end
  endtask

  task expect_packet;
    input [31:0] expected_val;
    begin
      wait(tx_valid);
      @(posedge clk); 
      if (tx_data !== expected_val) begin
        $display("[TB] ERROR: Time=%0t | Expected=0x%h, Got=0x%h", $time, expected_val, tx_data);
        $stop;
      end else begin
        $display("[TB] PASS:  Time=%0t | Got Correct Data=0x%h", $time, tx_data);
      end
    end
  endtask

  // ===========================================================================
  // 4. MAIN TEST
  // ===========================================================================
  initial begin
    sys_reset();

    // TEST CASE 1
    $display("\nTEST CASE 1: Single Mode");
    load_sram_word(12'd0, 32'hFFFF_FF01); 
    load_sram_word(12'd1, 32'hFFFF_FF02);
    load_sram_word(12'd2, 32'hFFFF_FF03);
    load_sram_word(12'd3, 32'hFFFF_FF04);

    run_drain_sequence(12'd4, 1'b0);
    expect_packet(32'h04030201);
    wait(done);
    repeat(5) @(posedge clk);

    // TEST CASE 2
    $display("\nTEST CASE 2: Split Mode");
    load_sram_word(12'd0, 32'h0A0A0A0A); // Sum=40 (0x28)
    load_sram_word(12'd1, 32'h32323232); // Sum=200 (0xC8)
    load_sram_word(12'd2, 32'h64646464); // Sum=400->255 (0xFF)
    load_sram_word(12'd3, 32'h01010101); // Sum=4 (0x04)

    run_drain_sequence(12'd4, 1'b1);
    expect_packet(32'h04FFC828);
    wait(done);
    repeat(5) @(posedge clk);

    $display("\n=== ALL DRAIN TESTS PASSED ===");
    $finish;
  end

endmodule