# CSNC: 循环移位 + XOR FEC（CS）与 RS 对照仓库

本仓库研究以“循环移位 + XOR”完成编码，并以矩阵乘法完成解码的 CS（Circular-Shift）方案，与传统 RS（矩阵乘法编码 + 高斯消元解码）进行实现与资源对比。

- 目标：在硬件侧显著节约 LUT/寄存器资源，利于高吞吐、低面积实现。
- 语言/工具：SystemVerilog + Vivado 2025.1，Python 3.10+（算法与绘图）。
- 结构：`algo/` 为算法与掩码生成，`verilog/` 为 RTL 与 TB，`scripts/` 为 Vivado/Python 脚本。

## 目录速览

- `algo/`
  - `generate_cs_masks_standalone.py`：生成 CS 编/解码掩码（不依赖外部库）。
  - 其它算法基线与说明：`framework.md`、`fec_vs_rs.md` 等。
- `verilog/`
  - `cs_encoder_static.sv` / `cs_decoder_static.sv`：核心组合逻辑（移位 + XOR）。
  - `cs_pair_top.sv` / `cs_pair_impl_top.sv`：实现封装与双核实例化顶层。
  - `cs_pipeline_tb.sv`：行为级 TB（含 include 掩码）。
- `scripts/`
  - `cs_pipeline_tb.tcl`：TB 仿真。
  - `cs_dual_project.tcl`：分别综合 CS 编码器/译码器并导出利用率/时序。
  - `cs_ps_axu3eg_xsa.tcl`：AXU3EG（ZU3EG）PS+PL 工程，生成 bit 并导出 XSA。
  - `cs_pair_impl_project.tcl`：纯 PL 实现截图工程（仅时钟/复位 IO）。
  - `plot_utilization.py`：解析报告并生成“学术标准”图与 CSV。
  - `clean_repo.ps1`：清理本地 Vivado 产物/日志。

## 环境

- Python 3.10+（可选安装 matplotlib/numpy 以导出 PNG；SVG 无需依赖）
- Vivado 2025.1（Windows/Linux）

## 快速仿真（CS 管线）

1) 生成掩码（示例：L=11, M=3, K=5，使用列 0/1/2）

```bash
python algo/generate_cs_masks_standalone.py \
  --L 11 --M 3 --K 5 --avail 0 1 2 \
  --out verilog/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh
```

2) 运行行为仿真（包含 include 掩码；完成后打印 PASS）

```bash
vivado -mode batch -source scripts/cs_pipeline_tb.tcl \
  -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e
```

## CS/RS 资源对比出图与数据

1) 生成 CS 编/解码器的综合利用率报告（ZU3EG，L=11,K=5,M=3）

```bash
vivado -mode batch -source scripts/cs_dual_project.tcl \
  -tclargs ./vivado_cs_dual xczu3eg-sbva484-1-e 11 5 3
```

2) 出图（SVG）与导出 CSV（学术排版友好）

```bash
python scripts/plot_utilization.py \
  --label CS-ENC --in vivado_cs_dual/enc_utilization.rpt \
  --label CS-DEC --in vivado_cs_dual/dec_utilization.rpt \
  --label RS-ENC --in verilog/zu3eg_rs_resources.md --grep rs_enc_0 \
  --label RS-DEC --in verilog/zu3eg_rs_resources.md --grep rs_dec_0 \
  --out reports/cs_rs_util.svg --csv reports/cs_rs_util.csv \
  --title "Resource Utilization: ZU3EG L=11 K=5 M=3"
```

- 图：`reports/cs_rs_util.svg`（色盲友好配色，图例位于右上角且带白底，不遮挡网格/数据）。
- 数据：`reports/cs_rs_util.csv`（首行含设备注释，便于论文附表/版本归档）。

备注：`plot_utilization.py` 可解析 Vivado `.rpt` 与 Markdown 摘要。若无 matplotlib，自动回退生成 SVG；安装 matplotlib/numpy 可导出 300 dpi PNG。

## AXU3EG（ZU3EG）XSA 构建（PS+PL）

使用 PS `pl_clk0`/`proc_sys_reset` 驱动 PL 内 `cs_pair_impl_top`（同时实例化编码器/译码器，彼此独立）：

```bash
vivado -mode batch -source scripts/cs_ps_axu3eg_xsa.tcl \
  -tclargs ./vivado_cs_axu3eg xczu3eg-sbva484-1-e 11 5 3
# 输出 XSA：vivado_cs_axu3eg/axu3eg_cs_ps.xsa（含 bitstream）
```

说明：该 XSA 不绑定外部 PL IO，适合在 Vitis 建平台并由软件侧通过 PS 访问；如需 AXI-Lite/AXIS/DMA，可在此 BD 基础上扩展。

## 实现截图工程（纯 PL）

仅保留 `aclk/aresetn` 两个 IO，内部激励防剪枝，便于布局布线截图：

```bash
vivado -mode batch -source scripts/cs_pair_impl_project.tcl \
  -tclargs ./vivado_cs_impl xczu3eg-sbva484-1-e 11 5 3 5.0
# 输出：vivado_cs_impl/impl_timing_summary.rpt, impl_utilization.rpt, impl_post_route.dcp
```

## 清理

```bash
# 仅清理日志/备份
pwsh scripts/clean_repo.ps1
# 包括 Vivado 工作目录一并清理
pwsh scripts/clean_repo.ps1 -All
```

## 参考/说明

- CS 掩码、生成与验证流程见 `algo/` 与 `verilog/cs_pipeline_tb.sv`。
- RS 侧参考 `verilog/rs_encoder_analysis.md` 与 `verilog/zu3eg_rs_resources.md`（示例汇总）。
- 若需要在 README 中展示具体数字，请将对应 `.rpt` 和 CSV 附上版本来源（器件/版本/命令）。

---

遇到问题或需要扩展（如 AXI-Lite 外设壳层、AXIS 数据通道、DMA/PS 驱动示例），欢迎提 Issue。我们乐于接受可综合、可复用的 RTL 与验证贡献。
