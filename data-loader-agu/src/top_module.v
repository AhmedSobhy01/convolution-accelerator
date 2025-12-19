`timescale 1ns/1ps
`define USE_POWER_PINS

module conv_accelerator_top #(
  parameter ADDR_W = 10,              // SRAM0 word address width (1024 words)
  parameter BYTE_ADDR_W = 13,         // Byte address width (8KB)
  parameter KER_BASE_BYTE = 16'd4096,
  parameter IMG_BASE_BYTE = 16'd0,
  parameter SRAM1_ADDR_W  = 12        // SRAM1 word address width (4096 words)
)(
  input  wire         clk,
  input  wire         rst_n,

  // Configuration
  input  wire [6:0]   cfg_N,          // image size
  input  wire [4:0]   cfg_K,          // kernel size
  input  wire         cfg_start_pass, // Reset Writeback pointers for new pass
  input  wire [1:0]   cfg_ker_idx,    // Quadrant index for writeback
  input  wire         cfg_split_mode, // 0=Single, 1=Split mode for drain

  // Control interface
  input  wire         start_load,     // start DMA load of image+kernel
  output wire         load_done,      // DMA load complete
  
  input  wire         start_kernel_load,   // start streaming kernel to SA
  input  wire [1:0]   kernel_idx,         // kernel quadrant index
  output wire         kernel_done,         // kernel load complete
  
  input  wire         start_window,   // start streaming image window
  input  wire [15:0]  window_col,     // starting column for window
  output wire         window_done,    // window streaming complete

  input  wire         start_drain,    // Start draining SRAM1 to DRAM
  output wire         drain_done,     // Drain complete

  // DRAM input stream (32-bit) -> SRAM0
  input  wire [31:0]  rx_data,
  input  wire         rx_valid,
  output wire         rx_ready,
  
  // DRAM output stream (32-bit) <- SRAM1
  output wire         tx_valid,
  output wire [31:0]  tx_data,
  input  wire         tx_ready,

  // Systolic Array Interface
  // Outputs TO SA
  output wire         w_valid,        // kernel/weight data valid
  output wire [63:0]  w_data,         // kernel column vector
  output wire         p_valid,        // pixel data valid
  output wire [63:0]  p_data,         // pixel row vector
  
  // Inputs FROM SA (Results)
  input  wire         sa_out_valid,
  input  wire [7:0]   sa_out_data,
  output wire         sa_wb_busy      // Writeback buffer full
);

  // ============================================
  // Power Pins
  // ============================================
  `ifdef USE_POWER_PINS
    supply1 vccd1;
    supply0 vssd1;
  `endif

  // ============================================
  // SRAM0 Signals (Input Buffer)
  // ============================================
  wire         sram0_p0_en;
  wire         sram0_p0_we;
  wire [ADDR_W-1:0] sram0_p0_addr;
  wire [63:0]  sram0_p0_wdata;
  wire [7:0]   sram0_p0_wmask;
  wire [63:0]  sram0_p0_rdata;

  wire         sram0_p1_en;
  wire [ADDR_W-1:0] sram0_p1_addr;
  wire [63:0]  sram0_p1_rdata;

  // ============================================
  // SRAM1 Signals (Output Buffer)
  // ============================================
  wire         sram1_p0_en;
  wire         sram1_p0_we;
  wire [SRAM1_ADDR_W-1:0] sram1_p0_addr;
  wire [31:0]  sram1_p0_wdata;
  wire [3:0]   sram1_p0_wmask;
  wire [31:0]  sram1_p0_rdata; // Unused, port 0 is write-only here

  wire         sram1_p1_en;
  wire [SRAM1_ADDR_W-1:0] sram1_p1_addr;
  wire [31:0]  sram1_p1_rdata;

  // ============================================
  // DMA Loader (writes to SRAM0)
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
  // Unaligned Memory Reader (Reads SRAM0)
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
    .sram_p0_rdata(sram0_p0_rdata),
    .sram_p1_en(reader_p1_en),
    .sram_p1_addr(reader_p1_addr),
    .sram_p1_rdata(sram0_p1_rdata)
  );

  // ============================================
  // Streamer Orchestrator
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
    .kernel_idx(kernel_idx),
    .kernel_done(kernel_done),
    .start_stream_window(start_window),
    .window_col(window_col),
    .window_done(window_done),
    .w_valid(w_valid),
    .w_data(w_data),
    .p_valid(p_valid),
    .p_data(p_data),
    .reader_req_valid(reader_req_valid),
    .reader_byte_addr(reader_byte_addr),
    .reader_len_bytes(reader_len_bytes),
    .reader_req_ready(reader_req_ready),
    .reader_resp_valid(reader_resp_valid),
    .reader_resp_data(reader_resp_data)
  );

  // ============================================
  // Writeback (SA -> SRAM1)
  // ============================================
  dl_sa_writeback #(
    .ADDR_W(SRAM1_ADDR_W)
  ) u_writeback (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_start_pass(cfg_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .sa_valid(sa_out_valid),
    .sa_wdata(sa_out_data),
    .busy(sa_wb_busy),
    .sram_en(sram1_p0_en),
    .sram_we(sram1_p0_we),
    .sram_addr(sram1_p0_addr),
    .sram_wdata(sram1_p0_wdata),
    .sram_wmask(sram1_p0_wmask)
  );

  // ============================================
  // Drain (SRAM1 -> DRAM)
  // ============================================
  // Calculate total pixels: N * N
  wire [13:0] total_pixels = {7'd0, cfg_N} * {7'd0, cfg_N};

  dl_drain_stream #(
    .ADDR_W(SRAM1_ADDR_W)
  ) u_drain (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_drain),
    .cfg_num_pixels(total_pixels[SRAM1_ADDR_W-1:0]),
    .cfg_split_mode(cfg_split_mode),
    .done(drain_done),
    .sram_en(sram1_p1_en),
    .sram_addr(sram1_p1_addr),
    .sram_rdata(sram1_p1_rdata),
    .tx_valid(tx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready)
  );

  // ============================================
  // SRAM0 Arbitration
  // ============================================
  wire dma_active = dma_sram_we;

  assign sram0_p0_en    = dma_active ? dma_sram_en    : reader_p0_en;
  assign sram0_p0_we    = dma_active ? dma_sram_we    : 1'b0;
  assign sram0_p0_addr  = dma_active ? dma_sram_addr  : reader_p0_addr;
  assign sram0_p0_wdata = dma_active ? dma_sram_wdata : 64'd0;
  assign sram0_p0_wmask = dma_active ? dma_sram_wmask : 8'h00;

  assign sram0_p1_en    = reader_p1_en;
  assign sram0_p1_addr  = reader_p1_addr;

  // ============================================
  // SRAM Instantiations
  // ============================================

  // Input SRAM (64-bit wide)
  sram0_1rw1r_64x1024_wrapper u_sram0 (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    .p0_en(sram0_p0_en),
    .p0_we(sram0_p0_we),
    .p0_addr(sram0_p0_addr),
    .p0_wdata(sram0_p0_wdata),
    .p0_wmask(sram0_p0_wmask),
    .p0_rdata(sram0_p0_rdata),
    .p1_en(sram0_p1_en),
    .p1_addr(sram0_p1_addr),
    .p1_rdata(sram0_p1_rdata)
  );

  // Output SRAM (32-bit wide)
  // Port 0: Writeback (Write Only used)
  // Port 1: Drain (Read Only used)
  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    .p0_en(sram1_p0_en),
    .p0_we(sram1_p0_we),
    .p0_addr(sram1_p0_addr),
    .p0_wdata(sram1_p0_wdata),
    .p0_wmask(sram1_p0_wmask),
    .p0_rdata(sram1_p0_rdata),
    .p1_en(sram1_p1_en),
    .p1_addr(sram1_p1_addr),
    .p1_rdata(sram1_p1_rdata)
  );

endmodule