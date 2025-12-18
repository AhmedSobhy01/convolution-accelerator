module control_unit #(
    parameter CYCLES_PER_KERNEL_LOAD = 16,  // From DRAM to SRAM
    parameter FILL_CYCLES = 16,             // Number of cycles to fill the systolic array
    parameter SA_DIM = 8                    // Size of one dimension of the systolic array
)(
    input  wire clk,
    input  wire rst_n,

    input  wire start,
    input  wire [5:0] cfg_N,
    input  wire [3:0] cfg_K,
    output reg  done,

    // Data loader is sending data to DRAM (kernel/image)
    input wire dl_busy,

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
        WAIT_LOADING_KERNEL_TO_SRAM = 4'd4,
        LOAD_I_TO_SRAM     = 4'd5,
        WAIT_LOADING_IMAGE_TO_SRAM = 4'd6,
        LOAD_K_TO_SA       = 4'd7,
        WAIT_LOADING_K_TO_SA = 4'd8,
        COMPUTE            = 4'd9,
        ACCUMULATE_OUTPUT  = 4'd10,
        WAIT_MEM_OUT       = 4'd11,
        STORE_OUT          = 4'd12,
        DONE_STATE         = 4'd13;

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
                        state <= LOAD_K_TO_SRAM;
                        counter <= 0;
                    end
                end

                LOAD_K_TO_SRAM: begin
                    rx_ready <= 1'b1;
                    start_loading_kernel_to_sram <= 1'b1;

                    // QUESTION: do we need to check on rx_valid here?                
                    if (dl_busy) begin
                        state <= WAIT_LOADING_KERNEL_TO_SRAM;
                    end
                end
                
                WAIT_LOADING_KERNEL_TO_SRAM: begin
                    rx_ready <= 1'b1;
                    start_loading_kernel_to_sram <= 1'b1;

                    if (!dl_busy) begin
                        state <= LOAD_I_TO_SRAM;
                    end
                end

                LOAD_I_TO_SRAM: begin
                    rx_ready <= 1'b1;
                    start_loading_image_to_sram <= 1'b1;

                    // QUESTION: do we need to check on rx_valid here?
                    if (dl_busy) begin
                        state <= WAIT_LOADING_IMAGE_TO_SRAM;
                    end
                end

                WAIT_LOADING_IMAGE_TO_SRAM: begin
                    rx_ready <= 1'b1;
                    start_loading_image_to_sram <= 1'b1;

                    if (!dl_busy) begin
                        state <= LOAD_K_TO_SA;
                    end
                end

                LOAD_K_TO_SA: begin
                    load_kernel <= 1'b1;
                    kernel_index <= 2'd0;
                    // kernel parts -> number of indices


                    // TODO: This needs to be a computed value and needs to handle K > SA_SIZE condition
                    if (dl_busy) begin
                        state <= WAIT_LOADING_K_TO_SA;
                    end
                end

                WAIT_LOADING_K_TO_SA: begin
                    load_kernel <= 1'b1;

                    if (!dl_busy) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    systolic_data_valid <= 1'b1;

                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule