# ============================================================
# RS IP 核资源基准测试脚本 (Vivado 2025.1 兼容版)
# 用于获取 Xilinx Reed-Solomon IP 核的真实资源占用数据
# 作为 CS-FEC 方案的对比基线
# ============================================================

# 目标器件 (Zynq UltraScale+ ZU3EG)
set part "xczu3eg-sfvc784-1-e"

# 工作目录
set work_dir [file dirname [info script]]
cd $work_dir

# 项目目录
set proj_dir "rs_benchmark_proj"

# 输出文件
set output_file "rs_ip_results.csv"

# ============================================================
# RS 配置列表 (Vivado 2025.1 参数格式)
# 格式: {n k symbol_width 描述}
# n = 码长 (Symbol_Per_Block / Symbols_Per_Block)
# k = 数据符号数 (Data_Symbols)
# symbol_width = 符号位宽 (3-12)
# 校验符号数 = n - k
# ============================================================
set configs {
    {7    5   4   "RS(7,5)_4bit"}
    {15   11  4   "RS(15,11)_4bit"}
    {15   9   4   "RS(15,9)_4bit"}
    {31   27  5   "RS(31,27)_5bit"}
    {31   23  5   "RS(31,23)_5bit"}
    {63   55  6   "RS(63,55)_6bit"}
    {63   53  6   "RS(63,53)_6bit"}
    {127  117 7   "RS(127,117)_7bit"}
    {255  239 8   "RS(255,239)_8bit_DVB"}
    {255  223 8   "RS(255,223)_8bit"}
    {255  191 8   "RS(255,191)_8bit"}
}

# ============================================================
# 辅助函数: 从综合报告中提取资源数据
# ============================================================
proc extract_resources {rpt_file} {
    set lut 0
    set ff 0
    set bram 0
    set dsp 0
    
    if {![file exists $rpt_file]} {
        puts "    警告: 报告文件不存在 - $rpt_file"
        return [list 0 0 0 0]
    }
    
    set fp [open $rpt_file r]
    set content [read $fp]
    close $fp
    
    # 提取 Slice LUTs
    if {[regexp {Slice LUTs\s*\|\s*(\d+)} $content match val]} {
        set lut $val
    } elseif {[regexp {CLB LUTs\s*\|\s*(\d+)} $content match val]} {
        set lut $val
    } elseif {[regexp {LUT as Logic\s*\|\s*(\d+)} $content match val]} {
        set lut $val
    }
    
    # 提取 Slice Registers (FF)
    if {[regexp {Slice Registers\s*\|\s*(\d+)} $content match val]} {
        set ff $val
    } elseif {[regexp {CLB Registers\s*\|\s*(\d+)} $content match val]} {
        set ff $val
    } elseif {[regexp {Register as Flip Flop\s*\|\s*(\d+)} $content match val]} {
        set ff $val
    }
    
    # 提取 BRAM
    if {[regexp {Block RAM Tile\s*\|\s*(\d+\.?\d*)} $content match val]} {
        set bram $val
    } elseif {[regexp {RAMB36/FIFO\s*\|\s*(\d+)} $content match val]} {
        set bram $val
    } elseif {[regexp {RAMB18\s*\|\s*(\d+)} $content match val]} {
        set bram [expr {$val / 2.0}]
    }
    
    # 提取 DSP
    if {[regexp {DSPs\s*\|\s*(\d+)} $content match val]} {
        set dsp $val
    } elseif {[regexp {DSP48E2\s*\|\s*(\d+)} $content match val]} {
        set dsp $val
    }
    
    return [list $lut $ff $bram $dsp]
}

# ============================================================
# 辅助函数: 综合 IP 并获取资源报告
# ============================================================
proc synth_and_get_resources {ip_name proj_dir} {
    puts "    综合中..."
    
    # 综合 IP (OOC 模式)
    if {[catch {synth_ip [get_ips $ip_name] -force} err]} {
        puts "    综合失败: $err"
        return [list 0 0 0 0]
    }
    
    # 等待综合完成
    if {[catch {wait_on_run ${ip_name}_synth_1} err]} {
        puts "    等待综合失败: $err"
    }
    
    # 查找资源报告文件
    set synth_dir "$proj_dir/rs_bench.runs/${ip_name}_synth_1"
    set rpt_file "${synth_dir}/${ip_name}_utilization_synth.rpt"
    
    # 如果报告不存在，尝试手动生成
    if {![file exists $rpt_file]} {
        puts "    尝试生成资源报告..."
        if {[catch {
            open_run ${ip_name}_synth_1
            report_utilization -file $rpt_file
            close_design
        } err]} {
            puts "    生成报告失败: $err"
            return [list 0 0 0 0]
        }
    }
    
    puts "    读取报告: $rpt_file"
    return [extract_resources $rpt_file]
}

# ============================================================
# 主程序
# ============================================================
puts ""
puts "============================================================"
puts " Xilinx RS IP 核资源基准测试 (Vivado 2025.1)"
puts " 目标器件: $part"
puts "============================================================"
puts ""

# 删除已有项目
file delete -force $proj_dir

# 创建项目
puts "创建项目..."
create_project rs_bench $proj_dir -part $part -force

