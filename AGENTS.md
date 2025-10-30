# Repository Guidelines

## 架构与算法概览
- 目标：研究用“循环移位 + XOR”完成编码，并用矩阵乘法完成解码，替代 RS 方案的“矩阵乘法编码 + 高斯消元解码”。
- 取舍：软件层面无明显优势；硬件侧可显著节约 LUT/寄存器资源，利于高吞吐、低面积实现。
- 现状：尚无成熟硬件实现，欢迎贡献可综合、可复用的 Verilog 设计与验证方案。

## 项目结构与模块组织
- `algo/`：Python 研究工作区
  - `matrix/`：可复用数学组件（`vandermonde.py`, `cyc_matrix.py`, `helper_matrix.py`, `matrix_test.py`）。新增通用数学请放此处，并维护 `matrix/__init__.py`。
  - `encoder.py`：基于 `Matrix` 的分包/编码草图
  - `mock_data_frame.py`：可复现的帧载荷生成器
  - `framework.md`：处理流程说明
- `verilog/`：RTL 与脚本；`scripts/`：系数与工程生成工具

## 环境与开发命令
- Python 3.10+，在 `algo/` 下创建虚拟环境并安装依赖：
  ```bash
  python -m venv .venv
  source .venv/bin/activate    # PowerShell: .venv\Scripts\Activate.ps1
  pip install -r requirements.txt
  ```
- 在 `algo/` 目录运行：
  - `python matrix/matrix_test.py`：按位循环 FEC 管线回归
  - `python mock_data_frame.py`：查看比特率波动示例
  - `python encoder.py`：集成 mock 帧与 Matrix 编码
- 使用确定性随机种子（见 `matrix/matrix_test.py`）。需要时将矩阵输出重定向：`> dump.txt`。

## 编码风格与命名
- PEP 8、四空格缩进；公共 API 添加类型标注。
- 函数/常量用 `snake_case`，类用 `CamelCase`（如 `Matrix`, `CyclicMatrix`）。
- 模块可导入、逻辑可复用；简短 docstring，只有在变换复杂处添加行内注释。

## 测试指南
- 将 `matrix/matrix_test.py` 视作回归与文档双重基线，扩展算法时补充 `assert` 校验。
- 驱动程序的核心逻辑尽量纯函数化，避免网络/文件 I/O 进入测试路径。

## 提交与 PR 规范
- 提交主题简洁、祈使（如：`refine matrix pipeline`），Python 变更尽量按语言分组提交。
- PR 前确保 `python matrix/matrix_test.py` 通过；在描述中说明意图、给出验证命令与代表性指标/日志。
- 安全相关问题按 `SECURITY.md` 流程上报。
