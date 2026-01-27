import rexta::*;

///////////////////////////////////////////////////////
// ALU - Arithmetic Logic Unit                       //
//---------------------------------------------------//
// Handles arithmetic operations.                    //
///////////////////////////////////////////////////////

module alu (
    // Interface
    input  logic [31:0] a,          // Connected to read_data1
    input  logic [31:0] b,          // Connected to read_data2
    input  alu_op_t     op,         // Which math operation?
    output logic [31:0] result,     // The answer
	output logic        is_zero
);

    always_comb begin
		case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
			ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            default:  result = 32'd0;
        endcase
    end

	assign is_zero = (result == 32'h0);

endmodule
