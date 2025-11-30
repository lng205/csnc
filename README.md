# CSNC: 循环移位 + XOR FEC 理论算法实现

本仓库提供循环移位 + XOR FEC（CS）方案的理论算法 Python 实现，用于研究和验证编码解码算法。

## 📁 项目结构

```
csnc/
├── core/                   # 核心算法实现
│   ├── __init__.py        # 模块导出
│   ├── cyc_matrix.py      # 循环移位矩阵转换
│   ├── helper_matrix.py   # 辅助矩阵（升维/降维）
│   ├── vandermonde.py     # 范德蒙德矩阵生成与求逆
│   └── main.py            # 示例和测试代码
│
├── requirements.txt        # Python 依赖
└── README.md              # 本文件
```

## 🚀 快速开始

### 环境要求

- Python 3.10+
- NumPy
- galois（用于有限域运算）

### 安装依赖

```bash
# 创建虚拟环境（可选）
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\Activate.ps1

# 安装依赖
pip install -r requirements.txt
```

### 使用示例

```python
from core import Matrix

# 创建矩阵实例：m=5, k=9, order=11
matrix = Matrix(m=5, k=9, order=11)

# 获取编码矩阵
encode_matrix = matrix.get_encode_matrix()
print(encode_matrix)
```

或者直接运行示例代码：

```bash
python core/main.py
```

## 📚 核心模块说明

### `vandermonde.py`
- 生成系统范德蒙德矩阵
- 支持对指定列求逆（用于解码）

### `cyc_matrix.py`
- 将有限域元素转换为循环移位矩阵
- 实现按位循环移位操作

### `helper_matrix.py`
- 生成辅助矩阵用于维度转换
- 支持符号位宽的提升和回落

## 🧪 测试

运行核心算法测试：

```bash
cd core
python main.py
```

## 📝 算法说明

本实现基于以下理论：
- 使用循环移位 + XOR 完成编码
- 使用矩阵乘法完成解码
- 通过范德蒙德矩阵生成编码矩阵
- 通过循环移位矩阵转换实现硬件友好的操作

---

欢迎贡献和改进！
