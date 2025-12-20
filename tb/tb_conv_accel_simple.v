`timescale 1ns/1ps

module tb_conv_accel_simple;

  // Clock and reset
  reg clk;
  reg rst_n;

  // Configuration
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;

  // Control
  reg start;
  wire done;

  // DRAM interface
  reg [7:0]   rx_data;
  reg         rx_valid;
  wire        rx_ready;
  wire        tx_valid;
  wire [31:0] tx_data;
  reg         tx_ready;

  // File reading variables
  integer file_handle;
  integer scan_result;
  reg [7:0] data_buffer [0:65535]; // pick a size big enough
  integer data_count;
  integer data_index;

  // Output capture
  integer output_file;
  integer tx_word_count;

  // ============================================
  // DUT instantiation
  // ============================================
  conv_accelerator_top #(
    .ADDR_W(10),
    .BYTE_ADDR_W(13),
    .KER_BASE_BYTE(4096),
    .IMG_BASE_BYTE(0),
    .SRAM1_ADDR_W(12),
    .SA_DIM(8),
    .SA_INPUT_FILL_TIME(8)
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
    .tx_valid(tx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready)
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
    integer tmp;
    begin
      file_handle = $fopen(filename, "r");
      if (file_handle == 0) begin
        $display("ERROR: Could not open file %s", filename);
        $finish;
      end

      data_count = 0;
      while (!$feof(file_handle)) begin
        tmp = 0;
        scan_result = $fscanf(file_handle, "%h\n", tmp);
        if (scan_result == 1) begin
          data_buffer[data_count] = tmp[7:0];
          data_count = data_count + 1;
        end
      end

      $fclose(file_handle);
      $display("Loaded %0d bytes from %s", data_count, filename);
    end
  endtask

  // ============================================
  // DRAM Input Streaming
  // ============================================
  initial begin
    rx_data   = 8'd0;
    rx_valid  = 1'b0;
    data_index = 0;

    @(posedge start);
    @(posedge clk);

    rx_valid = 1'b1;
    while (data_index < data_count) begin
      rx_data = data_buffer[data_index];

      @(posedge clk);
      if (rx_ready) begin
        data_index = data_index + 1;
      end
      // else: keep same rx_data and keep rx_valid high until accepted
    end

    rx_valid = 1'b0;
    rx_data  = 8'd0;
    $display("[%0t] Input data streaming complete", $time);
  end

  // ============================================
  // DRAM Output Capture
  // ============================================
  initial begin : output_capture
    tx_ready = 1'b1;
    tx_word_count = 0;

    @(posedge start);

    output_file = $fopen("output_data.txt", "w");

    forever begin
      @(posedge clk);
      if (tx_valid && tx_ready) begin
        // Write each byte on a separate line in uppercase hex
        $fwrite(output_file, "%c%c\n",
          hex_char(tx_data[7:4]),
          hex_char(tx_data[3:0]));

        $fwrite(output_file, "%c%c\n",
          hex_char(tx_data[15:12]),
          hex_char(tx_data[11:8]));

        $fwrite(output_file, "%c%c\n",
          hex_char(tx_data[23:20]),
          hex_char(tx_data[19:16]));

        $fwrite(output_file, "%c%c\n",
          hex_char(tx_data[31:28]),
          hex_char(tx_data[27:24]));

        $display("[%0t] TX: %02X %02X %02X %02X (word %0d)", $time, 
                 tx_data[7:0], tx_data[15:8], tx_data[23:16], tx_data[31:24], tx_word_count);
        tx_word_count = tx_word_count + 1;
      end

      if (done) begin
        $fclose(output_file);
        $display("[%0t] Output capture complete. Total words: %0d", $time, tx_word_count);
        disable output_capture;
      end
    end
  end
  function automatic [7:0] hex_char(input [3:0] nibble);
    if (nibble < 4'd10)
      hex_char = "0" + nibble;
    else
      hex_char = "A" + (nibble - 4'd10);
  endfunction


  // ============================================
  // Main test sequence
  // ============================================
  initial begin
    // Initialize
    rst_n = 0;
    start = 0;
    cfg_N = 6'd16;
    cfg_K = 4'd2;

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    $display("========================================");
    $display("Convolution Accelerator Test");
    $display("========================================");
    $display("Configuration: N=%0d, K=%0d", cfg_N, cfg_K);

    // Load input data file
    load_data_file("./tb/inputdata.data");

    // Start convolution
    $display("\n[%0t] Starting convolution operation", $time);
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    // Wait for completion
    wait(done);
    repeat(10) @(posedge clk);

    $display("\n========================================");
    $display("TEST COMPLETED SUCCESSFULLY");
    $display("========================================");
    $display("Expected output size: %0d x %0d = %0d pixels",
             cfg_N - cfg_K + 1, cfg_N - cfg_K + 1,
             (cfg_N - cfg_K + 1) * (cfg_N - cfg_K + 1));
    $display("Expected TX words: %0d (4 pixels per word)",
             ((cfg_N - cfg_K + 1) * (cfg_N - cfg_K + 1)) / 4);

    $finish;
  end

  // Timeout watchdog
  initial begin
    #50000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

  // VCD dump
  initial begin
    $dumpfile("tb_conv_accel_simple.vcd");
    $dumpvars(0, tb_conv_accel_simple);
  end

endmodule
