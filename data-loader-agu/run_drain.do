transcript on
if {[file exists work]} { vdel -lib work -all }
vlib work

# Compile SRAM Models
vlog -work work Python_scripts/macro_files/V_BB/sky130_sram_1kbyte_1rw1r_32x256_8.v
vlog -work work designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v

# Compile Wrapper
vlog -work work src/sram1_wrapper.v

# Compile Design & TB
vlog -work work src/dl_drain_stream.v
vlog -work work src/tb_drain.v

vsim -t 1ns -voptargs=+acc work.tb_drain

add wave -divider {Control}
add wave -hex sim:/tb_drain/clk
add wave -hex sim:/tb_drain/start
add wave -hex sim:/tb_drain/done
add wave -hex sim:/tb_drain/dut/state

add wave -divider {SRAM Read}
add wave -hex sim:/tb_drain/drain_en
add wave -hex sim:/tb_drain/drain_addr
add wave -hex sim:/tb_drain/sram_rdata_drain
add wave -hex sim:/tb_drain/tb_en
add wave -hex sim:/tb_drain/tb_we
add wave -hex sim:/tb_drain/tb_addr
add wave -hex sim:/tb_drain/tb_wdata
add wave -hex sim:/tb_drain/tb_wmask
add wave -hex sim:/tb_drain/dut/computed_pixel
add wave -hex sim:/tb_drain/dut/state
add wave -hex sim:/tb_drain/dut/pack_buf

add wave -divider {DRAM Output}
add wave -hex sim:/tb_drain/tx_valid
add wave -hex sim:/tb_drain/tx_ready
add wave -hex sim:/tb_drain/tx_data

run -all