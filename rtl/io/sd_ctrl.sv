// =============================================================================
// sd_ctrl.sv
// SD Card SPI Controller Peripheral
//
// Provides low-level SPI byte transfer for SD card communication.
// Higher-level SD initialisation and FAT filesystem logic is handled in
// firmware running on the CPU.
//
// Each transaction sends and receives one byte simultaneously (full duplex).
//
// Register map (word addressed):
//   0x00  DATA     [7:0]  write: byte to transmit
//                         read:  last received byte
//   0x04  CONTROL  [0]    start: write 1 to begin a byte transfer
//                  [1]    cs: chip select (1 = assert CS low, 0 = deassert)
//   0x08  STATUS   [0]    busy: 1 = transfer in progress
//   0x0C  DIVIDER  [7:0]  clock divider (SCLK = clk / (2 * DIVIDER))
//                         default 255 = ~100KHz on 50MHz clock for init
//
// Note: SD cards require at least 74 clock cycles with CS deasserted and
// MOSI high before sending the first command. Handle in firmware by sending
// dummy 0xFF bytes with CS deasserted.
//
// Parameters:
//   CLK_MHZ — system clock frequency in MHz
// =============================================================================

module sd_ctrl #(
    parameter int CLK_MHZ = 50
) (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone target interface
    wishbone_if.target  bus,

    // SD card SPI physical interface
    output logic        sd_sclk,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n
);
    timeunit 1ns;
    timeprecision 1ps;

    // =========================================================================
    // Registers
    // =========================================================================
    logic [7:0]  tx_data;       // byte to transmit
    logic [7:0]  rx_data;       // last received byte
    logic        cs_reg;        // chip select state (1 = asserted / CS low)
    logic [7:0]  divider;       // clock divider value

    // =========================================================================
    // SPI state machine
    // =========================================================================
    typedef enum logic [1:0] {
        S_IDLE,
        S_TRANSFER,
        S_DONE
    } spi_state_t;

    spi_state_t spi_state;

    logic        busy;
    logic        start;         // pulse from Wishbone to start a transfer
    logic [2:0]  bit_cnt;
    logic [7:0]  shift_out;
    logic [7:0]  shift_in;
    logic [7:0]  div_cnt;
    logic        sclk_reg;
    logic        sclk_rising;
    logic        sclk_falling;
    logic        sclk_en;

    assign sd_cs_n = ~cs_reg;
    assign sd_sclk = sclk_reg;
    assign sd_mosi = shift_out[7];

    // =========================================================================
    // Clock divider
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt      <= '0;
            sclk_reg     <= '0;
            sclk_rising  <= '0;
            sclk_falling <= '0;
        end else begin
            sclk_rising  <= '0;
            sclk_falling <= '0;
            if (sclk_en) begin
                if (div_cnt >= divider) begin
                    div_cnt  <= '0;
                    sclk_reg <= ~sclk_reg;
                end else begin
                    div_cnt <= div_cnt + 1;
                    if (div_cnt == divider - 1) begin
                        if (sclk_reg == 1'b0)
                            sclk_rising  <= '1;
                        else
                            sclk_falling <= '1;
                    end
                end
            end else begin
                div_cnt  <= '0;
                sclk_reg <= '0;
            end
        end
    end

    // =========================================================================
    // SPI transfer state machine
    // Sole driver of: spi_state, shift_out, shift_in, rx_data, busy, sclk_en
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_state <= S_IDLE;
            sclk_en   <= '0;
            shift_out <= '1;
            shift_in  <= '0;
            rx_data   <= '0;
            bit_cnt   <= '0;
            busy      <= '0;
        end else begin
            case (spi_state)

                S_IDLE: begin
                    sclk_en <= '0;
                    busy    <= '0;
                    if (start) begin
                        shift_out <= tx_data;
                        bit_cnt   <= '0;
                        spi_state <= S_TRANSFER;
                    end
                end

                S_TRANSFER: begin
                    sclk_en <= '1;
                    busy    <= '1;
                    if (sclk_falling) begin
                        shift_out <= {shift_out[6:0], 1'b1};
                    end
                    if (sclk_rising) begin
                        shift_in <= {shift_in[6:0], sd_miso};
                        if (bit_cnt == 3'd7) begin
                            bit_cnt   <= '0;
                            spi_state <= S_DONE;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                S_DONE: begin
                    sclk_en   <= '0;
                    rx_data   <= shift_in;
                    busy      <= '0;
                    spi_state <= S_IDLE;
                end

                default: spi_state <= S_IDLE;

            endcase
        end
    end

    // =========================================================================
    // Wishbone register interface
    // Sole driver of: tx_data, cs_reg, divider, start, bus.*
    // =========================================================================
    assign bus.stall = '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data   <= '1;
            cs_reg    <= '0;
            divider   <= 8'd255;
            start     <= '0;
            bus.ack   <= '0;
            bus.err   <= '0;
            bus.dat_r <= '0;
        end else begin
            bus.ack <= '0;
            bus.err <= '0;
            start   <= '0;      // pulse for one cycle only

            if (bus.cyc && bus.stb && !bus.ack) begin
                bus.ack <= '1;

                unique case (bus.adr[3:2])
                    2'h0: begin     // DATA
                        if (bus.we)
                            tx_data <= bus.dat_w[7:0];
                        else
                            bus.dat_r <= {24'b0, rx_data};
                    end
                    2'h1: begin     // CONTROL
                        if (bus.we) begin
                            cs_reg <= bus.dat_w[1];
                            if (bus.dat_w[0] && !busy)
                                start <= '1;
                        end else begin
                            bus.dat_r <= {30'b0, cs_reg, 1'b0};
                        end
                    end
                    2'h2: begin     // STATUS
                        if (!bus.we)
                            bus.dat_r <= {31'b0, busy};
                    end
                    2'h3: begin     // DIVIDER
                        if (bus.we)
                            divider <= bus.dat_w[7:0];
                        else
                            bus.dat_r <= {24'b0, divider};
                    end
                    default: bus.err <= '1;
                endcase
            end
        end
    end

endmodule
