`timescale 1ns/1ps
`define USE_POWER_PINS

module tb_conv_accelerator;

  // Clock and reset
  reg clk;
  reg rst_n;

  // Configuration
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;

  // Control signals
  reg         start_load;
  wire        load_done;
  reg         start_kernel_load;
  wire        kernel_done;
  reg         start_window;
  reg [15:0]  window_col;
  wire        window_done;

  // DRAM interface
  reg [31:0]  rx_data;
  reg         rx_valid;
  wire        rx_ready;

  // SA outputs
  wire        w_valid;
  wire [63:0] w_data;
  wire        p_valid;
  wire [63:0] p_data;

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
    .IMG_BASE_BYTE(0)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    
    .start_load(start_load),
    .load_done(load_done),
    
    .start_kernel_load(start_kernel_load),
    .kernel_done(kernel_done),
    
    .start_window(start_window),
    .window_col(window_col),
    .window_done(window_done),
    
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    
    .w_valid(w_valid),
    .w_data(w_data),
    .p_valid(p_valid),
    .p_data(p_data)
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
  // DRAM streaming process (runs continuously)
  // ============================================
  initial begin
    rx_data = 32'd0;
    rx_valid = 1'b0;
    data_index = 0;
    
    // Wait for load to start
    @(posedge start_load);
    @(posedge clk);
    
    // Stream all data
    while (data_index < data_count) begin
      rx_data = data_buffer[data_index];
      rx_valid = 1'b1;
      
      @(posedge clk);
      
      // Wait for handshake
      while (!rx_ready) begin
        @(posedge clk);
      end
      
      data_index = data_index + 1;
    end
    
    // Done streaming
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
  initial begin
    // Initialize
    rst_n = 0;
    start_load = 0;
    start_kernel_load = 0;
    start_window = 0;
    window_col = 16'd0;
    cfg_N = 7'd8;
    cfg_K = 5'd4;
    
    // Reset
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    
    $display("========================================");
    $display("Starting convolution accelerator test");
    $display("Config: N=%0d, K=%0d", cfg_N, cfg_K);
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
    
    // Wait for load done
    @(posedge load_done);
    @(posedge clk);
    $display("[%0t] Data load complete", $time);
    
    // ----------------------------------------
    // Phase 2: Load kernel
    // ----------------------------------------
    $display("\n[%0t] Phase 2: Loading kernel", $time);
    repeat(5) @(posedge clk);
    
    start_kernel_load = 1'b1;
    @(posedge clk);
    start_kernel_load = 1'b0;
    
    @(posedge kernel_done);
    @(posedge clk);
    $display("[%0t] Kernel load complete", $time);
    
    // ----------------------------------------
    // Phase 3: Stream window
    // ----------------------------------------
    $display("\n[%0t] Phase 3: Streaming window", $time);
    repeat(5) @(posedge clk);
    
    window_col = 16'd0;
    start_window = 1'b1;
    @(posedge clk);
    start_window = 1'b0;
    
    @(posedge window_done);
    @(posedge clk);
    $display("[%0t] Window stream complete", $time);
    
    // ----------------------------------------
    // Done
    // ----------------------------------------
    repeat(10) @(posedge clk);
    $display("\n========================================");
    $display("Test completed successfully!");
    $display("========================================");
    $finish;
  end

  // ============================================
  // Waveform dump
  // ============================================
  initial begin
    $dumpfile("conv_accelerator.vcd");
    $dumpvars(0, tb_conv_accelerator);
  end

  // Timeout
  initial begin
    #1000000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule
