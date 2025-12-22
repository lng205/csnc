import numpy as np
import galois


# 生成循环移位矩阵的幂: I, C, C^2, ..., C^{L-1}
def cyclic_shift_powers(L: int) -> list[np.ndarray]:
    C = np.zeros((L, L), dtype=int)
    i = np.arange(L)
    C[i, (i + 1) % L] = 1  # 循环右移一位

    powers = [np.eye(L, dtype=int)]
    for _ in range(1, L):
        powers.append((powers[-1] @ C) % 2)
    return powers


# 将一个扩域元素（整数表示）展开成 L×L 的循环移位矩阵
def element_to_cyclic(v: int, powers: list[np.ndarray]) -> np.ndarray:
    M = np.zeros_like(powers[0], dtype=int)
    bit = 0
    while v:
        if v & 1:
            M ^= powers[bit]
        v >>= 1
        bit += 1
    return M


# 扩域矩阵 A → GF(2) 上的块循环移位矩阵
def matrix_to_cyclic(A: np.ndarray, powers: list[np.ndarray]) -> np.ndarray:
    return np.vstack([
        np.hstack([element_to_cyclic(int(x), powers) for x in row])
        for row in A
    ])


# 只跟 L 有关的两个小块，用来升/降维
def helper_blocks(L: int) -> tuple[np.ndarray, np.ndarray]:
    # zero_eye: L x (L-1)，把 (L-1) 维向量嵌入 L 维
    zero_eye = np.vstack((np.zeros((1, L - 1), dtype=int), np.eye(L - 1, dtype=int)))
    # one_eye: (L-1) x L，把 L 维向量压回 (L-1) 维
    one_eye  = np.hstack((np.ones((L - 1, 1), dtype=int), np.eye(L - 1, dtype=int)))
    return zero_eye, one_eye


# 将扩域上的线性变换 A（r×c）映射为 GF(2) 上的 r(L-1)×c(L-1) 线性变换
def build_linear(A: np.ndarray,
                 powers: list[np.ndarray],
                 zero_eye: np.ndarray,
                 one_eye: np.ndarray) -> np.ndarray:
    r, c = A.shape
    L = zero_eye.shape[0]

    # 域元素 → L 位多项式循环移位矩阵
    A_cyc = matrix_to_cyclic(A, powers)               # (rL) x (cL)

    # 域向量嵌入/压缩的 Kronecker 扩展
    zp = np.kron(np.eye(c, dtype=int), zero_eye)      # (cL) x (c(L-1))
    op = np.kron(np.eye(r, dtype=int), one_eye)       # (r(L-1)) x (rL)

    return (op @ A_cyc @ zp) % 2                      # (r(L-1)) x (c(L-1))


class Vandermonde:
    """
    扩域 GF(2^{L-1}) 上的系统形 Vandermonde 生成矩阵:
        M (m×k) = [ I_m | V ]
    """
    def __init__(self, m: int, k: int, L: int):
        self.m = m
        self.k = k

        order = L - 1
        poly = [1] * (order + 1)  # 1 + x + ... + x^{order}
        GF_ext = galois.GF(2**order, irreducible_poly=poly)
        self.GF_ext = GF_ext
        self.alpha = GF_ext.primitive_element

        parity = k - m
        # Vandermonde 部分
        vander = np.array(
            [[int(self.alpha ** (i * (j + 1))) for j in range(parity)]
             for i in range(m)],
            dtype=int,
        )
        # 系统形生成矩阵 M： [ I_m | vander ]，形状 m×k
        self.M = np.concatenate([np.eye(m, dtype=int), vander], axis=1)

    # 取列子矩阵并在扩域里求逆：返回 (M[:, cols])^{-1}
    def invert_cols(self, cols: np.ndarray) -> np.ndarray:
        sub = self.GF_ext(self.M[:, cols])
        inv = np.linalg.inv(sub)
        return np.array(inv, dtype=int)


# 端到端测试：
#   数据 x (m 个符号) → 全部 k 个包 → 随机丢掉 k−m 个包 → 用收到的 m 个包解码
def end_to_end_demo(m: int, k: int, L: int) -> bool:
    van = Vandermonde(m, k, L)
    powers = cyclic_shift_powers(L)
    zero_eye, one_eye = helper_blocks(L)

    # --- 1. 构造“全列”编码矩阵：从 m 个符号编码出 k 个包 ---
    # 域上的编码矩阵：encode_alpha: k×m，y = encode_alpha @ x
    encode_alpha = van.M.T                             # k x m
    E_full = build_linear(encode_alpha, powers, zero_eye, one_eye)  # (k(L-1)) x (m(L-1))

    n_bits = m * (L - 1)

    # 原始数据比特（列向量）
    x = np.random.randint(0, 2, size=(n_bits, 1), dtype=int)

    # 编码得到 k 个包的比特（逐包拼接）
    y_all = (E_full @ x) % 2                           # k(L-1) x 1

    # --- 2. 模拟丢包：在 k 个包中随机保留 m 个 ---
    all_idxs = np.arange(k)
    packets = np.sort(np.random.choice(all_idxs, m, replace=False))  # 收到的包索引
    lost = np.setdiff1d(all_idxs, packets)                           # 丢失的包索引

    print("收到的包索引:", packets)
    print("丢失的包索引:", lost)

    # --- 3. 针对“收到的包”构造解码矩阵 ---
    # encode_alpha_S = encode_alpha[packets, :] = (M[:, packets])^T
    # 解码矩阵应该是 encode_alpha_S^{-1}
    inv_cols = van.invert_cols(packets)               # (M[:, packets])^{-1}
    decode_alpha = inv_cols.T                         # 等价于 (encode_alpha_S)^{-1}

    D = build_linear(decode_alpha, powers, zero_eye, one_eye)  # (m(L-1)) x (m(L-1))

    # --- 4. 从 y_all 中取出“收到的 m 个包”的比特，按 packets 顺序拼接 ---
    Lm1 = L - 1
    y_recv_blocks = [y_all[j * Lm1 : (j + 1) * Lm1, :] for j in packets]
    y_recv = np.vstack(y_recv_blocks)                 # m(L-1) x 1

    # 解码还原
    x_hat = (D @ y_recv) % 2

    ok = np.array_equal(x, x_hat)
    print("端到端测试 x == decoder( select(encoder(x)) ) :", ok)
    print("x 前 16 位      :", x[:16, 0])
    print("x_hat 前 16 位 :", x_hat[:16, 0])
    return ok


if __name__ == "__main__":
    m, k, L = 5, 9, 11
    ok = end_to_end_demo(m, k, L)
    print("end_to_end_demo passed:", ok)
