// Implementation wrapper for screenshot: minimal IO (clock/reset only)
// Instantiates encoder and decoder independently and drives them with
// simple internal test patterns to avoid pruning. No external data IOs.

`timescale 1ns/1ps

module cs_pair_impl_top #(
  parameter int K = 5,
  parameter int M = 3,
  parameter int L = 11
) (
  input  logic aclk,
  input  logic aresetn
);

  // Keep attributes to avoid trimming
  (* DONT_TOUCH = "TRUE" *) logic [M-1:0][L-2:0] enc_din;
  (* DONT_TOUCH = "TRUE" *) logic [K-1:0][L-2:0] enc_dout;
  (* DONT_TOUCH = "TRUE" *) logic [K-1:0][L-2:0] dec_din;
  (* DONT_TOUCH = "TRUE" *) logic [M-1:0][L-2:0] dec_dout;

  logic enc_in_valid, enc_in_ready, enc_out_valid;
  logic dec_in_valid, dec_in_ready, dec_out_valid;

  // Simple LFSRs to generate activity for both encoder and decoder inputs
  logic [15:0] lfsr_a, lfsr_b;
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      lfsr_a <= 16'h1;
      lfsr_b <= 16'hACE1;
    end else begin
      // x^16 + x^14 + x^13 + x^11 + 1
      lfsr_a <= {lfsr_a[14:0], lfsr_a[15]^lfsr_a[13]^lfsr_a[12]^lfsr_a[10]};
      lfsr_b <= {lfsr_b[14:0], ~(lfsr_b[15]^lfsr_b[13]^lfsr_b[12]^lfsr_b[10])};
    end
  end

  // Drive inputs with repeated LFSR slices, independent for enc/dec
  for (genvar i = 0; i < M; ++i) begin : G_ENC_STIM
    always_ff @(posedge aclk) begin
      if (!aresetn) enc_din[i] <= '0; else enc_din[i] <= { {(L-1){1'b0}} } ^ lfsr_a[L-2:0];
    end
  end

  for (genvar j = 0; j < K; ++j) begin : G_DEC_STIM
    always_ff @(posedge aclk) begin
      if (!aresetn) dec_din[j] <= '0; else dec_din[j] <= { {(L-1){1'b0}} } ^ lfsr_b[L-2:0];
    end
  end

  // Always-valid handshake; cores are combinational with one-cycle regs external
  assign enc_in_valid = 1'b1;
  assign dec_in_valid = 1'b1;

  // Instantiate pair top (independent encoder/decoder)
  (* keep_hierarchy = "yes", DONT_TOUCH = "TRUE" *)
  cs_pair_top #(.K(K), .M(M), .L(L)) u_pair (
    .aclk(aclk), .aresetn(aresetn),
    .enc_in_valid(enc_in_valid), .enc_in_ready(enc_in_ready), .enc_din(enc_din), .enc_out_valid(enc_out_valid), .enc_dout(enc_dout),
    .dec_in_valid(dec_in_valid), .dec_in_ready(dec_in_ready), .dec_din(dec_din), .dec_out_valid(dec_out_valid), .dec_dout(dec_dout)
  );

  // Sink outputs into a dummy register to maintain fanout
  (* DONT_TOUCH = "TRUE" *) logic sink;
  always_ff @(posedge aclk) begin
    if (!aresetn) sink <= 1'b0; else begin
      sink <= ^{enc_dout, dec_dout, enc_out_valid, dec_out_valid, enc_in_ready, dec_in_ready};
    end
  end

endmodule

