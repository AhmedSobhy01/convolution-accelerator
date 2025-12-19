`timescale 1ns/1ps
`define USE_POWER_PINS

module unaligned_memory_reader (
  input  wire         clk,
  input  wire         rst_n,

  // Request interface
  input  wire         req_valid,
  input  wire [9:0]   byte_addr,      // Byte address (up to 1024*8 = 8192)
  input  wire [2:0]   len_bytes,      // 1-8 bytes to read
  output wire         req_ready,
  
  // Response interface
  output reg          resp_valid,
  output reg [63:0]   resp_data,
  input  wire         resp_ready
);

  
  `ifdef USE_POWER_PINS
    supply1 vccd1;
    supply0 vssd1;
  `endif

  // SRAM ports
  reg         p0_en_reg;
  reg [9:0]   p0_addr_reg;
  wire [63:0] p0_rdata;
  
  reg         p1_en_reg;
  reg [9:0]   p1_addr_reg;
  wire [63:0] p1_rdata;

  // FSM states
  localparam IDLE     = 3'd0;
  localparam SETUP    = 3'd1;
  localparam READ     = 3'd2;
  localparam CAPTURE  = 3'd3;
  localparam COMPUTE  = 3'd4;
  localparam RESPOND  = 3'd5;
  
  reg [2:0] state, next_state;
  
  // Internal registers
  reg [9:0]  saved_byte_addr;
  reg [2:0]  saved_len_bytes;
  reg [9:0]  saved_word_addr;
  reg [2:0]  saved_byte_offset;
  reg [63:0] word0, word1;
  
  // Request ready when idle and not waiting for response to be consumed
  assign req_ready = (state == IDLE) && (!resp_valid || resp_ready);
  
  // SRAM instance
  sram0_1rw1r_64x1024_wrapper u_sram (
    .clk(clk),
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),
      .vssd1(vssd1),
    `endif
    
    // Port 0 - Read first word
    .p0_en(p0_en_reg),
    .p0_we(1'b0),
    .p0_addr(p0_addr_reg),
    .p0_wdata(64'd0),
    .p0_wmask(8'd0),
    .p0_rdata(p0_rdata),
    
    // Port 1 - Read second word
    .p1_en(p1_en_reg),
    .p1_addr(p1_addr_reg),
    .p1_rdata(p1_rdata)
  );
  
  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end
  
  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (req_valid && req_ready)
          next_state = SETUP;
      end
      
      SETUP: begin
        next_state = READ;
      end
      
      READ: begin
        next_state = CAPTURE;
      end
      
      CAPTURE: begin
        next_state = COMPUTE;
      end
      
      COMPUTE: begin
        next_state = RESPOND;
      end
      
      RESPOND: begin
        if (resp_ready)
          next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  // Save request parameters and compute address in SETUP
  always @(posedge clk) begin
    if (state == IDLE && req_valid && req_ready) begin
      saved_byte_addr <= byte_addr;
      saved_len_bytes <= len_bytes;
      saved_word_addr <= byte_addr[9:3];       // word address
      saved_byte_offset <= byte_addr[2:0];     // byte offset within word
    end
  end
  
  // SRAM control - assert enables in SETUP state, addresses valid in READ
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p0_en_reg <= 1'b0;
      p1_en_reg <= 1'b0;
      p0_addr_reg <= 10'd0;
      p1_addr_reg <= 10'd0;
    end else begin
      if (state == SETUP) begin
        p0_en_reg <= 1'b1;
        p1_en_reg <= 1'b1;
        p0_addr_reg <= saved_word_addr;
        p1_addr_reg <= saved_word_addr + 10'd1;
      end else if (state == CAPTURE) begin
        p0_en_reg <= 1'b0;
        p1_en_reg <= 1'b0;
      end
    end
  end
  
  // Capture SRAM outputs
  always @(posedge clk) begin
    if (state == CAPTURE) begin
      word0 <= p0_rdata;
      word1 <= p1_rdata;
    end
  end
  
  // Compute result
  reg [127:0] combined;
  reg [63:0] mask;
  reg [7:0] shift_bits;
  
  always @(posedge clk) begin
    if (state == COMPUTE) begin
      // Combine the two words: word1 << 64 | word0
      combined = {word1, word0};
      
      // Calculate shift amount in bits
      shift_bits = {saved_byte_offset, 3'b000};  // multiply by 8
      
      // Calculate mask based on len_bytes (0 means 8 bytes)
      case (saved_len_bytes)
        3'd1: mask = 64'h00000000000000FF;
        3'd2: mask = 64'h000000000000FFFF;
        3'd3: mask = 64'h0000000000FFFFFF;
        3'd4: mask = 64'h00000000FFFFFFFF;
        3'd5: mask = 64'h000000FFFFFFFFFF;
        3'd6: mask = 64'h0000FFFFFFFFFFFF;
        3'd7: mask = 64'h00FFFFFFFFFFFFFF;
        default: mask = 64'hFFFFFFFFFFFFFFFF;  // 8 bytes
      endcase
    end
  end
  
  // Response handling
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      resp_valid <= 1'b0;
      resp_data <= 64'd0;
    end else begin
      if (state == RESPOND && !resp_valid) begin
        resp_valid <= 1'b1;
        // Apply shift and mask
        resp_data <= (combined >> shift_bits) & mask;
      end else if (resp_valid && resp_ready) begin
        resp_valid <= 1'b0;
      end
    end
  end

endmodule