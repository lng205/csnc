`timescale 1ns/1ps

module cs_pipeline_tb;
  // Parameters
  localparam int L = 11; // lifted width
  localparam int M = 3;  // data symbols
  localparam int K = 5;  // total outputs

  // Include generated masks (avail: 0,1,2)
  `include "generated/cs_coeff_L11_M3_K5_avail_0_1_2.svh"

  // DUTs with injected coefficients
  logic [M-1:0][L-2:0] din;
  logic [K-1:0][L-2:0] enc_out;
  logic [M-1:0][L-2:0] dec_out;

  cs_encoder_static #(
    .K(K), .M(M), .L(L), .COEFF(CS_ENC_COEFF)
  ) u_enc (
    .data_i(din), .data_o(enc_out)
  );

  cs_decoder_static #(
    .K(K), .M(M), .L(L), .COEFF(CS_DEC_COEFF)
  ) u_dec (
    .data_i(enc_out), .data_o(dec_out)
  );

  function automatic [L-2:0] rand_symbol(int seed);
    rand_symbol = $urandom(seed) % (1<<(L-1));
  endfunction

  initial begin
    // Deterministic stimulus
    din[0] = rand_symbol(1);
    din[1] = rand_symbol(2);
    din[2] = rand_symbol(3);

    #1;
    // Since decoder is configured to use columns 0..2 only, recover din
    if (dec_out !== din) begin
      $display("FAIL: dec_out != din\n din=%p\n dec_out=%p", din, dec_out);
      $finish(1);
    end
    $display("PASS: CS encode->decode recovers input (fixed erasure pattern)");
    $finish(0);
  end
endmodule

