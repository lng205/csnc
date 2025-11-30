#!/usr/bin/env python3
"""
CS-FEC 实验脚本
用于生成毕业论文所需的实验数据和图表

实验内容：
1. 算法正确性验证 - 编解码一致性测试
2. 编码矩阵结构可视化
3. 计算复杂度对比分析
4. 硬件资源估算
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'core'))

import numpy as np
import matplotlib.pyplot as plt
from matplotlib import rcParams
import galois

from vandermonde import Van
from cyc_matrix import CyclicMatrix
from helper_matrix import HelperMatrix

# ============================================================
# 学术论文图表样式设置
# ============================================================

# 字体设置：中文宋体，英文 Times New Roman
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['SimSun', 'Times New Roman', 'DejaVu Serif']
plt.rcParams['font.sans-serif'] = ['SimSun', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['mathtext.fontset'] = 'stix'  # 数学字体，接近 Times New Roman

# 图表质量
plt.rcParams['figure.dpi'] = 150
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['savefig.bbox'] = 'tight'
plt.rcParams['savefig.pad_inches'] = 0.05

# 字号设置（学术论文规范：正文10-12pt）
plt.rcParams['font.size'] = 10.5
plt.rcParams['axes.titlesize'] = 11
plt.rcParams['axes.labelsize'] = 10.5
plt.rcParams['xtick.labelsize'] = 9
plt.rcParams['ytick.labelsize'] = 9
plt.rcParams['legend.fontsize'] = 9
plt.rcParams['figure.titlesize'] = 12

# 坐标轴和边框
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['axes.edgecolor'] = 'black'
plt.rcParams['axes.labelcolor'] = 'black'

# 刻度线设置（朝内是学术规范）
plt.rcParams['xtick.direction'] = 'in'
plt.rcParams['ytick.direction'] = 'in'
plt.rcParams['xtick.major.size'] = 4
plt.rcParams['ytick.major.size'] = 4
plt.rcParams['xtick.minor.size'] = 2
plt.rcParams['ytick.minor.size'] = 2
plt.rcParams['xtick.major.width'] = 0.8
plt.rcParams['ytick.major.width'] = 0.8
plt.rcParams['xtick.top'] = True
plt.rcParams['ytick.right'] = True

# 线条样式
plt.rcParams['lines.linewidth'] = 1.2
plt.rcParams['lines.markersize'] = 5

# 图例设置
plt.rcParams['legend.frameon'] = True
plt.rcParams['legend.framealpha'] = 1.0
plt.rcParams['legend.edgecolor'] = 'black'
plt.rcParams['legend.fancybox'] = False
plt.rcParams['legend.borderpad'] = 0.4
plt.rcParams['legend.labelspacing'] = 0.3

# 网格设置
plt.rcParams['grid.linewidth'] = 0.5
plt.rcParams['grid.alpha'] = 0.4
plt.rcParams['grid.linestyle'] = '--'

# 柱状图边框
plt.rcParams['patch.linewidth'] = 0.8
plt.rcParams['patch.edgecolor'] = 'black'

# 创建输出目录
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'results')
os.makedirs(OUTPUT_DIR, exist_ok=True)

GF2 = galois.GF(2)


def experiment_1_correctness():
    """
    实验1: 算法正确性验证
    验证不同 (M, K, L) 配置下的编解码一致性
    """
    print("=" * 60)
    print("实验1: 算法正确性验证")
    print("=" * 60)
    
    configs = [
        (2, 3, 5),   # 简单配置
        (3, 5, 5),   # 实用配置
        (4, 6, 7),   # 中等配置
        (4, 8, 9),   # 高冗余配置
        (5, 8, 9),   # 更大规模
        (6, 10, 11), # 大规模配置
    ]
    
    results = []
    num_trials = 100  # 每种配置测试次数
    
    for m, k, L in configs:
        print(f"\n测试配置: (M={m}, K={k}, L={L})")
        print(f"  数据符号数: {m}")
        print(f"  总符号数: {k}")
        print(f"  校验符号数: {k-m}")
        print(f"  符号位宽: {L-1} bits")
        print(f"  最大可恢复丢失: {k-m}")
        
        success_count = 0
        
        for trial in range(num_trials):
            try:
                van = Van(m, k, L - 1)
                c = CyclicMatrix(L)
                h = HelperMatrix(m, L)
                
                # 随机选择 m 个符号位置
                packets = np.random.choice(k, m, replace=False)
                
                # 编码矩阵
                e_alpha = van.M[:, packets]
                e = c.convert_matrix(e_alpha)
                
                # 解码矩阵
                d_alpha = van.invert(packets)
                d = c.convert_matrix(d_alpha)
                
                # 辅助矩阵
                zp, op, e, d = GF2(h.zp), GF2(h.op), GF2(e), GF2(d)
                
                # 验证满速率编解码
                res = zp @ e @ op @ zp @ d @ op
                
                if np.all(res == np.eye(m * (L - 1))):
                    success_count += 1
            except Exception as ex:
                pass
        
        success_rate = success_count / num_trials * 100
        results.append({
            'config': f"({m},{k})",
            'm': m, 'k': k, 'L': L,
            'parity': k - m,
            'width': L - 1,
            'success_rate': success_rate,
            'trials': num_trials
        })
        print(f"  成功率: {success_rate:.1f}% ({success_count}/{num_trials})")
    
    # 生成结果表格
    print("\n" + "=" * 60)
    print("实验1 结果汇总")
    print("=" * 60)
    print(f"{'配置':<10} {'数据':<6} {'校验':<6} {'位宽':<6} {'成功率':<10}")
    print("-" * 40)
    for r in results:
        print(f"{r['config']:<10} {r['m']:<6} {r['parity']:<6} {r['width']:<6} {r['success_rate']:.1f}%")
    
    return results


def experiment_2_matrix_visualization():
    """
    实验2: 编码矩阵结构可视化
    展示范德蒙德矩阵到循环移位矩阵的转换过程
    """
    print("\n" + "=" * 60)
    print("实验2: 编码矩阵结构可视化")
    print("=" * 60)
    
    # 使用 (2, 3, 5) 配置作为示例
    m, k, L = 2, 3, 5
    
    van = Van(m, k, L - 1)
    c = CyclicMatrix(L)
    h = HelperMatrix(m, L)
    
    print(f"\n配置: (M={m}, K={k}, L={L})")
    print(f"\n1. 范德蒙德矩阵 (GF(2^{L-1})):")
    print(van.M)
    
    # 选择特定列进行编码
    packets = [0, 1]  # 选择前两列
    e_alpha = van.M[:, packets]
    print(f"\n2. 选择列 {packets} 后的编码矩阵:")
    print(e_alpha)
    
    # 转换为循环移位矩阵
    e = c.convert_matrix(e_alpha)
    print(f"\n3. 转换后的循环移位矩阵 ({e.shape[0]}x{e.shape[1]}):")
    
    # 创建可视化
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    
    # 图1: 范德蒙德矩阵
    ax1 = axes[0]
    im1 = ax1.imshow(van.M, cmap='Blues', aspect='auto')
    ax1.set_title(f'范德蒙德矩阵\n(M={m}, K={k}, GF($2^{{{L-1}}}$))', fontsize=11)
    ax1.set_xlabel('列索引 (符号位置)')
    ax1.set_ylabel('行索引')
    for i in range(van.M.shape[0]):
        for j in range(van.M.shape[1]):
            ax1.text(j, i, str(van.M[i, j]), ha='center', va='center', fontsize=9)
    plt.colorbar(im1, ax=ax1, shrink=0.6)
    
    # 图2: 循环移位基矩阵 C_L
    ax2 = axes[1]
    im2 = ax2.imshow(c.C, cmap='Greens', aspect='equal')
    ax2.set_title(f'循环移位基矩阵 $C_{{{L}}}$\n({L}×{L})', fontsize=11)
    ax2.set_xlabel('列索引')
    ax2.set_ylabel('行索引')
    for i in range(c.C.shape[0]):
        for j in range(c.C.shape[1]):
            ax2.text(j, i, str(c.C[i, j]), ha='center', va='center', fontsize=9)
    
    # 图3: 转换后的编码矩阵
    ax3 = axes[2]
    im3 = ax3.imshow(e, cmap='Oranges', aspect='auto')
    ax3.set_title(f'转换后的编码矩阵\n({e.shape[0]}×{e.shape[1]}, GF(2))', fontsize=11)
    ax3.set_xlabel('列索引')
    ax3.set_ylabel('行索引')
    plt.colorbar(im3, ax=ax3, shrink=0.6)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig1_matrix_transform.png'), 
                bbox_inches='tight', facecolor='white')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig1_matrix_transform.pdf'), 
                bbox_inches='tight')
    print(f"\n图表已保存: fig1_matrix_transform.png/pdf")
    plt.close()
    
    # 辅助矩阵可视化
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    ax1 = axes[0]
    im1 = ax1.imshow(h.zp, cmap='Purples', aspect='auto')
    ax1.set_title(f'零填充矩阵 $Z_p$\n({h.zp.shape[0]}×{h.zp.shape[1]})', fontsize=11)
    ax1.set_xlabel('列索引')
    ax1.set_ylabel('行索引')
    plt.colorbar(im1, ax=ax1, shrink=0.6)
    
    ax2 = axes[1]
    im2 = ax2.imshow(h.op, cmap='Reds', aspect='auto')
    ax2.set_title(f'一填充矩阵 $O_p$\n({h.op.shape[0]}×{h.op.shape[1]})', fontsize=11)
    ax2.set_xlabel('列索引')
    ax2.set_ylabel('行索引')
    plt.colorbar(im2, ax=ax2, shrink=0.6)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig2_helper_matrices.png'), 
                bbox_inches='tight', facecolor='white')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig2_helper_matrices.pdf'), 
                bbox_inches='tight')
    print(f"图表已保存: fig2_helper_matrices.png/pdf")
    plt.close()
    
    return van.M, e


def experiment_3_complexity_analysis():
    """
    实验3: 计算复杂度对比分析
    对比传统 GF 乘法与循环移位+XOR 的复杂度
    """
    print("\n" + "=" * 60)
    print("实验3: 计算复杂度对比分析")
    print("=" * 60)
    
    configs = [
        (2, 3, 5),
        (3, 5, 5),
        (4, 6, 7),
        (4, 8, 9),
        (5, 8, 9),
        (6, 10, 11),
        (8, 12, 13),
    ]
    
    results = []
    
    for m, k, L in configs:
        n = k - m  # 校验符号数
        w = L - 1  # 位宽
        
        # 传统 Reed-Solomon (GF 乘法)
        # 编码: 每个校验符号需要 m 次 GF 乘法和 m-1 次 GF 加法
        # GF(2^w) 乘法复杂度: O(w^2) 位操作
        # GF(2^w) 加法复杂度: O(w) 位操作 (XOR)
        rs_mul_ops = n * m * (w * w)  # GF 乘法
        rs_add_ops = n * (m - 1) * w   # GF 加法
        rs_total = rs_mul_ops + rs_add_ops
        
        # CS-FEC (循环移位 + XOR)
        # 编码: 每个校验符号需要 m 次循环移位和 m-1 次 XOR
        # 循环移位: 纯布线，0 逻辑操作 (硬件中)
        # XOR: O(w) 位操作
        cs_shift_ops = 0  # 循环移位在硬件中是免费的
        cs_xor_ops = n * (m - 1) * w
        cs_total = cs_shift_ops + cs_xor_ops
        
        # 复杂度比
        reduction = (1 - cs_total / rs_total) * 100 if rs_total > 0 else 0
        
        results.append({
            'config': f"({m},{k},{L})",
            'm': m, 'k': k, 'L': L,
            'rs_ops': rs_total,
            'cs_ops': cs_total,
            'reduction': reduction
        })
        
        print(f"\n配置 ({m}, {k}, L={L}):")
        print(f"  传统 RS 操作数: {rs_total}")
        print(f"  CS-FEC 操作数: {cs_total}")
        print(f"  复杂度降低: {reduction:.1f}%")
    
    # 可视化
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    configs_labels = [r['config'] for r in results]
    rs_ops = [r['rs_ops'] for r in results]
    cs_ops = [r['cs_ops'] for r in results]
    reductions = [r['reduction'] for r in results]
    
    # 图1: 操作数对比
    ax1 = axes[0]
    x = np.arange(len(configs_labels))
    width = 0.35
    bars1 = ax1.bar(x - width/2, rs_ops, width, label='传统 RS (GF乘法)', 
                    color='#e74c3c', edgecolor='black', linewidth=0.8)
    bars2 = ax1.bar(x + width/2, cs_ops, width, label='CS-FEC (移位+XOR)', 
                    color='#3498db', edgecolor='black', linewidth=0.8)
    ax1.set_xlabel('编码配置 (M, K, L)')
    ax1.set_ylabel('位操作数')
    ax1.set_title('编码计算复杂度对比')
    ax1.set_xticks(x)
    ax1.set_xticklabels(configs_labels, rotation=45, ha='right')
    ax1.legend(loc='upper left')
    ax1.set_yscale('log')
    ax1.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    # 图2: 复杂度降低百分比
    ax2 = axes[1]
    # 使用绿色渐变表示优化效果
    colors = plt.cm.Greens(np.linspace(0.4, 0.8, len(reductions)))
    bars = ax2.bar(configs_labels, reductions, color=colors, edgecolor='black', linewidth=0.8)
    ax2.set_xlabel('编码配置 (M, K, L)')
    ax2.set_ylabel('复杂度降低 (%)')
    ax2.set_title('CS-FEC 相比传统 RS 的复杂度降低')
    ax2.set_xticklabels(configs_labels, rotation=45, ha='right')
    ax2.set_ylim(0, 105)
    ax2.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    # 添加数值标签
    for bar, val in zip(bars, reductions):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1, 
                f'{val:.1f}%', ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig3_complexity_comparison.png'), 
                bbox_inches='tight', facecolor='white')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig3_complexity_comparison.pdf'), 
                bbox_inches='tight')
    print(f"\n图表已保存: fig3_complexity_comparison.png/pdf")
    plt.close()
    
    return results


def experiment_4_hardware_estimation():
    """
    实验4: 硬件资源估算
    估算不同配置下的 FPGA 资源占用
    """
    print("\n" + "=" * 60)
    print("实验4: 硬件资源估算")
    print("=" * 60)
    
    configs = [
        (2, 3, 5),
        (3, 5, 5),
        (4, 6, 7),
        (4, 8, 9),
        (5, 8, 9),
        (6, 10, 11),
    ]
    
    results = []
    
    for m, k, L in configs:
        n = k - m  # 校验符号数
        w = L - 1  # 位宽
        
        # 编码器资源估算
        # 循环移位: 纯布线，不消耗 LUT
        # XOR 树: 每个 XOR 大约 1 LUT6 (6输入), 需要 ceil(log2(m)) 级
        # 每个校验符号需要 (m-1) 个 w-bit XOR
        xor_per_parity = (m - 1) * w
        encoder_luts = n * xor_per_parity // 2  # 2-input XOR per LUT
        
        # 解码器资源估算 (单丢失恢复)
        # 需要: 选择器 + XOR 树 + 逆移位
        # 选择器: 每 bit 需要 1 LUT
        # XOR: 与编码器类似
        decoder_luts = m * w + n * xor_per_parity // 2
        
        # 寄存器 (流水线)
        encoder_ffs = k * w  # 输出寄存器
        decoder_ffs = m * w  # 输出寄存器
        
        # 总计
        total_luts = encoder_luts + decoder_luts
        total_ffs = encoder_ffs + decoder_ffs
        
        # 对比传统 RS
        # GF 乘法器: 每个需要约 w^2 个 LUT
        rs_mul_luts = n * m * (w * w) // 4
        rs_total_luts = rs_mul_luts + encoder_luts  # 加上 XOR
        
        lut_reduction = (1 - total_luts / rs_total_luts) * 100 if rs_total_luts > 0 else 0
        
        results.append({
            'config': f"({m},{k})",
            'm': m, 'k': k, 'L': L, 'w': w,
            'enc_luts': encoder_luts,
            'dec_luts': decoder_luts,
            'total_luts': total_luts,
            'total_ffs': total_ffs,
            'rs_luts': rs_total_luts,
            'lut_reduction': lut_reduction
        })
        
        print(f"\n配置 ({m}, {k}, L={L}, 位宽={w}):")
        print(f"  编码器 LUTs: ~{encoder_luts}")
        print(f"  解码器 LUTs: ~{decoder_luts}")
        print(f"  总 LUTs: ~{total_luts}")
        print(f"  总 FFs: ~{total_ffs}")
        print(f"  传统 RS LUTs: ~{rs_total_luts}")
        print(f"  LUT 节省: {lut_reduction:.1f}%")
    
    # 可视化
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    configs_labels = [r['config'] for r in results]
    
    # 图1: LUT 使用对比
    ax1 = axes[0]
    x = np.arange(len(configs_labels))
    width = 0.35
    rs_luts = [r['rs_luts'] for r in results]
    cs_luts = [r['total_luts'] for r in results]
    
    bars1 = ax1.bar(x - width/2, rs_luts, width, label='传统 RS', 
                    color='#e74c3c', edgecolor='black', linewidth=0.8)
    bars2 = ax1.bar(x + width/2, cs_luts, width, label='CS-FEC', 
                    color='#3498db', edgecolor='black', linewidth=0.8)
    ax1.set_xlabel('编码配置 (M, K)')
    ax1.set_ylabel('LUT 数量 (估算)')
    ax1.set_title('FPGA LUT 资源对比')
    ax1.set_xticks(x)
    ax1.set_xticklabels(configs_labels)
    ax1.legend(loc='upper left')
    ax1.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    # 图2: 资源分布 (编码器 vs 解码器)
    ax2 = axes[1]
    enc_luts = [r['enc_luts'] for r in results]
    dec_luts = [r['dec_luts'] for r in results]
    
    bars1 = ax2.bar(x - width/2, enc_luts, width, label='编码器', 
                    color='#9b59b6', edgecolor='black', linewidth=0.8)
    bars2 = ax2.bar(x + width/2, dec_luts, width, label='解码器', 
                    color='#f39c12', edgecolor='black', linewidth=0.8)
    ax2.set_xlabel('编码配置 (M, K)')
    ax2.set_ylabel('LUT 数量 (估算)')
    ax2.set_title('CS-FEC 编解码器资源分布')
    ax2.set_xticks(x)
    ax2.set_xticklabels(configs_labels)
    ax2.legend(loc='upper left')
    ax2.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.4)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig4_hardware_resources.png'), 
                bbox_inches='tight', facecolor='white')
    plt.savefig(os.path.join(OUTPUT_DIR, 'fig4_hardware_resources.pdf'), 
                bbox_inches='tight')
    print(f"\n图表已保存: fig4_hardware_resources.png/pdf")
    plt.close()
    
    return results


def generate_latex_tables(all_results):
    """生成 LaTeX 格式的表格"""
    print("\n" + "=" * 60)
    print("生成 LaTeX 表格")
    print("=" * 60)
    
    latex_output = []
    
    # 表1: 算法正确性验证
    latex_output.append(r"""
