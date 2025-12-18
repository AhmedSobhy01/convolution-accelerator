# 1. Create Library
vlib work
vmap work work

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
vlog -work work src/byte_window_streamer.v
vlog -work work src/sram0_selector.v


# 5. Compile Design Modules
vlog -work work src/dl_sa_writeback.v
vlog -work work src/dl_drain_stream.v
vlog -work work src/agu_top.v

# 6. Compile Testbench
vlog -work work src/tb_agu_top.v

# 7. Load Simulation (Optimized with access to all signals)
vsim -voptargs=+acc work.tb_agu_top

# --- WAVES ---
add wave -noupdate -divider "Control"
add wave -noupdate /tb_agu_top/clk
add wave -noupdate /tb_agu_top/cmd
add wave -noupdate /tb_agu_top/cmd_start
add wave -noupdate /tb_agu_top/cmd_done

add wave -noupdate -divider "DRAM Interface"
add wave -noupdate -radix hex /tb_agu_top/dram_rx_data
add wave -noupdate -radix hex /tb_agu_top/dram_tx_data
add wave -noupdate /tb_agu_top/dram_tx_valid

add wave -noupdate -divider "SA Interface"
add wave -noupdate /tb_agu_top/sa_pixel_valid
add wave -noupdate /tb_agu_top/sa_weight_valid
add wave -noupdate /tb_agu_top/sa_out_valid
add wave -noupdate -radix hex /tb_agu_top/sa_out_data

add wave -noupdate -divider "SRAM1 (Writeback)"
# See valid data being written
add wave -noupdate /tb_agu_top/dut/wb_en
add wave -noupdate /tb_agu_top/dut/wb_we
add wave -noupdate -radix unsigned /tb_agu_top/dut/wb_addr
add wave -noupdate -radix hex /tb_agu_top/dut/wb_wdata

add wave -noupdate -divider "SRAM1 (Drain)"
# See the drain reading empty addresses
add wave -noupdate /tb_agu_top/dut/drain_en
add wave -noupdate -radix unsigned /tb_agu_top/dut/drain_addr
add wave -noupdate -radix hex /tb_agu_top/dut/drain_rdata

run -all