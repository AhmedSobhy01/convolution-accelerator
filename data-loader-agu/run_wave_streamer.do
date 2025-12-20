# Debug: Print current state
puts "Current Working Directory: [pwd]"
puts "Script path from info: [info script]"

# Smart Path Detection
set current_dir [pwd]
if {[string match "*src" $current_dir]} {
    puts "Detected running inside src/ directory."
    set src_path "."
} else {
    puts "Detected running outside src/ directory. Assuming files are in src/"
    set src_path "src"
}

# Create library
if {[file exists work] == 0} {
    vlib work
}

# Compile Dependencies
puts "Compiling simple_ram_models.v from $src_path"
vlog -work work $src_path/simple_ram_models.v

puts "Compiling sram0_wrapper.v from $src_path"
vlog -work work $src_path/sram0_wrapper.v

puts "Compiling byte_window_streamer.v from $src_path"
vlog -work work $src_path/byte_window_streamer.v  

# Compile Design and Testbench
puts "Compiling kernel_window_streamer.v from $src_path"
vlog -work work $src_path/kernel_window_streamer.v

puts "Compiling tb_wave_streamer.v from $src_path"
vlog -work work $src_path/tb_wave_streamer.v

# Load Simulation
vsim -voptargs=+acc work.tb_wave_streamer

# Add Waves
add wave -noupdate -divider "TB Signals"
add wave -noupdate -radix hexadecimal /tb_wave_streamer/clk
add wave -noupdate -radix hexadecimal /tb_wave_streamer/rst_n
add wave -noupdate -radix hexadecimal /tb_wave_streamer/p_valid
add wave -noupdate -radix hexadecimal /tb_wave_streamer/p_data
add wave -noupdate -radix hexadecimal /tb_wave_streamer/dut_req_valid
add wave -noupdate -radix hexadecimal /tb_wave_streamer/dut_resp_valid

add wave -noupdate -divider "Internal Buffer"
add wave -noupdate -radix hexadecimal /tb_wave_streamer/dut/row_buf
add wave -noupdate -radix unsigned /tb_wave_streamer/dut/wave_tick
add wave -noupdate -radix unsigned /tb_wave_streamer/dut/req_cnt
add wave -noupdate -radix unsigned /tb_wave_streamer/dut/resp_cnt

add wave -noupdate -divider "SRAM Interface"
add wave -noupdate -radix hexadecimal /tb_wave_streamer/reader_sram_p0_addr
add wave -noupdate -radix hexadecimal /tb_wave_streamer/reader_sram_p0_rdata

# Run
run -all
zoom full
