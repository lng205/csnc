# Minimal Vivado project to instantiate AMD RS Encoder IP and run a tiny AXI4-Stream testbench.
# Usage (PowerShell/CMD):
#   vivado -mode batch -source scripts/rs_encoder_min_tb.tcl \
#     -tclargs ./vivado_rs_tb xc7z010clg225-1 10 15 11 2
# Args: <proj_dir> <part> <m> <n> <k> <t>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir [_arg_or_default $argv 0 "./vivado_rs_tb"]
set part     [_arg_or_default $argv 1 "xc7z010clg225-1"]
set m        [_arg_or_default $argv 2 10]
set n        [_arg_or_default $argv 3 15]
set k        [_arg_or_default $argv 4 11]
set t        [_arg_or_default $argv 5 2]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part m=$m n=$n k=$k t=$t"

file mkdir $proj_dir
create_project rs_enc_tb $proj_dir -part $part -force
# Vivado 项目语言标记为 Verilog，.sv 会按 SystemVerilog 识别
set_property target_language Verilog [current_project]

# Create RS Encoder IP
create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_0

# Dump available parameters to help align names per-version
report_property -all [get_ips rs_enc_0] -file "$proj_dir/rs_enc_props.txt"

generate_target all [get_ips rs_enc_0]
export_ip_user_files -of_objects [get_ips rs_enc_0] -no_script -sync -force -quiet
export_simulation -of_objects [get_ips rs_enc_0] -directory $proj_dir/ip_user_files/sim_scripts -force -quiet

# Write a minimal SystemVerilog testbench that drives K symbols and prints N outputs.
set tb_file [file normalize "$proj_dir/tb_rs_enc.sv"]
set fh [open $tb_file w]
puts $fh "`timescale 1ns/1ps"
puts $fh "module tb_rs_enc;"
puts $fh "  localparam int M = $m;"
puts $fh "  localparam int K = $k;"
puts $fh "  localparam int N = $n;"
puts $fh "  logic aclk = 0; always #5 aclk = ~aclk; // 100 MHz"
puts $fh "  logic aresetn = 0;"
puts $fh "  logic \[M-1:0\] s_axis_tdata;  logic s_axis_input_tvalid, s_axis_input_tready, s_axis_input_tlast;"
puts $fh "  logic \[M-1:0\] m_axis_tdata;  logic m_axis_output_tvalid, m_axis_output_tlast;"
puts $fh ""
puts $fh "  rs_enc_0 dut ("
puts $fh "    .aclk(aclk),"
puts $fh "    .s_axis_input_tdata(s_axis_tdata), .s_axis_input_tvalid(s_axis_input_tvalid), .s_axis_input_tready(s_axis_input_tready), .s_axis_input_tlast(s_axis_input_tlast),"
puts $fh "    .m_axis_output_tdata(m_axis_tdata), .m_axis_output_tvalid(m_axis_output_tvalid), .m_axis_output_tlast(m_axis_output_tlast)"
puts $fh "  );"
puts $fh ""
puts $fh "  initial begin"
puts $fh "    int count;"
puts $fh "    s_axis_tdata = '0; s_axis_input_tvalid = 1'b0; s_axis_input_tlast = 1'b0;"
puts $fh "    repeat (5) @(posedge aclk);"
puts $fh "    aresetn = 1'b1;"
puts $fh "    @(posedge aclk);"
puts $fh ""
puts $fh "    // Drive K input symbols with TLAST at the end"
puts $fh "    for (int i = 0; i < K; i++) begin"
puts $fh "      @(posedge aclk);"
puts $fh "      s_axis_input_tvalid <= 1'b1;"
puts $fh "      s_axis_tdata  <= i\[M-1:0\];"
puts $fh "      s_axis_input_tlast  <= (i == K-1);"
puts $fh "      wait (s_axis_input_tready == 1'b1);"
puts $fh "    end"
puts $fh "    @(posedge aclk);"
puts $fh "    s_axis_input_tvalid <= 1'b0; s_axis_input_tlast <= 1'b0;"
puts $fh ""
puts $fh "    // Wait for N outputs"
puts $fh "    count = 0;"
puts $fh "    while (count < N) begin"
puts $fh "      @(posedge aclk);"
puts $fh "      if (m_axis_output_tvalid) begin"
puts $fh "        count++;"
puts $fh {        $display("OUT %0t: %0h %s", $time, m_axis_tdata, m_axis_output_tlast?"LAST":"");}
puts $fh "      end"
puts $fh "    end"
puts $fh "    repeat (10) @(posedge aclk);"
puts $fh {    $finish;}
puts $fh "  end"
puts $fh "endmodule"
close $fh

add_files -fileset sim_1 $tb_file
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
run 2 ms
close_sim
puts "[clock format [clock seconds]] INFO: Simulation completed."
