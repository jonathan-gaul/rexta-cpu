// =============================================================================
// psram_pll.sv
// PLL wrapper for PSRAM clocks
//
// Generates two clocks from the 50MHz system clock:
//   clk_psram         — 100MHz, used by PSRAM state machine
//   clk_psram_shifted — 100MHz, 180° phase shifted, output directly as PSRAM SCLK
//
// To switch to 1MHz for breadboard testing, set PSRAM_MHZ = 1.
// The PLL configuration changes but nothing else does.
//
// Parameters:
//   PSRAM_MHZ — target PSRAM clock frequency (1 for breadboard, 100 for production)
// =============================================================================

module psram_pll #(
    parameter int PSRAM_MHZ = 1
) (
    input  logic clk_in,        // 50MHz system clock
    input  logic rst_n,
    output logic clk_psram,     // PSRAM state machine clock
    output logic clk_psram_out, // Phase-shifted clock for PSRAM SCLK pin
    output logic locked
);

generate
    if (PSRAM_MHZ == 100) begin : gen_100mhz
        // 50MHz -> 100MHz, with 180° shifted output
        // VCO = 50 * 4 = 200MHz, C0 = /2 = 100MHz, C1 = /2 = 100MHz phase shifted 180°
        altpll #(
            .intended_device_family  ("Cyclone IV E"),
            .lpm_type                ("altpll"),
            .pll_type                ("AUTO"),
            .operation_mode          ("NORMAL"),
            .inclk0_input_frequency  (20000),   // 50MHz = 20000ps period
            .clk0_multiply_by        (2),
            .clk0_divide_by          (1),
            .clk0_phase_shift        ("0"),
            .clk1_multiply_by        (2),
            .clk1_divide_by          (1),
            .clk1_phase_shift        ("5000"),  // 180° at 100MHz = 5000ps
            .compensate_clock        ("CLK0"),
            .width_clock             (2)
        ) pll_inst (
            .inclk  ({1'b0, clk_in}),
            .clk    ({clk_psram_out, clk_psram}),
            .locked (locked),
            .areset (~rst_n)
        );
    end else begin : gen_1mhz
        // 50MHz -> 1MHz using simple clock divider
        // PLL not used — just divide down for breadboard testing
        // clk_psram_out is phase inverted version of clk_psram
        logic [4:0] div_cnt;
        logic       clk_div;

        always_ff @(posedge clk_in or negedge rst_n) begin
            if (!rst_n) begin
                div_cnt <= '0;
                clk_div <= '0;
            end else begin
                if (div_cnt >= 24) begin
                    div_cnt <= '0;
                    clk_div <= ~clk_div;
                end else begin
                    div_cnt <= div_cnt + 1;
                end
            end
        end

        assign clk_psram     = clk_div;
        assign clk_psram_out = ~clk_div;  // 180° shift = invert
        assign locked        = rst_n;
    end
endgenerate

endmodule
