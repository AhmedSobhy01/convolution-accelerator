vlib work

vlog -work work rtl/pe.v
vlog -work work rtl/systolic_array.v
vlog -work work tb/systolic_array_tb.v
vsim -voptargs="+acc" work.systolic_array_tb

add wave -divider "Clock and Reset"
add wave -position insertpoint sim:/systolic_array_tb/clk
add wave -position insertpoint sim:/systolic_array_tb/rst

add wave -divider "Control Signals"
add wave -position insertpoint sim:/systolic_array_tb/load_kernel_signal
add wave -position insertpoint sim:/systolic_array_tb/outputs_valid

add wave -divider "Inputs"
add wave -position insertpoint -radix hexadecimal sim:/systolic_array_tb/input_in
add wave -position insertpoint -radix hexadecimal sim:/systolic_array_tb/kernel_in

add wave -divider "Output"
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/out_data

add wave -divider "PE Array Row 0"
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[0]/col[0]/pe_00/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[0]/col[1]/pe_top_row/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[0]/col[2]/pe_top_row/pe_inst/out_partial

add wave -divider "PE Array Row 1"
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[1]/col[0]/pe_left_col/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[1]/col[1]/pe_inner/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[1]/col[2]/pe_inner/pe_inst/out_partial

add wave -divider "PE Array Row 2"
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[2]/col[0]/pe_left_col/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[2]/col[1]/pe_inner/pe_inst/out_partial
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/row[2]/col[2]/pe_inner/pe_inst/out_partial

add wave -divider "Sum Partials"
add wave -position insertpoint -radix unsigned sim:/systolic_array_tb/dut/sum_partials

configure wave -namecolwidth 250
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
