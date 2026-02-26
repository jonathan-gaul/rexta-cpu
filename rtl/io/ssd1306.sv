// =============================================================================
// ssd1306.sv
// SSD1306 OLED Display Controller
//
// SPI interface controller for SSD1306 128x64 OLED display.
//
// The SSD1306 has a command/data interface via SPI:
//   - Commands are sent with DC=0
//   - Data is sent with DC=1
//
// Pin mapping:
//   D0  (sclk) = SPI Clock
//   D1  (mosi) = SPI Data (MOSI)
//   RES (res)  = Reset (active low)
//   DC  (dc)   = Data/Command select (0=command, 1=data)
//   CS  (cs_n) = Chip Select (active low)
//
// Register map (word addressed):
//   0x00  DATA     [7:0]  Data byte to write to display
//   0x04  CMD      [7:0]  Command byte to send to display
//   0x08  CTRL     [0]    busy (read-only, 1=busy, 0=ready)
//                 [1]    reset (write 1 to assert, auto-clears after reset pulse)
//   0x0C  STATUS   [7:0]  Read-only status register
//
// The controller has a simple state machine that sends bytes via SPI when
// either DATA or CMD register is written. Writing to CMD asserts DC=0,
// writing to DATA asserts DC=1.
// =============================================================================

module ssd1306 #(
    parameter int CLK_MHZ = 50,     // System clock frequency
    parameter int SPI_MHZ = 8       // SPI clock frequency (max 10 MHz for SSD1306)
) (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone target interface
    wishbone_if.target  bus,

    // SSD1306 SPI physical interface
    output logic        ssd_sclk,   // SPI clock (D0)
    output logic        ssd_mosi,   // SPI data (D1)
    output logic        ssd_res_n,  // Reset (active low)
    output logic        ssd_dc,     // Data/Command select (0=cmd, 1=data)
    output logic        ssd_cs_n    // Chip select (active low)
);
    timeunit 1ns;
    timeprecision 1ps;

    // =========================================================================
    // SPI timing parameters
    // =========================================================================
    localparam int SPI_DIV = (CLK_MHZ + SPI_MHZ - 1) / SPI_MHZ / 2;  // Half period in clocks
    localparam int SPI_DIV_WIDTH = $clog2(SPI_DIV + 1);

    // Reset pulse duration (100 µs minimum for SSD1306)
    localparam int RESET_CYCLES = CLK_MHZ * 100;  // 100 µs at CLK_MHZ
    localparam int RESET_WIDTH = $clog2(RESET_CYCLES + 1);

    // =========================================================================
    // Registers
    // =========================================================================
    logic [7:0]                   tx_data;
    logic                         tx_start;
    logic                         tx_busy;
    logic                         dc_mode;    // 0=command, 1=data
    logic [RESET_WIDTH-1:0]       reset_counter;
    logic                         reset_req;

    // =========================================================================
    // SPI transmit state machine
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE,
        SCLK_LOW,
        SCLK_HIGH,
        DONE
    } spi_state_t;

    spi_state_t                   spi_state;
    logic [2:0]                   bit_counter;
    logic [SPI_DIV_WIDTH-1:0]     clk_divider;
    logic [7:0]                   shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_state   <= IDLE;
            bit_counter <= '0;
            clk_divider <= '0;
            shift_reg   <= '0;
            ssd_sclk    <= '0;
            ssd_mosi    <= '0;
            ssd_cs_n    <= '1;
            ssd_dc      <= '0;
            tx_busy     <= '0;
        end else begin
            case (spi_state)
                IDLE: begin
                    ssd_cs_n    <= '1;
                    ssd_sclk    <= '0;
                    tx_busy     <= '0;
                    
                    if (tx_start) begin
                        shift_reg   <= tx_data;
                        bit_counter <= 7;
                        clk_divider <= SPI_DIV_WIDTH'(SPI_DIV - 1);
                        ssd_cs_n    <= '0;
                        ssd_dc      <= dc_mode;
                        tx_busy     <= '1;
                        spi_state   <= SCLK_LOW;
                    end
                end

                SCLK_LOW: begin
                    ssd_mosi <= shift_reg[7];
                    ssd_sclk <= '0;
                    
                    if (clk_divider == 0) begin
                        clk_divider <= SPI_DIV_WIDTH'(SPI_DIV - 1);
                        spi_state   <= SCLK_HIGH;
                    end else begin
                        clk_divider <= clk_divider - 1;
                    end
                end

                SCLK_HIGH: begin
                    ssd_sclk <= '1;
                    
                    if (clk_divider == 0) begin
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        clk_divider <= SPI_DIV_WIDTH'(SPI_DIV - 1);
                        
                        if (bit_counter == 0) begin
                            spi_state <= DONE;
                        end else begin
                            bit_counter <= bit_counter - 1;
                            spi_state   <= SCLK_LOW;
                        end
                    end else begin
                        clk_divider <= clk_divider - 1;
                    end
                end

                DONE: begin
                    ssd_sclk  <= '0;
                    ssd_cs_n  <= '1;
                    tx_busy   <= '0;
                    spi_state <= IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    // Reset control
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_counter <= '0;
            ssd_res_n     <= '0;  // Assert reset on power-up
        end else begin
            if (reset_req) begin
                reset_counter <= RESET_WIDTH'(RESET_CYCLES - 1);
                ssd_res_n     <= '0;
            end else if (reset_counter != 0) begin
                reset_counter <= reset_counter - 1;
                ssd_res_n     <= '0;
            end else begin
                ssd_res_n     <= '1;
            end
        end
    end

    // =========================================================================
    // Wishbone interface
    // =========================================================================
    assign bus.stall = '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start  <= '0;
            tx_data   <= '0;
            dc_mode   <= '0;
            reset_req <= '1;  // Request reset on startup
            bus.ack   <= '0;
            bus.err   <= '0;
            bus.dat_r <= '0;
        end else begin
            bus.ack   <= '0;
            bus.err   <= '0;
            tx_start  <= '0;
            reset_req <= '0;

            if (bus.cyc && bus.stb && !bus.ack) begin
                bus.ack <= '1;

                unique case (bus.adr[3:2])
                    2'h0: begin     // DATA register
                        if (bus.we && !tx_busy) begin
                            tx_data  <= bus.dat_w[7:0];
                            dc_mode  <= '1;  // Data mode
                            tx_start <= '1;
                        end else begin
                            bus.dat_r <= {24'b0, tx_data};
                        end
                    end

                    2'h1: begin     // CMD register
                        if (bus.we && !tx_busy) begin
                            tx_data  <= bus.dat_w[7:0];
                            dc_mode  <= '0;  // Command mode
                            tx_start <= '1;
                        end else begin
                            bus.dat_r <= {24'b0, tx_data};
                        end
                    end

                    2'h2: begin     // CTRL register
                        if (bus.we) begin
                            reset_req <= bus.dat_w[1];
                        end else begin
                            bus.dat_r <= {30'b0, reset_req, tx_busy};
                        end
                    end

                    2'h3: begin     // STATUS register (read-only)
                        bus.dat_r <= {24'b0, 6'b0, ssd_res_n, tx_busy};
                    end

                    default: bus.err <= '1;
                endcase
            end
        end
    end

endmodule
