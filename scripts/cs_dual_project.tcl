# Create a single Vivado project containing independent encoder and decoder builds.
# - Two separate source sets and synthesis runs: synth_enc and synth_dec
# - Minimal parameterized top wrappers are auto-generated for each
# - Writes utilization/timing reports and post-synth DCPs per block
#
# Usage:
#   vivado -mode batch -source scripts/cs_dual_project.tcl \
#     -tclargs ./vivado_cs_dual xczu3eg-sbva484-1-e 11 5 3
# Args: <proj_dir> <part> <L> <K> <M>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_dual"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set L        [_arg_or_default $argv 2 11]
set K        [_arg_or_default $argv 3 5]
set M        [_arg_or_default $argv 4 3]

# Anchor paths relative to this script's directory to avoid CWD issues in GUI
set script_dir [file dirname [info script]]
set repo_root  [file normalize [file join $script_dir ..]]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part L=$L K=$K M=$M"

file mkdir $proj_dir
create_project cs_dual $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Common RTL paths (resolved from repo root)
set enc_sv [file normalize [file join $repo_root verilog cs_encoder_static.sv]]
set dec_sv [file normalize [file join $repo_root verilog cs_decoder_static.sv]]

if {![file exists $enc_sv]} { error "Missing $enc_sv" }
if {![file exists $dec_sv]} { error "Missing $dec_sv" }

# Create encoder wrapper
set enc_top [file normalize [file join $proj_dir cs_enc_top.sv]]
set fh [open $enc_top w]
puts $fh {module cs_enc_top(
  input  logic [M-1:0][L-2:0] din_i,
  output logic [K-1:0][L-2:0] dout_o
);} 
puts $fh "  localparam int L=$L; localparam int K=$K; localparam int M=$M;"
puts $fh {  cs_encoder_static #(
    .K(K), .M(M), .L(L)
  ) u_enc (
    .data_i(din_i), .data_o(dout_o)
  );
endmodule}
close $fh

# Create decoder wrapper
set dec_top [file normalize [file join $proj_dir cs_dec_top.sv]]
set fh [open $dec_top w]
puts $fh {module cs_dec_top(
  input  logic [K-1:0][L-2:0] din_i,
  output logic [M-1:0][L-2:0] dout_o
);} 
puts $fh "  localparam int L=$L; localparam int K=$K; localparam int M=$M;"
puts $fh {  cs_decoder_static #(
    .K(K), .M(M), .L(L)
  ) u_dec (
    .data_i(din_i), .data_o(dout_o)
  );
endmodule}
close $fh

# Create separate source sets so each run can have its own top
catch { create_fileset -srcset sources_enc }
catch { create_fileset -srcset sources_dec }

add_files -fileset sources_enc -norecurse $enc_sv
add_files -fileset sources_enc -norecurse $enc_top
set gen_dir [file normalize [file join $repo_root verilog generated]]
if {[file isdirectory $gen_dir]} {
  set_property include_dirs $gen_dir [get_filesets sources_enc]
}
update_compile_order -fileset [get_filesets sources_enc]
set_property top cs_enc_top [get_filesets sources_enc]

add_files -fileset sources_dec -norecurse $dec_sv
add_files -fileset sources_dec -norecurse $dec_top
if {[file isdirectory $gen_dir]} {
  set_property include_dirs $gen_dir [get_filesets sources_dec]
}
update_compile_order -fileset [get_filesets sources_dec]
set_property top cs_dec_top [get_filesets sources_dec]

# Create independent synthesis runs bound to each sourceset
set enc_run [create_run synth_enc -flow {Vivado Synthesis 2025} -srcset sources_enc -part $part]
set dec_run [create_run synth_dec -flow {Vivado Synthesis 2025} -srcset sources_dec -part $part]

launch_runs [list synth_enc synth_dec] -jobs 2
wait_on_run [list synth_enc synth_dec]

# Encoder reports
open_run synth_enc -name synth_enc
report_utilization    -file "$proj_dir/enc_utilization.rpt"
catch { report_utilization -format csv -file "$proj_dir/enc_utilization.csv" }
catch { report_timing_summary -file "$proj_dir/enc_timing_summary.rpt" -delay_type max -max_paths 10 }
catch { write_checkpoint -force "$proj_dir/enc_post_synth.dcp" }

# Decoder reports
open_run synth_dec -name synth_dec
report_utilization    -file "$proj_dir/dec_utilization.rpt"
catch { report_utilization -format csv -file "$proj_dir/dec_utilization.csv" }
catch { report_timing_summary -file "$proj_dir/dec_timing_summary.rpt" -delay_type max -max_paths 10 }
catch { write_checkpoint -force "$proj_dir/dec_post_synth.dcp" }

puts "[clock format [clock seconds]] INFO: CS dual project complete. Reports at $proj_dir"
