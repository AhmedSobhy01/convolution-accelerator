# ==============================================================================
# ModelSim/QuestaSim DO File for Convolution Accelerator
# ==============================================================================

# 1. Compilation
# ------------------------------------------------------------------------------
vlib work
vmap work work
vlog src/*.v

# 2. Start Simulation
# ------------------------------------------------------------------------------
vsim -voptargs=+acc work.tb_conv_accelerator

# 2) Compile SRAM macro wrappers next
# vlog -work work designs/SRAM_32_4096_1_grid/src/memory_generator_sky130_32_4096_1.v
# vlog -work work designs/SRAM_64_1024_2_grid/src/memory_generator_sky130_64_1024_2.v

# 3) Compile your wrappers
vlog -work work src/sram0_wrapper.v
vlog -work work src/sram1_wrapper.v

# ------------------------------------------------------------------------------
# GROUP: TOP LEVEL CONTROLS & CONFIG
# ------------------------------------------------------------------------------
add wave -noupdate -divider "CONTROLS & CONFIG"
add wave -noupdate -group "Controls" -color "Yellow" -radix binary   /tb_conv_accelerator/clk
add wave -noupdate -group "Controls" -color "Yellow" -radix binary   /tb_conv_accelerator/rst_n

# Configuration Signals
add wave -noupdate -group "Controls" -color "White"  -radix unsigned /tb_conv_accelerator/cfg_N
add wave -noupdate -group "Controls" -color "White"  -radix unsigned /tb_conv_accelerator/cfg_K
add wave -noupdate -group "Controls" -color "White"  -radix binary   /tb_conv_accelerator/cfg_start_pass
add wave -noupdate -group "Controls" -color "White"  -radix unsigned /tb_conv_accelerator/cfg_ker_idx
add wave -noupdate -group "Controls" -color "White"  -radix binary   /tb_conv_accelerator/cfg_split_mode

# Operation Triggers (Magenta) & Status (Green)
add wave -noupdate -group "Controls" -color "Magenta" /tb_conv_accelerator/start_load
add wave -noupdate -group "Controls" -color "Green"   /tb_conv_accelerator/load_done
add wave -noupdate -group "Controls" -color "Magenta" /tb_conv_accelerator/start_kernel_load
add wave -noupdate -group "Controls" -color "Green"   /tb_conv_accelerator/kernel_done
add wave -noupdate -group "Controls" -color "Magenta" /tb_conv_accelerator/start_window
add wave -noupdate -group "Controls" -color "Green"   /tb_conv_accelerator/window_done
add wave -noupdate -group "Controls" -color "Magenta" /tb_conv_accelerator/start_drain
add wave -noupdate -group "Controls" -color "Green"   /tb_conv_accelerator/drain_done

# ------------------------------------------------------------------------------
# GROUP: EXTERNAL INTERFACES
# ------------------------------------------------------------------------------
add wave -noupdate -divider "EXTERNAL INTERFACES"

# DRAM RX (Input)
add wave -noupdate -group "DRAM IO" -color "Cyan"   -radix hex /tb_conv_accelerator/rx_data
add wave -noupdate -group "DRAM IO" -color "Orange"            /tb_conv_accelerator/rx_valid
add wave -noupdate -group "DRAM IO" -color "Orange"            /tb_conv_accelerator/rx_ready

# DRAM TX (Output)
add wave -noupdate -group "DRAM IO" -color "Cyan"   -radix hex /tb_conv_accelerator/tx_data
add wave -noupdate -group "DRAM IO" -color "Orange"            /tb_conv_accelerator/tx_valid
add wave -noupdate -group "DRAM IO" -color "Orange"            /tb_conv_accelerator/tx_ready

# Systolic Array Interface
add wave -noupdate -group "SA Interface" -color "Cyan"   -radix hex /tb_conv_accelerator/w_data
add wave -noupdate -group "SA Interface" -color "Orange"            /tb_conv_accelerator/w_valid
add wave -noupdate -group "SA Interface" -color "Cyan"   -radix hex /tb_conv_accelerator/p_data
add wave -noupdate -group "SA Interface" -color "Orange"            /tb_conv_accelerator/p_valid
add wave -noupdate -group "SA Interface" -color "Cyan"   -radix hex /tb_conv_accelerator/sa_out_data
add wave -noupdate -group "SA Interface" -color "Orange"            /tb_conv_accelerator/sa_out_valid
add wave -noupdate -group "SA Interface" -color "Red"               /tb_conv_accelerator/sa_wb_busy

# ------------------------------------------------------------------------------
# GROUP: INTERNAL MODULES
# ------------------------------------------------------------------------------
add wave -noupdate -divider "INTERNAL MODULES"

# Module: DMA (Loader)
add wave -noupdate -group "DMA (Loader)" -color "Yellow"                  /tb_conv_accelerator/dut/u_dma/state
add wave -noupdate -group "DMA (Loader)" -color "Cyan"   -radix unsigned  /tb_conv_accelerator/dut/u_dma/byte_ptr
add wave -noupdate -group "DMA (Loader)" -color "Cyan"   -radix hex       /tb_conv_accelerator/dut/u_dma/rx_data
add wave -noupdate -group "DMA (Loader)" -color "Orange"                  /tb_conv_accelerator/dut/u_dma/sram0_we
add wave -noupdate -group "DMA (Loader)" -color "Cyan"   -radix hex       /tb_conv_accelerator/dut/u_dma/sram0_wdata

# Module: Unaligned Reader
add wave -noupdate -group "Reader" -color "Cyan"   -radix unsigned /tb_conv_accelerator/dut/u_reader/byte_addr
add wave -noupdate -group "Reader" -color "Cyan"   -radix unsigned /tb_conv_accelerator/dut/u_reader/len_bytes
add wave -noupdate -group "Reader" -color "Orange"                 /tb_conv_accelerator/dut/u_reader/req_valid
add wave -noupdate -group "Reader" -color "Green"  -radix hex      /tb_conv_accelerator/dut/u_reader/resp_data
add wave -noupdate -group "Reader" -color "Green"                  /tb_conv_accelerator/dut/u_reader/resp_valid

# Module: Streamer (Orchestrator)
add wave -noupdate -group "Streamer" -color "Yellow"                 /tb_conv_accelerator/dut/u_streamer/state
add wave -noupdate -group "Streamer" -color "Cyan"   -radix unsigned /tb_conv_accelerator/dut/u_streamer/row_cnt
add wave -noupdate -group "Streamer" -color "Cyan"   -radix unsigned /tb_conv_accelerator/dut/u_streamer/col_cnt

# Module: Writeback (SA -> SRAM1)
add wave -noupdate -group "Writeback" -color "Cyan"   -radix hex      /tb_conv_accelerator/dut/u_writeback/sa_wdata
add wave -noupdate -group "Writeback" -color "Orange"                 /tb_conv_accelerator/dut/u_writeback/sa_valid
add wave -noupdate -group "Writeback" -color "Red"                    /tb_conv_accelerator/dut/u_writeback/busy
add wave -noupdate -group "Writeback" -color "Violet" -radix unsigned /tb_conv_accelerator/dut/u_writeback/cnt
add wave -noupdate -group "Writeback" -color "Green"                  /tb_conv_accelerator/dut/u_writeback/sram_we
add wave -noupdate -group "Writeback" -color "Cyan"   -radix hex      /tb_conv_accelerator/dut/u_writeback/sram_addr
add wave -noupdate -group "Writeback" -color "Cyan"   -radix hex      /tb_conv_accelerator/dut/u_writeback/sram_wdata

# Module: Drain (SRAM1 -> DRAM)
add wave -noupdate -group "Drain" -color "Yellow"                 /tb_conv_accelerator/dut/u_drain/state
add wave -noupdate -group "Drain" -color "Cyan"   -radix unsigned /tb_conv_accelerator/dut/u_drain/pixel_cnt
add wave -noupdate -group "Drain" -color "Cyan"   -radix hex      /tb_conv_accelerator/dut/u_drain/sram_rdata
add wave -noupdate -group "Drain" -color "Green"  -radix hex      /tb_conv_accelerator/dut/u_drain/tx_data
add wave -noupdate -group "Drain" -color "Orange"                 /tb_conv_accelerator/dut/u_drain/tx_valid

# ------------------------------------------------------------------------------
# GROUP: SRAM MONITORS
# ------------------------------------------------------------------------------
add wave -noupdate -divider "SRAM MONITORS"

# SRAM0 (Input Buffer)
add wave -noupdate -group "SRAM0 (Input)" -color "Orange"            /tb_conv_accelerator/dut/sram0_p0_en
add wave -noupdate -group "SRAM0 (Input)" -color "Red"               /tb_conv_accelerator/dut/sram0_p0_we
add wave -noupdate -group "SRAM0 (Input)" -color "Cyan"   -radix hex /tb_conv_accelerator/dut/sram0_p0_addr
add wave -noupdate -group "SRAM0 (Input)" -color "Green"  -radix hex /tb_conv_accelerator/dut/sram0_p0_wdata
add wave -noupdate -group "SRAM0 (Input)" -color "Cyan"   -radix hex /tb_conv_accelerator/dut/sram0_p1_addr
add wave -noupdate -group "SRAM0 (Input)" -color "Green"  -radix hex /tb_conv_accelerator/dut/sram0_p1_rdata

# SRAM1 (Output Buffer)
add wave -noupdate -group "SRAM1 (Output)" -color "Orange"            /tb_conv_accelerator/dut/sram1_p0_en
add wave -noupdate -group "SRAM1 (Output)" -color "Red"               /tb_conv_accelerator/dut/sram1_p0_we
add wave -noupdate -group "SRAM1 (Output)" -color "Cyan"   -radix hex /tb_conv_accelerator/dut/sram1_p0_addr
add wave -noupdate -group "SRAM1 (Output)" -color "Green"  -radix hex /tb_conv_accelerator/dut/sram1_p0_wdata
add wave -noupdate -group "SRAM1 (Output)" -color "Cyan"   -radix hex /tb_conv_accelerator/dut/sram1_p1_addr
add wave -noupdate -group "SRAM1 (Output)" -color "Green"  -radix hex /tb_conv_accelerator/dut/sram1_p1_rdata

# 4. View Configuration
# ------------------------------------------------------------------------------
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# 5. Run
# ------------------------------------------------------------------------------
run -all
wave zoom full