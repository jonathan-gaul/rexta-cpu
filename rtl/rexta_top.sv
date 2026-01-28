`default_nettype none

import rexta::*;

///////////////////////////////////////////////////////
// TOP - MAIN FILE                                   //
//---------------------------------------------------//
// This is the top-level module, ultimately          //
// responsible for combining all other modules into  //
// the CPU proper.                                   //
///////////////////////////////////////////////////////

module rexta_top (
    // Inputs
    input wire clk,      // Clock in
    input wire reset_n,  // Active-low reset button

    // Outputs
    output logic [4:0] debug_leds,  // Debug LEDs on Cyclone IV board
    output logic heartbeat_led,      // Heartbeat LED

    // SD Card
    output wire sd_cs,
    output wire sd_mosi,
    output wire sd_sclk,
    input wire sd_miso,

    // SA52 (LED display)
    output logic [7:0] sa52_seg
);

logic reset;
assign reset = ~reset_n;

//============================================================
// STACK
//------------------------------------------------------------
//
logic stack_sel;
logic [31:0] stack_addr;
logic stack_ready;
logic [31:0] stack_rdata;
logic stack_we;
logic [31:0] stack_wdata;
//
stack stack_inst (
    .clk(clk),
    .cs(stack_sel),
    .addr(stack_addr),
    .we(stack_we),
    .wdata(stack_wdata),
    .rdata(stack_rdata),
    .ready(stack_ready)
);
//============================================================

//============================================================
// ROM
//------------------------------------------------------------
//
logic rom_sel;
logic [31:0] rom_addr;
logic rom_ready;
logic [31:0] rom_rdata;
//
rom rom_inst (
    .clk(clk),
    .cs(rom_sel),
    .addr(rom_addr),
    .rdata(rom_rdata),
    .ready(rom_ready)
);
//============================================================

//============================================================
// IO
//------------------------------------------------------------
//
logic io_sel;
logic io_ready;
logic io_we;
logic [31:0] io_addr;
logic [31:0] io_wdata;
logic [31:0] io_rdata;
//
io io_inst (
    .clk(clk),
    .reset(reset),
    .cs(io_sel),
    .we(io_we),
    .ready(io_ready),
    .addr(io_addr),
    .rdata(io_rdata),
    .wdata(io_wdata),

    // Debug LEDs
    .debug_leds(debug_leds),

    // SD Card
    .sd_cs(sd_cs),
    .sd_mosi(sd_mosi),
    .sd_sclk(sd_sclk),
    .sd_miso(sd_miso),

    // SA52 (LED Display)
    .sa52_seg(sa52_seg)
);

//============================================================
// BUS
//------------------------------------------------------------
//
logic bus_we;
logic bus_ready;
logic [31:0] bus_addr;
logic [31:0] bus_wdata;
logic [31:0] bus_rdata;
//
system_bus bus_inst (
    // Bus interface
    .addr(bus_addr),
    .wdata(bus_wdata),
    .we(bus_we),
    .rdata(bus_rdata),
    .ready(bus_ready),

    // ROM
    .rom_sel(rom_sel),
    .rom_ready(rom_ready),
    .rom_addr(rom_addr),
    .rom_rdata(rom_rdata),

    // Stack
    .stack_sel(stack_sel),
    .stack_we(stack_we),
    .stack_ready(stack_ready),
    .stack_addr(stack_addr),
    .stack_rdata(stack_rdata),
    .stack_wdata(stack_wdata),

    // IO
    .io_sel(io_sel),
    .io_we(io_we),
    .io_ready(io_ready),
    .io_addr(io_addr),
    .io_rdata(io_rdata),
    .io_wdata(io_wdata)
);
//============================================================

//============================================================
// CPU
//------------------------------------------------------------
//
cpu cpu_inst (
    .clk(clk),
    .reset_n(reset_n),

    // Bus interface
    .bus_addr(bus_addr),
    .bus_wdata(bus_wdata),
    .bus_we(bus_we),
    .bus_rdata(bus_rdata),
    .bus_ready(bus_ready)
	 
	 // .debug_leds(debug_leds)
);
//
//------------------------------------------------------------


///// HEARTBEAT
// Lets us toggle an LED to show that "something" is running.
logic [24:0] hb_count;
always_ff @(posedge clk) hb_count <= hb_count + 25'h1;
assign heartbeat_led = ~hb_count[24];

endmodule