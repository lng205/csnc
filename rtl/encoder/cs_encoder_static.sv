// Combinational cyclic-shift + XOR encoder (static coefficients)
// Fixed-parameter example aligned to L=11 (=> 10-bit symbols after drop parity bit)
// Default maps first 3 outputs to pass-through of 3 inputs; last 2 outputs are parity-like XORs.

module cs_encoder_static #(
  parameter int K = 5,    // outputs (systematic: first M are pass-through)
  parameter int M = 3,    // inputs (data symbols per codeword)
  parameter int L = 11,   // lifted bit width (original symbol is L-1)
  parameter logic [L-1:0] COEFF [K][M] = '{
    // row 0..2: identity on inputs 0..2
    '{ 11'b00000000001, 11'b00000000000, 11'b00000000000 },
    '{ 11'b00000000000, 11'b00000000001, 11'b00000000000 },
    '{ 11'b00000000000, 11'b00000000000, 11'b00000000001 },
    // row 3..4: simple parity: out3 = in0 ^ rot1(in1); out4 = rot3(in2)
    '{ 11'b00000000001, 11'b00000000010, 11'b00000000000 },
    '{ 11'b00000001000, 11'b00000000000, 11'b00000000001 }
  }
) (
  input  logic [M-1:0][L-2:0] data_i,   // M inputs of (L-1) bits
  output logic [K-1:0][L-2:0] data_o    // K outputs of (L-1) bits
);

  function automatic logic [L-1:0] rotl(input logic [L-1:0] x, input int s);
    logic [L-1:0] y; int sh; begin
      sh = (s % L + L) % L;
      y = (x << sh) | (x >> (L - sh));
      return y;
    end
  endfunction

  function automatic logic [L-1:0] apply_mask(
    input logic [L-1:0] mask,
    input logic [L-1:0] sym
  );
    logic [L-1:0] acc;
    acc = '0;
    for (int s = 0; s < L; s++) begin
      if (mask[s]) acc ^= rotl(sym, s);
    end
    return acc;
  endfunction

  logic [M-1:0][L-1:0] lift;
  for (genvar i = 0; i < M; ++i) begin : G_LIFT
    logic p;
    assign p = ^data_i[i];
    assign lift[i] = {p, data_i[i]};
  end

  for (genvar r = 0; r < K; ++r) begin : G_ROW
    logic [L-1:0] acc;
    always_comb begin
      acc = '0;
      for (int c = 0; c < M; ++c) begin
        if (COEFF[r][c] != '0) acc ^= apply_mask(COEFF[r][c], lift[c]);
      end
    end
    assign data_o[r] = acc[L-2:0];
  end

endmodule

