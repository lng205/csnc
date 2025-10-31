// Combinational cyclic-shift + XOR decoder (static coefficients)
// Reconstruct M original symbols from K inputs using inverse matrix masks.

module cs_decoder_static #(
  parameter int K = 5,    // inputs (systematic: first M carry original, last K-M are redundancy)
  parameter int M = 3,    // outputs (recovered data symbols)
  parameter int L = 11,   // lifted bit width (original symbol is L-1)
  // Default masks are illustrative; real design应由 algo 侧生成逆矩阵掩码
  parameter logic [L-1:0] COEFF [M][K] = '{
    // out0 = in0 ^ rot1(in3)
    '{ 11'b00000000001, 11'b00000000000, 11'b00000000000, 11'b00000000010, 11'b00000000000 },
    // out1 = rot2(in1) ^ in4
    '{ 11'b00000000000, 11'b00000000100, 11'b00000000000, 11'b00000000000, 11'b00000000001 },
    // out2 = rot3(in2)
    '{ 11'b00000000000, 11'b00000000000, 11'b00000001000, 11'b00000000000, 11'b00000000000 }
  }
) (
  input  logic [K-1:0][L-2:0] data_i,   // K inputs of (L-1) bits
  output logic [M-1:0][L-2:0] data_o    // M outputs of (L-1) bits
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

  // lift inputs by parity bit
  logic [K-1:0][L-1:0] lift;
  for (genvar i = 0; i < K; ++i) begin : G_LIFT
    logic p;
    assign p = ^data_i[i];
    assign lift[i] = {p, data_i[i]};
  end

  // rows accumulate from K inputs with masks
  for (genvar r = 0; r < M; ++r) begin : G_ROW
    logic [L-1:0] acc;
    always_comb begin
      acc = '0;
      for (int c = 0; c < K; ++c) begin
        if (COEFF[r][c] != '0) acc ^= apply_mask(COEFF[r][c], lift[c]);
      end
    end
    assign data_o[r] = acc[L-2:0];
  end

endmodule
