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

# ---------------------------------------------------------
# 4) Add Waves
# ---------------------------------------------------------
# Add Top-level TB signals
add wave -noupdate -divider {Testbench Signals}
add wave -noupdate -radix hex sim:/tb_dl_writeback/*

# Add DUT internal signals (helpful to see the counter)
add wave -noupdate -divider {DUT Internals}
add wave -noupdate -radix unsigned sim:/tb_dl_writeback/dut/write_cnt
add wave -noupdate -radix hex      sim:/tb_dl_writeback/dut/calc_addr
add wave -noupdate -radix hex      sim:/tb_dl_writeback/dut/sram1_addr
add wave -noupdate -radix hex      sim:/tb_dl_writeback/dut/sram1_wdata
add wave -noupdate -radix binary   sim:/tb_dl_writeback/dut/sram1_we

# Configure the wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# ---------------------------------------------------------
# 5) Run
# ---------------------------------------------------------
run -all