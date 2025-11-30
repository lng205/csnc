//-----------------------------------------------------------------------------
// Module: cs_encoder
// Description: Parameterized (M, K) MDS Encoder using Cyclic Shift + XOR
//              - M data symbols in, K coded symbols out
//              - Systematic code: first M outputs = input data
//              - Remaining K-M outputs = parity symbols
//
// Parameters:
//   M:     Number of data symbols (input)
//   K:     Number of coded symbols (output), K > M
//   WIDTH: Bits per symbol (= L-1 where L is cyclic matrix dimension)
//
// Shift Table Format:
//   SHIFT_TABLE[p][d] = shift amount for data symbol d contributing to parity p
//   Parity_p = XOR of cyclic_shift(data_d, SHIFT_TABLE[p][d]) for all d
//-----------------------------------------------------------------------------

module cs_encoder #(
    parameter M     = 2,                // Data symbols
    parameter K     = 3,                // Total symbols (M data + K-M parity)
    parameter WIDTH = 4,                // Symbol width in bits
    
    // Shift table: [parity_idx][data_idx] -> shift amount
    // Default: simple incrementing pattern (override for real use)
    parameter logic [3:0] SHIFT_TABLE [K-M][M] = '{default: '{default: 0}}
) (
    input  logic                 clk,
    input  logic                 rst_n,
    
    // Input interface
    input  logic                 valid_in,
    input  logic [WIDTH-1:0]     data_in [M],    // M data symbols
    
    // Output interface
    output logic                 valid_out,
    output logic [WIDTH-1:0]     coded_out [K]   // K coded symbols
);

    localparam NUM_PARITY = K - M;

    //-------------------------------------------------------------------------
    // Internal signals
    //-------------------------------------------------------------------------
    logic [WIDTH-1:0] shifted [NUM_PARITY][M];  // Shifted data for each parity
    logic [WIDTH-1:0] parity [NUM_PARITY];      // Computed parity symbols

    //-------------------------------------------------------------------------
    // Generate shift units for parity computation
    //-------------------------------------------------------------------------
    generate
        genvar p, d;
        
        // For each parity symbol
        for (p = 0; p < NUM_PARITY; p++) begin : gen_parity
            // Shift each data symbol
            for (d = 0; d < M; d++) begin : gen_shift
                cyclic_shift #(
                    .WIDTH     (WIDTH),
                    .SHIFT_AMT (SHIFT_TABLE[p][d])
                ) u_shift (
                    .data_in   (data_in[d]),
                    .data_out  (shifted[p][d])
                );
            end
        end
    endgenerate

    //-------------------------------------------------------------------------
    // XOR tree for parity generation
    //-------------------------------------------------------------------------
    generate
        genvar pi;
        for (pi = 0; pi < NUM_PARITY; pi++) begin : gen_xor
            always_comb begin
                parity[pi] = '0;
                for (int di = 0; di < M; di++) begin
                    parity[pi] = parity[pi] ^ shifted[pi][di];
                end
            end
        end
    endgenerate

    //-------------------------------------------------------------------------
    // Output registers (single pipeline stage)
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            for (int i = 0; i < K; i++) begin
                coded_out[i] <= '0;
            end
        end else begin
            valid_out <= valid_in;
            
            // Systematic: first M outputs are data pass-through
            for (int i = 0; i < M; i++) begin
                coded_out[i] <= data_in[i];
            end
            
            // Remaining outputs are parity
            for (int i = 0; i < NUM_PARITY; i++) begin
                coded_out[M + i] <= parity[i];
            end
        end
    end

endmodule
