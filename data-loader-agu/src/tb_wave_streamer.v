`timescale 1ns/1ps
`define USE_POWER_PINS

module tb_wave_streamer;

  reg clk;
  reg rst_n;
  
  // Power pins
  supply1 vccd1;
  supply0 vssd1;

  // Configuration
  reg [6:0] cfg_N;
  reg [4:0] cfg_K;
  
  // Controls
  reg start_load_kernel;
  reg [1:0] kernel_idx;
  reg start_stream_window;
  reg [15:0] window_col;
  
  // Outputs from DUT
  wire kernel_done;
  wire window_done;
  wire w_valid;
  wire [63:0] w_data;
  wire p_valid;
  wire [63:0] p_data;
  
  // ===================================
  // Component Connections
  // ===================================
  
  // Streamer <-> Reader Interface
  wire         dut_req_valid;
  wire [12:0]  dut_req_addr;
  wire [2:0]   dut_req_len;
  wire         dut_req_ready;
  wire         dut_resp_valid;
  wire [63:0]  dut_resp_data;

  // Reader <-> SRAM Interface
  wire         reader_sram_p0_en;
  wire [9:0]   reader_sram_p0_addr;
  wire [63:0]  reader_sram_p0_rdata;
  wire         reader_sram_p1_en;
  wire [9:0]   reader_sram_p1_addr;
  wire [63:0]  reader_sram_p1_rdata;

  // TB <-> SRAM Interface (For Writing Test Data)
  // We MUX Port 0: TB writes when `tb_we` is high. Reader reads when `tb_we` is low.
  reg          tb_we_active;
  reg [9:0]    tb_sram_addr;
  reg [63:0]   tb_sram_wdata;
  
  // Mux signals for SRAM Port 0
  wire         sram_p0_en    = tb_we_active ? 1'b1 : reader_sram_p0_en;
  wire         sram_p0_we    = tb_we_active ? 1'b1 : 1'b0; // Reader only reads
  wire [9:0]   sram_p0_addr  = tb_we_active ? tb_sram_addr : reader_sram_p0_addr;
  wire [63:0]  sram_p0_wdata = tb_sram_wdata;
  wire [7:0]   sram_p0_wmask = 8'hFF; // Write all bytes during TB load
  wire [63:0]  sram_p0_rdata; // Output from SRAM

  // ===================================
  // Instantiations
  // ===================================

  // 1. SRAM Wrapper
  sram0_1rw1r_64x1024_wrapper u_sram (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    // Port 0 (Muxed TB Write / Reader Read)
    .p0_en(sram_p0_en),
    .p0_we(sram_p0_we),
    .p0_addr(sram_p0_addr),
    .p0_wdata(sram_p0_wdata),
    .p0_wmask(sram_p0_wmask),
    .p0_rdata(sram_p0_rdata),
    
    // Port 1 (Reader Read Only)
    .p1_en(reader_sram_p1_en),
    .p1_addr(reader_sram_p1_addr),
    .p1_rdata(reader_sram_p1_rdata)
  );
  
  // Connect SRAM Read Data back to Reader
  assign reader_sram_p0_rdata = sram_p0_rdata;

  // 2. Unaligned Memory Reader
  unaligned_memory_reader #(
    .ADDR_W(13)
  ) u_reader (
    .clk(clk),
    .rst_n(rst_n),
    .req_valid(dut_req_valid),
    .byte_addr(dut_req_addr),
    .len_bytes(dut_req_len),
    .req_ready(dut_req_ready),
    .resp_valid(dut_resp_valid),
    .resp_data(dut_resp_data),
    
    // SRAM connections
    .sram_p0_en(reader_sram_p0_en),
    .sram_p0_addr(reader_sram_p0_addr),
    .sram_p0_rdata(reader_sram_p0_rdata),
    .sram_p1_en(reader_sram_p1_en),
    .sram_p1_addr(reader_sram_p1_addr),
    .sram_p1_rdata(reader_sram_p1_rdata)
  );

  // 3. DUT: Kernel/Window Streamer
  kernel_and_window_streamer #(
    .BYTE_ADDR_W(13),
    .KER_BASE_BYTE(16'd4096),
    .IMG_BASE_BYTE(16'd0)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    .start_load_kernel(start_load_kernel),
    .kernel_idx(kernel_idx),
    .kernel_done(kernel_done),
    .start_stream_window(start_stream_window),
    .window_col(window_col),
    .window_done(window_done),
    .w_valid(w_valid),
    .w_data(w_data),
    .p_valid(p_valid),
    .p_data(p_data),
    
    // Connect to Reader
    .reader_req_valid(dut_req_valid),
    .reader_byte_addr(dut_req_addr),
    .reader_len_bytes(dut_req_len),
    .reader_req_ready(dut_req_ready),
    .reader_resp_valid(dut_resp_valid),
    .reader_resp_data(dut_resp_data)
  );

  // ===================================
  // Testbench Logic
  // ===================================
  
  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $dumpfile("tb_wave_streamer.vcd");
    $dumpvars(0, tb_wave_streamer);
    
    // Init Signals
    rst_n = 0;
    cfg_N = 7'd16;  // 16x16 Image
    cfg_K = 5'd4;   // 4x4 Kernel
    start_load_kernel = 0;
    kernel_idx = 0;
    start_stream_window = 0;
    window_col = 0;
    tb_we_active = 0;
    tb_sram_addr = 0;
    tb_sram_wdata = 0;
    
    // Reset
    #20 rst_n = 1;
    #10;
    
    // 1. Initialize SRAM (Rows 0..15)
    $display("Initializing SRAM (Rows 0..15, 16 bytes wide)...");
    write_sram_data();
    
    #20;
    
    // 2. Start Streaming
    $display("Starting Wavefront Stream Test (16x16, K=4)...");
    start_stream_window = 1;
    #10 start_stream_window = 0;
    
    // Monitor Outputs
    monitor_outputs_loop();
    
    #100;
    $display("Test Finished Successfully");
    $finish;
  end
  
  // Task: Fill SRAM
  task write_sram_data;
    integer r, w;
    reg [63:0] val;
    integer byte_idx;
    begin
      tb_we_active = 1;
      $display("--- SRAM Content Initialization ---");
      // Image: 16 Rows. Width: 16 Bytes.
      // 16 Bytes = 2 x 64-bit Words.
      // Stride = 2 Words.
      
      for (r = 0; r < 16; r = r + 1) begin
         // We need to write 2 words for each row: w=0 (Bytes 0-7), w=1 (Bytes 8-15)
         for (w = 0; w < 2; w = w + 1) begin
             tb_sram_addr = (r * 2) + w;
             
             // Construct 64-bit word from 8 bytes
             // Val = (Row << 4) | Col
             // Word 0: Cols 0..7. Word 1: Cols 8..15.
             val = 64'd0;
             for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
                 // Col index = w*8 + byte_idx
                 // Value = (r * 16) + (w * 8 + byte_idx)
                 val[byte_idx*8 +: 8] = (r * 16) + (w * 8 + byte_idx);
             end
             
             tb_sram_wdata = val;
             
             if (r < 4) begin
                $display("Row %0d Word %0d (Addr %0d): %h", r, w, tb_sram_addr, val);
             end
             @(posedge clk);
         end
      end
      tb_sram_addr = 0;
      tb_we_active = 0; // Release control to Reader
      $display("... (Loaded 16 rows)");
      $display("-----------------------------------");
    end
  endtask

  // Monitor All Activity
  task monitor_outputs_loop;
    integer cyc;
    reg stop_test;
    begin
      $display("\n==========================================================================");
      $display("                            CYCLE LOG                                     ");
      $display("==========================================================================");
      $display("Cycle | Action   | Details");
      $display("------+----------+--------------------------------------------------------");
      
      cyc = 0;
      stop_test = 0;
      
      while (!stop_test) begin
         #1; 
         
         // 1. Monitor Request
         if (dut_req_valid) begin
             $display("%5d | REQ      | Addr=%d (Row %0d Part %0d), Len=%d", 
                cyc, dut_req_addr, dut_req_addr/16, (dut_req_addr%16)/8, dut_req_len);
         end
         
         // 2. Monitor Response
         if (dut_resp_valid) begin
             $display("%5d | RESP     | Data=%h (Row Val ~ %0d)", 
                cyc, dut_resp_data, dut_resp_data[7:0]);
         end
         
         // 3. Monitor Stream Output (Only 4 Lanes relevant for K=4)
         if (p_valid) begin
             $display("%5d | STREAM   | L0:%02h L1:%02h L2:%02h L3:%02h", 
                cyc, 
                p_data[7:0], p_data[15:8], p_data[23:16], p_data[31:24]);
         end
         
         if (window_done) begin
             $display("%5d | DONE     | Window Done Signal Asserted", cyc);
             stop_test = 1;
         end
         
         if (cyc > 100) stop_test = 1;
         
         @(posedge clk);
         cyc = cyc + 1;
      end
    end
  endtask

endmodule
