# RTL 实现

## (2, 3) MDS 码

- **cs_encoder_2_3.sv** - 编码器：2 个数据 → 3 个编码符号
- **cs_decoder_2_3.sv** - 解码器：可恢复 1 个擦除
- **cs_tb_2_3.sv** - 测试平台

## 参数

- WIDTH = 4 bits
- SHIFT_D0 = 1, SHIFT_D1 = 2
- INV_SHIFT_D0 = 3, INV_SHIFT_D1 = 2

## 仿真

```bash
# Vivado
xvlog -sv cs_encoder_2_3.sv cs_decoder_2_3.sv cs_tb_2_3.sv
xelab cs_tb_2_3 -s sim
xsim sim -runall
```
