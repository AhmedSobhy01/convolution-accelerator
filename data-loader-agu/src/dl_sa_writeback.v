`timescale 1ns/1ps

module dl_sa_writeback #(
  parameter ADDR_W = 12 // SRAM Depth 4096 Words
)(
  input  wire         clk,
  input  wire         rst_n,

  // Config from Control Unit
  input  wire         cfg_start_pass, // Pulse: Resets counter to cfg_ker_idx
  input  wire [1:0]   cfg_ker_idx,    // Sets the initial offset (0, 1, 2, or 3)

  // From Systolic Array (1 Byte per Valid)
  input  wire         sa_valid,
  input  wire [7:0]   sa_wdata,       // UPDATED: Just 8 bits
  output wire         busy,           // FIFO Full

  // To SRAM1 Wrapper (Port 0 - Write)
  output reg          sram_en,
  output reg          sram_we,
  output reg [ADDR_W-1:0] sram_addr,      
  output reg [31:0]   sram_wdata,
  output reg [3:0]    sram_wmask
);

  // ===========================================================================
  // 1. Internal FIFO (8-bit width)
  // ===========================================================================
  localparam FIFO_DEPTH = 8;
  localparam PTR_W      = 3; // log2(8)

  reg [7:0]       mem [0:FIFO_DEPTH-1];
  reg [PTR_W-1:0] wptr;
  reg [PTR_W-1:0] rptr;
  reg [PTR_W:0]   cnt;

  wire fifo_full  = (cnt[PTR_W]); 
  wire fifo_empty = (cnt == 0);
  
  assign busy = fifo_full;

  wire push = sa_valid && !fifo_full;
  reg  pop; 

  // FIFO Write Side
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr <= 0;
      cnt  <= 0;
    end else begin
      if (cfg_start_pass) begin
        wptr <= 0;
        cnt  <= 0;
      end else begin
        if (push) begin
          mem[wptr] <= sa_wdata;
          wptr <= wptr + 1'b1;
        end
        
        if (push && !pop)      cnt <= cnt + 1'b1;
        else if (!push && pop && !fifo_empty) cnt <= cnt - 1'b1;
      end
    end
  end

  // FIFO Read Side
  wire [7:0] fifo_rdata = mem[rptr];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rptr <= 0;
    else if (cfg_start_pass) rptr <= 0;
    else if (pop && !fifo_empty) rptr <= rptr + 1'b1;
  end

  // ===========================================================================
  // 2. Strided Address Logic
  // Logic: 
  //   On cfg_start_pass: byte_ptr = cfg_ker_idx
  //   On Write:          byte_ptr = byte_ptr + 4
  // ===========================================================================
  
  // We need extra bits for byte addressing. 
  // ADDR_W is Word Address width. Byte Address width is ADDR_W + 2.
  reg [ADDR_W-1:0] byte_ptr; 

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_ptr   <= 0;
      pop        <= 0;
      
      sram_en    <= 0;
      sram_we    <= 0;
      sram_addr  <= 0;
      sram_wdata <= 0;
      sram_wmask <= 0;
    end else begin
      // Default
      pop <= 0;
      
      if (cfg_start_pass) begin
        // Reset Logic: Initialize to the Kernel Index
        byte_ptr <= { {(ADDR_W){1'b0}}, cfg_ker_idx }; 
        sram_en  <= 0;
        sram_we  <= 0;
      end else begin
        if (!fifo_empty) begin
          // Processing
          pop <= 1'b1;
          
          // SRAM Control
          sram_en    <= 1'b1;
          sram_we    <= 1'b1;
          
          // Address Derivation:
          // Word Address = byte_ptr >> 2 (Upper bits)
          sram_addr  <= byte_ptr;

          // Mask Derivation:
          // Byte Lane = byte_ptr % 4 (Lower 2 bits)
          sram_wmask <= (4'b0001 << byte_ptr[1:0]);
          
          // Data: Broadcast 8-bit value to all lanes (mask selects valid one)
          sram_wdata <= {4{fifo_rdata}};
          
          // Update Counter: Stride by 4
          byte_ptr   <= byte_ptr + 3'd4;
          
        end else begin
          // Idle
          sram_en <= 1'b0;
          sram_we <= 1'b0;
        end
      end
    end
  end

endmodule