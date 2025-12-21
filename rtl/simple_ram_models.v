`timescale 1ns/1ps

// =============================================================================
// Simple Behavioral Model for SRAM0 (64-bit x 1024 words)
// Replaces: memory_generator_sky130_64_1024_2
// Features: 1RW + 1R port, 1-cycle read latency.
// Matches PDK Macro Interface exactly.
// =============================================================================
module memory_generator_sky130_64_1024_2 #(
    parameter DATA_W = 64,
    parameter ADDR_W = 10
)(
    inout vccd1,
    inout vssd1,
    // Port 0: RW
    input  wire              clk0,
    input  wire              csb0,
    input  wire              web0,
    input  wire [7:0]        wmask0,
    input  wire [ADDR_W-1:0] port0_address, 
    input  wire [DATA_W-1:0] port0_datain,
    output reg  [DATA_W-1:0] port0_dataout,

    // Port 1: R
    input  wire              clk1,
    input  wire              csb1,
    input  wire [ADDR_W-1:0] port1_address,
    output reg  [DATA_W-1:0] port1_dataout
);

    // Memory Array
    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    // Port 0: Read/Write
    always @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin // WRITE
                if (wmask0[0]) mem[port0_address][ 7: 0] <= port0_datain[ 7: 0];
                if (wmask0[1]) mem[port0_address][15: 8] <= port0_datain[ 15: 8];
                if (wmask0[2]) mem[port0_address][23:16] <= port0_datain[ 23:16];
                if (wmask0[3]) mem[port0_address][31:24] <= port0_datain[ 31:24];
                if (wmask0[4]) mem[port0_address][39:32] <= port0_datain[ 39:32];
                if (wmask0[5]) mem[port0_address][47:40] <= port0_datain[ 47:40];
                if (wmask0[6]) mem[port0_address][55:48] <= port0_datain[ 55:48];
                if (wmask0[7]) mem[port0_address][63:56] <= port0_datain[ 63:56];
            end else begin   // READ
                port0_dataout <= mem[port0_address];
            end
        end
    end

    // Port 1: Read Only
    always @(posedge clk1) begin
        if (!csb1) begin
            port1_dataout <= mem[port1_address]; 
        end
    end

endmodule


// =============================================================================
// Simple Behavioral Model for SRAM1 (32-bit x 4096 words) -> Output Memory
// Replaces: memory_generator_sky130_32_4096_1
// Features: 1RW + 1R port, 1-cycle read latency.
// =============================================================================
module memory_generator_sky130_32_4096_1 #(
    parameter DATA_W = 32,
    parameter ADDR_W = 12
)(
    inout vccd1,
    inout vssd1,
    // Port 0: RW
    input  wire              clk0,
    input  wire              csb0,
    input  wire              web0,
    input  wire [3:0]        wmask0,
    input  wire [ADDR_W-1:0] port0_address,
    input  wire [DATA_W-1:0] port0_datain,
    output reg  [DATA_W-1:0] port0_dataout,

    // Port 1: R
    input  wire              clk1,
    input  wire              csb1,
    input  wire [ADDR_W-1:0] port1_address,
    output reg  [DATA_W-1:0] port1_dataout
);

    // Memory Array
    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    // Port 0: Read/Write
    always @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin // WRITE
                if (wmask0[0]) mem[port0_address][ 7: 0] <= port0_datain[ 7: 0];
                if (wmask0[1]) mem[port0_address][15: 8] <= port0_datain[ 15: 8];
                if (wmask0[2]) mem[port0_address][23:16] <= port0_datain[ 23:16];
                if (wmask0[3]) mem[port0_address][31:24] <= port0_datain[ 31:24];
            end else begin   // READ
                port0_dataout <= mem[port0_address];
            end
        end
    end

    // Port 1: Read Only
    always @(posedge clk1) begin
        if (!csb1) begin
            port1_dataout <= mem[port1_address];
        end
    end

endmodule