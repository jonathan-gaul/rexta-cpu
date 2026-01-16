`include "cpu_state.sv"
`include "cpu_opcode.sv"
`include "alu.sv"
`include "ram.sv"

module cpu_top (
	input wire clk,
	input wire reset_n,
	output wire [4:0] leds
);

// registers
logic [23:0] pc;    			// program counter
logic [23:0] sp;    			// stack pointer
cpu_opcode_t ir; 				// instruction register (current instruction)
logic [7:0] ir_l; 				// ir low byte

logic [7:0] regs [0:15]; 		// 16 user registers

logic [7:0] ops [0:7];			// 8 operand registers

logic carry;					// carry flag
logic zero;						// zero flag
logic [7:0] temp;				// temp register for e.g. zero checks

assign leds = regs[0][4:0];

// Parts of IR
wire [2:0] op_count = ir[11:9];	// 3-bit op count (max 7 operands)
wire [1:0] ir_width = ir[1:0];	// 2-bit instruction width (0, 1, 2, 3)

// Parts of OP
wire [3:0] rd = ops[0][7:4];	// xxxx---- rd always in high nibble of ops[0] if present
wire [3:0] rs = ops[0][3:0];	// ----xxxx rs always in low nibble of ops[0] if present

cpu_state_t state;				// current state
logic [2:0] state_ctr;			// state counter

integer i; 				// temp counter

// memory module
logic [23:0] mem_addr;
logic mem_write;
logic [7:0] mem_in;
logic [7:0] mem_out;
logic [1:0] load_wait;				// > 0 if memory access was requested and we need to wait
parameter MEM_WAIT = 2'h2; 		// number of cycles to wait for memory ops
ram #(
	.ADDR_WIDTH(24),
	.DATA_WIDTH(8)
) ram_inst (
	.clk(clk),
	.write(mem_write),
	.addr(mem_addr),
	.din(mem_in),
	.dout(mem_out)
);

// ALU module
logic [3:0]		alu_op;
logic [7:0] 	alu_a, alu_b;
logic       	alu_cin;
logic [7:0] 	alu_result;
logic       	alu_cout;
logic			alu_zf;

alu alu_inst (
    .a(alu_a),
    .b(alu_b),
    .carry_in(alu_cin),
    .op(alu_op),
    .result(alu_result),
    .carry_out(alu_cout),
    .zero(alu_zf)
);

