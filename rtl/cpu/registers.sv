
///////////////////////////////////////////////////////
// Register File                                     //
//---------------------------------------------------//
// Store and access user registers.                  //
///////////////////////////////////////////////////////

module registers (
    // Interface
    input  logic clk,
    input  logic reset,
    input  logic we,

	 // Read port 1
    input  logic [4:0]  read_addr1, // Register to read (Source 1)
	output logic [31:0] read_data1, // Current value of Source 1

	 // Read port 2
    input  logic [4:0]  read_addr2, // Register to read (Source 2)
	output logic [31:0] read_data2, // Current value of Source 2

	 // Write port
    input  logic [4:0]  write_addr, // Register to write (Destination)
    input  logic [31:0] write_data  // Data to store
);

    // Note "ramstyle" here ensures the registers are not placed into (slow) BRAM.
    // Also x0 (register 0) is handled separately.
    (* ramstyle = "logic" *) logic [31:0] regs [1:31];

    ///// READ LOGIC (Combinational)
    // If address is 0, output 0. Otherwise, output the register value.
    assign read_data1 = (read_addr1 == 5'd0) ? 32'd0 : regs[read_addr1];
    assign read_data2 = (read_addr2 == 5'd0) ? 32'd0 : regs[read_addr2];

    ///// WRITE LOGIC (Sequential)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 1; i < 32; i++) regs[i] <= 32'h0;  // Clear all registers
        end else begin
            if (we && write_addr != 5'd0) begin
                regs[write_addr] <= write_data;
            end
        end
    end

endmodule
