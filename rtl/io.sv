module io (   
    input  logic        clk,
    input  logic        reset,
    input  logic        cs,
    output logic        ready,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        we,

    // Debug LEDs
    output logic [4:0] debug_leds,

    // SD Card port
    output logic sd_cs,
    output logic sd_sclk,
    output logic sd_mosi,
    input  logic sd_miso,

    // SA52 port (LED display)
    output logic [7:0] sa52_seg

);

    // Debug LEDs
    logic [4:0] leds_reg;
    // assign debug_leds = ~leds_reg;
    // assign debug_leds[4] = ~sd_cs; // LED 4 lights up when the card is SELECTED (Active Low)
    // assign debug_leds[0] = sd_sclk;  // Should flicker/glow if clock is running
    // assign debug_leds[1] = sd_mosi;  // Should flicker during commands
    // assign debug_leds[2] = sd_miso;  // This is the card's voice
    // assign debug_leds[3] = sd_cs;    // Should be DIM (mostly low) during polling
    // assign debug_leds[4] = ready;    // If this is OFF, your CPU is frozen/deadlocke

    // Keep the status for now, but use LED 0-3 for the SD result
    // assign debug_leds[3:0] = ~leds_reg[3:0]; // Show the lower 4 bits of the SD response
    // assign debug_leds[4]   = ready;           // Keep this as a heartbeat

    assign debug_leds[3:0] = ~leds_reg[3:0]; // LED ON if CPU writes a '1'
    assign debug_leds[4]   = ready;           // Heartbeat/Ready signal

    // Peripheral Selection
    logic [3:0] slot;
    assign slot = addr[7:4];
    
    //------------------------------------------------------------
    // SD Card & SPI Internal Signals
    //------------------------------------------------------------
    logic [7:0] sd_clk_div;
    logic       sd_cs_reg;
    logic [7:0] sd_data_out;
    logic       sd_busy;
    logic       sd_start;
    logic       last_we_sd;

    // Edge detector: Trigger SD only on the first cycle of a Data write
    always_ff @(posedge clk) begin
        if (reset) 
            last_we_sd <= 1'b0;            
        else 
            last_we_sd <= (cs && we && slot == 4'h2 && addr[3:0] == 4'h0);
    end
    
    // If the CPU is currently trying to write to Data (0x20), 
    // keep the start signal high until the SD module says it's busy.
    assign sd_start = (cs && we && slot == 4'h2 && addr[3:0] == 4'h0) && !last_we_sd;
    // assign sd_start = (cs && we && slot == 4'h2 && addr[3:0] == 4'h0);

    // Registers for SD Configuration
    always_ff @(posedge clk) begin
        if (reset) begin
            sd_clk_div <= 8'd125; // Default slow for init
            sd_cs_reg  <= 1'b1;   // Default high (Deselected)
        end else if (cs && we && slot == 4'h2) begin
            if (addr[3:0] == 4'h4) sd_cs_reg  <= wdata[0];
            if (addr[3:0] == 4'h8) sd_clk_div <= wdata[7:0];
        end
    end

    // Instantiate the SD module (which contains the SPI Master)
    sd sd_inst (
        .clk(clk),
        .reset(reset),
        .din(wdata[7:0]),
        .clk_divider(sd_clk_div),
        .start(sd_start),
        .cs_in(sd_cs_reg),
        .dout(sd_data_out),
        .busy(sd_busy),
        .sd_cs(sd_cs),
        .sd_sclk(sd_sclk),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso)
    );

    //------------------------------------------------------------
    // Virtual UART
    //------------------------------------------------------------
    logic vuart_we;
    virtual_uart vuart_inst (
        .clk(clk),
        .we(vuart_we),
        .wdata(wdata)
    );    

    //------------------------------------------------------------
    // SA52 (LED display)
    //------------------------------------------------------------
    logic [7:0] sa52_value;
    sa52 sa52_inst (
        .value(sa52_value),
        .seg(sa52_seg)
    );

    //------------------------------------------------------------
    // Bus Logic (Ready & Read Data)
    //------------------------------------------------------------   
    always_comb begin
        vuart_we = 1'b0;
        rdata    = 32'h0;
        ready    = 1'b1;

        if (cs) begin
            case (slot)
                // Slot 0: Virtual UART (Write-only)
                4'h0: begin
                    vuart_we = we;
                    rdata    = 32'h0;
                    ready    = 1'b1; 
                end

                // Slot 1: Debug LEDs
                4'h1: begin
                    rdata    = {27'h0, leds_reg}; // Allow CPU to read back LED state
                    ready    = 1'b1;
                end

                // Slot 2: SD Card / SPI
                4'h2: begin
                    case (addr[3:0])
                        4'h0: begin // SPI Data Register
                            ready = !sd_busy; // Handshake: Hold CPU until SPI is done
                            rdata = {24'h0, sd_data_out}; 
                        end
                        4'h4: begin // CS Control
                            rdata = {31'h0, sd_cs_reg};
                            ready = 1'b1;
                        end
                        4'h8: begin // Clock Divider
                            rdata = {24'h0, sd_clk_div};
                            ready = 1'b1;
                        end
                        default: ready = 1'b1;
                    endcase
                end

                // Slot 3: SA52 (LED display)
                4'h3: begin 
                    rdata = {24'h0, sa52_value};
                    ready = 1'b1;
                end

                default: begin
                    rdata = 32'hBAAD_F00D; // Debug: indicate unknown slot
                    ready = 1'b1;
                end
            endcase
        end
    end

    // Synchronous write    
    always_ff @(posedge clk) begin
        if (reset) begin
            leds_reg <= 5'b0;
            sa52_value <= 8'hF; // Default to '0' on reset
        end else if (cs && we) begin 
            case (slot)
                4'h1: leds_reg <= wdata[4:0];
                4'h3: sa52_value <= wdata[7:0];
            endcase
        end
    end


endmodule