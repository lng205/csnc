#! 循环移位（CS）编解码资源分析（ZU3EG）

## 场景与方法
- 目标器件：`xczu3eg-sbva484-1-e`
- 模块：`verilog/cs_encoder_static.sv`（组合逻辑，固定系数）
- 参数：`L=11`（对应 10bit 符号）、`M=3` 输入、`K=5` 输出（前三路直通，后二路为移位+XOR 冗余）
- 命令：
  ```bash
  vivado -mode batch -source scripts/cs_synth_util_report.tcl \
    -tclargs ./vivado_cs_synth xczu3eg-sbva484-1-e 11 5 3
  ```

## 掩码生成与逻辑仿真
- 生成真实掩码（固定可用列 avail=0,1,2）：
  ```bash
  python algo/generate_cs_masks_standalone.py \
    --L 11 --M 3 --K 5 --avail 0 1 2 \
    --out verilog/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh
  ```
- 组合流水线仿真（encoder→decoder，固定擦除列 3,4）：
  ```bash
  vivado -mode batch -source scripts/cs_pipeline_tb.tcl \
    -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e
  ```
- 结果：PASS（decoder 输出与输入完全一致）。

## 资源结果（合成后）
- 编码器（cs_encoder_static.sv，`vivado_cs_synth/`）：
  - CLB 逻辑：LUT=14，寄存器=0（组合逻辑）
  - 存储/DSP：BRAM=0，URAM=0，DSP=0
- 解码器（cs_decoder_static.sv，`vivado_cs_dec_synth/`）：
  - CLB 逻辑：LUT=24，寄存器=0（组合逻辑）
  - 存储/DSP：BRAM=0，URAM=0，DSP=0
- 说明：两者的顶层 I/O 计数源自端口展开，不代表核心成本；以 LUT/FF 为主观察。

## 结论与对照
- CS 编码器（14 LUT）与 CS 解码器（24 LUT）都极轻量，均未使用寄存器/存储/DSP。
- 对比 RS：Encoder（LUT≈47，REG≈92）> CS 编码器；RS Decoder（LUT≈12360，REG≈10479，BRAM≈1）远大于 CS 解码器。
- 提醒：CS 解码的真实规模取决于掩码稀疏度与每行参与的输入数量；本报告默认系数为示例，工程化需由 algo 端生成逆矩阵掩码后重新综合评估。

## 后续
- 扩展 `cs_encoder_static`/`cs_decoder_static`：由 `algo/` 生成真实掩码（编码矩阵与逆矩阵），批量扫 (L,M,K) 与稀疏度，导出 CSV。
- 封装 AXI-Stream 外壳，评估接口与缓存对资源/时序的影响。
