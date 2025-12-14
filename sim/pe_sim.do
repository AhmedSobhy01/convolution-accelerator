vlib work

vlog -work work rtl/pe.v
vlog -work work tb/pe_tb.v
vsim -voptargs="+acc" work.pe_tb

add wave -divider "Clock and Reset"
add wave -position insertpoint sim:/pe_tb/clk
add wave -position insertpoint sim:/pe_tb/rst

add wave -divider "Control Signals"
add wave -position insertpoint sim:/pe_tb/load_kernel_signal

add wave -divider "Inputs"
add wave -position insertpoint -radix unsigned sim:/pe_tb/in_top
add wave -position insertpoint -radix unsigned sim:/pe_tb/in_left

add wave -divider "Outputs"
add wave -position insertpoint -radix unsigned sim:/pe_tb/out_partial
add wave -position insertpoint -radix unsigned sim:/pe_tb/out_down
add wave -position insertpoint -radix unsigned sim:/pe_tb/out_right

add wave -divider "Internal Registers"
add wave -position insertpoint -radix unsigned sim:/pe_tb/uut/top_reg
add wave -position insertpoint -radix unsigned sim:/pe_tb/uut/left_reg

configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

run -all
wave zoom full
