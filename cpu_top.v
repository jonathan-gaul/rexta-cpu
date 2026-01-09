module cpu_top (
	input wire clk,
	input wire reset,
	output wire [2:0] leds
);

	// Program Counter
	reg [15:0] pc;
		
	// Registers
	reg [7:0] regs [0:7];
	assign leds = ~regs[0][2:0];
	
	// Simple program RAM
	reg [7:0] ram [0:255] /* synthesis ram_init_file = "program1.mif" */;
			
	// State register 
	reg [2:0] state;
	
	// CPU state machine
	localparam STATE_FETCH_IR 	= 3'b000;
	localparam STATE_FETCH_OP1 = 3'b001;
	localparam STATE_FETCH_OP2 = 3'b010;
	localparam STATE_FETCH_OP3 = 3'b011;
	localparam STATE_EXECUTE 	= 3'b100;
	localparam STATE_HALT		= 3'b101;
	
	// ALU output
	reg [7:0] alu_out;
	reg cf_out, zf_out;
	
	// Formats
	localparam OPFMT_NONE		= 4'h0;
	localparam OPFMT_RD			= 4'h1;
	localparam OPFMT_RD_RS		= 4'h2;
	localparam OPFMT_RD_IMM		= 4'h3;
	localparam OPFMT_RD_ADDR	= 4'h4;
	localparam OPFMT_ADDR		= 4'h5;
	
	// Opcodes	
	localparam OPCODE_RTS		= {OPFMT_NONE,	   4'h1};
	localparam OPCODE_HLT 		= {OPFMT_NONE,    4'h2};
	
	localparam OPCODE_ADD		= {OPFMT_RD_RS,   4'h0};
	localparam OPCODE_SUB		= {OPFMT_RD_RS,   4'h1};
	localparam OPCODE_AND		= {OPFMT_RD_RS,   4'h2};
	localparam OPCODE_OR 		= {OPFMT_RD_RS,   4'h3};
	localparam OPCODE_XOR 		= {OPFMT_RD_RS,   4'h4};
	
	localparam OPCODE_NOT 		= {OPFMT_RD, 	   4'h0};
	
	localparam OPCODE_LOADI 	= {OPFMT_RD_IMM,  4'h0};
	localparam OPCODE_ADDI 	 	= {OPFMT_RD_IMM,	4'h1};
	
	localparam OPCODE_LOAD  	= {OPFMT_RD_ADDR, 4'h0};	
	localparam OPCODE_STORE		= {OPFMT_RD_ADDR, 4'h1};
	
	localparam OPCODE_JMP 		= {OPFMT_ADDR, 	4'h0};
	localparam OPCODE_JZ 		= {OPFMT_ADDR, 	4'h1};
	localparam OPCODE_JC 		= {OPFMT_ADDR, 	4'h2};
	localparam OPCODE_JSR 		= {OPFMT_ADDR, 	4'h3};
	
	
	// Instruction Register
	reg [7:0] ir;
	
	// Operand registers
	reg [7:0] operand1;
	reg [7:0] operand2;
	reg [7:0] operand3;
	
	// FLAGS (carry, zero)
	reg cf, zf;
	
	
	
	integer i;
	// Initial block (simulation + ROM init)
	// Only needed for simulation
	
	initial begin
		pc 	= 16'h0000;
		state = STATE_FETCH_IR;
		
		// Init registers
		for (i = 0; i < 8; i = i + 1)
			regs[i] = 8'h00;
			
		cf <= 0;
		zf <= 0;
		
	  // Temporary hard-coded program
	  ram[0] = OPCODE_LOADI;
	  ram[1] = 8'h00; // R0
	  ram[2] = 8'h0A; // 10
	  ram[3] = OPCODE_LOADI;
	  ram[4] = 8'h01; // R1
	  ram[5] = 8'h01; // 1
	  ram[6] = OPCODE_ADD;
	  ram[7] = {4'h1, 4'h0}; // Rs=1:Rd=0
	  ram[8] = OPCODE_HLT;
	end	
	
	// ALU combinational logic
	always @(*) begin 
		alu_out = 8'h00;
		cf_out = 0;
		zf_out = 0;
		
		case (ir)
			OPCODE_ADD: begin // ADD Rd, Rs
				{cf_out, alu_out} = regs[operand1[3:0]] + regs[operand1[7:4]];
				zf_out = (alu_out == 8'h00);
			end
			
			OPCODE_ADDI: begin // ADDI Rd, imm
				{cf_out, alu_out} = regs[operand1[3:0]] + operand2;
				zf_out = (alu_out == 8'h00);
			end
			
			OPCODE_SUB: begin // SUB Rd, Rs
				alu_out = regs[operand1[3:0]] - regs[operand1[7:4]];
				zf_out = (alu_out == 8'h00);
				cf_out = (regs[operand1[3:0]] >= regs[operand1[7:4]]); // CF = 1 if no borrow	
			end
			
			OPCODE_AND: begin // AND Rd, Rs
				alu_out = regs[operand1[3:0]] & regs[operand1[7:4]];
				cf_out = 0;
				zf_out = (alu_out == 8'h00);
			end
			
			OPCODE_OR: begin // OR Rd, Rs
				alu_out = regs[operand1[3:0]] | regs[operand1[7:4]];
				cf_out = 0;
				zf_out = (alu_out == 8'h00);
			end
			
			OPCODE_XOR: begin // XOR Rd, Rs
				alu_out = regs[operand1[3:0]] | regs[operand1[7:4]];
				cf_out = 0;
				zf_out = (alu_out == 8'h00);
			end
			
			OPCODE_NOT: begin 
				alu_out = ~regs[operand1[3:0]];
				cf_out = 0;
				zf_out = (alu_out == 8'h00);
			end
			
			default: begin
			end
		endcase
	end
	
	wire a_reset = ~reset;
	always @(posedge clk or posedge a_reset) begin
		if (a_reset) begin 
			pc 	<= 16'h0000;
			ir		<= 8'h00;
			
			regs[0] <= 8'h00;
			regs[1] <= 8'h00;
			regs[2] <= 8'h00;
			regs[3] <= 8'h00;
			regs[4] <= 8'h00;
			regs[5] <= 8'h00;
			regs[6] <= 8'h00;
			regs[7] <= 8'h00;
			
			state <= STATE_FETCH_IR;
		end else begin 
			case (state)
				STATE_FETCH_IR: begin 
					ir <= ram[pc];
					pc <= pc + 16'h0001;
					state <= STATE_FETCH_OP1;
				end
				
				// Fetch operands based on high nibble of opcode
				STATE_FETCH_OP1: begin
					case (ir[7:4])
						OPFMT_RD, OPFMT_RD_RS, OPFMT_RD_IMM, 
						OPFMT_RD_ADDR, OPFMT_ADDR: begin
							operand1 <= ram[pc];
							pc <= pc + 16'h0001;
							state <= STATE_FETCH_OP2;
						end
						default: begin
							state <= STATE_EXECUTE;
						end
					endcase
				end
				
				STATE_FETCH_OP2: begin 
					case (ir[7:4])
						OPFMT_RD_ADDR, OPFMT_RD_IMM, OPFMT_ADDR: begin 
							operand2 <= ram[pc];
							pc <= pc + 16'h0001;
							state <= STATE_FETCH_OP3;
						end
						default: begin
							state <= STATE_EXECUTE;
						end					
					endcase
				end				
				
				STATE_FETCH_OP3: begin
					case (ir[7:4])
						OPFMT_RD_ADDR: begin
							operand3 <= ram[pc];
							pc <= pc + 16'h0001;
						end
						default: begin
						end
					endcase
					state <= STATE_EXECUTE;
				end
				
				STATE_EXECUTE: begin
					case (ir)
						OPCODE_LOADI: begin
							regs[operand1[3:0]] <= operand2;
							state <= STATE_FETCH_IR;
						end
						
						// Handled by ALU
						OPCODE_ADD, OPCODE_SUB,
						OPCODE_AND, OPCODE_OR,
						OPCODE_XOR, OPCODE_NOT,
						OPCODE_ADDI: begin
							regs[operand1[3:0]] <= alu_out;
							cf <= cf_out;
							zf <= zf_out;
							state <= STATE_FETCH_IR;
						end
						
						OPCODE_HLT: begin
							state <= STATE_HALT;
						end
						
						default: begin
							state <= STATE_FETCH_IR;
							// unknown opcode
						end
					endcase
				end
				
				STATE_HALT: begin
					// do nothing, halted
				end
			endcase			
		end
	end
	
endmodule
