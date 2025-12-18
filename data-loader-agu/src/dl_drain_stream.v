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
  localparam ST_IDLE    = 3'd0;
  localparam ST_READ_0  = 3'd1; // Req Px0
  localparam ST_READ_1  = 3'd2; // Req Px1
  localparam ST_READ_2  = 3'd3; // Req Px2 (Px0 arriving)
  localparam ST_READ_3  = 3'd4; // Req Px3, Latch Px0
  localparam ST_LATCH_1 = 3'd5; // Latch Px1
  localparam ST_LATCH_2 = 3'd6; // Latch Px2
  localparam ST_SEND    = 3'd7; // Latch Px3 & Send

  reg [2:0] state;
  reg [ADDR_W-1:0] pixel_cnt;
  reg [31:0] pack_buf;

  // Summation Logic
  reg [7:0] computed_pixel;
  reg [9:0] sum_temp;

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

        // Pipeline: Req N occurs at State N.
        // Data N captured at State N+3 (2-cycle SRAM latency + 1 cycle register delay)

        ST_READ_0: begin // Cycle T0: Addr=0
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

        ST_READ_1: begin // Cycle T1: Addr=1
          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_READ_2;
        end

        ST_READ_2: begin // Cycle T2: Addr=2
          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_READ_3;
        end

        ST_READ_3: begin // Cycle T3: Addr=3. Data(0) is valid here.
          // Latch Pixel 0
          pack_buf[7:0] <= computed_pixel;

          if (pixel_cnt < cfg_num_pixels) begin
            sram_en   <= 1'b1;
            sram_addr <= pixel_cnt;
            pixel_cnt <= pixel_cnt + 1'b1;
          end
          state <= ST_LATCH_1;
        end

        ST_LATCH_1: begin // Cycle T4. Data(1) valid.
          // Latch Pixel 1
          pack_buf[15:8] <= computed_pixel;
          state <= ST_LATCH_2;
        end

        ST_LATCH_2: begin // Cycle T5. Data(2) valid.
          // Latch Pixel 2
          pack_buf[23:16] <= computed_pixel;
          state <= ST_SEND;
        end

        ST_SEND: begin // Cycle T6. Data(3) valid.
          if (!tx_valid) begin
             // Capture Pixel 3 and Drive Output
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

      endcase
    end
  end

endmodule