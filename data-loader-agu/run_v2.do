# run_tb_loader.do
# Compile Verilog sources in ./src and run the testbench tb_load_image_to_sram
# Usage (GUI):  vsim -do run_tb_loader.do
# Usage (batch): vsim -c -do run_tb_loader.do

# create work library
vlib work
vmap work ./work

# compile all sources in src/
vlog -timescale 1ns/1ps \
	Python_scripts/macro_files/V_BB/sky130_sram_2kbyte_1rw1r_32x512_8.v \
	Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v \
	Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_8x1024_8.v \
	src/data_loader.v src/memory_generator_sky130_64_4096_2.v src/sram_wrapper.v src/tb_loader.v

# load the testbench (work library)
vsim work.tb_load_image_to_sram -voptargs=+acc

# optional: show all signals in waveform window
add wave -recursive /tb_load_image_to_sram/*
view wave

# run simulation until $stop/$finish in the testbench
run -all

# # quit simulator when finished (use -f to force)
# quit -f