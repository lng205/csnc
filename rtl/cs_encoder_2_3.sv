`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Module: cs_encoder_2_3
// Description: Fixed (2, 3) MDS Encoder - Simple and Correct
//              - 2 data symbols in, 3 coded symbols out
//              - WIDTH = 4 bits
//
// Encoding: p0 = shift(d0, 1) XOR shift(d1, 2)
//-----------------------------------------------------------------------------

module cs_encoder_2_3 (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input
    input  logic        valid_in,
    input  logic [3:0]  data_in [2],    // d0, d1
    
    // Output
    output logic        valid_out,
    output logic [3:0]  coded_out [3]   // d0, d1, p0
);

    // Fixed parameters
    localparam WIDTH = 4;
    localparam SHIFT_D0 = 1;
    localparam SHIFT_D1 = 2;

    //-------------------------------------------------------------------------
    // Cyclic shift (inline)
    //-------------------------------------------------------------------------
    function automatic logic [3:0] shift_right(input logic [3:0] val, input int amt);
        case (amt)
            0: return val;
            1: return {val[0], val[3:1]};
            2: return {val[1:0], val[3:2]};
            3: return {val[2:0], val[3]};
            default: return val;
        endcase
    endfunction

    //-------------------------------------------------------------------------
    // Parity computation
    //-------------------------------------------------------------------------
    logic [3:0] parity;
    
    always_comb begin
        parity = shift_right(data_in[0], SHIFT_D0) ^ shift_right(data_in[1], SHIFT_D1);
    end

    //-------------------------------------------------------------------------
    // Output registers
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            coded_out[0] <= '0;
            coded_out[1] <= '0;
            coded_out[2] <= '0;
        end else begin
            valid_out <= valid_in;
            coded_out[0] <= data_in[0];  // Systematic: d0
            coded_out[1] <= data_in[1];  // Systematic: d1
            coded_out[2] <= parity;      // Parity: p0
        end
    end

endmodule

