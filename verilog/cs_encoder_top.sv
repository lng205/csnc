`timescale 1ns / 1ps

module cs_encoder_top #(
  parameter int M        = 3,
  parameter int WIDTH    = 11,
  parameter int DATA_W   = WIDTH - 1
) (
  input  logic [M*WIDTH-1:0]            decoded_symbols_flat,
  input  logic [M*M*WIDTH-1:0]          encode_coeffs_flat,
  output logic [M*WIDTH-1:0]            encoded_symbols_flat,
  output logic [M*DATA_W-1:0]           symbols_out_flat
);
  logic [WIDTH-1:0] decoded_symbols   [M];
  logic [WIDTH-1:0] encoded_symbols   [M];
  logic [DATA_W-1:0] symbols_out      [M];
  logic [WIDTH-1:0] encode_coeffs     [M][M];

  genvar r, c;
  generate
    for (r = 0; r < M; r++) begin : GEN_DECODED_UNPACK
      assign decoded_symbols[r] = decoded_symbols_flat[r*WIDTH +: WIDTH];
      assign encoded_symbols_flat[r*WIDTH +: WIDTH] = encoded_symbols[r];
      assign symbols_out_flat[r*DATA_W +: DATA_W] = symbols_out[r];
      for (c = 0; c < M; c++) begin : GEN_COEFF_UNPACK
        localparam int INDEX = (r*M + c);
        assign encode_coeffs[r][c] = encode_coeffs_flat[INDEX*WIDTH +: WIDTH];
      end
    end
  endgenerate

  fec_encoder #(
    .M(M),
    .WIDTH(WIDTH)
  ) u_encoder (
    .decoded_symbols(decoded_symbols),
    .encode_coeffs  (encode_coeffs),
    .encoded_symbols(encoded_symbols),
    .symbols_out    (symbols_out)
  );
endmodule
