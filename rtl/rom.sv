import rexta::*;

///////////////////////////////////////////////////////
// ROM - Read Only Memory                            //
//---------------------------------------------------//
// This is the code that will be run at startup.     //
///////////////////////////////////////////////////////

module rom (
    input  logic        clk,
    input  logic        cs,
    input  logic [31:0] addr,
    output logic [31:0] rdata,
    output logic        ready
);

// Static 4KB ROM
logic [31:0] mem [0:1023];

// Initialise the ROM from a .hex file
initial $readmemh("../examples/led-b.hex", mem);

always_comb begin
    rdata = mem[addr[11:2]];
    ready = 1'b1;
end

endmodule
