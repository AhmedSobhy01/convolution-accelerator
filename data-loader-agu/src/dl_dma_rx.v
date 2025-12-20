`timescale 1ns/1ps

module dl_dma_rx #(
  parameter ADDR_W        = 10,
  parameter KER_BASE_BYTE = 16'd4096
)(
  input                   clk,
  input                   rst_n,

  input                   start,
  input      [6:0]        cfg_N,
  input      [4:0]        cfg_K,
  output reg              done,

  input       [7:0]       rx_data,
  input                   rx_valid,
  output reg              rx_ready,

  // SRAM0 write port (64-bit)
  output reg              sram0_en,
  output reg              sram0_we,
  output reg [ADDR_W-1:0] sram0_addr,
  output reg [63:0]       sram0_wdata,
  output reg [7:0]        sram0_wmask
);

  wire [15:0] N16 = {9'd0, cfg_N};
  wire [15:0] K16 = {11'd0, cfg_K};

  // PACKED: no padding
  wire [15:0] row_bytes = N16;
  wire [15:0] col_bytes = K16;

  wire [15:0] img_bytes_total = N16 * N16;
  wire [15:0] ker_bytes_total = K16 * K16;

  localparam IDLE    = 2'd0;
  localparam IMG_WR  = 2'd1;
  localparam KER_WR  = 2'd2;
  localparam DONE_ST = 2'd3;

  reg [1:0]  state;

  reg [15:0] byte_ptr;
  reg [15:0] img_written;
  reg [15:0] ker_written;

  wire [2:0] lane    = byte_ptr[2:0];
  wire [5:0] shamt   = {lane, 3'b000};
  wire [63:0] wdata_byte = (64'({56'd0, rx_data}) << shamt);
  wire [7:0]  wmask_byte = (8'b0000_0001 << lane);

  wire img_last = (img_written + 16'd1 >= img_bytes_total);
  wire ker_last = (ker_written + 16'd1 >= ker_bytes_total);

  // Handshake ready/done
  always @(*) begin
    rx_ready = (state == IMG_WR) || (state == KER_WR);
    done     = (state == DONE_ST);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      byte_ptr <= 16'd0;
      img_written <= 16'd0;
      ker_written <= 16'd0;

      sram0_en <= 1'b0;
      sram0_we <= 1'b0;
      sram0_addr <= {ADDR_W{1'b0}};
      sram0_wdata <= 64'd0;
      sram0_wmask <= 8'h00;

    end else begin
      sram0_en    <= 1'b0;
      sram0_we    <= 1'b0;
      sram0_wmask <= 8'h00;
      sram0_wdata <= 64'd0;

      case (state)
        IDLE: begin
          byte_ptr <= 16'd0;
          img_written <= 16'd0;
          ker_written <= 16'd0;
          if (start) state <= IMG_WR;
        end

        IMG_WR: begin
          if (rx_valid && rx_ready) begin
            sram0_en <= 1'b1;
            sram0_we <= 1'b1;
            sram0_addr <= byte_ptr[ADDR_W+2:3]; // word address = byte_ptr >> 3
            sram0_wdata <= wdata_byte;
            sram0_wmask <= wmask_byte;

            byte_ptr <= byte_ptr + 16'd1;
            img_written <= img_written + 16'd1;

            if (img_last) begin
              byte_ptr <= KER_BASE_BYTE;
              state <= KER_WR;
            end
          end
        end

        KER_WR: begin
          if (rx_valid && rx_ready) begin
            sram0_en    <= 1'b1;
            sram0_we    <= 1'b1;
            sram0_addr  <= byte_ptr[ADDR_W+2:3];
            sram0_wdata <= wdata_byte;
            sram0_wmask <= wmask_byte;

            byte_ptr  <= byte_ptr + 16'd1;
            ker_written <= ker_written + 16'd1;

            if (ker_last) begin
              state <= DONE_ST;
            end
          end
        end

        DONE_ST: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
