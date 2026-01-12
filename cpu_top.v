`include "opcodes.v"
`include "states.v"

module cpu_top (
	input wire clk,
	input wire reset,
	output wire [2:0] leds
);

	// Program Counter - 24-bit
	reg [23:0] pc;
		
	// Registers - 8-bit x REG_COUNT
	parameter REG_COUNT = 9;
	reg [7:0] regs [0:REG_COUNT-1];
	assign leds = ~regs[0][2:0]; // LEDs on board show lowest 3 bits of R0
	
	parameter RAM_SIZE = 1024;
	// Simple program RAM
	reg [7:0] ram [0:RAM_SIZE-1] /* synthesis ram_init_file = "program1.mif" */;
			
	// State register
	reg [2:0] state;
	reg [2:0] substate; // Substate/state counter

	
	// 16-bit Instruction Register
	reg [15:0] ir;
	
	// Instructin width from instruction register
	wire [1:0] instruction_width;
	assign instruction_width = ir[1:0];
	
	// Operand count from instruction register
	wire [2:0] operand_count;
	assign operand_count = ir[11:9];
	
	// 8-bit Operand registers x7
	reg [7:0] operands [0:8];
	
	// If Rd is present, it is always in the upper 4 bits of operands[0]	
	wire [4:0] rd = operands[0][7:4];
	// If Rs is present, it is always in the lower 4 bits of operands[0]
	wire [4:0] rs = operands[0][3:0];
	
	// FLAGS (carry, zero)
	reg cf, zf;
			
	integer i;
	reg [7:0] temp_byte; // Temporary buffer byte for e.g. ZF checks
	reg carry; // Temp carry for multibyte arithmetic
	
	// ALU	
	reg [7:0] reg_a;
	reg [7:0] reg_b;
	reg [3:0] alu_op;
	reg carry_in;
	wire [7:0] alu_out;
	wire alu_carry;	
	alu alu_inst (
	  .a(reg_a),
	  .b(reg_b),
	  .op(alu_op),
	  .carry_in(carry_in),
	  .result(alu_out),
	  .carry_out(alu_carry)
   );


	// Initial block (simulation + RAM init)
	// Only needed for simulation	
	initial begin
		pc 	<= 16'h0000;
		state <= `STATE_FETCH_IR;
		
		// Init registers
		for (i = 0; i < 9; i = i + 1)
			regs[i] = 8'h00;
			
		cf <= 0;
		zf <= 0;
		
		// Init RAM
		for (i = 0; i < RAM_SIZE; i = i + 1)
			ram[i] = 8'h00;
		
		// LOADI.1 R0, 0x42
		ram[0] = 8'h04; // LOADI1 opcode high byte
		ram[1] = 8'h01; // LOADI1 opcode low byte
		ram[2] = 8'h00; // Rd=R0
		ram[3] = 8'h42; // value

		// HLT
		ram[4] = 8'h00; // HLT high byte
		ram[5] = 8'h04; // HLT low byte
	end
	                          	
	wire a_reset = ~reset;
	always @(posedge clk or posedge a_reset) begin
		if (a_reset) begin 
			pc 	<= 16'h0000;
			ir 	<= 16'h0000;
			
			regs[0] <= 8'h00;
			regs[1] <= 8'h00;
			regs[2] <= 8'h00;
			regs[3] <= 8'h00;
			regs[4] <= 8'h00;
			regs[5] <= 8'h00;
			regs[6] <= 8'h00;
			regs[7] <= 8'h00;
			
			state <= `STATE_FETCH_IR;
			substate <= 0;
		end else begin 
			case (state)
				`STATE_FETCH_IR: begin					
					if (substate) begin
						ir[7:0] <= ram[pc];
						substate <= 3'b000;
						state <= `STATE_FETCH_OP;
					end else begin
						ir[15:8] <= ram[pc];
						substate <= 3'b001;
					end
					pc <= pc + 16'h0001;					
				end
				
				// Fetch operands based on bits 11:9 of the opcode
				`STATE_FETCH_OP: begin
					operands[substate] <= ram[pc];
					pc <= pc + 16'h0001;
					
					if (substate + 3'b001 == operand_count) begin
						// All operands have been fetched
						substate <= 0;
						state <= `STATE_EXECUTE;
					end else begin
						substate <= substate + 3'b001;
					end
				end				
				
				`STATE_EXECUTE: begin
					case (ir)
						`OP_LOADI1, `OP_LOADI2, `OP_LOADI3: begin
							case (instruction_width)
								2'b01: begin
									regs[rd] <= operands[1];
									zf <= (regs[rd] == 8'h00);
								end								
								2'b10: begin
									regs[rd] <= operands[1];
									regs[(rd+1) % REG_COUNT] <= operands[2];
									zf <= (regs[rd] == 8'h00)
											&& (regs[(rd+1) % REG_COUNT] == 8'h00);
								end
								2'b11: begin
									regs[rd] <= operands[1];
									regs[(rd+1) % REG_COUNT] <= operands[2];
									regs[(rd+2) % REG_COUNT] <= operands[3];
									zf <= (regs[rd] == 8'h00)
											&& (regs[(rd+1) % REG_COUNT] == 8'h00) 
											&& (regs[(rd+1) % REG_COUNT] == 8'h00);
								end
							endcase
							substate <= 0;
							state <= `STATE_FETCH_IR;
						end
						
						`OP_ADDI1, `OP_ADDI2, `OP_ADDI3: begin
							carry = 0;
							temp_byte = 0; // zf
							
							for (i = 0; i < 3; i = i + 1) begin
								// Set up ALU inputs
								reg_a = regs[(rd + i) % REG_COUNT];
								reg_b = i < instruction_width ? operands[i + 1] : 8'h00;
								alu_op = 3'b000; // ADD
								carry_in = carry;
								
								regs[(rd + i) % REG_COUNT] <= alu_out;
								carry = alu_carry;
								temp_byte = temp_byte | alu_out;
							end
							
							zf <= (temp_byte == 8'h00);
							cf <= carry;
							
							substate <= 0;
							state <= `STATE_FETCH_IR;
						end
						
						`OP_HLT: begin
							substate <= 0;
							state <= `STATE_HALT;
						end
						
						default: begin
							substate <= 0;
							state <= `STATE_HALT;
							// unknown opcode
						end
					endcase
				end
				
				`STATE_HALT: begin
					// do nothing, halted
				end
			endcase			
		end
	end
	
endmodule
