module sd (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] din,
    input  logic [7:0] clk_divider,
    input  logic       start,
    input  logic       cs_in,      // CS control from CPU
    output logic [7:0] dout,
    output logic       busy,
    
    // Physical Pins
    output logic       sd_cs,
    output logic       sd_sclk,
    output logic       sd_mosi,
    input  logic       sd_miso
);

    // Pass the CS register directly to the pin
    assign sd_cs = cs_in;

    // Instantiate the engine
    spi_master engine (
        .clk(clk),
        .reset(reset),
        .din(din),
        .clk_divider(clk_divider),
        .start(start),
        .dout(dout),
        .busy(busy),
        .sclk(sd_sclk),
        .mosi(sd_mosi),
        .miso(sd_miso)
    );

endmodule