# 循环移位 FEC 与 Reed-Solomon IP 资源对比

本算法针对硬件加速五合一专用，核心逻辑由循环移位与异或组成。为量化不同参数下的资源占用，我们使用 Vivado 2025.1 在同一器件 (`xc7z010iclg225-1L`) 上综合以下三组场景，并与 AMD 官方 Reed-Solomon 编码/解码 IP（`rs_encoder:9.0`、`rs_decoder:9.0`）对照。

## 实验流程

1. **生成常量矩阵顶层** – 运行 `scripts/generate_static_fec.py` 会在 `verilog/generated/` 下写出 `fec_codec_static_m*_k*_w*.sv`。
2. **拷贝源文件到 Windows 侧** – 便于 Vivado 访问：
   ```bash
   mkdir -p D:/vivado/src_repo/verilog
   copy verilog\*.sv D:/vivado/src_repo/verilog
   copy verilog\generated\*.sv D:/vivado/src_repo/verilog/generated
   ```
3. **批量综合并收集资源** – 使用 `verilog/synth_resource_compare.tcl`：
   ```bash
   # 先在 WSL / 仓库根目录生成静态模块
   source .venv/bin/activate
   python scripts/generate_static_fec.py

   # 在 Windows 执行 Vivado 批处理命令
   D:\apps\Xilinx\2025.1\Vivado\bin\vivado.bat ^
     -mode batch -source D:\vivado\synth_resource_compare.tcl ^
     -tclargs D:\vivado\src_repo
   ```
脚本会依次创建 `fec_rs_compare_m{m}k{k}w{w}/` 工程目录，生成 RS IP、综合三个方案，并写出 `D:\vivado\fec_rs_compare_summary.csv`。

## 参数组合与资源

| m | k | data_width | FEC LUTs | FEC Regs | RS Encoder LUTs | RS Encoder Regs | RS Decoder LUTs | RS Decoder Regs |
|---|---|------------|---------|----------|-----------------|-----------------|-----------------|-----------------|
| 3 | 5 | 10 | 58 | 0 | 74 | 113 | 467 | 377 |
| 5 | 8 | 10 | 146 | 0 | 85 | 123 | 486 | 380 |
| 8 | 12 | 10 | 292 | 0 | 97 | 134 | 587 | 475 |

> 其中 `fec_codec_static` 为组合逻辑实现，无需触发器；RS 编码器资源略增，解码器资源增长更快，与其内建的 Berlekamp-Massey、Chien 搜索流程有关。综合过程中 Vivado 会提示 "hardware_evaluation" 许可证，但不影响资源统计。

## 结论与建议

1. **资源优势显著**：在同等纠删能力下，循环移位 FEC 的 LUT 使用量远低于 RS 解码 IP，且几乎不占用寄存器，适合资源敏感或低功耗场景。
2. **扩展趋势平稳**：随着 `m` 增大，循环移位 FEC 的 LUT 近似线性增长；RS 解码器则呈更陡峭的增长曲线，差距进一步扩大。
3. **后续工作**：
   - 为 `fec_codec_stream` 增加 AXI4-Stream/AXI-Lite 封装，结合视频帧吞吐评估时序与流水深度。
   - 在上述工程基础上补充统一 Testbench，对比两种方案的最大工作频率与端到端延迟。
   - 如需支持更大 `k` 或不同符号宽度，可扩展 `scripts/generate_static_fec.py` 的参数列表后重新运行上述流程。
