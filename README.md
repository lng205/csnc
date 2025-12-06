# CSNC

循环移位 + XOR MDS FEC 算法实现。

## 结构

```
csnc/
├── csnc.py        # 单文件 Python 实现与示例入口
├── README.md
└── requirements.txt
```

## 快速开始

### Python 算法验证

```bash
pip install -r requirements.txt
python csnc.py
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
