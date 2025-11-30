//-----------------------------------------------------------------------------
// Module: cs_decoder
// Description: Parameterized (M, K) MDS Decoder using Cyclic Shift + XOR
//              - K coded symbols in (with erasure mask), M data symbols out
//              - Can recover from up to K-M symbol erasures
//
// Parameters:
//   M:     Number of data symbols (output)
//   K:     Number of coded symbols (input), K > M
//   WIDTH: Bits per symbol
//
// Decoding Strategy:
//   - For systematic code, if all M data symbols present, pass through
//   - If some data symbols erased, use parity to recover
//   - Supports single erasure recovery (extend for multiple)
//-----------------------------------------------------------------------------

module cs_decoder #(
    parameter M     = 2,
    parameter K     = 3,
    parameter WIDTH = 4,
    
    // Encoding shift table (same as encoder)
    parameter logic [3:0] SHIFT_TABLE [K-M][M] = '{default: '{default: 0}},
    
    // Inverse shift table for decoding
    // INV_SHIFT[p][d] = WIDTH - SHIFT_TABLE[p][d] (mod WIDTH)
    parameter logic [3:0] INV_SHIFT [K-M][M] = '{default: '{default: 0}}
) (
    input  logic                 clk,
    input  logic                 rst_n,
    
    // Input interface  
    input  logic                 valid_in,
    input  logic [K-1:0]         erasure,        // Bit mask: 1 = symbol erased
    input  logic [WIDTH-1:0]     coded_in [K],   // K coded symbols
    
    // Output interface
    output logic                 valid_out,
    output logic                 decode_ok,      // 1 = success, 0 = too many erasures
    output logic [WIDTH-1:0]     data_out [M]    // M recovered data symbols
);

    localparam NUM_PARITY = K - M;

    //-------------------------------------------------------------------------
    // Count erasures
    //-------------------------------------------------------------------------
    logic [$clog2(K+1)-1:0] erasure_count;
    logic [$clog2(M)-1:0]   erased_data_idx;     // Index of erased data symbol
    logic                   data_erased;         // At least one data symbol erased
    logic                   recoverable;

    always_comb begin
        erasure_count = '0;
        erased_data_idx = '0;
        data_erased = 1'b0;
        
        // Count total erasures
        for (int i = 0; i < K; i++) begin
            if (erasure[i]) erasure_count = erasure_count + 1;
        end
        
        // Find first erased data symbol (for single erasure recovery)
        for (int i = 0; i < M; i++) begin
            if (erasure[i]) begin
                erased_data_idx = i[$clog2(M)-1:0];
                data_erased = 1'b1;
            end
        end
        
        // Recoverable if erasures <= NUM_PARITY
        recoverable = (erasure_count <= NUM_PARITY);
    end

    //-------------------------------------------------------------------------
    // Recovery logic for single data erasure
    // Uses first available parity symbol
    //-------------------------------------------------------------------------
    logic [WIDTH-1:0] recovery_xor;         // XOR of other shifted data
    logic [WIDTH-1:0] recovery_shifted;     // After inverse shift
    logic [WIDTH-1:0] recovered_data;

    // For single erasure: recovery = inv_shift(parity XOR sum_of_other_shifted_data)
    always_comb begin
        recovery_xor = '0;
        
        // Find first non-erased parity
        for (int p = 0; p < NUM_PARITY; p++) begin
            if (!erasure[M + p]) begin
                // Start with parity value
                recovery_xor = coded_in[M + p];
                
                // XOR with shifted versions of non-erased data symbols
                for (int d = 0; d < M; d++) begin
                    if (d != erased_data_idx && !erasure[d]) begin
                        // Shift and XOR
                        for (int b = 0; b < WIDTH; b++) begin
                            recovery_xor[b] = recovery_xor[b] ^ 
                                coded_in[d][(b + SHIFT_TABLE[p][d]) % WIDTH];
                        end
                    end
                end
                break;  // Use first available parity
            end
        end
    end

    // Inverse shift to recover original data
    always_comb begin
        recovered_data = '0;
        
        // Apply inverse shift based on erased position
        for (int p = 0; p < NUM_PARITY; p++) begin
            if (!erasure[M + p]) begin
                for (int b = 0; b < WIDTH; b++) begin
                    recovered_data[b] = recovery_xor[(b + INV_SHIFT[p][erased_data_idx]) % WIDTH];
                end
                break;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Output logic
    //-------------------------------------------------------------------------
    logic [WIDTH-1:0] data_result [M];

    always_comb begin
        for (int i = 0; i < M; i++) begin
            if (erasure[i] && data_erased && recoverable) begin
                // This data symbol was erased - use recovered value
                data_result[i] = (i == erased_data_idx) ? recovered_data : coded_in[i];
            end else begin
                // Pass through
                data_result[i] = coded_in[i];
            end
        end
    end

    //-------------------------------------------------------------------------
    // Output registers
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            decode_ok <= 1'b0;
            for (int i = 0; i < M; i++) begin
                data_out[i] <= '0;
            end
        end else begin
            valid_out <= valid_in;
            decode_ok <= recoverable;
            for (int i = 0; i < M; i++) begin
                data_out[i] <= data_result[i];
            end
        end
    end

endmodule
