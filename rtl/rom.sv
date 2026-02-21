// =============================================================================
// rom.sv
// Boot ROM
//
// Synchronous read, single cycle ACK.
// (* ramstyle = "M9K" *) forces Quartus to use block RAM.
// Initialised from boot.hex at synthesis/simulation time.
//
// Parameters:
//   SIZE — number of 32-bit words (must be a power of 2, default 1024 = 4KB)
// =============================================================================

module rom #(
    parameter int SIZE = 1024     // size in 32-bit words — 1024 = 4KB
)(
    input  logic        clk,
    input  logic        rst_n,

    wishbone_if.target  bus
);
    timeunit 1ns;
    timeprecision 1ps;

    (* ramstyle = "M9K" *) logic [31:0] mem [0:SIZE-1];

    // Word address — drop bottom 2 bits (byte addressed, word aligned)
    logic [$clog2(SIZE)-1:0] word_addr;
    assign word_addr = bus.adr[$clog2(SIZE)+1:2];

    // Initialise from hex file
    initial $readmemh("../rom/boot.hex", mem);

    // Single cycle ACK
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus.ack <= '0;
        end else begin
            bus.ack <= bus.cyc && bus.stb && !bus.ack;
        end
    end

    // Synchronous read for M9K block RAM inference
    always_ff @(posedge clk) begin
        bus.dat_r <= mem[word_addr];
    end

    // ROM is read only — always return no error, never write
    assign bus.err   = '0;
    assign bus.stall = '0;

endmodule
