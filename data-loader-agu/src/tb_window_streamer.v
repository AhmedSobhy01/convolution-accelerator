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
  reg         resp_ready;
  
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
    .resp_ready(resp_ready)
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Test variables
  reg [63:0] expected_result;
  integer test_num;
  integer pass_count;
  integer fail_count;
  
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
  
  // Test stimulus
  initial begin
    $dumpfile("unaligned_mem.vcd");
    $dumpvars(0, tb_unaligned_memory_reader);
    
    // Initialize signals
    rst_n = 0;
    req_valid = 0;
    byte_addr = 0;
    len_bytes = 0;
    resp_ready = 1;
    test_num = 0;
    pass_count = 0;
    fail_count = 0;
    
    // Reset
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);
    
    // Wait for SRAM initialization
    repeat(30) @(posedge clk);
    
    $display("\n========================================");
    $display("=== Starting Unaligned Memory Tests ===");
    $display("========================================\n");
    
    // Test 1: byte_addr=0, len_bytes=5
    test_num = 1;
    expected_result = 64'h0000000504030201;
    $display("Test %0d: byte_addr=0, len_bytes=5", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd0, 3'd5);
    wait_response();
    check_result(expected_result);
    
    // Test 2: byte_addr=5, len_bytes=5
    test_num = 2;
    expected_result = 64'h0000000A09080706;
    $display("\nTest %0d: byte_addr=5, len_bytes=5", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd5, 3'd5);
    wait_response();
    check_result(expected_result);
    
    // Test 3: byte_addr=10, len_bytes=5
    test_num = 3;
    expected_result = 64'h0000000F0E0D0C0B;
    $display("\nTest %0d: byte_addr=10, len_bytes=5", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd10, 3'd5);
    wait_response();
    check_result(expected_result);
    
    // Test 4: byte_addr=15, len_bytes=5
    test_num = 4;
    expected_result = 64'h0000001413121110;
    $display("\nTest %0d: byte_addr=15, len_bytes=5", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd15, 3'd5);
    wait_response();
    check_result(expected_result);
    
    // Test 5: byte_addr=20, len_bytes=5
    test_num = 5;
    expected_result = 64'h0000001918171615;
    $display("\nTest %0d: byte_addr=20, len_bytes=5", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd20, 3'd5);
    wait_response();
    check_result(expected_result);
    
    $display("\n========================================");
    $display("=== Additional Edge Case Tests ===");
    $display("========================================\n");
    
    // Test 6: Aligned 8-byte read at byte_addr=0
    test_num = 6;
    expected_result = 64'h0807060504030201;
    $display("Test %0d: Aligned 8-byte read at byte_addr=0", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd0, 3'd0);  // 0 means 8 bytes
    wait_response();
    check_result(expected_result);
    
    // Test 7: Single byte read at byte_addr=7
    test_num = 7;
    expected_result = 64'h0000000000000008;
    $display("\nTest %0d: Single byte read at byte_addr=7", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd7, 3'd1);
    wait_response();
    check_result(expected_result);
    
    // Test 8: Read crossing word boundary at byte_addr=6
    test_num = 8;
    expected_result = 64'h0B0A090807;
    $display("\nTest %0d: 5-byte read at byte_addr=6", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd6, 3'd5);
    wait_response();
    check_result(expected_result);
    
    // Test 9: Aligned read at word 1
    test_num = 9;
    expected_result = 64'h100F0E0D0C0B0A09;
    $display("\nTest %0d: Aligned 8-byte read at byte_addr=8", test_num);
    $display("  Expected: 0x%016X", expected_result);
    send_request(10'd8, 3'd0);
    wait_response();
    check_result(expected_result);
    
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
  
  // Task to send a read request
  task send_request(input [9:0] addr, input [2:0] len);
    begin
      @(posedge clk);
      byte_addr = addr;
      len_bytes = len;
      req_valid = 1;
      
      // Wait for ready
      wait(req_ready);
      @(posedge clk);
      req_valid = 0;
    end
  endtask
  
  // Task to wait for response
  task wait_response();
    begin
      wait(resp_valid);
      @(posedge clk);  // Sample the data
    end
  endtask
  
  // Task to check result
  task check_result(input [63:0] expected);
    begin
      $display("  Got:      0x%016X at time=%0t", resp_data, $time);
      if (resp_data === expected) begin
        $display("  Result:   PASS nice");
        pass_count = pass_count + 1;
      end else begin
        $display("  Result:   FAIL NOOOO");
        $display("  ERROR: Mismatch!");
        fail_count = fail_count + 1;
      end
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