# CSNC: 循环移位 + XOR FEC（CS）与 RS 对照仓库

本仓库研究以"循环移位 + XOR"完成编码，并以矩阵乘法完成解码的 CS（Circular-Shift）方案，与传统 RS（矩阵乘法编码 + 高斯消元解码）进行实现与资源对比。

- 目标：在硬件侧显著节约 LUT/寄存器资源，利于高吞吐、低面积实现。
- 语言/工具：SystemVerilog + Vivado 2025.1，Python 3.10+（算法与绘图）。

## 📁 项目结构

```
csnc/
├── core/                   # 核心算法实现
│   ├── cyc_matrix.py      # 循环移位矩阵
│   ├── helper_matrix.py   # 辅助矩阵
│   ├── vandermonde.py     # 范德蒙德矩阵
│   └── tests/
│       └── matrix_test.py # 算法回归测试
│
├── tools/                  # 工具脚本
│   ├── generate_masks.py  # 掩码生成器（无外部依赖）
│   ├── visualize.py       # 资源可视化
│   └── summarize_reports.py # 报告汇总
│
├── rtl/                    # RTL设计
│   ├── encoder/           # CS编码器
│   ├── decoder/           # CS解码器
│   ├── top/               # 顶层设计
│   ├── testbench/         # 测试平台
│   └── generated/         # 自动生成的系数文件
│
├── scripts/                # Vivado TCL脚本
│   ├── sim/               # 仿真脚本
│   ├── synth/             # 综合脚本
│   ├── impl/              # 实现脚本
│   └── utils/             # 工具脚本
│
├── docs/                   # 文档
│   ├── algorithm/         # 算法文档
│   ├── hardware/          # 硬件分析
│   ├── paper/             # 论文相关
│   └── patent.txt         # 专利信息
│
└── reports/                # 报告输出
```

## 🚀 快速开始

### 环境要求

- Python 3.10+ （掩码生成无需依赖；可视化需要 matplotlib）
- Vivado 2025.1 （Windows/Linux）

### 安装 Python 依赖（可选）

```bash
# 掩码生成工具完全独立，无需依赖
# 如需算法开发和可视化，安装：
pip install -r requirements.txt
```

### 1️⃣ 生成 CS 掩码

示例：L=11, M=3, K=5，使用列 0/1/2

```bash
python tools/generate_masks.py \
  --L 11 --M 3 --K 5 --avail 0 1 2 \
  --out rtl/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh
```

### 2️⃣ 运行仿真

行为级仿真（含编码→解码管线测试）：

```bash
vivado -mode batch -source scripts/sim/cs_pipeline_tb.tcl \
  -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e
```

### 3️⃣ 综合与资源对比

生成 CS 编/解码器的综合报告（ZU3EG，L=11,K=5,M=3）：

```bash
vivado -mode batch -source scripts/synth/cs_dual_project.tcl \
  -tclargs ./vivado_cs_dual xczu3eg-sbva484-1-e 11 5 3
```

### 4️⃣ 可视化资源对比

生成 SVG 图表和 CSV 数据：

```bash
python tools/visualize.py \
  --label CS-ENC --in vivado_cs_dual/enc_utilization.rpt \
  --label CS-DEC --in vivado_cs_dual/dec_utilization.rpt \
  --label RS-ENC --in docs/hardware/zu3eg_rs_resources.md --grep rs_enc_0 \
  --label RS-DEC --in docs/hardware/zu3eg_rs_resources.md --grep rs_dec_0 \
  --out reports/cs_rs_util.svg --csv reports/cs_rs_util.csv \
  --title "Resource Utilization: ZU3EG L=11 K=5 M=3"
```

输出：
- 图表：`reports/cs_rs_util.svg`（色盲友好配色）
- 数据：`reports/cs_rs_util.csv`（适用于论文附表）

## 🔧 高级用法

### AXU3EG（ZU3EG）XSA 构建（PS+PL）

使用 PS `pl_clk0`/`proc_sys_reset` 驱动 PL 内编解码器：

```bash
vivado -mode batch -source scripts/impl/cs_ps_axu3eg_xsa.tcl \
  -tclargs ./vivado_cs_axu3eg xczu3eg-sbva484-1-e 11 5 3
# 输出：vivado_cs_axu3eg/axu3eg_cs_ps.xsa（含 bitstream）
```

### 实现截图工程（纯 PL）

仅保留 `aclk/aresetn` 两个 IO，便于布局布线截图：

```bash
vivado -mode batch -source scripts/impl/cs_pair_impl_project.tcl \
  -tclargs ./vivado_cs_impl xczu3eg-sbva484-1-e 11 5 3 5.0
# 输出：vivado_cs_impl/impl_timing_summary.rpt, impl_utilization.rpt
```

## 🧪 运行测试

```bash
# 核心算法回归测试
cd core
python -m pytest tests/matrix_test.py

# 或直接运行
python tests/matrix_test.py
```

## 🧹 清理

```bash
# 仅清理日志/备份
pwsh scripts/utils/clean_repo.ps1

# 包括 Vivado 工作目录一并清理
pwsh scripts/utils/clean_repo.ps1 -All
```

## 📚 文档索引

- **算法说明**：[`docs/algorithm/framework.md`](docs/algorithm/framework.md)
- **CS vs RS 对比**：[`docs/algorithm/fec_vs_rs.md`](docs/algorithm/fec_vs_rs.md)
- **RS 编码器分析**：[`docs/hardware/rs_encoder_analysis.md`](docs/hardware/rs_encoder_analysis.md)
- **资源报告**：[`docs/hardware/zu3eg_rs_resources.md`](docs/hardware/zu3eg_rs_resources.md)
- **论文附录**：[`docs/paper/appendix.md`](docs/paper/appendix.md)

## 🤝 贡献指南

详见 [`AGENTS.md`](AGENTS.md) 中的开发规范和提交流程。

欢迎贡献可综合、可复用的 RTL 与验证方案！

---

遇到问题或需要扩展（如 AXI-Lite 外设、AXIS 数据通道、DMA/PS 驱动示例），欢迎提 Issue。
