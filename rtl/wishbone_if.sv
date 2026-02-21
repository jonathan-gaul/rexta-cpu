// =============================================================================
// wishbone_if.sv
// Wishbone B4 Interface
//
// Classic mode — initiator asserts CYC+STB, waits for ACK.
// Pipelined mode — stall signal supported but tie low for classic operation.
//
// Usage:
//   wishbone_if.initiator  — for modules that drive transactions (CPU, DMA)
//   wishbone_if.target     — for modules that respond to transactions (RAM, peripherals)
// =============================================================================

interface wishbone_if;
    logic        cyc;    // bus cycle active
    logic        stb;    // transfer strobe
    logic        we;     // 1 = write, 0 = read
    logic [3:0]  sel;    // byte select (1 bit per byte lane)
    logic [31:0] adr;    // address
    logic [31:0] dat_w;  // data from initiator to target
    logic [31:0] dat_r;  // data from target to initiator
    logic        ack;    // transfer acknowledge from target
    logic        err;    // bus error from target
    logic        stall;  // target not ready (tie low for classic mode)

    modport initiator (
        output cyc, stb, we, sel, adr, dat_w,
        input  dat_r, ack, err, stall
    );

    modport target (
        input  cyc, stb, we, sel, adr, dat_w,
        output dat_r, ack, err, stall
    );

    // Used by interconnect/bus decoder modules that need full bidirectional
    // access — both driving signals toward slaves and reading responses back
    modport interconnect (
        inout  cyc, stb, we, sel, adr, dat_w,
               dat_r, ack, err, stall
    );

endinterface
