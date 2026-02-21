// =============================================================================
// psram.sv
// Top-level PSRAM module — drop-in replacement for previous versions
//
// Instantiates:
//   psram_pll  — generates clk_psram and phase-shifted SCLK output
//   psram_cdc  — clock domain crossing between Wishbone and PSRAM clock
//   psram_ctrl — QPI state machine running on clk_psram
//
// Parameters:
//   CLK_MHZ   — system clock frequency (default 50)
//   PSRAM_MHZ — PSRAM clock frequency (1 for breadboard, 100 for production)
// =============================================================================

module psram #(
    parameter int CLK_MHZ   = 50,
    parameter int PSRAM_MHZ = 1
) (
    input  logic        clk,
    input  logic        rst_n,

    wishbone_if.target  bus,

    output logic        psram_ready,

    output logic        psram_ce_n,
    output logic        psram_sclk,    // driven directly from PLL phase-shifted clock
    inout  wire  [3:0]  psram0_sio,
    inout  wire  [3:0]  psram1_sio
);

    logic clk_psram;
    logic clk_psram_out;
    logic pll_locked;

    // Reset for PSRAM domain — hold in reset until PLL locked
    logic rst_psram_n;
    assign rst_psram_n = rst_n && pll_locked;

    // Phase-shifted clock goes directly to PSRAM SCLK pin
    assign psram_sclk = clk_psram_out;

    // =========================================================================
    // PLL
    // =========================================================================
    psram_pll #(
        .PSRAM_MHZ (PSRAM_MHZ)
    ) PLL (
        .clk_in        (clk),
        .rst_n         (rst_n),
        .clk_psram     (clk_psram),
        .clk_psram_out (clk_psram_out),
        .locked        (pll_locked)
    );

    // =========================================================================
    // CDC bridge signals
    // =========================================================================
    logic        psram_req;
    logic        psram_we;
    logic [23:0] psram_addr;
    logic [31:0] psram_wdata;
    logic        psram_ack;
    logic [31:0] psram_rdata;

    // =========================================================================
    // CDC bridge
    // =========================================================================
    psram_cdc CDC (
        .clk_sys      (clk),
        .rst_sys_n    (rst_n),
        .wb           (bus),
        .clk_psram    (clk_psram),
        .rst_psram_n  (rst_psram_n),
        .psram_req    (psram_req),
        .psram_we     (psram_we),
        .psram_addr   (psram_addr),
        .psram_wdata  (psram_wdata),
        .psram_ack    (psram_ack),
        .psram_rdata  (psram_rdata)
    );

    // =========================================================================
    // PSRAM controller
    // =========================================================================
    psram_ctrl #(
        .CLK_MHZ (PSRAM_MHZ)
    ) CTRL (
        .clk_psram    (clk_psram),
        .rst_n        (rst_psram_n),
        .req          (psram_req),
        .we           (psram_we),
        .addr         (psram_addr),
        .wdata        (psram_wdata),
        .ack          (psram_ack),
        .rdata        (psram_rdata),
        .psram_ready  (psram_ready),
        .psram_ce_n   (psram_ce_n),
        .psram0_sio   (psram0_sio),
        .psram1_sio   (psram1_sio)
    );

endmodule