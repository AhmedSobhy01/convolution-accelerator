module control_unit #(
    parameter SA_DIM = 8,                    // Size of one dimension of the systolic array
    parameter SA_INPUT_FILL_TIME = 2*8                 // Number of cycles to wait to fill the systolic array
  )(
    input  wire clk,
    input  wire rst_n,

    input  wire start,
    input  wire [6:0] cfg_N,
    input  wire [4:0] cfg_K,
    output wire  done,

    output reg [6:0] dl_cfg_N,
    output reg [4:0] dl_cfg_K,

    output wire start_loading_data_to_sram,
    input wire done_loading_data_to_sram,

    output reg start_pass_dl,

    output reg load_kernel,
    output reg [1:0] kernel_index, // Index of the current kernel being loaded (for K > SA_SIZE)
    input wire done_loading_kernel_to_sa,
    input wire dl_output_data_valid,

    output reg [15:0] start_column_index,
    output reg [15:0] end_column_index,

    // Image column loading control
    output reg load_column,
    output wire [15:0] load_column_index,
    input wire done_loading_column_to_sa,

    output reg start_sending_output_to_dram,
    input wire done_sending_output_to_dram,
  
    output wire systolic_data_valid,
    
    output reg insert_nop_to_systolic
  );

  localparam [3:0]
    IDLE               = 4'd0,
    CONFIG             = 4'd1,
    LOAD_DATA_TO_SRAM  = 4'd2,
    LOAD_K_TO_SA       = 4'd3,
    WAIT_LOAD_K_TO_SA  = 4'd4,
    ADJUST_KERNEL_POS  = 4'd5,
    WAIT_FOR_STREAMER_READY = 4'd10,
    WAIT_FILL_SA       = 4'd11,
    COMPUTE            = 4'd6,
    STORE_OUT          = 4'd7,
    WAIT_STORE_OUT     = 4'd8,
    DONE_STATE         = 4'd9;
  reg [3:0] state;

  reg [7:0] counter;

  wire [2:0] total_kernel_parts = (cfg_K > SA_DIM) ? 4 : 1;    // Total number of kernel parts to load (for K > SA_SIZE)
  reg [7: 0] sa_input_rows_counter;      // Number of rows processed in the systolic array
  reg [15: 0] sa_cols_counter;      // Number of columns processed in the systolic array
  
  reg [6:0] padding_rows_counter;

  wire [15:0] max_columns =  (cfg_N - cfg_K + 1);
  wire [15:0] right_column_offset =  (cfg_K % 2) == 0 ? (cfg_K>>1) : (cfg_K>>1) + 1;
  assign load_column_index = sa_cols_counter + ((kernel_index % 2 == 0) ? 0  : right_column_offset);


  // wire [15:0] start_column_index = (kernel_index < 2) ? 0 : right_column_offset;
  // wire [15:0] end_column_index = start_column_index + (cfg_N - cfg_K);

  always @(*) begin
    if(kernel_index % 2 == 0) begin
      start_column_index = 0;
      end_column_index = (cfg_N - cfg_K+1);
    end else begin
      start_column_index = (dl_cfg_K % 2) == 0 ? (dl_cfg_K>>1) : ((dl_cfg_K>>1) + 1);
      end_column_index = start_column_index + (cfg_N - cfg_K);
    end
  end

  // Kernal is split into halfs if K > SA_SIZE
  reg [3:0] current_kernel_width;
  reg [3:0] current_kernel_height;

  always @(*)
  begin
    if (cfg_K <= SA_DIM)
    begin
      current_kernel_width = cfg_K;
      current_kernel_height = cfg_K;
    end
    else
    begin
      // Width calculation
      if (kernel_index % 2 == 0)
      begin
        current_kernel_width = (cfg_K >> 1);
      end
      else
      begin
        current_kernel_width = (cfg_K % 2) ? ((cfg_K >> 1) + 1) : (cfg_K >> 1);
      end

      // Height calculation
      if (kernel_index < 2)
      begin
        current_kernel_height = (cfg_K >> 1);
      end
      else
      begin
        current_kernel_height = (cfg_K % 2) ? ((cfg_K >> 1) + 1) : (cfg_K >> 1);
      end
    end
  end

  wire [7:0] result_size = (cfg_N - cfg_K + 1);


  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
      load_column <= 1'b0;
      start_sending_output_to_dram <= 1'b0;
      load_kernel <= 1'b0;
      kernel_index <= 2'd0;

      sa_input_rows_counter <= 8'd0;
      sa_cols_counter <= 8'd0;

    end
    else
    begin
      start_pass_dl <= 1'b0;
      load_kernel <= 1'b0;
      load_column <= 1'b0;
      start_sending_output_to_dram <= 1'b0;
      insert_nop_to_systolic <= 1'b0;
      


      case (state)
        IDLE:
        begin
          if (start)
          begin
            state <= CONFIG;
          end
        end

        CONFIG:
        begin
          dl_cfg_N <= cfg_N;
          dl_cfg_K <= cfg_K;

          state <= LOAD_DATA_TO_SRAM;
        end

        LOAD_DATA_TO_SRAM:
        begin
          if (done_loading_data_to_sram)
          begin
            state <= LOAD_K_TO_SA;
            kernel_index <= 2'd0;
          end
        end

        LOAD_K_TO_SA:
        begin
          load_kernel <= 1'b1;
          start_pass_dl <= 1;

          state <= WAIT_LOAD_K_TO_SA;
        end

        WAIT_LOAD_K_TO_SA:
        begin
          load_kernel <= 1'b0;
          start_pass_dl <= 0;

          if (done_loading_kernel_to_sa)
          begin
            sa_input_rows_counter <= 8'd0;
            sa_cols_counter <= 8'd0;


            padding_rows_counter <= 7'd0;
            state <= ADJUST_KERNEL_POS;
          end
        end

        ADJUST_KERNEL_POS:
        begin
          // Not used in current design
          insert_nop_to_systolic <= 1'b1;

          padding_rows_counter <= padding_rows_counter + 1;

          if (padding_rows_counter + 2 >= ( SA_DIM - current_kernel_height))
          begin
            state <= WAIT_FOR_STREAMER_READY;
          end


        end
        WAIT_FOR_STREAMER_READY:
        begin
          load_column <= 1'b1;

          if (dl_output_data_valid)
          begin
            sa_cols_counter <= 8'd0;
            counter <= 8'd0;
            state <= WAIT_FILL_SA;
          end
        end
        WAIT_FILL_SA:
        begin
          // Wait for k cycles to fill the systolic array
          if (counter <= SA_INPUT_FILL_TIME+3) begin
            counter <= counter + 1;
          end else begin
            counter <= 8'd0;
            sa_cols_counter <= 8'd0;
            state <= COMPUTE;
          end
        end
        COMPUTE:
        begin
          load_column <= 1'b0;

          if (counter < (result_size + current_kernel_height-2)) begin
            counter <= counter + 1;
          end else begin
            counter <= 8'd0;
            sa_cols_counter <= sa_cols_counter + 1;
            // state <= COMPUTE;
          end

          if (sa_cols_counter >= max_columns && !systolic_data_valid) begin
            if (kernel_index < (total_kernel_parts - 1))
            begin
              kernel_index <= kernel_index + 1;
              state <= LOAD_K_TO_SA;
            end
            else
            begin
              state <= STORE_OUT;
            end

          end

          // Handle Output data signal
          // if (sa_output_rows_counter >= (SA_INPUT_FILL_TIME-1)) begin
          //   systolic_data_valid <= 1'b1;
          // end

          // if (sa_output_rows_counter < result_size + SA_INPUT_FILL_TIME) begin
          //   sa_output_rows_counter <= sa_output_rows_counter + 1;
          // end else begin
          //   systolic_data_valid <= 1'b0;
          //   sa_output_rows_counter <= 8'd0;
          // end

          // // Handle Input data signals
          // load_column <= 1'b1;       

          // if(dl_output_data_valid) begin
          //   sa_input_rows_counter <= sa_input_rows_counter + 1; 
          // end

          // if (sa_input_rows_counter != 0) begin
          //     // load_column <= 1'b0;
          // end

          // if (sa_input_rows_counter >= (cfg_N - (cfg_K - current_kernel_height)))
          // begin
          //   sa_input_rows_counter <= 8'd0;
          //   sa_cols_counter <= sa_cols_counter + 1;
          // end

          // // Stop loading columns when all columns are done
          // if (sa_cols_counter >= max_columns)
          // begin
          //   load_column <= 1'b0;
          // end

          // // handle systolic data valid signal
          // if (sa_input_rows_counter >= (2 * SA_DIM - 1) && dl_output_data_valid)
          // begin
          //   systolic_data_valid <= 1'b1;
          //   sa_output_rows_counter <= 8'd0;
          // end

          // if(systolic_data_valid)
          // begin
          //   sa_output_rows_counter <= sa_output_rows_counter + 1;
          // end

          // if(sa_output_rows_counter >= (result_size - 1))
          // begin
          //   systolic_data_valid <= 1'b0;
          //   sa_output_rows_counter <= 8'd0;
          // end

          // // Exit condition: all columns processed and current column output complete
          // if (sa_cols_counter >= max_columns && !systolic_data_valid)
          // begin
          //   if (kernel_index < (total_kernel_parts - 1))
          //   begin
          //     kernel_index <= kernel_index + 1;
          //     state <= LOAD_K_TO_SA;
          //   end
          //   else
          //   begin
          //     state <= STORE_OUT;
          //   end
          // end
        end

        STORE_OUT:
        begin
          start_sending_output_to_dram <= 1'b1;

          state <= WAIT_STORE_OUT;
        end
        WAIT_STORE_OUT:
        begin
          start_sending_output_to_dram <= 1'b0;

          if (done_sending_output_to_dram)
          begin
            state <= DONE_STATE;
          end
        end

        DONE_STATE:
        begin
          state <= IDLE;
        end

        default:
          state <= IDLE;
      endcase
    end
  end


  assign done = (state == DONE_STATE);
  assign start_loading_data_to_sram = (state == LOAD_DATA_TO_SRAM);
  assign systolic_data_valid = (state == COMPUTE) ? (counter >= (current_kernel_height-1)) : 1'b0;


endmodule
