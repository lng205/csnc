#!/usr/bin/env python3
"""
Generate shift amount table for CS-FEC RTL implementation.
This script bridges the Python algorithm and Verilog implementation.
"""

import sys
sys.path.insert(0, '../core')

from vandermonde import Van
import numpy as np

def gen_shift_table(m: int, k: int, L: int):
    """
    Generate shift amounts for (m, k) MDS code with L-dimensional cyclic matrix.
    
    Args:
        m: number of data symbols
        k: number of coded symbols (m data + k-m parity)
        L: cyclic matrix dimension (each symbol is L-1 bits)
    
    Returns:
        Dictionary with shift amounts for encoding and decoding
    """
    van = Van(m, k, L - 1)
    
    print(f"CS-FEC Configuration: (m={m}, k={k}, L={L})")
    print(f"  Data symbols:   {m}")
    print(f"  Parity symbols: {k - m}")
    print(f"  Symbol width:   {L - 1} bits")
    print(f"  Max erasures:   {k - m}")
    print()
    
    # The Vandermonde matrix
    print("Vandermonde Matrix (as field elements):")
    print(van.M)
    print()
    
    # Extract parity rows (columns m to k-1 of the systematic matrix)
    # For encoding: parity_j = XOR of shift(data_i, shift_amount[i][j])
    print("Encoding Shift Amounts:")
    print("(Each parity symbol is XOR of shifted data symbols)")
    
    shift_table = []
    for j in range(k - m):
        row_shifts = []
        print(f"  Parity {j}:", end=" ")
        for i in range(m):
            # Get the field element at position [i, m+j]
            elem = int(van.M[i, m + j])
            # The shift amount is the log of the element (in GF(2^order))
            # For simple cases, element value directly maps to shift
            shift = elem.bit_length() - 1 if elem > 0 else 0
            # Actually for our cyclic matrix conversion, we use the element directly
            # as an index into power-of-alpha shifts
            row_shifts.append(elem)
            print(f"shift(d{i}, {elem})", end=" ")
            if i < m - 1:
                print("XOR", end=" ")
        print()
        shift_table.append(row_shifts)
    
    print()
    return {
        'm': m,
        'k': k,
        'L': L,
        'width': L - 1,
        'matrix': van.M.tolist(),
        'shift_table': shift_table
    }


def gen_verilog_params(config: dict):
    """Generate Verilog parameter snippet."""
    m, k, L = config['m'], config['k'], config['L']
    
    print("Verilog Instantiation Template:")
    print("-" * 40)
    print(f"""
// Parameters
localparam WIDTH = {L - 1};  // Symbol width (L-1)
localparam M = {m};          // Data symbols
localparam K = {k};          // Total symbols

// Shift amounts for encoding (parity generation)
// shift_table[parity_idx][data_idx] = shift amount
""")
    
    for j, row in enumerate(config['shift_table']):
        shifts = ', '.join(str(s) for s in row)
        print(f"localparam logic [{L-1}-1:0] PARITY{j}_SHIFTS [{m}] = '{{{shifts}}};")
    
    print()


def main():
    # Example: (2, 3) code - simplest MDS
    print("=" * 50)
    config_2_3 = gen_shift_table(2, 3, 5)
    gen_verilog_params(config_2_3)
    
    # Example: (3, 5) code - more practical
    print("=" * 50)
    config_3_5 = gen_shift_table(3, 5, 5)
    gen_verilog_params(config_3_5)
    
    # Example: (4, 6) code
    print("=" * 50)
    config_4_6 = gen_shift_table(4, 6, 7)
    gen_verilog_params(config_4_6)


if __name__ == "__main__":
    main()
