# To use this file, cd to this folder from within the test software and "do sim.do".

if {[file exists work]} { vdel -all }
vlib work

vlog -sv ../rtl/pkg.sv
vlog -sv ../rtl/cpu/alu.sv
vlog -sv ../rtl/cpu/decoder.sv
vlog -sv ../rtl/cpu/registers.sv
vlog -sv ../rtl/bus.sv
vlog -sv ../rtl/rom.sv
vlog -sv ../rtl/stack.sv
vlog -sv ../rtl/io/virtual_uart.sv
vlog -sv ../rtl/io.sv
vlog -sv ../rtl/io/spi.sv
vlog -sv ../rtl/io/sd.sv
vlog -sv ../rtl/io/sa52.sv
vlog -sv ../rtl/cpu.sv
vlog -sv ../rtl/rexta_top.sv

vlog -sv ../tb/rexta_tb.sv

vsim -voptargs="+acc" work.rexta_tb

add wave -position insertpoint -label "CLK" sim:/rexta_tb/clk
add wave -position insertpoint -label "RESET" sim:/rexta_tb/rexta_inst/reset

add wave -position insertpoint -divider "Control"
add wave -position insertpoint -label "STATE" sim:/rexta_tb/rexta_inst/cpu_inst/state 
add wave -position insertpoint -label "PC" -radix decimal sim:/rexta_tb/rexta_inst/cpu_inst/pc
add wave -position insertpoint -label "opcode" sim:/rexta_tb/rexta_inst/cpu_inst/decoder_inst/opcode

add wave -position insertpoint -divider "Registers"
add wave -position insertpoint -label "x1 (RA)" sim:/rexta_tb/rexta_inst/cpu_inst/registers_inst/regs[1] 
add wave -position insertpoint -label "x2 (SP)" sim:/rexta_tb/rexta_inst/cpu_inst/registers_inst/regs[2]

# 5. Run for a set amount of time
run 3000ns

# 6. Zoom to show everything
wave zoom full