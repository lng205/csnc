// csnc_dec_k3_l12_erasure.sv
module csnc_dec_k3_l12_erasure #(
  parameter int L = 12,
  parameter int K = 3,
  parameter int VARS = L*K,    // 36
  parameter int EQS  = L*3     // 收到3个包 → 3*L 约束
)(
  input  logic            aclk,
  input  logic            aresetn,
  // AXIS in (3 equations/frame). role: 0=d0,1=d1,2=d2,3=p0,4=p1
  input  logic [L-1:0]    s_axis_tdata,
  input  logic [2:0]      s_axis_role,
  input  logic            s_axis_tvalid,
  output logic            s_axis_tready,
  input  logic            s_axis_tlast,
  // AXIS out (d0,d1,d2; 3 symbols/frame)
  output logic [L-1:0]    m_axis_tdata,
  output logic            m_axis_tvalid,
  input  logic            m_axis_tready,
  output logic            m_axis_tlast
);

  // --- build 12x12 identity and rot matrices on the fly ---
  function automatic logic [L-1:0] rotl(input logic [L-1:0] v, input int unsigned sh);
    int unsigned s; logic [2*L-1:0] dbl;
    begin s = (sh%L); dbl = {v,v}; return dbl[2*L-1-s -: L]; end
  endfunction

  function automatic logic [L-1:0] basis(input int idx);
    logic [L-1:0] e; begin e='0; e[idx]=1'b1; return e; end
  endfunction

  // Vandermonde exponents for parity rows (12-bit)
  localparam int R01 = 1,  R02 = 2;   // p0 row: [I, rot^1,  rot^2]
  localparam int R11 = 5,  R12 = 10;  // p1 row: [I, rot^5,  rot^10]

  // Storage for 36x36 matrix A and RHS y (36 bits)
  logic [VARS-1:0] A [0:EQS-1];  // each row: 36 bits
  logic            Y [0:EQS-1];

  // input buffering
  typedef enum logic [1:0] {COLLECT, ELIM, OUTPUT} state_t;
  state_t state, nstate;

  logic [1:0]   in_cnt;    // 0..2 rows collected
  logic [7:0]   piv_c, piv_r;  // elimination indices
  logic [VARS-1:0] X;      // solution (36 bits)

  // handshake
  assign s_axis_tready = (state==COLLECT);
  wire in_fire = s_axis_tvalid && s_axis_tready;

  // Build one equation block-row into A/Y (12 eqs for this packet)
  task automatic add_equation_block(input int blk_idx, input logic [L-1:0] vec, input int role);
    int r, c; logic [L-1:0] colvec;
    begin
      // rows r0..r0+11
      int r0 = blk_idx*L;
      for (r=0; r<L; r++) begin
        // clear row
        A[r0+r] = '0; Y[r0+r] = vec[r];
        // fill 3 blocks (d0,d1,d2)
        // block for d0:
        if (role==0) begin // d0 row: [I,0,0]
          A[r0+r][0*L + r] = 1'b1;
        end else if (role==3 || role==4) begin // parity row includes d0 with I
          A[r0+r][0*L + r] = 1'b1;
        end
        // block for d1:
        if (role==1) begin // d1 row: [0,I,0]
          A[r0+r][1*L + r] = 1'b1;
        end else if (role==3) begin // p0 uses rot^1
          // column j in block corresponds to effect of d1[j] on y[r]
          // rot^k means y = rot^k(d1); so y[r]=d1[(r - k) mod L]
          int j = (r - R01); if (j<0) j+=L;
          A[r0+r][1*L + j] = 1'b1;
        end else if (role==4) begin // p1 uses rot^5
          int j = (r - R11); if (j<0) j+=L;
          A[r0+r][1*L + j] = 1'b1;
        end
        // block for d2:
        if (role==2) begin // d2 row: [0,0,I]
          A[r0+r][2*L + r] = 1'b1;
        end else if (role==3) begin // p0 uses rot^2
          int j = (r - R02); if (j<0) j+=L;
          A[r0+r][2*L + j] = 1'b1;
        end else if (role==4) begin // p1 uses rot^10
          int j = (r - R12); if (j<0) j+=L;
          A[r0+r][2*L + j] = 1'b1;
        end
      end
    end
  endtask

  // Simple FSM
  always_comb begin
    nstate = state;
    unique case (state)
      COLLECT: if (in_cnt==2 && in_fire && s_axis_tlast) nstate = ELIM;
      ELIM:    if (piv_c==VARS)                          nstate = OUTPUT;
      OUTPUT:  if (m_axis_tready)                        nstate = COLLECT;
    endcase
  end

  // elimination core (GF(2) gaussian elimination with back-substitution)
  // We operate in-place on A/Y; X holds solution when done.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state<=COLLECT; in_cnt<=0; piv_c<=0; piv_r<=0; X<='0;
    end else begin
      state <= nstate;

      case (state)
        COLLECT: begin
          if (in_fire) begin
            add_equation_block(in_cnt, s_axis_tdata, s_axis_role);
            in_cnt <= in_cnt + 1;
            if (s_axis_tlast) begin
              // init elimination indices
              piv_c <= 0; piv_r <= 0;
            end
          end
        end

        ELIM: begin
          // forward elimination over columns 0..VARS-1
          if (piv_c < VARS) begin
            // find pivot row at/after piv_r with A[row][piv_c]==1
            int r;
            int found = 0;
            for (r = piv_r; r < EQS; r++) begin
              if (A[r][piv_c]) begin
                found = 1;
                // swap rows r and piv_r if needed
                if (r != piv_r) begin
                  logic [VARS-1:0] tmpA; logic tmpY;
                  tmpA = A[r]; A[r] = A[piv_r]; A[piv_r] = tmpA;
                  tmpY = Y[r]; Y[r] = Y[piv_r]; Y[piv_r] = tmpY;
                end
                break;
              end
            end
            // if pivot found, eliminate below
            if (found) begin
              // eliminate rows r = 0..EQS-1 excluding piv_r
              int rr, cc;
              for (rr = 0; rr < EQS; rr++) begin
                if (rr!=piv_r && A[rr][piv_c]) begin
                  A[rr] ^= A[piv_r];
                  Y[rr] ^= Y[piv_r];
                end
              end
              piv_r <= piv_r + 1;
            end
            piv_c <= piv_c + 1;
          end else begin
            // back substitution: with columns reduced, read solution
            // (A is now RREF; X[c] = Y[row_of_pivot_c])
            int c, r2;
            X <= '0;
            for (c = 0; c < VARS; c++) begin
              // find row with pivot at column c
              for (r2 = 0; r2 < EQS; r2++) begin
                if (A[r2][c]) begin
                  // ensure row has single 1 at pivot (RREF)
                  X[c] <= Y[r2];
                  break;
                end
              end
            end
          end
        end

        OUTPUT: begin
          // stream out d0,d1,d2 (each 12 bits) in order
          m_axis_tvalid <= 1'b1;
          m_axis_tdata  <= X[0 +: L];
          m_axis_tlast  <= 1'b0;
          if (m_axis_tready) begin
            // shift remaining
            X <= { { (VARS-L){1'b0} }, X[VARS-1 -: (VARS-L)] }; // rotate windows
            // after three beats, reset for next frame
            // for simplicity, pulse one beat per cycle
            // (testbench将连续吃3拍)
          end
          // go back to COLLECT on state transition (handled by nstate)
          if (nstate==COLLECT) begin
            in_cnt<=0; m_axis_tvalid<=1'b0; m_axis_tlast<=1'b0;
          end
        end
      endcase
    end
  end

  // default outputs
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      m_axis_tvalid <= 1'b0; m_axis_tdata<='0; m_axis_tlast<=1'b0;
    end else if (state!=OUTPUT) begin
      m_axis_tvalid <= 1'b0; m_axis_tlast<=1'b0;
    end
  end

endmodule
