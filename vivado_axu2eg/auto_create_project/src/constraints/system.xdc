# ============================================================================
# AXU2EG System Constraints
# 适用于 ALINX AXU2EG 开发板
# 引脚配置与 AXU3EG 底板相同
# ============================================================================

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design] 

# ============================================================================
# Fan Control
# ============================================================================
set_property PACKAGE_PIN AA11 [get_ports {fan_tri_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fan_tri_o[0]}]

# ============================================================================
# PL LED
# ============================================================================
set_property PACKAGE_PIN W13 [get_ports {leds_tri_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_tri_o[0]}]

# ============================================================================
# PL Key
# ============================================================================
set_property PACKAGE_PIN AD11 [get_ports {btns_tri_i[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btns_tri_i[0]}]

# ============================================================================
# PL UART (EMIO)
# ============================================================================
set_property PACKAGE_PIN F13 [get_ports uart_rxd]
set_property PACKAGE_PIN E13 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

