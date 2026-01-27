///////////////////////////////////////////////////////
// IO - Input/Output                                 //
//---------------------------------------------------//
// Handles peripheral devices (SD card, keyboard,    //
// mouse and so on).                                 //
///////////////////////////////////////////////////////

module io (    
    input  logic        clk,
    input  logic        reset,
	input  logic		cs,
	output logic 		ready,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        we   
);

    ///// Peripheral Selection
    // We use bits [7:4] to define 16 possible "slots"
    logic [3:0] slot;
    assign slot = addr[7:4];
    

    //============================================================
    // Virtual UART
    //------------------------------------------------------------
    //
    logic vuart_we;
    //
    virtual_uart vuart_inst (
        .clk(clk),
        .we(vuart_we),
        .wdata(wdata)
    );    
    //============================================================

    always_comb begin
        vuart_we = 1'b0;

        if (cs && we) begin
            case (slot)
                // Slot 0: Virtual UART
                4'h0: begin 
                    vuart_we = 1'b1; 
                    ready = 1'b1;
                end


                default: ; 
            endcase            
        end
    end

endmodule
