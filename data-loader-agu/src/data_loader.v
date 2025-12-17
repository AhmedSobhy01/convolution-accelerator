module data_loader_padded_calc #(
  parameter ADDR_W = 12,
  parameter KER_BASE_BYTE = 16'd4096
)(
  input                   clk,
  input                   rst_n,

  input                   start,
  input      [6:0]        cfg_N,
  input      [4:0]        cfg_K,
  output reg              done,

  // 32-bit input stream [file:1]
  input      [31:0]       rx_data,
  input                   rx_valid,
  output reg              rx_ready,

  // SRAM0 write port (image + kernel, 16 KB)
  output reg              sram0_en,
  output reg              sram0_we,        // 1=write
  output reg [ADDR_W-1:0] sram0_addr,      // word address
  output reg [63:0]       sram0_wdata,
  output reg [7:0]        sram0_wmask,

  // SRAM1 write port (unused for now, reserved for psum/output)
  output reg              sram1_en,
  output reg              sram1_we,
  output reg [ADDR_W-1:0] sram1_addr,
  output reg [63:0]       sram1_wdata,
  output reg [7:0]        sram1_wmask
);

  // ----------------------------
  // pad helpers
  // ----------------------------
  function [15:0] ceil8;
    input [15:0] x;
    begin
      ceil8 = (x + 16'd7) & 16'hFFF8;   // round up to multiple of 8
    end
  endfunction

  wire [15:0] N16 = {9'd0, cfg_N};
  wire [15:0] K16 = {11'd0, cfg_K};

  // image: row padding
  wire [15:0] row_bytes = ceil8(N16);
  wire [15:0] img_bytes_padded = row_bytes * N16;

  // kernel: column padding (since you store kernel column-major)
  wire [15:0] col_bytes = ceil8(K16);
  wire [15:0] ker_bytes_padded = col_bytes * K16;

  // ----------------------------
  // FSM
  // ----------------------------
  localparam IDLE             = 3'd0;
  localparam LOAD_IMG_LOWER   = 3'd1;
  localparam LOAD_IMG_UPPER   = 3'd2;
  localparam LOAD_KER_LOWER   = 3'd3;
  localparam LOAD_KER_UPPER   = 3'd4;
  localparam DONE_ST          = 3'd5;

  reg [2:0] state;

  reg [31:0] buf_lo;

  reg [15:0] byte_ptr;
  reg [15:0] img_written;
  reg [15:0] ker_written;

  // ----------------------------
  // combinational outputs
  // ----------------------------
  always @(*) begin
    rx_ready   = 1'b0;
    done       = 1'b0;
    case (state)
      LOAD_IMG_LOWER: rx_ready = 1'b1;
      LOAD_IMG_UPPER: rx_ready = 1'b1;
      LOAD_KER_LOWER: rx_ready = 1'b1;
      LOAD_KER_UPPER: rx_ready = 1'b1;
      DONE_ST:        done     = 1'b1;
      default: ;
    endcase
  end

  // ----------------------------
  // sequential
  // ----------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      buf_lo <= 32'd0;

      byte_ptr <= 16'd0;
      img_written <= 16'd0;
      ker_written <= 16'd0;

      // SRAM0 defaults (idle)
      sram0_en <= 1'b0;
      sram0_we <= 1'b0;
      sram0_addr <= {ADDR_W{1'b0}};
      sram0_wdata <= 64'd0;
      sram0_wmask <= 8'h00;

      // SRAM1 defaults (idle)
      sram1_en    <= 1'b0;
      sram1_we    <= 1'b0;
      sram1_addr  <= {ADDR_W{1'b0}};
      sram1_wdata <= 64'd0;
      sram1_wmask <= 8'h00;
    end else begin
      // default: no write pulse unless asserted in a *_UPPER state
      sram0_en <= 1'b0;
      sram0_we <= 1'b0;
      sram0_wmask <= 8'h00;

      sram1_en    <= 1'b0;
      sram1_we    <= 1'b0;
      sram1_wmask <= 8'h00;

      case (state)
        IDLE: begin
          byte_ptr <= 16'd0;
          img_written <= 16'd0;
          ker_written <= 16'd0;
          if (start) state <= LOAD_IMG_LOWER;
        end

        LOAD_IMG_LOWER: begin
          if (rx_valid && rx_ready) begin
            buf_lo <= rx_data;
            state <= LOAD_IMG_UPPER;
          end
        end

        LOAD_IMG_UPPER: begin
          if (rx_valid && rx_ready) begin
            // write 8 bytes (2x32-bit beats) into SRAM0
            sram0_en    <= 1'b1;
            sram0_we    <= 1'b1;
            sram0_addr  <= byte_ptr[15:3];
            sram0_wdata <= {rx_data, buf_lo};
            sram0_wmask <= 8'hFF;

            byte_ptr <= byte_ptr + 16'd8;
            img_written <= img_written + 16'd8;

            if (img_written + 16'd8 >= img_bytes_padded) begin
              // force kernel at fixed 4KB
              byte_ptr <= KER_BASE_BYTE;
              state <= LOAD_KER_LOWER;
            end else begin
              state <= LOAD_IMG_LOWER;
            end
          end
        end

        LOAD_KER_LOWER: begin
          if (rx_valid && rx_ready) begin
            buf_lo <= rx_data;
            state <= LOAD_KER_UPPER;
          end
        end

        LOAD_KER_UPPER: begin
          if (rx_valid && rx_ready) begin
            sram0_en    <= 1'b1;
            sram0_we    <= 1'b1;
            sram0_addr  <= byte_ptr[15:3];
            sram0_wdata <= {rx_data, buf_lo};
            sram0_wmask <= 8'hFF;

            byte_ptr <= byte_ptr + 16'd8;
            ker_written <= ker_written + 16'd8;

            if (ker_written + 16'd8 >= ker_bytes_padded) begin
              state <= DONE_ST;
            end else begin
              state <= LOAD_KER_LOWER;
            end
          end
        end

        DONE_ST: begin
          state <= IDLE; // done is high in DONE_ST via combinational
        end
      endcase
    end
  end

endmodule
