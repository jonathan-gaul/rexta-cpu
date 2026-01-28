import rexta::*;

///////////////////////////////////////////////////////
// CPU - Central Processing Unit                     //
//---------------------------------------------------//
// This is the core of the CPU, it handles the       //
// FETCH/EXECUTE sequence, the program counter and   //
// branching.                                        //
///////////////////////////////////////////////////////

module cpu (
    input  logic clk,
    input  logic reset_n,

    // System bus port
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic bus_we,
    input  logic [31:0] bus_rdata,
    input  logic bus_ready,

    // Debug LEDs
    output logic [4:0] debug_leds
);

    // CPU internal logic
	logic [31:0] pc = 32'h0;  // program counter
    logic [31:0] pc_current;  // keep track of pc for the current execution
    logic [31:0] instruction; // current instruction before decoding
    
    assign debug_leds = pc[4:0];

    typedef enum logic { FETCH, EXECUTE } state_t;
    state_t state;

	// Internal registers
    logic [4:0]  rs1, rs2, rd;          // Source 1, Source 2, Destination
    logic [31:0] rdata1, rdata2, wdata; // Read 1, Read 2, Write

    //============================================================
    // Register File
    //------------------------------------------------------------
    //
    logic reg_we;
    //
    registers registers_inst (
        .clk(clk),
        .reset(~reset_n),
        .we(reg_we),                 // Write Enable

	    // read port 1
        .read_addr1(rs1), .read_data1(rdata1),

        // read port 2
        .read_addr2(rs2), .read_data2(rdata2),

        // write port
        .write_addr(rd), .write_data(wdata)
    );
    //============================================================


    //============================================================
    // ALU
    //------------------------------------------------------------
    //
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    alu_op_t alu_op;
    logic [31:0] alu_result;
    logic alu_is_zero;
    //
    alu alu_inst (
        .a(alu_a),
        .b(alu_b),
        .op(alu_op),
        .result(alu_result),
        .is_zero(alu_is_zero)
    );
    //============================================================


    //============================================================
    // Decoder
    //------------------------------------------------------------
    //
    logic op_is_bne;
    logic op_is_beq;
    logic op_use_immediate;
	logic op_is_mem_access;
	logic op_is_halt;
    logic op_is_jump;
    logic [31:0] op_immediate_value;
    logic op_reg_we;
    assign reg_we = op_reg_we && (state == EXECUTE) && bus_ready && (rd != 5'h0);
    logic [1:0] op_wb_sel;
    logic op_use_pc;
    //
    decoder decoder_inst (
        // Input instruction
        .instruction(instruction),

        // Register file port
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_we(op_reg_we),

        // Flags
        .alu_op(alu_op),
        .use_immediate(op_use_immediate),
        .immediate_value(op_immediate_value),
        .is_bne(op_is_bne),
        .is_beq(op_is_beq),
        .is_halt(op_is_halt),
        .is_jump(op_is_jump),
		.is_mem_access(op_is_mem_access),
        .wb_sel(op_wb_sel),
        .mem_we(bus_we),
        .use_pc(op_use_pc)
    );
    //============================================================

    // ALU drivers
    assign alu_a = (op_use_pc) ? pc_current : rdata1;
    assign alu_b = (op_use_immediate) ? op_immediate_value : rdata2;

    // Bus drivers
    assign bus_wdata = rdata2;
    
    // If the instruction is a Load or Store, use the ALU's math for the address.
    // Otherwise, keep the address pointed at the PC to fetch the next instruction.
    assign bus_addr = (state == EXECUTE && op_is_mem_access) ? alu_result : pc;

    // Write data driver (reading from memory or ALU?)
    always_comb begin
        case (op_wb_sel)
            WB_LUI: wdata = op_immediate_value;
            WB_MEM: wdata = bus_rdata;
            WB_PC4: wdata = pc_current + 4;
            default: wdata = alu_result;
        endcase
    end

    // Branching logic
	logic rd_equal;
    assign rd_equal = (rdata1 == rdata2);
    logic is_branch_taken;
    assign is_branch_taken = (op_is_beq && rd_equal) || (op_is_bne && !rd_equal) || (op_is_jump);

	// CPU 'tick'
	logic reset;
    assign reset = ~reset_n;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= FETCH;
            pc          <= 32'h0;
            pc_current  <= 32'h0;
            instruction <= 32'h0;
        end else if (bus_ready && !op_is_halt) begin
            case (state)
                FETCH: begin
                    // 1. Capture the instruction coming from the bus
                    instruction <= bus_rdata;
                    // 2. Latch the address of THIS instruction
                    pc_current  <= pc; 
                    // 3. Move to Execute
                    state       <= EXECUTE;
                end

                EXECUTE: begin
                    // 4. Update PC for the NEXT instruction
                    if (is_branch_taken) begin
                        pc <= alu_result; // Use the target calculated by the instruction
                    end else begin
                        pc <= pc + 4;     // Standard increment
                    end
                    // 5. Go back to Fetch
                    state <= FETCH;
                end
            endcase
        end
    end

endmodule
