# CS-FEC RTL Implementation

简单的循环移位 + XOR MDS FEC 硬件实现。

## 文件说明

| 文件 | 说明 |
|------|------|
| `cyclic_shift.sv` | 参数化循环移位模块 |
| `cs_encoder_2_3.sv` | (2,3) MDS 编码器：2 数据 → 3 编码符号 |
| `cs_decoder_2_3.sv` | (2,3) MDS 解码器：支持单符号纠删 |
| `cs_codec_tb.sv` | 编解码器测试平台 |

## 参数配置

当前实现使用 `(m=2, k=3, L=5)` 配置：
- **m=2**: 2 个数据符号
- **k=3**: 3 个编码符号（2 数据 + 1 校验）
- **L=5**: 每个符号 4 bits (L-1)
- **容错**: 可恢复任意 1 个符号丢失

## 编码原理

```
编码矩阵 G (系统形式):
[1  0]     coded_0 = data_0
[0  1]     coded_1 = data_1
[α  α²]    coded_2 = shift(data_0, 1) XOR shift(data_1, 2)
```

其中 α 是 GF(2^4) 的本原元，对应循环右移 1 位。

## 解码原理

根据擦除位置选择恢复策略：

| 擦除 | 恢复方法 |
|------|----------|
| coded_0 | `inv_shift(coded_2 XOR shift(coded_1, 2), 1)` |
| coded_1 | `inv_shift(coded_2 XOR shift(coded_0, 1), 2)` |
| coded_2 | 无需恢复（系统码） |

## 仿真

### 使用 iverilog

```bash
cd rtl
iverilog -g2012 -o cs_tb.vvp cyclic_shift.sv cs_encoder_2_3.sv cs_decoder_2_3.sv cs_codec_tb.sv
vvp cs_tb.vvp
```

### 使用 Vivado

```tcl
# 在 Vivado Tcl console 中
cd <project_path>/rtl
xvlog -sv cyclic_shift.sv cs_encoder_2_3.sv cs_decoder_2_3.sv cs_codec_tb.sv
xelab cs_codec_tb -debug typical
xsim cs_codec_tb -runall
```

### 使用 ModelSim/QuestaSim

```bash
cd rtl
vlog -sv cyclic_shift.sv cs_encoder_2_3.sv cs_decoder_2_3.sv cs_codec_tb.sv
vsim -c cs_codec_tb -do "run -all"
```

## 资源估计

对于 (2,3) 配置：
- **编码器**: ~20 LUTs, 12 FFs
- **解码器**: ~50 LUTs, 10 FFs
- **延迟**: 1 时钟周期

## 扩展

要支持其他 (m, k) 配置：
1. 修改 Python 代码生成对应的移位量表
2. 根据移位量修改 RTL 中的 `SHIFT_AMT` 参数
3. 增加/减少数据输入端口数量
