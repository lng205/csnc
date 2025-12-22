`timescale 1ns / 1ps

module cyclic_basis_op #(
    parameter L = 11,
    parameter SHIFT = 0
) (
    input  wire [L-2:0] in_vec,
    output wire [L-2:0] out_vec
);
    // 逻辑对应 Python 中的:
    // 1. zero_eye: 扩展到 L 维 (在 index 0 处补 0)
    // 2. Cyclic Shift: 循环右移 SHIFT 位
    // 3. one_eye: 压缩回 L-1 维 (index 0 加到其他位)

    wire [L-1:0] expanded;
    wire [L-1:0] shifted;

    // 1. Expand: [u_{L-2}, ..., u_0] -> [u_{L-2}, ..., u_0, 0]
    // 对应 Python zero_eye (L x L-1)，第一行为0。我们假设 bit 0 对应 index 0。
    assign expanded = {in_vec, 1'b0};

    // 2. Cyclic Right Shift by SHIFT
    // Verilog 中 >> 是逻辑右移，我们需要拼接实现循环
    assign shifted = (expanded >> SHIFT) | (expanded << (L - SHIFT));

    // 3. Project: [v_{L-1}, ..., v_1, v_0]
    // 对应 Python one_eye: result[i] = v[i+1] ^ v[0]
    // out_vec[k] 对应 shifted[k+1] ^ shifted[0]
    
    genvar i;
    generate
        for (i = 0; i < L-1; i = i + 1) begin : proj_loop
            assign out_vec[i] = shifted[i+1] ^ shifted[0];
        end
    endgenerate

endmodule


module gf_mult_const #(
    parameter L = 11,
    parameter COEFF = 0 // Integer representation of the field element
) (
    input  wire [L-2:0] in_vec,
    output wire [L-2:0] out_vec
);
    // 每一个置位的比特对应一个循环移位的叠加
    // 例如 COEFF = 11 (binary 1011) -> Shift(0) ^ Shift(1) ^ Shift(3)

    wire [L-2:0] partial_sums [L-1:0]; 
    wire [L-2:0] final_sum;

    genvar b;
    generate
        for (b = 0; b < L; b = b + 1) begin : bit_slice
            if ((COEFF >> b) & 1) begin
                // 如果系数的第 b 位是 1，则实例化一个移位算子
                cyclic_basis_op #(.L(L), .SHIFT(b)) shifter (
                    .in_vec(in_vec),
                    .out_vec(partial_sums[b])
                );
            end else begin
                // 否则输出 0
                assign partial_sums[b] = {(L-1){1'b0}};
            end
        end
    endgenerate

    // 将所有分支结果异或起来
    // 简单的级联异或
    integer k;
    reg [L-2:0] accum;
    always @(*) begin
        accum = 0;
        for (k = 0; k < L; k = k + 1) begin
            accum = accum ^ partial_sums[k];
        end
    end

    assign out_vec = accum;

endmodule


module csnc_encoder (
    input  wire [49:0] data_in,  // 5 symbols * 10 bits
    output wire [89:0] data_out  // 9 symbols * 10 bits
);
    // Parameters matches Python: m=5, k=9, L=11
    localparam L = 11;
    localparam W = L - 1; // 10 bits width

    // Unpack inputs
    wire [W-1:0] x [0:4];
    assign x[0] = data_in[9:0];
    assign x[1] = data_in[19:10];
    assign x[2] = data_in[29:20];
    assign x[3] = data_in[39:30];
    assign x[4] = data_in[49:40];

    // Systematic outputs (first 5 are copy of inputs)
    assign data_out[9:0]   = x[0];
    assign data_out[19:10] = x[1];
    assign data_out[29:20] = x[2];
    assign data_out[39:30] = x[3];
    assign data_out[49:40] = x[4];

    // Parity outputs (calculated based on Vandermonde matrix)
    // Matrix P part (rows 0-4 correspond to inputs x0-x4)
    // Column 5: [1, 11, 69, 743, 19]^T
    // Column 6: [1, 69, 19, 864, 261]^T
    // Column 7: [1, 743, 864, 806, 861]^T
    // Column 8: [1, 19, 261, 861, 49]^T

    // --- Helper to sum 5 multiplication results ---
    // y = sum(x_i * coeff_i)
    
    // We need 4 parity output blocks. Let's define them.
    wire [W-1:0] p [0:3]; // Parity 0, 1, 2, 3 (corresponding to Col 5, 6, 7, 8)

    // --- Parity 0 (Col 5) ---
    // Coeffs: 1, 11, 69, 743, 19
    wire [W-1:0] p0_terms [0:4];
    gf_mult_const #(.L(L), .COEFF(1))   m00 (.in_vec(x[0]), .out_vec(p0_terms[0]));
    gf_mult_const #(.L(L), .COEFF(11))  m01 (.in_vec(x[1]), .out_vec(p0_terms[1]));
    gf_mult_const #(.L(L), .COEFF(69))  m02 (.in_vec(x[2]), .out_vec(p0_terms[2]));
    gf_mult_const #(.L(L), .COEFF(743)) m03 (.in_vec(x[3]), .out_vec(p0_terms[3]));
    gf_mult_const #(.L(L), .COEFF(19))  m04 (.in_vec(x[4]), .out_vec(p0_terms[4]));
    assign p[0] = p0_terms[0] ^ p0_terms[1] ^ p0_terms[2] ^ p0_terms[3] ^ p0_terms[4];

    // --- Parity 1 (Col 6) ---
    // Coeffs: 1, 69, 19, 864, 261
    wire [W-1:0] p1_terms [0:4];
    gf_mult_const #(.L(L), .COEFF(1))   m10 (.in_vec(x[0]), .out_vec(p1_terms[0]));
    gf_mult_const #(.L(L), .COEFF(69))  m11 (.in_vec(x[1]), .out_vec(p1_terms[1]));
    gf_mult_const #(.L(L), .COEFF(19))  m12 (.in_vec(x[2]), .out_vec(p1_terms[2]));
    gf_mult_const #(.L(L), .COEFF(864)) m13 (.in_vec(x[3]), .out_vec(p1_terms[3]));
    gf_mult_const #(.L(L), .COEFF(261)) m14 (.in_vec(x[4]), .out_vec(p1_terms[4]));
    assign p[1] = p1_terms[0] ^ p1_terms[1] ^ p1_terms[2] ^ p1_terms[3] ^ p1_terms[4];

    // --- Parity 2 (Col 7) ---
    // Coeffs: 1, 743, 864, 806, 861
    wire [W-1:0] p2_terms [0:4];
    gf_mult_const #(.L(L), .COEFF(1))   m20 (.in_vec(x[0]), .out_vec(p2_terms[0]));
    gf_mult_const #(.L(L), .COEFF(743)) m21 (.in_vec(x[1]), .out_vec(p2_terms[1]));
    gf_mult_const #(.L(L), .COEFF(864)) m22 (.in_vec(x[2]), .out_vec(p2_terms[2]));
    gf_mult_const #(.L(L), .COEFF(806)) m23 (.in_vec(x[3]), .out_vec(p2_terms[3]));
    gf_mult_const #(.L(L), .COEFF(861)) m24 (.in_vec(x[4]), .out_vec(p2_terms[4]));
    assign p[2] = p2_terms[0] ^ p2_terms[1] ^ p2_terms[2] ^ p2_terms[3] ^ p2_terms[4];

    // --- Parity 3 (Col 8) ---
    // Coeffs: 1, 19, 261, 861, 49
    wire [W-1:0] p3_terms [0:4];
    gf_mult_const #(.L(L), .COEFF(1))   m30 (.in_vec(x[0]), .out_vec(p3_terms[0]));
    gf_mult_const #(.L(L), .COEFF(19))  m31 (.in_vec(x[1]), .out_vec(p3_terms[1]));
    gf_mult_const #(.L(L), .COEFF(261)) m32 (.in_vec(x[2]), .out_vec(p3_terms[2]));
    gf_mult_const #(.L(L), .COEFF(861)) m33 (.in_vec(x[3]), .out_vec(p3_terms[3]));
    gf_mult_const #(.L(L), .COEFF(49))  m34 (.in_vec(x[4]), .out_vec(p3_terms[4]));
    assign p[3] = p3_terms[0] ^ p3_terms[1] ^ p3_terms[2] ^ p3_terms[3] ^ p3_terms[4];

    // Assign Parity Outputs
    assign data_out[59:50] = p[0];
    assign data_out[69:60] = p[1];
    assign data_out[79:70] = p[2];
    assign data_out[89:80] = p[3];

endmodule