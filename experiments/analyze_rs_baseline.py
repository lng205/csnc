#!/usr/bin/env python3
"""
RS IP 基准测试结果分析脚本
对比 Xilinx RS IP 核与 CS-FEC 方案的资源消耗
"""

import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import font_manager

# ============================================================
# 学术论文图表样式设置
# ============================================================

# 中文宋体设置
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['SimSun', 'STSong', 'FangSong', 'Times New Roman']
plt.rcParams['font.sans-serif'] = ['SimSun', 'Microsoft YaHei']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['mathtext.fontset'] = 'stix'

# 图表尺寸和分辨率
plt.rcParams['figure.dpi'] = 150
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['savefig.bbox'] = 'tight'
plt.rcParams['savefig.pad_inches'] = 0.02

# 字号设置 (学术规范: 正文10-12pt)
plt.rcParams['font.size'] = 10.5
plt.rcParams['axes.labelsize'] = 10.5
plt.rcParams['xtick.labelsize'] = 9
plt.rcParams['ytick.labelsize'] = 9
plt.rcParams['legend.fontsize'] = 9

# 坐标轴样式
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['axes.edgecolor'] = 'black'

# 刻度线朝内 (学术规范)
plt.rcParams['xtick.direction'] = 'in'
plt.rcParams['ytick.direction'] = 'in'
plt.rcParams['xtick.major.size'] = 4
plt.rcParams['ytick.major.size'] = 4
plt.rcParams['xtick.major.width'] = 0.8
plt.rcParams['ytick.major.width'] = 0.8
plt.rcParams['xtick.top'] = True
plt.rcParams['ytick.right'] = True

# 图例样式
plt.rcParams['legend.frameon'] = True
plt.rcParams['legend.framealpha'] = 1.0
plt.rcParams['legend.edgecolor'] = 'black'
plt.rcParams['legend.fancybox'] = False
plt.rcParams['legend.borderpad'] = 0.4

# 网格
plt.rcParams['grid.linewidth'] = 0.5
plt.rcParams['grid.alpha'] = 0.4
plt.rcParams['grid.linestyle'] = '--'

# 柱状图
plt.rcParams['patch.linewidth'] = 0.8
plt.rcParams['patch.edgecolor'] = 'black'

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'results')
os.makedirs(OUTPUT_DIR, exist_ok=True)


