
///////////////////////////////////////////////////////
// System Bus                                        //
//---------------------------------------------------//
// The system bus maps devices/specific modules into //
// areas of memory.                                  //
///////////////////////////////////////////////////////

module system_bus (
    // Interface
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        we,
    output logic [31:0] rdata,
    output logic        ready,

    // Port to Boot ROM (Target 1)
    output logic        rom_sel,
    input  logic        rom_ready,
    output logic [31:0] rom_addr,
    input  logic [31:0] rom_rdata,

    // Port to Stack BRAM (Target 2)
    output logic        stack_sel,
    input  logic        stack_ready,
    output logic        stack_we,
    output logic [31:0] stack_addr,
    input  logic [31:0] stack_rdata,
    output logic [31:0] stack_wdata,

    // Port to Peripherals (Target 3)
    output logic        io_sel,
    input  logic        io_ready,
    output logic        io_we,
    output logic [31:0] io_addr,
    input  logic [31:0] io_rdata,
    output logic [31:0] io_wdata  
);
    // Broadcast wdata
    assign stack_wdata = wdata;
    assign io_wdata    = wdata;

    always_comb begin
        // Defaults
        rom_sel     = 1'b0;
        stack_sel   = 1'b0;
        io_sel      = 1'b0;
        rdata       = 32'h0;
        ready       = 1'b1;
		rom_addr    = 32'h0;
		stack_addr  = 32'h0;
		io_addr     = 32'h0;
        stack_we    = 1'b0;
        io_we       = 1'b0;

        casez (addr)
            // 0x00000000 - 0x00000FFF (4KB Boot ROM)
            32'h0000_0???: begin
                rom_sel   = 1'b1;
                rdata     = rom_rdata;
                rom_addr  = addr;
                ready     = rom_ready;
            end

            // 0x10000000 - 0x10000FFF (4KB Stack)
            32'h1000_0???: begin
                stack_sel  = 1'b1;
                stack_addr = addr[11:0];
                stack_we   = we;
                rdata      = stack_rdata;
                ready      = stack_ready;
            end

            // 0xFF000000+ (Peripherals)
            32'hFF??_????: begin
                io_sel    = 1'b1;
                io_we     = we;
                io_addr   = addr[23:0];
                rdata     = io_rdata;
                ready     = io_ready;
            end

            default: begin
                // Easy way to see something is being accessed outside of the bus.
                rdata = 32'hDEADBEEF; 
                ready = 1'b1;
            end
        endcase
    end
endmodule
