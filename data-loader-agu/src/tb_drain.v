`timescale 1ns/1ps

module tb_drain;

  // ===========================================================================
  // 1. SIGNAL DECLARATIONS
  // ===========================================================================
  reg clk;
  reg rst_n;

  // DUT Control Signals
  reg        start;
  reg [11:0] cfg_num_pixels;
  reg        cfg_split_mode; // 0 = Single Mode, 1 = Split/Sum Mode
  wire       done;
  
  // SRAM Interface (DUT -> SRAM)
  wire        drain_en;
  wire [11:0] drain_addr;
  wire [31:0] sram_rdata_drain;
  
  // DRAM Interface (DUT -> External)
  wire        tx_valid;
  wire [31:0] tx_data;
  reg         tx_ready;

  // Testbench SRAM Write Port (TB -> SRAM)
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
  
  // Design Under Test: The Drain Streamer
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

  // Simulation Memory Model (SRAM1)
  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    .vccd1(vccd1),
    .vssd1(vssd1),
    // Port 0: Used by Testbench to load data
    .p0_en(tb_en), .p0_we(tb_we), .p0_addr(tb_addr), .p0_wdata(tb_wdata), .p0_wmask(tb_wmask), .p0_rdata(),
    // Port 1: Used by DUT to read data
    .p1_en(drain_en), .p1_addr(drain_addr), .p1_rdata(sram_rdata_drain)
  );

  // ===========================================================================
  // 3. HELPER TASKS (Making the Flow Readable)
  // ===========================================================================

  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Task: Reset the System
  task sys_reset;
    begin
      rst_n = 0;
      start = 0;
      cfg_num_pixels = 0;
      cfg_split_mode = 0;
      tx_ready = 1; // Always ready to accept data
      tb_en = 0;
      tb_we = 0;
      #20 rst_n = 1;
      #10;
    end
  endtask

  // Task: Write a word to SRAM (used to setup test cases)
  task load_sram_word;
    input [11:0] addr;
    input [31:0] data;
    begin
      tb_en    <= 1'b1;
      tb_we    <= 1'b1;
      tb_addr  <= addr;
      tb_wdata <= data;
      tb_wmask <= 4'hF; // Write all bytes
      @(posedge clk);
      tb_en    <= 1'b0;
      tb_we    <= 1'b0;
      @(posedge clk);
    end
  endtask

  // Task: Configure DUT and Start
  task run_drain_sequence;
    input [11:0] count;
    input        mode; // 0=Single, 1=Split
    begin
      cfg_num_pixels <= count;
      cfg_split_mode <= mode;
      
      @(posedge clk);
      start <= 1'b1;
      $display("[TB] Starting Drain Sequence (Mode=%s, Count=%0d)...", (mode ? "SPLIT" : "SINGLE"), count);
      
      @(posedge clk);
      start <= 1'b0;
    end
  endtask

  // Task: Verify Output Data
  task expect_packet;
    input [31:0] expected_val;
    begin
      // Wait until DUT outputs valid data
      wait(tx_valid);
      @(posedge clk); // Sample exactly at the clock edge
      
      if (tx_data !== expected_val) begin
        $display("[TB] ERROR: Time=%0t | Expected=0x%h, Got=0x%h", $time, expected_val, tx_data);
        $stop;
      end else begin
        $display("[TB] PASS:  Time=%0t | Got Correct Data=0x%h", $time, tx_data);
      end
    end
  endtask

  // ===========================================================================
  // 4. MAIN TEST FLOW
  // ===========================================================================
  initial begin
    sys_reset();

    // -------------------------------------------------------------------------
    // TEST CASE 1: Single Mode (Kernel <= 8x8)
    // Scenario: We only care about Byte 0 of the SRAM word.
    // Goal: DUT should pack 4 pixels (Bytes 0) into one DRAM word.
    // -------------------------------------------------------------------------
    $display("\n==============================================");
    $display(" TEST CASE 1: Single Mode (Byte 0 Only)");
    $display("==============================================");

    // 1. Load SRAM with test data (Upper bytes are garbage 'FF')
    // Px0=0x01, Px1=0x02, Px2=0x03, Px3=0x04
    load_sram_word(12'd0, 32'hFFFF_FF01); 
    load_sram_word(12'd1, 32'hFFFF_FF02);
    load_sram_word(12'd2, 32'hFFFF_FF03);
    load_sram_word(12'd3, 32'hFFFF_FF04);

    // 2. Start DUT (4 Pixels, Mode 0)
    run_drain_sequence(12'd4, 1'b0);

    // 3. Verify Output
    // Logic: {Px3, Px2, Px1, Px0} = {04, 03, 02, 01}
    expect_packet(32'h04030201);

    // 4. Wait for Done
    wait(done);
    $display("[TB] Done signal received.");
    repeat(5) @(posedge clk); // Idle gap


    // -------------------------------------------------------------------------
    // TEST CASE 2: Split Mode (Kernel > 8x8)
    // Scenario: We must sum Bytes 0,1,2,3 inside the SRAM word.
    // Goal: DUT should Sum, Saturate, and Pack.
    // -------------------------------------------------------------------------
    $display("\n==============================================");
    $display(" TEST CASE 2: Split Mode (Summation)");
    $display("==============================================");

    // 1. Load SRAM with partial sums
    // Px0: 10+10+10+10 = 40 (0x28)
    load_sram_word(12'd0, 32'h0A0A0A0A);
    // Px1: 50+50+50+50 = 200 (0xC8)
    load_sram_word(12'd1, 32'h32323232);
    // Px2: 100+100+100+100 = 400 -> Saturate to 255 (0xFF)
    load_sram_word(12'd2, 32'h64646464);
    // Px3: 1+1+1+1 = 4 (0x04)
    load_sram_word(12'd3, 32'h01010101);

    // 2. Start DUT (4 Pixels, Mode 1)
    run_drain_sequence(12'd4, 1'b1);

    // 3. Verify Output
    // Logic: {Px3, Px2, Px1, Px0} = {04, FF, C8, 28}
    expect_packet(32'h04FFC828);

    // 4. Wait for Done
    wait(done);
    $display("[TB] Done signal received.");
    repeat(5) @(posedge clk);

    $display("\n=== ALL DRAIN TESTS PASSED ===");
    $finish;
  end

endmodule