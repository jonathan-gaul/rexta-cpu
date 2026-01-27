import rexta::*;

///////////////////////////////////////////////////////
// Decoder                                           //
//---------------------------------------------------//
// Decodes an instruction into its component parts.  //
// Outputs known flags and values which tell the CPU //
// how to act on the instruction.                    //
///////////////////////////////////////////////////////

module decoder (
    // Instruction in
    input  logic [31:0] instruction,

    // Register File Port
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic        reg_we,  // High if writing to registers

    // ALU Port
    output alu_op_t     alu_op,
    output logic        use_immediate,
    output logic        use_pc,

    // Output Flags
	output logic		is_bne,
	output logic		is_beq,
    output logic [31:0] immediate_value,
    output logic        mem_we,   // High if writing to memory
    output logic        is_halt,
	output logic 		is_mem_access,
    output logic        is_jump,
    output wb_sel_t     wb_sel
);

    // RISC-V Instruction Slicing
    cpu_op_t  opcode;
    logic [2:0]  funct3;
    logic [31:0] i_imm; // Immediate for LW
    logic [31:0] s_imm; // Immediate for SW
    logic [31:0] u_imm; // Immediate for LUI
    logic [31:0] b_imm; // Immediate for BR
    logic [31:0] j_imm; // Immediate for JAL/JALR

    assign opcode = cpu_op_t'(instruction[6:0]);
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];

    // Immediates are "scrambled" to keep rs1/rs2 in the same place
    assign i_imm = { {20{instruction[31]}}, instruction[31:20] };
    assign s_imm = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] };
    assign u_imm = { instruction[31:12], 12'b0 };
    assign b_imm = { {19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
    assign j_imm = $signed({instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0});

    // Decide which immediate to use
    always_comb begin
        case (opcode)
            OP_STORE:   immediate_value = s_imm;
            OP_LUI:     immediate_value = u_imm; // Though LUI doesn't use the Adder
            OP_BRANCH:  immediate_value = b_imm;
            OP_JAL:     immediate_value = j_imm;
            default:    immediate_value = i_imm; // LW and others use I-type
        endcase
    end

    always_comb begin
        is_beq        = 1'b0;
        is_bne        = 1'b0;
        reg_we        = 1'b0;
        alu_op        = ALU_ADD;
        mem_we        = 1'b0;
        use_pc        = 1'b0;
        use_immediate = 1'b0;
        is_halt       = 1'b0;
	    is_jump       = 1'b0;
        is_mem_access = 1'b0;
        wb_sel        = WB_ALU;

        case (opcode)
            OP_STORE: begin
                use_immediate = 1'b1;
                mem_we        = 1'b1;
                is_mem_access = 1'b1;
            end

            OP_LOAD: begin
                use_immediate = 1'b1;
                wb_sel = WB_MEM;
                is_mem_access = 1'b1;
                reg_we = 1'b1;
            end

            OP_LUI: begin
                use_immediate = 1'b1;
                wb_sel        = WB_LUI;
                reg_we        = 1'b1;
            end

            OP_REG_IMM: begin
                reg_we = 1'b1;
                use_immediate = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI (Set Less Than Immediate)
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b110: alu_op = ALU_OR;    // ORI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OP_REG_REG: begin
                reg_we = 1'b1;
                case (funct3)
                    3'b000: alu_op = (instruction[30]) ? ALU_SUB : ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    default: alu_op = ALU_ADD;
                endcase
            end

            OP_BRANCH: begin
                reg_we = 1'b0; // Branches never write to registers
                use_pc = 1'b1;
                use_immediate = 1'b1;
                case (funct3)
                    3'b001: is_bne = 1'b1;
                    3'b000: is_beq = 1'b1;
                    default: ;
                endcase
            end

            OP_JAL: begin
                is_jump = 1'b1;
                reg_we = 1'b1;
                wb_sel = WB_PC4;
                use_pc = 1'b1;
                use_immediate = 1'b1;
            end

            OP_JALR: begin
                is_jump = 1'b1;
                use_immediate = 1'b1;
                wb_sel = WB_PC4;
                reg_we = 1'b1;
            end

            default: ;
        endcase
    end
endmodule
