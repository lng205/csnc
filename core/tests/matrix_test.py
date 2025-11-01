from __future__ import annotations

from typing import List, Sequence, Tuple

import numpy as np
import galois

import sys
from pathlib import Path
# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from vandermonde import Van
from cyc_matrix import CyclicMatrix
from helper_matrix import HelperMatrix

np.set_printoptions(threshold=32, linewidth=np.inf)

GF2 = galois.GF(2)


def bits_to_int(bits: Sequence[int]) -> int:
    """Pack a big-endian bit vector into an integer."""
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return value


def bits_matrix_to_ints(bit_rows: np.ndarray) -> List[int]:
    return [bits_to_int(row) for row in bit_rows]


def int_to_bits(word: int, width: int) -> np.ndarray:
    """Unpack an integer into a big-endian bit vector."""
    return np.array([(word >> shift) & 1 for shift in range(width - 1, -1, -1)], dtype=np.uint8)


def ints_to_bits(words: Sequence[int], width: int) -> np.ndarray:
    return np.vstack([int_to_bits(word, width) for word in words])


def rotate_left(word: int, shift: int, width: int) -> int:
    """Cyclically rotate a word left by `shift` within `width` bits."""
    shift %= width
    if shift == 0:
        return word & ((1 << width) - 1)
    mask = (1 << width) - 1
    return ((word << shift) & mask) | (word >> (width - shift))


def parity_extend_words(words: Sequence[int], width: int) -> Tuple[List[int], int]:
    """Attach a parity bit as the most-significant bit of each word."""
    mask = (1 << width) - 1
    extended = []
    for word in words:
        trimmed = word & mask
        parity = trimmed.bit_count() & 1
        extended.append((parity << width) | trimmed)
    return extended, width + 1


def drop_parity_words(words: Sequence[int], width: int) -> Tuple[List[int], int]:
    """Remove the parity bit that was previously prepended."""
    new_width = width - 1
    mask = (1 << new_width) - 1
    return [word & mask for word in words], new_width


def apply_coefficient(mask: int, symbol: int, width: int) -> int:
    """Apply a field coefficient using cyclic shifts and XOR only."""
    if mask == 0:
        return 0

    if mask.bit_count() > (width - 1) // 2:
        mask ^= (1 << width) - 1

    result = 0
    shift = 0
    temp = mask
    while temp:
        if temp & 1:
            result ^= rotate_left(symbol, shift, width)
        temp >>= 1
        shift += 1
    return result & ((1 << width) - 1)


def apply_matrix(coeffs: np.ndarray, symbols: Sequence[int], width: int) -> List[int]:
    """Combine symbols through XOR and rotation for a coefficient matrix."""
    coeffs = np.asarray(coeffs, dtype=np.int64)
    rows, cols = coeffs.shape
    out: List[int] = []
    for row in range(rows):
        accum = 0
        for col in range(cols):
            mask = int(coeffs[row, col])
            if mask:
                accum ^= apply_coefficient(mask, symbols[col], width)
        out.append(accum & ((1 << width) - 1))
    return out


def run_pipeline(payload: Sequence[int], packets: Sequence[int], m: int, k: int, full_width: int) -> Tuple[List[int], List[Tuple[str, int, List[int]]]]:
    """Execute the encode/decode pipeline using integer-friendly stages."""
    packets = [int(p) for p in packets]
    van = Van(m, k, full_width - 1)
    decode_coeffs = van.invert(packets)
    encode_coeffs = van.M[:, packets]

    data = list(payload)
    width = full_width - 1
    snapshots: List[Tuple[str, int, List[int]]] = [("input", width, data.copy())]

    data, width = parity_extend_words(data, width)
    snapshots.append(("lift_to_cyclic_domain", width, data.copy()))

    data = apply_matrix(decode_coeffs, data, width)
    snapshots.append(("fec_decode", width, data.copy()))

    data = apply_matrix(encode_coeffs, data, width)
    snapshots.append(("fec_encode", width, data.copy()))

    data, width = drop_parity_words(data, width)
    snapshots.append(("trim_zero_padding", width, data.copy()))

    return data, snapshots


def matrix_reference(bits: np.ndarray, m: int, k: int, length: int, packets: Sequence[int]) -> np.ndarray:
    """Reference implementation using full binary matrices for verification."""
    helper = HelperMatrix(m, length)
    cyclic = CyclicMatrix(length)
    van = Van(m, k, length - 1)

    vec = GF2(bits.reshape(-1))
    lifted = GF2(helper.op) @ vec
    decoded = GF2(cyclic.convert_matrix(van.invert(packets))) @ lifted
    encoded = GF2(cyclic.convert_matrix(van.M[:, packets])) @ decoded
    trimmed = GF2(helper.zp) @ encoded
    return trimmed.view(np.ndarray).reshape(bits.shape)


def format_symbols(stage_name: str, width: int, words: Sequence[int]) -> str:
    rows = [f"s{idx}: {''.join(map(str, int_to_bits(word, width)))}" for idx, word in enumerate(words)]
    return f"[{stage_name}]\n" + "\n".join(rows)


def run_trial(m: int, k: int, length: int, seed: int | None = None) -> None:
    rng = np.random.default_rng(seed)
    packets = np.sort(rng.choice(k, m, replace=False))

    payload_bits = rng.integers(0, 2, size=(m, length - 1), dtype=np.uint8)
    payload_words = bits_matrix_to_ints(payload_bits)

    restored_words, snapshots = run_pipeline(payload_words, packets, m, k, length)
    reference_bits = matrix_reference(payload_bits, m, k, length, packets)
    reference_words = bits_matrix_to_ints(reference_bits)

    print("Selected packets:", [int(p) for p in packets])
    for name, width, words in snapshots:
        print()
        print(format_symbols(name, width, words))

    matches_input = restored_words == payload_words
    matches_reference = restored_words == reference_words
    print("\nRestored matches input:", matches_input)
    print("Restored matches matrix reference:", matches_reference)
    if not matches_reference:
        diff_bits = ints_to_bits(
            [restored_words[i] ^ reference_words[i] for i in range(len(restored_words))],
            length - 1,
        )
        print("Difference vs reference:")
        print(diff_bits)


if __name__ == "__main__":
    run_trial(m=3, k=5, length=11, seed=42)

