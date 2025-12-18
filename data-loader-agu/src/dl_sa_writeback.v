`timescale 1ns/1ps

module dl_sa_writeback #(
  parameter ADDR_W = 11 // 16KB SRAM (64-bit words) => 2048 words => 11 bits
)(
  input  wire        clk,
  input  wire        rst_n,

  // Configuration from Control Unit
  input  wire        cfg_start_pass, // Pulse: Reset pointer for new kernel pass
  input  wire [1:0]  cfg_ker_idx,    // Current sub-kernel index (0..3)

  // From Systolic Array / Aggregator
  input  wire        sa_valid,       // Data is valid this cycle
  input  wire [63:0] sa_wdata,       // 8 pixels packed (8 bits each)

  // To SRAM1 (Write Port)
  output reg              sram1_en,
  output reg              sram1_we,
  output reg [ADDR_W-1:0] sram1_addr,
  output reg [63:0]       sram1_wdata,
  output reg [7:0]        sram1_wmask
);

  // Counter to track the linear sequence of output blocks (Pixel Groups)
  // For a 64x64 image, we have ~512 blocks. 11 bits is sufficient.
  reg [ADDR_W-1:0] write_cnt;

  // Address Calculation:
  // We offset the linear block index by 4 to leave room for the 4 sub-kernels.
  // Addr = (Block_Index * 4) + Kernel_Index
  // This stores K0, K1, K2, K3 results for the same pixels in adjacent words.
  wire [ADDR_W-1:0] calc_addr = (write_cnt << 2) + { {(ADDR_W-2){1'b0}}, cfg_ker_idx }; 

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_cnt    <= {ADDR_W{1'b0}};
      sram1_en     <= 1'b0;
      sram1_we     <= 1'b0;
      sram1_addr   <= {ADDR_W{1'b0}};
      sram1_wdata  <= 64'd0;
      sram1_wmask  <= 8'h00;
    end else begin
      // Default: disable write
      sram1_en    <= 1'b0;
      sram1_we    <= 1'b0;
      sram1_wmask <= 8'h00;

      if (cfg_start_pass) begin
        // Reset counter at the beginning of a sub-kernel pass
        write_cnt <= {ADDR_W{1'b0}};
      end else if (sa_valid) begin
        // Drive SRAM signals
        sram1_en    <= 1'b1;
        sram1_we    <= 1'b1;
        sram1_addr  <= calc_addr;
        sram1_wdata <= sa_wdata;
        sram1_wmask <= 8'hFF; // Write all 8 bytes

        // Advance block counter
        write_cnt <= write_cnt + 1'b1;
      end
    end
  end

endmodule
