`timescale 1ns/1ps

module dl_dma_rx #(
  parameter ADDR_W = 10
)(
  input                    clk,
  input                    rst_n,

  input                    cmd_valid,
  output                   cmd_ready,
  input      [15:0]        cmd_base_byte,
  input      [15:0]        cmd_len_bytes,
  output                   cmd_done,

  input      [31:0]        rx_data,
  input                    rx_valid,
  output                   rx_ready,

  output reg               sram0_p0_en,
  output reg               sram0_p0_we,
  output reg [ADDR_W-1:0]  sram0_p0_addr,
  output reg [63:0]        sram0_p0_wdata,
  output reg [7:0]         sram0_p0_wmask
);

  localparam ST_IDLE  = 2'd0;
  localparam ST_GETLO = 2'd1;
  localparam ST_GETHI = 2'd2;
  localparam ST_DONE  = 2'd3;

  reg [1:0]  st;
  reg [31:0] buf_lo;

  reg [15:0] len_bytes;
  reg [15:0] bytes_written;
  reg [15:0] cur_byte_ptr;

  // temps (for older Verilog parsers)
  reg [15:0] rem_bytes;
  reg [2:0]  rem_low3;

  assign cmd_ready = (st == ST_IDLE);
  assign cmd_done  = (st == ST_DONE);
  assign rx_ready  = (st == ST_GETLO) || (st == ST_GETHI);

  function [7:0] mask_for_last;
    input [2:0] nbytes;
    begin
      case (nbytes)
        3'd1: mask_for_last = 8'b0000_0001;
        3'd2: mask_for_last = 8'b0000_0011;
        3'd3: mask_for_last = 8'b0000_0111;
        3'd4: mask_for_last = 8'b0000_1111;
        3'd5: mask_for_last = 8'b0001_1111;
        3'd6: mask_for_last = 8'b0011_1111;
        3'd7: mask_for_last = 8'b0111_1111;
        default: mask_for_last = 8'b0000_0000;
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st            <= ST_IDLE;
      buf_lo        <= 32'd0;
      len_bytes     <= 16'd0;
      bytes_written <= 16'd0;
      cur_byte_ptr  <= 16'd0;

      sram0_p0_en    <= 1'b0;
      sram0_p0_we    <= 1'b0;
      sram0_p0_addr  <= {ADDR_W{1'b0}};
      sram0_p0_wdata <= 64'd0;
      sram0_p0_wmask <= 8'h00;

      rem_bytes <= 16'd0;
      rem_low3  <= 3'd0;

    end else begin
      sram0_p0_en    <= 1'b0;
      sram0_p0_we    <= 1'b0;
      sram0_p0_wmask <= 8'h00;

      case (st)
        ST_IDLE: begin
          bytes_written <= 16'd0;
          if (cmd_valid && cmd_ready) begin
            cur_byte_ptr <= cmd_base_byte;
            len_bytes    <= cmd_len_bytes;
            st           <= ST_GETLO;
          end
        end

        ST_GETLO: begin
          if (rx_valid && rx_ready) begin
            buf_lo <= rx_data;
            st     <= ST_GETHI;
          end
        end

        ST_GETHI: begin
          if (rx_valid && rx_ready) begin
            if (len_bytes > bytes_written) begin
              rem_bytes = len_bytes - bytes_written; // blocking temp is ok here
              rem_low3  = rem_bytes[2:0];

              sram0_p0_en    <= 1'b1;
              sram0_p0_we    <= 1'b1;
              sram0_p0_addr  <= cur_byte_ptr[15:3];
              sram0_p0_wdata <= {rx_data, buf_lo};

              if (rem_bytes >= 16'd8)
                sram0_p0_wmask <= 8'hFF;
              else
                sram0_p0_wmask <= mask_for_last(rem_low3);

              if (rem_bytes >= 16'd8)
                bytes_written <= bytes_written + 16'd8;
              else
                bytes_written <= bytes_written + rem_bytes;

              cur_byte_ptr <= cur_byte_ptr + 16'd8;
            end

            if ((len_bytes - bytes_written) <= 16'd8)
              st <= ST_DONE;
            else
              st <= ST_GETLO;
          end
        end

        ST_DONE: begin
          st <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
