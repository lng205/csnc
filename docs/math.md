# Cyclic Shift Network Coding（CSNC）算法说明

本文档描述本项目中使用的 CSNC 算法的**核心抽象逻辑**，只关注数学结构，不涉及具体代码实现细节。

---

## 1. 参数与目标

- 参数：
  - \( m \)：原始符号数（源包数）
  - \( k \)：编码后符号数（总包数），\( k \ge m \)
  - \( L \)：循环移位长度，扩域选择为 \( GF(2^{L-1}) \)

- 目标：
  - 在扩域 \( GF(2^{L-1}) \) 上构造一个 MDS 型线性码，使得：
    > 任意接收到的 \( m \) 个包都能恢复原始的 \( m \) 个符号。
  - 将这一符号级线性码，等价地实现为 GF(2) 上长度为 \( m(L-1) \) → \( k(L-1) \) 的比特级线性变换。

---

## 2. 扩域与 Vandermonde 码

1. 构造扩域  
   \[
   \mathbb{F} = GF(2^{L-1}) \cong GF(2)[x] / (p(x)),
   \]
   其中 \( p(x) \) 是某个不可约多项式（实现中取全 1 多项式）。

2. 选择本原元 \( \alpha \in \mathbb{F} \)。

3. 构造系统形 Vandermonde 生成矩阵  
   \[
   M = \left[ I_m \mid V \right] \in \mathbb{F}^{m \times k},
   \]
   其中 Vandermonde 部分为  
   \[
   V_{i,j} = \alpha^{\, i (j+1)},\quad i=0,\dots,m-1;\ j=0,\dots,k-m-1.
   \]

4. 定义扩域上的编码矩阵  
   \[
   E = M^\top \in \mathbb{F}^{k \times m}.
   \]

5. 对任意原始符号向量  
   \[
   x \in \mathbb{F}^m,
   \]
   编码得到  
   \[
   y = E x \in \mathbb{F}^k.
   \]

> **关键性质（MDS）：**  
> 对任意选取的大小为 \( m \) 的索引集合 \( S \subset \{0,\dots,k-1\} \)，
> 取出对应的子矩阵 \( E_S \in \mathbb{F}^{m\times m} \) 都是可逆的。  
> 因此只要收到任意 \( m \) 个包 \( y_S \)，就可以在扩域中解出：
> \[
> x = E_S^{-1} y_S.
> \]

---

## 3. 扩域符号到比特的线性嵌入

扩域元素 \( a \in \mathbb{F} = GF(2^{L-1}) \) 可以表示为 GF(2) 上的多项式：
\[
a(x) = a_0 + a_1 x + \cdots + a_{L-2} x^{L-2},
\]
其中 \( a_i \in GF(2) \)。

将系数拼成列向量：
\[
\mathrm{vec}(a) = (a_0, a_1, \dots, a_{L-2})^\top \in GF(2)^{L-1}.
\]

于是得到符号级与比特级之间的线性同构：
\[
\mathrm{vec}: \mathbb{F} \longrightarrow GF(2)^{L-1},
\]
并扩展到向量：
\[
\mathrm{vec}: \mathbb{F}^n \longrightarrow GF(2)^{n(L-1)}.
\]

---

## 4. 扩域线性变换的比特矩阵表示

对于任意扩域矩阵  
\[
A \in \mathbb{F}^{r \times c},
\]
我们希望构造一个 GF(2) 矩阵
\[
\Phi(A) \in GF(2)^{r(L-1) \times c(L-1)},
\]
使得对任意 \( x \in \mathbb{F}^c \) 都有：
\[
\mathrm{vec}(A x) = \Phi(A)\, \mathrm{vec}(x).
\]

也就是说，\(\Phi(A)\) 是「线性变换 \( A \)」在比特空间中的矩阵表示。

通过以下方式构造 \(\Phi\)：

1. 为域元素构造一个环同态  
   \[
   \Psi: \mathbb{F} \rightarrow \mathrm{Mat}_{L\times L}(GF(2)),
   \]
   使得
   \[
   \Psi(a+b) = \Psi(a) + \Psi(b), \quad
   \Psi(a\cdot b) = \Psi(a)\Psi(b).
   \]
   实现中使用 **循环移位矩阵及其幂的线性组合** 来表示「乘以多项式」的线性变换。

2. 将矩阵 \( A = (a_{ij}) \) 中每个元素 \( a_{ij} \) 替换为对应的块矩阵 \( \Psi(a_{ij}) \)，得到块矩阵
   \[
   A_{\text{cyc}} \in GF(2)^{rL \times cL}.
   \]

3. 通过固定的升/降维线性映射，将 \(L\) 维的冗余表示压缩回 \(L-1\) 维，得到最终的
   \[
   \Phi(A) \in GF(2)^{r(L-1) \times c(L-1)}.
   \]

> **核心性质：**
> \[
> \Phi(A + B) = \Phi(A) + \Phi(B),\quad
> \Phi(A B) = \Phi(A)\Phi(B).
> \]
> 因此 \(\Phi\) 是保持乘法结构的线性嵌入（环同态）。

---

## 5. CSNC 的端到端流程

### 5.1 比特级编码

1. 原始比特向量  
   \[
   b = \mathrm{vec}(x) \in GF(2)^{m(L-1)},
   \]
   对应扩域符号向量 \( x \in \mathbb{F}^m \)。

2. 扩域编码矩阵：\( E \in \mathbb{F}^{k \times m} \)。

3. 比特级编码矩阵：
   \[
   E_{\text{bin}} = \Phi(E) \in GF(2)^{k(L-1) \times m(L-1)}.
   \]

4. 比特级编码：
   \[
   y_{\text{bin}} = E_{\text{bin}}\, b \in GF(2)^{k(L-1)}.
   \]
   这可视为 \(k\) 个包，每个包长度为 \(L-1\) 比特。

### 5.2 丢包与选包

- 在 \(k\) 个包中，任意选择一个大小为 \(m\) 的索引集合 \( S \subset \{0,\dots,k-1\} \) 表示收到的包。
- 在扩域层面，对应取出
  \[
  E_S \in \mathbb{F}^{m \times m},
  \]
  它是可逆的。
- 在比特层面，对应取出收到包的比特向量 \( y_{\text{recv}} \)，等价于对 \( E_{\text{bin}} \) 做相应行块选择。

### 5.3 比特级解码

1. 扩域解码矩阵：
   \[
   D = E_S^{-1} \in \mathbb{F}^{m \times m}.
   \]

2. 比特级解码矩阵：
   \[
   D_{\text{bin}} = \Phi(D) \in GF(2)^{m(L-1)\times m(L-1)}.
   \]

3. 比特级解码：
   \[
   \hat{b} = D_{\text{bin}}\, y_{\text{recv}}.
   \]

### 5.4 正确性

因为：
\[
D E_S = I_m,
\]
应用 \(\Phi\) 得：
\[
\Phi(D)\, \Phi(E_S) = \Phi(D E_S) = \Phi(I_m) = I_{m(L-1)}.
\]

在比特级上就是：
\[
D_{\text{bin}}\, (E_{\text{bin}})_S = I_{m(L-1)}.
\]

于是对任意原始比特向量 \( b \)：
\[
\hat{b}
= D_{\text{bin}}\, (E_{\text{bin}})_S\, b
= I_{m(L-1)}\, b
= b.
\]

也就是说：

> **在比特层面，先编码成 \(k\) 个包、任意丢掉 \(k-m\) 个包，只用剩下的 \(m\) 个包，就可以无损恢复所有原始比特。**

这就是 CSNC 算法在本项目中的核心数学逻辑。
