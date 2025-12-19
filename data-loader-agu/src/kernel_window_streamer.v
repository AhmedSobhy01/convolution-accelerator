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
  output reg          kernel_done,

  input  wire         start_stream_window,
  input  wire [15:0]  window_col,
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

  localparam IDLE        = 2'd0;
  localparam LOAD_KERNEL = 2'd1;
  localparam STREAM_WIN  = 2'd2;

  reg [1:0] state;
  reg [4:0] col_cnt;       // requests issued
  reg [4:0] col_resp_cnt;  // responses received
  reg [6:0] row_cnt;
  reg [6:0] row_resp_cnt;

  wire [15:0] ker_col_addr = KER_BASE_BYTE + col_cnt * col_bytes;
  wire [15:0] img_row_addr = IMG_BASE_BYTE + window_col + row_cnt * row_bytes;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      col_cnt <= 5'd0;
      col_resp_cnt <= 5'd0;
      row_cnt <= 7'd0;
      row_resp_cnt <= 7'd0;
      reader_req_valid <= 1'b0;
      reader_byte_addr <= {BYTE_ADDR_W{1'b0}};
      reader_len_bytes <= 3'd0;
      w_valid <= 1'b0;
      w_data  <= 64'd0;
      p_valid <= 1'b0;
      p_data  <= 64'd0;
      kernel_done <= 1'b0;
      window_done <= 1'b0;
    end else begin
      // Default: deassert done flags
      kernel_done <= 1'b0;
      window_done <= 1'b0;

      // Capture responses (happens in parallel with request issuing)
      if (reader_resp_valid) begin
        if (state == LOAD_KERNEL) begin
          w_valid <= 1'b1;
          w_data  <= reader_resp_data;
          col_resp_cnt <= col_resp_cnt + 1'b1;
          
          // Check if all responses received
          if (col_resp_cnt + 1'b1 >= cfg_K) begin
            kernel_done <= 1'b1;
          end
        end else if (state == STREAM_WIN) begin
          p_valid <= 1'b1;
          p_data  <= reader_resp_data;
          row_resp_cnt <= row_resp_cnt + 1'b1;
          
          if (row_resp_cnt + 1'b1 >= cfg_N) begin
            window_done <= 1'b1;
          end
        end
      end else begin
        w_valid <= 1'b0;
        p_valid <= 1'b0;
      end

      // State machine: issue requests
      case (state)
        IDLE: begin
          col_cnt <= 5'd0;
          col_resp_cnt <= 5'd0;
          row_cnt <= 7'd0;
          row_resp_cnt <= 7'd0;
          reader_req_valid <= 1'b0;
          
          if (start_load_kernel) begin
            state <= LOAD_KERNEL;
          end else if (start_stream_window) begin
            state <= STREAM_WIN;
          end
        end

        LOAD_KERNEL: begin
          // Issue requests every cycle until done
          if (col_cnt < cfg_K) begin
            reader_byte_addr <= ker_col_addr;
            reader_len_bytes <= cfg_K[2:0];
            reader_req_valid <= 1'b1;
            col_cnt <= col_cnt + 1'b1;
          end else begin
            reader_req_valid <= 1'b0;
            // Wait for all responses, then go idle
            if (col_resp_cnt >= cfg_K) begin
              state <= IDLE;
            end
          end
        end

        STREAM_WIN: begin
          if (row_cnt < cfg_N) begin
            reader_byte_addr <= img_row_addr;
            reader_len_bytes <= cfg_K[2:0];
            reader_req_valid <= 1'b1;
            row_cnt <= row_cnt + 1'b1;
          end else begin
            reader_req_valid <= 1'b0;
            if (row_resp_cnt >= cfg_N) begin
              state <= IDLE;
            end
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
