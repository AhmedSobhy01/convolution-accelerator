`timescale 1ns/1ps

module tb_dl_writeback;

  reg clk;
  reg rst_n;

  // Signals
  reg        cfg_start_pass;
  reg [1:0]  cfg_ker_idx;
  reg        sa_valid;
  reg [63:0] sa_wdata;

  wire        sram1_en;
  wire        sram1_we;
  wire [10:0] sram1_addr;
  wire [63:0] sram1_wdata;
  wire [7:0]  sram1_wmask;

  // Simulation Variables
  integer pass, block;
  reg [63:0] mock_data;
  localparam NUM_BLOCKS = 4; 

  // Monitor Variables (Declared here to avoid scope errors)
  reg [1:0] mon_pass_idx;
  integer   mon_block_cnt;
  integer   exp_addr;          // <--- Moved here

  // DUT Instance
  dl_sa_writeback #(
    .ADDR_W(11)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_start_pass(cfg_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .sa_valid(sa_valid),
    .sa_wdata(sa_wdata),
    .sram1_en(sram1_en),
    .sram1_we(sram1_we),
    .sram1_addr(sram1_addr),
    .sram1_wdata(sram1_wdata),
    .sram1_wmask(sram1_wmask)
  );

  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -----------------------------------------------------------------------
  // DRIVER TASK: Sends data with random stalls
  // -----------------------------------------------------------------------
  task send_sa_data;
    input [63:0] data;
    begin
      sa_valid <= 1'b1;
      sa_wdata <= data;
      @(posedge clk);         // Active cycle
      sa_valid <= 1'b0;
      sa_wdata <= 64'd0;
      // Random gap (stalls)
      repeat ($urandom_range(0, 2)) @(posedge clk);
    end
  endtask

  // -----------------------------------------------------------------------
  // MONITOR: Checks outputs independently
  // -----------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst_n) begin
      mon_block_cnt <= 0;
      mon_pass_idx  <= 0;
    end else begin
      // Sync Monitor with Config signals
      if (cfg_start_pass) begin
        mon_pass_idx  <= cfg_ker_idx;
        mon_block_cnt <= 0;
      end 
      
      // Verify Write on Enable
      if (sram1_en && sram1_we) begin
        // Calculate Expected Values
        exp_addr = (mon_block_cnt * 4) + mon_pass_idx;
        
        // Check Address
        if (sram1_addr !== exp_addr[10:0]) begin
          $display("ERROR: Addr Mismatch! Time: %0t, Pass: %0d, Block: %0d", $time, mon_pass_idx, mon_block_cnt);
          $display("       Exp Addr: %0d, Got: %0d", exp_addr, sram1_addr);
          $stop;
        end
        
        // Check Data Payload (specifically the embedded IDs)
        // Payload format: {8'hAA, 8'hBB, pass[7:0], block[7:0], ...}
        if (sram1_wdata[47:40] !== {6'b0, mon_pass_idx} || 
            sram1_wdata[39:32] !== mon_block_cnt[7:0]) begin
          $display("ERROR: Data Mismatch! Time: %0t", $time);
          $display("       Expected payload with Pass=%0d Block=%0d", mon_pass_idx, mon_block_cnt);
          $display("       Got Data: %16h", sram1_wdata);
          $stop;
        end

        $display("[Monitor] OK: Pass %0d Block %0d -> Addr %0d", mon_pass_idx, mon_block_cnt, sram1_addr);
        
        // Advance Monitor Counter
        mon_block_cnt <= mon_block_cnt + 1;
      end
    end
  end

  // -----------------------------------------------------------------------
  // MAIN STIMULUS
  // -----------------------------------------------------------------------
  initial begin
    // Init
    rst_n = 0;
    cfg_start_pass = 0;
    cfg_ker_idx = 0;
    sa_valid = 0;
    sa_wdata = 0;
    mock_data = 0;
    
    #20 rst_n = 1;
    #10;

    $display("\n=== Starting Write-Back Interleave Test ===");

    // Loop through 4 kernel passes (idx 0..3)
    for (pass = 0; pass < 4; pass = pass + 1) begin
      $display("\n--- Stimulus: Pass Kernel Idx %0d ---", pass);
      
      // 1. Pulse start configuration
      cfg_ker_idx <= pass[1:0];
      cfg_start_pass <= 1'b1;
      @(posedge clk);
      cfg_start_pass <= 1'b0;
      @(posedge clk);

      // 2. Send NUM_BLOCKS of data
      for (block = 0; block < NUM_BLOCKS; block = block + 1) begin
        // Construct unique data pattern matching monitor expectations
        mock_data = {8'hAA, 8'hBB, pass[7:0], block[7:0], 32'h12345678}; 
        send_sa_data(mock_data);
      end
      
      // Allow valid signal to settle before next pass
      repeat(2) @(posedge clk);
    end
    
    repeat(5) @(posedge clk);
    $display("\n=== ALL TESTS PASSED ===");
    $finish;
  end

endmodule