#!/usr/bin/env python3
"""
验证 (2, 3) MDS 码的编解码
- 2 个数据符号，1 个校验符号
- 可恢复 1 个擦除
- WIDTH = 4 bits (L = 5)
"""

import numpy as np

# 配置
M, K, WIDTH = 2, 3, 4
L = WIDTH + 1  # L = 5

def cyclic_shift_right(val, shift, width=WIDTH):
    """循环右移"""
    shift = shift % width
    return ((val >> shift) | (val << (width - shift))) & ((1 << width) - 1)

def cyclic_shift_left(val, shift, width=WIDTH):
    """循环左移 (逆移位)"""
    return cyclic_shift_right(val, width - shift, width)

# 从 cs_config_pkg.sv 获取的移位表
# Parity_0 = shift(d0, 1) XOR shift(d1, 2)
SHIFT_TABLE = [[1, 2]]  # [parity_idx][data_idx]

def encode(d0, d1):
    """编码：生成校验符号"""
    p0 = cyclic_shift_right(d0, SHIFT_TABLE[0][0]) ^ cyclic_shift_right(d1, SHIFT_TABLE[0][1])
    return [d0, d1, p0]

def decode_no_erasure(c0, c1, c2):
    """无擦除：直接返回数据"""
    return c0, c1

def decode_d0_erased(c1, c2):
    """d0 被擦除：用 p0 和 d1 恢复 d0
    
    p0 = shift(d0, 1) XOR shift(d1, 2)
    shift(d0, 1) = p0 XOR shift(d1, 2)
    d0 = inv_shift(p0 XOR shift(d1, 2), 1)
    """
    temp = c2 ^ cyclic_shift_right(c1, SHIFT_TABLE[0][1])
    d0 = cyclic_shift_left(temp, SHIFT_TABLE[0][0])
    return d0, c1

def decode_d1_erased(c0, c2):
    """d1 被擦除：用 p0 和 d0 恢复 d1
    
    p0 = shift(d0, 1) XOR shift(d1, 2)
    shift(d1, 2) = p0 XOR shift(d0, 1)
    d1 = inv_shift(p0 XOR shift(d0, 1), 2)
    """
    temp = c2 ^ cyclic_shift_right(c0, SHIFT_TABLE[0][0])
    d1 = cyclic_shift_left(temp, SHIFT_TABLE[0][1])
    return c0, d1

def decode_p0_erased(c0, c1):
    """p0 被擦除：数据完整，直接返回"""
    return c0, c1

def test_case(d0, d1, erasure_mask, name):
    """测试一个用例"""
    print(f"\n=== {name} ===")
    print(f"Input: d0=0x{d0:X}, d1=0x{d1:X}")
    
    # 编码
    coded = encode(d0, d1)
    print(f"Encoded: c0=0x{coded[0]:X}, c1=0x{coded[1]:X}, p0=0x{coded[2]:X}")
    
    # 模拟擦除
    received = [0 if (erasure_mask >> i) & 1 else coded[i] for i in range(K)]
    print(f"Erasure mask: {erasure_mask:03b}, Received: {[f'0x{x:X}' for x in received]}")
    
    # 解码
    if erasure_mask == 0b000:
        result = decode_no_erasure(*received)
    elif erasure_mask == 0b001:
        result = decode_d0_erased(received[1], received[2])
    elif erasure_mask == 0b010:
        result = decode_d1_erased(received[0], received[2])
    elif erasure_mask == 0b100:
        result = decode_p0_erased(received[0], received[1])
    else:
        print("Too many erasures!")
        return False
    
    print(f"Decoded: d0=0x{result[0]:X}, d1=0x{result[1]:X}")
    
    # 验证
    if result[0] == d0 and result[1] == d1:
        print("[PASS]")
        return True
    else:
        print(f"[FAIL]: Expected d0=0x{d0:X}, d1=0x{d1:X}")
        return False

def main():
    print("=" * 50)
    print("(2, 3) MDS Code Verification")
    print(f"WIDTH={WIDTH}, SHIFT_TABLE={SHIFT_TABLE}")
    print("=" * 50)
    
    tests = [
        (0xA, 0x5, 0b000, "No erasure"),
        (0xA, 0x5, 0b001, "D0 erased"),
        (0xA, 0x5, 0b010, "D1 erased"),
        (0xA, 0x5, 0b100, "P0 erased"),
        (0xF, 0x0, 0b001, "Edge: d0=F, d1=0, D0 erased"),
        (0x0, 0xF, 0b010, "Edge: d0=0, d1=F, D1 erased"),
        (0x1, 0x1, 0b001, "Small: d0=1, d1=1, D0 erased"),
    ]
    
    passed = sum(test_case(*t) for t in tests)
    print(f"\n{'=' * 50}")
    print(f"Results: {passed}/{len(tests)} passed")
    
    # 打印 RTL 需要的参数
    print(f"\n{'=' * 50}")
    print("RTL Parameters:")
    print(f"  SHIFT_TABLE[0] = {{{SHIFT_TABLE[0][0]}, {SHIFT_TABLE[0][1]}}}")
    print(f"  INV_SHIFT[0] = {{{WIDTH - SHIFT_TABLE[0][0]}, {WIDTH - SHIFT_TABLE[0][1]}}}")
    print(f"                = {{{(WIDTH - SHIFT_TABLE[0][0]) % WIDTH}, {(WIDTH - SHIFT_TABLE[0][1]) % WIDTH}}}")

if __name__ == "__main__":
    main()

