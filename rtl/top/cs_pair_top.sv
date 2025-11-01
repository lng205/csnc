// Top-level that instantiates encoder and decoder independently.
// Adds simple clocked wrappers (one-cycle register in/out) so both blocks
// can be implemented on hardware and accessed by software without internal coupling.

`timescale 1ns/1ps

module cs_pair_top #(
  parameter int K = 5,
  parameter int M = 3,
  parameter int L = 11
) (
  input  logic                         aclk,
  input  logic                         aresetn,

  // Encoder interface (independent)
  input  logic                         enc_in_valid,
  output logic                         enc_in_ready,
  input  logic [M-1:0][L-2:0]          enc_din,
  output logic                         enc_out_valid,
  output logic [K-1:0][L-2:0]          enc_dout,

  // Decoder interface (independent)
  input  logic                         dec_in_valid,
  output logic                         dec_in_ready,
  input  logic [K-1:0][L-2:0]          dec_din,
  output logic                         dec_out_valid,
  output logic [M-1:0][L-2:0]          dec_dout
);

  // Always ready, single-cycle latency handshake
  assign enc_in_ready = 1'b1;
  assign dec_in_ready = 1'b1;

  // Input registers
  logic [M-1:0][L-2:0] enc_din_q;
  logic [K-1:0][L-2:0] dec_din_q;

  // Combinational core outputs
  logic [K-1:0][L-2:0] enc_out_c;
  logic [M-1:0][L-2:0] dec_out_c;

  // Output registers and valid pipelines
  logic enc_v_q, enc_v_qq;
  logic dec_v_q, dec_v_qq;

  // Capture inputs and pipeline valid
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      enc_din_q <= '0;
      dec_din_q <= '0;
      enc_v_q   <= 1'b0;
      enc_v_qq  <= 1'b0;
      dec_v_q   <= 1'b0;
      dec_v_qq  <= 1'b0;
    end else begin
      if (enc_in_valid) enc_din_q <= enc_din;
      if (dec_in_valid) dec_din_q <= dec_din;
      enc_v_q  <= enc_in_valid;
      enc_v_qq <= enc_v_q;
      dec_v_q  <= dec_in_valid;
      dec_v_qq <= dec_v_q;
    end
  end

  // Instantiate combinational static cores
  cs_encoder_static #(
    .K(K), .M(M), .L(L)
  ) u_enc (
    .data_i(enc_din_q),
    .data_o(enc_out_c)
  );

  cs_decoder_static #(
    .K(K), .M(M), .L(L)
  ) u_dec (
    .data_i(dec_din_q),
    .data_o(dec_out_c)
  );

  // Register outputs to form reg->comb->reg paths
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      enc_dout      <= '0;
      dec_dout      <= '0;
      enc_out_valid <= 1'b0;
      dec_out_valid <= 1'b0;
    end else begin
      enc_dout      <= enc_out_c;
      dec_dout      <= dec_out_c;
      enc_out_valid <= enc_v_qq; // two-cycle pipeline (input capture + output reg)
      dec_out_valid <= dec_v_qq;
    end
  end

endmodule

