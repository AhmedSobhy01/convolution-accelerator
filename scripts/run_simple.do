# ==============================================================================
# ModelSim/QuestaSim DO File for Simple Convolution Accelerator Test
# ==============================================================================
# Description: Comprehensive simulation script for testing the convolution
#              accelerator with full waveform capture and hierarchical view
# ==============================================================================

# ==============================================================================
# 1. COMPILATION
# ==============================================================================
vlib work
vmap work work

echo "Compiling Control Unit..."
vlog -work work control_unit/control_unit.v
vlog -work work data-loader-agu/Python_scripts/macro_files/V_BB/sky130_sram_2kbyte_1rw1r_32x512_8.v
vlog -work work data-loader-agu/Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v
vlog -work work data-loader-agu/Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_8x1024_8.v
vlog -work work data-loader-agu/designs/SRAM_64_1024_2_grid/src/memory_generator_sky130_64_1024_2.v
vlog -work work data-loader-agu/designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v

echo "Compiling Data Loader & AGU Modules..."
vlog -work work data-loader-agu/src/dl_dma_rx.v
vlog -work work data-loader-agu/src/byte_window_streamer.v
vlog -work work data-loader-agu/src/kernel_window_streamer.v
vlog -work work data-loader-agu/src/dl_sa_writeback.v
vlog -work work data-loader-agu/src/dl_drain_stream.v

echo "Compiling SRAM Wrappers..."
vlog -work work data-loader-agu/src/sram0_wrapper.v
vlog -work work data-loader-agu/src/sram1_wrapper.v

echo "Compiling Systolic Array..."
vlog -work work rtl/pe.v
vlog -work work rtl/systolic_array.v

echo "Compiling Top Level..."
vlog -work work conv_accelerator_top.v

echo "Compiling Testbench..."
vlog -work work tb/tb_conv_accel_simple.v

# ==============================================================================
# 2. START SIMULATION
# ==============================================================================
echo "Starting Simulation..."
vsim -voptargs=+acc work.tb_conv_accel_simple

# ==============================================================================
# 3. ADD WAVEFORMS
# ==============================================================================

# ------------------------------------------------------------------------------
# 3.1 TOP-LEVEL SIGNALS (Testbench Interface)
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ CLOCK & RESET ═══════════════════"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/clk
add wave -noupdate -color "Red"    /tb_conv_accel_simple/rst_n

add wave -noupdate -divider "═══════════════════ TOP CONTROL ═══════════════════"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/start
add wave -noupdate -color "Green"   /tb_conv_accel_simple/done
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/cfg_N
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/cfg_K

add wave -noupdate -divider "═══════════════════ DRAM INTERFACE ═══════════════════"
add wave -noupdate -divider "RX (Input Stream)"
add wave -noupdate -color "Cyan"   -radix hex /tb_conv_accel_simple/rx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/rx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/rx_ready

add wave -noupdate -divider "TX (Output Stream)"
add wave -noupdate -color "Cyan"   -radix hex /tb_conv_accel_simple/tx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/tx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/tx_ready

# ------------------------------------------------------------------------------
# 3.2 CONTROL UNIT
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ CONTROL UNIT ═══════════════════"
add wave -noupdate -divider "State Machine"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_control/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_input_rows_counter
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_output_rows_counter
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_control/sa_cols_counter
add wave -noupdate -color "White" -radix unsigned /tb_conv_accel_simple/dut/u_control/kernel_index
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_control/systolic_data_valid

add wave -noupdate -divider "Control Signals"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_start_load
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_load_done
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_load_kernel
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_kernel_done
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_load_column
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/cu_column_idx
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/cu_start_drain
add wave -noupdate -color "Green"   /tb_conv_accel_simple/dut/cu_drain_done

add wave -noupdate -divider "Configuration & Counters"
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

# ------------------------------------------------------------------------------
# 3.3 DATA LOADING PATH
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ DMA LOADER ═══════════════════"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_dma/state
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_dma/done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/byte_ptr
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/cfg_N
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/cfg_K
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/img_bytes_total
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/ker_bytes_total
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_dma/img_written
add wave -noupdate -divider "DMA -> SRAM"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/dma_sram_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/dma_sram_addr
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/rx_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/rx_ready
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/rx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_dma/sram0_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/sram0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_dma/sram0_wmask

add wave -noupdate -divider "═══════════════════ UNALIGNED READER ═══════════════════"
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

add wave -noupdate -divider "═══════════════════ WINDOW STREAMER ═══════════════════"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_streamer/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/cfg_N
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/cfg_K
add wave -noupdate -divider "Kernel Loading"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_streamer/start_load_kernel
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_streamer/kernel_done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/kernel_idx
add wave -noupdate -divider "Window Streaming"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_streamer/start_stream_window
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_streamer/window_done
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/col_cnt
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_streamer/row_cnt
add wave -noupdate -divider "Reader Interface"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_req_valid
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_req_ready
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_streamer/reader_byte_addr
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_streamer/reader_resp_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_streamer/reader_resp_data
add wave -noupdate -divider "Output Streams"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/w_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/w_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/p_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/p_data

# ------------------------------------------------------------------------------
# 3.4 SYSTOLIC ARRAY
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ SYSTOLIC ARRAY ═══════════════════"
add wave -noupdate -divider "Array Interface"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_systolic_array/load_kernel_signal
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/input_in
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/kernel_in
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/out_data
add wave -noupdate -color "Yellow" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/sum_partials

add wave -noupdate -divider "Array Internal State"
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sa_result
add wave -noupdate -color "Orange" -radix binary /tb_conv_accel_simple/dut/sa_valid_pipe

add wave -noupdate -divider "PE Weights (Row 0)"
add wave -noupdate -color "Yellow" -label "PE[0][0]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[0]/pe_00/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][1]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[1]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][2]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[2]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][3]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[3]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][4]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[4]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][5]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[5]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][6]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[6]/pe_top_row/pe_inst/left_reg
add wave -noupdate -color "Yellow" -label "PE[0][7]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[7]/pe_top_row/pe_inst/left_reg

add wave -noupdate -divider "PE Inputs (Row 0)"
add wave -noupdate -color "Cyan" -label "PE[0][0]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[0]/pe_00/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][1]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[1]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][2]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[2]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][3]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[3]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][4]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[4]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][5]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[5]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][6]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[6]/pe_top_row/pe_inst/top_reg
add wave -noupdate -color "Cyan" -label "PE[0][7]" -radix hex /tb_conv_accel_simple/dut/u_systolic_array/row[0]/col[7]/pe_top_row/pe_inst/top_reg

# ------------------------------------------------------------------------------
# 3.5 WRITEBACK & DRAIN PATH
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ WRITEBACK ═══════════════════"
add wave -noupdate -divider "SA -> Writeback"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sa_out_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sa_out_data
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sa_wb_busy
add wave -noupdate -divider "Writeback Internals"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_writeback/cfg_start_pass
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_writeback/cfg_ker_idx
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sa_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sa_wdata
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/u_writeback/busy
add wave -noupdate -divider "Writeback -> SRAM1"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sram_en
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_writeback/sram_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_writeback/sram_wmask
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_addr

add wave -noupdate -divider "═══════════════════ DRAIN STREAM ═══════════════════"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/u_drain/state
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_drain/read_cnt
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_drain/tx_cnt
add wave -noupdate -color "Cyan" -radix unsigned /tb_conv_accel_simple/dut/u_drain/cfg_num_pixels
add wave -noupdate -color "White" /tb_conv_accel_simple/dut/u_drain/cfg_split_mode
add wave -noupdate -color "Orange" -radix binary /tb_conv_accel_simple/dut/u_drain/valid_sr
add wave -noupdate -divider "Drain -> SRAM1"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p1_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_drain/sram_rdata
add wave -noupdate -divider "Drain -> TX"
add wave -noupdate -color "Magenta" /tb_conv_accel_simple/dut/u_drain/start
add wave -noupdate -color "Green" /tb_conv_accel_simple/dut/u_drain/done
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_drain/tx_valid
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/u_drain/tx_data
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/u_drain/tx_ready

# ------------------------------------------------------------------------------
# 3.6 MEMORY SUBSYSTEM (SRAM Interfaces)
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ SRAM0 (Input/Kernel) ═══════════════════"
add wave -noupdate -divider "Port 0 (DMA Write / Reader)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram0_p0_en
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sram0_p0_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p0_wmask
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram0_p0_rdata

add wave -noupdate -divider "Port 1 (Reader)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram0_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram0_p1_addr
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram0_p1_rdata

add wave -noupdate -divider "═══════════════════ SRAM1 (Output) ═══════════════════"
add wave -noupdate -divider "Port 0 (Writeback)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p0_en
add wave -noupdate -color "Red" /tb_conv_accel_simple/dut/sram1_p0_we
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_addr
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_wdata
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p0_wmask

add wave -noupdate -divider "Port 1 (Drain)"
add wave -noupdate -color "Orange" /tb_conv_accel_simple/dut/sram1_p1_en
add wave -noupdate -color "Cyan" -radix hex /tb_conv_accel_simple/dut/sram1_p1_addr
add wave -noupdate -color "Green" -radix hex /tb_conv_accel_simple/dut/sram1_p1_rdata

# ------------------------------------------------------------------------------
# 3.7 MISCELLANEOUS
# ------------------------------------------------------------------------------
add wave -noupdate -divider "═══════════════════ ARBITRATION & MISC ═══════════════════"
add wave -noupdate -color "Yellow" /tb_conv_accel_simple/dut/dma_active

# ==============================================================================
# 4. WAVEFORM VIEW CONFIGURATION
# ==============================================================================
configure wave -namecolwidth 350
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

# ==============================================================================
# 5. RUN SIMULATION
# ==============================================================================
echo "Running simulation..."
run -all

# ==============================================================================
# 6. FINALIZE VIEW
# ==============================================================================
echo "Finalizing waveform view..."
wave zoom full

# ==============================================================================
# 7. COMPLETION MESSAGE
# ==============================================================================
echo "=============================================================="
echo "Simulation Complete!"
echo "=============================================================="
echo "Waveforms are ready for analysis."
echo "Use 'wave zoom range <start> <end>' to zoom to specific time."
echo "Use 'wave zoom full' to view the entire simulation."
echo "=============================================================="
