# 循环移位 FEC 算法与 FPGA 设计仓库

本仓库用于实现和验证基于循环移位的前向纠错（FEC）算法，涵盖 Python 参考实现、参数矩阵生成工具以及面向 FPGA 的 SystemVerilog 设计和综合脚本。重点目标是在视频流场景下，用移位 + 异或逻辑替代传统 Reed-Solomon（RS）有限域算术，实现低资源占用的高通量解码/编码结构。

## 目录结构

- `matrix/`：Python 侧的有限域工具与流水线测试（`matrix_test.py`）。
- `scripts/`：辅助脚本，如 `generate_static_fec.py` 用于生成固定系数模块。
- `verilog/`：SystemVerilog 源码、测试平台与 Vivado 脚本。
- `algo/`：论文撰写用的设计与对比文档。
- `framework.md`：整体流程的图示说明。

## 环境准备

### Python

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

完成后可运行 `python matrix/matrix_test.py` 输出参考流水线的阶段比特流。

### Vivado

本文档默认使用 Vivado 2025.1，目标器件为 `xc7z010iclg225-1L`。若使用其他版本或器件，请根据需要调整脚本参数。

## FPGA 模块总览

| 文件 | 功能简介 |
| --- | --- |
| `fec_matrix_apply.sv` | 将 Vandermonde 系数矩阵与符号向量进行移位+异或组合的核心运算模组。 |
| `fec_decoder.sv` | Parity 扩展 + 逆矩阵运算，输出升维后的符号。 |
| `fec_encoder.sv` | 重新组合编码矩阵并去除 parity，得到原始位宽。 |
| `fec_codec.sv` | 将解码器与编码器串联，保留调试探针。 |
| `fec_codec_stream.sv` | 带 `valid/ready` 握手与寄存器配置接口的流式外壳。 |
| `fec_codec_tb.sv`、`fec_codec_stream_tb.sv` | 行为仿真 testbench。 |
| `verilog/fec_codec_sim.tcl` | 自动执行组合与流式 testbench 的 xsim 仿真。 |
| `verilog/synth_resource_compare.tcl` | 批量综合循环移位 FEC 与 RS IP，输出资源统计。 |

## 矩阵生成与资源评估流程

1. **生成固定系数顶层（可选）**
   ```bash
   source .venv/bin/activate
   python scripts/generate_static_fec.py
   ```
   默认生成 `(m,k,data_width) = (3,5,10)、(5,8,10)、(8,12,10)` 三组静态模块，写入 `verilog/generated/`。

2. **拷贝源码到 Windows（如在 WSL 中操作）**
   ```bash
   mkdir -p D:/vivado/src_repo/verilog
   copy verilog\*.sv D:/vivado/src_repo/verilog
   copy verilog\generated\*.sv D:/vivado/src_repo/verilog/generated
   ```

3. **批处理综合并生成资源表**
   ```bat
   D:\apps\Xilinx\2025.1\Vivado\bin\vivado.bat ^
     -mode batch -source D:\vivado\synth_resource_compare.tcl ^
     -tclargs D:\vivado\src_repo
   ```
   脚本会依次生成 `fec_rs_compare_m%dk%dw%d` 工程目录，并将 LUT/寄存器统计结果写入 `D:/vivado/fec_rs_compare_summary.csv`。

4. **查看综合电路**
   在 Vivado GUI 中打开对应 `.xpr`，执行 *Open Synthesized Design* 后即可通过 *Schematic* 观察 `fec_decoder`、`fec_encoder` 或 AMD RS IP 的电路拓扑。

## 仿真指导

```bat
xvlog -sv fec_matrix_apply.sv fec_decoder.sv fec_encoder.sv fec_codec.sv fec_codec_tb.sv
xelab work.fec_codec_tb -s fec_codec_tb
xsim fec_codec_tb -runall
```

流式外壳仿真：

```bat
xvlog -sv fec_matrix_apply.sv fec_decoder.sv fec_encoder.sv ^
  fec_codec.sv fec_codec_stream.sv fec_codec_stream_tb.sv
xelab work.fec_codec_stream_tb -s fec_codec_stream_tb
xsim  fec_codec_stream_tb -runall
```
或直接调用 `vivado -mode batch -source verilog/fec_codec_sim.tcl` 一键执行。

## 资源对比摘要

自动综合脚本在 `XC7Z010ICLG225-1L` 上得到的 LUT/寄存器占用如下：

| m | k | data\_width | FEC LUTs | FEC Regs | RS Encoder LUTs | RS Encoder Regs | RS Decoder LUTs | RS Decoder Regs |
|---|---|------------|---------|----------|-----------------|-----------------|-----------------|-----------------|
| 3 | 5 | 10 | 58 | 0 | 74 | 113 | 467 | 377 |
| 5 | 8 | 10 | 146 | 0 | 85 | 123 | 486 | 380 |
| 8 | 12 | 10 | 292 | 0 | 97 | 134 | 587 | 475 |

可以看出循环移位 FEC 在保持相同纠删能力的同时，大幅降低了逻辑资源开销，并避免额外触发器。

## 论文与文档引用

- `algo/fec_vs_rs.md` 给出完整的实验流程、命令行示例以及 Vivado 报告的中文说明。
- 如需在学位论文中引用该部分内容，可直接引用上述流程及资源表。

## 后续工作建议

1. 将 `fec_codec_stream` 封装为 AXI4-Stream/AXI-Lite 接口，方便同高清视频链路对接。
2. 根据实际视频帧大小拓展 `scripts/generate_static_fec.py` 的参数组合，并扩充 `synth_resource_compare.tcl` 的循环列表。
3. 在 Vivado 中对不同参数的 Fmax、延迟与功耗进行进一步评估，以支撑工程化部署。

如需更多帮助或扩展功能，可在 `verilog/README.md` 中查看模块细节。