def estimate_csfec_resources(n, k, symbol_width):
    """估算 CS-FEC 方案的资源消耗"""
    parity = n - k
    w = symbol_width
    
    xor_stages = max(1, (k - 1 + 1) // 2)
    encoder_luts = parity * xor_stages * w // 3
    encoder_ffs = n * w // 2
    
    selector_luts = w * 2
    decoder_xor_luts = xor_stages * w // 3
    decoder_luts = selector_luts + decoder_xor_luts
    decoder_ffs = k * w // 2
    
    return {
        'encoder_lut': max(encoder_luts, 10),
        'encoder_ff': encoder_ffs,
        'decoder_lut': max(decoder_luts, 15),
        'decoder_ff': decoder_ffs,
        'total_lut': max(encoder_luts, 10) + max(decoder_luts, 15),
        'total_ff': encoder_ffs + decoder_ffs,
    }


def load_rs_ip_results(csv_file='rs_ip_results.csv'):
    """加载 RS IP 基准测试结果"""
    if not os.path.exists(csv_file):
        print(f"[警告] 未找到文件: {csv_file}")
        return None
    
    results = []
    with open(csv_file, 'r', encoding='utf-8') as f:
        f.readline()  # skip header
        for line in f:
            values = line.strip().split(',')
            if len(values) >= 12:
                try:
                    n, k = int(values[0]), int(values[1])
                    sw, parity = int(values[2]), int(values[3])
                    enc_lut, enc_ff = int(values[4]), int(values[5])
                    dec_lut, dec_ff = int(values[8]), int(values[9])
                    dec_bram = float(values[10])
                    
                    if enc_lut == 0 and dec_lut == 0:
                        continue
                    
                    results.append({
                        'config': f"RS({n},{k})",
                        'n': n, 'k': k, 'symbol_width': sw, 'parity': parity,
                        'encoder_lut': enc_lut, 'encoder_ff': enc_ff,
                        'decoder_lut': dec_lut, 'decoder_ff': dec_ff,
                        'decoder_bram': dec_bram,
                        'total_lut': enc_lut + dec_lut,
                        'total_ff': enc_ff + dec_ff,
                    })
                except (ValueError, IndexError):
                    continue
    
    print(f"加载了 {len(results)} 条配置数据")
    return results


def analyze_and_compare():
    """分析对比"""
    print("=" * 60)
    print("RS IP vs CS-FEC 资源对比分析")
    print("=" * 60)
    
    rs_data = load_rs_ip_results()
    if not rs_data:
        return None, None
    
    csfec_data = []
    for rs in rs_data:
        cs = estimate_csfec_resources(rs['n'], rs['k'], rs['symbol_width'])
        cs['config'] = rs['config']
        cs['n'], cs['k'] = rs['n'], rs['k']
        cs['symbol_width'] = rs['symbol_width']
        csfec_data.append(cs)
    
    print("\n" + "=" * 80)
    print(f"{'配置':<12} {'RS编码器':>8} {'RS解码器':>8} {'RS合计':>8} {'CS-FEC':>8} {'节省':>8}")
    print("-" * 80)
    
    for i, rs in enumerate(rs_data):
        cs = csfec_data[i]
        reduction = (1 - cs['total_lut'] / rs['total_lut']) * 100 if rs['total_lut'] > 0 else 0
        print(f"{rs['config']:<12} {rs['encoder_lut']:>8} {rs['decoder_lut']:>8} "
              f"{rs['total_lut']:>8} {cs['total_lut']:>8} {reduction:>7.1f}%")
    
    return rs_data, csfec_data


def generate_figure(rs_data, csfec_data):
    """生成学术规范图表 (无标题, 中文宋体)"""
    print("\n生成图表...")
    
    configs = [r['config'] for r in rs_data]
    x = np.arange(len(configs))
    width = 0.35
    
    # ========== 图4: RS IP 编解码器资源分布 ==========
    fig, ax = plt.subplots(figsize=(7, 4.5))
    
    enc_luts = [r['encoder_lut'] for r in rs_data]
    dec_luts = [r['decoder_lut'] for r in rs_data]
    
    bars1 = ax.bar(x - width/2, enc_luts, width, label='RS编码器', 
                   color='#27ae60', edgecolor='black', linewidth=0.8, hatch='/')
    bars2 = ax.bar(x + width/2, dec_luts, width, label='RS解码器', 
                   color='#8e44ad', edgecolor='black', linewidth=0.8, hatch='\\\\')
    
    ax.set_xlabel('编码配置')
    ax.set_ylabel('LUT 数量')
    ax.set_xticks(x)
    ax.set_xticklabels(configs)
    ax.legend(loc='upper left')
    ax.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    # 添加数值标签
    for bar in bars1:
        h = bar.get_height()
        ax.annotate(f'{int(h)}', xy=(bar.get_x() + bar.get_width()/2, h),
                   xytext=(0, 2), textcoords='offset points',
                   ha='center', va='bottom', fontsize=8)
    for bar in bars2:
        h = bar.get_height()
        ax.annotate(f'{int(h)}', xy=(bar.get_x() + bar.get_width()/2, h),
                   xytext=(0, 2), textcoords='offset points',
                   ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig4_rs_encoder_decoder.pdf'), bbox_inches='tight')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig4_rs_encoder_decoder.png'), bbox_inches='tight', facecolor='white')
    print("  保存: fig4_rs_encoder_decoder.pdf")
    plt.close()
    
    # ========== 图5: RS IP vs CS-FEC 对比 ==========
    fig, ax = plt.subplots(figsize=(7, 4.5))
    
    rs_luts = [r['total_lut'] for r in rs_data]
    cs_luts = [c['total_lut'] for c in csfec_data]
    
    bars1 = ax.bar(x - width/2, rs_luts, width, label='Xilinx RS IP', 
                   color='#e74c3c', edgecolor='black', linewidth=0.8)
    bars2 = ax.bar(x + width/2, cs_luts, width, label='CS-FEC', 
                   color='#3498db', edgecolor='black', linewidth=0.8)
    
    ax.set_xlabel('编码配置')
    ax.set_ylabel('LUT 数量')
    ax.set_xticks(x)
    ax.set_xticklabels(configs)
    ax.legend(loc='upper left')
    ax.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    # 添加数值标签
    for bar in bars1:
        h = bar.get_height()
        ax.annotate(f'{int(h)}', xy=(bar.get_x() + bar.get_width()/2, h),
                   xytext=(0, 2), textcoords='offset points',
                   ha='center', va='bottom', fontsize=8)
    for bar in bars2:
        h = bar.get_height()
        ax.annotate(f'{int(h)}', xy=(bar.get_x() + bar.get_width()/2, h),
                   xytext=(0, 2), textcoords='offset points',
                   ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig5_rs_vs_csfec_lut.pdf'), bbox_inches='tight')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig5_rs_vs_csfec_lut.png'), bbox_inches='tight', facecolor='white')
    print("  保存: fig5_rs_vs_csfec_lut.pdf")
    plt.close()


def generate_latex_table(rs_data, csfec_data):
    """生成 LaTeX 表格"""
    print("\n生成表格...")
    
    latex = r"""\begin{table}[htbp]
\centering
\caption{Xilinx RS IP 与 CS-FEC 硬件资源对比}
\label{tab:rs_vs_csfec}
\begin{tabular}{lcccccc}
\toprule
\multirow{2}{*}{配置} & \multicolumn{3}{c}{Xilinx RS IP} & \multirow{2}{*}{CS-FEC} & \multirow{2}{*}{节省} & \multirow{2}{*}{BRAM} \\
\cmidrule(lr){2-4}
 & 编码器 & 解码器 & 合计 & & & \\
\midrule
"""
    
    for i, rs in enumerate(rs_data):
        cs = csfec_data[i]
        reduction = (1 - cs['total_lut'] / rs['total_lut']) * 100 if rs['total_lut'] > 0 else 0
        bram = rs.get('decoder_bram', 0)
        
        latex += f"{rs['config']} & {rs['encoder_lut']} & {rs['decoder_lut']} & {rs['total_lut']} & "
        latex += f"{cs['total_lut']} & {reduction:.1f}\\% & {bram} \\\\\n"
    
    latex += r"""\bottomrule
\end{tabular}
\end{table}
"""
    
    with open(os.path.join(OUTPUT_DIR, 'table_rs_vs_csfec.tex'), 'w', encoding='utf-8') as f:
        f.write(latex)
    print("  保存: table_rs_vs_csfec.tex")


def main():
    print("\n" + "=" * 60)
    print("RS IP 基准测试结果分析")
    print("=" * 60)
    
    rs_data, csfec_data = analyze_and_compare()
    
    if rs_data is None:
        print("缺少数据")
        return
    
    generate_figure(rs_data, csfec_data)
    generate_latex_table(rs_data, csfec_data)
    
    print("\n完成!")


if __name__ == "__main__":
    main()
