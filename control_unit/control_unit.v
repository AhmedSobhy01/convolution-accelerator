module control_unit #(
    parameter SA_DIM = 8,                    // Size of one dimension of the systolic array
    parameter SA_INPUT_FILL_TIME = 8                 // Number of cycles to wait to fill the systolic array
)(
    input  wire clk,
    input  wire rst_n,

    input  wire start,
    input  wire [5:0] cfg_N,
    input  wire [3:0] cfg_K,
    output wire  done,

    // Data loader is sending data to DRAM (kernel/image)
    input wire dl_busy,

    // Input data stream from DRAM to Data Loader
    output reg  rx_ready, // ready to receive from DRAM
    input  wire rx_valid, // DRAM has valid data

    // Output data stream from SRAM to DRAM
    input wire tx_ready,  // DRAM ready to receive data
    output reg tx_valid,  // valid data to DRAM

    output wire [5:0] dl_cfg_N,
    output wire [3:0] dl_cfg_K,

    output reg start_loading_kernel_to_sram,
    output reg start_loading_image_to_sram,

    output reg load_kernel,
    output reg [1:0] kernel_index, // Index of the current kernel being loaded (for K > SA_SIZE)

    output reg load_column,
    output wire [5:0] load_column_index,

    output reg systolic_data_valid,

    output reg start_sending_output_to_dram
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
        WAIT_MEM_OUT       = 4'd10,
        STORE_OUT          = 4'd11,
        DONE_STATE         = 4'd12;

    reg [3:0] state;

    reg [2:0] total_kernel_parts;    // Total number of kernel parts to load (for K > SA_SIZE)
    reg [7: 0] sa_rows_counter;      // Number of rows processed in the systolic array
    reg [7: 0] sa_cols_counter;      // Number of columns processed in the systolic array


    wire [3:0] max_columns =  (cfg_N - cfg_K + 1);
    wire [3:0] right_column_offset =  (cfg_K % 2) == 0 ? (cfg_K>>1) : (cfg_K>>1) + 1;
    assign load_column_index = sa_cols_counter + ((kernel_index % 2 == 0) ? 0  : right_column_offset);

    wire [3:0] current_kernel_size = (kernel_index == total_kernel_parts - 1) ? (cfg_K - (SA_DIM * (total_kernel_parts - 1))) : SA_DIM;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_ready <= 1'b0;
            tx_valid <= 1'b0;
            start_loading_kernel_to_sram <= 1'b0;
            start_loading_image_to_sram <= 1'b0;
            load_column <= 1'b0;
            systolic_data_valid <= 1'b0;
            start_sending_output_to_dram <= 1'b0;
            load_kernel <= 1'b0;
            kernel_index <= 2'd0;

            total_kernel_parts <= 3'd0;
            sa_rows_counter <= 8'd0;
            sa_cols_counter <= 8'd0;
            
        end else begin
            
            load_kernel <= 1'b0;
            systolic_data_valid <= 1'b0;
            start_loading_image_to_sram <= 1'b0;
            start_loading_kernel_to_sram <= 1'b0;
            tx_valid <= 1'b0;
            start_sending_output_to_dram <= 1'b0;
            

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CONFIG;
                    end
                end

                CONFIG: begin
                    // Check if kernel size is bigger than systolic array size
                    if (cfg_K > SA_DIM) begin
                        total_kernel_parts <= 4;
                    end else begin
                        total_kernel_parts <= 3'd1;
                    end

                    state <= WAIT_MEM;
                end 

                WAIT_MEM: begin
                    rx_ready <= 1'b1;

                    if (rx_valid) begin
                        state <= LOAD_K_TO_SRAM;
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

                    // TODO: This needs to be a computed value and needs to handle K > SA_SIZE condition
                    if (dl_busy) begin
                        state <= WAIT_LOADING_K_TO_SA;
                    end
                end

                WAIT_LOADING_K_TO_SA: begin
                    load_kernel <= 1'b1;
                    sa_rows_counter <= 8'd0;
                    sa_cols_counter <= 8'd0;

                    if (!dl_busy) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    sa_rows_counter <= sa_rows_counter + 1;
                    load_column <= 1'b1;

                    // Wait to fill cycles
                    if (sa_rows_counter >= (SA_INPUT_FILL_TIME-1)) begin
                        systolic_data_valid <= 1'b1;
                    end else begin
                        systolic_data_valid <= 1'b0;
                    end 

                    // If all rows processed, move to next column
                    if (sa_rows_counter == cfg_N) begin
                        sa_cols_counter <= sa_cols_counter + 1;
                    end
                    
                    // If column processed, set sa_data_valid to 0 till loading next column
                    // Update rows counter according to overlapped time between loading and storing
                    if (sa_rows_counter >= SA_INPUT_FILL_TIME + (cfg_N - cfg_K + 1)) begin
                        systolic_data_valid <= 1'b0;
                        sa_rows_counter <= (SA_INPUT_FILL_TIME - cfg_K + 1); 
                    end

                    // If all columns processed, check for more kernel parts and move to loading next kernel part or accumlation
                    // Or move to wait for DRAM
                    if(sa_cols_counter >= max_columns) begin
                        load_column <= 1'b0;
                    end

                    if (sa_cols_counter >= max_columns && (sa_rows_counter >= SA_INPUT_FILL_TIME + (cfg_N - cfg_K + 1))) begin 
                        if (kernel_index < (total_kernel_parts - 1)) begin
                            kernel_index <= kernel_index + 1;
                            state <= LOAD_K_TO_SA;
                        end else begin
                            state <= WAIT_MEM_OUT;
                        end
                    end
                end

                WAIT_MEM_OUT: begin
                    start_sending_output_to_dram <= 1'b1;
                    if (tx_ready && dl_busy) begin
                        state <= STORE_OUT;
                    end
                end

                STORE_OUT: begin
                    start_sending_output_to_dram <= 1'b1;
                    tx_valid <= 1'b1;
                    
                    if (!dl_busy) begin
                        state <= DONE_STATE;
                    end
                    
                end

                DONE_STATE: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end



    assign done = (state == DONE_STATE);


endmodule