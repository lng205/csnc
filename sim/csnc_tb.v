
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
        data_in = 50'h0afe7b07f4e47;
        expected_out = 90'h3aa2b2e0f68afe7b07f4e47;
        
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
