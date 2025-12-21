module control_unit #(
    parameter SA_DIM = 8,                    // Size of one dimension of the systolic array
    parameter SA_INPUT_FILL_TIME = 8                 // Number of cycles to wait to fill the systolic array
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

    // Image column loading control
    output reg load_column,
    output wire [15:0] load_column_index,
    input wire done_loading_column_to_sa,

    output reg start_sending_output_to_dram,
    input wire done_sending_output_to_dram,

    output reg systolic_data_valid
  );

  localparam [3:0]
    IDLE               = 4'd0,
    CONFIG             = 4'd1,
    LOAD_DATA_TO_SRAM  = 4'd2,
    LOAD_K_TO_SA       = 4'd3,
    WAIT_LOAD_K_TO_SA  = 4'd4,
    COMPUTE            = 4'd5,
    STORE_OUT          = 4'd6,
    DONE_STATE         = 4'd7;

  reg [3:0] state;

  wire [2:0] total_kernel_parts = (cfg_K > SA_DIM) ? 4 : 1;    // Total number of kernel parts to load (for K > SA_SIZE)
  reg [6:0] sa_input_rows_counter;       // Number of rows processed (max 64)
  reg [6:0] sa_output_rows_counter;      // Number of output rows processed (max 64)
  reg [6:0] sa_cols_counter;             // Number of columns processed (max 64-K+1 = 63)


  wire [6:0] max_columns = (cfg_N - cfg_K + 1);  // Max 64-2+1 = 63
  wire [4:0] right_column_offset = (cfg_K % 2) == 0 ? (cfg_K>>1) : (cfg_K>>1) + 1;
  assign load_column_index = {9'd0, sa_cols_counter} + ((kernel_index % 2 == 0) ? 16'd0 : {11'd0, right_column_offset});

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
      systolic_data_valid <= 1'b0;
      start_sending_output_to_dram <= 1'b0;
      load_kernel <= 1'b0;
      kernel_index <= 2'd0;

      sa_input_rows_counter <= 7'd0;
      sa_output_rows_counter <= 7'd0;
      sa_cols_counter <= 7'd0;

    end
    else
    begin
      start_pass_dl <= 1'b0;
      load_kernel <= 1'b0;
      load_column <= 1'b0;
      systolic_data_valid <= 1'b0;
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
          start_pass_dl <= 1'b1;
          state <= WAIT_LOAD_K_TO_SA;
        end

        WAIT_LOAD_K_TO_SA:
        begin
          // Check immediately for done - removes 1 idle cycle
          if (done_loading_kernel_to_sa)
          begin
            sa_input_rows_counter <= 7'd0;
            sa_output_rows_counter <= 7'd0;
            sa_cols_counter <= 7'd0;
            systolic_data_valid <= 1'b0;
            state <= COMPUTE;
          end
        end

        COMPUTE:
        begin

          // Handle Input data signals
          load_column <= 1'b1;

          if(dl_output_data_valid) begin
            sa_input_rows_counter <= sa_input_rows_counter + 1;
          end

          if (sa_input_rows_counter != 0) begin
              load_column <= 1'b0;
          end

          if (sa_input_rows_counter >= (cfg_N - (cfg_K - current_kernel_height)))
          begin
            sa_input_rows_counter <= 7'd0;
            sa_cols_counter <= sa_cols_counter + 1;
          end

          // Stop loading columns when all columns are done
          if (sa_cols_counter >= max_columns)
          begin
            load_column <= 1'b0;
          end

          // handle systolic data valid signal
          if (sa_input_rows_counter >= (current_kernel_height - 2) && dl_output_data_valid)
          begin
            systolic_data_valid <= 1'b1;
            sa_output_rows_counter <= 7'd0;
          end

          if(systolic_data_valid)
          begin
            sa_output_rows_counter <= sa_output_rows_counter + 1;
          end

          if(sa_output_rows_counter >= (result_size - 1))
          begin
            systolic_data_valid <= 1'b0;
            sa_output_rows_counter <= 7'd0;
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
              state <= STORE_OUT;
            end
          end
        end

        STORE_OUT:
        begin
          start_sending_output_to_dram <= 1'b1;

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


endmodule
