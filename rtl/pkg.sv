package rexta;

	// ALU operations
	typedef enum logic [3:0] {
		ALU_ADD  = 4'b0000,
		ALU_SUB  = 4'b0001,
		ALU_SLT  = 4'b0010,
		ALU_SLTU = 4'b0011,
		ALU_AND  = 4'b0100,
		ALU_OR   = 4'b0101,
		ALU_XOR  = 4'b0111
	} alu_op_t;

	// RISC-V opcodes
	typedef enum logic [6:0] {
		OP_REG_REG = 7'b0110011, // ADD, SUB, etc.
		OP_REG_IMM = 7'b0010011, // ADDI, SLTI, etc.
		OP_LUI     = 7'b0110111,
		OP_LOAD    = 7'b0000011, // LW, LH, LB
    	OP_STORE   = 7'b0100011, // SW, SH, SB 
		OP_AUIPC   = 7'b0010111, // Often used with LUI
		OP_JAL     = 7'b1101111,
		OP_JALR    = 7'b1100111,
		OP_BRANCH  = 7'b1100011
	} cpu_op_t;

	// Writeback selector
	typedef enum logic [1:0] {
		WB_ALU = 2'b00,
    	WB_MEM = 2'b01,
    	WB_PC4 = 2'b10,
		WB_LUI = 2'b11
	} wb_sel_t;

endpackage