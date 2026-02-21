// =============================================================================
// psram_ctrl.sv
// QPI PSRAM Controller — runs entirely on clk_psram
//
// clk_psram is 180° phase shifted from the PSRAM SCLK output, meaning:
//   - clk_psram rising edge  = SCLK falling edge -> state advances, outputs update
//   - clk_psram falling edge = SCLK rising edge  -> chip samples inputs
//
// SIO outputs are COMBINATORIAL based on current state, so they update
// immediately when state changes on posedge clk_psram, giving a full
// half-period of setup time before the chip samples on the next SCLK rising edge.
//
// Read data is captured on negedge clk_psram (= SCLK rising edge).
// =============================================================================

module psram_ctrl #(
    parameter int CLK_MHZ = 100
) (
    input  logic        clk_psram,
    input  logic        rst_n,

    input  logic        req,
    input  logic        we,
    input  logic [23:0] addr,
    input  logic [31:0] wdata,
    output logic        ack,
    output logic [31:0] rdata,

    output logic        psram_ready,

    output logic        psram_ce_n,
    inout  wire  [3:0]  psram0_sio,
    inout  wire  [3:0]  psram1_sio
);
    timeunit 1ns;
    timeprecision 1ps;

    localparam int WAIT_150US     = CLK_MHZ * 150;
    localparam int WAIT_TRST      = (CLK_MHZ < 20) ? 1 : (CLK_MHZ / 20);
    localparam int WAIT_TCPH      = 1;
    localparam int QPI_DUMMY_CYCLES = (CLK_MHZ > 66) ? 6 : 4;

    localparam logic [7:0] CMD_RESET_EN  = 8'h66;
    localparam logic [7:0] CMD_RESET     = 8'h99;
    localparam logic [7:0] CMD_ENTER_QPI = 8'h35;
    localparam logic [7:0] CMD_QPI_READ  = 8'h0B;
    localparam logic [7:0] CMD_QPI_WRITE = 8'h38;

    typedef enum logic [5:0] {
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
        S_RD_DESEL,
        S_RD_DESEL2,
        S_WR_CMD0, S_WR_CMD1,
        S_WR_ADDR0, S_WR_ADDR1, S_WR_ADDR2,
        S_WR_ADDR3, S_WR_ADDR4, S_WR_ADDR5,
        S_WR_DATA0, S_WR_DATA1, S_WR_DATA2, S_WR_DATA3,
        S_WR_DESEL,
        S_WR_WAIT_REQ_LOW
    } state_t;

    state_t state;

    // =========================================================================
    // Registered address and data — captured from inputs when transaction starts
    // =========================================================================
    logic [23:0] addr_r;
    logic [31:0] wdata_r;

    // =========================================================================
    // Combinatorial SIO output — based purely on current state
    // Updates immediately when state changes, no clock delay
    // =========================================================================
    logic [3:0] sio_out_comb;
    logic [3:0] sio0_out_comb;
    logic [3:0] sio1_out_comb;
    logic       sio_oe_comb;
    logic       sio_data_phase_comb;

    always_comb begin
        sio_out_comb        = '0;
        sio0_out_comb       = '0;
        sio1_out_comb       = '0;
        sio_oe_comb         = '0;
        sio_data_phase_comb = '0;

        case (state)
            // SPI init — drive SIO[0] only
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

            // QPI read address
            S_RD_ADDR0: begin sio_oe_comb = '1; sio_out_comb = addr_r[23:20]; end
            S_RD_ADDR1: begin sio_oe_comb = '1; sio_out_comb = addr_r[19:16]; end
            S_RD_ADDR2: begin sio_oe_comb = '1; sio_out_comb = addr_r[15:12]; end
            S_RD_ADDR3: begin sio_oe_comb = '1; sio_out_comb = addr_r[11:8];  end
            S_RD_ADDR4: begin sio_oe_comb = '1; sio_out_comb = addr_r[7:4];   end
            S_RD_ADDR5: begin sio_oe_comb = '1; sio_out_comb = addr_r[3:0];   end

            // QPI read dummy + data — bus released (high-Z)
            S_RD_DUMMY0, S_RD_DUMMY1, S_RD_DUMMY2, S_RD_DUMMY3,
            S_RD_DUMMY4, S_RD_DUMMY5,
            S_RD_DATA0, S_RD_DATA1, S_RD_DATA2, S_RD_DATA3: begin
                sio_oe_comb = '0;
            end

            // QPI write command
            S_WR_CMD0: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_WRITE[7:4]; end
            S_WR_CMD1: begin sio_oe_comb = '1; sio_out_comb = CMD_QPI_WRITE[3:0]; end

            // QPI write address
            S_WR_ADDR0: begin sio_oe_comb = '1; sio_out_comb = addr_r[23:20]; end
            S_WR_ADDR1: begin sio_oe_comb = '1; sio_out_comb = addr_r[19:16]; end
            S_WR_ADDR2: begin sio_oe_comb = '1; sio_out_comb = addr_r[15:12]; end
            S_WR_ADDR3: begin sio_oe_comb = '1; sio_out_comb = addr_r[11:8];  end
            S_WR_ADDR4: begin sio_oe_comb = '1; sio_out_comb = addr_r[7:4];   end
            S_WR_ADDR5: begin sio_oe_comb = '1; sio_out_comb = addr_r[3:0];   end

            // QPI write data — chip0 carries [15:0], chip1 carries [31:16]
            S_WR_DATA0: begin
                sio_oe_comb         = '1;
                sio_data_phase_comb = '1;
                sio0_out_comb       = wdata_r[15:12];
                sio1_out_comb       = wdata_r[31:28];
            end
            S_WR_DATA1: begin
                sio_oe_comb         = '1;
                sio_data_phase_comb = '1;
                sio0_out_comb       = wdata_r[11:8];
                sio1_out_comb       = wdata_r[27:24];
            end
            S_WR_DATA2: begin
                sio_oe_comb         = '1;
                sio_data_phase_comb = '1;
                sio0_out_comb       = wdata_r[7:4];
                sio1_out_comb       = wdata_r[23:20];
            end
            S_WR_DATA3: begin
                sio_oe_comb         = '1;
                sio_data_phase_comb = '1;
                sio0_out_comb       = wdata_r[3:0];
                sio1_out_comb       = wdata_r[19:16];
            end

            default: begin
                sio_oe_comb = '0;
            end
        endcase
    end

    // =========================================================================
    // SIO tristate — driven by combinatorial signals
    // =========================================================================
    assign psram0_sio = sio_oe_comb ? (sio_data_phase_comb ? sio0_out_comb : sio_out_comb) : 4'bZZZZ;
    assign psram1_sio = sio_oe_comb ? (sio_data_phase_comb ? sio1_out_comb : sio_out_comb) : 4'bZZZZ;

    // =========================================================================
    // CE# — combinatorial based on state
    // =========================================================================
    always_comb begin
        case (state)
            S_WAIT_PU, S_RESET_EN_DESEL, S_RESET_DESEL,
            S_ENTER_QPI_DESEL, S_READY,
            S_RD_DESEL, S_RD_DESEL2,
            S_WR_DESEL, S_WR_WAIT_REQ_LOW: psram_ce_n = '1;
            default:                 psram_ce_n = '0;
        endcase
    end

    // =========================================================================
    // Read data capture — on negedge clk_psram (= SCLK rising edge)
    // =========================================================================
    logic [31:0] read_data;

    // =========================================================================
    // State machine — advances on posedge clk_psram (= SCLK falling edge)
    // =========================================================================
    logic [$clog2(WAIT_150US+1)-1:0] wait_cnt;

    always_ff @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_WAIT_PU;
            wait_cnt <= '0;
            addr_r   <= '0;
            wdata_r  <= '0;
            ack      <= '0;
            rdata    <= '0;
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

                // Init sequence — simple state chain
                S_RESET_EN_0:    state <= S_RESET_EN_1;
                S_RESET_EN_1:    state <= S_RESET_EN_2;
                S_RESET_EN_2:    state <= S_RESET_EN_3;
                S_RESET_EN_3:    state <= S_RESET_EN_4;
                S_RESET_EN_4:    state <= S_RESET_EN_5;
                S_RESET_EN_5:    state <= S_RESET_EN_6;
                S_RESET_EN_6:    state <= S_RESET_EN_7;
                S_RESET_EN_7:    state <= S_RESET_EN_DESEL;
                S_RESET_EN_DESEL: state <= S_RESET_0;

                S_RESET_0:       state <= S_RESET_1;
                S_RESET_1:       state <= S_RESET_2;
                S_RESET_2:       state <= S_RESET_3;
                S_RESET_3:       state <= S_RESET_4;
                S_RESET_4:       state <= S_RESET_5;
                S_RESET_5:       state <= S_RESET_6;
                S_RESET_6:       state <= S_RESET_7;
                S_RESET_7:       state <= S_RESET_DESEL;
                S_RESET_DESEL: begin
                    if (wait_cnt >= WAIT_TRST) begin
                        wait_cnt <= '0;
                        state    <= S_ENTER_QPI_0;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                S_ENTER_QPI_0:   state <= S_ENTER_QPI_1;
                S_ENTER_QPI_1:   state <= S_ENTER_QPI_2;
                S_ENTER_QPI_2:   state <= S_ENTER_QPI_3;
                S_ENTER_QPI_3:   state <= S_ENTER_QPI_4;
                S_ENTER_QPI_4:   state <= S_ENTER_QPI_5;
                S_ENTER_QPI_5:   state <= S_ENTER_QPI_6;
                S_ENTER_QPI_6:   state <= S_ENTER_QPI_7;
                S_ENTER_QPI_7:   state <= S_ENTER_QPI_DESEL;
                S_ENTER_QPI_DESEL: state <= S_READY;

                S_READY: begin
                    if (req) begin
                        addr_r  <= addr;
                        wdata_r <= wdata;
                        state   <= we ? S_WR_CMD0 : S_RD_CMD0;
                    end
                end

                // Read sequence
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
                S_RD_DATA0:  begin read_data[31:28] <= psram1_sio; read_data[15:12] <= psram0_sio; state <= S_RD_DATA1; end
                S_RD_DATA1:  begin read_data[27:24] <= psram1_sio; read_data[11:8]  <= psram0_sio; state <= S_RD_DATA2; end
                S_RD_DATA2:  begin read_data[23:20] <= psram1_sio; read_data[7:4]   <= psram0_sio; state <= S_RD_DATA3; end
                S_RD_DATA3:  begin read_data[19:16] <= psram1_sio; read_data[3:0]   <= psram0_sio; state <= S_RD_DESEL; end

                S_RD_DESEL:  state <= S_RD_DESEL2;

                S_RD_DESEL2: begin
                    if (wait_cnt >= WAIT_TCPH) begin
                        wait_cnt <= '0;
                        rdata    <= read_data;
                        ack      <= '1;
                        state    <= S_READY;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                // Write sequence
                S_WR_CMD0:   state <= S_WR_CMD1;
                S_WR_CMD1:   state <= S_WR_ADDR0;
                S_WR_ADDR0:  state <= S_WR_ADDR1;
                S_WR_ADDR1:  state <= S_WR_ADDR2;
                S_WR_ADDR2:  state <= S_WR_ADDR3;
                S_WR_ADDR3:  state <= S_WR_ADDR4;
                S_WR_ADDR4:  state <= S_WR_ADDR5;
                S_WR_ADDR5:  state <= S_WR_DATA0;
                S_WR_DATA0:  state <= S_WR_DATA1;
                S_WR_DATA1:  state <= S_WR_DATA2;
                S_WR_DATA2:  state <= S_WR_DATA3;
                S_WR_DATA3:  state <= S_WR_DESEL;
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
                    // Wait for req to go low before accepting next transaction
                    // This ensures req_psram_sync has settled after the write ack
                    if (!req) state <= S_READY;
                end

                default: state <= S_WAIT_PU;

            endcase
        end
    end

    assign psram_ready = (state == S_READY);

endmodule
