# RS Encoder cycle benchmark: configure IP (m,n,k), drive multi-packet payload, measure cycles.
# Usage:
#   vivado -mode batch -source scripts/rs_encoder_bench_cycles.tcl \
#     -tclargs ./vivado_rs_bench xc7z010clg225-1 10 5 3 1500 3
# Args: <proj_dir> <part> <m> <n> <k> <payload_bytes> <packets>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir      [_arg_or_default $argv 0 "./vivado_rs_bench"]
set part          [_arg_or_default $argv 1 "xc7z010clg225-1"]
set m             [_arg_or_default $argv 2 10]
set n             [_arg_or_default $argv 3 5]
set k             [_arg_or_default $argv 4 3]
set payload_bytes [_arg_or_default $argv 5 1500]
set packets       [_arg_or_default $argv 6 3]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part m=$m n=$n k=$k bytes=$payload_bytes pkts=$packets"

file mkdir $proj_dir
create_project rs_enc_bench $proj_dir -part $part -force
set_property target_language Verilog [current_project]

create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_0

# Configure: symbol width, N, K, no output tready, 1 channel, fixed block length
set cfg [list \
  CONFIG.Symbol_Width $m \
  CONFIG.Symbol_Per_Block $n \
  CONFIG.Data_Symbols $k \
  CONFIG.Output_has_Tready false \
  CONFIG.Number_Of_Channels 1 \
  CONFIG.Variable_Block_Length false]
catch { set_property -dict $cfg [get_ips rs_enc_0] }
report_property -all [get_ips rs_enc_0] -file "$proj_dir/rs_enc_props.txt"

generate_target all [get_ips rs_enc_0]
export_ip_user_files -of_objects [get_ips rs_enc_0] -no_script -sync -force -quiet
export_simulation -of_objects [get_ips rs_enc_0] -directory $proj_dir/ip_user_files/sim_scripts -force -quiet

# Testbench
set tb_file [file normalize "$proj_dir/tb_rs_bench.sv"]
set fh [open $tb_file w]
puts $fh "`timescale 1ns/1ps"
puts $fh "module tb_rs_bench;"
puts $fh "  localparam int M = $m;"
puts $fh "  localparam int K = $k;"
puts $fh "  localparam int N = $n;"
puts $fh "  localparam int BYTES = $payload_bytes;"
puts $fh "  localparam int PACKETS = $packets;"
puts $fh "  logic aclk = 0; always #5 aclk = ~aclk; // 100 MHz"
puts $fh {  logic [M-1:0] s_axis_tdata;  logic s_axis_input_tvalid, s_axis_input_tready, s_axis_input_tlast;}
puts $fh {  logic [M-1:0] m_axis_tdata;  logic m_axis_output_tvalid, m_axis_output_tlast;}
puts $fh ""
puts $fh "  rs_enc_0 dut ("
puts $fh "    .aclk(aclk),"
puts $fh "    .s_axis_input_tdata(s_axis_tdata), .s_axis_input_tvalid(s_axis_input_tvalid), .s_axis_input_tready(s_axis_input_tready), .s_axis_input_tlast(s_axis_input_tlast),"
puts $fh "    .m_axis_output_tdata(m_axis_tdata), .m_axis_output_tvalid(m_axis_output_tvalid), .m_axis_output_tlast(m_axis_output_tlast)"
puts $fh "  );"
puts $fh ""
puts $fh "  int ticks; initial ticks = 0; always @(posedge aclk) ticks++;"
puts $fh "  int outn;"
puts $fh "  initial begin"
puts $fh "    int S, C; int start_tick, end_tick;"
puts $fh "    s_axis_tdata = '0; s_axis_input_tvalid = 1'b0; s_axis_input_tlast = 1'b0;"
puts $fh "    repeat (5) @(posedge aclk);"
puts $fh "    S = (BYTES*8 + M - 1)/M;"
puts $fh "    C = (S + K - 1)/K;"
puts $fh {    $display("CFG M=%0d K=%0d N=%0d BYTES=%0d => S=%0d symbols, C=%0d codewords per packet", M,K,N,BYTES,S,C);}
puts $fh "    start_tick = ticks;"
puts $fh "    for (int p = 0; p < PACKETS; p++) begin"
puts $fh "      for (int cw = 0; cw < C; cw++) begin"
puts $fh "        for (int i = 0; i < K; i++) begin"
puts $fh "          @(posedge aclk);"
puts $fh "          s_axis_input_tvalid <= 1'b1;"
puts $fh "          s_axis_tdata  <= (i + cw*K + p*S);"
puts $fh "          s_axis_input_tlast  <= (i == K-1);"
puts $fh "          wait (s_axis_input_tready == 1'b1);"
puts $fh "        end"
puts $fh "        @(posedge aclk);"
puts $fh "        s_axis_input_tvalid <= 1'b0; s_axis_input_tlast <= 1'b0;"
puts $fh "        outn = 0;"
puts $fh "        while (outn < N) begin"
puts $fh "          @(posedge aclk); if (m_axis_output_tvalid) outn++;"
puts $fh "        end"
puts $fh "      end"
puts $fh "    end"
puts $fh "    end_tick = ticks;"
puts $fh {    $display("RESULT total cycles for %0d packets: %0d", PACKETS, end_tick - start_tick);}
puts $fh {    repeat (10) @(posedge aclk); $finish;}
puts $fh "  end"
puts $fh "endmodule"
close $fh

add_files -fileset sim_1 $tb_file
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run 2 ms
close_sim
puts "[clock format [clock seconds]] INFO: Simulation completed."



