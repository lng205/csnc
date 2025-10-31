# 循环移位 FEC RTL 模块说明

本目录提供可综合的 SystemVerilog 实现，用于在 FPGA 上加速循环移位 FEC 编解码流程。模块按照“矩阵运算内核 → 解码 → 编码 → 流式封装”的层次划分，便于在不同系统中独立复用或组合使用。

## 核心模块

| 文件 | 说明 |
| --- | --- |
| `cs_encoder_static.sv` | 示例 CS 编码器（组合逻辑，固定系数）。以“循环左移 + XOR”实现系统码编码，`L=11` 对应 10bit 符号。 |
| `cs_decoder_static.sv` | 示例 CS 解码器（组合逻辑，固定系数）。按逆矩阵掩码对 K 路输入做移位+XOR，恢复 M 路数据。 |

## 测试/综合脚本

- `scripts/cs_synth_util_report.tcl`：综合 `cs_encoder_static`，导出 `utilization.rpt` 与时序摘要。
- `scripts/cs_dec_synth_util_report.tcl`：综合 `cs_decoder_static`，导出 `utilization.rpt` 与时序摘要。
- `scripts/rs_synth_util_report.tcl`：批量综合 RS 编解码器，导出 per-IP 与顶层资源报告。

## 报告与结果

- RS：`verilog/rs_bench_report.md`（周期）与 `verilog/zu3eg_rs_resources.md`（资源）。
- CS：`verilog/cs_bench_report.md`（资源）。

## 使用提示

1. 在添加模块到工程前，请确保 `requirements.txt` 所需 Python 库已安装，并运行脚本生成对应的常量系数顶层。
2. 如果仅需解码或编码功能，可直接实例化 `fec_decoder` 或 `fec_encoder`；完整链路则使用 `fec_codec` 或 `fec_codec_stream`。
3. RS IP 需要 Vivado 提供的官方许可证，批处理脚本会出现 `hardware_evaluation` 提示，但不影响资源评估。

如需进一步了解系统级集成与实验流程，请参考仓库根目录的 README 及 `algo/fec_vs_rs.md`。
