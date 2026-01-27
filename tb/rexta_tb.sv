`timescale 1ns/1ps

module rexta_tb();
    logic clk;
    logic reset_n;
    
    // 1. Instantiate your CPU
    rexta_top rexta_inst (
        .clk(clk),
        .reset_n(reset_n)
    );

    // 2. Generate a 50MHz Clock
    always #10 clk = ~clk;

    // 3. The "Script" for the simulation
    initial begin
        clk = 0;
        reset_n = 0;      // Start in Reset
        #50 reset_n = 1;  // Release Reset after 50ns
        
        #2000;          // Run for 1 microsecond
        $stop;          // Pause simulation
    end
endmodule