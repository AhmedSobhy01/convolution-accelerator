if {[file exists work]} { vdel -lib work -all }
vlib work

# 1) Compile SRAM macro leaf models first
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_2kbyte_1rw1r_32x512_8.v
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_8x1024_8.v

# 2) Compile SRAM macro wrappers next
# vlog -work work designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v
# vlog -work work designs/SRAM_64_1024_2_grid/src/memory_generator_sky130_64_1024_2.v

# 3) Compile your wrappers
vlog -work work src/sram0_wrapper.v
vlog -work work src/sram1_wrapper.v

# 4) Compile RTL
vlog -work work src/byte_window_streamer.v
vlog -work work src/dl_dma_rx.v
vlog -work work src/kernel_window_streamer.v
vlog -work work src/sram0_selector.v
vlog -work work src/simple_ram_models.v
vlog -work work src/top_module.v

# 5) Compile testbench
vlog -work work src/tb_top_module.v

vsim -t 1ns -voptargs=+acc work.tb_conv_accelerator
add wave -r sim:/tb_conv_accelerator/dut/*

run -all