`timescale 1ns / 1ps

module fec_codec #(
  parameter int M        = 3,
  parameter int WIDTH    = 11,  // width in cyclic domain (parity included)
  parameter int DATA_W   = WIDTH - 1
) (
  input  logic [DATA_W-1:0] symbols_in    [M],
  input  logic [WIDTH-1:0]  decode_coeffs [M][M],
  input  logic [WIDTH-1:0]  encode_coeffs [M][M],
  output logic [DATA_W-1:0] symbols_out   [M],
  output logic [WIDTH-1:0]  lifted_symbols[M],
  output logic [WIDTH-1:0]  decoded_symbols[M],
  output logic [WIDTH-1:0]  encoded_symbols[M]
);

  fec_decoder #(
    .M(M),
    .WIDTH(WIDTH)
  ) u_decoder (
    .symbols_in    (symbols_in),
    .decode_coeffs (decode_coeffs),
    .lifted_symbols(lifted_symbols),
    .decoded_symbols(decoded_symbols)
  );

  fec_encoder #(
    .M(M),
    .WIDTH(WIDTH)
  ) u_encoder (
    .decoded_symbols(decoded_symbols),
    .encode_coeffs  (encode_coeffs),
    .encoded_symbols(encoded_symbols),
    .symbols_out    (symbols_out)
  );

endmodule : fec_codec
