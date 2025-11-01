#!/usr/bin/env python3
"""
Standalone generator for CS encoder/decoder masks without external deps.

Field: GF(2^w), implemented via polynomial arithmetic over GF(2) with a
primitive polynomial (default for w=10: x^10 + x^3 + 1 = 0b1_0000_1001 = 0x409).

Outputs a SystemVerilog header (.svh) with:
  localparam logic [L-1:0] CS_ENC_COEFF [K][M]
  localparam logic [L-1:0] CS_DEC_COEFF [M][K]

Usage:
  python algo/generate_cs_masks_standalone.py --L 11 --M 3 --K 5 \
    --avail 0 1 2 \
    --out verilog/generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh

Optionally, specify --prim 0x409 for a different primitive polynomial.
"""
from __future__ import annotations
import argparse
from pathlib import Path
from typing import List


def gf_mul(a: int, b: int, w: int, prim: int) -> int:
    res = 0
    for i in range(w * 2):
        if b & 1:
            res ^= a
        b >>= 1
        carry = a & (1 << (w - 1))
        a = (a << 1) & ((1 << w) - 1)
        if carry:
            a ^= prim & ((1 << w) - 1)
        if b == 0:
            break
    return res & ((1 << w) - 1)


def gf_pow(a: int, e: int, w: int, prim: int) -> int:
    result = 1
    base = a
    while e > 0:
        if e & 1:
            result = gf_mul(result, base, w, prim)
        base = gf_mul(base, base, w, prim)
        e >>= 1
    return result


def gf_inv(a: int, w: int, prim: int) -> int:
    if a == 0:
        raise ZeroDivisionError("GF inverse of zero")
    # a^(2^w - 2) by Fermat's little theorem
    return gf_pow(a, (1 << w) - 2, w, prim)


def gf_mat_mul(A: List[List[int]], B: List[List[int]], w: int, prim: int) -> List[List[int]]:
    r, n, c = len(A), len(A[0]), len(B[0])
    out = [[0] * c for _ in range(r)]
    for i in range(r):
        for k in range(n):
            if A[i][k] == 0:
                continue
            for j in range(c):
                if B[k][j] == 0:
                    continue
                out[i][j] ^= gf_mul(A[i][k], B[k][j], w, prim)
    return out


def gf_mat_inv(M: List[List[int]], w: int, prim: int) -> List[List[int]]:
    n = len(M)
    A = [row[:] for row in M]
    I = [[0] * n for _ in range(n)]
    for i in range(n):
        I[i][i] = 1
    # Gauss-Jordan
    for col in range(n):
        # find pivot
        piv = None
        for r in range(col, n):
            if A[r][col] != 0:
                piv = r
                break
        if piv is None:
            raise ValueError("Matrix not invertible in GF(2^w)")
        if piv != col:
            A[col], A[piv] = A[piv], A[col]
            I[col], I[piv] = I[piv], I[col]
        inv_p = gf_inv(A[col][col], w, prim)
        # normalize pivot row
        for j in range(n):
            A[col][j] = gf_mul(A[col][j], inv_p, w, prim)
            I[col][j] = gf_mul(I[col][j], inv_p, w, prim)
        # eliminate others
        for r in range(n):
            if r == col:
                continue
            factor = A[r][col]
            if factor == 0:
                continue
            for j in range(n):
                A[r][j] ^= gf_mul(factor, A[col][j], w, prim)
                I[r][j] ^= gf_mul(factor, I[col][j], w, prim)
    return I


def build_systematic_vandermonde(m: int, k: int, w: int, prim: int) -> List[List[int]]:
    # Generator element 'a' = 2 (polynomial x)
    a = 2
    v_cols = k - m
    V = [[0] * v_cols for _ in range(m)]
    for i in range(m):
        for j in range(v_cols):
            V[i][j] = gf_pow(a, i * (j + 1), w, prim)
    # Concatenate [I | V]
    M = [row[:] for row in [[0] * k for _ in range(m)]]
    for i in range(m):
        M[i][i] = 1
        for j in range(v_cols):
            M[i][m + j] = V[i][j]
    return M


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--L", type=int, required=True)
    ap.add_argument("--M", type=int, required=True)
    ap.add_argument("--K", type=int, required=True)
    ap.add_argument("--avail", type=int, nargs='+', required=True)
    ap.add_argument("--out", type=str, required=True)
    ap.add_argument("--prim", type=lambda s: int(s, 0), default=0x409, help="Primitive polynomial (default 0x409 for w=10)")
    args = ap.parse_args()

    L, M, K, prim = args.L, args.M, args.K, args.prim
    assert L >= 3 and M > 0 and K > M
    w = L - 1

    M_sys = build_systematic_vandermonde(M, K, w, prim)  # m x k
    # Encoder coeffs: K x M
    enc_kxm = [list(col) for col in zip(*M_sys)]

    # Decoder for fixed erasure: invert M[:, avail] -> m x m, then expand to m x k with zero on erased cols
    avail = args.avail
    assert len(avail) == M and len(set(avail)) == M and all(0 <= c < K for c in avail)
    M_sel = [[M_sys[i][c] for c in avail] for i in range(M)]
    dec_mxm = gf_mat_inv(M_sel, w, prim)
    dec_mxk = [[0] * K for _ in range(M)]
    for idx, c in enumerate(avail):
        for r in range(M):
            dec_mxk[r][c] = dec_mxm[r][idx]

    def row_to_sv(row: List[int]) -> str:
        return "{ " + ", ".join(f"{L}'b{(val & ((1<<(L-1))-1)):0{L}b}" for val in row) + " }"

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    lines: List[str] = []
    lines.append(f"// Auto-generated by generate_cs_masks_standalone.py (L={L}, M={M}, K={K}, avail={avail}, prim=0x{prim:x})")
    lines.append("localparam int CS_L = {};").append if False else None
    lines.append(f"localparam int CS_L = {L};")
    lines.append(f"localparam int CS_M = {M};")
    lines.append(f"localparam int CS_K = {K};")
    lines.append("")
    lines.append("localparam logic [CS_L-1:0] CS_ENC_COEFF [CS_K][CS_M] = '{")
    for r in range(K):
        comma = "," if r < K - 1 else ""
        lines.append(f"  {row_to_sv(enc_kxm[r])}{comma}")
    lines.append("};")
    lines.append("")
    lines.append("localparam logic [CS_L-1:0] CS_DEC_COEFF [CS_M][CS_K] = '{")
    for r in range(M):
        comma = "," if r < M - 1 else ""
        lines.append(f"  {row_to_sv(dec_mxk[r])}{comma}")
    lines.append("};")
    lines.append("")
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
