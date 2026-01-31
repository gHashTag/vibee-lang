## ═══════════════════════════════════════════════════════════════════════════════
## VIBEE FPGA Constraints for Digilent Arty A7-35T
## ═══════════════════════════════════════════════════════════════════════════════
##
## Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
## Golden Identity: φ² + 1/φ² = 3
## PHOENIX = 999
##
## Board: Digilent Arty A7-35T
## FPGA: Xilinx Artix-7 XC7A35TICSG324-1L
##
## ═══════════════════════════════════════════════════════════════════════════════

## ═══════════════════════════════════════════════════════════════════════════════
## CLOCK - 100 MHz Oscillator
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ═══════════════════════════════════════════════════════════════════════════════
## RESET - Button 0 (Active Low)
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## ═══════════════════════════════════════════════════════════════════════════════
## GREEN LEDs (accent LEDs LD4-LD7)
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## ═══════════════════════════════════════════════════════════════════════════════
## RGB LEDs (accent LEDs LD0-LD3)
## ═══════════════════════════════════════════════════════════════════════════════

## LED0 (accent RGB)
set_property -dict { PACKAGE_PIN G6    IOSTANDARD LVCMOS33 } [get_ports { led0_r }];
set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { led0_g }];
set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 } [get_ports { led0_b }];

## LED1 (accent RGB)
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { led1_r }];
set_property -dict { PACKAGE_PIN J4    IOSTANDARD LVCMOS33 } [get_ports { led1_g }];
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS33 } [get_ports { led1_b }];

## LED2 (accent RGB)
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { led2_r }];
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { led2_g }];
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { led2_b }];

## LED3 (accent RGB)
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { led3_r }];
set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports { led3_g }];
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { led3_b }];

## ═══════════════════════════════════════════════════════════════════════════════
## BUTTONS
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];
set_property -dict { PACKAGE_PIN B9    IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN B8    IOSTANDARD LVCMOS33 } [get_ports { btn[3] }];

## ═══════════════════════════════════════════════════════════════════════════════
## SWITCHES
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

## ═══════════════════════════════════════════════════════════════════════════════
## PMOD HEADERS (optional expansion)
## ═══════════════════════════════════════════════════════════════════════════════

## Pmod Header JA
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { ja[0] }];
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { ja[1] }];
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { ja[2] }];
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { ja[3] }];
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { ja[4] }];
set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { ja[5] }];
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { ja[6] }];
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { ja[7] }];

## Pmod Header JB
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { jb[0] }];
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { jb[1] }];
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { jb[2] }];
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { jb[3] }];
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { jb[4] }];
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { jb[5] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { jb[6] }];
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { jb[7] }];

## ═══════════════════════════════════════════════════════════════════════════════
## UART (optional)
## ═══════════════════════════════════════════════════════════════════════════════

set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];

## ═══════════════════════════════════════════════════════════════════════════════
## TIMING CONSTRAINTS
## ═══════════════════════════════════════════════════════════════════════════════

## Input delay for buttons and switches (asynchronous inputs)
set_input_delay -clock sys_clk_pin -max 3.0 [get_ports { btn[*] sw[*] rst_n }]
set_input_delay -clock sys_clk_pin -min 1.0 [get_ports { btn[*] sw[*] rst_n }]

## Output delay for LEDs
set_output_delay -clock sys_clk_pin -max 2.0 [get_ports { led[*] }]
set_output_delay -clock sys_clk_pin -min 0.5 [get_ports { led[*] }]

## ═══════════════════════════════════════════════════════════════════════════════
## CONFIGURATION
## ═══════════════════════════════════════════════════════════════════════════════

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## ═══════════════════════════════════════════════════════════════════════════════
## KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3
## ═══════════════════════════════════════════════════════════════════════════════
