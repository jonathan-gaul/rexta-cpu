`timescale 1ns / 1ps

module cpu_tb;

	reg clk;
	reg reset;
	
	// Instantiate the CPU
	cpu_top cpu (
		.clk(clk),
		.reset(reset)
	);
	
	// Clock generation: 10ns period = 100MHz
	initial clk = 0;
	always #5 clk = ~clk;
	
	// Simulation
	initial begin 
		reset = 0;
		#20; // hold reset for 20ns
		reset = 1;
		
		// Run simulation for 1500ns
		#1500;
		
		$stop;
	end
endmodule
