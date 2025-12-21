transcript on
if {[file exists work]} { vdel -lib work -all }
vlib work

# ---------------------------------------------------------
# 1) Compile RTL
#    Assuming the new files are in the 'src' folder
# ---------------------------------------------------------
vlog -work work src/dl_sa_writeback.v

# ---------------------------------------------------------
# 2) Compile Testbench
# ---------------------------------------------------------
vlog -work work src/tb_dl_writeback.v

# ---------------------------------------------------------
# 3) Run Simulation
# ---------------------------------------------------------
vsim -t 1ns -voptargs=+acc work.tb_dl_writeback

# 3. Add Waves
# --- Config & Input ---
add wave -noupdate -divider "Control"
add wave -noupdate -color yellow -label clk /tb_dl_writeback/clk
add wave -noupdate -label rst_n /tb_dl_writeback/rst_n
add wave -noupdate -color orange -label cfg_start /tb_dl_writeback/cfg_start_pass
add wave -noupdate -color orange -label ker_idx /tb_dl_writeback/cfg_ker_idx
add wave -noupdate -color magenta -label sa_valid /tb_dl_writeback/sa_valid
add wave -noupdate -radix hex -label sa_wdata /tb_dl_writeback/sa_wdata
add wave -noupdate -color red -label busy /tb_dl_writeback/busy

# --- Internal State ---
add wave -noupdate -divider "Internal State"
add wave -noupdate -radix unsigned -label fifo_cnt /tb_dl_writeback/dut/cnt
add wave -noupdate -radix unsigned -label push /tb_dl_writeback/dut/push
add wave -noupdate -radix unsigned -label pop /tb_dl_writeback/dut/pop
add wave -noupdate -radix unsigned -label rptr /tb_dl_writeback/dut/rptr
add wave -noupdate -radix unsigned -label wptr /tb_dl_writeback/dut/wptr
add wave -noupdate -radix unsigned -label fifo_empty /tb_dl_writeback/dut/fifo_empty



add wave -noupdate -radix hex -label fifo_out /tb_dl_writeback/dut/fifo_rdata
add wave -noupdate -radix unsigned -label byte_ptr /tb_dl_writeback/dut/byte_ptr

# --- SRAM Output ---
add wave -noupdate -divider "SRAM Output"
add wave -noupdate -color cyan -label sram_en /tb_dl_writeback/sram1_en
add wave -noupdate -label sram_we /tb_dl_writeback/sram1_we
add wave -noupdate -radix unsigned -label sram_addr_word /tb_dl_writeback/sram1_addr
add wave -noupdate -radix bin -label sram_mask /tb_dl_writeback/sram1_wmask
add wave -noupdate -radix hex -label sram_data /tb_dl_writeback/sram1_wdata

# 4. Format
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# 5. Run
run -all