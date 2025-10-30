# AMD/Xilinx Reed-Solomon Encoder 分析（v9.x）

本文总结 AMD LogiCORE RS Encoder 的典型接口、参数与时序特性，给出与本项目（循环移位+XOR FEC）对照与联调建议。

## 概述
- 功能：在 GF(2^m) 上实现系统码 RS 编码，输出顺序通常为“信息符号 K 个 + 校验 2t 个”。支持短码（Shortened RS）与交织。
- 使用场景：AXI4-Stream 输入输出，1 拍/符号的持续吞吐；可选 AXI4-Lite 进行运行时配置，静态配置则无控制口。

## 接口与关键参数
- 时钟与复位：`aclk`，`aresetn`（低有效）。
- AXI4-Stream 输入：`s_axis_tdata[m-1:0]`，`s_axis_tvalid/tready/tlast`（K 符号末置位）。
- AXI4-Stream 输出：`m_axis_tdata[m-1:0]`，`m_axis_tvalid/tready/tlast`（N=K+2t 符号末置位）。
- 典型参数：
  - `SYMBOL_WIDTH=m`（GF(2^m) 位宽）。
  - `N, K, T`（块长 n、信息 k、纠错能力 t，满足 n=K+2t；Shortened RS 由 K<n 的装载长度/填充决定）。
  - 域与码多项式：Primitive Polynomial、First Root、Generator Polynomial（影响兼容性与综合结构）。
  - `Interleaving Depth`（可选交织深度）。

## 数据流与时序
- 输入帧：连续喂入 K 个符号，末符号 `s_axis_tlast=1`；遵循 `tvalid && tready` 握手。
- 输出帧：延迟若干拍后，以 1 符号/拍输出 N 个符号，通常先 K 个信息、再 2t 个校验；末符号 `m_axis_tlast=1`。
- 持续吞吐：若 `m_axis_tready=1`，可实现满速流；回压时保持 AXIS 语义。
- 延迟特性（经验性）：
  - 首字至首输出延迟约为若干级管线（实现相关）；
  - 帧级延迟近似为 K（数据通过）+ 2t（校验尾）+ 管线深度；
  - 吞吐上限为 1 符号/拍（单通道配置）。

## 资源与规模趋势
- 资源随 `m` 与 `t` 增长：乘法/加法器数量与生成多项式相关；寄存器形成 LFSR/寄存链。一般远低于 RS 解码器的资源与时序复杂度。
- 交织、并行与更高时钟目标会增加 LUT/寄存器与布线压力。

## 验证与联调
- 最小测试：
  1) 固定 `(N,K,m,t)`，静态配置，产生一帧长度 K 的已知序列（计数/PRBS）。
  2) 记录输出 N 符号，验证系统码属性：前 K 符号等于输入，最后 2t 为校验。
  3) 多帧背靠背，验证 `tready` 回压、`tlast` 对齐、跨帧状态复位。
- 与本项目对比：
  - 统一符号位宽 `m` 与分帧方式（以 `TLAST` 对齐块边界）。
  - 固定 `(N,K)` 与吞吐策略，收集资源/时序以对比循环移位 FEC。
  - 输出日志中记录每帧校验段，便于与软件参考（`algo/matrix_test.py`）的冗余策略差异对齐。

## Vivado 快速上手（Tcl 片段）
```tcl
# 创建并自定义 RS 编码器（需按实际版本调整）
create_ip -name rs_encoder -vendor xilinx.com -library ip -version 9.0 -module_name rs_enc_0
# 可在 GUI 设置 SYMBOL_WIDTH/N/K/T/多项式，或使用 set_property 配置参数
# 打开示例工程便于查看端口与示例 testbench
open_example_design -force [get_ips rs_enc_0]
```

或直接使用仓库脚本自动创建最小工程与仿真：

```bash
vivado -mode batch -source scripts/rs_encoder_min_tb.tcl \
  -tclargs ./vivado_rs_tb xc7z010clg225-1 10 15 11 2
```
参数依次为：工程目录、器件、符号位宽 m、块长 n、信息符号 k、纠错能力 t。

## 与循环移位 FEC 的映射关系
- 二者均为系统码，便于在同一帧结构下对比资源与吞吐。
- 我方编码器为组合/浅流水的“移位+XOR”结构，资源更低；RS 编码器为域上多项式结构，校验生成以 LFSR/乘法器为主。
- 对比建议：使用相同 `K`、符号位宽 `m`，记录 LUT/寄存器、Fmax、首字/帧延迟；详见 `algo/fec_vs_rs.md` 的报告模板。
