// =============================================================================
// sram.sv
// On-chip Scratchpad RAM
//
// Synchronous read/write, single-cycle ACK.
// Uses four parallel byte-wide M9K arrays so individual byte enables work.
//
// Parameters:
//   SIZE — number of 32-bit words (must be a power of 2, default 128 = 512 B)
// =============================================================================

module sram #(
    parameter int SIZE = 128      // size in 32-bit words — 128 = 512 B
)(
    input  logic        clk,
    input  logic        rst_n,

    wishbone_if.target  bus
);
    timeunit 1ns;
    timeprecision 1ps;

    // Four byte-wide M9K arrays — one per byte lane
    (* ramstyle = "M9K" *) logic [7:0] mem0 [0:SIZE-1];
    (* ramstyle = "M9K" *) logic [7:0] mem1 [0:SIZE-1];
    (* ramstyle = "M9K" *) logic [7:0] mem2 [0:SIZE-1];
    (* ramstyle = "M9K" *) logic [7:0] mem3 [0:SIZE-1];

    // Word address — drop bottom 2 bits (byte addressed, word aligned)
    logic [$clog2(SIZE)-1:0] word_addr;
    assign word_addr = bus.adr[$clog2(SIZE)+1:2];

    // =========================================================================
    // RAM read/write — synchronous for M9K inference
    // =========================================================================
    always_ff @(posedge clk) begin
        // Write path — byte enables applied individually
        if (bus.cyc && bus.stb && bus.we) begin
            if (bus.sel[0]) mem0[word_addr] <= bus.dat_w[ 7: 0];
            if (bus.sel[1]) mem1[word_addr] <= bus.dat_w[15: 8];
            if (bus.sel[2]) mem2[word_addr] <= bus.dat_w[23:16];
            if (bus.sel[3]) mem3[word_addr] <= bus.dat_w[31:24];
        end

        // Read path — always reads, dat_r updates every cycle
        bus.dat_r <= {mem3[word_addr], mem2[word_addr],
                      mem1[word_addr], mem0[word_addr]};
    end

    // =========================================================================
    // Single-cycle ACK
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bus.ack <= '0;
        else
            bus.ack <= bus.cyc && bus.stb && !bus.ack;
    end

    // No errors, no stalling
    assign bus.err   = '0;
    assign bus.stall = '0;

endmodule
