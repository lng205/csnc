//-----------------------------------------------------------------------------
// Module: cs_codec
// Description: Complete CS-FEC Codec - Encoder + Decoder in one module
//              Provides a unified interface for encode/decode operations
//
// Parameters:
//   M:     Number of data symbols
//   K:     Number of total symbols (M data + K-M parity)
//   WIDTH: Bits per symbol
//   SHIFT_TABLE: Encoding shift amounts [parity_idx][data_idx]
//   INV_SHIFT:   Decoding inverse shifts [parity_idx][data_idx]
//-----------------------------------------------------------------------------

module cs_codec #(
    parameter M     = 2,
    parameter K     = 3,
    parameter WIDTH = 4,
    parameter logic [3:0] SHIFT_TABLE [K-M][M] = '{default: '{default: 0}},
    parameter logic [3:0] INV_SHIFT   [K-M][M] = '{default: '{default: 0}}
) (
    input  logic             clk,
    input  logic             rst_n,
    
    //-------------------------------------------------------------------------
    // Encoder interface
    //-------------------------------------------------------------------------
    input  logic             enc_valid_in,
    input  logic [WIDTH-1:0] enc_data_in [M],
    output logic             enc_valid_out,
    output logic [WIDTH-1:0] enc_coded_out [K],
    
    //-------------------------------------------------------------------------
    // Decoder interface
    //-------------------------------------------------------------------------
    input  logic             dec_valid_in,
    input  logic [K-1:0]     dec_erasure,
    input  logic [WIDTH-1:0] dec_coded_in [K],
    output logic             dec_valid_out,
    output logic             dec_ok,
    output logic [WIDTH-1:0] dec_data_out [M]
);

    //-------------------------------------------------------------------------
    // Encoder instance
    //-------------------------------------------------------------------------
    cs_encoder #(
        .M           (M),
        .K           (K),
        .WIDTH       (WIDTH),
        .SHIFT_TABLE (SHIFT_TABLE)
    ) u_encoder (
        .clk         (clk),
        .rst_n       (rst_n),
        .valid_in    (enc_valid_in),
        .data_in     (enc_data_in),
        .valid_out   (enc_valid_out),
        .coded_out   (enc_coded_out)
    );

    //-------------------------------------------------------------------------
    // Decoder instance
    //-------------------------------------------------------------------------
    cs_decoder #(
        .M           (M),
        .K           (K),
        .WIDTH       (WIDTH),
        .SHIFT_TABLE (SHIFT_TABLE),
        .INV_SHIFT   (INV_SHIFT)
    ) u_decoder (
        .clk         (clk),
        .rst_n       (rst_n),
        .valid_in    (dec_valid_in),
        .erasure     (dec_erasure),
        .coded_in    (dec_coded_in),
        .valid_out   (dec_valid_out),
        .decode_ok   (dec_ok),
        .data_out    (dec_data_out)
    );

endmodule
