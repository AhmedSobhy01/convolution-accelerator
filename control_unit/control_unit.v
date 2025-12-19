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

    // Input data stream from DRAM to Data Loader
    output reg  rx_ready, // ready to receive from DRAM
    input  wire rx_valid, // DRAM has valid data

    // Output data stream from SRAM to DRAM
    input wire tx_ready,  // DRAM ready to receive data
    output reg tx_valid,  // valid data to DRAM

    output reg [5:0] dl_cfg_N,
    output reg [3:0] dl_cfg_K,

    output reg start_loading_data_to_sram,
    input wire done_loading_data_to_sram,

    output reg load_kernel,
    output reg [1:0] kernel_index, // Index of the current kernel being loaded (for K > SA_SIZE)
    input wire done_loading_kernel_to_sa,

    output reg load_column,
    output wire [5:0] load_column_index,

    output reg systolic_data_valid,

    output reg start_sending_output_to_dram
  );

  localparam [3:0]
             IDLE               = 4'd0,
             CONFIG             = 4'd1,
             WAIT_MEM           = 4'd2,
             LOAD_DATA_TO_SRAM     = 4'd3,
             WAIT_LOADING_DATA_TO_SRAM = 4'd4,
             LOAD_K_TO_SA       = 4'd7,
             WAIT_LOADING_K_TO_SA = 4'd8,
             COMPUTE            = 4'd9,
             WAIT_MEM_OUT       = 4'd10,
             STORE_OUT          = 4'd11,
             DONE_STATE         = 4'd12;

  reg [3:0] state;

  reg [2:0] total_kernel_parts;    // Total number of kernel parts to load (for K > SA_SIZE)
  reg [7: 0] sa_input_rows_counter;      // Number of rows processed in the systolic array
  reg [7: 0] sa_output_rows_counter;      // Number of rows processed in the systolic array
  reg [7: 0] sa_cols_counter;      // Number of columns processed in the systolic array


  wire [7:0] max_columns =  (cfg_N - cfg_K + 1);
  wire [7:0] right_column_offset =  (cfg_K % 2) == 0 ? (cfg_K>>1) : (cfg_K>>1) + 1;
  assign load_column_index = sa_cols_counter + ((kernel_index % 2 == 0) ? 0  : right_column_offset);

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
        current_kernel_width = (cfg_K % 2) ? ((cfg_K >> 1) + 1) : (cfg_K >> 1);
      end
      else
      begin
        current_kernel_width = (cfg_K >> 1);
      end

      // Height calculation
      if (kernel_index < 2)
      begin
        current_kernel_height = (cfg_K % 2) ? ((cfg_K >> 1) + 1) : (cfg_K >> 1);
      end
      else
      begin
        current_kernel_height = (cfg_K >> 1);
      end
    end
  end

  wire [7:0] result_size = (cfg_N - cfg_K + 1);


  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
      rx_ready <= 1'b0;
      tx_valid <= 1'b0;
      start_loading_data_to_sram <= 1'b0;
      load_column <= 1'b0;
      systolic_data_valid <= 1'b0;
      start_sending_output_to_dram <= 1'b0;
      load_kernel <= 1'b0;
      kernel_index <= 2'd0;

      total_kernel_parts <= 3'd0;
      sa_input_rows_counter <= 8'd0;
      sa_output_rows_counter <= 8'd0;
      sa_cols_counter <= 8'd0;

    end
    else
    begin

      load_column <= 1'b0;
      rx_ready <= 1'b0;
      load_kernel <= 1'b0;
      systolic_data_valid <= 1'b0;
      start_loading_data_to_sram <= 1'b0;
      tx_valid <= 1'b0;
      start_sending_output_to_dram <= 1'b0;


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
          // Check if kernel size is bigger than systolic array size
          if (cfg_K > SA_DIM)
          begin
            total_kernel_parts <= 4;
          end
          else
          begin
            total_kernel_parts <= 3'd1;
          end

          dl_cfg_N <= cfg_N;
          dl_cfg_K <= cfg_K;


          state <= WAIT_MEM;
        end

        WAIT_MEM:
        begin
          rx_ready <= 1'b1;

          if (rx_valid)
          begin
            state <= LOAD_DATA_TO_SRAM;
          end
        end

        LOAD_DATA_TO_SRAM:
        begin
          rx_ready <= 1'b1;
          start_loading_data_to_sram <= 1'b1;

          // QUESTION: do we need to check on rx_valid here?
          if (done_loading_data_to_sram)
          begin
            state <= LOAD_K_TO_SA;
            kernel_index <= 2'd0;
          end
        end

        LOAD_K_TO_SA:
        begin
          load_kernel <= 1'b1;

          if (done_loading_kernel_to_sa)
          begin
            sa_input_rows_counter <= 8'd0;
            sa_output_rows_counter <= 8'd0;
            sa_cols_counter <= 8'd0;
            systolic_data_valid <= 1'b0;
            state <= COMPUTE;
          end
        end

        COMPUTE:
        begin
          // handle systolic data valid signal
          if (sa_input_rows_counter >= SA_INPUT_FILL_TIME)
          begin
            systolic_data_valid <= 1'b1;
            sa_output_rows_counter <= 8'd0;
          end

          if(systolic_data_valid)
          begin
            sa_output_rows_counter <= sa_output_rows_counter + 1;
          end

          if(sa_output_rows_counter >= result_size)
          begin
            systolic_data_valid <= 1'b0;
            sa_output_rows_counter <= 8'd0;
          end


          // Handle Input data signals
          load_column <= 1'b1;
          sa_input_rows_counter <= sa_input_rows_counter + 1;

          if (sa_input_rows_counter >= (cfg_N - (cfg_K - current_kernel_height)))
          begin
            sa_input_rows_counter <= 8'd0;
            sa_cols_counter <= sa_cols_counter + 1;
          end

          // Stop loading columns when all columns are done
          if (sa_cols_counter >= max_columns)
          begin
            load_column <= 1'b0;
          end

          // Exit condition: all columns processed and current column output complete
          if (sa_cols_counter >= max_columns && !systolic_data_valid)
          begin
            if (kernel_index < (total_kernel_parts - 1))
            begin
              kernel_index <= kernel_index + 1;
              state <= LOAD_K_TO_SA;
            end
            else
            begin
              state <= WAIT_MEM_OUT;
            end
          end
        end

        WAIT_MEM_OUT:
        begin
          start_sending_output_to_dram <= 1'b1;
          if (tx_ready)
          begin
            state <= STORE_OUT;
          end
        end

        STORE_OUT:
        begin
          start_sending_output_to_dram <= 1'b1;
          tx_valid <= 1'b1;

          if (!dl_busy)
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


endmodule
