module spi_shifter_8bit (
    input  logic       clk,      // System Clock (e.g., 50MHz)
    input  logic       reset,      // Active High Reset
    input  logic       start,    // Pulse to begin transfer
    input  logic [7:0] data_in,  // Byte to send
    output logic [7:0] data_out, // Byte received
    output logic       busy,     // Status signal for CPU polling
    
    // Physical SD Card Interface
    input  logic       miso,
    output logic       mosi,
    output logic       sclk
);

    // --- 1. Clock Divider (400kHz for Init) ---
    // 50MHz / 128 = ~390kHz. 
    logic [6:0] clk_count;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) clk_count <= '0;
        else     clk_count <= clk_count + 1'b1;
    end
    
    // Generate a pulse at the end of the divider count
    logic spi_tick;
    assign spi_tick = (clk_count == 7'd127);

    // --- 2. State Machine & Shifter ---
    typedef enum logic { IDLE, TRANSFER } state_e;
    state_e state;
    
    logic [3:0] bit_cnt;
    logic [7:0] shift_reg;
    logic       sclk_reg;


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            busy      <= 1'b0;
            sclk_reg  <= 1'b0;
            mosi      <= 1'b1;
            bit_cnt   <= '0;
            shift_reg <= '0;
            data_out  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    busy     <= 1'b0;
                    sclk_reg <= 1'b0;
                    mosi     <= 1'b1;
                    if (start) begin
                        shift_reg <= data_in;
                        state     <= TRANSFER;
                        busy      <= 1'b1;
                        bit_cnt   <= 4'd8;
                    end
                end

                TRANSFER: begin
                    if (spi_tick) begin
                        if (!sclk_reg) begin
                            // --- Rising Edge ---
                            // Sample the MISO line into our shift register
                            sclk_reg  <= 1'b1;
                            shift_reg <= {shift_reg[6:0], miso};
                        end else begin
                            // --- Falling Edge ---
                            // Prepare the next bit on MOSI
                            sclk_reg <= 1'b0;
                            bit_cnt  <= bit_cnt - 1'b1;
                            
                            if (bit_cnt == 4'd1) begin
                                state    <= IDLE;
                                data_out <= {shift_reg[6:0], miso}; // Final capture
                            end
                        end
                    end
                end
            endcase
        end
    end

    // --- 3. Output Assignments ---
    assign sclk = sclk_reg;
    // We drive the MSB of the shift register onto the MOSI pin
    assign mosi = (state == TRANSFER) ? shift_reg[7] : 1'b1;

endmodule