% 表1: 算法正确性验证结果
\begin{table}[htbp]
\centering
\caption{CS-FEC 算法正确性验证结果}
\label{tab:correctness}
\begin{tabular}{cccccc}
\toprule
配置 & 数据符号 & 校验符号 & 符号位宽 & 测试次数 & 成功率 \\
\midrule
""")
    for r in all_results['correctness']:
        latex_output.append(f"({r['m']},{r['k']}) & {r['m']} & {r['parity']} & {r['width']} & {r['trials']} & {r['success_rate']:.1f}\\% \\\\\n")
    latex_output.append(r"""\bottomrule
\end{tabular}
\end{table}
""")
    
    # 表2: 计算复杂度对比
    latex_output.append(r"""
% 表2: 计算复杂度对比
\begin{table}[htbp]
\centering
\caption{CS-FEC 与传统 Reed-Solomon 计算复杂度对比}
\label{tab:complexity}
\begin{tabular}{ccccc}
\toprule
配置 & 传统 RS 操作数 & CS-FEC 操作数 & 复杂度降低 \\
\midrule
""")
    for r in all_results['complexity']:
        latex_output.append(f"{r['config']} & {r['rs_ops']} & {r['cs_ops']} & {r['reduction']:.1f}\\% \\\\\n")
    latex_output.append(r"""\bottomrule
