# CS-FEC RTL

参数化的循环移位 + XOR MDS FEC 硬件实现。

## 文件

| 文件 | 说明 |
|------|------|
| `cyclic_shift.sv` | 循环移位基础模块 |
| `cs_encoder.sv` | 参数化编码器 |
| `cs_decoder.sv` | 参数化解码器 |
| `cs_codec.sv` | 编解码器顶层封装 |
| `cs_config_pkg.sv` | 预定义配置包 |
| `cs_tb.sv` | 测试平台 |

## 参数

| 参数 | 说明 |
|------|------|
| `M` | 数据符号数 |
| `K` | 总符号数 (数据 + 校验) |
| `WIDTH` | 符号位宽 |
| `SHIFT_TABLE` | 编码移位表 `[K-M][M]` |
| `INV_SHIFT` | 解码逆移位表 `[K-M][M]` |

## 使用

```systemverilog
import cs_config_pkg::*;

cs_codec #(
    .M           (CFG_2_3_M),
    .K           (CFG_2_3_K),
    .WIDTH       (CFG_2_3_WIDTH),
    .SHIFT_TABLE (CFG_2_3_SHIFT),
    .INV_SHIFT   (CFG_2_3_INV)
) u_codec ( ... );
```

## 仿真

```bash
# Vivado
xvlog -sv cs_config_pkg.sv cyclic_shift.sv cs_encoder.sv cs_decoder.sv cs_codec.sv cs_tb.sv
xelab cs_tb -debug typical
xsim cs_tb -runall
```
