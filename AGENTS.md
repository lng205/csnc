# Repository Guidelines

## 架构与算法概览
- 目标：研究用"循环移位 + XOR"完成编码，并用矩阵乘法完成解码，替代 RS 方案的"矩阵乘法编码 + 高斯消元解码"。
- 取舍：软件层面无明显优势；硬件侧可显著节约 LUT/寄存器资源，利于高吞吐、低面积实现。
- 现状：尚无成熟硬件实现，欢迎贡献可综合、可复用的 Verilog 设计与验证方案。

## 项目结构与模块组织
- `core/`：核心算法实现（可作为 Python 包使用）
  - `matrix_test.py`：按位循环移位 FEC 管线的回归与参考对比（位于 `core/tests/`）
  - `cyc_matrix.py`：循环移位矩阵与按位实现转换
  - `helper_matrix.py`：符号位宽提升/回落辅助矩阵
  - `vandermonde.py`：系统范德蒙德矩阵生成与选列求逆
- `tools/`：工具脚本
  - `generate_masks.py`：不依赖外部库的掩码生成脚本
  - `visualize.py`：资源利用率可视化（SVG/PNG，学术标准图表）
  - `summarize_reports.py`：解析 `utilization.rpt` 生成 Markdown 摘要
- `rtl/`：RTL 设计
  - `encoder/`：CS 编码器（`cs_encoder.sv`, `cs_encoder_static.sv`）
  - `decoder/`：CS 解码器（`cs_decoder.sv`, `cs_decoder_static.sv`）
  - `top/`：顶层设计（`cs_pair_top.sv`, `cs_pair_impl_top.sv`）
  - `testbench/`：测试平台（`cs_pipeline_tb.sv`, `cs_tb.sv`）
  - `generated/`：自动生成的系数文件（.svh）
- `scripts/`：Vivado TCL 脚本（按功能分类）
  - `sim/`：仿真脚本
    - `cs_pipeline_tb.tcl`：CS 编→解组合仿真（含生成掩码的 include）
    - `rs_encoder_min_tb.tcl`：最小 RS 编码器实例化与仿真
    - `rs_encoder_bench_cycles.tcl`：按 (m,n,k,bytes,packets) 统计拍数
    - `rs_encode_decode_erase_tb.tcl`：RS 编码→随机擦除→解码 端到端测试
  - `synth/`：综合脚本
    - `cs_dual_project.tcl`：分别综合 CS 编/解码器并导出利用率/时序
    - `rs_synth_util_report.tcl`：批量综合 RS Encoder/Decoder 并导出利用率/时序
  - `impl/`：实现脚本
    - `cs_pair_impl_project.tcl`：纯 PL 实现截图工程（仅时钟/复位 IO）
    - `cs_ps_axu3eg_xsa.tcl`：AXU3EG（ZU3EG）PS+PL 工程，生成 bit 并导出 XSA
  - `utils/`：工具脚本
    - `clean_repo.ps1`：清理本地 Vivado 产物/日志
- `docs/`：文档
  - `algorithm/`：算法流程与设计说明（`framework.md`, `fec_vs_rs.md`）
  - `hardware/`：硬件分析与资源报告（`rs_encoder_analysis.md`, `zu3eg_rs_resources.md`等）
  - `paper/`：论文相关文档（`appendix.md`）
  - `patent.txt`：专利信息

## 环境与开发命令
- Python 3.10+，在项目根目录创建虚拟环境并安装依赖：
  ```bash
  python -m venv .venv
  source .venv/bin/activate    # PowerShell: .venv\Scripts\Activate.ps1
  pip install -r requirements.txt
  ```
- 运行核心算法测试：
  - `python core/tests/matrix_test.py`：按位循环 FEC 管线回归
  - 或使用 pytest：`cd core && pytest tests/matrix_test.py`
- 生成掩码（无外部依赖）：
  ```bash
  python tools/generate_masks.py --L 11 --M 3 --K 5 --avail 0 1 2 \
    --out rtl/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh
  ```
- Vivado 批处理示例：
  - 仿真：`vivado -mode batch -source scripts/sim/cs_pipeline_tb.tcl -tclargs ./vivado_cs_tb xczu3eg-sbva484-1-e`
  - 综合：`vivado -mode batch -source scripts/synth/cs_dual_project.tcl -tclargs ./vivado_cs_dual xczu3eg-sbva484-1-e 11 5 3`
  - 资源对比可视化：
    ```bash
    python tools/visualize.py \
      --label CS-ENC --in vivado_cs_dual/enc_utilization.rpt \
      --label CS-DEC --in vivado_cs_dual/dec_utilization.rpt \
      --out reports/cs_rs_util.svg --csv reports/cs_rs_util.csv
    ```
- 使用确定性随机种子（见 `core/tests/matrix_test.py`）。需要时将矩阵输出重定向：`> dump.txt`。

## 编码风格与命名
- PEP 8、四空格缩进；公共 API 添加类型标注。
- 函数/常量用 `snake_case`，类用 `CamelCase`（如 `Matrix`, `CyclicMatrix`）。
- 模块可导入、逻辑可复用；简短 docstring，只有在变换复杂处添加行内注释。

## 测试指南
- 将 `core/tests/matrix_test.py` 视作回归与文档双重基线，扩展算法时补充 `assert` 校验。
- 驱动程序的核心逻辑尽量纯函数化，避免网络/文件 I/O 进入测试路径。

## 提交与 PR 规范
- 提交主题简洁、祈使（如：`refine matrix pipeline`），Python 变更尽量按语言分组提交。
- PR 前确保 `python core/tests/matrix_test.py` 通过；在描述中说明意图、给出验证命令与代表性指标/日志。
- 安全相关问题按 `SECURITY.md` 流程上报。
