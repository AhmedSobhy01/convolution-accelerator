`timescale 1ns/1ps

module tb_agu_top;

  // Signals
  reg clk, rst_n;
  reg [2:0] cmd;
  reg cmd_start;
  wire cmd_done;

  reg [6:0] cfg_N;
  reg [4:0] cfg_K;
  reg [1:0] cfg_ker_idx;
  reg [6:0] cfg_col_idx;
  reg cfg_split_mode;
  reg cfg_wb_start_pass;

  reg [31:0] dram_rx_data;
  reg dram_rx_valid;
  wire dram_rx_ready;
  wire dram_tx_valid;
  wire [31:0] dram_tx_data;
  reg dram_tx_ready;

  wire [63:0] sa_weight_data;
  wire sa_weight_valid;
  wire [63:0] sa_pixel_data;
  wire sa_pixel_valid;
  reg [63:0] sa_out_data;
  reg sa_out_valid;

  localparam CLK_PERIOD = 10;

  // DUT
  agu_top #(.ADDR_W(10), .DATA_W(32)) dut (
    .clk(clk), .rst_n(rst_n),
    .cmd(cmd), .cmd_start(cmd_start), .cmd_done(cmd_done),
    .cfg_N(cfg_N), .cfg_K(cfg_K), .cfg_ker_idx(cfg_ker_idx),
    .cfg_col_idx(cfg_col_idx), .cfg_split_mode(cfg_split_mode),
    .cfg_wb_start_pass(cfg_wb_start_pass),
    .dram_rx_data(dram_rx_data), .dram_rx_valid(dram_rx_valid), .dram_rx_ready(dram_rx_ready),
    .dram_tx_valid(dram_tx_valid), .dram_tx_data(dram_tx_data), .dram_tx_ready(dram_tx_ready),
    .sa_weight_data(sa_weight_data), .sa_weight_valid(sa_weight_valid),
    .sa_pixel_data(sa_pixel_data), .sa_pixel_valid(sa_pixel_valid),
    .sa_out_data(sa_out_data), .sa_out_valid(sa_out_valid)
  );

  // Clock
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // =========================================================
  // FIXED MOCK SA (Pipelined to accept stream without dropping)
  // =========================================================
  reg [1:0] sa_valid_pipe;
  reg [7:0] sa_mock_counter;
  
  initial sa_mock_counter = 0;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sa_valid_pipe <= 0;
        sa_out_valid <= 0;
        sa_out_data <= 0;
    end else begin
        // Shift register for 2-cycle latency
        sa_valid_pipe <= {sa_valid_pipe[0], sa_pixel_valid};
        
        // Output validity follows the pipeline
        sa_out_valid <= sa_valid_pipe[1];
        
        // Data generation (increments for every valid output)
        if (sa_valid_pipe[1]) begin
             sa_out_data <= {8{sa_mock_counter + 8'd1}}; 
             sa_mock_counter <= sa_mock_counter + 1;
        end else begin
             sa_out_data <= 0;
        end
    end
  end

  // Task: DRAM Stream
  task dram_send_stream;
    input [31:0] count;
    integer k;
    begin
      for (k = 0; k < count; k = k + 1) begin
        while (!dram_rx_ready) @(posedge clk);
        dram_rx_valid <= 1;
        dram_rx_data  <= k; 
        @(posedge clk);
        dram_rx_valid <= 0;
        if (($random & 3) == 0) @(posedge clk); 
      end
    end
  endtask

  // Main Stimulus
  integer i, timeout_cnt;
  
  initial begin
    rst_n = 0;
    cmd = 0; cmd_start = 0;
    cfg_N = 16; cfg_K = 4; cfg_split_mode = 0;
    dram_rx_data = 0; dram_rx_valid = 0; dram_tx_ready = 1;
    
    #100 rst_n = 1;
    #20;
    
    // 1. LOAD DATA (72 words)
    $display("\n[TB] CMD: LOAD_DATA");
    cmd = 3'd1; cmd_start = 1; @(posedge clk); cmd_start = 0;
    fork
      dram_send_stream(72);
      begin
        wait(cmd_done);
        $display("[TB] LOAD_DATA Done.");
      end
    join
    @(posedge clk);

    // 2. LOAD KERNEL
    $display("\n[TB] CMD: LOAD_KERNEL_IDX");
    cmd = 3'd2; cfg_ker_idx = 0; cmd_start = 1; @(posedge clk); cmd_start = 0;
    wait(cmd_done);
    @(posedge clk);

    // 3. COMPUTE ALL COLUMNS (0 to 15)
    // This fills the entire 16x16 output memory
    $display("\n[TB] Starting Computation Loop (Cols 0..15)...");
    
    // Reset writeback pointers ONCE at the start of the pass
    cfg_wb_start_pass = 1; 
    @(posedge clk);
    cfg_wb_start_pass = 0;

    for (i = 0; i < 16; i = i + 1) begin
        cmd = 3'd3; // LOAD_COL
        cfg_col_idx = i[6:0];
        cmd_start = 1; 
        @(posedge clk); 
        cmd_start = 0;
        
        wait(cmd_done);
        // Small gap between columns
        repeat(5) @(posedge clk);
    end
    $display("[TB] All Columns Computed.");

    // Wait for Mock SA pipeline to flush final pixels
    repeat(50) @(posedge clk);

    // 4. DRAIN
    $display("\n[TB] CMD: DRAIN");
    cmd = 3'd4; cmd_start = 1; @(posedge clk); cmd_start = 0;
    
    fork
      wait(cmd_done);
      begin
         // Watch output
         while (!cmd_done) begin
           @(posedge clk);
           if (dram_tx_valid) begin
             // Verify data is not X
             if (dram_tx_data === 32'bx) 
                 $display("[TB] ERROR: Saw X in output!");
             else
                 $display("[TB] DRAIN Output: %h", dram_tx_data);
           end
         end
      end
    join

    $display("\n=== TEST COMPLETE ===");
    $stop;
  end

endmodule