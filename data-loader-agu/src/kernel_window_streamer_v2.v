`timescale 1ns/1ps

module kernel_and_window_streamer #(
  parameter BYTE_ADDR_W = 13,
  parameter KER_BASE_BYTE = 16'd4096,
  parameter IMG_BASE_BYTE = 16'd0
)(
  input  wire         clk,
  input  wire         rst_n,

  input  wire [6:0]   cfg_N,
  input  wire [4:0]   cfg_K,

  input  wire         start_load_kernel,
  input  wire [1:0]   kernel_idx,
  output reg          kernel_done,

  input  wire         start_stream_window,
  input  wire [15:0]  start_col,
  input  wire [15:0]  end_col,
  output reg          window_done,

  output reg          w_valid,
  output reg  [63:0]  w_data,
  output reg          p_valid,
  output reg  [63:0]  p_data,

  output reg                      reader_req_valid,
  output reg  [BYTE_ADDR_W-1:0]   reader_byte_addr,
  output reg  [2:0]               reader_len_bytes,
  input  wire                     reader_req_ready,
  input  wire                     reader_resp_valid,
  input  wire [63:0]              reader_resp_data
);

  wire [15:0] N16 = {9'd0, cfg_N};
  wire [15:0] K16 = {11'd0, cfg_K};
  wire [15:0] row_bytes = N16;
  wire [15:0] col_bytes = K16;

  // Kernel Geometry
  wire [15:0] k_lo  = K16 >> 1;
  wire [15:0] k_hi  = K16 - k_lo;
  wire        k_big = (cfg_K > 5'd8);

  wire ker_top = (kernel_idx == 2'd0) || (kernel_idx == 2'd1);
  wire ker_left  = (kernel_idx == 2'd0) || (kernel_idx == 2'd2);
  wire ker_right = (kernel_idx == 2'd1) || (kernel_idx == 2'd3);

  wire [15:0] ker_row_start = (!k_big) ? 16'd0 : (ker_top ? 16'd0 : k_lo);
  wire [15:0] ker_rows_total = (!k_big) ? K16 : (ker_top ? k_lo : k_hi);
  wire [15:0] ker_col_off  = (!k_big) ? 16'd0 : (ker_left ? 16'd0 : k_lo);
  wire [2:0]  ker_len_bytes = (!k_big) ? cfg_K[2:0] : (ker_left ? k_lo[2:0] : k_hi[2:0]);

  // Image Geometry
  wire img_is_top = (kernel_idx == 2'd0) || (kernel_idx == 2'd1);
  wire [15:0] img_row_start = img_is_top ? 16'd0 : k_lo;
  wire [15:0] img_rows_per_col = N16 - ((k_big) ?  k_lo : 16'd0); 
  wire [2:0]  img_len_bytes = (!k_big) ? cfg_K[2:0] : (ker_right ? k_hi[2:0] : k_lo[2:0]);
  
  // Control State
  reg mode_kernel; 
  reg main_busy; 
  
  // 1. Fetcher Logic
  reg [15:0] fetch_col; // Current logical column being fetched
  reg [15:0] fetch_row; // Row index within current logical column
  
  // "Total Request Counter": Monotonically increasing index of requested rows
  // Used for buffer synchronization and completion tracking.
  reg [31:0] total_req_cnt; 
  
  wire [31:0] total_to_fetch_ker = {16'd0, ker_rows_total};
  
  // Total Window Rows = (Number of Columns) * (Rows per Column)
  wire [15:0] total_cols = (end_col - start_col + 16'd1);
  wire [31:0] total_to_fetch_img = total_cols * img_rows_per_col;
  
  wire [31:0] req_limit = mode_kernel ? total_to_fetch_ker : total_to_fetch_img;

  // Address Calculation
  wire [15:0] ker_req_row = ker_row_start + fetch_row;
  wire [15:0] ker_req_addr = KER_BASE_BYTE + ker_req_row * col_bytes + ker_col_off;
  wire [15:0] img_req_addr = IMG_BASE_BYTE + fetch_col + (img_row_start + fetch_row) * row_bytes;

  // Buffer Flow Control (Circular Buffer check)
  // We can only fetch if the buffer has space relative to what the streamer needs.
  // Oldest needed logical row is roughly (wave_tick - 7).
  // Buffer size in logic is 16.
  wire signed [32:0] oldest_needed = $signed({1'b0, wave_tick}) - 33'd7;
  wire signed [32:0] req_cnt_s = {1'b0, total_req_cnt};
  wire buf_full = (req_cnt_s >= (oldest_needed + 33'd16));

  reg [31:0] wave_tick; 

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_req_cnt <= 0;
      fetch_col <= 0;
      fetch_row <= 0;
      reader_req_valid <= 0;
      reader_byte_addr <= 0;
      reader_len_bytes <= 0;
      main_busy <= 0;
      mode_kernel <= 0;
    end else begin
      if (!main_busy) begin
        if (start_load_kernel) begin
          main_busy <= 1;
          mode_kernel <= 1;
          total_req_cnt <= 0;
          fetch_row <= 0;
        end else if (start_stream_window) begin
          main_busy <= 1;
          mode_kernel <= 0;
          total_req_cnt <= 0;
          fetch_col <= start_col;
          fetch_row <= 0;
        end
        reader_req_valid <= 0;
      end 
      else begin
        // Issue requests if not done 
        if (total_req_cnt < req_limit) begin
          if (reader_req_ready) begin
             if (mode_kernel || !buf_full) begin
                reader_req_valid <= 1;
                reader_byte_addr <= mode_kernel ? ker_req_addr : img_req_addr;
                reader_len_bytes <= mode_kernel ? ker_len_bytes : img_len_bytes;
                
                total_req_cnt <= total_req_cnt + 1;
                
                // Advance counters
                if (mode_kernel) begin
                   fetch_row <= fetch_row + 1;
                end else begin
                   // If finished this column's rows, move to next column
                   if (fetch_row + 1'b1 == img_rows_per_col) begin
                      fetch_row <= 0;
                      fetch_col <= fetch_col + 1; 
                   end else begin
                      fetch_row <= fetch_row + 1;
                   end
                end
             end else begin
                reader_req_valid <= 0; // Stall
             end
          end
        end else begin
          reader_req_valid <= 0;
        end
      end
    end
  end

  // 2. Response Capture & Circular Buffer
  reg [63:0] row_buf [0:15];
  reg [31:0] resp_cnt;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_cnt <= 0;
      w_valid <= 0;
      w_data <= 0;
      kernel_done <= 0;
    end else begin
      kernel_done <= 0;
      w_valid <= 0;
      
      if (!main_busy) begin
        resp_cnt <= 0;
      end else begin
        if (reader_resp_valid) begin
           if (mode_kernel) begin
              w_data <= reader_resp_data;
              w_valid <= 1;
              resp_cnt <= resp_cnt + 1;
              if (resp_cnt + 1 >= req_limit) kernel_done <= 1;
           end else begin
              // Circular Buffer Write
              // Writes to index: (resp_cnt % 16)
              row_buf[resp_cnt[3:0]] <= reader_resp_data;
              resp_cnt <= resp_cnt + 1;
           end
        end
      end
      
      if (main_busy && mode_kernel && kernel_done) main_busy <= 0;
      if (main_busy && !mode_kernel && window_done) main_busy <= 0;
    end
  end

  // 3. Pipelined Wavefront Streamer
  wire [15:0] effective_len_base = (img_len_bytes == 0) ? 16'd8 : {13'd0, img_len_bytes};
  wire [31:0] wave_limit = req_limit + {16'd0, effective_len_base}; 
  
  // Ready when needed row (T) has been received
  wire wave_ready = (wave_tick < req_limit) ? (resp_cnt > wave_tick) : (resp_cnt >= req_limit);

  wire [3:0] effective_len = (img_len_bytes == 3'd0) ? 4'd8 : {1'b0, img_len_bytes};

  integer i;
  always @(*) begin
    p_data = 64'd0;
    for (i = 0; i < 8; i = i + 1) begin
       // Check if this logical lane i needs data from a valid logical row index
       // Logical Row Index = wave_tick - i
       if ((wave_tick >= i) && ((wave_tick - i) < req_limit) && (i < effective_len)) begin
          p_data[i*8 +: 8] = row_buf[(wave_tick - i) & 32'h000F][i*8 +: 8];
       end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wave_tick <= 0;
      p_valid <= 0;
      window_done <= 0;
    end else begin
      window_done <= 0;
      p_valid <= 0;
      
      if (!main_busy) begin
        wave_tick <= 0;
      end 
      else if (!mode_kernel) begin
        if (wave_tick < wave_limit) begin
           if (wave_ready) begin
              p_valid <= 1;
              wave_tick <= wave_tick + 1;
           end else begin
              p_valid <= 0; 
           end
        end else begin
           window_done <= 1;
        end
      end
    end
  end

endmodule
