# 查询 RS IP 参数名称
set part "xczu3eg-sfvc784-1-e"

file delete -force query_proj
create_project query_proj query_proj -part $part -force

# 创建 RS Encoder 并列出所有参数
puts "\n========== RS Encoder 参数 =========="
create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_test
set props [list_property [get_ips rs_enc_test] CONFIG.*]
foreach p $props {
    set val [get_property $p [get_ips rs_enc_test]]
    puts "  $p = $val"
}

# 创建 RS Decoder 并列出所有参数
puts "\n========== RS Decoder 参数 =========="
create_ip -name rs_decoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_dec_test
set props [list_property [get_ips rs_dec_test] CONFIG.*]
foreach p $props {
    set val [get_property $p [get_ips rs_dec_test]]
    puts "  $p = $val"
}

close_project
file delete -force query_proj
exit

