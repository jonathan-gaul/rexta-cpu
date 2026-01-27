module sd ( 
    input logic clk, 
    input logic reset,
    
    // Physical interface
    input  logic sd_miso,
    output logic sd_cs,
    output logic sd_mosi,
    output logic sd_clk,
    
    output logic ready
);

// // 1. Clock Divider (400kHz for Init) 
// reg [7:0] clk_div = 0; 

// always @(posedge clk) clk_div <= clk_div + 1; 

// wire spi_clk = clk_div[7];

// // 2. State Machine Variables 
// reg [1:0] state = 0; // 0:IDLE, 1:WARMUP, 2:CMD, 3:READ 
// reg [47:0] cmd_hex = 48'h400000000095; 
// reg [6:0] count = 0; 
// reg [7:0] response = 0;

// // 3. Logic 
// always @(posedge spi_clk) begin 
//     case (state) 
//         0: begin 
//             // IDLE 
//             sd_cs <= 1; 
//             sd_mosi <= 1; 
//             if (btn_start == 0) begin 
//                 state <= 1; 
//                 count <= 0; 
//             end 
//         end 
//         1: begin 
//             // WARMUP (80 clocks) 
//             count <= count + 1; 
//             if (count == 80) begin 
//                 state <= 2; 
//                 count <= 0; 
//             end
//         end 
//         2: begin 
//             // SEND CMD0 
//             sd_cs <= 0; 
//             sd_mosi <= cmd_hex[47-count]; 
//             if (count == 47) begin 
//                 state <= 3; 
//                 count <= 0; 
//             end else 
//                 count <= count + 1; 
//         end 
//         3: begin 
//             // READ RESPONSE 
//             sd_mosi <= 1; 
//             response <= {response[6:0], sd_miso}; 
//             if (response == 8'h01 || count == 32) 
//                 state <= 0; 
//             else 
//                 count <= count + 1; 
//         end 
//     endcase 
// end

// assign leds = response; assign sd_sclk = (state == 0) ? 0 : spi_clk;

endmodule