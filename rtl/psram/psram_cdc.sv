// =============================================================================
// psram_cdc.sv
// Clock domain crossing bridge between Wishbone (clk_sys) and PSRAM (clk_psram)
// =============================================================================

module psram_cdc (
    input  logic        clk_sys,
    input  logic        rst_sys_n,
    wishbone_if.target  wb,

    input  logic        clk_psram,
    input  logic        rst_psram_n,

    output logic        psram_req,
    output logic        psram_we,
    output logic [23:0] psram_addr,
    output logic [31:0] psram_wdata,
    input  logic        psram_ack,
    input  logic [31:0] psram_rdata
);

    logic req_sys;
    logic ack_sys_meta;
    logic ack_sys_sync;
    logic ack_sys_prev;

    always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
            req_sys      <= '0;
            wb.ack       <= '0;
            wb.err       <= '0;
            wb.dat_r     <= '0;
            ack_sys_meta <= '0;
            ack_sys_sync <= '0;
            ack_sys_prev <= '0;
            psram_we     <= '0;
            psram_addr   <= '0;
            psram_wdata  <= '0;
        end else begin
            wb.ack <= '0;

            ack_sys_meta <= psram_ack;
            ack_sys_sync <= ack_sys_meta;
            ack_sys_prev <= ack_sys_sync;

            if (!req_sys && !ack_sys_sync && !ack_sys_prev) begin
                if (wb.cyc && wb.stb) begin
                    req_sys     <= '1;
                    psram_we    <= wb.we;
                    psram_addr  <= wb.adr[23:0];
                    psram_wdata <= wb.dat_w;
                end
            end else if (req_sys) begin
                if (ack_sys_sync && !ack_sys_prev) begin
                    wb.ack   <= '1;
                    wb.dat_r <= psram_rdata;
                    req_sys  <= '0;
                end
            end
        end
    end

    assign wb.stall = '0;

    logic req_psram_meta;
    logic req_psram_sync;

    always_ff @(posedge clk_psram or negedge rst_psram_n) begin
        if (!rst_psram_n) begin
            req_psram_meta <= '0;
            req_psram_sync <= '0;
        end else begin
            req_psram_meta <= req_sys;
            req_psram_sync <= req_psram_meta;
        end
    end

    assign psram_req = req_psram_sync;

endmodule
