`timescale 1ns/1ps

module tb_conv_accel_simple;

  // Clock and reset
  reg clk;
  reg rst_n;

  // Configuration
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;
  reg [15:0] cfg_output_size;

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
  integer input_count;  // Tracks where input data ends

  // Config file parsing
  integer cfg_file;
  reg [8*256-1:0] line_buffer;
  integer parsed_n, parsed_k, parsed_output_size;

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
  // Config file loading task
  // ============================================
  task load_config_file;
    input [1024*8-1:0] filename;
    integer val;
    reg [8*256-1:0] line;
    begin
      cfg_file = $fopen(filename, "r");
      if (cfg_file == 0) begin
        $display("ERROR: Could not open config file %s", filename);
        $finish;
      end

      parsed_n = 0;
      parsed_k = 0;
      parsed_output_size = 0;

      while (!$feof(cfg_file)) begin
        scan_result = $fgets(line, cfg_file);
        if (scan_result != 0) begin
          val = 0;
          if ($sscanf(line, "N=%d", val) == 1) begin
            parsed_n = val;
          end
          else if ($sscanf(line, "K=%d", val) == 1) begin
            parsed_k = val;
          end
          else if ($sscanf(line, "Output_Size=%d", val) == 1) begin
            parsed_output_size = val;
          end
        end
      end

      $fclose(cfg_file);
      $display("Config loaded: N=%0d, K=%0d, Output_Size=%0d", parsed_n, parsed_k, parsed_output_size);
    end
  endtask

  // ============================================
  // Input file loading task (loads at offset 0)
  // ============================================
  task load_input_file;
    input [1024*8-1:0] filename;
    integer tmp;
    integer local_count;
    begin
      file_handle = $fopen(filename, "r");
      if (file_handle == 0) begin
        $display("ERROR: Could not open file %s", filename);
        $finish;
      end

      local_count = 0;
      while (!$feof(file_handle)) begin
        tmp = 0;
        scan_result = $fscanf(file_handle, "%h\n", tmp);
        if (scan_result == 1) begin
          data_buffer[local_count] = tmp[7:0];
          local_count = local_count + 1;
        end
      end

      input_count = local_count;  // Save input count for kernel appending
      data_count = local_count;

      $fclose(file_handle);
      $display("Loaded %0d bytes from %s (input data)", local_count, filename);
    end
  endtask

  // ============================================
  // Kernel file loading task (appends after input data)
  // ============================================
  task load_kernel_file;
    input [1024*8-1:0] filename;
    integer tmp;
    integer local_count;
    begin
      file_handle = $fopen(filename, "r");
      if (file_handle == 0) begin
        $display("ERROR: Could not open file %s", filename);
        $finish;
      end

      local_count = 0;
      while (!$feof(file_handle)) begin
        tmp = 0;
        scan_result = $fscanf(file_handle, "%h\n", tmp);
        if (scan_result == 1) begin
          // Append kernel immediately after input data
          data_buffer[input_count + local_count] = tmp[7:0];
          local_count = local_count + 1;
        end
      end

      // Total data is input + kernel
      data_count = input_count + local_count;

      $fclose(file_handle);
      $display("Loaded %0d bytes from %s (kernel data, appended after input)", local_count, filename);
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
    integer pixel_count;
    integer pixels_remaining;

    tx_ready = 1'b1;
    tx_word_count = 0;
    pixel_count = 0;

    @(posedge start);

    output_file = $fopen("output_data.txt", "w");

    forever begin
      @(posedge clk);
      if (tx_valid && tx_ready) begin
        pixels_remaining = cfg_output_size - pixel_count;

        if (pixels_remaining > 0) begin
          $fwrite(output_file, "%c%c\n",
            hex_char(tx_data[7:4]),
            hex_char(tx_data[3:0]));
          pixel_count = pixel_count + 1;
        end

        if (pixels_remaining > 1) begin
          $fwrite(output_file, "%c%c\n",
            hex_char(tx_data[15:12]),
            hex_char(tx_data[11:8]));
          pixel_count = pixel_count + 1;
        end

        if (pixels_remaining > 2) begin
          $fwrite(output_file, "%c%c\n",
            hex_char(tx_data[23:20]),
            hex_char(tx_data[19:16]));
          pixel_count = pixel_count + 1;
        end

        if (pixels_remaining > 3) begin
          $fwrite(output_file, "%c%c\n",
            hex_char(tx_data[31:28]),
            hex_char(tx_data[27:24]));
          pixel_count = pixel_count + 1;
        end

        $display("[%0t] TX: %02X %02X %02X %02X (word %0d, pixels written: %0d)", $time,
                 tx_data[7:0], tx_data[15:8], tx_data[23:16], tx_data[31:24], tx_word_count, pixel_count);
        tx_word_count = tx_word_count + 1;
      end

      if (done) begin
        $fclose(output_file);
        $display("[%0t] Output capture complete. Total words: %0d, Total pixels: %0d", $time, tx_word_count, pixel_count);
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
    cfg_N = 7'd0;
    cfg_K = 5'd0;
    cfg_output_size = 16'd0;

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    $display("========================================");
    $display("Convolution Accelerator Test");
    $display("========================================");

    load_config_file("./tb/config.txt");
    cfg_N = parsed_n[6:0];
    cfg_K = parsed_k[4:0];
    cfg_output_size = parsed_output_size[15:0];

    $display("Configuration: N=%0d, K=%0d, Expected Output Size=%0d", cfg_N, cfg_K, cfg_output_size);

    load_input_file("./tb/input.hex");

    load_kernel_file("./tb/kernel.hex");

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
