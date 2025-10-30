`timescale 1ns / 1ps

module fec_matrix_apply #(
  parameter int ROWS = 3,
  parameter int COLS = 3,
  parameter int W    = 11
) (
  input  logic [W-1:0] coeffs [ROWS][COLS],
  input  logic [W-1:0] symbols[COLS],
  output logic [W-1:0] result [ROWS]
);

  function automatic int popcount(input logic [W-1:0] value);
    int count;
    count = 0;
    for (int idx = 0; idx < W; idx++) begin
      count += value[idx];
    end
    return count;
  endfunction

  function automatic logic [W-1:0] rotate_left(
    input logic [W-1:0] word,
    input int           shift
  );
    int sh;
    logic [W-1:0] left_part;
    logic [W-1:0] right_part;

    if (W == 0) begin
      return '0;
    end
    sh = shift % W;
    if (sh == 0) begin
      return word;
    end
    left_part  = word << sh;
    right_part = word >> (W - sh);
    return left_part | right_part;
  endfunction

  function automatic logic [W-1:0] apply_coefficient(
    input logic [W-1:0] mask,
    input logic [W-1:0] symbol
  );
    logic [W-1:0] adjusted;
    logic [W-1:0] accum;

    if (mask == '0) begin
      return '0;
    end

    adjusted = mask;
    if (popcount(mask) > (W - 1) / 2) begin
      adjusted = ~mask;
    end

    accum = '0;
    for (int shift = 0; shift < W; shift++) begin
      if (adjusted[shift]) begin
        accum ^= rotate_left(symbol, shift);
      end
    end
    return accum;
  endfunction

  always_comb begin
    for (int row = 0; row < ROWS; row++) begin
      logic [W-1:0] accum;
      accum = '0;
      for (int col = 0; col < COLS; col++) begin
        if (coeffs[row][col] != '0) begin
          accum ^= apply_coefficient(coeffs[row][col], symbols[col]);
        end
      end
      result[row] = accum;
    end
  end

endmodule : fec_matrix_apply
