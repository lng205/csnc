# CSNC

循环移位 + XOR MDS FEC 算法实现。

## 结构

```
csnc/
├── docs/          # 文档 (math.md, proof.md)
├── python/        # Python 算法实现与验证脚本
│   ├── csnc.py        # 核心算法实现
│   ├── gen_tb.py      # 生成 Verilog Testbench 的脚本
│   └── requirements.txt
├── rtl/           # Verilog 硬件实现
│   └── csnc_encoder.v # 编码器实现
├── sim/           # 仿真文件
│   └── csnc_tb.v      # 自动生成的 Testbench
├── README.md
└── .gitignore
```

## 快速开始

### 1. Python 算法验证

```bash
cd python
# 安装依赖
pip install -r requirements.txt

# 运行算法演示
python csnc.py

# 生成 Verilog 测试向量 (可选，已生成)
python gen_tb.py
```

### 2. RTL 仿真 (Vivado)

在项目根目录下运行：

```bash
# 1. 编译 Verilog 文件
xvlog rtl/csnc_encoder.v sim/csnc_tb.v

# 2. 生成仿真快照
xelab -debug typical -top csnc_tb -snapshot csnc_tb_snap

# 3. 运行仿真
xsim csnc_tb_snap -R
```

## 算法原理

利用循环移位矩阵在二进制域上同构表示有限域乘法，从而用简单的**循环移位 + XOR** 操作替代复杂的有限域乘法器，实现硬件友好的纠删码 (MDS Code)。

详细数学推导请参阅 [docs/math.md](docs/math.md) 和 [docs/proof.md](docs/proof.md)。