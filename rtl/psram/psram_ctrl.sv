// =============================================================================
// psram_ctrl.sv
// QPI PSRAM Controller — runs entirely on clk_psram
//
// Two APS6404L chips on shared SIO/SCLK bus with independent CE# lines:
//   Chip 0: addresses 0x000000 - 0x7FFFFF (addr[23] = 0)
//   Chip 1: addresses 0x800000 - 0xFFFFFF (addr[23] = 1)
//
// Both chips share the same SIO lines — only one CE# is asserted at a time.
// The full 16MB address space is byte-addressable.
//
// Wishbone sel signals are used to determine how many bytes to transfer:
//   sel = 4'b0001 — byte 0 only  (1 byte,  addr+0)
//   sel = 4'b0010 — byte 1 only  (1 byte,  addr+1)
//   sel = 4'b0100 — byte 2 only  (1 byte,  addr+2)
//   sel = 4'b1000 — byte 3 only  (1 byte,  addr+3)
//   sel = 4'b0011 — bytes 0-1    (2 bytes, addr+0)
//   sel = 4'b1100 — bytes 2-3    (2 bytes, addr+2)
//   sel = 4'b1111 — all bytes    (4 bytes, addr+0)
//
// For reads, always reads 4 bytes and masks the result using sel.
//
// clk_psram is 180° phase shifted from the PSRAM SCLK output, meaning:
//   - clk_psram rising edge  = SCLK falling edge -> state advances, outputs update
//   - clk_psram falling edge = SCLK rising edge  -> chip samples inputs
//
// SIO outputs are COMBINATORIAL based on current state, so they update
// immediately when state changes on posedge clk_psram, giving a full
// half-period of setup time before the chip samples on the next SCLK rising edge.
// =============================================================================

