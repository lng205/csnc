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
├── rtl/                    # Verilog 硬件实现
│   ├── cs_encoder.sv      # 编码器
│   ├── cs_decoder.sv      # 解码器
│   ├── cs_codec.sv        # 顶层封装
│   └── cs_config_pkg.sv   # 配置包
│
└── tools/
    └── gen_shift_table.py # 移位表生成工具
```

## 快速开始

### Python 算法

```bash
pip install numpy galois
python core/main.py
```

### RTL 仿真

```bash
cd rtl
xvlog -sv cs_config_pkg.sv cyclic_shift.sv cs_encoder.sv cs_decoder.sv cs_codec.sv cs_tb.sv
xelab cs_tb && xsim cs_tb -runall
```

## 算法原理

**(M, K) MDS 码**：M 个数据符号编码为 K 个符号，可恢复任意 K-M 个丢失。

**编码**：`Parity = XOR(cyclic_shift(data_i, shift_i))`

**解码**：`Data = inv_shift(Parity XOR other_shifted_data)`

优势：用循环移位 + XOR 替代有限域乘法，硬件友好。