\end{tabular}
\end{table}
""")
    
    # 表3: 硬件资源估算
    latex_output.append(r"""
% 表3: FPGA 硬件资源估算
\begin{table}[htbp]
\centering
\caption{CS-FEC FPGA 资源估算}
\label{tab:hardware}
\begin{tabular}{cccccc}
\toprule
配置 & 位宽 & 编码器 LUT & 解码器 LUT & 总 LUT & 传统 RS LUT \\
\midrule
""")
    for r in all_results['hardware']:
        latex_output.append(f"({r['m']},{r['k']}) & {r['w']} & {r['enc_luts']} & {r['dec_luts']} & {r['total_luts']} & {r['rs_luts']} \\\\\n")
    latex_output.append(r"""\bottomrule
\end{tabular}
\end{table}
""")
    
    latex_content = ''.join(latex_output)
    
    with open(os.path.join(OUTPUT_DIR, 'tables.tex'), 'w', encoding='utf-8') as f:
        f.write(latex_content)
    
    print(f"LaTeX 表格已保存: tables.tex")
    print("\n预览:")
    print(latex_content[:1000] + "...")
    
    return latex_content


def main():
    """运行所有实验"""
    print("\n" + "=" * 60)
    print("    CS-FEC 毕业论文实验")
    print("    循环移位 + XOR MDS 纠删码")
    print("=" * 60)
    
    all_results = {}
    
    # 运行实验
    all_results['correctness'] = experiment_1_correctness()
    all_results['matrices'] = experiment_2_matrix_visualization()
    all_results['complexity'] = experiment_3_complexity_analysis()
    all_results['hardware'] = experiment_4_hardware_estimation()
    
    # 生成 LaTeX 表格
    generate_latex_tables(all_results)
    
    # 总结
    print("\n" + "=" * 60)
    print("实验完成！")
    print("=" * 60)
    print(f"\n输出目录: {OUTPUT_DIR}")
    print("\n生成的文件:")
    for f in os.listdir(OUTPUT_DIR):
        print(f"  - {f}")
    
    print("\n图表说明:")
    print("  fig1: 编码矩阵转换可视化")
    print("  fig2: 辅助矩阵结构")
    print("  fig3: 计算复杂度对比")
    print("  fig4: 硬件资源估算")
    print("  tables.tex: LaTeX 格式数据表格")


if __name__ == "__main__":
    main()

