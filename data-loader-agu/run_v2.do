transcript on
if {[file exists work]} { vdel -lib work -all }
vlib work

# 1) Compile SRAM macro leaf models first
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_2kbyte_1rw1r_32x512_8.v
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_8x1024_8.v

# 2) Compile generated memories
vlog -work work designs/SRAM_64_1024_2_grid/src/memory_generator_sky130_64_1024_2.v
vlog -work work designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v

# 3) Compile your wrappers
vlog -work work src/sram0_wrapper.v
vlog -work work src/sram1_wrapper.v

# 4) Compile RTL + TB
vlog -work work src/dl_dma_rx.v
vlog -work work src/tb_loader.v

vsim -t 1ns -voptargs=+acc work.tb_loader
# # Add waves (use explicit top scope)
# add wave -r sim:/tb_loader/*
# # (optional) include deeper hierarchy too
add wave -r sim:/tb_loader/dut/*
add wave -r sim:/tb_loader/u_sram0/*
# add wave -r sim:/tb_loader/u_sram1/*
run -all