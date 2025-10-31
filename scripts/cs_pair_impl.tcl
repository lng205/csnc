# Implement a combined CS project that instantiates encoder and decoder together
# with independent interfaces (no internal connection). Adds a minimal clock
# constraint to enable meaningful timing.
#
# Usage:
#   vivado -mode batch -source scripts/cs_pair_impl.tcl \
#     -tclargs ./vivado_cs_pair xczu3eg-sbva484-1-e 11 5 3 5.0
# Args: <proj_dir> <part> <L> <K> <M> <period_ns>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_cs_pair"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set L        [_arg_or_default $argv 2 11]
set K        [_arg_or_default $argv 3 5]
set M        [_arg_or_default $argv 4 3]
set period   [_arg_or_default $argv 5 5.0]

set script_dir [file dirname [info script]]
set repo_root  [file normalize [file join $script_dir ..]]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part L=$L K=$K M=$M period=${period}ns"

file mkdir $proj_dir
create_project cs_pair $proj_dir -part $part -force
set_property target_language Verilog [current_project]

set enc_sv  [file normalize [file join $repo_root verilog cs_encoder_static.sv]]
set dec_sv  [file normalize [file join $repo_root verilog cs_decoder_static.sv]]
set pair_sv [file normalize [file join $repo_root verilog cs_pair_top.sv]]

foreach f [list $enc_sv $dec_sv $pair_sv] {
  if {![file exists $f]} { error "Missing $f" }
}

add_files -norecurse $enc_sv
add_files -norecurse $dec_sv
add_files -norecurse $pair_sv
update_compile_order -fileset sources_1

# Parameterize top via generic map (Verilog parameters)
set_property top cs_pair_top [current_fileset]

# Apply parameters by creating a synthesized wrapper with generics (via define)
# Simpler approach: create a tiny param wrapper here with desired L/K/M
set top_file [file normalize "$proj_dir/cs_pair_param_top.sv"]
set fh [open $top_file w]
puts $fh {module cs_pair_param_top(
  input  logic                         aclk,
  input  logic                         aresetn,
  input  logic                         enc_in_valid,
  output logic                         enc_in_ready,
  input  logic [M-1:0][L-2:0]          enc_din,
  output logic                         enc_out_valid,
  output logic [K-1:0][L-2:0]          enc_dout,
  input  logic                         dec_in_valid,
  output logic                         dec_in_ready,
  input  logic [K-1:0][L-2:0]          dec_din,
  output logic                         dec_out_valid,
  output logic [M-1:0][L-2:0]          dec_dout
);} 
puts $fh "  localparam int L=$L; localparam int K=$K; localparam int M=$M;"
puts $fh {  cs_pair_top #(.K(K), .M(M), .L(L)) u_pair (
    .aclk(aclk), .aresetn(aresetn),
    .enc_in_valid(enc_in_valid), .enc_in_ready(enc_in_ready), .enc_din(enc_din), .enc_out_valid(enc_out_valid), .enc_dout(enc_dout),
    .dec_in_valid(dec_in_valid), .dec_in_ready(dec_in_ready), .dec_din(dec_din), .dec_out_valid(dec_out_valid), .dec_dout(dec_dout)
  );
endmodule}
close $fh

add_files $top_file
set_property top cs_pair_param_top [current_fileset]

# Minimal XDC: clock and async reset false path
set xdc_file [file normalize "$proj_dir/cs_pair_min.xdc"]
set fh [open $xdc_file w]
puts $fh "create_clock -name aclk -period $period \[get_ports aclk\]"
puts $fh "set_false_path -from \[get_ports aresetn\]"
puts $fh "set_property IOSTANDARD LVCMOS18 \[get_ports *\]"
close $fh

add_files -fileset constrs_1 $xdc_file
update_compile_order -fileset constrs_1

puts "[clock format [clock seconds]] INFO: OOC synth/impl for cs_pair_param_top"
synth_design -top cs_pair_param_top -part $part -mode out_of_context
opt_design
place_design
route_design
report_utilization    -file "$proj_dir/pair_utilization_impl.rpt"
report_timing_summary -file "$proj_dir/pair_timing_summary_impl.rpt" -delay_type max -max_paths 10
catch { write_checkpoint -force "$proj_dir/pair_post_route.dcp" }

puts "[clock format [clock seconds]] INFO: CS pair implementation complete. Reports at $proj_dir"
