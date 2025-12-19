`timescale 1ns/1ps

module dl_drain_stream #(
  parameter ADDR_W = 12
)(
  input  wire               clk,
  input  wire               rst_n,

  // Control Signals
  input  wire               start,
  input  wire [ADDR_W-1:0]  cfg_num_pixels,
  input  wire               cfg_split_mode,
  output reg                done,

  // SRAM1 Read Port
  output reg                sram_en,
  output reg [ADDR_W-1:0]   sram_addr,
  input  wire [31:0]        sram_rdata,

  // DRAM Output Stream
  output reg                tx_valid,
  output reg [31:0]         tx_data,
  input  wire               tx_ready
);

  // Expanded States for 2-cycle latency
  // Timing:
  // T0: ST_READ_0 (Addr 0)
  // T1: ST_READ_1 (Addr 1). SRAM latches Addr 0.
  // T2: ST_READ_2 (Addr 2). SRAM outputs Data 0. Latch Data 0.
  // T3: ST_READ_3 (Addr 3). SRAM outputs Data 1. Latch Data 1.
  localparam ST_IDLE    = 3'd0;
  localparam ST_READ_0  = 3'd1; 
  localparam ST_READ_1  = 3'd2; 
  localparam ST_READ_2  = 3'd3; 
  localparam ST_READ_3  = 3'd4; 
  localparam ST_LATCH_1 = 3'd5; 
  localparam ST_SEND    = 3'd6; 

  reg [2:0] state;
  reg [ADDR_W-1:0] pixel_cnt;
  reg [31:0] pack_buf;

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
      pack_buf   <= 32'd0;
      tx_valid   <= 1'b0;
      tx_data    <= 32'd0;
      done       <= 1'b0;
    end else begin
      // Defaults
      sram_en  <= 1'b0;
      done     <= 1'b0;

      case (state)
        ST_IDLE: begin
          pixel_cnt <= {ADDR_W{1'b0}};
          if (start) state <= ST_READ_0;
        end

        ST_READ_0: begin // Cycle T0: Req Px0
          if (pixel_cnt >= cfg_num_pixels) begin
            done  <= 1'b1;
            state <= ST_IDLE;
          end else begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
            state     <= ST_READ_1;
          end
        end

        ST_READ_1: begin // Cycle T1: Req Px1
          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_READ_2;
        end

        ST_READ_2: begin // Cycle T2: Req Px2. Data Px0 is valid at sram_rdata.
          // Capture Px0
          pack_buf[7:0] <= computed_pixel;
          
          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_READ_3;
        end

        ST_READ_3: begin // Cycle T3: Req Px3. Data Px1 is valid.
          // Capture Px1
          pack_buf[15:8] <= computed_pixel;

          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_LATCH_1;
        end

        ST_LATCH_1: begin // Cycle T4. Data Px2 is valid.
          // Capture Px2
          pack_buf[23:16] <= computed_pixel;
          state <= ST_SEND;
        end

        ST_SEND: begin // Cycle T5. Data Px3 is valid.
          if (!tx_valid) begin
             // Capture Px3 and Drive Output
             pack_buf[31:24] <= computed_pixel;
             tx_data         <= {computed_pixel, pack_buf[23:0]};
             tx_valid        <= 1'b1;
          end else begin
             // Handshake
             if (tx_ready) begin
               tx_valid <= 1'b0;
               if (pixel_cnt >= cfg_num_pixels) begin
                 done  <= 1'b1;
                 state <= ST_IDLE;
               end else begin
                 state <= ST_READ_0;
               end
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