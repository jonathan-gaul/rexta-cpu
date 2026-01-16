`include "alu_opcode.sv"

module alu(
    input  wire [7:0]   a,
    input  wire [7:0]   b,
    input  wire         carry_in,
    input  reg  [3:0]   op,         // can't use an enum for this as ModelSim doesn't seem to support it
    output reg  [7:0]   result,
    output reg          carry_out,
    output reg          zero
);

always @(*) begin
    case (op)
        `ALU_ADD: {carry_out, result} = a + b + carry_in;
        `ALU_SUB: {carry_out, result} = a - b - ~carry_in;
        `ALU_SHL: begin
            result    = a << 1;
            carry_out = a[7];
        end
        `ALU_SHR: begin
            result    = a >> 1;
            carry_out = a[0];
        end
        `ALU_ROL: begin
            result    = {a[6:0], carry_in};
            carry_out = a[7];
        end
        `ALU_ROR: begin
            result    = {carry_in, a[7:1]};
            carry_out = a[0];
        end
        `ALU_NOT: begin
            result    = ~a;
            carry_out = 1'b0;
        end
        default: begin
            result = 8'h00;
            carry_out = 1'b0;
        end
    endcase

    zero = (result == 8'h00);
end

endmodule
