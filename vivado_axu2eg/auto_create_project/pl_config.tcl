# PL 端配置 - 简化版本 (不包含 DDR4，适用于基础测试)
# AXU2EG 使用相同的底板，引脚配置相同

# Create interface ports
set btns [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 btns ]
set fan [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 fan ]
set leds [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 leds ]
set uart [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 uart ]

# Create instance: fan_gpio, and set properties
set fan_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 fan_gpio ]
set_property -dict [ list \
   CONFIG.C_ALL_OUTPUTS {1} \
   CONFIG.C_GPIO_WIDTH {1} \
] $fan_gpio

# Create instance: pl_key, and set properties
set pl_key [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pl_key ]
set_property -dict [ list \
   CONFIG.C_ALL_INPUTS {1} \
   CONFIG.C_GPIO_WIDTH {1} \
   CONFIG.C_INTERRUPT_PRESENT {1} \
] $pl_key

# Create instance: pl_led, and set properties
set pl_led [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pl_led ]
set_property -dict [ list \
   CONFIG.C_ALL_OUTPUTS {1} \
   CONFIG.C_GPIO_WIDTH {1} \
] $pl_led

# Create instance: ps8_0_axi_periph, and set properties
set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
set_property -dict [ list \
   CONFIG.NUM_MI {3} \
] $ps8_0_axi_periph

# Create instance: rst_ps8_0_200M, and set properties
set rst_ps8_0_200M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_200M ]

# Create instance: xlconcat_0, and set properties
set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
set_property -dict [ list \
   CONFIG.NUM_PORTS {1} \
] $xlconcat_0

# Create interface connections
connect_bd_intf_net -intf_net axi_gpio_0_GPIO [get_bd_intf_ports fan] [get_bd_intf_pins fan_gpio/GPIO]
connect_bd_intf_net -intf_net pl_key_GPIO [get_bd_intf_ports btns] [get_bd_intf_pins pl_key/GPIO]
connect_bd_intf_net -intf_net pl_led_GPIO [get_bd_intf_ports leds] [get_bd_intf_pins pl_led/GPIO]
connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins fan_gpio/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins pl_key/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins pl_led/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_LPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]
connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_UART_1 [get_bd_intf_ports uart] [get_bd_intf_pins zynq_ultra_ps_e_0/UART_1]

# Create port connections
connect_bd_net -net ARESETN_1 [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins rst_ps8_0_200M/interconnect_aresetn]
connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins fan_gpio/s_axi_aclk] [get_bd_pins pl_key/s_axi_aclk] [get_bd_pins pl_led/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins rst_ps8_0_200M/slowest_sync_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]
connect_bd_net -net pl_key_ip2intc_irpt [get_bd_pins pl_key/ip2intc_irpt] [get_bd_pins xlconcat_0/In0]
connect_bd_net -net rst_ps8_0_149M_peripheral_aresetn [get_bd_pins fan_gpio/s_axi_aresetn] [get_bd_pins pl_key/s_axi_aresetn] [get_bd_pins pl_led/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins rst_ps8_0_200M/peripheral_aresetn]
connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins rst_ps8_0_200M/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

assign_bd_address

