# 循环移位 + XOR 的 FEC 框架

本文档概述本项目在 `algo/` 中的算法流程、数据表示与验证路径，便于与硬件实现对齐。

## 设计目标
- 编码：仅用按位循环移位与 XOR 组合实现。
- 解码：使用矩阵乘法等线性代数方法（替代 RS 的高斯消元）。
- 取舍：软件无明显优势；硬件端有望显著节省 LUT/寄存器，适合高吞吐、低面积实现。

## 数据模型与“提升”
- 每个符号原始位宽为 `L-1`，在 GF(2) 上操作。
- 通过前置 1 位奇偶位将符号“提升”到 `L` 位循环域，使域元素的作用可表达为“若干位循环左移的 XOR 叠加”。
- `HelperMatrix` 生成两个块对角矩阵：`op = [1; I]`（提升）、`zp = [0, I]`（回落去填充）。

## 系数与矩阵
- `Van` 生成系统范德蒙德矩阵 `M ∈ GF(2^(L-1))^(m×k)`；`invert(packets)` 得到接收列对应的 `m×m` 逆矩阵（解码），`M[:, packets]` 用于回投影（编码）。
- `CyclicMatrix` 给出循环移位生成矩阵 `C` 及其幂；元素到位运算的等价关系为：将域元素映射为 L 位掩码，其 1 位所在偏移集合对应若干次 `C^i` 的按位 XOR。

## 位级实现管线（参考 `matrix_test.py`）
1) 提升：为每个 `L-1` 位符号前置奇偶位，得到 `L` 位。
2) 解码：对选中列的逆矩阵（`m×m`）逐行应用“掩码→循环左移→XOR”叠加。
3) 编码：将解码结果乘以 `M[:, packets]`，同样以移位+XOR 表达。
4) 回落：去掉前置奇偶位，恢复到 `L-1` 位。
- 优化：若掩码中 1 的个数大于 `(L-1)/2`，先按位取反以减少移位次数（与提升保持等价）。

## 正确性验证
- 参考路径将每个系数替换为 `L×L` 的循环移位块矩阵，在 GF(2) 上进行一次大矩阵乘法，结果应与位级实现逐符号一致。
- 运行：`cd algo && python matrix_test.py`，脚本会打印各阶段符号并校验一致性。

## 已知注意点
- 域构造需保证多项式不可约；`vandermonde.py` 中的占位构造可根据目标参数替换为稳定的不可约多项式。
- 断言条件与参数检查应覆盖 `k, m, L` 的可行域（示例代码中有可改进之处）。
- 硬件侧：移位与 XOR 可综合为组合逻辑；后续应评估流水化、位宽与并行度的折中，以及 AXI-Stream 封装与时序收敛。

## 硬件编码器：最简版本设计
固定参数示例：`k=5, m=3, L=11`（与 `matrix_test.py` 默认接近），输出 `k` 个 `L-1` 位符号（系统码：前 `m` 个等于输入，后 `k-m` 个为冗余）。

- 输入与输出（组合逻辑，无握手）：
  - 输入：`data_i[m][L-1:0]`，每个为 `L-1` 位源符号（高位在左）。
  - 输出：`data_o[k][L-1:0]`，每个为 `L-1` 位编码后符号（系统码+冗余）。

- 核心步骤（硬件实现等价于 `matrix_test.py` 的位级路径）：
  1) 提升：对每个输入计算奇偶位 `p=^data_i`，拼接为 `lift_i = {p, data_i}`（`L` 位）。
  2) 系数作用：对编码矩阵 `E = M[:, 0:k]` 的每个元素（整型掩码），将对应输入符号循环左移若干位并 XOR 累加。对掩码 1 位数大于 `(L-1)/2` 的元素先按位取反以减少移位数。
  3) 回落：对每个输出 `L` 位结果丢弃最高位（奇偶位），得到 `L-1` 位输出。

- 系数获取：在 `algo/` 用脚本生成整型掩码常量（`E[row][col]`），写入 Verilog `localparam int COEFF[K][M]` 即可；也可扩展为可编程寄存器。

- SystemVerilog 原型（组合逻辑骨架）：
  ```systemverilog
  module fec_encoder_static #(
    parameter int K = 5,
    parameter int M = 3,
    parameter int L = 11,
    parameter int COEFF[K][M] = '{/* 由 algo 生成 */}
  )(
    input  logic [M-1:0][L-2:0] data_i,   // m 个 (L-1) 位
    output logic [K-1:0][L-2:0] data_o    // k 个 (L-1) 位
  );
    function automatic logic [L-1:0] rotl(input logic [L-1:0] x, input int s);
      logic [L-1:0] y; int sh = s % L; y = (x << sh) | (x >> (L - sh)); return y;
    endfunction

    function automatic logic [L-1:0] apply_mask(
      input int mask, input logic [L-1:0] sym
    );
      logic [L-1:0] acc = '0; int m = mask;
      if ($countones(mask) > (L-1)/2) m = mask ^ ((1<<L)-1);
      for (int s=0; s<L; s++) if (m[s]) acc ^= rotl(sym, s);
      return acc;
    endfunction

    logic [M-1:0][L-1:0] lift;
    for (genvar i=0; i<M; ++i) begin : G_LIFT
      logic p; assign p = ^data_i[i]; assign lift[i] = {p, data_i[i]};
    end

    for (genvar r=0; r<K; ++r) begin : G_ROW
      logic [L-1:0] acc; always_comb begin
        acc = '0;
        for (int c=0; c<M; ++c) if (COEFF[r][c] != 0)
          acc ^= apply_mask(COEFF[r][c], lift[c]);
      end
      assign data_o[r] = acc[L-2:0];
    end
  endmodule
  ```

- 演进方向：
  - 系数可编程（AXI-Lite/CSR 装载），支持不同 `packets` 选择与参数组。
  - 流式接口（AXI4-Stream）：对 `data_i` 序列化，并在输出端维持有效/就绪；移位+XOR 可分组流水化。
  - 资源与时序：轮廓由“掩码 1 的个数 × 输入数 × 位宽”决定；按掩码减半优化后 LUT 近似线性随 `K·M·L` 增长。
