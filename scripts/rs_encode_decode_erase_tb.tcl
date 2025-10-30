# RS encode->drop 2 (erasures)->decode testbench (AXI4-Stream), multi-packet, codeword-by-codeword.
# Usage:
#   vivado -mode batch -source scripts/rs_encode_decode_erase_tb.tcl \
#     -tclargs ./vivado_rs_ede xc7z010clg225-1 10 5 3 1500 3
# Args: <proj_dir> <part> <m> <n> <k> <payload_bytes> <packets>

proc _arg_or_default {args idx def} {
  if {[llength $args] > $idx} {return [lindex $args $idx]} {return $def}
}

set proj_dir      [_arg_or_default $argv 0 "./vivado_rs_ede"]
set part          [_arg_or_default $argv 1 "xc7z010clg225-1"]
set m             [_arg_or_default $argv 2 10]
set n             [_arg_or_default $argv 3 5]
set k             [_arg_or_default $argv 4 3]
set payload_bytes [_arg_or_default $argv 5 1500]
set packets       [_arg_or_default $argv 6 3]

puts "[clock format [clock seconds]] INFO: proj_dir=$proj_dir part=$part m=$m n=$n k=$k bytes=$payload_bytes pkts=$packets"

file mkdir $proj_dir
create_project rs_ede $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Encoder IP
create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_0

# Decoder IP
create_ip -name rs_decoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_dec_0

# Configure common parameters (best-effort; per-version names may vary)
set enc_cfg [list \
  CONFIG.Symbol_Width $m \
  CONFIG.Symbol_Per_Block $n \
  CONFIG.Data_Symbols $k \
  CONFIG.Output_has_Tready false \
  CONFIG.Number_Of_Channels 1 \
  CONFIG.Variable_Block_Length false]
catch { set_property -dict $enc_cfg [get_ips rs_enc_0] }

catch { set_property CONFIG.Symbol_Width $m           [get_ips rs_dec_0] }
catch { set_property CONFIG.Symbols_Per_Block $n      [get_ips rs_dec_0] }
catch { set_property CONFIG.Data_Symbols $k           [get_ips rs_dec_0] }
catch { set_property CONFIG.Number_Of_Channels 1      [get_ips rs_dec_0] }
catch { set_property CONFIG.Variable_Block_Length false [get_ips rs_dec_0] }
catch { set_property CONFIG.Marker_Bits true          [get_ips rs_dec_0] }
catch { set_property CONFIG.Number_Of_Marker_Bits 1   [get_ips rs_dec_0] }
report_property -all [get_ips rs_dec_0] -file "$proj_dir/rs_dec_props.txt"

generate_target all [get_ips rs_enc_0]
generate_target all [get_ips rs_dec_0]
export_ip_user_files -of_objects [get_ips rs_enc_0 rs_dec_0] -no_script -sync -force -quiet
export_simulation  -of_objects [get_ips rs_enc_0 rs_dec_0] -directory $proj_dir/ip_user_files/sim_scripts -force -quiet

# Testbench
set tb_file [file normalize "$proj_dir/tb_rs_ede.sv"]
set fh [open $tb_file w]
puts $fh "`timescale 1ns/1ps"
puts $fh "module tb_rs_ede;"
puts $fh "  localparam int M = $m;"
puts $fh "  localparam int K = $k;"
puts $fh "  localparam int N = $n;"
puts $fh "  localparam int BYTES = $payload_bytes;"
puts $fh "  localparam int PACKETS = $packets;"
puts $fh "  logic aclk = 0; always #5 aclk = ~aclk; // 100 MHz"
puts $fh {  logic [M-1:0] s_tdata;  logic s_tvalid, s_tready, s_tlast;}
puts $fh {  logic [M-1:0] e_tdata;  logic e_tvalid, e_tlast;}
puts $fh {  logic [M-1:0] d_tdata;  logic d_tvalid, d_tlast;}
puts $fh {  logic        d_tuser;}
puts $fh ""
puts $fh "  rs_enc_0 u_enc ("
puts $fh "    .aclk(aclk),"
puts $fh "    .s_axis_input_tdata(s_tdata), .s_axis_input_tvalid(s_tvalid), .s_axis_input_tready(s_tready), .s_axis_input_tlast(s_tlast),"
puts $fh "    .m_axis_output_tdata(e_tdata), .m_axis_output_tvalid(e_tvalid), .m_axis_output_tlast(e_tlast)"
puts $fh "  );"
puts $fh ""
puts $fh "  rs_dec_0 u_dec ("
puts $fh "    .aclk(aclk),"
puts $fh "    .s_axis_input_tdata(e_tdata), .s_axis_input_tvalid(e_tvalid), .s_axis_input_tready(), .s_axis_input_tlast(e_tlast), .s_axis_input_tuser(d_tuser),"
puts $fh "    .m_axis_output_tdata(d_tdata), .m_axis_output_tvalid(d_tvalid), .m_axis_output_tlast(d_tlast)"
puts $fh "  );"
puts $fh ""
puts $fh "  // LFSR for reproducible pseudo-random erasures"
puts $fh "  int lfsr = 32'h1;"
puts $fh "  function int prand(int max);
    lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
    prand = lfsr % (max+1);
  endfunction"