wire reset = ~reset_n;
always_ff @( posedge clk or posedge reset ) begin : main

	if (reset) begin
		pc <= 16'h0000;
		sp <= 16'h0000;
		load_wait <= 0;
		state_ctr <= 0;
		state <= STATE_FETCH_IR;
		carry <= 0;
		zero <= 0;
	end else begin
		case (state)

			STATE_RESET: begin
				for (i = 0; i < 16; i = i + 1) begin
					regs[i] <= 0;
				end

				pc <= 16'h0000;
				sp <= 16'h1000;
				state_ctr <= 0;
				state <= STATE_FETCH_IR;
				load_wait <= 0;
				mem_addr <= 0;
				mem_write <= 0;
				mem_in <= 0;
			end

			STATE_FETCH_IR: begin
				if (!load_wait) begin
					// Step 1: set RAM address
					mem_addr <= pc;
					pc <= pc + 24'h000001;
					load_wait <= MEM_WAIT;            // wait for mem_out to be valid next clock
				end else begin
					if (load_wait == 1) begin
						// Step 2: capture instruction byte
						if (!state_ctr) begin
							ir_l <= mem_out;
							load_wait <= 0;
							state_ctr <= 1;
						end else begin
							ir <= cpu_opcode_t'({mem_out, ir_l});
							load_wait <= 0;
							state_ctr <= 0;
							state <= STATE_FETCH_OP;
						end
					end else begin
						load_wait <= load_wait - 2'h1;
					end
				end
			end

			STATE_FETCH_OP: begin
				if (state_ctr == op_count) begin
					state_ctr <= 0;
					load_wait <= 0;
					state <= STATE_EXECUTE;
				end else if (!load_wait) begin
					// Step 1: set RAM address
					mem_addr <= pc;
					pc <= pc + 24'h000001;
					load_wait <= MEM_WAIT;        // wait one clock for mem_out
				end else begin
					load_wait <= load_wait - 2'h1;
					if (load_wait == 1) begin
						// Step 2: capture the operand byte
						ops[state_ctr] <= mem_out;
						state_ctr <= state_ctr + 3'h1;
					end
				end
			end

			STATE_EXECUTE: begin
				case (ir)

					// ----------------------------------------
					// LOADI
					// ----------------------------------------
					OP_LOADI1, OP_LOADI2, OP_LOADI3: begin
						if (state_ctr == ir_width) begin
							state_ctr <= 0;
							state <= STATE_FETCH_IR;
						end else begin
							regs[rd + state_ctr] = ops[state_ctr + 1];
							state_ctr <= state_ctr + 3'h1;
						end
					end

					// ----------------------------------------
					// LOAD
					// ----------------------------------------
					OP_LOAD1, OP_LOAD2, OP_LOAD3: begin
						if (!load_wait) begin
							// Step 1: set memory address
							mem_addr <= {ops[3], ops[2], ops[1]} + state_ctr;
							load_wait <= MEM_WAIT;
						end else begin
							if (load_wait == 1) begin
								// Step 2: capture mem_out
								regs[rd + state_ctr] <= mem_out;
								state_ctr <= state_ctr + 3'h1;
								load_wait <= 0;          // reset for next byte
								if (state_ctr == ir_width) begin
									state_ctr <= 0;
									state <= STATE_FETCH_IR;
								end
							end else begin
								load_wait <= load_wait - 2'h1;
							end
						end
					end

					// ----------------------------------------
					// STORE
					// ----------------------------------------
					OP_STORE1, OP_STORE2, OP_STORE3: begin
						if (!load_wait) begin
							// Step 1: set memory address & data to write
							mem_addr <= {ops[3], ops[2], ops[1]} + state_ctr;
							mem_in <= regs[rs + state_ctr];
							mem_write <= 1;
							load_wait <= 1;
						end else begin
							// Step 2: wait for write.
							mem_write <= 0;
							load_wait <= 0;
							state_ctr <= state_ctr + 3'h1;
							if (state_ctr == ir_width) begin
								state_ctr <= 0;
								state <= STATE_FETCH_IR;
							end
						end
					end

					// ----------------------------------------
					// ADD
					// ----------------------------------------
					OP_ADD1, OP_ADD2, OP_ADD3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= regs[rs + state_ctr];
								alu_op <= `ALU_ADD;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// ADDI
					// ----------------------------------------
					OP_ADDI1, OP_ADDI2, OP_ADDI3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= ops[1 + state_ctr];
								alu_op <= `ALU_ADD;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// SUB
					// ----------------------------------------
					OP_SUB1, OP_SUB2, OP_SUB3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= regs[rs + state_ctr];
								alu_op <= `ALU_SUB;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// SUBI
					// ----------------------------------------
					OP_SUBI1, OP_SUBI2, OP_SUBI3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= ops[1 + state_ctr];
								alu_op <= `ALU_SUB;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// AND
					// ----------------------------------------
					OP_AND1, OP_AND2, OP_AND3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= regs[rs + state_ctr];
								alu_op <= `ALU_AND;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// OR
					// ----------------------------------------
					OP_OR1, OP_OR2, OP_OR3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= regs[rs + state_ctr];
								alu_op <= `ALU_OR;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// XOR
					// ----------------------------------------
					OP_XOR1, OP_XOR2, OP_XOR3: begin
						if (state_ctr == ir_width + 1) begin
							state_ctr <= 0;
							zero <= (temp == 8'h00);
							state <= STATE_FETCH_IR;
						end else begin
							if (!load_wait) begin
								alu_a <= regs[rd + state_ctr];
								alu_b <= regs[rs + state_ctr];
								alu_op <= `ALU_XOR;
								alu_cin <= carry;
								load_wait <= 1; // get result at next clock edge
							end else begin
								regs[rd + state_ctr] <= alu_result;
								carry <= alu_cout;

								if (!state_ctr) begin
									temp <= alu_result;
								end else begin
									temp <= temp | alu_result;
								end

								load_wait <= 0;
								state_ctr <= state_ctr + 3'h1;
							end
						end
					end

					// ----------------------------------------
					// MOV
					// ----------------------------------------
					OP_MOV1, OP_MOV2, OP_MOV3: begin
						regs[rd] <= regs[rs];
						temp = regs[rs];

						if (ir_width > 1) begin
							regs[rd+1] <= regs[rs+1];
							temp = temp | regs[rs+1];
						end

						if (ir_width > 2) begin
							regs[rd+2] <= regs[rs+2];
							temp = temp | regs[rs+2];
						end

						zero <= temp == 8'h00;
					end

					// ----------------------------------------
					// JMP
					// ----------------------------------------
					OP_JMP: begin
						pc <= {ops[2], ops[1], ops[0]};
						state_ctr <= 0;
						state <= STATE_FETCH_IR;
					end

					// ----------------------------------------
					// JCS
					// ----------------------------------------
					OP_JCS: begin
						if (carry) begin
							state_ctr <= 0;
							state <= STATE_FETCH_IR;
							pc <= {ops[2], ops[1], ops[0]};
						end
					end

					// ----------------------------------------
					// JZS
					// ----------------------------------------
					OP_JZS: begin
						if (zero) begin
							state_ctr <= 0;
							state <= STATE_FETCH_IR;
							pc <= {ops[2], ops[1], ops[0]};
						end
					end

					// ----------------------------------------
					// JCN
					// ----------------------------------------
					OP_JCN: begin
						if (!carry) begin
							state_ctr <= 0;
							state <= STATE_FETCH_IR;
							pc <= {ops[2], ops[1], ops[0]};
						end
					end

					// ----------------------------------------
					// JZN
					// ----------------------------------------
					OP_JZN: begin
						if (!zero) begin
							state_ctr <= 0;
							state <= STATE_FETCH_IR;
							pc <= {ops[2], ops[1], ops[0]};
						end
					end

					// ----------------------------------------
					// CLC
					// ----------------------------------------
					OP_CLC: begin
						carry <= 0;
						state_ctr <= 0;
						state <= STATE_FETCH_IR;
					end

					// ----------------------------------------
					// SEC
					// ----------------------------------------
					OP_SEC: begin
						carry <= 1;
						state_ctr <= 0;
						state <= STATE_FETCH_IR;
					end

					// ----------------------------------------
					// HLT
					// ----------------------------------------
					OP_HLT: begin
						state_ctr <= 0;
						state <= STATE_HALT;
					end

					default: begin
						state_ctr <= 0;
						state <= STATE_FETCH_IR;
					end
				endcase
			end

			STATE_HALT: begin
				// noop
			end
		endcase
	end
end

endmodule
