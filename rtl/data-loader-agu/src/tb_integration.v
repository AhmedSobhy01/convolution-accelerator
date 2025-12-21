`timescale 1ns/1ps

module tb_integration;

  reg clk;
  reg rst_n;

  // --- DUT Signals ---
  reg        cfg_start_pass;
  reg [1:0]  cfg_ker_idx;
  reg        sa_valid;
  reg [63:0] sa_wdata;
  wire       busy;

  // --- SRAM Interconnect ---
  wire        wb_en, wb_we;
  wire [11:0] wb_addr;
  wire [31:0] wb_wdata;
  wire [3:0]  wb_wmask;
  
  wire [31:0] wb_rdata_unused;

  // --- Power Pins ---
  wire vccd1 = 1'b1;
  wire vssd1 = 1'b0;

  // --- Verification Signals (Port 1) ---
  reg         tb_p1_en;
  reg [11:0]  tb_p1_addr;
  wire [31:0] tb_p1_rdata;

  // --- Instantiations ---
  dl_sa_writeback dut_wb (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_start_pass(cfg_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .sa_valid(sa_valid),
    .sa_wdata(sa_wdata),
    .busy(busy),
    .sram_en(wb_en),
    .sram_we(wb_we),
    .sram_addr(wb_addr),
    .sram_wdata(wb_wdata),
    .sram_wmask(wb_wmask)
  );

  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    .vccd1(vccd1),
    .vssd1(vssd1),
    .p0_en(wb_en),
    .p0_we(wb_we),
    .p0_addr(wb_addr),
    .p0_wdata(wb_wdata),
    .p0_wmask(wb_wmask),
    .p0_rdata(wb_rdata_unused),
    .p1_en(tb_p1_en),
    .p1_addr(tb_p1_addr),
    .p1_rdata(tb_p1_rdata)
  );

  // --- Simulation Control ---
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Monitor writes to SRAM to see what's happening
  always @(posedge clk) begin
    if (wb_en && wb_we) begin
      $display("[TIME %0t] SRAM WRITE: Addr=%0d Data=%h Mask=%b", 
               $time, wb_addr, wb_wdata, wb_wmask);
    end
  end

  // Robust Verify Task
  task verify_sram;
    input [11:0] addr;
    input [31:0] expected_val;
    input [31:0] mask; 
    begin
      @(posedge clk); #1;
      tb_p1_en   = 1'b1;
      tb_p1_addr = addr;
      @(posedge clk); #1;
      tb_p1_en   = 1'b0; // Turn off enable
      @(posedge clk); #1; // Wait for data
      
      if ((tb_p1_rdata & mask) !== (expected_val & mask)) begin
        $display("ERROR at Addr %0d: Expected %h, Got %h (Mask %h)", 
                 addr, expected_val, tb_p1_rdata, mask);
        $stop;
      end else begin
        $display("PASS at Addr %0d: Got %h (Matches Expected masked)", addr, tb_p1_rdata);
      end
    end
  endtask

  initial begin
    rst_n = 0;
    cfg_start_pass = 0;
    cfg_ker_idx = 0;
    sa_valid = 0;
    sa_wdata = 0;
    tb_p1_en = 0;
    tb_p1_addr = 0;

    #20 rst_n = 1;
    #10;

    // -------------------------------------------------------
    $display("\n=== 1. Writing Pass 0 (Sub-Kernel 0) ===");
    // -------------------------------------------------------
    cfg_ker_idx    <= 2'd0; 
    cfg_start_pass <= 1'b1;
    @(posedge clk);
    cfg_start_pass <= 1'b0;
    @(posedge clk);

    // Data: 8 pixels [08, 07, 06, 05, 04, 03, 02, 01]
    sa_valid <= 1'b1;
    sa_wdata <= 64'h0807060504030201; 
    @(posedge clk);
    sa_valid <= 1'b0;

    @(posedge clk); // Wait for busy to rise
    wait(busy == 0);
    repeat(5) @(posedge clk); // Allow extra time for final write to settle

    $display("--- Verifying Pass 0 Results (Byte 0) ---");
    // Verify Pixel 0 (Addr 0) -> Byte 0 should be 01
    verify_sram(12'd0, 32'h00000001, 32'h000000FF);
    // Verify Pixel 7 (Addr 7) -> Byte 0 should be 08
    verify_sram(12'd7, 32'h00000008, 32'h000000FF);


    // -------------------------------------------------------
    $display("\n=== 2. Writing Pass 1 (Sub-Kernel 1) ===");
    // -------------------------------------------------------
    cfg_ker_idx    <= 2'd1; 
    cfg_start_pass <= 1'b1;
    @(posedge clk);
    cfg_start_pass <= 1'b0;
    @(posedge clk);

    // Data: 8 pixels [80, 70, 60, 50, 40, 30, 20, 10]
    sa_valid <= 1'b1;
    sa_wdata <= 64'h8070605040302010;
    @(posedge clk);
    sa_valid <= 1'b0;

    @(posedge clk); // Wait for busy to rise
    wait(busy == 0);
    repeat(5) @(posedge clk);

    $display("--- Verifying Combined Results (Bytes 1 & 0) ---");
    // Addr 0: Px 10 & 01 -> 1001
    verify_sram(12'd0, 32'h00001001, 32'h0000FFFF);
    // Addr 1: Px 20 & 02 -> 2002
    verify_sram(12'd1, 32'h00002002, 32'h0000FFFF);
    // Addr 7: Px 80 & 08 -> 8008
    verify_sram(12'd7, 32'h00008008, 32'h0000FFFF);

    $display("\n=== INTEGRATION TEST PASSED ===\n");
    $finish;
  end

endmodule
