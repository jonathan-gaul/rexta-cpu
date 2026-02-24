# Rexta CPU

A small 32-bit RISC-V system-on-chip for the REXTA system, targeting the Intel (Altera) Cyclone IV EP4CE6E22C8 FPGA, built around the PicoRV32 soft processor core with a Wishbone B4 interconnect.

## See Also

- (USB Controller)[https://github.com/jonathan-gaul/rexta-usb]
- (Audio Controller)[https://github.com/jonathan-gaul/rexta-apu]

## Hardware

- **FPGA**: Intel Cyclone IV EP4CE6E22C8 (6272 LEs)
- **CPU**: PicoRV32 (RISC-V RV32I) with Wishbone B4 classic mode interface
- **External RAM**: 2× Apmemory APS6404L-3SQR 64Mbit QPI PSRAM (8MB each, 16MB total)
- **Storage**: SD card via SPI
- **Display**: SA52 seven-segment display (active low)

## Memory Map

| Address range               | Size  | Device          |
|-----------------------------|-------|-----------------|
| `0x0000_0000`               | 4 KB  | Boot ROM        |
| `0x2000_0000`               | 512 B | Scratchpad SRAM |
| `0x3000_0000` - `0x307F_FFFF` | 8 MB  | PSRAM chip 0    |
| `0x3080_0000` - `0x30FF_FFFF` | 8 MB  | PSRAM chip 1    |
| `0xF000_0000`               | —     | IO peripherals  |

## PSRAM Controller

The PSRAM controller (`psram.sv`) drives two APS6404L-3SQR chips independently in QPI (quad SPI) mode. Each chip has its own CE# line and handles its own 8MB of byte-addressable space. The two chips share SCLK and SIO lines — only one CE# is asserted at a time.

**Clock architecture**: A PLL generates two clocks from the 50 MHz system clock — `clk_psram` for the state machine and `clk_psram_out` at 180° phase shift which drives the SCLK pin directly. This means posedge `clk_psram` coincides with the SCLK falling edge, giving a full half-period of setup time for output data, and the chip samples on the SCLK rising edge (negedge `clk_psram`).

**Clock domain crossing**: A CDC bridge (`psram_cdc.sv`) handles the crossing between the 50 MHz Wishbone domain and the PSRAM clock domain using a two-FF synchroniser handshake. After a write transaction completes, the controller waits in `S_WR_WAIT_REQ_LOW` until the CDC request signal has been deasserted before accepting the next transaction — this prevents the controller from acting on a stale request level left over from the previous transaction.

**Chip selection**: Address bit 23 selects which chip is active. Bits 22:0 are the byte address sent to the chip. During init both CE# lines are asserted simultaneously so both chips receive the reset and QPI-enter sequence together.

**QPI transactions**: All outputs are driven combinatorially from the current state, with explicit per-nibble states (no counters or shift registers). Each transaction sends a full 32-bit word as 8 nibbles (4 bytes), or fewer for sub-word writes based on the Wishbone `sel` signals. Note that PicoRV32 drives `sel = 4'b0000` for reads — the controller ignores `sel` on reads and always returns all 4 bytes.

**Init sequence**: On reset the controller waits 150 µs, sends Reset Enable (`0x66`) and Reset (`0x99`) in SPI mode, then sends Enter QPI (`0x35`) to place both chips into QPI mode simultaneously. All subsequent transactions use QPI.

**Read timing**: The APS6404L requires 4 dummy cycles at ≤66 MHz after the address before data is valid. Data is captured on posedge `clk_psram` (SCLK falling edge) during states `S_RD_DATA0` through `S_RD_DATA7`.

**Parameters**:
- `CLK_MHZ` — system clock frequency (default 50)
- `PSRAM_MHZ` — PSRAM clock frequency (1 for breadboard testing, 100 for production)

## IO Peripherals

All peripherals are mapped starting from `0xF000_0000` and accessed via the Wishbone IO bus.

**SA52 seven-segment display**: Active-low 8-segment display. Writing a value 0–15 to `SEG7_DISPLAY` shows the corresponding hex digit. `SEG7_RAW` allows direct control of individual segments. OR-ing with `0x10` lights the decimal point.

**SD card**: SPI-mode SD card interface with dedicated SCLK, MOSI, MISO and CS lines.

## Wishbone Interconnect

The address decoder in `soc_top.sv` routes transactions combinatorially based on the top 4 bits of the address. The PSRAM region additionally stalls the CPU (`cpu_bus.stall`) while the PSRAM controller is initialising, ensuring the CPU cannot access RAM before it is ready.

The PicoRV32 Wishbone wrapper uses classic mode — it asserts `CYC+STB` and waits for `ACK`. The `stall` signal is wired through but PicoRV32 does not use it internally; stalling is achieved by withholding `ACK`.

## Building

Targeting Quartus Prime with the EP4CE6E22C8. Pin `PIN_43` (PLL1_CLKOUTp) or another PLL pin must be assigned to `psram_sclk` for correct operation of the phase-shifted clock output.

The pin assignments used in development are:

| Target           | FPGA Pin | Target Pin |
| ---------------- | -------- | ---------- |
| Reset Button     | PIN_144  |            |
| Front Panel Busy LED | PIN_133 |         |
| PSRAM Chip 0     | PIN_50   | /CE        |
| PSRAM Chip 1     | PIN_52   | /CE        |
| PSRAM Chip 0 & 1 | PIN_43   | SCLK       |
| PSRAM Chip 0 & 1 | PIN_65   | SI/SIO[0]  |
| PSRAM Chip 0 & 1 | PIN_67   | SO/SIO[1]  |
| PSRAM Chip 0 & 1 | PIN_66   | SIO[2]     |
| PSRAM Chip 0 & 1 | PIN_64   | SIO[3]     |
| SA52             | PIN_33   | a          |
| SA52             | PIN_32   | b          |
| SA52             | PIN_28   | c          |
| SA52             | PIN_83   | d          |
| SA52             | PIN_85   | e          |
| SA52             | PIN_76   | f          |
| SA52             | PIN_77   | g          |
| SA52             | PIN_30   | dp         |
| SD Card          | PIN_127  | /CS        |
| SD Card          | PIN_124  | MISO       |
| SD Card          | PIN_125  | MOSI       |
| SD Card          | PIN_126  | SCLK       |
