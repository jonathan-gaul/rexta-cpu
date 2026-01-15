module cpu_tb;
    logic clk;
    logic reset;

    logic [4:0] leds;

    // Instantiate your CPU top module
    cpu_top cpu(
        .clk(clk),
        .reset_n(reset),
        .leds(leds)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk; // 10 time units clock period

    // Reset + simulation control
    initial begin
        reset = 0;
        #10;
        reset = 1;

        // Run simulation for enough cycles to execute LOADI + HLT
        #500;

        $display("R0 = %0d", cpu.regs[0]); // should print 10
        $stop;
    end
endmodule