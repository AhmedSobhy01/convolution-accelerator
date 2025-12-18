`timescale 1ns/1ps

module dl_sa_writeback (
  input  wire         clk,
  input  wire         rst_n,

  // Config from Control Unit
  input  wire         cfg_start_pass, // Pulse: Reset pixel counter at start of pass
  input  wire [1:0]   cfg_ker_idx,    // 0..3: Selects which byte lane to write

  // From Systolic Array (8 pixels valid at once)
  input  wire         sa_valid,
  input  wire [63:0]  sa_wdata,
  output reg          busy,           // High while serializing writes

  // To SRAM1 Wrapper (Port 0 - Write)
  output reg          sram_en,
  output reg          sram_we,
  output reg [11:0]   sram_addr,      // 4096 words
  output reg [31:0]   sram_wdata,
  output reg [3:0]    sram_wmask
);

  // FSM States
  localparam ST_IDLE  = 1'b0;
  localparam ST_WRITE = 1'b1;
  reg state;

  // Internal storage
  reg [63:0] data_buf;    // Buffer for the 8 pixels
  reg [2:0]  pixel_idx;   // 0..7 counter for serialization
  reg [11:0] base_addr;   // Tracks current image pixel offset (0, 8, 16...)

  // Byte Mask Decoder (1 << ker_idx)
  // idx 0 -> 0001, idx 1 -> 0010, etc.
  wire [3:0] byte_mask = (4'b0001 << cfg_ker_idx);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      base_addr   <= 12'd0;
      data_buf    <= 64'd0;
      pixel_idx   <= 3'd0;
      busy        <= 1'b0;
      
      // SRAM Outputs
      sram_en     <= 1'b0;
      sram_we     <= 1'b0;
      sram_addr   <= 12'd0;
      sram_wdata  <= 32'd0;
      sram_wmask  <= 4'd0;
    end else begin
      // Default controls
      sram_en <= 1'b0;
      sram_we <= 1'b0;

      // Reset base address at start of a kernel pass
      if (cfg_start_pass) begin
        base_addr <= 12'd0;
        state     <= ST_IDLE;
        busy      <= 1'b0;
      end else begin
        
        case (state)
          ST_IDLE: begin
            pixel_idx <= 3'd0;
            if (sa_valid) begin
              data_buf <= sa_wdata;
              busy     <= 1'b1;
              state    <= ST_WRITE;
            end else begin
              busy     <= 1'b0;
            end
          end

          ST_WRITE: begin
            // Drive SRAM Write for current pixel
            sram_en     <= 1'b1;
            sram_we     <= 1'b1;
            sram_wmask  <= byte_mask;
            sram_addr   <= base_addr + {9'd0, pixel_idx};
            
            // Extract the specific byte for the current pixel_idx
            // and replicate it 4 times (mask selects the correct lane)
            // Pixel 0 is bits [7:0], Pixel 1 is [15:8]...
            case (pixel_idx)
              3'd0: sram_wdata <= {4{data_buf[ 7: 0]}};
              3'd1: sram_wdata <= {4{data_buf[15: 8]}};
              3'd2: sram_wdata <= {4{data_buf[23:16]}};
              3'd3: sram_wdata <= {4{data_buf[31:24]}};
              3'd4: sram_wdata <= {4{data_buf[39:32]}};
              3'd5: sram_wdata <= {4{data_buf[47:40]}};
              3'd6: sram_wdata <= {4{data_buf[55:48]}};
              3'd7: sram_wdata <= {4{data_buf[63:56]}};
            endcase

            // Loop logic
            if (pixel_idx == 3'd7) begin
              base_addr <= base_addr + 12'd8; // Advance base for next batch
              state     <= ST_IDLE;
              // busy remains high this cycle, goes low next cycle in IDLE
            end else begin
              pixel_idx <= pixel_idx + 3'd1;
            end
          end
        endcase
      end
    end
  end

endmodule