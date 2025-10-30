if {[llength $argv] < 1} {
  set repo_dir [file normalize "."]
} else {
  set repo_dir_arg [lindex $argv 0]
  if {[string match "\\\\*" $repo_dir_arg]} {
    set repo_dir $repo_dir_arg
  } else {
    set repo_dir [file normalize $repo_dir_arg]
  }
}

set combos {
  {3 5 10}
  {5 8 10}
  {8 12 10}
}

set results {}
set summary_rows {}

foreach combo $combos {
  lassign $combo m k data_w
  set module_name [format "fec_codec_static_m%d_k%d_w%d" $m $k $data_w]
  set generated_file [file join $repo_dir "verilog" "generated" "${module_name}.sv"]

  if {![file exists $generated_file]} {
    puts "ERROR: Generated module $generated_file not found. Run scripts/generate_static_fec.py first."
    exit 1
  }

  set proj_dir [file normalize [format "D:/vivado/fec_rs_compare_m%dk%dw%d" $m $k $data_w]]
  set src_dir [file join $proj_dir "src"]

  puts [format ">>> Starting synthesis for m=%d k=%d width=%d (project: %s)" $m $k $data_w $proj_dir]

  if {[file exists $proj_dir]} {
    file delete -force $proj_dir
  }
  file mkdir $src_dir

  set verilog_dir [file join $repo_dir "verilog"]
  foreach fname {"fec_matrix_apply.sv" "fec_codec.sv"} {
    file copy -force [file join $verilog_dir $fname] [file join $src_dir $fname]
  }
  file copy -force $generated_file [file join $src_dir [file tail $generated_file]]

  set project_name [format "fec_rs_compare_m%dk%dw%d" $m $k $data_w]
  create_project $project_name $proj_dir -part xc7z010iclg225-1L
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]

  add_files [glob -nocomplain [file join $src_dir "*.sv"]]
  set_property top $module_name [current_fileset]
  update_compile_order -fileset sources_1

  # RS encoder IP
  create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc
  set_property -dict [list \
    CONFIG.Data_Symbols     $m \
    CONFIG.Symbol_Per_Block $k \
    CONFIG.Symbol_Width     $data_w \
    CONFIG.Output_has_Tready {true} \
  ] [get_ips rs_enc]

  # RS decoder IP
  create_ip -name rs_decoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_dec
  set_property -dict [list \
    CONFIG.Data_Symbols        $m \
    CONFIG.Symbols_Per_Block   $k \
    CONFIG.Symbol_Width        $data_w \
  ] [get_ips rs_dec]

  generate_target {synthesis} [get_ips {rs_enc rs_dec}]
  create_ip_run [get_ips rs_enc]
  create_ip_run [get_ips rs_dec]

  launch_runs rs_enc_synth_1 -jobs 4
  launch_runs rs_dec_synth_1 -jobs 4
  wait_on_run rs_enc_synth_1
  wait_on_run rs_dec_synth_1

  # RS Encoder summary
  open_run rs_enc_synth_1
  set enc_util [report_utilization -return_string]
  report_utilization -file [file join $proj_dir "rs_encoder_util.rpt"] -pb all
  regexp {Slice LUTs\*\s*\|\s*(\d+)} $enc_util -> enc_luts
  regexp {Slice Registers\s*\|\s*(\d+)} $enc_util -> enc_regs
  close_design

  # RS Decoder summary
  open_run rs_dec_synth_1
  set dec_util [report_utilization -return_string]
  report_utilization -file [file join $proj_dir "rs_decoder_util.rpt"] -pb all
  regexp {Slice LUTs\*\s*\|\s*(\d+)} $dec_util -> dec_luts
  regexp {Slice Registers\s*\|\s*(\d+)} $dec_util -> dec_regs
  close_design

  # FEC codec
  launch_runs synth_1 -jobs 4
  wait_on_run synth_1
  open_run synth_1
  set fec_util [report_utilization -return_string]
  report_utilization -file [file join $proj_dir "fec_codec_static_util.rpt"] -pb all
  regexp {Slice LUTs\*\s*\|\s*(\d+)} $fec_util -> fec_luts
  regexp {Slice Registers\s*\|\s*(\d+)} $fec_util -> fec_regs
  close_design

  close_project

  lappend summary_rows [list $m $k $data_w "fec_codec_static" $fec_luts $fec_regs]
  lappend summary_rows [list $m $k $data_w "rs_encoder_ip" $enc_luts $enc_regs]
  lappend summary_rows [list $m $k $data_w "rs_decoder_ip" $dec_luts $dec_regs]

  puts [format "Completed m=%d k=%d width=%d -> FEC LUT=%s REG=%s, RS ENC LUT=%s REG=%s, RS DEC LUT=%s REG=%s" \
    $m $k $data_w $fec_luts $fec_regs $enc_luts $enc_regs $dec_luts $dec_regs]
}

set summary_file [file normalize "D:/vivado/fec_rs_compare_summary.csv"]
set fh [open $summary_file w]
puts $fh "m,k,data_width,design,LUTs,Registers"
foreach row $summary_rows {
  puts $fh [join $row ","]
}
close $fh

puts "Summary written to $summary_file"

exit
