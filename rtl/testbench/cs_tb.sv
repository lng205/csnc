// tb_csnc_k3n5.sv
`timescale 1ns/1ps
module tb_csnc_k3n5;
  localparam int LIN  = 11;
  localparam int LOUT = 12;

  logic clk=0, rstn=0; always #5 clk = ~clk;

  // DUTs
  logic [LIN-1:0]  s_tdata;  logic s_tvalid, s_tready, s_tlast;
  logic [LOUT-1:0] m_tdata;  logic m_tvalid, m_tready, m_tlast;

  cxor_enc_l11p1_k3_s2 u_enc(
    .aclk(clk), .aresetn(rstn),
    .s_axis_tdata(s_tdata), .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready), .s_axis_tlast(s_tlast),
    .m_axis_tdata(m_tdata), .m_axis_tvalid(m_tvalid), .m_axis_tready(m_tready), .m_axis_tlast(m_tlast)
  );

  // capture encoder outputs into simple RAM
  logic [LOUT-1:0] codeword [0:4];
  int out_idx;

  // decoder I/F
  logic [LOUT-1:0]  dec_s_tdata; logic [2:0] dec_s_role; logic dec_s_tvalid, dec_s_tready, dec_s_tlast;
  logic [LOUT-1:0]  dec_m_tdata; logic        dec_m_tvalid, dec_m_tready, dec_m_tlast;

  csnc_dec_k3_l12_erasure u_dec(
    .aclk(clk), .aresetn(rstn),
    .s_axis_tdata(dec_s_tdata), .s_axis_role(dec_s_role),
    .s_axis_tvalid(dec_s_tvalid), .s_axis_tready(dec_s_tready), .s_axis_tlast(dec_s_tlast),
    .m_axis_tdata(dec_m_tdata), .m_axis_tvalid(dec_m_tvalid), .m_axis_tready(dec_m_tready), .m_axis_tlast(dec_m_tlast)
  );

  // helpers
  function automatic [LOUT-1:0] lift(input [LIN-1:0] x);
    lift = {^x, x};
  endfunction

  // stimulus
  initial begin
    m_tready = 1; dec_m_tready = 1;
    s_tvalid = 0; s_tlast = 0; rstn = 0;
    repeat(5) @(posedge clk);
    rstn = 1;

    // random data
    int i;
    logic [LIN-1:0] d0 = $urandom();
    logic [LIN-1:0] d1 = $urandom();
    logic [LIN-1:0] d2 = $urandom();

    // drive encoder: 3 inputs
    @(posedge clk);
    s_tdata  = d0; s_tvalid=1; s_tlast=0; wait(s_tready); @(posedge clk);
    s_tdata  = d1; s_tvalid=1; s_tlast=0; wait(s_tready); @(posedge clk);
    s_tdata  = d2; s_tvalid=1; s_tlast=1; wait(s_tready); @(posedge clk);
    s_tvalid=0; s_tlast=0;

    // capture 5 outputs
    out_idx = 0;
    wait(m_tvalid);
    while (out_idx<5) begin
      if (m_tvalid) begin
        codeword[out_idx] = m_tdata;
        out_idx++;
      end
      @(posedge clk);
    end

    // choose any 3 of 5; e.g., pick {d1, p0, p1} = indices {1,3,4}
    int pick [0:2]; pick[0]=1; pick[1]=3; pick[2]=4;

    // feed decoder three packets with roles
    // roles: 0=d0,1=d1,2=d2,3=p0,4=p1
    automatic int rtab [0:4] = '{0,1,2,3,4};

    for (i=0;i<3;i++) begin
      @(posedge clk);
      dec_s_tdata  <= codeword[pick[i]];
      dec_s_role   <= rtab[pick[i]];
      dec_s_tvalid <= 1;
      dec_s_tlast  <= (i==2);
      wait(dec_s_tready);
    end
    @(posedge clk); dec_s_tvalid<=0; dec_s_tlast<=0;

    // collect 3 outputs (d0,d1,d2 12b) and compare (只比低11位；MSB是奇偶)
    logic [LOUT-1:0] r0, r1, r2;
    wait(dec_m_tvalid); r0 = dec_m_tdata; @(posedge clk);
    wait(dec_m_tvalid); r1 = dec_m_tdata; @(posedge clk);
    wait(dec_m_tvalid); r2 = dec_m_tdata; @(posedge clk);

    if (r0[10:0]!==d0 || r1[10:0]!==d1 || r2[10:0]!==d2) begin
      $display("FAIL: mismatch");
      $display("d0=%h r0=%h | d1=%h r1=%h | d2=%h r2=%h", d0, r0, d1, r1, d2, r2);
    end else begin
      $display("PASS");
    end
    #20 $finish;
  end
endmodule
