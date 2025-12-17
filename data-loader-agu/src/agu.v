// agu_window_stream_dp_yfirst
// Y-first traversal: for each out_x block, sweep out_y = 0..OH-1,
// emitting K rows per output, one address per cycle.
module agu_window_stream_dp_yfirst #(
  parameter ADDR_W = 12
)(
  input  wire        clk,
  input  wire        rst_n,

  // Control (set per kernel corner phase)
  input  wire        start,
  input  wire [15:0] cfg_OW,          // output width  (N - K + 1)
  input  wire [15:0] cfg_OH,          // output height (N - K + 1)
  input  wire [15:0] cfg_K,           // kernel size K (square)
  input  wire [15:0] img_row_stride,  // bytes (padded N)

  input  wire [7:0]  corner_row_off,  // per-corner offsets
  input  wire [7:0]  corner_col_off,

  // To chunk loader pipeline (one request per cycle)
  output reg               req_valid,
  output reg [ADDR_W+2:0]  req_byte_addr,

  // Optional meta for SA / debug
  output reg [15:0]        cur_out_x,
  output reg [15:0]        cur_out_y,
  output reg [7:0]         cur_ker_row,

  output reg               done
);

  localparam ST_IDLE = 2'd0;
  localparam ST_RUN  = 2'd1;
  localparam ST_DONE = 2'd2;

  reg [1:0]  state;

  // Counters: out_x steps by 8; out_y sweeps 0..OH-1; ker_row 0..K-1
  reg [15:0] out_x;
  reg [15:0] out_y;
  reg [7:0]  ker_row;

  // Address math
  wire [31:0] base_row   = (out_y + corner_row_off + ker_row);
  wire [31:0] base_col   = (out_x + corner_col_off);
  wire [31:0] byte_addr  = base_row * img_row_stride + base_col;

  always @(*) begin
    req_valid     = (state == ST_RUN);
    req_byte_addr = byte_addr[ADDR_W+2:0];
    done          = (state == ST_DONE);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= ST_IDLE;
      out_x   <= 16'd0;
      out_y   <= 16'd0;
      ker_row <= 8'd0;
    end else begin
      case (state)
        ST_IDLE: begin
          out_x   <= 16'd0;
          out_y   <= 16'd0;
          ker_row <= 8'd0;
          if (start) state <= ST_RUN;
        end

        ST_RUN: begin
          // One address each cycle; advance ker_row first
          if (ker_row == cfg_K - 1) begin
            ker_row <= 8'd0;
            // Y-first: move to next output row
            if (out_y == cfg_OH - 1) begin
              out_y <= 16'd0;
              // advance to next out_x block (SA width = 8)
              if (out_x + 16'd8 >= cfg_OW) begin
                out_x <= 16'd0;
                state <= ST_DONE;
              end else begin
                out_x <= out_x + 16'd8;
              end
            } else begin
              out_y <= out_y + 16'd1;
            end
          end else begin
            ker_row <= ker_row + 8'd1;
          end
        end

        ST_DONE: begin
          state <= ST_IDLE; // single-cycle done
        end
      endcase
    end
  end

endmodule
