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
    // case (addr[11:2])
    //     // --- Setup ---
    //     // 0x00: LUI sp, 0x10001 (sp = 0x10001000)
    //     10'h0: rdata = 32'h10001137; 
        
    //     // 0x04: LUI x6, 0xFF000 (IO Base = 0xFF000000)
    //     10'h1: rdata = 32'hff000337; 

    //     // --- Main Execution ---
    //     // 0x08: ADDI x5, x0, 65 ('A')
    //     10'h2: rdata = 32'h04100293; 
    //     // 0x0C: SW x5, 0(x6) -> PRINT 'A'
    //     10'h3: rdata = 32'h00532023; 

    //     // 0x10: JAL x1, 0x20 (Jump to 'Print B' function, offset +16 bytes)
    //     // Encoded Imm = 8
    //     10'h4: rdata = 32'h010000ef; 

    //     // 0x14: ADDI x5, x0, 67 ('C')
    //     10'h5: rdata = 32'h04300293; 
    //     // 0x18: SW x5, 0(x6) -> PRINT 'C'
    //     10'h6: rdata = 32'h00532023; 

    //     // 0x1C: Success Loop (Trap)
    //     10'h7: rdata = 32'h00000063; 

    //     // --- Function: Print B (Located at 0x20) ---
    //     // 0x20: ADDI x5, x0, 66 ('B')
    //     10'h8: rdata = 32'h04200293; 
    //     // 0x24: SW x5, 0(x6) -> PRINT 'B'
    //     10'h9: rdata = 32'h00532023; 
    //     // 0x28: JALR x0, x1, 0 (Return to address stored in x1, which is 0x14)
    //     10'ha: rdata = 32'h00008067;

    //     default: rdata = 32'h00000013; // NOP
    // endcase

// LED test
// case (addr[11:2])
//     10'h0: rdata = 32'hff000337; // LUI x6, 0xFF000
//     10'h1: rdata = 32'h00f00293; // ADDI x5, x0, 15 (01111)
//     10'h2: rdata = 32'h00532823; // SW x5, 16(x6) -> Write 15 to LEDs
//     10'h3: rdata = 32'h00000063; // Trap Loop
//     default: rdata = 32'h00000013;
// endcase

// SD test
//     case (addr[11:2])
//     // --- Setup ---
//     // 0x00: LUI x6, 0xFF000 (IO Base = 0xFF000000)
//     10'h0: rdata = 32'hff000337; 

//     // 0x04: ADDI x7, x0, 62 (Divider for 400kHz)
//     10'h1: rdata = 32'h03e00393;
//     // 0x08: SW x7, 40(x6) -> Set SD_DIV
//     10'h2: rdata = 32'h02732423;

//     // --- SD Wake-up Sequence ---
//     // 0x0C: ADDI x7, x0, 1 (CS High)
//     10'h3: rdata = 32'h00100393;
//     // 0x10: SW x7, 36(x6) -> Set SD_CTRL (Deselect)
//     10'h4: rdata = 32'h00732223;

//     // 0x14: ADDI x5, x0, 255 (Data 0xFF)
//     10'h5: rdata = 32'h0ff00293;
//     // 0x18: ADDI x28, x0, 10 (Loop counter)
//     10'h6: rdata = 32'h00a00e13;

//     // --- Wake Loop (80 Clocks) ---
//     // 0x1C: SW x5, 32(x6) -> Send 0xFF to SD_DATA
//     10'h7: rdata = 32'h00532023;
//     // 0x20: ADDI x28, x28, -1
//     10'h8: rdata = 32'hfff60e13;
//     // 0x24: BNE x28, x0, -8 (Branch to 0x1C)
//     10'h9: rdata = 32'hfe0e1ce3;

//     // --- Send CMD0 ---
//     // 0x28: SW x0, 36(x6) -> Set SD_CTRL = 0 (Select Card)
//     10'ha: rdata = 32'h00032223;

//     // 0x2C: ADDI x5, x0, 64 (0x40 = CMD0)
//     10'hb: rdata = 32'h04000293;
//     // 0x30: SW x5, 32(x6)
//     10'hc: rdata = 32'h00532023;

