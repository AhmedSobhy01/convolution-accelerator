`timescale 1ns/1ps
`define USE_POWER_PINS

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

  // SRAM interface signals from DUT
  wire         dut_sram_p0_en;
  wire [9:0]   dut_sram_p0_addr;
  wire [63:0]  dut_sram_p0_rdata;
  wire         dut_sram_p1_en;
  wire [9:0]   dut_sram_p1_addr;
  wire [63:0]  dut_sram_p1_rdata;
  
  // Testbench write control signals
  reg          tb_wr_en;
  reg [9:0]    tb_wr_addr;
  reg [63:0]   tb_wr_data;
  reg [7:0]    tb_wr_mask;
  
  // Muxed SRAM signals
  wire         sram_p0_en;
  wire         sram_p0_we;
  wire [9:0]   sram_p0_addr;
  wire [63:0]  sram_p0_wdata;
  wire [7:0]   sram_p0_wmask;
  wire [63:0]  sram_p0_rdata;
  
  wire         sram_p1_en;
  wire [9:0]   sram_p1_addr;
  wire [63:0]  sram_p1_rdata;
  
  // MUX: When tb_wr_en is high, testbench controls port 0 for writing
  //      Otherwise, DUT controls port 0 for reading
  assign sram_p0_en    = tb_wr_en ? 1'b1         : dut_sram_p0_en;
  assign sram_p0_we    = tb_wr_en ? 1'b1         : 1'b0;  // DUT only reads
  assign sram_p0_addr  = tb_wr_en ? tb_wr_addr   : dut_sram_p0_addr;
  assign sram_p0_wdata = tb_wr_data;
  assign sram_p0_wmask = tb_wr_mask;
  
  // Port 1 is always controlled by DUT (read-only port)
  assign sram_p1_en   = dut_sram_p1_en;
  assign sram_p1_addr = dut_sram_p1_addr;
  
  // Connect SRAM read data back to DUT
  assign dut_sram_p0_rdata = sram_p0_rdata;
  assign dut_sram_p1_rdata = sram_p1_rdata;

	`ifdef USE_POWER_PINS
		supply1 vccd1;
		supply0 vssd1;
	`endif
  
  // SRAM instance
  sram0_1rw1r_64x1024_wrapper u_sram (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    
    // Port 0 - Muxed between testbench write and DUT read
    .p0_en(sram_p0_en),
    .p0_we(sram_p0_we),
    .p0_addr(sram_p0_addr),
    .p0_wdata(sram_p0_wdata),
    .p0_wmask(sram_p0_wmask),
    .p0_rdata(sram_p0_rdata),
    
    // Port 1 - DUT read only
    .p1_en(sram_p1_en),
    .p1_addr(sram_p1_addr),
    .p1_rdata(sram_p1_rdata)
  );
  
  // DUT instantiation
  unaligned_memory_reader dut (
    .clk(clk),
    .rst_n(rst_n),
    .req_valid(req_valid),
    .byte_addr(byte_addr),
    .len_bytes(len_bytes),
    .req_ready(req_ready),
    .resp_valid(resp_valid),
    .resp_data(resp_data),
    .sram_p0_en(dut_sram_p0_en),
    .sram_p0_addr(dut_sram_p0_addr),
    .sram_p0_rdata(dut_sram_p0_rdata),
    .sram_p1_en(dut_sram_p1_en),
    .sram_p1_addr(dut_sram_p1_addr),
    .sram_p1_rdata(dut_sram_p1_rdata)
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
  
  // Capture outputs when resp_valid is high
  always @(posedge clk) begin
    if (rst_n && resp_valid) begin
      captured_queue[captured_wr_ptr] = resp_data;
      captured_wr_ptr = captured_wr_ptr + 1;
      captured_count = captured_count + 1;
      $display("[Time=%0t] Captured output: 0x%016h", $time, resp_data);
    end
  end
  
  // Test stimulus
  initial begin
    $dumpfile("tb_unaligned_memory_reader.vcd");
    $dumpvars(0, tb_unaligned_memory_reader);
    
    // Initialize signals
    rst_n = 0;
    req_valid = 0;
    byte_addr = 0;
    len_bytes = 0;
    tb_wr_en = 0;
    tb_wr_addr = 0;
    tb_wr_data = 0;
    tb_wr_mask = 8'hFF;
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
    
    // Initialize SRAM with test data
    $display("\n========================================");
    $display("=== Initializing SRAM with Test Data ===");
    $display("========================================\n");
    
    write_sram(10'd0, 64'h0807060504030201);
    write_sram(10'd1, 64'h100F0E0D0C0B0A09);
    write_sram(10'd2, 64'h1817161514131211);
    write_sram(10'd3, 64'h0000000000000019);
    
    $display("SRAM initialized:");
    $display("  Word 0 (addr 0): 0x0807060504030201");
    $display("  Word 1 (addr 1): 0x100F0E0D0C0B0A09");
    $display("  Word 2 (addr 2): 0x1817161514131211");
    $display("  Word 3 (addr 3): 0x0000000000000019");
    
    repeat(10) @(posedge clk);
    
    $display("\n========================================");
    $display("=== Starting Unaligned Memory Tests ===");
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
    repeat(3) @(posedge clk);
    
    // Verify the first 5 results
    $display("\n=== Verifying Back-to-back Pipeline Results ===\n");
    verify_outputs(5);
    
    $display("\n========================================");
    $display("=== Individual Request Tests ===");
    $display("========================================\n");
    
    // Test 6: Aligned 8-byte read at byte_addr=0
    $display("Test 6: Aligned 8-byte read at byte_addr=0");
    queue_expected(64'h0807060504030201);
    send_request_async(10'd0, 3'd0);  // len=0 means 8 bytes
    wait(captured_count >= 6);
    repeat(2) @(posedge clk);
    
    // Test 7: Single byte read at byte_addr=7
    $display("\nTest 7: Single byte read at byte_addr=7");
    queue_expected(64'h0000000000000008);
    send_request_async(10'd7, 3'd1);
    wait(captured_count >= 7);
    repeat(2) @(posedge clk);
    
    // Test 8: Read crossing word boundary at byte_addr=6
    $display("\nTest 8: 5-byte read at byte_addr=6 (crosses word boundary)");
    queue_expected(64'h0000000B0A090807);  // Fixed: was 0x00000B0A09080706
    send_request_async(10'd6, 3'd5);
    wait(captured_count >= 8);
    repeat(2) @(posedge clk);
    
    // Test 9: Aligned read at word 1
    $display("\nTest 9: Aligned 8-byte read at byte_addr=8");
    queue_expected(64'h100F0E0D0C0B0A09);
    send_request_async(10'd8, 3'd0);  // len=0 means 8 bytes
    wait(captured_count >= 9);
    repeat(2) @(posedge clk);
    
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
  
  // Task to write to SRAM via testbench control
  task write_sram(input [9:0] addr, input [63:0] data);
    begin
      @(posedge clk);
      tb_wr_en = 1'b1;
      tb_wr_addr = addr;
      tb_wr_data = data;
      tb_wr_mask = 8'hFF;  // Write all bytes
      
      @(posedge clk);
      tb_wr_en = 1'b0;
      
      @(posedge clk);  // Extra cycle for write to complete
      $display("  Wrote 0x%016h to SRAM addr %0d", data, addr);
    end
  endtask
  
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
        $display("  Expected: 0x%016h", expected_val);
        $display("  Got:      0x%016h", captured_val);
        
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
  
  // Timeout watchdog
  initial begin
    #100000;  // 100us timeout
    $display("\n*** ERROR: Simulation timeout! ***\n");
    $finish;
  end

endmodule
