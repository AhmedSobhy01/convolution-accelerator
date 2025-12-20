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

  // Simplified States for byte-by-byte streaming
  // Timing:
  // T0: ST_READ (Request pixel from SRAM)
  // T1: ST_WAIT (Wait for SRAM 2-cycle latency)
  // T2: ST_SEND (Data valid, send to DRAM)
  localparam ST_IDLE = 2'd0;
  localparam ST_READ = 2'd1;
  localparam ST_WAIT = 2'd2;
  localparam ST_SEND = 2'd3;

  reg [1:0] state;
  reg [ADDR_W-1:0] pixel_cnt;

  // Row-major to column-major address conversion
  reg [6:0] row_cnt;  // Current row (0 to output_dim-1)
  reg [6:0] col_cnt;  // Current column (0 to output_dim-1)

  wire [ADDR_W-1:0] sram_addr_calc = col_cnt * cfg_output_dim + row_cnt;

  // Summation Logic (Combinational)
  reg [7:0] computed_pixel;
  reg [9:0] sum_temp;

  // CHANGED: Use Combinational Logic here.
  // sram_rdata is already registered inside the SRAM.
  always @(*) begin
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
      pixel_cnt  <= {ADDR_W{1'b0}};
      row_cnt    <= 7'd0;
      col_cnt    <= 7'd0;
      tx_valid   <= 1'b0;
      tx_data    <= 8'd0;
      done       <= 1'b0;
    end else begin
      // Defaults
      sram_en  <= 1'b0;
      done     <= 1'b0;

      case (state)
        ST_IDLE: begin
          pixel_cnt <= {ADDR_W{1'b0}};
          row_cnt   <= 7'd0;
          col_cnt   <= 7'd0;
          tx_valid  <= 1'b0;
          if (start) state <= ST_READ;
        end

        ST_READ: begin
          // Check if all pixels have been processed
          if (pixel_cnt >= cfg_num_pixels) begin
            done  <= 1'b1;
            state <= ST_IDLE;
          end else begin
            // Request pixel from SRAM
            sram_en   <= 1'b1;
            sram_addr <= sram_addr_calc;
            pixel_cnt <= pixel_cnt + 1'b1;
            
            // Update row/col counters for column-major addressing
            if (col_cnt + 1'b1 >= cfg_output_dim) begin
              col_cnt <= 7'd0;
              row_cnt <= row_cnt + 1'b1;
            end else begin
              col_cnt <= col_cnt + 1'b1;
            end
            
            state <= ST_WAIT;
          end
        end

        ST_WAIT: begin
          // Wait one cycle for SRAM 2-cycle latency
          // (First cycle was ST_READ, second cycle is ST_WAIT, data ready in ST_SEND)
          state <= ST_SEND;
        end

        ST_SEND: begin
          // Data is now valid from SRAM, computed_pixel has the result
          if (!tx_valid) begin
            // Drive output with computed pixel
            tx_data  <= computed_pixel;
            tx_valid <= 1'b1;
          end else begin
            // Wait for handshake
            if (tx_ready) begin
              tx_valid <= 1'b0;
              state    <= ST_READ;
            end
          end
        end

        default: begin
          state <= ST_IDLE;
        end

      endcase
    end
  end


endmodule
