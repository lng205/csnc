//-----------------------------------------------------------------------------
// Package: cs_config_pkg
// Description: Pre-defined configurations for common (M, K) setups
//              Shift tables derived from Vandermonde matrix in GF(2^n)
//-----------------------------------------------------------------------------

package cs_config_pkg;

    //=========================================================================
    // Configuration: (2, 3) - Simplest MDS
    // 2 data, 1 parity, can recover 1 erasure
    // L=5, WIDTH=4 bits per symbol
    //=========================================================================
    localparam CFG_2_3_M     = 2;
    localparam CFG_2_3_K     = 3;
    localparam CFG_2_3_WIDTH = 4;
    
    // Shift table: SHIFT_TABLE[parity_idx][data_idx]
    // Parity_0 = shift(d0, 1) XOR shift(d1, 2)
    localparam logic [3:0] CFG_2_3_SHIFT [1][2] = '{
        '{1, 2}     // Parity 0: shift amounts for d0, d1
    };
    
    // Inverse shifts: (WIDTH - shift) % WIDTH
    localparam logic [3:0] CFG_2_3_INV [1][2] = '{
        '{3, 2}     // WIDTH=4: inv(1)=3, inv(2)=2
    };

    //=========================================================================
    // Configuration: (3, 5) - Practical setup
    // 3 data, 2 parity, can recover 2 erasures
    // L=5, WIDTH=4 bits per symbol
    //=========================================================================
    localparam CFG_3_5_M     = 3;
    localparam CFG_3_5_K     = 5;
    localparam CFG_3_5_WIDTH = 4;
    
    // Parity_0 = shift(d0, 1) XOR shift(d1, 2) XOR shift(d2, 3)
    // Parity_1 = shift(d0, 2) XOR shift(d1, 0) XOR shift(d2, 2)
    localparam logic [3:0] CFG_3_5_SHIFT [2][3] = '{
        '{1, 2, 3},     // Parity 0
        '{2, 0, 2}      // Parity 1
    };
    
    localparam logic [3:0] CFG_3_5_INV [2][3] = '{
        '{3, 2, 1},     // Inverse of parity 0 shifts
        '{2, 0, 2}      // Inverse of parity 1 shifts
    };

    //=========================================================================
    // Configuration: (4, 6) - Higher protection
    // 4 data, 2 parity, can recover 2 erasures
    // L=7, WIDTH=6 bits per symbol
    //=========================================================================
    localparam CFG_4_6_M     = 4;
    localparam CFG_4_6_K     = 6;
    localparam CFG_4_6_WIDTH = 6;
    
    localparam logic [3:0] CFG_4_6_SHIFT [2][4] = '{
        '{1, 2, 3, 4},  // Parity 0
        '{2, 4, 1, 3}   // Parity 1
    };
    
    localparam logic [3:0] CFG_4_6_INV [2][4] = '{
        '{5, 4, 3, 2},  // WIDTH=6: inv shifts
        '{4, 2, 5, 3}
    };

    //=========================================================================
    // Configuration: (4, 8) - High redundancy
    // 4 data, 4 parity, can recover 4 erasures (50% overhead)
    // L=9, WIDTH=8 bits per symbol
    //=========================================================================
    localparam CFG_4_8_M     = 4;
    localparam CFG_4_8_K     = 8;
    localparam CFG_4_8_WIDTH = 8;
    
    localparam logic [3:0] CFG_4_8_SHIFT [4][4] = '{
        '{1, 2, 3, 4},
        '{2, 4, 6, 0},
        '{3, 6, 1, 4},
        '{4, 0, 4, 0}
    };
    
    localparam logic [3:0] CFG_4_8_INV [4][4] = '{
        '{7, 6, 5, 4},
        '{6, 4, 2, 0},
        '{5, 2, 7, 4},
        '{4, 0, 4, 0}
    };

endpackage
