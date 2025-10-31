# Synthesize cs_encoder_static and report utilization/timing (ZU3EG by default)
# Usage:
#   vivado -mode batch -source scripts/cs_synth_util_report.tcl \
#     -tclargs ./vivado_cs_synth xczu3eg-sbva484-1-e 11 5 3
# Args: <proj_dir> <part> <L> <K> <M>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_synth"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set L        [_arg_or_default $argv 2 11]
set K        [_arg_or_default $argv 3 5]
set M        [_arg_or_default $argv 4 3]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part L=$L K=$K M=$M"

file mkdir $proj_dir
create_project cs_synth $proj_dir -part $part -force
set_property target_language Verilog [current_project]

add_files -norecurse verilog/cs_encoder_static.sv
update_compile_order -fileset sources_1

# Create a trivial top wrapping the parameterization
set top_file [file normalize "$proj_dir/cs_top.sv"]
set fh [open $top_file w]
puts $fh {module cs_top(
  input  logic [M-1:0][L-2:0] din_i,
  output logic [K-1:0][L-2:0] dout_o
);} 
puts $fh "  localparam int L=$L; localparam int K=$K; localparam int M=$M;"
puts $fh {  cs_encoder_static #(.K(K), .M(M), .L(L)) u_cs(.data_i(din_i), .data_o(dout_o));}
puts $fh {endmodule}
close $fh

add_files $top_file
set_property top cs_top [current_fileset]

synth_design -top cs_top -part $part -directive default
report_utilization -file "$proj_dir/utilization.rpt"
catch { report_utilization -format csv -file "$proj_dir/utilization.csv" }
report_timing_summary -file "$proj_dir/timing_summary.rpt" -delay_type max -max_paths 10
write_checkpoint -force "$proj_dir/post_synth.dcp"
puts "[clock format [clock seconds]] INFO: CS synthesis completed; reports at $proj_dir"
