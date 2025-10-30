# 硬件加速器与原始算法整理说明

本仓库聚焦一种基于“循环移位 + 异或”的 FEC 思路：
- 编码侧用按位循环移位和 XOR 组合实现（不再采用 RS 的矩阵乘法编码）。
- 解码侧使用矩阵乘法等线性代数手段（替代 RS 的高斯消元解码）。
该方法在纯软件上并无明显性能优势，但在硬件加速器上可显著节约 LUT/寄存器等资源，适合做高吞吐、低面积实现。目前尚无完全成熟的硬件版本，本项目也在寻求更优雅、可综合性强的 Verilog 设计方案与实践。

算法仿真与硬件实现并行推进：
- Python 仿真与研究放在 `algo/` 工作区，编码矩阵完全由循环移位矩阵构成，便于与硬件一一对应。
- SystemVerilog 硬件在 `verilog/`，配套生成脚本在 `scripts/`。

## 目录结构

- `algo/`：算法与仿真工作区（请在该目录内创建虚拟环境并运行）
  - `matrix_test.py`：按位循环移位 FEC 管线的回归与参考对比
  - `cyc_matrix.py`：循环移位矩阵与按位实现的转换
  - `helper_matrix.py`：符号位宽提升/回落的块对角辅助矩阵
  - `vandermonde.py`：GF(2^(L-1)) 上的系统范德蒙德矩阵与选列求逆
  - `framework.md`：处理流程与设计说明（本分析文档）
  - `fec_vs_rs.md`：与 RS IP 的资源对比与流程记录
  - `requirements.txt`：算法侧依赖清单
- `verilog/`：FEC 编解码 RTL、流式接口实现与 testbench，Vivado 脚本
- `scripts/`：生成静态系数/工程脚本（Python/TCL）

## 算法环境与运行

在 `algo/` 下创建并激活独立环境后运行脚本：

```bash
cd algo
python -m venv .venv
source .venv/bin/activate   # PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 运行矩阵管线回归与可视化（可重现随机种子见脚本）
python matrix_test.py

```

说明：`matrix_test.py` 展示“提升到循环移位域 → 线性解码 → 线性编码 → 去填充”的整条流水线；系数矩阵由 `vandermonde.py` 生成（GF(2^w)），以 `cyc_matrix.py` 的循环移位 + XOR 方式实现，可与 RTL 一一对应。

提示：`galois` 在部分系统上需要 C/C++ 编译环境（Windows 建议安装 Build Tools；Linux 建议安装 `build-essential`）。

## 硬件合成与仿真

硬件细节与使用说明见 `verilog/README.md`。要点：
- `fec_matrix_apply.sv`：将 Vandermonde 系数转为“循环左移 + XOR”的按位运算
- `fec_decoder.sv` / `fec_encoder.sv`：解码/编码（含 parity 提升/裁剪）
- `fec_codec(_stream).sv`：打包编解码顶层（含 valid/ready 流控版本）
- `generated/`：由 `scripts/generate_static_fec.py` 生成的静态系数顶层

Vivado 批处理合成、资源对比、以及 testbench 仿真 TCL 已提供，详见 `verilog/` 目录。目标器件既可使用 Zynq-7000（如 `xc7z010clg225-1`），也可换成 ZU3EG（如 `xczu3eg-sbva484-1-e`），在脚本参数中替换 part 即可。

另见 `algo/framework.md` 的“硬件编码器：最简版本设计”，提供固定参数下的组合逻辑编码器骨架与系数生成思路，便于快速起板与验证。

若需集成/对比 AMD RS 编码器，请参考 `verilog/rs_encoder_analysis.md`，其中包含接口、参数与联调建议，以及 Vivado Tcl 快速上手片段。也可直接运行：

```bash
vivado -mode batch -source scripts/rs_encoder_min_tb.tcl \
  -tclargs ./vivado_rs_tb xc7z010clg225-1 10 15 11 2
```

端到端编码/解码（含随机两符号擦除）测试：

```bash
vivado -mode batch -source scripts/rs_encode_decode_erase_tb.tcl \
  -tclargs ./vivado_rs_ede xc7z010clg225-1 10 5 3 1500 3
```

资源综合与汇总（ZU3EG 示例）：

```bash
vivado -mode batch -source scripts/rs_synth_util_report.tcl \
  -tclargs ./vivado_rs_synth xczu3eg-sbva484-1-e 10 5 3

python scripts/summarize_utilization.py \
  --rpt vivado_rs_synth/utilization.rpt \
  --out verilog/zu3eg_rs_resources.md \
  --device xczu3eg-sbva484-1-e
```
结果文档：`verilog/zu3eg_rs_resources.md`。

## 结果与对比

在 Zynq-7000（`XC7Z010ICLG225-1L`）资源对比（示例）：

| m | k | data_width | FEC LUTs | FEC Regs | RS Encoder LUTs | RS Encoder Regs | RS Decoder LUTs | RS Decoder Regs |
|---|---|------------|---------|----------|-----------------|-----------------|-----------------|-----------------|
| 3 | 5 | 10 | 58 | 0 | 74 | 113 | 467 | 377 |
| 5 | 8 | 10 | 146 | 0 | 85 | 123 | 486 | 380 |
| 8 | 12 | 10 | 292 | 0 | 97 | 134 | 587 | 475 |

更多背景、方法论与测评备注见 `algo/fec_vs_rs.md`。

## 后续工作

1. 在 `fec_codec_stream` 上挂接 AXI4-Stream/AXI-Lite（寄存器装载系数/选择包）
2. 扩展 `scripts/generate_static_fec.py` 的参数空间，并联动 `synth_resource_compare.tcl`
3. 增加 Fmax 时序收敛实验与位宽/并行度折中分析

如需进一步说明或添加新的实验，请在 `algo/` 下新增模块与文档，并复用 `algo/matrix/` 中的可重用数学工具。
