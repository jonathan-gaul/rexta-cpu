// Driver for the SA52 single-digit LED

module sa52 (
    input logic [7:0] value,
    output logic [7:0] seg // Mapping: dot, g, f, e, d, c, b, a
);

always_comb begin 
    case (value)
        // Segments: g f e d c b a (0 is ON)
        8'h0: seg = 8'b11000000;
        8'h1: seg = 8'b11111001;
        8'h2: seg = 8'b10100100;
        8'h3: seg = 8'b10110000;
        8'h4: seg = 8'b10011001;
        8'h5: seg = 8'b10010010;
        8'h6: seg = 8'b10000010;
        8'h7: seg = 8'b11111000;
        8'h8: seg = 8'b10000000;
        8'h9: seg = 8'b10010000;
        8'hA: seg = 8'b10001000;
        8'hB: seg = 8'b10000011;
        8'hC: seg = 8'b11000110;
        8'hD: seg = 8'b10100001;
        8'hE: seg = 8'b10000110;
        8'hF: seg = 8'b10001110;
        default: seg = 8'b11111111; // All OFF
    endcase
end

endmodule