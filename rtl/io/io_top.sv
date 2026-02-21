// =============================================================================
// periph_top.sv
// Peripheral Subsystem Top Level
//
// Peripheral array index map: (*** not implemented yet)
//   [0] SA52 display        0xF0000000 
//   [1] SD card controller  0xF0001000
//   [2] Timer/counter       0xF0002000  ***
//   [3] Interrupt ctrl      0xF0003000  ***
//   [4] SPI master          0xF0004000  ***
//   [5] GPIO output         0xF0005000  ***
// =============================================================================

module io_top #(
    parameter int CLK_MHZ = 50
) (
    input  logic        clk,
    input  logic        rst_n,

    // Front panel
    output logic        fp_busy_led,  // for slow I/O

    // From SoC Wishbone interconnect
    wishbone_if.target  bus,

    // SD card physical interface
    output logic        sd_sclk,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n,

    // Generic SPI physical interface (for future peripherals)
    // output logic        spi_sclk,
    // output logic        spi_mosi,
    // input  logic        spi_miso,
    // output logic        spi_cs_n,   // software controlled via SPI CTRL register

    // External interrupt lines
    // input  logic [3:0]  ext_irq,

    // CPU interrupt line
    // output logic        irq_out,

    // SA52 seven segment display (active low)
    output logic [7:0]  sa52_n

    // Debug GPIO output — software writable, connected to LEDs
    // output logic [7:0]  gpio_out
);
    timeunit 1ns;
    timeprecision 1ps;

    localparam int DEVICE_COUNT = 2;  // number of peripherals in the system

    // =========================================================================
    // Peripheral interface array
    // =========================================================================
    wishbone_if devices[DEVICE_COUNT]();

    // =========================================================================
    // Internal interrupt wires
    // =========================================================================
    logic timer_irq;
    logic spi_irq;

    // =========================================================================
    // Peripheral bus decoder
    // =========================================================================
    io_bus #(
        .DEVICE_COUNT (DEVICE_COUNT)
    ) BUS_DECODER (
        .clk    (clk),
        .rst_n  (rst_n),
        .bus    (bus),
        .periph (devices)
    );

    // =========================================================================
    // SA52 seven segment display
    // =========================================================================
    sa52 SA52 (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus        (devices[0]),
        .seg_n      (sa52_n)
    );    

    // =========================================================================
    // SD card controller
    // =========================================================================
    sd_ctrl #(
        .CLK_MHZ (CLK_MHZ)
    ) SD (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus        (devices[1]),
        .sd_sclk    (sd_sclk),
        .sd_mosi    (sd_mosi),
        .sd_miso    (sd_miso),
        .sd_cs_n    (sd_cs_n)
    );

    logic [19:0] sd_activity_stretch;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sd_activity_stretch <= '0;
        else if (devices[1].ack)
            sd_activity_stretch <= '1;  // reload on activity
        else if (sd_activity_stretch != '0)
            sd_activity_stretch <= sd_activity_stretch - 1;
    end

    assign fp_busy_led = ~(sd_activity_stretch != '0);

    // =========================================================================
    // Interrupt controller
    // =========================================================================
    // irq_ctrl IRQ (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .bus        (devices[1]),
    //     .ext_irq    (ext_irq),
    //     .timer_irq  (timer_irq),
    //     .spi_irq    (spi_irq),
    //     .irq_out    (irq_out)
    // );

    // =========================================================================
    // Timer
    // =========================================================================
    // timer TIMER (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .bus        (devices[2]),
    //     .timer_irq  (timer_irq)
    // );



    // =========================================================================
    // Generic SPI master
    // =========================================================================
    // spi_master SPI (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .bus        (devices[4]),
    //     .spi_sclk   (spi_sclk),
    //     .spi_mosi   (spi_mosi),
    //     .spi_miso   (spi_miso)
    // );

    // assign spi_irq  = '0;
    // assign spi_cs_n = '1;

    // =========================================================================
    // GPIO output
    // =========================================================================
    // gpio GPIO (
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .bus        (devices[5]),
    //     .gpio_out   (gpio_out)
    // );

endmodule
