# AMD RS 编码器仿真测试报告（周期统计)

## 概要
- 对象：AMD/Xilinx LogiCORE Reed-Solomon Encoder v9.0（AXI4-Stream）。
- 目的：评估在固定参数下对多包输入的时钟拍数（周期）消耗，并与理论估算对照。
- 设备与工具：Vivado 2025.1（Windows），器件 `xc7z010clg225-1`，IP 许可为 Hardware_Evaluation（不影响仿真）。

## 配置与场景
- 固定参数（系统码）：`N=5, K=3`（即每码字3个信息符号+2个校验符号）。
- 符号位宽：`M=10` bit/符号（与仓库内 data_width=10 的资源对照一致）。
- 负载：`1500 Byte`/包（=12000 bit），连续 3 包。
- 代码与命令：
  ```bash
  vivado -mode batch -source scripts/rs_encoder_bench_cycles.tcl \
    -tclargs ./vivado_rs_bench xc7z010clg225-1 10 5 3 1500 3
  ```
  脚本会生成并运行 `tb_rs_bench.sv`，统计总拍数，打印 `CFG ...` 和 `RESULT ...`。

## 实测结果（拍数）
- 编码器（严格串行，bench_cycles 脚本）：
  - 控制台：`RESULT total cycles for 3 packets: 10800`
  - 理由：每码字近似 `K+N=3+5=8` 拍，3×400 码字≈9600 拍，外加起停/间隙≈10800 拍。
- 端到端（编码→整包擦除→解码，ede 脚本）：
  - CFG：`M=10 K=3 N=5 BYTES=1500 => S=1200, C=400`；固定整包丢弃两条流（`DROP streams: a and b`）。
  - 明细输出：生成 `ede_detail.csv`（列：`packet,cw,drop_a,drop_b,match,cw_cycles`）。已将脚本仿真窗口从 `run 2 ms` 延长为 `run 20 ms`，可覆盖 1200 码字并得到完整统计。

## CSV 汇总（方法）
- 位置：`vivado_rs_ede/rs_ede.sim/sim_1/behav/xsim/ede_detail.csv`。
- 指标：
  - 成功率：`match` 的均值（应为 1）。
  - 周期：对 `cw_cycles` 计算均值、P95、最大值；并累计得到 3×1500B 的总拍数（端到端）。
- 建议：附带 `RESULT ok/tot=... cycles=...` 的总览打印，以对齐编码器单项的 10800 拍情况。

## 理论对照与差异
- 记 `S=ceil(1500×8/M)=1200`，`C=ceil(S/K)=400`。
- 理想序列（不额外空转，码字内部输出与输入可重叠，且每码字需额外输出2个校验符号）：
  - 每包 ≈ `N × C = 5 × 400 = 2000` 拍；3 包 ≈ `6000` 拍。
- 本次实测 `10800` 拍，较理想值存在约 `+4800` 拍：来源于（a）等待输出时未计入输入阶段已重叠的系统码输出，形成 `+K×C×PACKETS`；（b）每码字之间 1 拍的 `valid` 低电平，形成 `+1×C×PACKETS`。

## 结论与建议
- 本次 `10800` 拍为严格串行驱动条件下的上界；工程化流水化驱动应更接近 `~6000` 拍（加上少量管线起停开销）。
- 如需得到更贴近实际的数据面吞吐：
  - 改进 testbench，使“输出计数”与“输入推动”并行进行，避免对系统码输出的二次计数；
  - 去掉码字之间的 1 拍 `valid` 间隙；
  - 输出 CSV：记录（包序号、码字序号、起始拍、结束拍、输出 LAST）便于与软件侧对齐。

## 复现实验
- 运行上方命令；结果将打印在 Vivado 控制台并写出 `vivado_rs_bench/tb_rs_bench.sv`（可再次运行仿真查看波形）。
- 参数可按 `scripts/rs_encoder_bench_cycles.tcl` 的入口说明修改 `M,N,K,Bytes,Packets` 以覆盖其他工况。

## 面向 ZU3EG 的板卡目标
- 目标器件可从 Zynq-7000 切换为 Zynq UltraScale+（例如 ZU3EG）。推荐示例 part：`xczu3eg-sbva484-1-e`。
- 调用示例（周期统计）：
  ```bash
  vivado -mode batch -source scripts/rs_encoder_bench_cycles.tcl \
    -tclargs ./vivado_rs_bench xczu3eg-sbva484-1-e 10 5 3 1500 3
  ```
- 调用示例（端到端整包擦除）：
  ```bash
  vivado -mode batch -source scripts/rs_encode_decode_erase_tb.tcl \
    -tclargs ./vivado_rs_ede xczu3eg-sbva484-1-e 10 5 3 1500 3
  ```
- 若需资源与时序：我可补充批处理综合脚本，自动 `synth_design` 并导出 `report_utilization`/`report_timing_summary` 为 CSV，覆盖多组 (m,N,K)。

## 资源占用与时序（获取方法）
- 新增脚本：`scripts/rs_synth_util_report.tcl`
  - 示例（ZU3EG）：
    ```bash
    vivado -mode batch -source scripts/rs_synth_util_report.tcl \
      -tclargs ./vivado_rs_synth xczu3eg-sbva484-1-e 10 5 3
    ```
  - 产物：`utilization.rpt`/`utilization.csv`、`timing_summary.rpt`，位于指定的工程目录。
  - 注意：RS 解码器资源/时序显著高于编码器；符号位宽 `m`、纠错深度 `t=(N-K)/2` 增长会放大乘法器/查找表规模。

### ZU3EG 资源结果（记录流程）
- 运行综合后，使用脚本汇总为 Markdown：
  ```bash
  python scripts/summarize_utilization.py \
    --rpt vivado_rs_synth/utilization.rpt \
    --out verilog/zu3eg_rs_resources.md \
    --device xczu3eg-sbva484-1-e
  ```
- 生成文件：`verilog/zu3eg_rs_resources.md`。请将其与本报告一并提交，作为 ZU3EG 资源占用与层级实例的正式记录。

### ZU3EG 资源结果（当前配置 K=3,N=5,m=10）
- 汇总（来自 `vivado_rs_synth/utilization.rpt`，详见 `verilog/zu3eg_rs_resources.md`）：
  - Encoder `rs_enc_0`: LUT=47, REG=92, BRAM_18K=0, URAM=0, DSP=0
  - Decoder `rs_dec_0`: LUT=12360, REG=10479, BRAM_18K=1, URAM=0, DSP=0
- 说明：解码器资源远高于编码器；若切换参数（更大 `m` 或更大冗余 `N-K`），解码器规模增幅更明显。
