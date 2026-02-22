// =============================================================================
// psram.sv
// Top-level PSRAM wrapper
//
// Two APS6404L chips on shared SIO/SCLK bus with independent CE# lines.
// Chip 0 handles addresses 0x000000-0x7FFFFF (addr[23]=0)
// Chip 1 handles addresses 0x800000-0xFFFFFF (addr[23]=1)
// =============================================================================

module psram #(
    parameter int CLK_MHZ   = 50,
    parameter int PSRAM_MHZ = 1
) (
    input  logic        clk,
    input  logic        rst_n,

    wishbone_if.target  bus,

    output logic        psram_ready,

    output logic        psram0_ce_n,
    output logic        psram1_ce_n,
    output logic        psram_sclk,
    inout  wire  [3:0]  psram_sio       // shared SIO bus
);

    logic clk_psram;
    logic clk_psram_out;
    logic pll_locked;

    logic rst_psram_n;
    assign rst_psram_n = rst_n && pll_locked;

    assign psram_sclk = clk_psram_out;

    psram_pll #(.PSRAM_MHZ(PSRAM_MHZ)) PLL (
        .clk_in        (clk),
        .rst_n         (rst_n),
        .clk_psram     (clk_psram),
        .clk_psram_out (clk_psram_out),
        .locked        (pll_locked)
    );

    logic        psram_req;
    logic        psram_we;
    logic [3:0]  psram_sel;
    logic [23:0] psram_addr;
    logic [31:0] psram_wdata;
    logic        psram_ack;
    logic [31:0] psram_rdata;

    psram_cdc CDC (
        .clk_sys      (clk),
        .rst_sys_n    (rst_n),
        .wb           (bus),
        .clk_psram    (clk_psram),
        .rst_psram_n  (rst_psram_n),
        .psram_req    (psram_req),
        .psram_we     (psram_we),
        .psram_sel    (psram_sel),
        .psram_addr   (psram_addr),
        .psram_wdata  (psram_wdata),
        .psram_ack    (psram_ack),
        .psram_rdata  (psram_rdata)
    );

    psram_ctrl #(.CLK_MHZ(PSRAM_MHZ)) CTRL (
        .clk_psram    (clk_psram),
        .rst_n        (rst_psram_n),
        .req          (psram_req),
        .we           (psram_we),
        .sel          (psram_sel),
        .addr         (psram_addr),
        .wdata        (psram_wdata),
        .ack          (psram_ack),
        .rdata        (psram_rdata),
        .psram_ready  (psram_ready),
        .psram0_ce_n  (psram0_ce_n),
        .psram1_ce_n  (psram1_ce_n),
        .psram_sio    (psram_sio)
    );

endmodule