//     // 0x34: SW x0, 32(x6) -> Arg 0x00
//     10'hd: rdata = 32'h00032023;
//     // 0x38: SW x0, 32(x6) -> Arg 0x00
//     10'he: rdata = 32'h00032023;
//     // 0x3C: SW x0, 32(x6) -> Arg 0x00
//     10'hf: rdata = 32'h00032023;
//     // 0x40: SW x0, 32(x6) -> Arg 0x00
//     10'h10: rdata = 32'h00032023;

//     // 0x44: ADDI x5, x0, 149 (0x95 = CRC for CMD0)
//     10'h11: rdata = 32'h09500293;
//     // 0x48: SW x5, 32(x6)
//     10'h12: rdata = 32'h00532023;

//     // --- Read Response ---
//     // 0x4C: ADDI x5, x0, 255 (Dummy 0xFF)
//     10'h13: rdata = 32'h0ff00293;
//     // 0x50: SW x5, 32(x6) -> Clock out response
//     10'h14: rdata = 32'h00532023;
//     // 0x54: LW x29, 32(x6) -> Read result from SD_DATA
//     10'h15: rdata = 32'h02032e83;

//     // --- Output to Physical LEDs ---
//     // 0x58: SW x29, 16(x6) -> Write response bits to Slot 1 (0xFF000010)
//     10'h16: rdata = 32'h01d32823; 

//     // 0x5C: Trap Loop
//     10'h17: rdata = 32'h00000063;

//     default: rdata = 32'h00000013; // NOP
// endcase

// case (addr[11:2])
//     // 1. Load the base address of IO (0xFF000000)
//     10'h0: rdata = 32'hff000337; // LUI x6, 0xFF000
    
//     // 2. Load the pattern '10' (binary 1010) into register x5
//     10'h1: rdata = 32'h00a00293; // ADDI x5, x0, 10
    
//     // 3. Store x5 into the LED register (Address 0xFF000010)
//     10'h2: rdata = 32'h00532823; // SW x5, 16(x6)
    
//     // 4. Stay here
//     10'h3: rdata = 32'h00000063; // TRAP: J TRAP
//     default: rdata = 32'h00000013;
// endcase

// case (addr[11:2])
//     // x6 = 0xFF000000 (Base)
//     // x5 = 0xFF (Comparison)
//     10'h1: rdata = 32'h02032783; // LW x15, 32(x6)   (Read SPI Data)
//     10'h2: rdata = 32'h00f78863; // BEQ x15, x5, -16 (Loop to 10'h1 if Data == 0xFF)
//     // --- If we get here, MISO was grounded! ---
//     10'h3: rdata = 32'h00f32823; // SW x15, 16(x6)   (Write the result to LEDs)
//     10'h4: rdata = 32'h00000063; // BEQ x0, x0, 0    (TRAP FOREVER)
//     default: rdata = 32'h00000013;
// endcase

// case (addr[11:2])
//     // 1. NOPs to move the PC away from 0
//     10'h0: rdata = 32'h00000013; // PC 0
//     10'h1: rdata = 32'h00000013; // PC 4
//     10'h2: rdata = 32'h00000013; // PC 8
    
//     // 2. Read SPI
//     10'h3: rdata = 32'h02032783; // PC 12 (Read)
    
//     // 3. Loop to PC 12 if data is NOT 0
//     10'h4: rdata = 32'hfe079ee3; // BNE x15, x0, -4 (Jump to PC 12)

//     // 4. Trap (PC 20 -> 00101)
//     10'h5: rdata = 32'h00000063; // Trap
//     default: rdata = 32'h00000013;
// endcase
// case (addr[11:2])
//     // --- Setup & Wake-up (Same as before) ---
//     10'h0:  rdata = 32'hff000337; // LUI x6, 0xFF000
//     10'h1:  rdata = 32'h03e00393; // ADDI x7, x0, 62
//     10'h2:  rdata = 32'h02732423; // SW x7, 40(x6)
//     10'h3:  rdata = 32'h00100393; // ADDI x7, x0, 1
//     10'h4:  rdata = 32'h00732223; // SW x7, 36(x6)
//     10'h5:  rdata = 32'h0ff00293; // ADDI x5, x0, 255
//     10'h6:  rdata = 32'h00a00e13; // ADDI x28, x0, 10
//     10'h7:  rdata = 32'h00532023; // SW x5, 32(x6)
//     10'h8:  rdata = 32'hfff60e13; // ADDI x28, x28, -1
//     10'h9:  rdata = 32'hfe0e1ce3; // BNE x28, x0, -8
    
