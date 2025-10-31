# Simulate combinational CS encode->decode with real masks (no AXIS), logic-level only.
# Usage:
#   vivado -mode batch -source scripts/cs_pipeline_tb.tcl -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_tb"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]

file mkdir $proj_dir
create_project cs_tb $proj_dir -part $part -force
set_property target_language Verilog [current_project]

add_files -norecurse verilog/cs_encoder_static.sv
add_files -norecurse verilog/cs_decoder_static.sv
add_files -norecurse verilog/cs_pipeline_tb.sv

set_property include_dirs "verilog/generated" [current_fileset]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
puts "[clock format [clock seconds]] INFO: CS pipeline TB completed."

