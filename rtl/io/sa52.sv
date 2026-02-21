// =============================================================================
// sa52.sv
// SA52 Seven Segment Display Peripheral
//
// Drives a single digit SA52 seven segment display (active low outputs).
// Segments are labelled a-g plus decimal point (dp) in standard orientation:
//
//    _
//   |_|
//   |_|.
//
//  Segment mapping:
//    seg[0] = a (top)
//    seg[1] = b (top right)
//    seg[2] = c (bottom right)
//    seg[3] = d (bottom)
//    seg[4] = e (bottom left)
//    seg[5] = f (top left)
//    seg[6] = g (middle)
//    seg[7] = dp (decimal point)
//
// Register map (word addressed):
//   0x00  DISPLAY  [3:0]  hex digit to display (0-F), hardware decodes to segments
//                 [4]    decimal point (1 = on)
//                 [5]    blank (1 = all segments off)
//   0x04  RAW      [7:0]  raw segment control (overrides DISPLAY if CTRL raw_mode=1)
//   0x08  CTRL     [0]    raw_mode (0 = decode hex digit, 1 = use RAW register)
//
// Outputs are active low to match SA52 common anode configuration.
// =============================================================================

module sa52 (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone target interface
    wishbone_if.target  bus,

    // SA52 display outputs (active low)
    output logic [7:0]  seg_n   // [7]=dp [6]=g [5]=f [4]=e [3]=d [2]=c [1]=b [0]=a
);
    timeunit 1ns;
    timeprecision 1ps;

    // =========================================================================
    // Registers
    // =========================================================================
    logic [3:0] digit;
    logic       dp;
    logic       blank;
    logic [7:0] raw;
    logic       raw_mode;

    // =========================================================================
    // Hex to seven segment decoder
    // Produces active high segments, inverted at output
    // =========================================================================
    logic [6:0] decoded;    // segments a-g, active high

    always_comb begin
        unique case (digit)
            4'h0: decoded = 7'b0111111;  // 0
            4'h1: decoded = 7'b0000110;  // 1
            4'h2: decoded = 7'b1011011;  // 2
            4'h3: decoded = 7'b1001111;  // 3
            4'h4: decoded = 7'b1100110;  // 4
            4'h5: decoded = 7'b1101101;  // 5
            4'h6: decoded = 7'b1111101;  // 6
            4'h7: decoded = 7'b0000111;  // 7
            4'h8: decoded = 7'b1111111;  // 8
            4'h9: decoded = 7'b1101111;  // 9
            4'hA: decoded = 7'b1110111;  // A
            4'hB: decoded = 7'b1111100;  // b
            4'hC: decoded = 7'b0111001;  // C
            4'hD: decoded = 7'b1011110;  // d
            4'hE: decoded = 7'b1111001;  // E
            4'hF: decoded = 7'b1110001;  // F
        endcase
    end

    // =========================================================================
    // Output logic — invert for active low SA52
    // =========================================================================
    logic [7:0] active_high;

    always_comb begin
        if (blank) begin
            active_high = '0;                           // all off
        end else if (raw_mode) begin
            active_high = raw;                          // direct segment control
        end else begin
            active_high = {dp, decoded};                // decoded digit + dp
        end
    end

    assign seg_n     = ~active_high;    // active low for SA52
    assign bus.stall = '0;

    // =========================================================================
    // Wishbone register interface
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit     <= '0;
            dp        <= '0;
            blank     <= '1;        // start blanked
            raw       <= '0;
            raw_mode  <= '0;
            bus.ack   <= '0;
            bus.err   <= '0;
            bus.dat_r <= '0;
        end else begin
            bus.ack <= '0;
            bus.err <= '0;

            if (bus.cyc && bus.stb && !bus.ack) begin
                bus.ack <= '1;

                unique case (bus.adr[3:2])
                    2'h0: begin     // DISPLAY
                        if (bus.we) begin
                            digit <= bus.dat_w[3:0];
                            dp    <= bus.dat_w[4];
                            blank <= bus.dat_w[5];
                        end else begin
                            bus.dat_r <= {26'b0, blank, dp, digit};
                        end
                    end
                    2'h1: begin     // RAW
                        if (bus.we)
                            raw <= bus.dat_w[7:0];
                        else
                            bus.dat_r <= {24'b0, raw};
                    end
                    2'h2: begin     // CTRL
                        if (bus.we)
                            raw_mode <= bus.dat_w[0];
                        else
                            bus.dat_r <= {31'b0, raw_mode};
                    end
                    default: bus.err <= '1;
                endcase
            end
        end
    end

endmodule
