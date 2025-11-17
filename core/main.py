from vandermonde import Van
from cyc_matrix import CyclicMatrix
from helper_matrix import HelperMatrix

import numpy as np
import galois

np.set_printoptions(threshold=np.inf, linewidth=np.inf)

GF = galois.GF(2)

def test(m, k, L):
    # (m, k) MDS码，每次处理 L-1 bits
    van = Van(m, k, L - 1)
    # L 维 循环右移矩阵
    c = CyclicMatrix(L)

    # 从 0 到 k-1 中随机选择 m 个不同的数
    packets = np.random.choice(k, m, replace=False)
    print("The chosen packets:")
    print(packets)
    print()

    # 编码矩阵
    # 取 k 维扩展范德蒙矩阵的 m 列
    e_alpha = van.M[:, packets]
    # 转换为 L 维循环右移矩阵
    e = c.convert_matrix(e_alpha)

    # 解码矩阵
    # 对 packets 列求逆
    d_alpha = van.invert(packets)
    # 转换为 L 维循环右移矩阵
    d = c.convert_matrix(d_alpha)

    # 辅助矩阵
    # 用于升维和降维
    # 使用克罗地克积生成
    h = HelperMatrix(m, L)

    res = GF(h.zp) @ GF(e) @ GF(d) @ GF(h.op)

    print("Zero padding + encoding + decoding:")
    print(res)

def test_paper():
    # Example from the paper
    
    L = 5
    m = np.array([
        [1, 1, 1, 1],
        [0, 1, 2, 4]
    ])
    c = CyclicMatrix(L)
    h = HelperMatrix(2, L)
    
    t2 = [2, 3]

    e_alpha = m[:, t2]
    d_alpha = np.linalg.inv(galois.GF(2**4, irreducible_poly=[1]*5)(e_alpha))

    print(d_alpha)

if __name__ == "__main__":
    test(3, 5, 11)
    # test_paper()