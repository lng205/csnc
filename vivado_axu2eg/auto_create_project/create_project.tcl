# ============================================================================
# AXU2EG Vivado 工程创建脚本
# 适用于 ALINX AXU2EG 开发板 (Zynq UltraScale+ xczu2eg)
# ============================================================================

set tclpath [pwd]
cd $tclpath
set src_dir $tclpath/src

# Create project path
cd ..
set projpath [pwd]

source $projpath/auto_create_project/project_info.tcl

# 设置项目名称
if {[string equal $devicePart "xczu2eg-sfvc784-1-e" ]} {
  puts "Creating project for AXU2EG (xczu2eg-sfvc784-1-e)"
  set projName "axu2eg_trd"
} else {
  puts "ERROR: Wrong Part! Expected xczu2eg-sfvc784-1-e"
  return 0
}

puts "============================================"
puts " AXU2EG Project Creation"
puts " Device: $devicePart"
puts " Project: $projName"
puts "============================================"

# Create project
create_project -force $projName $projpath -part $devicePart

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

file mkdir $projpath/$projName.srcs/sources_1/ip
file mkdir $projpath/$projName.srcs/sources_1/new

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
file mkdir $projpath/$projName.srcs/constrs_1/new

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}
file mkdir $projpath/$projName.srcs/sim_1/new

# Create block design
set bdname "design_1"
create_bd_design $bdname

open_bd_design $projpath/$projName.srcs/sources_1/bd/$bdname/$bdname.bd

# Add Zynq UltraScale+ PS
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0

# Configure PS
source $projpath/auto_create_project/ps_config.tcl
set_ps_config zynq_ultra_ps_e_0

# Additional PS settings
set_property -dict [list CONFIG.PSU__USE__IRQ0 {1}] [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {0}] [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} CONFIG.PSU__UART1__PERIPHERAL__IO {EMIO}] [get_bd_cells zynq_ultra_ps_e_0]

# Configure PL
source $tclpath/pl_config.tcl

regenerate_bd_layout
validate_bd_design
save_bd_design		 

# Create wrapper
make_wrapper -files [get_files $projpath/$projName.srcs/sources_1/bd/$bdname/$bdname.bd] -top
add_files -norecurse [glob -nocomplain $projpath/$projName.gen/sources_1/bd/$bdname/hdl/*.v]

puts $bdname
append bdWrapperName $bdname "_wrapper"
puts $bdWrapperName
set_property top $bdWrapperName [current_fileset]

# Add constraint files
add_files -fileset constrs_1 -copy_to $projpath/$projName.srcs/constrs_1/new -force -quiet [glob -nocomplain $src_dir/constraints/*.xdc]

# Set number of jobs for parallel processing
set runs_jobs 8

puts "============================================"
puts " Starting Synthesis..."
puts "============================================"

# Launch synthesis
reset_run synth_1
launch_runs synth_1 -jobs $runs_jobs
wait_on_run synth_1

puts "============================================"
puts " Starting Implementation..."
puts "============================================"

# Launch implementation and bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs $runs_jobs
wait_on_run impl_1 

# Export hardware platform with bitstream included
write_hw_platform -fixed -force -include_bit -file $projpath/$bdWrapperName.xsa

puts "============================================"
puts " Build Complete!"
puts " XSA file: $projpath/$bdWrapperName.xsa"
puts "============================================"

close_project

