
module soc_top (
    input wire clk,
    input wire rst_n,

    // Front panel outputs
    output logic        fp_busy_led,  // lights when SD card is being accessed

    // SA52 seven segment display (active low)
    output logic [7:0]  sa52_n,

    // Debug LED — shows PSRAM ready status
    output logic        debug_psram_ready,
    output logic        debug_sio_oe,

    // QSPI physical interface for PSRAM — shared data, separate chip selects
    output logic        psram0_ce_n,  // chip 0 select, active low
    output logic        psram1_ce_n,  // chip 1 select, active low
    output logic        psram_sclk,   // serial clock (both chips)
    inout  wire  [3:0]  psram_sio,    // chip quad I/O — data[15:0]

    // SPI physical interface for SD card
    output logic        sd_sclk,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n,

    // SPI physical interface for USB HID controller (Tang Nano 1K HID controller)
    output logic        usb_sclk,
    output logic        usb_mosi,
    input  logic        usb_miso,
    output logic        usb_cs_n,

    // IRQ input from Tang Nano 1K (active low, readable via STATUS)
    input  logic        usb_irq_n
);

    // =========================================================================
    // Wishbone interfaces
    // =========================================================================
    wishbone_if cpu_bus();     // CPU master side
    wishbone_if rom_bus();     // ROM target
    wishbone_if ram_bus();     // SRAM target
    wishbone_if io_bus();      // IO peripherals
    wishbone_if psram_bus();   // PSRAM target

    // PSRAM initialization status
    logic psram_ready;
    logic sio_oe;

    // =========================================================================
    // CPU — picorv32 Wishbone wrapper
    //
    // NOTE: wb_rst_i is active-high (the wrapper does resetn = ~wb_rst_i),
    //       so we pass ~rst_n.
    // =========================================================================
    picorv32_wb #(
        .PROGADDR_RESET (32'h0000_0000),
        .STACKADDR      (32'h2000_0200)  // top of 512 B RAM at 0x2000_0000
    ) cpu (
        .wb_clk_i   (clk),
        .wb_rst_i   (~rst_n),

        // Wishbone master → cpu_bus interface
        .wbm_adr_o  (cpu_bus.adr),
        .wbm_dat_o  (cpu_bus.dat_w),
        .wbm_dat_i  (cpu_bus.dat_r),
        .wbm_we_o   (cpu_bus.we),
        .wbm_sel_o  (cpu_bus.sel),
        .wbm_stb_o  (cpu_bus.stb),
        .wbm_cyc_o  (cpu_bus.cyc),
        .wbm_ack_i  (cpu_bus.ack),

        // Unused outputs
        .trap       (),
        .mem_instr  (),
        .trace_valid(),
        .trace_data (),

        // Tie off unused inputs
        .irq        (32'b0),
        .eoi        (),
        .pcpi_wr    (1'b0),
        .pcpi_rd    (32'b0),
        .pcpi_wait  (1'b0),
        .pcpi_ready (1'b0),
        .pcpi_valid (),
        .pcpi_insn  (),
        .pcpi_rs1   (),
        .pcpi_rs2   ()
    );

    // =========================================================================
    // Address decoder
    //
    // Memory map (top 4 bits of address):
    //   0x0xxx_xxxx → ROM   (4 KB)
    //   0x2xxx_xxxx → SRAM  (512 B)
    //   0x3xxx_xxxx → PSRAM (16 MB)
    //   0xFxxx_xxxx → IO    (peripherals)
    //
    // CPU pipeline stalls automatically during PSRAM initialization.
    // =========================================================================
    always_comb begin
        // Defaults — nothing selected
        rom_bus.cyc   = '0;  rom_bus.stb   = '0;
        rom_bus.we    = '0;  rom_bus.sel   = '0;
        rom_bus.adr   = '0;  rom_bus.dat_w = '0;

        ram_bus.cyc   = '0;  ram_bus.stb   = '0;
        ram_bus.we    = '0;  ram_bus.sel   = '0;
        ram_bus.adr   = '0;  ram_bus.dat_w = '0;

        io_bus.cyc    = '0;  io_bus.stb    = '0;
        io_bus.we     = '0;  io_bus.sel    = '0;
        io_bus.adr    = '0;  io_bus.dat_w  = '0;

        psram_bus.cyc   = '0;  psram_bus.stb   = '0;
        psram_bus.we    = '0;  psram_bus.sel   = '0;
        psram_bus.adr   = '0;  psram_bus.dat_w = '0;

        cpu_bus.dat_r = '0;
        cpu_bus.ack   = '0;
        cpu_bus.err   = '0;
        cpu_bus.stall = '0;

        if (cpu_bus.adr[31:28] == 4'hF) begin
            // ---- IO region ----
            io_bus.cyc    = cpu_bus.cyc;
            io_bus.stb    = cpu_bus.stb;
            io_bus.we     = cpu_bus.we;
            io_bus.sel    = cpu_bus.sel;
            io_bus.adr    = cpu_bus.adr;
            io_bus.dat_w  = cpu_bus.dat_w;

            cpu_bus.dat_r = io_bus.dat_r;
            cpu_bus.ack   = io_bus.ack;
            cpu_bus.err   = io_bus.err;
            cpu_bus.stall = io_bus.stall;
        end else if (cpu_bus.adr[31:28] == 4'h2) begin
            // ---- SRAM region ----
            ram_bus.cyc   = cpu_bus.cyc;
            ram_bus.stb   = cpu_bus.stb;
            ram_bus.we    = cpu_bus.we;
            ram_bus.sel   = cpu_bus.sel;
            ram_bus.adr   = cpu_bus.adr;
            ram_bus.dat_w = cpu_bus.dat_w;

            cpu_bus.dat_r = ram_bus.dat_r;
            cpu_bus.ack   = ram_bus.ack;
            cpu_bus.err   = ram_bus.err;
            cpu_bus.stall = ram_bus.stall;
        end else if (cpu_bus.adr[31:28] == 4'h3) begin
            // ---- PSRAM region ----
            psram_bus.cyc   = cpu_bus.cyc;
            psram_bus.stb   = cpu_bus.stb;
            psram_bus.we    = cpu_bus.we;
            psram_bus.sel   = cpu_bus.sel;
            psram_bus.adr   = cpu_bus.adr;
            psram_bus.dat_w = cpu_bus.dat_w;

            cpu_bus.dat_r = psram_bus.dat_r;
            cpu_bus.ack   = psram_bus.ack;
            cpu_bus.err   = psram_bus.err;
            // Stall if PSRAM is still initializing
            cpu_bus.stall = (!psram_ready) | psram_bus.stall;
        end else begin
            // ---- ROM region (default) ----
            rom_bus.cyc   = cpu_bus.cyc;
            rom_bus.stb   = cpu_bus.stb;
            rom_bus.we    = cpu_bus.we;
            rom_bus.sel   = cpu_bus.sel;
            rom_bus.adr   = cpu_bus.adr;
            rom_bus.dat_w = cpu_bus.dat_w;

            cpu_bus.dat_r = rom_bus.dat_r;
            cpu_bus.ack   = rom_bus.ack;
            cpu_bus.err   = rom_bus.err;
            cpu_bus.stall = rom_bus.stall;
        end
    end

    // =========================================================================
    // Boot ROM — 4 KB at 0x0000_0000
    // =========================================================================
    rom #(.SIZE(1024)) ROM (
        .clk    (clk),
        .rst_n  (rst_n),
        .bus    (rom_bus)
    );

    // =========================================================================
    // Scratchpad SRAM — 0x2000_0000
    // =========================================================================
    sram #(.SIZE(128)) SRAM (
        .clk    (clk),
        .rst_n  (rst_n),
        .bus    (ram_bus)
    );

    // =========================================================================
    // IO Peripherals — 0xF000_0000
    // =========================================================================
    io_top IO (
        .clk    (clk),
        .rst_n  (rst_n),
        .bus    (io_bus),

        .fp_busy_led(fp_busy_led),

        .sa52_n (sa52_n),

        .sd_sclk (sd_sclk),
        .sd_mosi (sd_mosi),
        .sd_miso (sd_miso),
        .sd_cs_n (sd_cs_n),

        .usb_sclk (usb_sclk),
        .usb_mosi (usb_mosi),
        .usb_miso (usb_miso),
        .usb_cs_n (usb_cs_n),
        .usb_irq_n (usb_irq_n)
    );

    // =========================================================================
    // PSRAM — 0x3000_0000
    // =========================================================================
    psram #(.CLK_MHZ(50), .PSRAM_MHZ(25)) PSRAM (
        .clk          (clk),
        .rst_n        (rst_n),
        .bus          (psram_bus),
        .psram_ready  (psram_ready),
        .psram0_ce_n  (psram0_ce_n),
        .psram1_ce_n  (psram1_ce_n),
        .psram_sclk   (psram_sclk),
        .psram_sio    (psram_sio)
    );

    // =========================================================================
    // Debug output — PSRAM ready status (active low)
    // =========================================================================
    assign debug_psram_ready = ~psram_ready;
    assign debug_sio_oe      = ~sio_oe;

endmodule