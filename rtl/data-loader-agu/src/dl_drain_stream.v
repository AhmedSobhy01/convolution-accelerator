`timescale 1ns/1ps

module dl_drain_stream #(
  parameter ADDR_W = 12
)(
  input  wire               clk,
  input  wire               rst_n,

  // Control Signals
  input  wire               start,
  input  wire [ADDR_W-1:0]  cfg_num_pixels,
  input  wire [6:0]         cfg_output_dim,
  input  wire               cfg_split_mode,
  output reg                done,

  // SRAM1 Read Port
  output reg                sram_en,
  output reg [ADDR_W-1:0]   sram_addr,
  input  wire [31:0]        sram_rdata,

  // DRAM Output Stream (Byte-by-byte)
  output reg                tx_valid,
  output reg [7:0]          tx_data,
  input  wire               tx_ready
);

  localparam ST_IDLE   = 2'd0;
  localparam ST_RUN    = 2'd1;  // Active draining
  localparam ST_DONE   = 2'd2;  // Signal done

  reg [1:0] state;

  // Read tracking
  reg [ADDR_W-1:0] read_cnt;     // Number of reads issued
  reg [ADDR_W-1:0] tx_cnt;       // Pixels transmitted

  // Row-major to column-major address conversion
  reg [6:0] read_row, read_col;

  // 2-stage pipeline to track data validity (matches SRAM latency)
  reg [1:0] valid_sr;  // Shift register: valid_sr[1] = data ready now

  // Address calculation (column-major order)
  wire [ADDR_W-1:0] sram_addr_calc = read_col * cfg_output_dim + read_row;

  // Can we issue more reads?
  wire can_read = (read_cnt < cfg_num_pixels);

  // Is data available at output?
  wire data_ready = valid_sr[1];

  // Are we done?
  wire all_done = (tx_cnt >= cfg_num_pixels) && !valid_sr[1] && !valid_sr[0];

  // Summation Logic (Combinational)
  reg [7:0] computed_pixel;
  reg [9:0] sum_temp;

  always @(*) begin
    // Default assignments prevent inferred latches (all paths drive both signals)
    sum_temp       = 10'd0;
    computed_pixel = 8'd0;
    if (cfg_split_mode) begin
      sum_temp = sram_rdata[7:0] + sram_rdata[15:8] + sram_rdata[23:16] + sram_rdata[31:24];
      computed_pixel = (sum_temp > 10'd255) ? 8'hFF : sum_temp[7:0];
    end else begin
      computed_pixel = sram_rdata[7:0];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      sram_en    <= 1'b0;
      sram_addr  <= {ADDR_W{1'b0}};
      read_cnt   <= {ADDR_W{1'b0}};
      read_row   <= 7'd0;
      read_col   <= 7'd0;
      tx_valid   <= 1'b0;
      tx_data    <= 8'd0;
      tx_cnt     <= {ADDR_W{1'b0}};
      done       <= 1'b0;
      valid_sr   <= 2'b00;
    end else begin
      done <= 1'b0;

      case (state)
        ST_IDLE: begin
          read_cnt   <= {ADDR_W{1'b0}};
          read_row   <= 7'd0;
          read_col   <= 7'd0;
          tx_cnt     <= {ADDR_W{1'b0}};
          tx_valid   <= 1'b0;
          valid_sr   <= 2'b00;
          sram_en    <= 1'b0;

          if (start) begin
            state <= ST_RUN;
          end
        end

        ST_RUN: begin
          sram_en <= 1'b0;  // Will be set below if we issue a read

          // Shift the valid pipeline every cycle
          valid_sr <= {valid_sr[0], 1'b0};

          // Issue read if: we have pixels left AND (no backpressure OR pipeline not full)
          // We issue a read when the TX side can accept or we're filling the pipeline
          if (can_read && (!tx_valid || tx_ready || !valid_sr[1])) begin
            sram_en   <= 1'b1;
            sram_addr <= sram_addr_calc;
            read_cnt  <= read_cnt + 1'b1;

            // Advance row/col pointers
            if (read_col + 1'b1 >= cfg_output_dim) begin
              read_col <= 7'd0;
              read_row <= read_row + 1'b1;
            end else begin
              read_col <= read_col + 1'b1;
            end

            // Push 1 into pipeline
            valid_sr <= {valid_sr[0], 1'b1};
          end

          // TX side: output when data is ready
          if (data_ready) begin
            if (!tx_valid || tx_ready) begin
              tx_data  <= computed_pixel;
              tx_valid <= 1'b1;
              tx_cnt   <= tx_cnt + 1'b1;
            end
          end else begin
            if (tx_ready) begin
              tx_valid <= 1'b0;
            end
          end

          if (all_done) begin
            state <= ST_DONE;
          end
        end

        ST_DONE: begin
          tx_valid <= 1'b0;
          sram_en  <= 1'b0;
          done     <= 1'b1;
          state    <= ST_IDLE;
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
