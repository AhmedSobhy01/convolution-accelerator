`timescale 1ns/1ps
`define USE_POWER_PINS

module conv_accelerator_top #(
  parameter ADDR_W = 10,              // SRAM word address width (1024 words)
  parameter BYTE_ADDR_W = 13,         // Byte address width (8KB)
  parameter KER_BASE_BYTE = 16'd4096,
  parameter IMG_BASE_BYTE = 16'd0
)(
  input  wire         clk,
  input  wire         rst_n,

  // Configuration
  input  wire [6:0]   cfg_N,          // image size
  input  wire [4:0]   cfg_K,          // kernel size

  // Control interface
  input  wire         start_load,     // start DMA load of image+kernel
  output wire         load_done,      // DMA load complete
  
  input  wire         start_kernel_load,   // start streaming kernel to SA
  output wire         kernel_done,         // kernel load complete
  
  input  wire         start_window,   // start streaming image window
  input  wire [15:0]  window_col,     // starting column for window
  output wire         window_done,    // window streaming complete

  // DMA input stream (32-bit)
  input  wire [31:0]  rx_data,
  input  wire         rx_valid,
  output wire         rx_ready,

  // Systolic Array outputs
  output wire         w_valid,        // kernel/weight data valid
  output wire [63:0]  w_data,         // kernel column vector
  output wire         p_valid,        // pixel data valid
  output wire [63:0]  p_data          // pixel row vector
);

  // ============================================
  // SRAM signals
  // ============================================
  wire         sram_p0_en;
  wire         sram_p0_we;
  wire [ADDR_W-1:0] sram_p0_addr;
  wire [63:0]  sram_p0_wdata;
  wire [7:0]   sram_p0_wmask;
  wire [63:0]  sram_p0_rdata;

  wire         sram_p1_en;
  wire [ADDR_W-1:0] sram_p1_addr;
  wire [63:0]  sram_p1_rdata;

  // ============================================
  // DMA Loader (writes to SRAM during load phase)
  // ============================================
  wire         dma_sram_en;
  wire         dma_sram_we;
  wire [ADDR_W-1:0] dma_sram_addr;
  wire [63:0]  dma_sram_wdata;
  wire [7:0]   dma_sram_wmask;

  dl_dma_rx #(
    .ADDR_W(ADDR_W),
    .KER_BASE_BYTE(KER_BASE_BYTE)
  ) u_dma (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_load),
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    .done(load_done),
    
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    
    .sram0_en(dma_sram_en),
    .sram0_we(dma_sram_we),
    .sram0_addr(dma_sram_addr),
    .sram0_wdata(dma_sram_wdata),
    .sram0_wmask(dma_sram_wmask)
  );

  // ============================================
  // Unaligned Memory Reader (byte-addressable)
  // ============================================
  wire         reader_req_valid;
  wire [BYTE_ADDR_W-1:0] reader_byte_addr;
  wire [2:0]   reader_len_bytes;
  wire         reader_req_ready;
  wire         reader_resp_valid;
  wire [63:0]  reader_resp_data;

  wire         reader_p0_en;
  wire [ADDR_W-1:0] reader_p0_addr;
  wire         reader_p1_en;
  wire [ADDR_W-1:0] reader_p1_addr;

  unaligned_memory_reader #(
    .ADDR_W(BYTE_ADDR_W)
  ) u_reader (
    .clk(clk),
    .rst_n(rst_n),
    
    .req_valid(reader_req_valid),
    .byte_addr(reader_byte_addr),
    .len_bytes(reader_len_bytes),
    .req_ready(reader_req_ready),
    
    .resp_valid(reader_resp_valid),
    .resp_data(reader_resp_data),
    
    .sram_p0_en(reader_p0_en),
    .sram_p0_addr(reader_p0_addr),
    .sram_p0_rdata(sram_p0_rdata),
    
    .sram_p1_en(reader_p1_en),
    .sram_p1_addr(reader_p1_addr),
    .sram_p1_rdata(sram_p1_rdata)
  );

  // ============================================
  // Kernel and Window Streamer Orchestrator
  // ============================================
  kernel_and_window_streamer #(
    .BYTE_ADDR_W(BYTE_ADDR_W),
    .KER_BASE_BYTE(KER_BASE_BYTE),
    .IMG_BASE_BYTE(IMG_BASE_BYTE)
  ) u_streamer (
    .clk(clk),
    .rst_n(rst_n),
    
    .cfg_N(cfg_N),
    .cfg_K(cfg_K),
    
    .start_load_kernel(start_kernel_load),
    .kernel_done(kernel_done),
    
    .start_stream_window(start_window),
    .window_col(window_col),
    .window_done(window_done),
    
    .w_valid(w_valid),
    .w_data(w_data),
    .p_valid(p_valid),
    .p_data(p_data),
    
    // Connect to reader
    .reader_req_valid(reader_req_valid),
    .reader_byte_addr(reader_byte_addr),
    .reader_len_bytes(reader_len_bytes),
    .reader_req_ready(reader_req_ready),
    .reader_resp_valid(reader_resp_valid),
    .reader_resp_data(reader_resp_data)
  );

  // ============================================
  // SRAM Port Arbitration
  // Port0 (RW): DMA during load, Reader during compute
  // Port1 (R):  Always Reader
  // ============================================
  
  // Simple arbitration: if DMA is active (we=1), give it port0
  // Otherwise reader owns port0
  wire dma_active = dma_sram_we;

  assign sram_p0_en    = dma_active ? dma_sram_en    : reader_p0_en;
  assign sram_p0_we    = dma_active ? dma_sram_we    : 1'b0;
  assign sram_p0_addr  = dma_active ? dma_sram_addr  : reader_p0_addr;
  assign sram_p0_wdata = dma_active ? dma_sram_wdata : 64'd0;
  assign sram_p0_wmask = dma_active ? dma_sram_wmask : 8'h00;

  assign sram_p1_en    = reader_p1_en;
  assign sram_p1_addr  = reader_p1_addr;

  // ============================================
  // SRAM Instance
  // ============================================

	`ifdef USE_POWER_PINS
		supply1 vccd1;
		supply0 vssd1;
	`endif

  sram0_1rw1r_64x1024_wrapper u_sram (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    
    .p0_en(sram_p0_en),
    .p0_we(sram_p0_we),
    .p0_addr(sram_p0_addr),
    .p0_wdata(sram_p0_wdata),
    .p0_wmask(sram_p0_wmask),
    .p0_rdata(sram_p0_rdata),
    
    .p1_en(sram_p1_en),
    .p1_addr(sram_p1_addr),
    .p1_rdata(sram_p1_rdata)
  );

endmodule
