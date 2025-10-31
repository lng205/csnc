# Create a Zynq UltraScale+ PS + CS pair block design and implement to route.
# The CS pair is instantiated as a custom RTL module with only aclk/aresetn ports.
# This avoids excessive PL IO while demonstrating PS integration.
#
# Usage:
#   vivado -mode batch -source scripts/cs_ps_bd_impl.tcl \
#     -tclargs ./vivado_cs_ps xczu3eg-sbva484-1-e 11 5 3
# Args: <proj_dir> <part> <L> <K> <M>

proc _arg_or_default {args idx def} { if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def} }

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_ps"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set L        [_arg_or_default $argv 2 11]
set K        [_arg_or_default $argv 3 5]
set M        [_arg_or_default $argv 4 3]

set script_dir [file dirname [info script]]
set repo_root  [file normalize [file join $script_dir ..]]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part L=$L K=$K M=$M"

file mkdir $proj_dir
create_project cs_ps $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Add RTL for the CS pair implementation wrapper and cores
set enc_sv   [file normalize [file join $repo_root verilog cs_encoder_static.sv]]
set dec_sv   [file normalize [file join $repo_root verilog cs_decoder_static.sv]]
set pair_sv  [file normalize [file join $repo_root verilog cs_pair_top.sv]]
set impl_sv  [file normalize [file join $repo_root verilog cs_pair_impl_top.sv]]
set wrap_v   [file normalize [file join $repo_root verilog cs_pair_impl_top_wrap.v]]
foreach f [list $enc_sv $dec_sv $pair_sv $impl_sv $wrap_v] { if {![file exists $f]} { error "Missing $f" } }
read_verilog $enc_sv
read_verilog $dec_sv
read_verilog $pair_sv
read_verilog $impl_sv
read_verilog $wrap_v
update_compile_order -fileset sources_1

# Create BD
create_bd_design cs_bd
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* zynq_ultra_ps_e_0]
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_ps8_0]
set vcc [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* xlconst0]
set_property -dict [list CONFIG.CONST_VAL {0}] $vcc

# Instantiate CS pair impl RTL as a BD module
set cs [create_bd_cell -type module -reference cs_pair_impl_top_wrap cs_pair_impl_top_0]

# Connect clock and reset
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]          [get_bd_pins rst_ps8_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]          [get_bd_pins cs_pair_impl_top_0/aclk]
catch { connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]  [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] }
connect_bd_net [get_bd_pins xlconst0/dout]                      [get_bd_pins rst_ps8_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps8_0/peripheral_aresetn]       [get_bd_pins cs_pair_impl_top_0/aresetn]

save_bd_design

# Generate wrapper and set as top
set bd_file [file normalize "$proj_dir/cs_ps.srcs/sources_1/bd/cs_bd/cs_bd.bd"]
generate_target all [get_files $bd_file]
make_wrapper -files [get_files $bd_file] -top
set wrapper [file normalize "$proj_dir/cs_ps.gen/sources_1/bd/cs_bd/hdl/cs_bd_wrapper.v"]
if {$wrapper eq ""} { error "Failed to find BD wrapper" }
add_files $wrapper
set_property top cs_bd_wrapper [current_fileset]

# Run to route (skip bitstream)
launch_runs synth_1 -jobs 2
wait_on_run synth_1
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1

open_run impl_1
report_utilization    -file "$proj_dir/ps_utilization_impl.rpt"
report_timing_summary -file "$proj_dir/ps_timing_summary_impl.rpt" -delay_type max -max_paths 10
catch { write_checkpoint -force "$proj_dir/ps_post_route.dcp" }

puts "[clock format [clock seconds]] INFO: CS+PS implementation complete. Reports at $proj_dir"
