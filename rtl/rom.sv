import rexta::*;

///////////////////////////////////////////////////////
// ROM - Read Only Memory                            //
//---------------------------------------------------//
// This is the code that will be run at startup.     //
///////////////////////////////////////////////////////

module rom (
    input  logic        clk,
    input  logic        cs,
    input  logic [31:0] addr,
    output logic [31:0] rdata,
    output logic        ready
);

/*
 * This is a bit of a mess as there a few examples that can be looked at.  
 * Just ensure that only ONE of the "case" statements is uncommented at a time.
 * Eventually this will just be a bootloader that reads from an SD card...
 */ 
always_comb begin
    // case (addr[11:2]) // Addressing by word
    //     // --- Main Program ---
    //     // 0x00: LUI sp, 0x10001 -> sp = 0x10001000
    //     // (This is just past the end of the 4KB stack)
    //     10'h0: rdata = 32'h10001137;

    //     // 0x04: JAL x1, 0x0C (Offset +8 bytes -> Imm = 4)
    //     10'h1: rdata = 32'h008000ef; 

    //     // 0x08: BEQ x0, x0, 0 (Self-loop trap on success)
    //     10'h2: rdata = 32'h00000063; 

    //     // --- Function A (Starts at 0x0C) ---
    //     // 0x0C: ADDI sp, sp, -4 -> Grow stack (sp = 0x0FFFFF_FC)
    //     10'h3: rdata = 32'hffc10113; 

    //     // 0x10: SW x1, 0(sp) -> Save Return Address (0x08) to stack
    //     10'h4: rdata = 32'h00112023; 

    //     // 0x14: JAL x1, 0x24 (Offset +16 bytes to Function B -> Imm = 8)
    //     10'h5: rdata = 32'h010000ef; 

    //     // 0x18: LW x1, 0(sp) -> Restore Return Address (0x08)
    //     10'h6: rdata = 32'h00012083; 

    //     // 0x1C: ADDI sp, sp, 4 -> Shrink stack (sp = 0x10000000)
    //     10'h7: rdata = 32'h00410113; 

    //     // 0x20: JALR x0, x1, 0 -> Return to Main (0x08)
    //     10'h8: rdata = 32'h00008067;

    //     // --- Function B (Starts at 0x24) ---
    //     // 0x24: ADDI x5, x0, 123 -> Do some "work"
    //     10'h9: rdata = 32'h07b00293; 

    //     // 0x28: JALR x0, x1, 0 -> Return to Function A (0x18)
    //     10'ha: rdata = 32'h00008067;

    //     default: rdata = 32'h00000013; // NOP
    // endcase

    // ------ PRINT HI
    // case (addr[11:2])
    //     // 1. Setup Stack
    //     10'h0: rdata = 32'h10001137; // LUI sp, 0x10001 (sp = 0x10001000)

    //     // 2. Setup IO Base Address (Slot 0)
    //     // 0x04: LUI x6, 0xFF000 -> x6 = 0xFF000000
    //     10'h1: rdata = 32'hff000337; 

    //     // 3. Send 'H' (72 / 0x48)
    //     10'h2: rdata = 32'h04800293; // ADDI x5, x0, 72
    //     10'h3: rdata = 32'h00532023; // SW x5, 0(x6)

    //     // 4. Send 'i' (105 / 0x69)
    //     10'h4: rdata = 32'h06900293; // ADDI x5, x0, 105
    //     10'h5: rdata = 32'h00532023; // SW x5, 0(x6)

    //     // 5. Success Loop
    //     10'h6: rdata = 32'h00000063; // BEQ x0, x0, 0

    //     default: rdata = 32'h00000013; // NOP
    // endcase

    // ------- ULTIMATE TEST (should print ABC)
    case (addr[11:2])
        // --- Setup ---
        // 0x00: LUI sp, 0x10001 (sp = 0x10001000)
        10'h0: rdata = 32'h10001137; 
        
        // 0x04: LUI x6, 0xFF000 (IO Base = 0xFF000000)
        10'h1: rdata = 32'hff000337; 

        // --- Main Execution ---
        // 0x08: ADDI x5, x0, 65 ('A')
        10'h2: rdata = 32'h04100293; 
        // 0x0C: SW x5, 0(x6) -> PRINT 'A'
        10'h3: rdata = 32'h00532023; 

        // 0x10: JAL x1, 0x20 (Jump to 'Print B' function, offset +16 bytes)
        // Encoded Imm = 8
        10'h4: rdata = 32'h010000ef; 

        // 0x14: ADDI x5, x0, 67 ('C')
        10'h5: rdata = 32'h04300293; 
        // 0x18: SW x5, 0(x6) -> PRINT 'C'
        10'h6: rdata = 32'h00532023; 

        // 0x1C: Success Loop (Trap)
        10'h7: rdata = 32'h00000063; 

        // --- Function: Print B (Located at 0x20) ---
        // 0x20: ADDI x5, x0, 66 ('B')
        10'h8: rdata = 32'h04200293; 
        // 0x24: SW x5, 0(x6) -> PRINT 'B'
        10'h9: rdata = 32'h00532023; 
        // 0x28: JALR x0, x1, 0 (Return to address stored in x1, which is 0x14)
        10'ha: rdata = 32'h00008067;

        default: rdata = 32'h00000013; // NOP
    endcase

    ready = 1'b1;
end

endmodule