//-----------------------------------------------------------------------------
// Module: cs_encoder_2_3
// Description: Simple (2,3) MDS Encoder using Cyclic Shift + XOR
//              - 2 data symbols in, 3 coded symbols out
//              - Can recover from any 1 symbol loss
//              - Uses L=5 (4-bit symbols)
//
// Encoding Matrix (systematic form):
//   [1  0]      -> output[0] = data[0]
//   [0  1]      -> output[1] = data[1]  
//   [α  α²]     -> output[2] = shift(data[0], 1) XOR shift(data[1], 2)
//
// Where α is primitive element in GF(2^4), shift amounts from Vandermonde
//-----------------------------------------------------------------------------

module cs_encoder_2_3 #(
    parameter WIDTH = 4             // Symbol width (L-1), L=5
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid_in,
    input  logic [WIDTH-1:0]     data_0,     // First data symbol
    input  logic [WIDTH-1:0]     data_1,     // Second data symbol
    
    output logic                 valid_out,
    output logic [WIDTH-1:0]     coded_0,    // = data_0 (systematic)
    output logic [WIDTH-1:0]     coded_1,    // = data_1 (systematic)
    output logic [WIDTH-1:0]     coded_2     // = parity (cyclic shift + XOR)
);

    //-------------------------------------------------------------------------
    // Internal signals
    //-------------------------------------------------------------------------
    logic [WIDTH-1:0] shifted_0;    // data_0 shifted by 1
    logic [WIDTH-1:0] shifted_1;    // data_1 shifted by 2
    logic [WIDTH-1:0] parity;

    //-------------------------------------------------------------------------
    // Cyclic shift units
    // Shift amounts derived from Vandermonde matrix: α^(i*j) in GF(2^4)
    //-------------------------------------------------------------------------
    
    // Shift data_0 by 1 position (corresponds to α^1)
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (1)
    ) u_shift_0 (
        .data_in   (data_0),
        .data_out  (shifted_0)
    );

    // Shift data_1 by 2 positions (corresponds to α^2)
    cyclic_shift #(
        .WIDTH     (WIDTH),
        .SHIFT_AMT (2)
    ) u_shift_1 (
        .data_in   (data_1),
        .data_out  (shifted_1)
    );

    //-------------------------------------------------------------------------
    // Parity generation: XOR of shifted symbols
    //-------------------------------------------------------------------------
    assign parity = shifted_0 ^ shifted_1;

    //-------------------------------------------------------------------------
    // Output registers (pipeline stage)
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            coded_0   <= '0;
            coded_1   <= '0;
            coded_2   <= '0;
        end else begin
            valid_out <= valid_in;
            coded_0   <= data_0;        // Systematic: pass through
            coded_1   <= data_1;        // Systematic: pass through
            coded_2   <= parity;        // Parity symbol
        end
    end

endmodule