//     // --- Send CMD0 ---
//     10'ha:  rdata = 32'h00032223; // SW x0, 36(x6) (Select)
//     10'hb:  rdata = 32'h04000293; // ADDI x5, x0, 64 (CMD0)
//     10'hc:  rdata = 32'h00532023; // SW x5, 32(x6)
//     10'hd:  rdata = 32'h00032023; // Arg 0
//     10'he:  rdata = 32'h00032023; // Arg 0
//     10'hf:  rdata = 32'h00032023; // Arg 0
//     10'h10: rdata = 32'h00032023; // Arg 0
//     10'h11: rdata = 32'h09500293; // ADDI x5, x0, 149 (CRC)
//     10'h12: rdata = 32'h00532023; // SW x5, 32(x6)

//     // --- NEW: Polling Read Loop ---
//     // 0x4C: Send dummy 0xFF to get a byte back
//     10'h13: rdata = 32'h0ff00293; // ADDI x5, x0, 255
//     10'h14: rdata = 32'h00532023; // SW x5, 32(x6) (Trigger SPI)
    
//     // 0x54: Load the response from the SD card
//     10'h15: rdata = 32'h02032e83; // LW x29, 32(x6)
    
//     // 0x58: If x29 == 255 (0xFF), jump back to 0x4C (Instruction 10'h13)
//     // This is a BEQ x29, x5, -12
//     10'h16: rdata = 32'hfe5e8ae3; 

//     // --- Output & Finish ---
//     // 0x5C: Write the non-0xFF response to LEDs
//     10'h17: rdata = 32'h01d32823; // SW x29, 16(x6)
    
//     // 0x60: Success Trap (Freeze here)
//     10'h18: rdata = 32'h00000063; // J 0x60

//     default: rdata = 32'h00000013;
// endcase

// case (addr[11:2])
//     // --- Step 1: Setup Pointers ---
//     10'h0: rdata = 32'hff000537; // LUI x10, 0xff000     <- IO Base
//     10'h1: rdata = 32'h07d00593; // ADDI x11, x0, 125    <- Slow clock (200kHz)
//     10'h2: rdata = 32'h02b52423; // SW x11, 40(x10)      <- Write to 0xFF000028 (Clock Div)

//     // --- Step 2: 80 Clock Pulses (10 bytes of 0xFF) with CS High ---
//     10'h3: rdata = 32'h00100593; // ADDI x11, x0, 1      <- CS = High
//     10'h4: rdata = 32'h00b52223; // SW x11, 36(x10)      <- Write to 0xFF000024 (CS)
//     10'h5: rdata = 32'h00a00e13; // ADDI x28, x0, 10     <- Loop counter
//     10'h6: rdata = 32'h0ff00593; // ADDI x11, x0, 255    <- Data 0xFF
//     // Loop Start (Addr 0x1C)
//     10'h7: rdata = 32'h00b52023; // SW x11, 32(x10)      <- Write 0xFF to 0xFF000020 (SPI Data)
//     10'h8: rdata = 32'hfff60613; // ADDI x12, x12, -1    <- Decrement counter
//     10'h9: rdata = 32'hfe0618e3; // BNE x12, x0, -16     <- Loop back to 10'h7 if not 0

//     // --- Step 3: Send CMD0 (Reset) with CS Low ---
//     10'hA: rdata = 32'h00000593; // ADDI x11, x0, 0      <- CS = Low
//     10'hB: rdata = 32'h00b52223; // SW x11, 36(x10)      <- Write to 0xFF000024
//     10'hC: rdata = 32'h04000593; // ADDI x11, x0, 0x40   <- CMD0 byte
//     10'hD: rdata = 32'h00b52023; // SW x11, 32(x10)      <- Send it
//     // Follow up with 4 zero bytes (Arguments) and 1 CRC byte (0x95)
//     10'hE: rdata = 32'h00000593; // ADDI x11, x0, 0      <- Argument byte
//     10'hF: rdata = 32'h00b52023; // SW x11, 32(x10)      <- Send Arg 1
//     10'h10: rdata = 32'h00b52023; // SW x11, 32(x10)     <- Send Arg 2
//     10'h11: rdata = 32'h00b52023; // SW x11, 32(x10)     <- Send Arg 3
//     10'h12: rdata = 32'h00b52023; // SW x11, 32(x10)     <- Send Arg 4
//     10'h13: rdata = 32'h09500593; // ADDI x11, x0, 0x95  <- CRC for CMD0
//     10'h14: rdata = 32'h00b52023; // SW x11, 32(x10)     <- Send CRC

