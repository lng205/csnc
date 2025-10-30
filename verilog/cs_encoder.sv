// cxor_enc_l11p1_k3_s2.sv
module cxor_enc_l11p1_k3_s2 #(
  parameter int LIN   = 11,
  parameter int LOUT  = 12      // lifted width (output width)
)(
  input  logic              aclk,
  input  logic              aresetn,
  // AXIS in: 3 symbols/frame, TLAST on 3rd
  input  logic [LIN-1:0]    s_axis_tdata,
  input  logic              s_axis_tvalid,
  output logic              s_axis_tready,
  input  logic              s_axis_tlast,
  // AXIS out: 5 symbols/frame (12-bit), TLAST on 5th
  output logic [LOUT-1:0]   m_axis_tdata,
  output logic              m_axis_tvalid,
  input  logic              m_axis_tready,
  output logic              m_axis_tlast
);

  // --- utils ---
  function automatic logic [LOUT-1:0] lift(input logic [LIN-1:0] x);
    logic parity; begin parity = ^x; return {parity, x}; end
  endfunction

  function automatic logic [LOUT-1:0] rotl(input logic [LOUT-1:0] v, input int unsigned sh);
    int unsigned s; logic [2*LOUT-1:0] dbl;
    begin s = (sh % LOUT); dbl = {v,v}; return dbl[2*LOUT-1-s -: LOUT]; end
  endfunction

  // Vandermonde exponents (12-bit domain)
  localparam int R0_0 = 0, R0_1 = 1,  R0_2 = 2;   // parity0: [1, x^1,  x^2]
  localparam int R1_0 = 0, R1_1 = 5,  R1_2 = 10;  // parity1: [1, x^5,  x^10]

  typedef enum logic [1:0] {IDLE, PASS_INFO, OUT_PAR} state_t;
  state_t state, nstate;

  logic [1:0] in_idx;     // 0..2
  logic       par_idx;    // 0..1
  logic [LOUT-1:0] acc0, acc1;

  wire in_fire  = s_axis_tvalid && s_axis_tready;
  wire out_fire = m_axis_tvalid && m_axis_tready;

  // next state
  always_comb begin
    nstate = state;
    unique case (state)
      IDLE:       if (in_fire)                   nstate = PASS_INFO;
      PASS_INFO:  if (in_fire && s_axis_tlast)   nstate = OUT_PAR;
      OUT_PAR:    if (out_fire && par_idx)       nstate = IDLE;
    endcase
  end

  // input ready：冗余阶段暂停
  always_comb begin
    s_axis_tready = (state==OUT_PAR) ? 1'b0 : m_axis_tready;
  end

  // output mux：信息阶段直通已lift的12bit；之后吐2个parity
  always_comb begin
    m_axis_tvalid = 1'b0; m_axis_tdata='0; m_axis_tlast=1'b0;
    unique case (state)
      IDLE, PASS_INFO: begin
        m_axis_tvalid = s_axis_tvalid;
        m_axis_tdata  = lift(s_axis_tdata);
      end
      OUT_PAR: begin
        m_axis_tvalid = 1'b1;
        m_axis_tdata  = (par_idx==1'b0) ? acc0 : acc1;
        m_axis_tlast  = (par_idx==1'b1);
      end
    endcase
  end

  // state & accumulators
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state<=IDLE; in_idx<=0; par_idx<=0; acc0<='0; acc1<='0;
    end else begin
      state <= nstate;

      if (state==IDLE && in_fire) begin
        acc0 <= '0; acc1 <= '0; in_idx <= 1;
        acc0 <= rotl(lift(s_axis_tdata), R0_0);
        acc1 <= rotl(lift(s_axis_tdata), R1_0);
      end
      else if (state==PASS_INFO && in_fire) begin
        unique case (in_idx)
          1: begin
            acc0 <= acc0 ^ rotl(lift(s_axis_tdata), R0_1);
            acc1 <= acc1 ^ rotl(lift(s_axis_tdata), R1_1);
          end
          default: begin
            acc0 <= acc0 ^ rotl(lift(s_axis_tdata), R0_2);
            acc1 <= acc1 ^ rotl(lift(s_axis_tdata), R1_2);
          end
        endcase
        in_idx <= in_idx + 1;
      end

      if (state==OUT_PAR && out_fire) begin
        par_idx <= par_idx + 1;
        if (par_idx) begin par_idx<=0; in_idx<=0; end
      end
    end
  end
endmodule
