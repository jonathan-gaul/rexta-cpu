module spi_master (
    input  logic clk, reset, start,
    input  logic [7:0] din,
    input  logic [7:0] clk_divider,
    input  logic miso,
    output logic mosi, sclk, busy,
    output logic [7:0] dout
);
    typedef enum {IDLE, TICK, TOCK, DONE} state_t;
    state_t state;
    
    logic [7:0] shift_reg;
    logic [3:0] bit_cnt;
    logic [7:0] count;
    logic m1, m2;

    // Sync MISO
    always_ff @(posedge clk) {m2, m1} <= {m1, miso};

    // MOSI must be MSB of data immediately when start is high
    assign mosi = (state == IDLE) ? din[7] : shift_reg[7];
    assign busy = (state != IDLE);
    assign dout = shift_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            sclk  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    sclk <= 0;
                    if (start) begin
                        shift_reg <= din;
                        bit_cnt   <= 0;
                        count     <= 0;
                        state     <= TICK;
                    end
                end
                TICK: begin
                    if (count >= clk_divider) begin
                        sclk  <= 1;
                        count <= 0;
                        state <= TOCK;
                    end else count <= count + 1;
                end
                TOCK: begin
                    if (count >= clk_divider) begin
                        sclk <= 0;
                        count <= 0;
                        // Sample and Shift on Falling Edge
                        shift_reg <= {shift_reg[6:0], m2}; 
                        if (bit_cnt == 7) state <= DONE;
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            state <= TICK;
                        end
                    end else count <= count + 1;
                end
                DONE: begin
                    // This state exists just to ensure 'start' has cleared
                    // before we allow the next transaction.
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule