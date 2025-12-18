transcript on
if {[file exists work]} { vdel -lib work -all }
vlib work

# 1. Compile SRAM Models
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v
vlog -work work designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v

# 2. Compile Wrapper
vlog -work work src/sram1_wrapper.v

# 3. Compile Design
vlog -work work src/dl_sa_writeback.v

# 4. Compile Testbench
vlog -work work src/tb_integration.v

# 5. Run
vsim -t 1ns -voptargs=+acc work.tb_integration

# 6. Waves
add wave -divider {Control}
add wave -hex sim:/tb_integration/cfg_ker_idx
add wave -hex sim:/tb_integration/busy

# Inspect the 8-cycle write burst
add wave -divider {Internal Writeback}
add wave -hex sim:/tb_integration/dut_wb/pixel_idx
add wave -hex sim:/tb_integration/dut_wb/base_addr
add wave -hex sim:/tb_integration/dut_wb/sram_wdata
add wave -binary sim:/tb_integration/dut_wb/sram_wmask

# Inspect SRAM Interface
add wave -divider {SRAM Interface}
add wave -hex sim:/tb_integration/wb_addr
add wave -hex sim:/tb_integration/wb_wdata
add wave -hex sim:/tb_integration/wb_wmask
add wave -hex sim:/tb_integration/wb_we
add wave -hex sim:/tb_integration/wb_en

run -all