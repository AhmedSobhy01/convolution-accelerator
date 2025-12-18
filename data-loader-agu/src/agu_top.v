`timescale 1ns/1ps

module agu_top #(
  parameter ADDR_W = 10,
  parameter DATA_W = 32
)(
  input  wire         clk,
  input  wire         rst_n,

  // ===========================================================================
  // Interface to Control Unit (CU)
  // ===========================================================================
  input  wire [2:0]   cmd,
  input  wire         cmd_start, 
  output reg          cmd_done,  

  // Configurations
  input  wire [6:0]   cfg_N,         // Image Size
  input  wire [4:0]   cfg_K,         // Kernel Size
  input  wire [1:0]   cfg_ker_idx,   // 0..3 (Quadrant index)
  input  wire [6:0]   cfg_col_idx,   // Which column to compute
  input  wire         cfg_split_mode,// 1 if K > 8
  
  input  wire         cfg_wb_start_pass, 
  
  // ===========================================================================
  // Interface to DRAM (External)
  // ===========================================================================
  input  wire [31:0]  dram_rx_data,
  input  wire         dram_rx_valid,
  output wire         dram_rx_ready,
  
  output wire         dram_tx_valid,
  output wire [31:0]  dram_tx_data,
  input  wire         dram_tx_ready,

  // ===========================================================================
  // Interface to Systolic Array (SA)
  // ===========================================================================
  output reg  [63:0]  sa_weight_data,
  output reg          sa_weight_valid,
  output reg  [63:0]  sa_pixel_data,
  output reg          sa_pixel_valid,
  input  wire [63:0]  sa_out_data,
  input  wire         sa_out_valid
);

  // ===========================================================================
  // Internal Signals & Constants
  // ===========================================================================
  localparam CMD_IDLE            = 3'd0;
  localparam CMD_LOAD_DATA       = 3'd1;
  localparam CMD_LOAD_KERNEL_IDX = 3'd2;
  localparam CMD_LOAD_COL        = 3'd3;
  localparam CMD_DRAIN           = 3'd4;
  
  localparam SRAM0_KER_BASE = 16'd4096;

  reg [2:0] state;

  // Counters for Streaming
  reg [6:0] row_cnt;
  
  // Byte Window Streamer Signals
  reg         ws_req_valid;
  reg [15:0]  ws_req_base;
  reg [3:0]   ws_req_len;
  wire        ws_req_ready;
  wire        ws_out_valid;
  wire [63:0] ws_out_data;
  reg         ws_out_ready;

  // SRAM Signals
  wire        ldr_p0_en, ldr_p0_we;
  wire [ADDR_W-1:0] ldr_p0_addr;
  wire [63:0] ldr_p0_wdata;
  wire [7:0]  ldr_p0_wmask;
  
  wire        st_p0_en, st_p0_we, st_p1_en;
  wire [ADDR_W-1:0] st_p0_addr, st_p1_addr;
  wire [63:0] st_p0_wdata;
  wire [7:0]  st_p0_wmask;
  
  wire        sram0_p0_en, sram0_p0_we, sram0_p1_en;
  wire [ADDR_W-1:0] sram0_p0_addr, sram0_p1_addr;
  wire [63:0] sram0_p0_wdata, sram0_p0_rdata, sram0_p1_rdata;
  wire [7:0]  sram0_p0_wmask;

  wire        wb_en, wb_we;
  wire [11:0] wb_addr;
  wire [31:0] wb_wdata;
  wire [3:0]  wb_wmask;
  
  wire        drain_en;
  wire [11:0] drain_addr;
  wire [31:0] drain_rdata;

  wire loader_done;
  wire drain_done;
  reg  mode_stream; 

  // ===========================================================================
  // 1. Calculations (Fixed based on user feedback)
  // ===========================================================================
  wire [15:0] N16 = {9'd0, cfg_N};
  wire [15:0] K16 = {11'd0, cfg_K};
  wire [15:0] half_K = K16 >> 1; // K/2

  // Offsets: Use Half K, not hardcoded 8
  wire [15:0] k_x_off = (cfg_ker_idx[0]) ? half_K : 16'd0;
  wire [15:0] k_y_off = (cfg_ker_idx[1]) ? half_K : 16'd0;
  
  // Active dimensions: How many rows/cols are we actually processing in this pass?
  // If Split: K/2. If Normal: K.
  reg [6:0] active_k_dim;
  always @(*) begin
    if (cfg_split_mode) 
      active_k_dim = half_K[6:0];
    else 
      active_k_dim = cfg_K[6:0];
  end

  // Column Streaming limits
  reg [15:0] col_start_row;
  reg [15:0] col_end_row;

  always @(*) begin
    if (cfg_split_mode) begin
       // Bottom sub-kernels start at offset K/2
       if (cfg_ker_idx >= 2) begin 
         col_start_row = half_K;
         col_end_row   = N16; 
       end else begin
         // Top sub-kernels end at N - K/2
         col_start_row = 16'd0;
         col_end_row   = N16 - half_K; 
       end
    end else begin
       col_start_row = 16'd0;
       col_end_row   = N16;
    end
  end

  // ===========================================================================
  // 2. Sub-Module Instantiations
  // ===========================================================================

  dl_dma_rx #( .ADDR_W(ADDR_W), .KER_BASE_BYTE(SRAM0_KER_BASE) ) u_loader (
    .clk(clk), .rst_n(rst_n),
    .start(cmd == CMD_LOAD_DATA && cmd_start),
    .cfg_N(cfg_N), .cfg_K(cfg_K),
    .done(loader_done),
    .rx_data(dram_rx_data), .rx_valid(dram_rx_valid), .rx_ready(dram_rx_ready),
    .sram0_en(ldr_p0_en), .sram0_we(ldr_p0_we), .sram0_addr(ldr_p0_addr),
    .sram0_wdata(ldr_p0_wdata), .sram0_wmask(ldr_p0_wmask),
    .sram1_en(), .sram1_we(), .sram1_addr(), .sram1_wdata(), .sram1_wmask()
  );

  byte_window_streamer #( .ADDR_W(ADDR_W) ) u_streamer (
    .clk(clk), .rst_n(rst_n),
    .req_valid(ws_req_valid), .req_ready(ws_req_ready),
    .req_base_byte(ws_req_base), .req_len(ws_req_len),
    .sram_p0_en(st_p0_en), .sram_p0_we(st_p0_we), .sram_p0_addr(st_p0_addr),
    .sram_p0_wdata(st_p0_wdata), .sram_p0_wmask(st_p0_wmask), .sram_p0_rdata(sram0_p0_rdata),
    .sram_p1_en(st_p1_en), .sram_p1_addr(st_p1_addr), .sram_p1_rdata(sram0_p1_rdata),
    .out_valid(ws_out_valid), .out_ready(ws_out_ready), .out_data(ws_out_data)
  );

  sram0_mux_load_tb_or_stream #( .ADDR_W(ADDR_W) ) u_sram0_mux (
    .mode_stream(mode_stream),
    .l_p0_en(ldr_p0_en), .l_p0_we(ldr_p0_we), .l_p0_addr(ldr_p0_addr),
    .l_p0_wdata(ldr_p0_wdata), .l_p0_wmask(ldr_p0_wmask),
    .tb_p1_en(1'b0), .tb_p1_addr({ADDR_W{1'b0}}),
    .s_p0_en(st_p0_en), .s_p0_we(st_p0_we), .s_p0_addr(st_p0_addr),
    .s_p0_wdata(st_p0_wdata), .s_p0_wmask(st_p0_wmask),
    .s_p1_en(st_p1_en), .s_p1_addr(st_p1_addr),
    .m_p0_en(sram0_p0_en), .m_p0_we(sram0_p0_we), .m_p0_addr(sram0_p0_addr),
    .m_p0_wdata(sram0_p0_wdata), .m_p0_wmask(sram0_p0_wmask),
    .m_p1_en(sram0_p1_en), .m_p1_addr(sram0_p1_addr)
  );

  sram0_1rw1r_64x1024_wrapper u_sram0 (
    .clk(clk),
    .p0_en(sram0_p0_en), .p0_we(sram0_p0_we), .p0_addr(sram0_p0_addr),
    .p0_wdata(sram0_p0_wdata), .p0_wmask(sram0_p0_wmask), .p0_rdata(sram0_p0_rdata),
    .p1_en(sram0_p1_en), .p1_addr(sram0_p1_addr), .p1_rdata(sram0_p1_rdata)
  );

  wire wb_busy;
  dl_sa_writeback u_writeback (
    .clk(clk), .rst_n(rst_n),
    .cfg_start_pass(cfg_wb_start_pass),
    .cfg_ker_idx(cfg_ker_idx),
    .sa_valid(sa_out_valid), .sa_wdata(sa_out_data),
    .busy(wb_busy),
    .sram_en(wb_en), .sram_we(wb_we), .sram_addr(wb_addr),
    .sram_wdata(wb_wdata), .sram_wmask(wb_wmask)
  );

  dl_drain_stream #( .ADDR_W(12) ) u_drain (
    .clk(clk), .rst_n(rst_n),
    .start(cmd == CMD_DRAIN && cmd_start),
    .cfg_num_pixels({5'd0, cfg_N} * {5'd0, cfg_N}), 
    .cfg_split_mode(cfg_split_mode),
    .done(drain_done),
    .sram_en(drain_en), .sram_addr(drain_addr), .sram_rdata(drain_rdata),
    .tx_valid(dram_tx_valid), .tx_data(dram_tx_data), .tx_ready(dram_tx_ready)
  );

  sram1_1rw1r_32x4096_wrapper u_sram1 (
    .clk(clk),
    .p0_en(wb_en), .p0_we(wb_we), .p0_addr(wb_addr),
    .p0_wdata(wb_wdata), .p0_wmask(wb_wmask), .p0_rdata(), 
    .p1_en(drain_en), .p1_addr(drain_addr), .p1_rdata(drain_rdata) 
  );

  // ===========================================================================
  // 3. FSM
  // ===========================================================================
  
  localparam ST_IDLE       = 3'd0;
  localparam ST_LOAD_WAIT  = 3'd1;
  localparam ST_KER_STREAM = 3'd2;
  localparam ST_COL_STREAM = 3'd3;
  localparam ST_DRAIN_WAIT = 3'd4;
  localparam ST_DONE       = 3'd5;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= ST_IDLE;
      cmd_done        <= 1'b0;
      mode_stream     <= 1'b0; 
      ws_req_valid    <= 1'b0;
      ws_req_base     <= 16'd0;
      ws_req_len      <= 4'd0;
      ws_out_ready    <= 1'b0;
      row_cnt         <= 7'd0;
      
      sa_weight_data  <= 64'd0;
      sa_weight_valid <= 1'b0;
      sa_pixel_data   <= 64'd0;
      sa_pixel_valid  <= 1'b0;
    end else begin
      // Defaults
      cmd_done        <= 1'b0;
      ws_req_valid    <= 1'b0;
      sa_weight_valid <= 1'b0;
      sa_pixel_valid  <= 1'b0;
      
      case (state)
        ST_IDLE: begin
          if (cmd_start) begin
            case (cmd)
              CMD_LOAD_DATA: begin
                mode_stream <= 1'b0; 
                state       <= ST_LOAD_WAIT;
              end
              CMD_LOAD_KERNEL_IDX: begin
                mode_stream <= 1'b1; 
                row_cnt     <= 7'd0; 
                state       <= ST_KER_STREAM;
              end
              CMD_LOAD_COL: begin
                mode_stream <= 1'b1; 
                row_cnt     <= col_start_row[6:0]; 
                state       <= ST_COL_STREAM;
              end
              CMD_DRAIN: begin
                mode_stream <= 1'b1;
                state       <= ST_DRAIN_WAIT;
              end
              default: state <= ST_IDLE;
            endcase
          end
        end

        ST_LOAD_WAIT: begin
          if (loader_done) begin
            cmd_done <= 1'b1;
            state    <= ST_DONE;
          end
        end

        // ---------------------------------------------------------------------
        // KERNEL STREAMING (Corrected)
        // ---------------------------------------------------------------------
        ST_KER_STREAM: begin
          // Only iterate up to the active sub-kernel dimension (K or K/2)
          if (row_cnt < active_k_dim) begin
            // 1. Send Request
            if (!ws_req_valid && !ws_out_ready) begin
              ws_req_valid <= 1'b1;
              ws_req_len   <= active_k_dim[3:0]; // Fetch exact width needed
              
              // Address Calculation: Base + (Y_offset + local_row)*K + X_offset
              if (cfg_split_mode) begin
                ws_req_base <= SRAM0_KER_BASE + ((k_y_off + {9'd0, row_cnt}) * K16) + k_x_off;
              end else begin
                 ws_req_base <= SRAM0_KER_BASE + ({9'd0, row_cnt} * K16);
              end
              
              ws_out_ready <= 1'b1; 
            end
            
            // 2. Receive Data
            if (ws_out_ready && ws_out_valid) begin
              sa_weight_data  <= ws_out_data;
              sa_weight_valid <= 1'b1;
              ws_out_ready    <= 1'b0; 
              row_cnt         <= row_cnt + 1'b1;
            end
          end else begin
            cmd_done <= 1'b1;
            state    <= ST_DONE;
          end
        end

        // ---------------------------------------------------------------------
        // COL STREAMING (Corrected)
        // ---------------------------------------------------------------------
        ST_COL_STREAM: begin
          if (row_cnt < col_end_row[6:0]) begin
            // 1. Send Request
            if (!ws_req_valid && !ws_out_ready) begin
              ws_req_valid <= 1'b1;
              // Fetch width of K (or K/2 in split mode? No, image window always width of kernel)
              // Actually for convolution input window, we need row width = Active K Width.
              ws_req_len   <= active_k_dim[3:0];
              
              // Address = Row * N + Col + (x_offset if needed? No, Col idx handles x)
              // Wait: If split mode, we are processing a sub-block.
              // If we are doing Right-Half Kernel, do we shift the image read?
              // No, convolution slides *across* the image. 
              // The "Col Index" from Control Unit determines where the window starts in Image.
              
              ws_req_base  <= ({9'd0, row_cnt} * N16) + {9'd0, cfg_col_idx};
              
              ws_out_ready <= 1'b1;
            end
            
            // 2. Receive Data
            if (ws_out_ready && ws_out_valid) begin
              sa_pixel_data  <= ws_out_data;
              sa_pixel_valid <= 1'b1;
              ws_out_ready   <= 1'b0;
              row_cnt        <= row_cnt + 1'b1;
            end
          end else begin
            cmd_done <= 1'b1;
            state    <= ST_DONE;
          end
        end

        ST_DRAIN_WAIT: begin
          if (drain_done) begin
            cmd_done <= 1'b1;
            state    <= ST_DONE;
          end
        end

        ST_DONE: begin
          if (!cmd_start) begin
            state <= ST_IDLE;
          end
        end

      endcase
    end
  end

endmodule