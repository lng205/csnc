set proj_dir [file normalize "D:/vivado/cs_encoder"]
set src_dir  [file join $proj_dir "src"]
set proj_name "cs_encoder"

create_project $proj_name $proj_dir -part xc7z010iclg225-1L -force
set_property target_language Verilog [current_project]
add_files -norecurse [glob -directory $src_dir *.sv]
update_compile_order -fileset sources_1
set_property top cs_encoder_top [get_filesets sources_1]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_utilization -file [file join $proj_dir "cs_encoder_util.rpt"]
close_design
close_project