module psram_ctrl #(
    parameter int CLK_MHZ = 100
) (
    input  logic        clk_psram,
    input  logic        rst_n,

    input  logic        req,
    input  logic        we,
    input  logic [3:0]  sel,
    input  logic [23:0] addr,
    input  logic [31:0] wdata,
    output logic        ack,
    output logic [31:0] rdata,

    output logic        psram_ready,

    output logic        psram0_ce_n,
    output logic        psram1_ce_n,
    inout  wire  [3:0]  psram_sio       // shared SIO bus — only one chip active at a time
);
    timeunit 1ns;
    timeprecision 1ps;

    localparam int WAIT_150US       = CLK_MHZ * 150;
    localparam int WAIT_TRST        = (CLK_MHZ < 20) ? 1 : (CLK_MHZ / 20);
    localparam int WAIT_TCPH        = 1;
    localparam int QPI_DUMMY_CYCLES = (CLK_MHZ > 66) ? 6 : 4;

    localparam logic [7:0] CMD_RESET_EN  = 8'h66;
    localparam logic [7:0] CMD_RESET     = 8'h99;
    localparam logic [7:0] CMD_ENTER_QPI = 8'h35;
    localparam logic [7:0] CMD_QPI_READ  = 8'h0B;
    localparam logic [7:0] CMD_QPI_WRITE = 8'h38;

    typedef enum logic [6:0] {
        S_WAIT_PU,
        S_RESET_EN_0, S_RESET_EN_1, S_RESET_EN_2, S_RESET_EN_3,
        S_RESET_EN_4, S_RESET_EN_5, S_RESET_EN_6, S_RESET_EN_7,
        S_RESET_EN_DESEL,
        S_RESET_0, S_RESET_1, S_RESET_2, S_RESET_3,
        S_RESET_4, S_RESET_5, S_RESET_6, S_RESET_7,
        S_RESET_DESEL,
        S_ENTER_QPI_0, S_ENTER_QPI_1, S_ENTER_QPI_2, S_ENTER_QPI_3,
        S_ENTER_QPI_4, S_ENTER_QPI_5, S_ENTER_QPI_6, S_ENTER_QPI_7,
        S_ENTER_QPI_DESEL,
        S_READY,
        S_RD_CMD0, S_RD_CMD1,
        S_RD_ADDR0, S_RD_ADDR1, S_RD_ADDR2,
        S_RD_ADDR3, S_RD_ADDR4, S_RD_ADDR5,
        S_RD_DUMMY0, S_RD_DUMMY1, S_RD_DUMMY2, S_RD_DUMMY3,
        S_RD_DUMMY4, S_RD_DUMMY5,
        S_RD_DATA0, S_RD_DATA1, S_RD_DATA2, S_RD_DATA3,
        S_RD_DATA4, S_RD_DATA5, S_RD_DATA6, S_RD_DATA7,
        S_RD_DESEL, S_RD_DESEL2,
        S_WR_CMD0, S_WR_CMD1,
        S_WR_ADDR0, S_WR_ADDR1, S_WR_ADDR2,
        S_WR_ADDR3, S_WR_ADDR4, S_WR_ADDR5,
        S_WR_DATA0, S_WR_DATA1, S_WR_DATA2, S_WR_DATA3,
        S_WR_DATA4, S_WR_DATA5, S_WR_DATA6, S_WR_DATA7,
        S_WR_DESEL,
        S_WR_WAIT_REQ_LOW
    } state_t;

    state_t state;

    // =========================================================================
    // Registered inputs
    // =========================================================================
    logic [23:0] addr_r;
    logic [31:0] wdata_r;
    logic [3:0]  sel_r;

    // Chip select — determined by addr bit 23
    logic chip_sel;
    assign chip_sel = addr_r[23];

    // Byte address sent to chip — addr[22:0] adjusted for sel offset
    logic [22:0] chip_addr;
    always_comb begin
        case (sel_r)
            4'b0010: chip_addr = addr_r[22:0] + 23'd1;
            4'b0100: chip_addr = addr_r[22:0] + 23'd2;
            4'b1000: chip_addr = addr_r[22:0] + 23'd3;
            4'b1100: chip_addr = addr_r[22:0] + 23'd2;
            default: chip_addr = addr_r[22:0];
        endcase
    end

    // Write data bytes — reordered from wdata based on sel
    logic [7:0] wr_byte0, wr_byte1, wr_byte2, wr_byte3;
    always_comb begin
        case (sel_r)
            4'b0001: begin wr_byte0 = wdata_r[7:0];   wr_byte1 = '0;             wr_byte2 = '0;             wr_byte3 = '0;             end
            4'b0010: begin wr_byte0 = wdata_r[15:8];  wr_byte1 = '0;             wr_byte2 = '0;             wr_byte3 = '0;             end
            4'b0100: begin wr_byte0 = wdata_r[23:16]; wr_byte1 = '0;             wr_byte2 = '0;             wr_byte3 = '0;             end
            4'b1000: begin wr_byte0 = wdata_r[31:24]; wr_byte1 = '0;             wr_byte2 = '0;             wr_byte3 = '0;             end
            4'b0011: begin wr_byte0 = wdata_r[7:0];   wr_byte1 = wdata_r[15:8];  wr_byte2 = '0;             wr_byte3 = '0;             end
            4'b1100: begin wr_byte0 = wdata_r[23:16]; wr_byte1 = wdata_r[31:24]; wr_byte2 = '0;             wr_byte3 = '0;             end
            default: begin wr_byte0 = wdata_r[7:0];   wr_byte1 = wdata_r[15:8];  wr_byte2 = wdata_r[23:16]; wr_byte3 = wdata_r[31:24]; end
        endcase
    end

    // Last write data state based on sel
    function automatic state_t last_wr_data_state(input logic [3:0] s);
        case (s)
            4'b0001, 4'b0010,
            4'b0100, 4'b1000: last_wr_data_state = S_WR_DATA1;  // 1 byte
            4'b0011, 4'b1100: last_wr_data_state = S_WR_DATA3;  // 2 bytes
            default:          last_wr_data_state = S_WR_DATA7;  // 4 bytes
        endcase
    endfunction

    // =========================================================================
    // Combinatorial SIO output
    // =========================================================================
    logic [3:0] sio_out_comb;
    logic       sio_oe_comb;

    always_comb begin
        sio_out_comb = '0;
        sio_oe_comb  = '0;

        case (state)
            // SPI init — SIO[0] only
            S_RESET_EN_0: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[7]}; end
            S_RESET_EN_1: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[6]}; end
            S_RESET_EN_2: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[5]}; end
            S_RESET_EN_3: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[4]}; end
            S_RESET_EN_4: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[3]}; end
            S_RESET_EN_5: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[2]}; end
            S_RESET_EN_6: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[1]}; end
            S_RESET_EN_7: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET_EN[0]}; end

            S_RESET_0: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[7]}; end
            S_RESET_1: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[6]}; end
            S_RESET_2: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[5]}; end
            S_RESET_3: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[4]}; end
            S_RESET_4: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[3]}; end
            S_RESET_5: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[2]}; end
            S_RESET_6: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[1]}; end
            S_RESET_7: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_RESET[0]}; end

            S_ENTER_QPI_0: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[7]}; end
            S_ENTER_QPI_1: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[6]}; end
            S_ENTER_QPI_2: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[5]}; end
            S_ENTER_QPI_3: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[4]}; end
            S_ENTER_QPI_4: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[3]}; end
            S_ENTER_QPI_5: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[2]}; end
            S_ENTER_QPI_6: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[1]}; end
            S_ENTER_QPI_7: begin sio_oe_comb = '1; sio_out_comb = {3'b0, CMD_ENTER_QPI[0]}; end

            // QPI read command
            S_RD_CMD0: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_READ[7:4]; end
            S_RD_CMD1: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_READ[3:0]; end

            // QPI read address (23 bits, MSB padded with 0)
            S_RD_ADDR0: begin sio_oe_comb = '1; sio_out_comb = {1'b0, chip_addr[22:20]}; end
            S_RD_ADDR1: begin sio_oe_comb = '1; sio_out_comb = chip_addr[19:16]; end
            S_RD_ADDR2: begin sio_oe_comb = '1; sio_out_comb = chip_addr[15:12]; end
            S_RD_ADDR3: begin sio_oe_comb = '1; sio_out_comb = chip_addr[11:8];  end
            S_RD_ADDR4: begin sio_oe_comb = '1; sio_out_comb = chip_addr[7:4];   end
            S_RD_ADDR5: begin sio_oe_comb = '1; sio_out_comb = chip_addr[3:0];   end

            // QPI read dummy + data — release bus
            S_RD_DUMMY0, S_RD_DUMMY1, S_RD_DUMMY2, S_RD_DUMMY3,
            S_RD_DUMMY4, S_RD_DUMMY5,
            S_RD_DATA0, S_RD_DATA1, S_RD_DATA2, S_RD_DATA3,
            S_RD_DATA4, S_RD_DATA5, S_RD_DATA6, S_RD_DATA7: sio_oe_comb = '0;

            // QPI write command
            S_WR_CMD0: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_WRITE[7:4]; end
            S_WR_CMD1: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_WRITE[3:0]; end

            // QPI write address
            S_WR_ADDR0: begin sio_oe_comb = '1; sio_out_comb = {1'b0, chip_addr[22:20]}; end
            S_WR_ADDR1: begin sio_oe_comb = '1; sio_out_comb = chip_addr[19:16]; end
            S_WR_ADDR2: begin sio_oe_comb = '1; sio_out_comb = chip_addr[15:12]; end
            S_WR_ADDR3: begin sio_oe_comb = '1; sio_out_comb = chip_addr[11:8];  end
            S_WR_ADDR4: begin sio_oe_comb = '1; sio_out_comb = chip_addr[7:4];   end
            S_WR_ADDR5: begin sio_oe_comb = '1; sio_out_comb = chip_addr[3:0];   end

            // QPI write data — 8 nibbles = 4 bytes, MSB first within each byte
            S_WR_DATA0: begin sio_oe_comb = '1; sio_out_comb = wr_byte0[7:4]; end
            S_WR_DATA1: begin sio_oe_comb = '1; sio_out_comb = wr_byte0[3:0]; end
            S_WR_DATA2: begin sio_oe_comb = '1; sio_out_comb = wr_byte1[7:4]; end
            S_WR_DATA3: begin sio_oe_comb = '1; sio_out_comb = wr_byte1[3:0]; end
            S_WR_DATA4: begin sio_oe_comb = '1; sio_out_comb = wr_byte2[7:4]; end
            S_WR_DATA5: begin sio_oe_comb = '1; sio_out_comb = wr_byte2[3:0]; end
            S_WR_DATA6: begin sio_oe_comb = '1; sio_out_comb = wr_byte3[7:4]; end
            S_WR_DATA7: begin sio_oe_comb = '1; sio_out_comb = wr_byte3[3:0]; end

            default: sio_oe_comb = '0;
        endcase
    end

    // =========================================================================
    // SIO tristate
    // =========================================================================
    assign psram_sio = sio_oe_comb ? sio_out_comb : 4'bZZZZ;

    // =========================================================================
    // CE# logic
    // During init: both chips selected
    // During transactions: chip selected by addr_r[23]
    // Between transactions: both chips deselected
    // =========================================================================
    logic ce_n_active;

    always_comb begin
        case (state)
            S_WAIT_PU, S_RESET_EN_DESEL, S_RESET_DESEL,
            S_ENTER_QPI_DESEL, S_READY,
            S_RD_DESEL, S_RD_DESEL2,
            S_WR_DESEL, S_WR_WAIT_REQ_LOW: ce_n_active = '1;
            default:                        ce_n_active = '0;
        endcase
    end

    logic in_init;
    always_comb begin
        case (state)
            S_RESET_EN_0, S_RESET_EN_1, S_RESET_EN_2, S_RESET_EN_3,
            S_RESET_EN_4, S_RESET_EN_5, S_RESET_EN_6, S_RESET_EN_7,
            S_RESET_0, S_RESET_1, S_RESET_2, S_RESET_3,
            S_RESET_4, S_RESET_5, S_RESET_6, S_RESET_7,
            S_ENTER_QPI_0, S_ENTER_QPI_1, S_ENTER_QPI_2, S_ENTER_QPI_3,
            S_ENTER_QPI_4, S_ENTER_QPI_5, S_ENTER_QPI_6, S_ENTER_QPI_7: in_init = '1;
            default: in_init = '0;
        endcase
    end

    assign psram0_ce_n = ce_n_active ? '1 : (in_init ? '0 : ( chip_sel ? '1 : '0));
    assign psram1_ce_n = ce_n_active ? '1 : (in_init ? '0 : (~chip_sel ? '1 : '0));

    // =========================================================================
    // Read data capture + state machine
    // =========================================================================
    logic [31:0] read_data;
    logic [$clog2(WAIT_150US+1)-1:0] wait_cnt;

    always_ff @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_WAIT_PU;
            wait_cnt  <= '0;
            addr_r    <= '0;
            wdata_r   <= '0;
            sel_r     <= '0;
            ack       <= '0;
            rdata     <= '0;
            read_data <= '0;
        end else begin
            ack <= '0;

            case (state)

                S_WAIT_PU: begin
                    if (wait_cnt >= WAIT_150US) begin
                        wait_cnt <= '0;
                        state    <= S_RESET_EN_0;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                // Init
                S_RESET_EN_0:     state <= S_RESET_EN_1;
                S_RESET_EN_1:     state <= S_RESET_EN_2;
                S_RESET_EN_2:     state <= S_RESET_EN_3;
                S_RESET_EN_3:     state <= S_RESET_EN_4;
                S_RESET_EN_4:     state <= S_RESET_EN_5;
                S_RESET_EN_5:     state <= S_RESET_EN_6;
                S_RESET_EN_6:     state <= S_RESET_EN_7;
                S_RESET_EN_7:     state <= S_RESET_EN_DESEL;
                S_RESET_EN_DESEL: state <= S_RESET_0;

                S_RESET_0:     state <= S_RESET_1;
                S_RESET_1:     state <= S_RESET_2;
                S_RESET_2:     state <= S_RESET_3;
                S_RESET_3:     state <= S_RESET_4;
                S_RESET_4:     state <= S_RESET_5;
                S_RESET_5:     state <= S_RESET_6;
                S_RESET_6:     state <= S_RESET_7;
                S_RESET_7:     state <= S_RESET_DESEL;
                S_RESET_DESEL: begin
                    if (wait_cnt >= WAIT_TRST) begin
                        wait_cnt <= '0;
                        state    <= S_ENTER_QPI_0;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                S_ENTER_QPI_0:     state <= S_ENTER_QPI_1;
                S_ENTER_QPI_1:     state <= S_ENTER_QPI_2;
                S_ENTER_QPI_2:     state <= S_ENTER_QPI_3;
                S_ENTER_QPI_3:     state <= S_ENTER_QPI_4;
                S_ENTER_QPI_4:     state <= S_ENTER_QPI_5;
                S_ENTER_QPI_5:     state <= S_ENTER_QPI_6;
                S_ENTER_QPI_6:     state <= S_ENTER_QPI_7;
                S_ENTER_QPI_7:     state <= S_ENTER_QPI_DESEL;
                S_ENTER_QPI_DESEL: state <= S_READY;

                S_READY: begin
                    if (req) begin
                        addr_r  <= addr;
                        wdata_r <= wdata;
                        sel_r   <= sel;
                        state   <= we ? S_WR_CMD0 : S_RD_CMD0;
                    end
                end

                // Read
                S_RD_CMD0:   state <= S_RD_CMD1;
                S_RD_CMD1:   state <= S_RD_ADDR0;
                S_RD_ADDR0:  state <= S_RD_ADDR1;
                S_RD_ADDR1:  state <= S_RD_ADDR2;
                S_RD_ADDR2:  state <= S_RD_ADDR3;
                S_RD_ADDR3:  state <= S_RD_ADDR4;
                S_RD_ADDR4:  state <= S_RD_ADDR5;
                S_RD_ADDR5:  state <= S_RD_DUMMY0;
                S_RD_DUMMY0: state <= S_RD_DUMMY1;
                S_RD_DUMMY1: state <= S_RD_DUMMY2;
                S_RD_DUMMY2: state <= S_RD_DUMMY3;
                S_RD_DUMMY3: state <= (QPI_DUMMY_CYCLES > 4) ? S_RD_DUMMY4 : S_RD_DATA0;
                S_RD_DUMMY4: state <= S_RD_DUMMY5;
                S_RD_DUMMY5: state <= S_RD_DATA0;

                S_RD_DATA0: begin read_data[7:4]   <= psram_sio; state <= S_RD_DATA1; end
                S_RD_DATA1: begin read_data[3:0]   <= psram_sio; state <= S_RD_DATA2; end
                S_RD_DATA2: begin read_data[15:12] <= psram_sio; state <= S_RD_DATA3; end
                S_RD_DATA3: begin read_data[11:8]  <= psram_sio; state <= S_RD_DATA4; end
                S_RD_DATA4: begin read_data[23:20] <= psram_sio; state <= S_RD_DATA5; end
                S_RD_DATA5: begin read_data[19:16] <= psram_sio; state <= S_RD_DATA6; end
                S_RD_DATA6: begin read_data[31:28] <= psram_sio; state <= S_RD_DATA7; end
                S_RD_DATA7: begin read_data[27:24] <= psram_sio; state <= S_RD_DESEL; end

                S_RD_DESEL: state <= S_RD_DESEL2;

                S_RD_DESEL2: begin
                    if (wait_cnt >= WAIT_TCPH) begin
                        wait_cnt     <= '0;
                        rdata        <= read_data;
                        ack          <= '1;
                        state        <= S_READY;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                // Write
                S_WR_CMD0:  state <= S_WR_CMD1;
                S_WR_CMD1:  state <= S_WR_ADDR0;
                S_WR_ADDR0: state <= S_WR_ADDR1;
                S_WR_ADDR1: state <= S_WR_ADDR2;
                S_WR_ADDR2: state <= S_WR_ADDR3;
                S_WR_ADDR3: state <= S_WR_ADDR4;
                S_WR_ADDR4: state <= S_WR_ADDR5;
                S_WR_ADDR5: state <= S_WR_DATA0;
                S_WR_DATA0: state <= S_WR_DATA1;
                S_WR_DATA1: state <= (last_wr_data_state(sel_r) == S_WR_DATA1) ? S_WR_DESEL : S_WR_DATA2;
                S_WR_DATA2: state <= S_WR_DATA3;
                S_WR_DATA3: state <= (last_wr_data_state(sel_r) == S_WR_DATA3) ? S_WR_DESEL : S_WR_DATA4;
                S_WR_DATA4: state <= S_WR_DATA5;
                S_WR_DATA5: state <= S_WR_DATA6;
                S_WR_DATA6: state <= S_WR_DATA7;
                S_WR_DATA7: state <= S_WR_DESEL;

                S_WR_DESEL: begin
                    if (wait_cnt >= WAIT_TCPH) begin
                        wait_cnt <= '0;
                        ack      <= '1;
                        state    <= S_WR_WAIT_REQ_LOW;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                S_WR_WAIT_REQ_LOW: begin
                    if (!req) state <= S_READY;
                end

                default: state <= S_WAIT_PU;

            endcase
        end
    end

    assign psram_ready = (state == S_READY);

endmodule