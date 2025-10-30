# Batch synthesize RS encoder/decoder and export utilization/timing.
# Usage:
#   vivado -mode batch -source scripts/rs_synth_util_report.tcl \
#     -tclargs ./vivado_rs_synth xczu3eg-sbva484-1-e 10 5 3
# Args: <proj_dir> <part> <m> <n> <k>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_rs_synth"]
set part     [_arg_or_default $argv 1 "xczu3eg-sbva484-1-e"]
set m        [_arg_or_default $argv 2 10]
set n        [_arg_or_default $argv 3 5]
set k        [_arg_or_default $argv 4 3]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part m=$m n=$n k=$k"

file mkdir $proj_dir
create_project rs_synth $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Create RS encoder/decoder IP
create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_0
create_ip -name rs_decoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_dec_0

set enc_cfg [list \
  CONFIG.Symbol_Width $m \
  CONFIG.Symbol_Per_Block $n \
  CONFIG.Data_Symbols $k \
  CONFIG.Number_Of_Channels 1 \
  CONFIG.Variable_Block_Length false]
catch { set_property -dict $enc_cfg [get_ips rs_enc_0] }

catch { set_property CONFIG.Symbol_Width $m             [get_ips rs_dec_0] }
catch { set_property CONFIG.Symbols_Per_Block $n        [get_ips rs_dec_0] }
catch { set_property CONFIG.Data_Symbols $k             [get_ips rs_dec_0] }
catch { set_property CONFIG.Number_Of_Channels 1        [get_ips rs_dec_0] }
catch { set_property CONFIG.Variable_Block_Length false [get_ips rs_dec_0] }
catch { set_property CONFIG.Marker_Bits true            [get_ips rs_dec_0] }
catch { set_property CONFIG.Number_Of_Marker_Bits 1     [get_ips rs_dec_0] }

generate_target all [get_ips rs_enc_0]
generate_target all [get_ips rs_dec_0]
export_ip_user_files -of_objects [get_ips rs_enc_0 rs_dec_0] -no_script -sync -force -quiet

# Out-of-context synth for IP, then per-IP utilization reports
catch { set_property generate_synth_checkpoint true [get_ips rs_enc_0 rs_dec_0] }
puts "[clock format [clock seconds]] INFO: Launching synth_ip for encoder/decoder"
catch { synth_ip [get_ips rs_enc_0] }
catch { synth_ip [get_ips rs_dec_0] }

set enc_dcp [file normalize "$proj_dir/rs_enc_0/rs_enc_0.dcp"]
set dec_dcp [file normalize "$proj_dir/rs_dec_0/rs_dec_0.dcp"]
if {[file exists $enc_dcp]} {
  open_checkpoint $enc_dcp
  report_utilization -file "$proj_dir/utilization_enc.rpt"
  catch { report_utilization -format csv -file "$proj_dir/utilization_enc.csv" }
  report_timing_summary -file "$proj_dir/timing_enc.rpt" -delay_type max -max_paths 10
  close_project
}
if {[file exists $dec_dcp]} {
  open_checkpoint $dec_dcp
  report_utilization -file "$proj_dir/utilization_dec.rpt"
  catch { report_utilization -format csv -file "$proj_dir/utilization_dec.csv" }
  report_timing_summary -file "$proj_dir/timing_dec.rpt" -delay_type max -max_paths 10
  close_project
}

# Minimal top to anchor both IPs (no IO constraints needed for synth)
set top_file [file normalize "$proj_dir/top_rs_pair.v"]
set fh [open $top_file w]
puts $fh "module top_rs_pair (input wire aclk);"
puts $fh "  wire [$m-1:0] din; wire s_valid, s_ready, s_last;"
puts $fh "  wire [$m-1:0] enc_d; wire enc_v, enc_l;"
puts $fh "  wire        dec_v, dec_l; wire [$m-1:0] dec_d; wire dec_user;"
puts $fh "  assign din = {$m{1'b0}};"
puts $fh "  assign s_valid = 1'b0;"
puts $fh "  assign s_last  = 1'b0;"
puts $fh "  assign dec_user = 1'b0;"
puts $fh "  rs_enc_0 u_enc(.aclk(aclk), .s_axis_input_tdata(din), .s_axis_input_tvalid(s_valid), .s_axis_input_tready(s_ready), .s_axis_input_tlast(s_last), .m_axis_output_tdata(enc_d), .m_axis_output_tvalid(enc_v), .m_axis_output_tlast(enc_l));"
puts $fh "  rs_dec_0 u_dec(.aclk(aclk), .s_axis_input_tdata(enc_d), .s_axis_input_tvalid(enc_v), .s_axis_input_tready(), .s_axis_input_tlast(enc_l), .s_axis_input_tuser(dec_user), .m_axis_output_tdata(dec_d), .m_axis_output_tvalid(dec_v), .m_axis_output_tlast(dec_l));"
puts $fh "endmodule"
close $fh

# Optional: synthesize a trivial top to get combined utilization (may fail without proper IP linking)
add_files $top_file
set_property top top_rs_pair [current_fileset]
if {[catch { synth_design -top top_rs_pair -part $part -directive default } msg]} {
  puts "WARN: top synth failed ($msg). Per-IP reports were generated from OOC checkpoints."
} else {
  report_utilization -hierarchical -hierarchical_depth 2 -file "$proj_dir/utilization.rpt"
  catch { report_utilization -format csv -file "$proj_dir/utilization.csv" }
  report_timing_summary -file "$proj_dir/timing_summary.rpt" -delay_type max -report_unconstrained -max_paths 10
  write_checkpoint -force "$proj_dir/post_synth.dcp"
}
puts "[clock format [clock seconds]] INFO: Synthesis completed; reports at $proj_dir"
