module control_unit #(
    parameter CYCLES_PER_KERNEL_LOAD = 16, // From DRAM to SRAM
    parameter FILL_CYCLES = 16,             // Number of cycles to fill the systolic array
    parameter SA_DIM = 8                    // Size of one dimension of the systolic array
)(
    input  wire clk,
    input  wire rst_n,

    input  wire start,
    input  wire [5:0] cfg_N,
    input  wire [3:0] cfg_K,
    output reg  done,

    // Input data stream from DRAM to Data Loader
    output reg  rx_ready, // ready to receive from DRAM
    input  wire rx_valid, // DRAM has valid data

    // Output data stream from Systolic Array to DRAM
    input wire tx_ready,  // DRAM ready to receive data

    output wire [5:0] dl_cfg_N,
    output wire [3:0] dl_cfg_K,

    output reg start_loading_kernel_to_sram,
    output reg start_loading_image_to_sram,

    output reg load_kernel,
    output reg [1:0] kernel_index, // Index of the current kernel being loaded (for K > SA_SIZE)

    output reg load_column,
    output reg [5:0] load_column_index,

    output reg systolic_data_valid,

    output reg start_accumlation
);

    assign dl_cfg_N = cfg_N;
    assign dl_cfg_K = cfg_K;

    localparam [3:0] 
        IDLE               = 4'd0,
        CONFIG             = 4'd1,
        WAIT_MEM           = 4'd2,
        LOAD_K_TO_SRAM     = 4'd3,
        LOAD_I_TO_SRAM     = 4'd4,
        LOAD_K_TO_SA       = 4'd5,
        COMPUTE            = 4'd6,
        ACCUMULATE_OUTPUT  = 4'd8,
        WAIT_MEM_OUT       = 4'd9,
        STORE_OUT          = 4'd10,
        DONE_STATE         = 4'd11;

    reg [3:0] state;

    integer counter;
    
    reg [1:0] kernel_index = 2'd0;
    reg kernel_bigger_than_sa;       // Flag to indicate if K > SA_SIZE
    reg [2:0] total_kernel_parts;    // Total number of kernel parts to load (for K > SA_SIZE)
    reg [1: 0] tiles_per_dim;        // Number of tiles per dimension when K > SA_SIZE (K / SA_DIM)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            rx_ready <= 1'b0;
            start_loading_kernel_to_sram <= 1'b0;
            start_loading_image_to_sram <= 1'b0;
            load_column <= 1'b0;
            load_column_index <= 6'd0;
            systolic_data_valid <= 1'b0;
            start_accumlation <= 1'b0;
            load_kernel <= 1'b0;
            kernel_index <= 2'd0;
            kernel_bigger_than_sa <= 1'b0;

        end else begin
            
            load_kernel <= 1'b0;
            systolic_data_valid <= 1'b0;
            start_loading_image_to_sram <= 1'b0;
            start_loading_kernel_to_sram <= 1'b0;
            start_accumlation <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CONFIG;
                    end
                end

                CONFIG: begin
                    // Check if kernel size is bigger than systolic array size
                    kernel_bigger_than_sa <= (cfg_K > SA_DIM) ? 1'b1 : 1'b0;
                    
                    if (cfg_K > SA_DIM) begin
                        tiles_per_dim <= (cfg_K + SA_DIM - 1) / SA_DIM; // Ceiling division
                        total_kernel_parts <= tiles_per_dim * tiles_per_dim; // Ceiling division
                    end else begin
                        total_kernel_parts <= 3'd1;
                    end

                    state <= WAIT_MEM;
                end 

                WAIT_MEM: begin
                    rx_ready <= 1'b1;
                    if (rx_valid) begin
                        start_loading_kernel_to_sram <= 1'b1;
                        state <= LOAD_K_TO_SRAM;
                        counter <= 0;
                    end
                end  

                LOAD_K_TO_SRAM: begin
                    

                end

                LOAD_K_TO_SA: begin
                    load_kernel <= 1'b1;
                    kernel_index <= 2'd0;

                    if (counter > CYCLES_PER_KERNEL_LOAD) begin
                        state <= COMPUTE;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                COMPUTE: begin
                    systolic_data_valid <= 1'b1;

                    // if (counter > (cfg_N * cfg_K)) begin
                    //     systolic_data_valid <= 1'b0;
                    //     counter <= 0;
                    // end else begin
                    //     counter <= counter + 1;
                    // end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule