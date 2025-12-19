# ModelSim/QuestaSim DO file for Control Unit Testbench
# Usage: vsim -do run_tb.do

# Create work library if it doesn't exist
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile design files
vlog -work work control_unit.v

# Compile testbench
vlog -work work tb_control_unit.v

# Start simulation
vsim -voptargs=+acc work.tb_control_unit

# Add waves to waveform viewer
add wave -divider "Clock and Reset"
add wave -color "Yellow" sim:/tb_control_unit/clk
add wave -color "Red" sim:/tb_control_unit/rst_n

add wave -divider "Control Inputs"
add wave sim:/tb_control_unit/start
add wave -radix unsigned sim:/tb_control_unit/cfg_N
add wave -radix unsigned sim:/tb_control_unit/cfg_K
add wave sim:/tb_control_unit/done

add wave -divider "Data Loader Interface"
add wave sim:/tb_control_unit/dl_busy
add wave sim:/tb_control_unit/busy_clk
add wave sim:/tb_control_unit/rx_ready
add wave sim:/tb_control_unit/rx_valid
add wave sim:/tb_control_unit/tx_ready
add wave sim:/tb_control_unit/tx_valid

add wave -divider "Configuration Outputs"
add wave -radix unsigned sim:/tb_control_unit/dl_cfg_N
add wave -radix unsigned sim:/tb_control_unit/dl_cfg_K

add wave -divider "Control Signals"
add wave sim:/tb_control_unit/start_loading_kernel_to_sram
add wave sim:/tb_control_unit/start_loading_image_to_sram
add wave sim:/tb_control_unit/load_kernel
add wave -radix unsigned sim:/tb_control_unit/kernel_index
add wave sim:/tb_control_unit/load_column
add wave -radix unsigned sim:/tb_control_unit/load_column_index
add wave sim:/tb_control_unit/systolic_data_valid
add wave sim:/tb_control_unit/start_sending_output_to_dram

add wave -divider "Internal State"
add wave sim:/tb_control_unit/dut/state
add wave -radix unsigned sim:/tb_control_unit/dut/total_kernel_parts
add wave -radix unsigned sim:/tb_control_unit/dut/sa_input_rows_counter
add wave -radix unsigned sim:/tb_control_unit/dut/sa_output_rows_counter
add wave -radix unsigned sim:/tb_control_unit/dut/sa_cols_counter
add wave -radix unsigned sim:/tb_control_unit/dut/max_columns
add wave -radix unsigned sim:/tb_control_unit/dut/current_kernel_width
add wave -radix unsigned sim:/tb_control_unit/dut/current_kernel_height
add wave -radix unsigned sim:/tb_control_unit/dut/right_column_offset
add wave -radix unsigned sim:/tb_control_unit/dut/result_size

# Configure wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Run simulation
run -all

# Zoom to fit all waves
wave zoom full