//     // --- Step 4: Wait for Response (Poll MISO) ---
//     10'h15: rdata = 32'h0ff00593; // ADDI x11, x0, 0xFF  <- Dummy byte to trigger read
//     10'h16: rdata = 32'h00b52023; // SW x11, 32(x10)     <- Send Dummy
//     10'h17: rdata = 32'h02052603; // LW x12, 32(x10)     <- Read Result (Wait for ready)
//     10'h18: rdata = 32'h00c52823; // SW x12, 16(x10)     <- Show byte on LEDs (Slot 1)
//     10'h19: rdata = 32'h00b58663; // BEQ x11, x12, 12   <- If Result == 0xFF, JUMP to 10'h1C (Loop)
//     10'h1A: rdata = 32'h00000063; // BEQ x0, x0, 0      <- SUCCESS: Halt here and show LEDs
//     10'h1B: rdata = 32'h00000013; // NOP
//     10'h1C: rdata = 32'hfe000ce3; // BEQ x0, x0, -40    <- JUMP back to 0x15 (Address 10'h15)
//     default: rdata = 32'h00000013;
// endcase

/// LED DISPLAY TEST
    // case (addr[11:2])
    //     // 0x00: lui x10, 0xFF000     -> x10 = 0xFF000000
    //     10'h0: rdata = 32'hFF000537; 
        
    //     // 0x04: addi x10, x10, 0x30  -> x10 = 0xFF000030 (Slot 3)
    //     10'h1: rdata = 32'h03050513; 
        
    //     // 0x08: li x11, 10           -> x11 = 0x0000000A ('A')
    //     10'h2: rdata = 32'h00A00593; 
        
    //     // 0x0C: sw x11, 0(x10)       -> Write 'A' to SA52
    //     10'h3: rdata = 32'h00B52023; 
        
    //     // 0x10: j 0x10               -> Trap (Infinite Loop)
    //     10'h4: rdata = 32'h0000006F; 
        
    //     // Default to NOP
    //     default: rdata = 32'h00000013; 
    // endcase


    case (addr[11:2])
            // Setup: x10 = 0xFF000000 (IO Base)
            10'h0: rdata = 32'hFF000537; 

            // STEP 1: Show '1', then Init Clock Divider (0x28)
            10'h1: rdata = 32'h00100593; // li x11, 1
            10'h2: rdata = 32'h00B52623; // sw x11, 48(x10) -> SA52 (0x30)
            10'h3: rdata = 32'h07D00593; // li x11, 125
            10'h4: rdata = 32'h00B52423; // sw x11, 40(x10) -> SD Divider (0x28)

            // STEP 2: Show '2', then Toggle Chip Select (0x24)
            10'h5: rdata = 32'h00200593; // li x11, 2
            10'h6: rdata = 32'h00B52623; // sw x11, 48(x10) -> SA52 (0x30)
            10'h7: rdata = 32'h00000593; // li x11, 0 (CS Low)
            10'h8: rdata = 32'h00B52223; // sw x11, 36(x10) -> SD CS (0x24)

            // STEP 3: Show '3', then Send Command (0x20)
            // This is the "Ready" handshake point.
            10'h9: rdata = 32'h00300593; // li x11, 3
            10'hA: rdata = 32'h00B52623; // sw x11, 48(x10) -> SA52 (0x30)
            10'hB: rdata = 32'h0FF00593; // li x11, 0xFF
            10'hC: rdata = 32'h00B52023; // sw x11, 32(x10) -> SD Data (0x20)

            // STEP 4: Show '4' (The SPI finished!)
            10'hD: rdata = 32'h00400593; // li x11, 4
            10'hE: rdata = 32'h00B52623; // sw x11, 48(x10) -> SA52 (0x30)

            10'hF: rdata = 32'h0000006F; // j trap (hang here if successful)
            
            default: rdata = 32'h00000013; // nop
        endcase

    ready = 1'b1;
end

endmodule