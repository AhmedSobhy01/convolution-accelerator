`timescale 1ns/1ps

module tb_conv_accel_simple;

  // Test case selection parameter
  parameter TEST_CASE = 2;  // Default to test case 01

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
  wire [7:0]  tx_data;
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

  // Test case path construction
  reg [1024*8-1:0] test_name;
  reg [1024*8-1:0] config_path;
  reg [1024*8-1:0] input_path;
  reg [1024*8-1:0] kernel_path;

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
  integer cycle_count;

  initial begin
    clk = 0;
    cycle_count = 0;
    forever #5 clk = ~clk;
  end

  reg counting;
  initial begin
    counting = 0;
    @(posedge start);
    counting = 1;
  end

  always @(posedge clk) begin
    if (counting && !done)
      cycle_count <= cycle_count + 1;
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

    tx_ready = 1'b1;
    tx_word_count = 0;
    pixel_count = 0;

    @(posedge start);

    output_file = $fopen("output_data.txt", "w");

    forever begin
      @(posedge clk);
      if (tx_valid && tx_ready) begin

        $fwrite(output_file, "%c%c\n",
          hex_char(tx_data[7:4]),
          hex_char(tx_data[3:0]));
          pixel_count = pixel_count + 1;

        $display("[%0t] TX: %02X (byte %0d, pixels written: %0d)", $time,
                 tx_data, tx_word_count, pixel_count);
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

    // Construct test case paths based on TEST_CASE parameter
    case (TEST_CASE)
      1:  test_name = "01_Basic_Minimal";
      2:  test_name = "02_Basic_Identity";
      3:  test_name = "03_Basic_AllOnes";
      4:  test_name = "04_Regular_Standard";
      5:  test_name = "05_Regular_LargeHalo";
      6:  test_name = "06_Regular_PingPong";
      7:  test_name = "07_Adv_MaxSpec";
      8:  test_name = "08_Adv_Throughput";
      9:  test_name = "09_Pro_PartialTile";
      10: test_name = "10_Pro_Saturation";
      default: begin
        $display("ERROR: Invalid TEST_CASE=%0d. Valid range is 1-10.", TEST_CASE);
        $finish;
      end
    endcase

    $sformat(config_path, "./test_cases/%0s_config.txt", test_name);
    $sformat(input_path, "./test_cases/%0s_in.hex", test_name);
    $sformat(kernel_path, "./test_cases/%0s_weight.hex", test_name);

    $display("Running test case: %0s", test_name);
    $display("Config:  %0s", config_path);
    $display("Input:   %0s", input_path);
    $display("Kernel:  %0s", kernel_path);

    load_config_file(config_path);
    cfg_N = parsed_n[6:0];
    cfg_K = parsed_k[4:0];
    cfg_output_size = parsed_output_size[15:0];

    $display("Configuration: N=%0d, K=%0d, Expected Output Size=%0d", cfg_N, cfg_K, cfg_output_size);

    load_input_file(input_path);

    load_kernel_file(kernel_path);

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
    $display("Total cycles: %0d", cycle_count);
    $display("Expected output size: %0d x %0d = %0d pixels",
             cfg_N - cfg_K + 1, cfg_N - cfg_K + 1,
             (cfg_N - cfg_K + 1) * (cfg_N - cfg_K + 1));
    $display("Expected TX bytes: %0d (1 pixel per byte)",
             (cfg_N - cfg_K + 1) * (cfg_N - cfg_K + 1));

    $finish;
  end

  initial begin
    @(posedge start);
    forever begin
      #10000;
      $display("[%0t] DEBUG: CU_state=%0d, kernel_done=%b, window_done=%b, load_kernel=%b, load_column=%b, drain_start=%b, drain_done=%b",
               $time,
               dut.u_control.state,
               dut.u_streamer.kernel_done,
               dut.u_streamer.window_done,
               dut.u_control.load_kernel,
               dut.u_control.load_column,
               dut.u_control.start_sending_output_to_dram,
               dut.u_drain.done);
    end
  end

  // Timeout watchdog
  initial begin
    #500000;
    $display("ERROR: Simulation timeout!");
    $finish;
  end

  // VCD dump
  initial begin
    $dumpfile("tb_conv_accel_simple.vcd");
    $dumpvars(0, tb_conv_accel_simple);
  end

endmodule
