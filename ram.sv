module ram #(
    parameter ADDR_WIDTH = 24,
    parameter DATA_WIDTH = 8
)(
    input logic clk,
    input logic write,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

// internal FPGA memory
logic [DATA_WIDTH-1:0] ram [0:2047];

integer i;
// Small test program in FPGA memory
initial begin
    // LOADI.1 R0, 10; HLT
	$readmemh("program1.hex", ram);
end

always_ff @(posedge clk) begin
    if (write)
        ram[addr] <= din;

    dout <= ram[addr];
end

endmodule