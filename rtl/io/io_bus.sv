// =============================================================================
// io_bus.sv
// IO Bus Decoder
//
// Decodes the peripheral region (0xF0000000 - 0xFFFFFFFF) and routes
// Wishbone transactions to individual peripherals via an interface array.
//
// Each peripheral gets a 4 KB window, indexed by adr[13:12] (etc.).
//
// Peripheral map (4 KB slices):
//   Index 0 — 0xF0000000 - 0xF0000FFF  SA52 display
//   Index 1 — 0xF0001000 - 0xF0001FFF  (reserved)
//   ...
//
// To add a peripheral: increment DEVICE_COUNT in io_top and add a decode entry.
// Unrecognised addresses return a bus error.
// =============================================================================

module io_bus #(
    parameter int DEVICE_COUNT = 1
) (
    input  logic clk,
    input  logic rst_n,

    wishbone_if    bus,
    wishbone_if    periph[DEVICE_COUNT]
);
    timeunit 1ns;
    timeprecision 1ps;

    // =========================================================================
    // Address decode — bits [12 +: $clog2(DEVICE_COUNT)] index the peripheral
    // Each peripheral gets a 4 KB slice
    // =========================================================================
    localparam int IDX_BITS = (DEVICE_COUNT > 1) ? $clog2(DEVICE_COUNT) : 1;

    logic [DEVICE_COUNT-1:0] sel;
    logic                    sel_invalid;
    logic [IDX_BITS-1:0]     sel_idx;

    always_comb begin
        sel         = '0;
        sel_invalid = '0;
        sel_idx     = '0;

        if (bus.cyc) begin
            sel_idx = bus.adr[12 +: IDX_BITS];
            if (int'(sel_idx) < DEVICE_COUNT) begin
                sel[sel_idx] = '1;
            end else begin
                sel_invalid = bus.stb;
            end
        end
    end

    // =========================================================================
    // Drive peripheral bus signals
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < DEVICE_COUNT; i++) begin : gen_periph_drive
            assign periph[i].cyc   = bus.cyc && sel[i];
            assign periph[i].stb   = bus.stb && sel[i];
            assign periph[i].we    = bus.we;
            assign periph[i].sel   = bus.sel;
            assign periph[i].adr   = bus.adr;
            assign periph[i].dat_w = bus.dat_w;
        end
    endgenerate

    // =========================================================================
    // Gather peripheral responses
    // =========================================================================
    logic [DEVICE_COUNT-1:0] periph_ack;
    logic [DEVICE_COUNT-1:0] periph_err;
    logic [31:0]             periph_dat_r [DEVICE_COUNT];

    genvar j;
    generate
        for (j = 0; j < DEVICE_COUNT; j++) begin : gen_periph_resp
            assign periph_ack[j]   = periph[j].ack;
            assign periph_err[j]   = periph[j].err;
            assign periph_dat_r[j] = periph[j].dat_r;
        end
    endgenerate

    always_comb begin
        bus.ack   = '0;
        bus.err   = '0;
        bus.dat_r = '0;

        if (sel_invalid) begin
            bus.err   = '1;
            bus.dat_r = 32'hDEAD_BEEF;
        end else begin
            for (int k = 0; k < DEVICE_COUNT; k++) begin
                if (sel[k]) begin
                    bus.ack   = periph_ack[k];
                    bus.err   = periph_err[k];
                    bus.dat_r = periph_dat_r[k];
                end
            end
        end
    end

    assign bus.stall = '0;

endmodule
