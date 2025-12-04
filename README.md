# CSNC

循环移位 + XOR MDS FEC 算法实现。

## 结构

```
csnc/
├── core/                   # Python 算法实现
│   ├── vandermonde.py     # 范德蒙德矩阵 (GF(2^k))
│   ├── cyc_matrix.py      # 循环移位矩阵转换
│   ├── helper_matrix.py   # 辅助矩阵
│   └── main.py            # 测试
│
├── rtl/                    # SystemVerilog 硬件实现
│   ├── cs_encoder_2_3.sv  # (2,3) 编码器
│   ├── cs_decoder_2_3.sv  # (2,3) 解码器
│   └── cs_tb_2_3.sv       # 测试平台
│
└── tools/
    └── verify_2_3.py      # Python 验证脚本
```

## 快速开始

### Python 算法验证

```bash
pip install numpy galois
python tools/verify_2_3.py
```

### RTL 仿真 (Vivado)

```bash
cd rtl
xvlog -sv cs_encoder_2_3.sv cs_decoder_2_3.sv cs_tb_2_3.sv
xelab cs_tb_2_3 -s sim
xsim sim -runall
```

## 算法原理

**(2, 3) MDS 码**：2 个数据符号编码为 3 个符号，可恢复 1 个丢失。

**编码**：
```
p0 = shift(d0, 1) XOR shift(d1, 2)
输出: [d0, d1, p0]
```

**解码**：
- d0 丢失: `d0 = inv_shift(p0 XOR shift(d1, 2), 1)`
- d1 丢失: `d1 = inv_shift(p0 XOR shift(d0, 1), 2)`

**优势**：用循环移位 + XOR 替代有限域乘法，硬件友好。
