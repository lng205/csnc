`timescale 1ns / 1ps

module fec_encoder #(
  parameter int M        = 3,
  parameter int WIDTH    = 11,
  parameter int DATA_W   = WIDTH - 1
) (
  input  logic [WIDTH-1:0]  decoded_symbols[M],
  input  logic [WIDTH-1:0]  encode_coeffs   [M][M],
  output logic [WIDTH-1:0]  encoded_symbols[M],
  output logic [DATA_W-1:0] symbols_out     [M]
);

  function automatic logic [DATA_W-1:0] drop_parity(input logic [WIDTH-1:0] word);
    return word[DATA_W-1:0];
  endfunction

  fec_matrix_apply #(
    .ROWS(M),
    .COLS(M),
    .W(WIDTH)
  ) apply_encode (
    .coeffs (encode_coeffs),
    .symbols(decoded_symbols),
    .result (encoded_symbols)
  );

  always_comb begin
    for (int idx = 0; idx < M; idx++) begin
      symbols_out[idx] = drop_parity(encoded_symbols[idx]);
    end
  end

endmodule : fec_encoder
