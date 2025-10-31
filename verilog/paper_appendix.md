#! 用循环移位+XOR替代RS的FEC方案：方法与结果（论文补充材料）

## 摘要
- 提出一种以“循环左移+按位异或（CS）”代替GF(2^m)乘加的线性分组码实现：
  - 编码：直接以移位+XOR表达生成矩阵的列组合。
  - 解码：以同样的移位+XOR表达逆矩阵的行组合（固定擦除集）。
- 在软件端性能不占优的前提下，该方案在硬件端显著降低LUT/寄存器/存储占用，适合高吞吐、低面积场景。

## 方法
- 域映射：将每个(L−1)位符号前置1位奇偶位，提升到L位循环域；GF(2^m)元素由一个L位掩码表示，1的位置集合对应若干次循环左移后XOR叠加。
- 线性运算：
  - 编码矩阵E∈GF(2^m)^{K×M} → 掩码阵CS_ENC_COEFF[K][M]；
  - 逆矩阵D∈GF(2^m)^{M×M} → 掩码阵CS_DEC_COEFF[M][K]（仅对可用列非零）。
- 生成矩阵（系统码）：Vandermonde [I | V]；GF算术由多项式实现（默认w=L−1=10，原始多项式x^10+x^3+1）。

## 硬件映射
- 单个“系数×符号”核为：对提升后的L位符号执行若干次rotl和XOR；当掩码1的个数>⌊(L−1)/2⌋时先按位取反以减半移位数。
- 组合版本：每行（输出符号）并行聚合M个输入；寄存器为可选的流水点。

## 实验设置
- EDA/器件：Vivado 2025.1（Windows），器件xczu3eg-sbva484-1-e；仅做综合与逻辑级仿真，不进行上板实现。
- 典型参数：L=11（10位符号），M=3，K=5；RS侧对应m=10、K=3、N=5。
- 工具链与脚本：
  - 掩码生成：`algo/generate_cs_masks_standalone.py`（无外部依赖）。
  - CS 综合：`scripts/cs_synth_util_report.tcl`、`scripts/cs_dec_synth_util_report.tcl`。
  - RS 综合：`scripts/rs_synth_util_report.tcl` + `scripts/summarize_utilization.py`。
  - 逻辑仿真：`scripts/cs_pipeline_tb.tcl`（encoder→decoder，固定擦除集）。

## 结果
- 资源占用（ZU3EG，合成后）：
  - CS 编码器：LUT=14，REG=0，BRAM=0，DSP=0。
  - CS 解码器：LUT=24，REG=0，BRAM=0，DSP=0。
  - RS 编码器：LUT=47，REG=92，BRAM=0，DSP=0。
  - RS 解码器：LUT=12360，REG=10479，BRAM=1，DSP=0。
- 周期（行为级TB，仅用于基线对比）：
  - RS 编码器（K=3,N=5,m=10，3×1500B）：10800拍（严格串行驱动，上界）。
- 正确性：
  - CS 组合流水线（encoder→decoder）在固定擦除集下恢复输入：PASS。

## 讨论
- 资源：CS编/解码均为移位+XOR的组合逻辑，LUT近似随“掩码1位数×输入数×位宽”线性增长；与RS IP相比，尤其在解码侧资源显著降低。
- 吞吐：行为级串行TB给出上界拍数；工程化流水（输入/输出重叠、去除码字间隙）有望进一步降低周期。
- 解码通用性：
  - 本文给出固定擦除集的逆矩阵掩码（便于落地与评估）。
  - 面向通用丢包模式，可引入可编程矩阵装载与擦除选择逻辑，或按场景生成多组掩码在片上切换。

## 复现
- 掩码生成：
  ```bash
  python algo/generate_cs_masks_standalone.py \
    --L 11 --M 3 --K 5 --avail 0 1 2 \
    --out verilog/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh
  ```
- CS 逻辑仿真：
  ```bash
  vivado -mode batch -source scripts/cs_pipeline_tb.tcl \
    -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e
  ```
- CS 综合（资源）：
  ```bash
  vivado -mode batch -source scripts/cs_synth_util_report.tcl \
    -tclargs ./vivado_cs_synth xczu3eg-sbva484-1-e 11 5 3
  vivado -mode batch -source scripts/cs_dec_synth_util_report.tcl \
    -tclargs ./vivado_cs_dec_synth xczu3eg-sbva484-1-e 11 5 3
  ```
- RS 综合（资源）：
  ```bash
  vivado -mode batch -source scripts/rs_synth_util_report.tcl \
    -tclargs ./vivado_rs_synth xczu3eg-sbva484-1-e 10 5 3
  python scripts/summarize_utilization.py \
    --rpt vivado_rs_synth/utilization.rpt \
    --out verilog/zu3eg_rs_resources.md \
    --device xczu3eg-sbva484-1-e
  ```

## 限制与展望
- 限制：当前解码侧验证在固定擦除集；端到端RS仿真中不同IP版本的擦除标注语义需额外校准（与tuser匹配）。
- 展望：
  - 设计AXI-Stream外壳与可编程系数装载，实现任意擦除集下的在线解码。
  - 在更大参数空间(L,M,K)与不同稀疏度下批量综合，绘制资源-吞吐Pareto曲线。
  - 原型FPGA上板评估Fmax与功耗，结合具体应用场景给出面积-能效优势。

