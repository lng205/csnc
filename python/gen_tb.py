import numpy as np
import galois
from csnc import cyclic_shift_powers, helper_blocks, build_linear, Vandermonde

def generate_tb():
    m, k, L = 5, 9, 11
    
    # Setup Python Encoder
    van = Vandermonde(m, k, L)
    powers = cyclic_shift_powers(L)
    zero_eye, one_eye = helper_blocks(L)
    encode_alpha = van.M.T
    E_full = build_linear(encode_alpha, powers, zero_eye, one_eye)
    
    # Generate Random Input (m blocks of L-1 bits)
    n_bits = m * (L - 1)
    x = np.random.randint(0, 2, size=(n_bits, 1), dtype=int)
    
    # Calculate Expected Output
    y_all = (E_full @ x) % 2
    
    # Helper to convert bit column to hex string
    def bits_to_hex(bits, width_bits):
        val = 0
        for b in bits.flatten()[::-1]: # LSB at index 0? No, usually array 0 is top.
            # Python array: [0, 1, 1...]
            # Standard binary: 0...110
            # Let's assume array index 0 is LSB for the purpose of the previous logic 
            # WAIT. In the Verilog design:
            # "assign expanded = {in_vec, 1'b0};"
            # This implies in_vec LSB is close to the 0 padding.
            # Python `build_linear` uses Kron.
            # Let's just treat the bit array as a big integer.
            val = (val << 1) | int(b)
        return f"{width_bits}'h{val:x}"

    # Helper for Verilog integer construction (Little Endian)
    def bits_to_int(bits):
        # bits is a column vector.
        # Python: row 0 is top.
        # We need to pack it into an integer.
        val = 0
        # Iterate backwards so row 0 becomes MSB or LSB?
        # In Verilog: data_in[9:0] = x[0].
        # In Python: x[0:10] is the first block.
        # If we treat x[0] as LSB:
        for i in range(len(bits)):
             if bits[i]: val |= (1 << i)
        return val

    # We need to match the bit ordering exactly.
    # Python: `y = E @ x`. E is constructed via Kronecker.
    # `element_to_cyclic` uses `powers[bit]`.
    # `powers[0]` corresponds to bit 0.
    # So index 0 of the vector is the LSB in the polynomial representation.
    # In Verilog: `in_vec` [9:0]. Bit 0 is LSB.
    # So Python vector index `i` maps to Verilog bit `i`.
    
    # Construct Input Hex
    # We have m=5 symbols, each 10 bits.
    # Total input width = 50.
    # data_in[9:0] is symbol 0.
    input_val = 0
    for i in range(n_bits):
        if x[i]: input_val |= (1 << i)
    
    input_hex = f"50'h{input_val:013x}"
    
    # Construct Output Hex
    # Total output width = 90.
    output_val = 0
    for i in range(len(y_all)):
        if y_all[i]: output_val |= (1 << i)
        
    output_hex = f"90'h{output_val:023x}"
    
    tb_content = f"""
`timescale 1ns / 1ps

module csnc_tb;

    reg [49:0] data_in;
    wire [89:0] data_out;
    reg [89:0] expected_out;

    // Instantiate the Unit Under Test (UUT)
    csnc_encoder uut (
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        // Initialize Inputs
        data_in = 0;
        expected_out = 0;

        // Wait 100 ns for global reset to finish
        #100;
        
        $display("Starting Test...");

        // Test Case 1: Generated from Python
        data_in = {input_hex};
        expected_out = {output_hex};
        
        #10;
        
        if (data_out === expected_out) begin
            $display("PASS: Input=%h", data_in);
            $display("      Output=%h", data_out);
        end else begin
            $display("FAIL: Input=%h", data_in);
            $display("      Expected=%h", expected_out);
            $display("      Got     =%h", data_out);
            
            // Debugging specific symbols
            $display("Debug Symbol 0 (Sys): Exp=%h, Got=%h", expected_out[9:0], data_out[9:0]);
            $display("Debug Symbol 5 (Par): Exp=%h, Got=%h", expected_out[59:50], data_out[59:50]);
        end

        $finish;
    end
      
endmodule
"""
    with open("../sim/csnc_tb.v", "w") as f:
        f.write(tb_content)
    print("Testbench generated: ../sim/csnc_tb.v")

if __name__ == "__main__":
    generate_tb()
