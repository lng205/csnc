# 循环移位 FEC RTL 模块说明

本目录提供可综合的 SystemVerilog 实现，用于在 FPGA 上加速循环移位 FEC 编解码流程。模块按照“矩阵运算内核 → 解码 → 编码 → 流式封装”的层次划分，便于在不同系统中独立复用或组合使用。

## 核心模块

| 文件 | 说明 |
| --- | --- |
| `fec_matrix_apply.sv` | 核心矩阵运算单元。对 Vandermonde 系数矩阵与符号向量执行移位 + XOR 组合。内部包含掩码翻转与循环移位函数。 |
| `fec_decoder.sv` | 独立解码模块，负责 parity 扩展并调用 `fec_matrix_apply` 完成逆矩阵运算。输出升维后的符号，用于后续编码或外部处理。 |
| `fec_encoder.sv` | 独立编码模块，接收升维后的符号，执行编码矩阵组合并回收 parity 位，输出原始宽度。 |
| `fec_codec.sv` | 顶层组合模块，将 decoder 与 encoder 串联，同时保留 `lifted`/`decoded`/`encoded` 调试端口。 |
| `fec_codec_stream.sv` | 时序化外壳，包含 `valid/ready` 握手、系数寄存器配置口（`cfg_we/cfg_select/cfg_index/cfg_data`）以及调试观测总线，便于与软件流水线对比。 |
| `cs_encoder_top.sv` | 示例顶层：将 `fec_encoder` 扁平化封装成单个模块，方便在 Vivado 工程中直接引用。 |

## 测试平台

- `fec_codec_tb.sv`：验证组合顶层的逐阶段输出是否与 Python 参考实现一致。
- `fec_codec_stream_tb.sv`：在流式接口下加载系数、发送固定负载并比对调试端口。
- `fec_codec_sim.tcl`：Vivado 批处理脚本，一键编译并执行上述两个 testbench。

## 综合与资源评估

- `synth_resource_compare.tcl`：批量综合循环移位 FEC 与 AMD 官方 RS Encoder/Decoder IP。脚本会生成多个工程目录，如 `fec_rs_compare_m3k5w10`，并在 `D:/vivado/fec_rs_compare_summary.csv` 中输出 LUT/寄存器统计结果。
- `generated/`：存放 `scripts/generate_static_fec.py` 自动产生的常量系数顶层（例如 `fec_codec_static_m3_k5_w10.sv`）。可根据需要修改脚本参数后重新生成。

## 使用提示

1. 在添加模块到工程前，请确保 `requirements.txt` 所需 Python 库已安装，并运行脚本生成对应的常量系数顶层。
2. 如果仅需解码或编码功能，可直接实例化 `fec_decoder` 或 `fec_encoder`；完整链路则使用 `fec_codec` 或 `fec_codec_stream`。
3. RS IP 需要 Vivado 提供的官方许可证，批处理脚本会出现 `hardware_evaluation` 提示，但不影响资源评估。

如需进一步了解系统级集成与实验流程，请参考仓库根目录的 README 及 `algo/fec_vs_rs.md`。
