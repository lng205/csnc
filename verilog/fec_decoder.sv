`timescale 1ns / 1ps

module fec_decoder #(
  parameter int M        = 3,
  parameter int WIDTH    = 11,  // width in cyclic domain (parity included)
  parameter int DATA_W   = WIDTH - 1
) (
  input  logic [DATA_W-1:0] symbols_in    [M],
  input  logic [WIDTH-1:0]  decode_coeffs [M][M],
  output logic [WIDTH-1:0]  lifted_symbols[M],
  output logic [WIDTH-1:0]  decoded_symbols[M]
);

  function automatic logic [WIDTH-1:0] parity_extend(input logic [DATA_W-1:0] word);
    logic parity = ^word;
    return {parity, word};
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
  ) apply_decode (
    .coeffs (decode_coeffs),
    .symbols(lifted_symbols),
    .result (decoded_symbols)
  );

endmodule : fec_decoder
