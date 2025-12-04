`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Module: cs_decoder_2_3
// Description: Fixed (2, 3) MDS Decoder - Simple and Correct
//              - 2 data symbols, 1 parity symbol
//              - Can recover 1 erasure
//              - WIDTH = 4 bits
//
// Encoding: p0 = shift(d0, 1) XOR shift(d1, 2)
// Decoding:
//   - d0 erased: d0 = inv_shift(p0 XOR shift(d1, 2), 1)
//   - d1 erased: d1 = inv_shift(p0 XOR shift(d0, 1), 2)
//-----------------------------------------------------------------------------

module cs_decoder_2_3 (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input
    input  logic        valid_in,
    input  logic [2:0]  erasure,        // [0]=d0, [1]=d1, [2]=p0
    input  logic [3:0]  coded_in [3],   // [0]=d0/c0, [1]=d1/c1, [2]=p0/c2
    
    // Output
    output logic        valid_out,
    output logic        decode_ok,
    output logic [3:0]  data_out [2]    // Recovered d0, d1
);

    // Fixed parameters
    localparam WIDTH = 4;
    localparam SHIFT_D0 = 1;  // shift amount for d0 in parity
    localparam SHIFT_D1 = 2;  // shift amount for d1 in parity
    localparam INV_SHIFT_D0 = 3;  // (WIDTH - SHIFT_D0) % WIDTH
    localparam INV_SHIFT_D1 = 2;  // (WIDTH - SHIFT_D1) % WIDTH

    //-------------------------------------------------------------------------
    // Cyclic shift functions (inline for simplicity)
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
    // Combinational decode logic
    //-------------------------------------------------------------------------
    logic [3:0] d0_recovered, d1_recovered;
    logic [3:0] temp_xor;
    logic       can_decode;

    always_comb begin
        // Default: pass through
        d0_recovered = coded_in[0];
        d1_recovered = coded_in[1];
        can_decode = 1'b1;

        // Count erasures
        case (erasure)
            3'b000: begin
                // No erasure - pass through
                d0_recovered = coded_in[0];
                d1_recovered = coded_in[1];
            end
            
            3'b001: begin
                // d0 erased: d0 = inv_shift(p0 XOR shift(d1, 2), 1)
                temp_xor = coded_in[2] ^ shift_right(coded_in[1], SHIFT_D1);
                d0_recovered = shift_right(temp_xor, INV_SHIFT_D0);
                d1_recovered = coded_in[1];
            end
            
            3'b010: begin
                // d1 erased: d1 = inv_shift(p0 XOR shift(d0, 1), 2)
                temp_xor = coded_in[2] ^ shift_right(coded_in[0], SHIFT_D0);
                d0_recovered = coded_in[0];
                d1_recovered = shift_right(temp_xor, INV_SHIFT_D1);
            end
            
            3'b100: begin
                // p0 erased - data intact, pass through
                d0_recovered = coded_in[0];
                d1_recovered = coded_in[1];
            end
            
            default: begin
                // Too many erasures
                can_decode = 1'b0;
                d0_recovered = '0;
                d1_recovered = '0;
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // Output registers
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            decode_ok <= 1'b0;
            data_out[0] <= '0;
            data_out[1] <= '0;
        end else begin
            valid_out <= valid_in;
            decode_ok <= can_decode;
            data_out[0] <= d0_recovered;
            data_out[1] <= d1_recovered;
        end
    end

endmodule

