# ==============================================================================
# ModelSim/QuestaSim DO File for Simple Convolution Accelerator Test
# ==============================================================================

# 1. Compilation
# ------------------------------------------------------------------------------
vlib work
vmap work work

# Compile control unit
vlog -work work control_unit/control_unit.v

# Compile data loader modules
vlog -work work data-loader-agu/src/dl_dma_rx.v
vlog -work work data-loader-agu/src/byte_window_streamer.v
vlog -work work data-loader-agu/src/kernel_window_streamer.v
vlog -work work data-loader-agu/src/dl_sa_writeback.v
vlog -work work data-loader-agu/src/dl_drain_stream.v
vlog -work work data-loader-agu/src/simple_ram_models.v

# Compile SRAM wrappers
vlog -work work data-loader-agu/src/sram0_wrapper.v
vlog -work work data-loader-agu/src/sram1_wrapper.v

# Compile systolic array modules
vlog -work work rtl/pe.v
vlog -work work rtl/systolic_array.v

# Compile top level
vlog -work work conv_accelerator_top.v

# Compile testbench
vlog -work work tb/tb_conv_accel_simple.v

# 2. Start Simulation
# ------------------------------------------------------------------------------
vsim -voptargs=+acc work.tb_conv_accel_simple

# ------------------------------------------------------------------------------
# Add Waves
# ------------------------------------------------------------------------------
add wave -noupdate -divider "CLOCK & RESET"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/clk
add wave -noupdate -color "Red"    /tb_conv_accel_simple/rst_n

add wave -noupdate -divider "CONTROL"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/start
add wave -noupdate -color "Green"   /tb_conv_accel_simple/done
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/cfg_N
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/cfg_K

add wave -noupdate -divider "DRAM RX (Input)"
add wave -noupdate -color "Cyan"   -radix hex /tb_conv_accel_simple/rx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/rx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/rx_ready

add wave -noupdate -divider "DRAM TX (Output)"
add wave -noupdate -color "Cyan"   -radix hex /tb_conv_accel_simple/tx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/tx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/tx_ready

add wave -noupdate -divider "CONTROL UNIT STATE"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_control/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_input_rows_counter
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_output_rows_counter
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_cols_counter
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/kernel_index
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_control/systolic_data_valid

add wave -noupdate -divider "CONTROL UNIT SIGNALS"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_start_load
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_load_done
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_load_kernel
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_kernel_done
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_load_column
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/cu_column_idx
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_start_drain
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_drain_done

add wave -noupdate -divider "DMA LOADER"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_dma/done
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_dma/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/byte_ptr
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/dma_sram_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/dma_sram_addr

add wave -noupdate -divider "STREAMER"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_streamer/state
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/w_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/w_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/p_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/p_data

add wave -noupdate -divider "SYSTOLIC ARRAY"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_systolic_array/clk
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/u_systolic_array/rst
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_systolic_array/load_kernel_signal
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/input_in
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/kernel_in
add wave -noupdate -color "Green" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/out_data
add wave -noupdate -color "Yellow" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/sum_partials

add wave -noupdate -divider "SYSTOLIC ARRAY INTERNAL"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/sa_result
add wave -noupdate -color "Orange" -radix binary /tb_conv_accel_simple/dut/sa_valid_pipe
add wave -noupdate -color "White" /tb_conv_accel_simple/dut/sa_accept_intput

add wave -noupdate -divider "SYSTOLIC ARRAY PE ROW 0"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][0]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][1]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][2]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][3]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][4]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][5]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][6]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[0][7]

add wave -noupdate -divider "SYSTOLIC ARRAY PE ROW 1"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][0]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][1]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][2]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][3]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][4]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][5]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][6]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[1][7]

add wave -noupdate -divider "SYSTOLIC ARRAY PE ROW 2"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][0]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][1]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][2]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][3]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][4]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][5]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][6]
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/pe_out_partials[2][7]

add wave -noupdate -divider "Systolic Weights"
add wave -noupdate -color "Yellow" -label "PE[0][0] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[0]/pe_00/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][1] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[1]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][2] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[2]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][3] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[3]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][4] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[4]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][5] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[5]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][6] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[6]/col[0]/pe_left_col/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][7] Weight" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[7]/col[0]/pe_left_col/pe_inst/left_reg

