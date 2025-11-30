# ============================================================
# 从已综合的 DCP 文件中提取资源数据
# ============================================================

set work_dir [file dirname [info script]]
cd $work_dir

set proj_dir "rs_benchmark_proj"
set output_file "rs_ip_results_extracted.csv"

puts "============================================================"
puts " 从 DCP 文件提取 RS IP 资源数据"
puts "============================================================"

# 查找所有 DCP 文件
set dcp_files [glob -nocomplain "$proj_dir/rs_bench.gen/sources_1/ip/*/*.dcp"]

puts "\n找到 [llength $dcp_files] 个 DCP 文件:\n"

# 打开输出文件
set fp [open $output_file w]
puts $fp "ip_name,type,n,k,symbol_width,lut,ff,bram,dsp"

foreach dcp $dcp_files {
    set ip_name [file rootname [file tail $dcp]]
    puts "处理: $ip_name"
    
    # 解析 IP 名称获取参数 (格式: rs_enc_n_k_Xb 或 rs_dec_n_k_Xb)
    if {[regexp {rs_(enc|dec)_(\d+)_(\d+)_(\d+)b} $ip_name match type n k sw]} {
        puts "  类型: $type, RS($n,$k), ${sw}bit"
    } else {
        puts "  无法解析 IP 名称"
        continue
    }
    
    # 加载检查点
    if {[catch {open_checkpoint $dcp} err]} {
        puts "  打开检查点失败: $err"
        continue
    }
    
    # 生成资源报告
    set rpt_file "${work_dir}/${ip_name}_util.rpt"
    report_utilization -file $rpt_file
    
    # 提取资源数据
    set lut 0
    set ff 0
    set bram 0
    set dsp 0
    
    set rpt_fp [open $rpt_file r]
    set content [read $rpt_fp]
    close $rpt_fp
    
    # 提取 LUT
    if {[regexp {Slice LUTs\*?\s*\|\s*(\d+)} $content match val]} {
        set lut $val
    } elseif {[regexp {CLB LUTs\*?\s*\|\s*(\d+)} $content match val]} {
        set lut $val
    }
    
    # 提取 FF
    if {[regexp {Slice Registers\s*\|\s*(\d+)} $content match val]} {
        set ff $val
    } elseif {[regexp {CLB Registers\s*\|\s*(\d+)} $content match val]} {
        set ff $val
    }
    
    # 提取 BRAM
    if {[regexp {Block RAM Tile\s*\|\s*(\d+\.?\d*)} $content match val]} {
        set bram $val
    }
    
    # 提取 DSP
    if {[regexp {DSPs\s*\|\s*(\d+)} $content match val]} {
        set dsp $val
    }
    
    puts "  LUT=$lut, FF=$ff, BRAM=$bram, DSP=$dsp"
    puts $fp "$ip_name,$type,$n,$k,$sw,$lut,$ff,$bram,$dsp"
    
    close_design
    
    # 删除临时报告文件
    file delete $rpt_file
}

close $fp

puts "\n============================================================"
puts " 完成! 结果保存至: $output_file"
puts "============================================================"

# 读取结果
puts "\n结果预览:"
set fp [open $output_file r]
puts [read $fp]
close $fp

exit

