"""
Cyclic Shift Network Coding (CSNC)
将线性网络编码转换为 (L-1, L) 循环移位编码
"""

import numpy as np
import galois

np.set_printoptions(threshold=np.inf, linewidth=np.inf)
GF2 = galois.GF(2)


def cyclic_shift_matrix(L: int) -> np.ndarray:
    """生成 L 维循环右移矩阵"""
    C = np.zeros((L, L), dtype=int)
    for i in range(L):
        C[i, (i + 1) % L] = 1
    return C


def element_to_cyclic(m: int, L: int, C: np.ndarray) -> np.ndarray:
    """将 GF(2^(L-1)) 元素转换为 L×L 循环移位矩阵"""
    assert 0 <= m < 2 ** (L - 1)
    # 若 1 的个数超过一半，翻转所有位以减少异或次数
    if m.bit_count() > (L - 1) / 2:
        m ^= 2 ** L - 1
    
    res = np.zeros((L, L), dtype=int)
    shift = 0
    while m:
        if m & 1:
            res = np.bitwise_xor(res, np.linalg.matrix_power(C, shift))
        m >>= 1
        shift += 1
    return res


def matrix_to_cyclic(M: np.ndarray, L: int) -> np.ndarray:
    """将 GF 矩阵的每个元素转换为循环移位矩阵并组合"""
    C = cyclic_shift_matrix(L)
    rows = [np.hstack([element_to_cyclic(int(x), L, C) for x in row]) for row in M]
    return np.vstack(rows)


def helper_matrices(m: int, L: int) -> tuple[np.ndarray, np.ndarray]:
    """
    生成升维/降维辅助矩阵
    zp: 零填充矩阵 [0 | I]
    op: 单位扩展矩阵 [1; I]
    """
    # [0, I_{L-1}]
    zero_eye = np.hstack([np.zeros((L - 1, 1), dtype=int), np.eye(L - 1, dtype=int)])
    # [1^T; I_{L-1}]
    one_eye = np.vstack([np.ones((1, L - 1), dtype=int), np.eye(L - 1, dtype=int)])
    
    zp = np.kron(np.eye(m, dtype=int), zero_eye)
    op = np.kron(np.eye(m, dtype=int), one_eye)
    return zp, op


class Vandermonde:
    """系统范德蒙矩阵及其求逆（在 GF(2^order) 上）"""
    
    def __init__(self, m: int, k: int, order: int):
        """
        m: 输入符号数
        k: 输出符号数  
        order: 域的阶数
        """
        assert m < k
        assert k - m <= order  # 域要足够大
        
        self.m, self.k = m, k
        self.GF = galois.GF(2 ** order, irreducible_poly=[1] * (order + 1))
        self.alpha = self.GF("x")
        self.M = self._build_systematic_vandermonde(m, k - m)
    
    def _build_systematic_vandermonde(self, rows: int, cols: int) -> np.ndarray:
        """构建系统范德蒙矩阵 [I | V]"""
        vander = np.array([
            [int(self.alpha ** (i * (j + 1))) for j in range(cols)]
            for i in range(rows)
        ], dtype=int)
        return np.concatenate([np.eye(rows, dtype=int), vander], axis=1)
    
    def invert(self, cols: list[int]) -> np.ndarray:
        """对指定列子矩阵求逆"""
        assert len(cols) == self.m
        assert all(0 <= c < self.k for c in cols)
        
        sub = self.M[:, cols]
        inv = np.linalg.inv(self.GF(sub))
        return np.array(inv, dtype=int)


def test_csnc(m: int, k: int, L: int):
    """
    测试 (m, k) MDS 码的循环移位网络编码
    每次处理 L-1 bits
    """
    van = Vandermonde(m, k, L - 1)
    
    # 随机选择 m 个数据包
    packets = np.random.choice(k, m, replace=False)
    print(f"选择的数据包: {packets}")
    
    # 编码矩阵：取范德蒙矩阵的 m 列并转换
    enc_alpha = van.M[:, packets]
    enc = matrix_to_cyclic(enc_alpha, L)
    
    # 解码矩阵：对选中列求逆并转换
    dec_alpha = van.invert(packets)
    dec = matrix_to_cyclic(dec_alpha, L)
    
    # 辅助矩阵
    zp, op = helper_matrices(m, L)
    
    # 转换为 GF(2) 并验证
    zp, op, enc, dec = GF2(zp), GF2(op), GF2(enc), GF2(dec)
    
    # 满速率编解码
    result = zp @ enc @ op @ zp @ dec @ op
    
    identity = np.eye(m * (L - 1), dtype=int)
    is_correct = np.all(result == identity)
    print(f"验证结果: {'✓ 正确' if is_correct else '✗ 错误'}")
    return is_correct


if __name__ == "__main__":
    test_csnc(m=5, k=9, L=11)