add wave -noupdate -divider "Systolic Inputs"
add wave -noupdate -color "Yellow" -label "PE[0][0] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[0]/pe_00/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][1] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[1]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][2] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[2]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][3] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[3]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][4] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[4]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][5] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[5]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][6] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[6]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Yellow" -label "PE[0][7] Inputs" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[7]/pe_top_row/pe_inst/top_reg

add wave -noupdate -divider "Systolic InTop"
add wave -noupdate -color "Yellow" -label "PE[0][0] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[0]/pe_00/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][1] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[1]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][2] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[2]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][3] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[3]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][4] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[4]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][5] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[5]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][6] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[6]/pe_top_row/pe_inst/in_top
add wave -noupdate -color "Yellow" -label "PE[0][7] in_top" -radix unsigned /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[7]/pe_top_row/pe_inst/in_top

add wave -noupdate -divider "WRITEBACK"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sa_out_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sa_out_data
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sa_wb_busy
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_addr

add wave -noupdate -divider "DRAIN"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_drain/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_drain/pixel_cnt
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p1_addr

add wave -noupdate -divider "CONTROL UNIT DETAILED"
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/cfg_N
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/cfg_K
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/dl_cfg_N
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/dl_cfg_K
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/total_kernel_parts
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/max_columns
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/right_column_offset
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/current_kernel_width
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/current_kernel_height
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/result_size
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/load_column_index

add wave -noupdate -divider "DMA DETAILED"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/cfg_N
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/cfg_K
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/img_bytes_total
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/ker_bytes_total
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/rx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/rx_ready
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/rx_data
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/img_written
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/sram0_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/sram0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/sram0_wmask

add wave -noupdate -divider "UNALIGNED READER"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_reader/req_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_reader/req_ready
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_reader/byte_addr
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_reader/len_bytes
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_reader/resp_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_reader/resp_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_reader/sram_p0_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_reader/sram_p0_addr
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_reader/sram_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_reader/sram_p1_addr

add wave -noupdate -divider "STREAMER DETAILED"
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/cfg_N
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/cfg_K
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_streamer/start_load_kernel
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_streamer/kernel_done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/kernel_idx
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_streamer/start_stream_window
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_streamer/window_done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/col_cnt
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/row_cnt
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_req_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_req_ready
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_streamer/reader_byte_addr
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_resp_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_streamer/reader_resp_data

add wave -noupdate -divider "WRITEBACK DETAILED"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_writeback/cfg_start_pass
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_writeback/cfg_ker_idx
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sa_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sa_wdata
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/u_writeback/busy
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sram_en
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sram_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_wmask

add wave -noupdate -divider "DRAIN DETAILED"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_drain/start
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_drain/done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_drain/cfg_num_pixels
add wave -noupdate -color "White" /tb_conv_accel_simple/dut/u_drain/cfg_split_mode
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_drain/sram_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_drain/sram_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_drain/sram_rdata
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_drain/tx_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_drain/tx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_drain/tx_ready

add wave -noupdate -divider "SRAM0 PORT 0 (DMA/Reader)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram0_p0_en
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sram0_p0_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_wmask
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram0_p0_rdata

add wave -noupdate -divider "SRAM0 PORT 1 (Reader)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram0_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p1_addr
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram0_p1_rdata

add wave -noupdate -divider "SRAM1 PORT 0 (Writeback)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p0_en
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sram1_p0_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_wmask

add wave -noupdate -divider "SRAM1 PORT 1 (Drain)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p1_addr
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram1_p1_rdata

add wave -noupdate -divider "SYSTOLIC ARRAY INTERFACE"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/w_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/w_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/p_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/p_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sa_out_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sa_out_data
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sa_wb_busy

add wave -noupdate -divider "ARBITRATION"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/dma_active

# 3. View Configuration
# ------------------------------------------------------------------------------
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# 4. Run
# ------------------------------------------------------------------------------
run -all

# 5. Zoom
# ------------------------------------------------------------------------------
wave zoom full