# 打开输出文件
set fp [open $output_file w]
puts $fp "n,k,symbol_width,parity,encoder_lut,encoder_ff,encoder_bram,encoder_dsp,decoder_lut,decoder_ff,decoder_bram,decoder_dsp,description"

# 遍历配置
foreach cfg $configs {
    set n [lindex $cfg 0]
    set k [lindex $cfg 1]
    set sw [lindex $cfg 2]
    set desc [lindex $cfg 3]
    set parity [expr {$n - $k}]
    
    puts ""
    puts "=========================================="
    puts " 测试 RS($n, $k), $sw-bit 符号"
    puts " 校验符号: $parity, 纠错能力: t=[expr {$parity/2}]"
    puts "=========================================="
    
    # 初始化结果
    set enc_lut 0
    set enc_ff 0
    set enc_bram 0
    set enc_dsp 0
    set dec_lut 0
    set dec_ff 0
    set dec_bram 0
    set dec_dsp 0
    
    # ========== RS Encoder ==========
    set enc_name "rs_enc_${n}_${k}_${sw}b"
    puts "\n  创建 RS Encoder IP: $enc_name"
    
    if {[catch {
        create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name $enc_name
        
        # Vivado 2025.1 正确的参数名称
        set_property -dict [list \
            CONFIG.Symbol_Width $sw \
            CONFIG.Symbol_Per_Block $n \
            CONFIG.Data_Symbols $k \
            CONFIG.Generator_Start {0} \
            CONFIG.Code_Specification {Custom} \
            CONFIG.Variable_Block_Length {false} \
            CONFIG.Memory_Style {Automatic} \
        ] [get_ips $enc_name]
        
        # 生成 IP 目标
        generate_target all [get_ips $enc_name]
        
        # 综合并获取资源
        set enc_result [synth_and_get_resources $enc_name $proj_dir]
        set enc_lut [lindex $enc_result 0]
        set enc_ff [lindex $enc_result 1]
        set enc_bram [lindex $enc_result 2]
        set enc_dsp [lindex $enc_result 3]
    } err]} {
        puts "    Encoder 创建/综合失败: $err"
    }
    
    puts "  Encoder 结果: LUT=$enc_lut, FF=$enc_ff, BRAM=$enc_bram, DSP=$enc_dsp"
    
    # ========== RS Decoder ==========
    set dec_name "rs_dec_${n}_${k}_${sw}b"
    puts "\n  创建 RS Decoder IP: $dec_name"
    
    if {[catch {
        create_ip -name rs_decoder -vendor xilinx.com -library ip -version 9.0 -module_name $dec_name
        
        # Vivado 2025.1 正确的参数名称 (注意 Symbols_Per_Block 有 's')
        set_property -dict [list \
            CONFIG.Symbol_Width $sw \
            CONFIG.Symbols_Per_Block $n \
            CONFIG.Data_Symbols $k \
            CONFIG.Generator_Start {0} \
            CONFIG.Code_Specification {Custom} \
            CONFIG.Variable_Block_Length {false} \
            CONFIG.Memory_Style {Automatic} \
        ] [get_ips $dec_name]
        
        # 生成 IP 目标
        generate_target all [get_ips $dec_name]
        
        # 综合并获取资源
        set dec_result [synth_and_get_resources $dec_name $proj_dir]
        set dec_lut [lindex $dec_result 0]
        set dec_ff [lindex $dec_result 1]
        set dec_bram [lindex $dec_result 2]
        set dec_dsp [lindex $dec_result 3]
    } err]} {
        puts "    Decoder 创建/综合失败: $err"
    }
    
    puts "  Decoder 结果: LUT=$dec_lut, FF=$dec_ff, BRAM=$dec_bram, DSP=$dec_dsp"
    
    # 写入结果
    puts $fp "$n,$k,$sw,$parity,$enc_lut,$enc_ff,$enc_bram,$enc_dsp,$dec_lut,$dec_ff,$dec_bram,$dec_dsp,$desc"
    flush $fp
    
    puts "\n  === RS($n,$k) 总计: LUT=[expr {$enc_lut + $dec_lut}], FF=[expr {$enc_ff + $dec_ff}] ==="
}

close $fp

# 关闭项目
close_project

puts ""
puts "============================================================"
puts " 基准测试完成!"
puts " 结果已保存至: $output_file"
puts "============================================================"
puts ""

# 读取并显示结果汇总
puts "结果汇总:"
puts "----------"
set fp [open $output_file r]
set header [gets $fp]
puts [format "%-20s %8s %8s %8s %8s %8s %8s" "配置" "Enc_LUT" "Enc_FF" "Dec_LUT" "Dec_FF" "Total_LUT" "Total_FF"]
puts [string repeat "-" 80]
while {[gets $fp line] >= 0} {
    set fields [split $line ","]
    set n [lindex $fields 0]
    set k [lindex $fields 1]
    set enc_lut [lindex $fields 4]
    set enc_ff [lindex $fields 5]
    set dec_lut [lindex $fields 8]
    set dec_ff [lindex $fields 9]
    set total_lut [expr {$enc_lut + $dec_lut}]
    set total_ff [expr {$enc_ff + $dec_ff}]
    puts [format "RS(%3d,%3d)          %8d %8d %8d %8d %8d %8d" $n $k $enc_lut $enc_ff $dec_lut $dec_ff $total_lut $total_ff]
}
close $fp

exit
