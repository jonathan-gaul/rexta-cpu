module virtual_uart (
    input  logic        clk,
    input  logic        we,     // Write enable from your I/O decoder
    input  logic [31:0] wdata   // Data from CPU
);

    always @(posedge clk) begin
        if (we) begin
            // %c tells the simulator to print the data as an ASCII character
            $write("%c", wdata[7:0]);
            // Ensure it prints immediately rather than buffering
            $fflush();
        end
    end

endmodule