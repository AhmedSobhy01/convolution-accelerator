`timescale 1ns/1ps
`define USE_POWER_PINS

module tb_conv_accelerator;

  // Clock and reset
  reg clk;
  reg rst_n;

  // Configuration
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;
  reg       cfg_start_pass;
  reg [1:0] cfg_ker_idx;
  reg       cfg_split_mode;

  // Control signals
  reg         start_load;
  wire        load_done;
  reg         start_kernel_load;
  reg  [1:0]  kernel_idx;
  wire        kernel_done;
  reg         start_window;
  reg [15:0]  window_col;
  wire        window_done;
  reg         start_drain;
  wire        drain_done;

  // DRAM interface
  reg [31:0]  rx_data;
  reg         rx_valid;
  wire        rx_ready;
  wire        tx_valid;
  wire [31:0] tx_data;
  reg         tx_ready;

  // SA outputs (DUT -> SA)
  wire        w_valid;
  wire [63:0] w_data;
  wire        p_valid;
  wire [63:0] p_data;

  // SA inputs (SA -> DUT)
  reg         sa_out_valid;
  reg [7:0]   sa_out_data;
  wire        sa_wb_busy;

  // File reading variables
  integer file_handle;
  integer scan_result;
  reg [31:0] data_buffer [0:8191];
  integer data_count;
  integer data_index;

  // ============================================
  // DUT instantiation
  // ============================================
  conv_accelerator_top #(
    .ADDR_W(10),
    .BYTE_ADDR_W(13),
    .KER_BASE_BYTE(4096),
    .IMG_BASE_BYTE(0),
    .SRAM1_ADDR_W(12)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    .cfg_start_pass(cfg_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .cfg_split_mode(cfg_split_mode),
    
    .start_load(start_load),
    .load_done(load_done),
    
    .start_kernel_load(start_kernel_load),
    .kernel_idx(kernel_idx),
    .kernel_done(kernel_done),
    
    .start_window(start_window),
    .window_col(window_col),
    .window_done(window_done),

    .start_drain(start_drain),
    .drain_done(drain_done),
    
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),

    .tx_valid(tx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready),
    
    .w_valid(w_valid),
    .w_data(w_data),
    .p_valid(p_valid),
    .p_data(p_data),
    
    .sa_out_valid(sa_out_valid),
    .sa_out_data(sa_out_data),
    .sa_wb_busy(sa_wb_busy)
  );

  // ============================================
  // Clock generation
  // ============================================
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ============================================
  // File loading task
  // ============================================
  task load_data_file;
    input [1024*8-1:0] filename;
    begin
      file_handle = $fopen(filename, "r");
      if (file_handle == 0) begin
        $display("ERROR: Could not open file %s", filename);
        $finish;
      end
      
      data_count = 0;
      while (!$feof(file_handle)) begin
        scan_result = $fscanf(file_handle, "%h\n", data_buffer[data_count]);
        if (scan_result == 1) begin
          data_count = data_count + 1;
        end
      end
      
      $fclose(file_handle);
      $display("Loaded %0d words from %s", data_count, filename);
    end
  endtask

  // ============================================
  // DRAM Input Streaming
  // ============================================
  initial begin
    rx_data = 32'd0;
    rx_valid = 1'b0;
    data_index = 0;
    
    @(posedge start_load);
    @(posedge clk);
    
    while (data_index < data_count) begin
      rx_data = data_buffer[data_index];
      rx_valid = 1'b1;
      
      @(posedge clk);
      while (!rx_ready) @(posedge clk);
      
      data_index = data_index + 1;
    end
    
    rx_valid = 1'b0;
    rx_data = 32'd0;
  end

  // ============================================
  // Monitor: Kernel loading
  // ============================================
  integer k_count;
  initial begin
    k_count = 0;
    forever begin
      @(posedge clk);
      if (w_valid) begin
        $display("[%0t] Kernel col %0d: %h", $time, k_count, w_data);
        k_count = k_count + 1;
      end
      if (kernel_done) begin
        k_count = 0;
      end
    end
  end

  // ============================================
  // Monitor: Window streaming
  // ============================================
  integer p_count;
  initial begin
    p_count = 0;
    forever begin
      @(posedge clk);
      if (p_valid) begin
        $display("[%0t] Row %0d pixels: %h", $time, p_count, p_data);
        p_count = p_count + 1;
      end
      if (window_done) begin
        p_count = 0;
      end
    end
  end

  // ============================================
  // Main test sequence
  // ============================================
  integer i;
  reg [31:0] expected_drain_data;
  reg [7:0]  px0, px1, px2, px3;
  integer    drain_word_cnt;

  initial begin
    // Initialize
    rst_n = 0;
    start_load = 0;
    start_kernel_load = 0;
    start_window = 0;
    start_drain = 0;
    window_col = 16'd0;
    cfg_N = 7'd8;
    cfg_K = 5'd13;
    cfg_start_pass = 0;
    cfg_ker_idx = 0;
    cfg_split_mode = 1; // Single mode for this test
    tx_ready = 1;
    kernel_idx = 2'd0;
    
    sa_out_valid = 0;
    sa_out_data = 0;
    
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    
    $display("========================================");
    $display("Starting convolution accelerator test");
    $display("========================================");
    
    // ----------------------------------------
    // Phase 1: Load data
    // ----------------------------------------
    $display("\n[%0t] Phase 1: Loading data", $time);
    load_data_file("inputdata.data");
    
    @(posedge clk);
    start_load = 1'b1;
    @(posedge clk);
    start_load = 1'b0;
    
    wait(load_done);
    $display("[%0t] Data load complete", $time);
    
    // ----------------------------------------
    // Phase 2: Load kernel
    // ----------------------------------------
    $display("\n[%0t] Phase 2: Loading kernel", $time);
    repeat(5) @(posedge clk);
    
    start_kernel_load = 1'b1;
    kernel_idx = 2'd0;
    @(posedge clk);
    start_kernel_load = 1'b0;
    
    wait(kernel_done);
    @(posedge clk);
    $display("[%0t] Kernel load complete (Quadrant 0)", $time);

    start_kernel_load = 1'b1;
    kernel_idx = 2'd1;
    @(posedge clk);
    start_kernel_load = 1'b0;
    wait(kernel_done);
    @(posedge clk);
    $display("[%0t] Kernel load complete (Quadrant 1)", $time);

    start_kernel_load = 1'b1;
    kernel_idx = 2'd2;
    @(posedge clk);
    start_kernel_load = 1'b0;
    wait(kernel_done);
    @(posedge clk);
    $display("[%0t] Kernel load complete (Quadrant 2)", $time);

    start_kernel_load = 1'b1;
    kernel_idx = 2'd3;
    @(posedge clk);
    start_kernel_load = 1'b0;
    wait(kernel_done);
    @(posedge clk);
    $display("[%0t] Kernel load complete (Quadrant 3)", $time);
    
    // ----------------------------------------
    // Phase 3A: Window Streaming (Read Path Test)
    // ----------------------------------------
    $display("\n[%0t] Phase 3A: Streaming window (Read Path Check)", $time);
    repeat(5) @(posedge clk);
    
    window_col = 16'd0;
    start_window = 1'b1;
    @(posedge clk);
    start_window = 1'b0;
    
    wait(window_done);
    $display("[%0t] Window stream complete", $time);

    
    // // ----------------------------------------
    // // Phase 3B: Writeback Test (Fill SRAM1)
    // // ----------------------------------------
    // // This phase manually drives the SA interface to fill SRAM1
    // // with a known pattern (0, 1, 2... 63) to test Writeback and prepare for Drain.
    // $display("\n[%0t] Phase 3B: Testing Writeback (Filling SRAM1 with 64 pixels)", $time);
    
    // // 1. Reset WB Pointers
    // cfg_start_pass = 1'b1;
    // @(posedge clk);
    // cfg_start_pass = 1'b0;
    // @(posedge clk);

    // 2. Stream 64 pixels (N*N) into the WB module
    for (i = 1; i < 65; i = i + 1) begin
      // Wait if busy
      while (sa_wb_busy) @(posedge clk);

      sa_out_valid = 1'b1;
      sa_out_data  = i[7:0]; // Data = Index (0x00, 0x01, ... 0x3F)
      @(posedge clk);
    end
    
    sa_out_valid = 1'b0;
    sa_out_data  = 8'd0;
    
    // Allow time for the Writeback FIFO to empty into SRAM1
    repeat(20) @(posedge clk);
   
    // 1. Reset WB Pointers
    cfg_ker_idx = 1;
    cfg_start_pass = 1'b1;
    @(posedge clk);
    cfg_start_pass = 1'b0;
    @(posedge clk);

    // 2. Stream 64 pixels (N*N) into the WB module
    for (i = 1; i < 65; i = i + 1) begin
      // Wait if busy
      while (sa_wb_busy) @(posedge clk);

      sa_out_valid = 1'b1;
      sa_out_data  = i[7:0]; // Data = Index (0x00, 0x01, ... 0x3F)
      @(posedge clk);
    end
    
    sa_out_valid = 1'b0;
    sa_out_data  = 8'd0;
    
    // Allow time for the Writeback FIFO to empty into SRAM1
    repeat(20) @(posedge clk);

      // 1. Reset WB Pointers
    cfg_ker_idx = 2;
    cfg_start_pass = 1'b1;
    @(posedge clk);
    cfg_start_pass = 1'b0;
    @(posedge clk);

    // 2. Stream 64 pixels (N*N) into the WB module
    for (i = 1; i < 65; i = i + 1) begin
      // Wait if busy
      while (sa_wb_busy) @(posedge clk);

      sa_out_valid = 1'b1;
      sa_out_data  = i[7:0]; // Data = Index (0x00, 0x01, ... 0x3F)
      @(posedge clk);
    end
    
    sa_out_valid = 1'b0;
    sa_out_data  = 8'd0;
    
    // Allow time for the Writeback FIFO to empty into SRAM1
    repeat(20) @(posedge clk);


      // 1. Reset WB Pointers
    cfg_ker_idx = 3;
    cfg_start_pass = 1'b1;
    @(posedge clk);
    cfg_start_pass = 1'b0;
    @(posedge clk);

    // 2. Stream 64 pixels (N*N) into the WB module
    for (i = 1; i < 65; i = i + 1) begin
      // Wait if busy
      while (sa_wb_busy) @(posedge clk);

    //   sa_out_valid = 1'b1;
    //   sa_out_data  = i[7:0]; // Data = Index (0x00, 0x01, ... 0x3F)
    //   @(posedge clk);
    // end
    
    // sa_out_valid = 1'b0;
    // sa_out_data  = 8'd0;
    
    // Allow time for the Writeback FIFO to empty into SRAM1
    repeat(20) @(posedge clk);

    $display("[%0t] Writeback filling complete.", $time);


    // // ----------------------------------------
    // // Phase 4: Drain Results & Verify
    // // ----------------------------------------
    // $display("\n[%0t] Phase 4: Draining Results & Verifying", $time);
    
    drain_word_cnt = 0;
    @(negedge clk);
    start_drain = 1'b1;
    @(negedge clk);
    start_drain = 1'b0;

    // // Monitor Loop
    // while (!drain_done) begin
    //   @(posedge clk);
      
    //   if (tx_valid && tx_ready) begin
    //     // Calculate Expected Data
    //     // The Drain module packs 4 pixels into one 32-bit word.
    //     // Word 0 contains pixels [3, 2, 1, 0] -> 0x03020100
    //     // Word 1 contains pixels [7, 6, 5, 4] -> 0x07060504
    //     px0 = (drain_word_cnt * 4) + 0;
    //     px1 = (drain_word_cnt * 4) + 1;
    //     px2 = (drain_word_cnt * 4) + 2;
    //     px3 = (drain_word_cnt * 4) + 3;
        
    //     expected_drain_data = {px3, px2, px1, px0};
        
    //     $write("[%0t] DRAIN OUTPUT: %h ... ", $time, tx_data);
        
        repeat(40) @(posedge clk);
        if (tx_data === expected_drain_data) begin
             $display("PASS (Matches Expected %h)", expected_drain_data);
        end else begin
             $display("FAIL (Expected %h)", expected_drain_data);
             $stop;
        end
        
    //     drain_word_cnt = drain_word_cnt + 1;
    //   end
    // end

    // $display("[%0t] Drain complete. Total Words: %0d", $time, drain_word_cnt);
    
    // // Final check
    // if (drain_word_cnt == 16) begin // 64 pixels / 4 per word = 16 words
    //     $display("\n========================================");
    //     $display("ALL TESTS COMPLETED SUCCESSFULLY!");
    //     $display("========================================");
    // end else begin
    //     $display("\nERROR: Incorrect number of drain words received.");
    // end
    
    $finish;
  end

  initial begin
    $dumpfile("conv_accelerator.vcd");
    $dumpvars(0, tb_conv_accelerator);
  end

  initial begin
    #20000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule