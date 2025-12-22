# 循环移位矩阵替换的环同态性（简要证明）

本文说明：在 CSNC 中，用「循环移位矩阵的幂 + 固定升/降维」来替代扩域元素，实际上给出了一个

$$
GF(2^{L-1}) \;\longrightarrow\; \mathrm{Mat}_{(L-1)\times(L-1)}(GF(2))
$$

的环同态（保持加法和乘法）。这保证了：扩域上的 $DE = I$ 会自动变成比特矩阵上的 $D_{\text{bin}} E_{\text{bin}} = I$。

---

## 1. 扩域模型

- 基域：$\mathbb{F}_2 = GF(2)$  
- 取整数 $L \ge 2$  
- 选一个不可约多项式（实现中取全 1 多项式）

$$
p(x) = 1 + x + x^2 + \cdots + x^{L-1} \in \mathbb{F}_2[x],
$$

则扩域为

$$
\mathbb{K} := GF(2^{L-1}) \cong \mathbb{F}_2[x] / (p(x)).
$$

每个元素 $a \in \mathbb{K}$ 都可以唯一表示为

$$
a(x) = a_0 + a_1 x + \cdots + a_{L-2} x^{L-2}, \quad a_i \in \mathbb{F}_2,
$$

即次数小于 $L-1$ 的多项式。

---

## 2. 循环移位矩阵和不变子空间

考虑向量空间

$$
V := \mathbb{F}_2^L
$$

以及**循环移位算子** $C : V \to V$，在标准基下：

- 令 $e_i$ 为第 $i$ 个标准基向量，则  
  $$
  C(e_i) = e_{(i+1) \bmod L}.
  $$

在代码中就是：

```python
C[i, (i + 1) % L] = 1
```

定义子空间

$$
U := \left\{ v = (v_0,\dots,v_{L-1})^\top \in \mathbb{F}_2^L \,\middle|\, \sum_{i=0}^{L-1} v_i = 0 \right\}.
$$

### 2.1 $U$ 的性质

1. **维数**

   只有一个线性约束（分量和为 0），因此

   $$
   \dim U = L - 1.
   $$

2. **对 $C$ 不变**

   对任意 $v \in U$，有

   $$
   \sum_i (Cv)_i = \sum_i v_i = 0,
   $$

   因为 $C$ 只是循环移位，不改变分量之和；因此 $Cv \in U$，$U$ 是 $C$ 的不变子空间。

   记

   $$
   T := C|_U : U \to U.
   $$

3. **$p(T) = 0$**

   在整个 $V$ 上有

   $$
   I + C + C^2 + \cdots + C^{L-1} = J,
   $$

   其中 $J$ 是「全 1」矩阵（每个位置都是 1）。对任意 $v \in U$，

   $$
   Jv = \Big(\sum_i v_i\Big) \cdot (1,1,\dots,1)^\top = 0,
   $$

   因为 $\sum_i v_i = 0$。于是

   $$
   (I + C + \cdots + C^{L-1})v = 0, \quad \forall v \in U.
   $$

   换成 $T$ 的记号：

   $$
   p(T) = I + T + T^2 + \cdots + T^{L-1} = 0 \quad (\text{作用在 } U \text{ 上}).
   $$

所以：$T$ 的最小多项式被 $p(x)$ 整除。

---

## 3. 从多项式环到算子环：构造环同态

定义

$$
\Phi_0 : \mathbb{F}_2[x] \to \mathrm{End}(U),\quad
f(x) \mapsto f(T),
$$

其中 $f(T)$ 的含义是：把多项式中的 $x$ 换成算子 $T$，常数项换成恒等算子 $I$。

### 3.1 $\Phi_0$ 是环同态

对任意 $f,g \in \mathbb{F}_2[x]$：

* 加法：

  $$
  \Phi_0(f+g) = (f+g)(T) = f(T) + g(T) = \Phi_0(f) + \Phi_0(g).
  $$

* 乘法：

  $$
  \Phi_0(fg) = (fg)(T) = f(T)\circ g(T) = \Phi_0(f),\Phi_0(g).
  $$

因此 $\Phi_0$ 是一个环同态。

### 3.2 核与理想 $(p(x))$

由上节 $p(T)=0$ 可知

$$
\Phi_0(p(x)) = p(T) = 0,
$$

所以 $p(x) \in \ker \Phi_0$。

* $\mathbb{F}_2[x]$ 是主理想整环；
* $p(x)$ 不可约；
* $\ker \Phi_0$ 是一个理想，且包含 $p(x)$。

因此

$$
\ker \Phi_0 = (p(x)).
$$

于是 $\Phi_0$ 在商环上诱导出一个**单射环同态**

$$
\Phi : \mathbb{F}_2[x]/(p(x)) \to \mathrm{End}(U),\quad [f(x)] \mapsto f(T).
$$

又因为

$$
\mathbb{F}_2[x]/(p(x)) \cong GF(2^{L-1}) = \mathbb{K},
$$

所以得到

> 存在一个单射环同态
> $$
> \Phi : \mathbb{K} \to \mathrm{End}(U),
> $$
> 满足
> $$
> \Phi(a+b) = \Phi(a) + \Phi(b), \quad
> \Phi(ab) = \Phi(a),\Phi(b).
> $$

---

## 4. 选基后得到 $(L-1)\times(L-1)$ 矩阵

$U$ 是维数 $L-1$ 的 $\mathbb{F}_2$ 向量空间。选一个基

$$
B : \mathbb{F}_2^{L-1} \xrightarrow{\sim} U,
$$

在实现里：

* `zero_eye`：实现从 $\mathbb{F}_2^{L-1}$ 嵌入到 $U \subset \mathbb{F}_2^L$；
* `one_eye`：实现从 $U$ 投影回 $\mathbb{F}_2^{L-1}$。

在这个基下，每个算子 $\Phi(a)$ 对应的矩阵表示为

$$
\tilde{\Phi}(a) := B^{-1} \circ \Phi(a) \circ B
;\in; \mathrm{Mat}_{(L-1)\times(L-1)}(\mathbb{F}_2).
$$

因为基变换是双射线性同构，共轭不会改变「加法/乘法」结构，所以

$$
\tilde{\Phi}(a+b) = \tilde{\Phi}(a) + \tilde{\Phi}(b), \quad
\tilde{\Phi}(ab) = \tilde{\Phi}(a),\tilde{\Phi}(b).
$$

这就是代码中真正用到的「扩域元素 → $(L-1)\times(L-1)$ 二进制矩阵」映射。

---

## 5. 和循环移位矩阵幂的实际替换对应

在实际实现中，对扩域元素 $a$ 的替换做了三件事：

1. 将 $a$ 视为多项式

   $$
   a(x) = a_0 + a_1 x + \cdots + a_{L-2} x^{L-2}.
   $$

2. 利用循环移位矩阵 $C$ 的幂 $I, C, C^2, \dots, C^{L-1}$ 构造

   $$
   \Psi_L(a) := \sum_i a_i, C^i \in \mathrm{Mat}_{L\times L}(\mathbb{F}_2).
   $$

3. 用固定的升/降维矩阵（代码里的 `zero_eye` / `one_eye`）在 $U$ 与 $\mathbb{F}_2^{L-1}$ 之间做基变换，得到

   $$
   \tilde{\Phi}(a) = B^{-1}, \Psi_L(a), B \in \mathrm{Mat}_{(L-1)\times(L-1)}(\mathbb{F}_2).
   $$

其中：

* $T = C|_U$ 是 $C$ 在不变子空间 $U$ 上的限制；
* 对 $T$ 的多项式 $f(T)$，可以通过 $f(C)$ 在 $U$ 上的作用来实现；
* $B, B^{-1}$ 负责把 $U$ 与 $\mathbb{F}_2^{L-1}$ 对齐。

因此：

> 「按系数线性组合 $C^i$，再通过固定升/降维压缩到 $(L-1)$ 维」
> 正是上面定义的 $\tilde{\Phi}(a)$ 的具体矩阵实现，
> 而 $\tilde{\Phi}$ 是一个环同态。

---

## 6. 扩展到扩域矩阵（编码 / 解码矩阵）

对单个元素 $a$，映射 $a \mapsto \tilde{\Phi}(a)$ 是环同态。
对扩域矩阵

$$
A = (a_{ij}) \in \mathbb{K}^{r\times c},
$$

按块替换：每个 $a_{ij}$ 换成 $\tilde{\Phi}(a_{ij})$，得到块矩阵

$$
\tilde{\Phi}(A) \in \mathrm{Mat}_{r(L-1)\times c(L-1)}(\mathbb{F}_2).
$$

块矩阵加法/乘法本质上都在元素块层面上进行，而每个块替换本身是环同态，因此整体满足

$$
\tilde{\Phi}(A+B) = \tilde{\Phi}(A) + \tilde{\Phi}(B), \quad
\tilde{\Phi}(AB) = \tilde{\Phi}(A),\tilde{\Phi}(B).
$$

**结论：**

> 在 CSNC 中，用循环移位矩阵的幂（加上固定升/降维）替代扩域矩阵，是一个
> $$
> GF(2^{L-1})^{r\times c} \longrightarrow GF(2)^{r(L-1)\times c(L-1)}
> $$
> 的环同态。因此扩域上的
> $$
> D E_S = I_m
> $$
> 会被严格保持为比特矩阵上的
> $$
> \tilde{\Phi}(D),\tilde{\Phi}(E_S) = I_{m(L-1)},
> $$
> 这就是 CSNC 算法在比特级仍能正确解码的数学基础。