// Verilog wrapper for SystemVerilog cs_pair_impl_top to enable BD module reference
module cs_pair_impl_top_wrap #(parameter K=5, parameter M=3, parameter L=11) (
  input wire aclk,
  input wire aresetn
);
  cs_pair_impl_top #(.K(K), .M(M), .L(L)) u_top (
    .aclk(aclk), .aresetn(aresetn)
  );
endmodule

