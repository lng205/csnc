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

  // Parity extension in the cyclic domain.
  function automatic logic [WIDTH-1:0] parity_extend(input logic [DATA_W-1:0] word);
    logic parity = ^word;
    return {parity, word};
  endfunction

  function automatic logic [DATA_W-1:0] drop_parity(input logic [WIDTH-1:0] word);
    return word[DATA_W-1:0];
  endfunction

  always_comb begin
    for (int idx = 0; idx < M; idx++) begin
      lifted_symbols[idx] = parity_extend(symbols_in[idx]);
    end
  end

  fec_matrix_apply #(
    .ROWS(M),
    .COLS(M),
    .W(WIDTH)
  ) decode_stage (
    .coeffs (decode_coeffs),
    .symbols(lifted_symbols),
    .result (decoded_symbols)
  );

  fec_matrix_apply #(
    .ROWS(M),
    .COLS(M),
    .W(WIDTH)
  ) encode_stage (
    .coeffs (encode_coeffs),
    .symbols(decoded_symbols),
    .result (encoded_symbols)
  );

  always_comb begin
    for (int idx = 0; idx < M; idx++) begin
      symbols_out[idx] = drop_parity(encoded_symbols[idx]);
    end
  end

endmodule : fec_codec
