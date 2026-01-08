module cpu_top (
	input wire clk,
	input wire reset
);

	// Program Counter
	reg [15:0] pc;
	
	// Instruction Register
	reg [7:0] ir;
	
	// Registers
	reg [7:0] regs [0:7];
	
	// Simple program ROM
	reg [7:0] rom [0:255];	
	
	// CPU state machine
	localparam STATE_FETCH 		= 2'b00;
	localparam STATE_EXECUTE 	= 2'b01;
	
	// State register 
	reg [1:0] state;
	
	integer i;
	// Initial block (simulation + ROM init)
	initial begin
		pc 	= 16'h0000;
		state = STATE_FETCH;
		
		// Init registers
		for (i = 0; i < 8; i = i + 1)
			regs[i] = 8'h00;
		
		// Temporary hard-coded program
		rom[0] = 8'h30; // LOADI
		rom[1] = 8'h00; // R0
		rom[2] = 8'h0A; // 10
		rom[3] = 8'h02; // HLT
	end
	
	always @(posedge clk) begin
		if (reset) begin 
			pc 	<= 16'h0000;
			state <= STATE_FETCH;
		end else begin 
			case (state)
				STATE_FETCH: begin 
					ir 	<= rom[pc];
					pc 	<= pc + 1;
					state <= STATE_EXECUTE;
				end
				
				STATE_EXECUTE: begin
					case (ir)
						8'h30: begin // LOADI							
							regs[rom[pc][3:0]] <= rom[pc + 1];
							pc <= pc + 2;
						end
						
						default: begin
							// unknown opcode
						end
					endcase
				end
			endcase
			
			state <= STATE_FETCH;
		end
	end
	
endmodule
