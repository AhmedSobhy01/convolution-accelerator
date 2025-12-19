`timescale 1ns/1ps

module dl_dma_rx #(
  parameter ADDR_W = 10,
  parameter KER_BASE_BYTE = 16'd4096
)(
  input                   clk,
  input                   rst_n,

  input                   start,
  input      [6:0]        cfg_N,
  input      [4:0]        cfg_K,
  output reg              done,

  // 32-bit input stream
  input      [31:0]       rx_data,
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

  localparam IDLE    = 3'd0;
  localparam IMG_LO  = 3'd1;
  localparam IMG_HI  = 3'd2;
  localparam KER_LO  = 3'd3;
  localparam KER_HI  = 3'd4;
  localparam DONE_ST = 3'd5;

  reg [2:0]  state;
  reg [31:0] buf_lo;

  reg [15:0] byte_ptr;
  reg [15:0] img_written;
  reg [15:0] ker_written;

  always @(*) begin
    rx_ready = 1'b0;
    done     = 1'b0;

    case (state)
      IMG_LO:  rx_ready = 1'b1;
      IMG_HI:  rx_ready = 1'b1;
      KER_LO:  rx_ready = 1'b1;
      KER_HI:  rx_ready = 1'b1;
      DONE_ST: done     = 1'b1;
      default: ;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      buf_lo <= 32'd0;

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

      case (state)
        IDLE: begin
          byte_ptr <= 16'd0;
          img_written <= 16'd0;
          ker_written <= 16'd0;
          if (start) state <= IMG_LO;
        end

        IMG_LO: begin
          if (rx_valid && rx_ready) begin
            buf_lo <= rx_data;
            state  <= IMG_HI;
          end
        end

        IMG_HI: begin
          if (rx_valid && rx_ready) begin
            sram0_en    <= 1'b1;
            sram0_we    <= 1'b1;
            sram0_addr  <= byte_ptr[15:3];
            sram0_wdata <= {rx_data, buf_lo};
            sram0_wmask <= 8'hFF;

            byte_ptr    <= byte_ptr + 16'd8;
            img_written <= img_written + 16'd8;

            if (img_written + 16'd8 >= img_bytes_total) begin
              byte_ptr <= KER_BASE_BYTE;
              state    <= KER_LO;
            end else begin
              state <= IMG_LO;
            end
          end
        end

        KER_LO: begin
          if (rx_valid && rx_ready) begin
            buf_lo <= rx_data;
            state  <= KER_HI;
          end
        end

        KER_HI: begin
          if (rx_valid && rx_ready) begin
            sram0_en    <= 1'b1;
            sram0_we    <= 1'b1;
            sram0_addr  <= byte_ptr[15:3];
            sram0_wdata <= {rx_data, buf_lo};
            sram0_wmask <= 8'hFF;

            byte_ptr    <= byte_ptr + 16'd8;
            ker_written <= ker_written + 16'd8;

            if (ker_written + 16'd8 >= ker_bytes_total)
              state <= DONE_ST;
            else
              state <= KER_LO;
          end
        end

        DONE_ST: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
