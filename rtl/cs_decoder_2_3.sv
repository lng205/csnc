//-----------------------------------------------------------------------------
// Module: cs_decoder_2_3
// Description: Simple (2,3) MDS Decoder using Cyclic Shift + XOR
//              - 3 coded symbols in (with erasure mask), 2 data symbols out
//              - Can recover from any 1 symbol erasure
//
// Decoding cases:
//   erasure[0]=1: data_0 lost -> recover from coded_1 and coded_2
//   erasure[1]=1: data_1 lost -> recover from coded_0 and coded_2  
//   erasure[2]=1: parity lost -> no recovery needed (systematic)
//   no erasure:   pass through systematic symbols
//-----------------------------------------------------------------------------

module cs_decoder_2_3 #(
    parameter WIDTH = 4             // Symbol width (L-1), L=5
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid_in,
    input  logic [2:0]           erasure,    // Erasure mask: bit[i]=1 means coded_i lost
    input  logic [WIDTH-1:0]     coded_0,    // First coded symbol (data_0 or garbage if erased)
    input  logic [WIDTH-1:0]     coded_1,    // Second coded symbol (data_1 or garbage if erased)
    input  logic [WIDTH-1:0]     coded_2,    // Third coded symbol (parity or garbage if erased)
    
    output logic                 valid_out,
    output logic                 decode_ok,  // 1 = successful decode, 0 = too many erasures
    output logic [WIDTH-1:0]     data_0,     // Recovered data_0
    output logic [WIDTH-1:0]     data_1      // Recovered data_1
);

    //-------------------------------------------------------------------------
    // Internal signals for recovery
    //-------------------------------------------------------------------------
    logic [WIDTH-1:0] recover_0;
    logic [WIDTH-1:0] recover_1;
    logic [WIDTH-1:0] shifted_1_inv;    // Inverse shift of coded_1 (shift by WIDTH-2)
    logic [WIDTH-1:0] shifted_0_inv;    // Inverse shift of coded_0 (shift by WIDTH-1)
    logic [WIDTH-1:0] shifted_parity_0; // Parity shifted for recovery
    logic [WIDTH-1:0] shifted_parity_1;
    logic             ok;

    //-------------------------------------------------------------------------
    // Inverse cyclic shifts for decoding
    // To invert shift by N, we shift by (WIDTH - N)
    //-------------------------------------------------------------------------
    
    // Inverse shift for recovering data_0: need to undo shift by 1
    // shift(parity XOR shift(data_1,2), WIDTH-1) 
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (WIDTH - 1)      // Inverse of shift by 1
    ) u_inv_shift_0 (
        .data_in   (shifted_parity_0),
        .data_out  (recover_0)
    );

    // Intermediate: shift coded_1 by 2 for XOR with parity
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (2)
    ) u_shift_c1 (
        .data_in   (coded_1),
        .data_out  (shifted_1_inv)
    );
    
    assign shifted_parity_0 = coded_2 ^ shifted_1_inv;

    // Inverse shift for recovering data_1: need to undo shift by 2
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (WIDTH - 2)      // Inverse of shift by 2
    ) u_inv_shift_1 (
        .data_in   (shifted_parity_1),
        .data_out  (recover_1)
    );

    // Intermediate: shift coded_0 by 1 for XOR with parity
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (1)
    ) u_shift_c0 (
        .data_in   (coded_0),
        .data_out  (shifted_0_inv)
    );
    
    assign shifted_parity_1 = coded_2 ^ shifted_0_inv;

    //-------------------------------------------------------------------------
    // Decode logic
    //-------------------------------------------------------------------------
    always_comb begin
        ok = 1'b1;
        
        case (erasure)
            3'b000: begin   // No erasure - pass through
                data_0 = coded_0;
                data_1 = coded_1;
            end
            3'b001: begin   // coded_0 (data_0) erased
                data_0 = recover_0;
                data_1 = coded_1;
            end
            3'b010: begin   // coded_1 (data_1) erased
                data_0 = coded_0;
                data_1 = recover_1;
            end
            3'b100: begin   // coded_2 (parity) erased - no recovery needed
                data_0 = coded_0;
                data_1 = coded_1;
            end
            default: begin  // Multiple erasures - cannot decode
                data_0 = '0;
                data_1 = '0;
                ok = 1'b0;
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // Output registers
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            decode_ok <= 1'b0;
        end else begin
            valid_out <= valid_in;
            decode_ok <= ok;
        end
    end

endmodule
