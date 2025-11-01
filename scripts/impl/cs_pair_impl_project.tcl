# Build a normal (non-OOC) implementable project for screenshots.
# Top exposes only clock/reset pins to avoid IO overuse.
#
# Usage:
#   vivado -mode batch -source scripts/cs_pair_impl_project.tcl \
#     -tclargs ./vivado_cs_impl xczu3eg-sbva484-1-e 11 5 3 5.0
# Args: <proj_dir> <part> <L> <K> <M> <period_ns>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_impl"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set L        [_arg_or_default $argv 2 11]
set K        [_arg_or_default $argv 3 5]
set M        [_arg_or_default $argv 4 3]
set period   [_arg_or_default $argv 5 5.0]

set script_dir [file dirname [info script]]
set repo_root  [file normalize [file join $script_dir ..]]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part L=$L K=$K M=$M period=${period}ns"

file mkdir $proj_dir
create_project cs_impl $proj_dir -part $part -force
set_property target_language Verilog [current_project]

set enc_sv   [file normalize [file join $repo_root verilog cs_encoder_static.sv]]
set dec_sv   [file normalize [file join $repo_root verilog cs_decoder_static.sv]]
set pair_sv  [file normalize [file join $repo_root verilog cs_pair_top.sv]]
set impl_sv  [file normalize [file join $repo_root verilog cs_pair_impl_top.sv]]

foreach f [list $enc_sv $dec_sv $pair_sv $impl_sv] { if {![file exists $f]} { error "Missing $f" } }

add_files -norecurse $enc_sv
add_files -norecurse $dec_sv
add_files -norecurse $pair_sv
add_files -norecurse $impl_sv

# Parameterized impl top wrapper
set top_file [file normalize "$proj_dir/cs_pair_impl_param_top.sv"]
set fh [open $top_file w]
puts $fh {module cs_pair_impl_param_top(
  input  logic aclk,
  input  logic aresetn
);} 
puts $fh "  localparam int L=$L; localparam int K=$K; localparam int M=$M;"
puts $fh {  cs_pair_impl_top #(.K(K), .M(M), .L(L)) u_top (
    .aclk(aclk), .aresetn(aresetn)
  );
endmodule}
close $fh

add_files $top_file
set_property top cs_pair_impl_param_top [current_fileset]
update_compile_order -fileset sources_1

# Minimal XDC: define clock, reset false-path, set IO standard to avoid bank Vcco conflicts
set xdc_file [file normalize "$proj_dir/cs_impl_min.xdc"]
set fh [open $xdc_file w]
puts $fh "create_clock -name aclk -period $period \[get_ports aclk\]"
puts $fh "set_false_path -from \[get_ports aresetn\]"
puts $fh "set_property IOSTANDARD LVCMOS18 \[get_ports {aclk aresetn}\]"
close $fh
add_files -fileset constrs_1 $xdc_file
update_compile_order -fileset constrs_1

launch_runs synth_1 -jobs 2
wait_on_run synth_1
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1

open_run impl_1
report_utilization    -file "$proj_dir/impl_utilization.rpt"
report_timing_summary -file "$proj_dir/impl_timing_summary.rpt" -delay_type max -max_paths 10
catch { write_checkpoint -force "$proj_dir/impl_post_route.dcp" }

puts "[clock format [clock seconds]] INFO: CS impl project complete. Reports at $proj_dir"
