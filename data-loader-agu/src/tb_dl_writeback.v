`timescale 1ns/1ps

module tb_dl_writeback;

  reg clk;
  reg rst_n;

  // Signals
  reg        cfg_start_pass;
  reg [1:0]  cfg_ker_idx;
  reg        sa_valid;
  reg [7:0]  sa_wdata; // UPDATED: 8 bits
  wire       busy;

  wire        sram1_en;
  wire        sram1_we;
  wire [11:0] sram1_addr;
  wire [31:0] sram1_wdata;
  wire [3:0]  sram1_wmask;

  // DUT Instance
  dl_sa_writeback #(
    .ADDR_W(12)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_start_pass(cfg_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .sa_valid(sa_valid),
    .sa_wdata(sa_wdata),
    .busy(busy),
    .sram_en(sram1_en),
    .sram_we(sram1_we),
    .sram_addr(sram1_addr),
    .sram_wdata(sram1_wdata),
    .sram_wmask(sram1_wmask)
  );

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Task: Push Single Pixel
  task push_pixel;
    input [7:0] val;
    begin
      while (busy) @(posedge clk);
      sa_valid <= 1'b1;
      sa_wdata <= val;
      @(posedge clk);
      sa_valid <= 1'b0;
      sa_wdata <= 8'd0;
    end
  endtask

  // Main Test
  initial begin
    rst_n = 0;
    cfg_start_pass = 0;
    cfg_ker_idx = 0;
    sa_valid = 0;
    sa_wdata = 0;
    
    #20 rst_n = 1;
    #10;

    $display("=== START STRIDED COUNTER TEST ===");
    
    // ---------------------------------------------------------
    // Scenario 1: Kernel Index 0 (Start 0, Step 4)
    // Expect: 
    //   Write 0xAA -> Addr 0, Mask 0001 (Byte 0)
    //   Write 0xBB -> Addr 1, Mask 0001 (Byte 0)
    //   Write 0xCC -> Addr 2, Mask 0001 (Byte 0)
    // ---------------------------------------------------------
    $display("[TB] Test 1: Kernel Index 0 (Start=0, Stride=4)");
    
    cfg_ker_idx    <= 0; 
    cfg_start_pass <= 1;
    @(posedge clk);
    cfg_start_pass <= 0;
    @(posedge clk);

    push_pixel(8'hAA);
    push_pixel(8'hBB);
    push_pixel(8'hCC);
    
    repeat(10) @(posedge clk);

    // ---------------------------------------------------------
    // Scenario 2: Kernel Index 1 (Start 1, Step 4)
    // Expect:
    //   Write 0x11 -> Addr 0, Mask 0010 (Byte 1)
    //   Write 0x22 -> Addr 1, Mask 0010 (Byte 1)
    // ---------------------------------------------------------
    $display("[TB] Test 2: Kernel Index 0 (Start=0, Stride=4)");
    
    @(posedge clk);

    push_pixel(8'hDD);
    push_pixel(8'hEE);
    push_pixel(8'hFF);
    
    repeat(10) @(posedge clk);

    // ---------------------------------------------------------
    // Scenario 2: Kernel Index 1 (Start 1, Step 4)
    // Expect:
    //   Write 0x11 -> Addr 0, Mask 0010 (Byte 1)
    //   Write 0x22 -> Addr 1, Mask 0010 (Byte 1)
    // ---------------------------------------------------------
    $display("[TB] Test 3: Kernel Index 1 (Start=1, Stride=4)");
    
    cfg_ker_idx    <= 1;
    cfg_start_pass <= 1;
    @(posedge clk);
    cfg_start_pass <= 0;
    @(posedge clk);

    push_pixel(8'h11);
    push_pixel(8'h22);
    
    repeat(10) @(posedge clk);

    $display("=== TEST COMPLETE ===");
    $finish;
  end

endmodule