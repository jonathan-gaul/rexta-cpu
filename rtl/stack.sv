///////////////////////////////////////////////////////
// Stack                                             //
//---------------------------------------------------//
// Since we have BRAM on the FPGA, and it's (a lot)  //
// faster than your normal everyday garden PSRAM, we //
// might as well make use of it for a stack.  This   //
// is accessed as if it were normal memory in a      //
// given range (determined by the bus), it's just    //
// quicker.                                          //
///////////////////////////////////////////////////////

module stack (
    input  logic        clk,
    input  logic        cs,
    input  logic [31:0] addr,    
    input  logic        we,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        ready
);
    // 1024 words = 4KB of Stack
    logic [31:0] mem [0:1023] = '{default: 32'h0};
    
    always_ff @(posedge clk) begin
        if (we && cs) begin
            mem[addr[11:2]] <= wdata;
        end

        rdata <= mem[addr[11:2]];
    end

    always_ff @(posedge clk) begin
        ready <= cs;
    end
endmodule
