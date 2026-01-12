// ALU

module alu (
	 input [7:0] a,
    input [7:0] b,
    input [2:0] op,       // ADD/SUB/AND/OR/etc
	 input carry_in,
	 output reg[7:0] result,
	 output reg carry_out	 
);

	always @(*) begin

		  case(op)
            3'b000: {carry_out, result} = a + b + carry_in;
            3'b001: {carry_out, result} = a - b - (8'h01 - carry_in);
            3'b010: {carry_out, result} = {1'b0, a & b};
            3'b011: {carry_out, result} = {1'b0, a | b};
				3'b100: {carry_out, result} = {1'b0, a ^ b};
				3'b111: {carry_out, result} = {1'b0, ~a};
				default: {carry_out, result} = {1'b0, a};
        endcase

	end

endmodule