puts $fh ""
puts $fh "  int ticks; initial ticks = 0; always @(posedge aclk) ticks++;"
puts $fh "  int S, C, start_tick, end_tick;"
puts $fh "  int ok=0, tot=0;"
puts $fh "  int drop_a, drop_b, outn, got, match, exp;"
puts $fh "  int cw_start, cw_end;"
puts $fh "  integer fd;"
puts $fh "  initial begin"
puts $fh "    s_tdata='0; s_tvalid=0; s_tlast=0; d_tuser=0;"
puts $fh "    repeat (5) @(posedge aclk);"
puts $fh "    S = (BYTES*8 + M - 1)/M;"
puts $fh "    C = (S + K - 1)/K;"
puts $fh {    $display("CFG M=%0d K=%0d N=%0d BYTES=%0d => S=%0d symbols, C=%0d codewords per packet", M,K,N,BYTES,S,C);}
puts $fh {    fd = $fopen("ede_detail.csv", "w");}
puts $fh {    $fwrite(fd, "packet,cw,drop_a,drop_b,match,cw_cycles\n");}
puts $fh "    // choose two packet streams to drop for the entire run (whole-packet erasure)"
puts $fh "    drop_a = prand(N-1); do drop_b = prand(N-1); while (drop_b==drop_a);"
puts $fh {    $display("DROP streams: %0d and %0d", drop_a, drop_b);}
puts $fh "    start_tick = ticks;"
puts $fh "    for (int p = 0; p < PACKETS; p++) begin"
puts $fh "      for (int cw = 0; cw < C; cw++) begin"
puts $fh "        // drive K info symbols to encoder"
puts $fh "        for (int i = 0; i < K; i++) begin"
puts $fh "          @(posedge aclk); s_tvalid <= 1'b1; s_tdata <= (i + cw*K + p*S); s_tlast <= (i==K-1); wait(s_tready);"
puts $fh "        end"
puts $fh "        @(posedge aclk); s_tvalid <= 1'b0; s_tlast <= 1'b0;"
puts $fh "        // feed encoder outputs into decoder, applying whole-packet erasures on drop_a/drop_b"
puts $fh "        outn=0; d_tuser <= 0;"
puts $fh "        while (outn < N) begin"
puts $fh "          @(posedge aclk);"
puts $fh "          if (e_tvalid) begin"
puts $fh "            d_tuser <= ((outn==drop_a) || (outn==drop_b));"
puts $fh "            outn++;"
puts $fh "          end"
puts $fh "        end"
puts $fh "        // collect K decoder outputs and verify equality to inputs 0..K-1"
puts $fh "        got=0; match=1; exp=0;"
puts $fh "        cw_start = ticks;"
puts $fh "        while (got < K) begin"
puts $fh "          @(posedge aclk); if (d_tvalid) begin got++; match &= (d_tdata==exp); exp++; end"
puts $fh "        end"
puts $fh "        cw_end = ticks;"
puts $fh {        $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d\n", p, cw, drop_a, drop_b, match, (cw_end - cw_start));}
puts $fh "        tot++; ok += match;"
puts $fh "      end"
puts $fh "    end"
puts $fh "    end_tick = ticks;"
puts $fh {    $display("RESULT ok/tot=%0d/%0d cycles=%0d", ok, tot, end_tick - start_tick);}
puts $fh {    $fclose(fd);}
puts $fh {    repeat(10) @(posedge aclk); $finish;}
puts $fh "  end"
puts $fh "endmodule"
close $fh

add_files -fileset sim_1 $tb_file
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
# 延长仿真以覆盖 3×1500B、C=400 的全量码字统计
run 20 ms
close_sim
puts "[clock format [clock seconds]] INFO: EDE Simulation completed."


