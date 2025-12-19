`timescale 1ns/1ps

module tb_unaligned_memory_reader;

  reg         clk;
  reg         rst_n;
  
  // Request interface
  reg         req_valid;
  reg [9:0]   byte_addr;
  reg [2:0]   len_bytes;
  wire        req_ready;
  
  // Response interface
  wire        resp_valid;
  wire [63:0] resp_data;
  
  // DUT instantiation
  unaligned_memory_reader dut (
    .clk(clk),
    .rst_n(rst_n),
    `ifdef USE_POWER_PINS
      .vccd1(1'b1),
      .vssd1(1'b0),
    `endif
    .req_valid(req_valid),
    .byte_addr(byte_addr),
    .len_bytes(len_bytes),
    .req_ready(req_ready),
    .resp_valid(resp_valid),
    .resp_data(resp_data)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Test variables
  integer test_num;
  integer pass_count;
  integer fail_count;
  
  // Queue for expected results
  reg [63:0] expected_queue [0:99];
  integer expected_wr_ptr;
  integer expected_rd_ptr;
  integer expected_count;
  
  // Queue for captured outputs
  reg [63:0] captured_queue [0:99];
  integer captured_wr_ptr;
  integer captured_count;
  
  // Initialize SRAM with test data matching Python code
  initial begin
    // Wait for reset and a few cycles
    #100;
    
    // Write test data to SRAM using port 0
    // Python data (as hex strings):
    //   sram[0] = "0807060504030201"
    //   sram[1] = "100F0E0D0C0B0A09"
    //   sram[2] = "1817161514131211"
    //   sram[3] = "0000000000000019"
    
    $display("Initializing SRAM...");
    write_sram(10'd0, 64'h0807060504030201);
    write_sram(10'd1, 64'h100F0E0D0C0B0A09);
    write_sram(10'd2, 64'h1817161514131211);
    write_sram(10'd3, 64'h0000000000000019);
    
    $display("SRAM initialized with test data");
    $display("  Word 0: 0x0807060504030201");
    $display("  Word 1: 0x100F0E0D0C0B0A09");
    $display("  Word 2: 0x1817161514131211");
    $display("  Word 3: 0x0000000000000019");
  end
  
  // Capture outputs on negedge when resp_valid is high
  always @(negedge clk) begin
    if (rst_n && resp_valid) begin
      captured_queue[captured_wr_ptr] = resp_data;
      captured_wr_ptr = captured_wr_ptr + 1;
      captured_count = captured_count + 1;
      $display("[Time=%0t] Captured output: 0x%016X", $time, resp_data);
    end
  end
  
  // Test stimulus
  initial begin
    
    // Initialize signals
    rst_n = 0;
    req_valid = 0;
    byte_addr = 0;
    len_bytes = 0;
    test_num = 0;
    pass_count = 0;
    fail_count = 0;
    expected_wr_ptr = 0;
    expected_rd_ptr = 0;
    expected_count = 0;
    captured_wr_ptr = 0;
    captured_count = 0;
    
    // Reset
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);
    
    // Wait for SRAM initialization
    repeat(30) @(posedge clk);
    
    $display("\n========================================");
    $display("=== Starting Unaligned Memory Tests ===");
    $display("=== PIPELINED - 1 cycle latency ===");
    $display("========================================\n");
    
    // Pipeline test - send requests back-to-back
    $display("=== Back-to-back Pipeline Test ===\n");
    $display("Issuing 5 back-to-back requests...\n");
    
    // Queue expected results FIRST
    queue_expected(64'h0000000504030201); // byte_addr=0, len=5
    queue_expected(64'h0000000A09080706); // byte_addr=5, len=5
    queue_expected(64'h0000000F0E0D0C0B); // byte_addr=10, len=5
    queue_expected(64'h0000001413121110); // byte_addr=15, len=5
    queue_expected(64'h0000001918171615); // byte_addr=20, len=5
    
    // Send requests
    send_request_async(10'd0, 3'd5);
    send_request_async(10'd5, 3'd5);
    send_request_async(10'd10, 3'd5);
    send_request_async(10'd15, 3'd5);
    send_request_async(10'd20, 3'd5);
    
    // Wait for all results to be captured
    wait(captured_count >= 5);
    @(posedge clk);
    
    // Verify the first 5 results
    $display("\n=== Verifying Back-to-back Pipeline Results ===\n");
    verify_outputs(5);
    
    $display("\n========================================");
    $display("=== Individual Request Tests ===");
    $display("========================================\n");
    
    // Test 6: Aligned 8-byte read at byte_addr=0
    $display("Test 6: Aligned 8-byte read at byte_addr=0");
    queue_expected(64'h0807060504030201);
    send_request_async(10'd0, 3'd0);
    wait(captured_count >= 6);
    @(posedge clk);
    
    // Test 7: Single byte read at byte_addr=7
    $display("\nTest 7: Single byte read at byte_addr=7");
    queue_expected(64'h0000000000000008);
    send_request_async(10'd7, 3'd1);
    wait(captured_count >= 7);
    @(posedge clk);
    
    // Test 8: Read crossing word boundary at byte_addr=6
    $display("\nTest 8: 5-byte read at byte_addr=6");
    queue_expected(64'h00000B0A09080706);
    send_request_async(10'd6, 3'd5);
    wait(captured_count >= 8);
    @(posedge clk);
    
    // Test 9: Aligned read at word 1
    $display("\nTest 9: Aligned 8-byte read at byte_addr=8");
    queue_expected(64'h100F0E0D0C0B0A09);
    send_request_async(10'd8, 3'd0);
    wait(captured_count >= 9);
    @(posedge clk);
    
    // Verify remaining tests
    $display("\n=== Verifying Individual Request Results ===\n");
    verify_outputs(4);
    
    $display("\n========================================");
    $display("=== Test Summary ===");
    $display("========================================");
    $display("Total Tests: %0d", pass_count + fail_count);
    $display("Passed:      %0d", pass_count);
    $display("Failed:      %0d", fail_count);
    
    if (fail_count == 0) begin
      $display("\n*** ALL TESTS PASSED! ***\n");
    end else begin
      $display("\n*** SOME TESTS FAILED ***\n");
    end
    
    repeat(10) @(posedge clk);
    $finish;
  end
  
  // Task to queue an expected result
  task queue_expected(input [63:0] expected);
    begin
      expected_queue[expected_wr_ptr] = expected;
      expected_wr_ptr = expected_wr_ptr + 1;
      expected_count = expected_count + 1;
    end
  endtask
  
  // Task to verify outputs
  task verify_outputs(input integer num_to_verify);
    integer i;
    reg [63:0] expected_val;
    reg [63:0] captured_val;
    begin
      for (i = 0; i < num_to_verify; i = i + 1) begin
        expected_val = expected_queue[expected_rd_ptr];
        captured_val = captured_queue[expected_rd_ptr];
        
        $display("Test %0d:", expected_rd_ptr + 1);
        $display("  Expected: 0x%016X", expected_val);
        $display("  Got:      0x%016X", captured_val);
        
        if (captured_val === expected_val) begin
          $display("  Result:   PASS ✓");
          pass_count = pass_count + 1;
        end else begin
          $display("  Result:   FAIL ✗");
          $display("  ERROR: Mismatch!");
          fail_count = fail_count + 1;
        end
        $display("");
        
        expected_rd_ptr = expected_rd_ptr + 1;
      end
    end
  endtask
  
  // Task to send request without waiting
  task send_request_async(input [9:0] addr, input [2:0] len);
    begin
      @(posedge clk);
      byte_addr = addr;
      len_bytes = len;
      req_valid = 1;
      $display("[Time=%0t] Sent request: byte_addr=%0d, len_bytes=%0d", $time, addr, len);
			@(posedge clk);
      req_valid = 0;

    end
  endtask
  
  // Task to write to SRAM
  task write_sram(input [9:0] addr, input [63:0] data);
    begin
      @(posedge clk);
      force dut.u_sram.p0_en = 1'b1;
      force dut.u_sram.p0_we = 1'b1;
      force dut.u_sram.p0_addr = addr;
      force dut.u_sram.p0_wdata = data;
      force dut.u_sram.p0_wmask = 8'hFF;
      
      @(posedge clk);
      @(posedge clk);  // Extra cycle for write to complete
      
      release dut.u_sram.p0_en;
      release dut.u_sram.p0_we;
      release dut.u_sram.p0_addr;
      release dut.u_sram.p0_wdata;
      release dut.u_sram.p0_wmask;
      
      @(posedge clk);
    end
  endtask
  
  // Timeout watchdog
  initial begin
    #100000;  // 100us timeout
    $display("\n*** ERROR: Simulation timeout! ***\n");
    $finish;
  end

endmodule