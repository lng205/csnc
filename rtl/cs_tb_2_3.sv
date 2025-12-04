//-----------------------------------------------------------------------------
// Testbench: cs_tb_2_3
// Description: Simple testbench for (2, 3) MDS Codec
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module cs_tb_2_3;

    logic clk = 0;
    logic rst_n = 0;
    
    always #5 clk = ~clk;

    // Encoder signals
    logic        enc_valid_in;
    logic [3:0]  enc_data [2];
    logic        enc_valid_out;
    logic [3:0]  enc_coded [3];
    
    // Decoder signals
    logic        dec_valid_in;
    logic [2:0]  dec_erasure;
    logic [3:0]  dec_coded [3];
    logic        dec_valid_out;
    logic        dec_ok;
    logic [3:0]  dec_data [2];

    // Encoder
    cs_encoder_2_3 u_enc (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (enc_valid_in),
        .data_in   (enc_data),
        .valid_out (enc_valid_out),
        .coded_out (enc_coded)
    );

    // Decoder
    cs_decoder_2_3 u_dec (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (dec_valid_in),
        .erasure   (dec_erasure),
        .coded_in  (dec_coded),
        .valid_out (dec_valid_out),
        .decode_ok (dec_ok),
        .data_out  (dec_data)
    );

    // Test tracking
    int tests = 0;
    int passed = 0;

    // Test task
    task automatic run_test(
        input [3:0] d0, d1,
        input [2:0] erase,
        input string name
    );
        logic [3:0] saved_d0, saved_d1;
        saved_d0 = d0;
        saved_d1 = d1;
        tests++;
        
        $display("\n--- Test %0d: %s ---", tests, name);
        $display("Input: d0=0x%h, d1=0x%h, erasure=%b", d0, d1, erase);
        
        // Encode
        @(posedge clk);
        enc_valid_in = 1;
        enc_data[0] = d0;
        enc_data[1] = d1;
        @(posedge clk);
        enc_valid_in = 0;
        @(posedge clk);  // Wait for output
        
        $display("Encoded: c0=0x%h, c1=0x%h, p0=0x%h", enc_coded[0], enc_coded[1], enc_coded[2]);
        
        // Decode
        @(posedge clk);
        dec_valid_in = 1;
        dec_erasure = erase;
        dec_coded[0] = erase[0] ? 4'h0 : enc_coded[0];
        dec_coded[1] = erase[1] ? 4'h0 : enc_coded[1];
        dec_coded[2] = erase[2] ? 4'h0 : enc_coded[2];
        @(posedge clk);
        dec_valid_in = 0;
        @(posedge clk);  // Wait for output
        
        $display("Decoded: d0=0x%h, d1=0x%h, ok=%b", dec_data[0], dec_data[1], dec_ok);
        
        // Verify
        if (dec_ok && dec_data[0] == saved_d0 && dec_data[1] == saved_d1) begin
            $display("PASS");
            passed++;
        end else begin
            $display("FAIL: Expected d0=0x%h, d1=0x%h", saved_d0, saved_d1);
        end
    endtask

    // Main test
    initial begin
        $display("========================================");
        $display("  (2, 3) MDS Codec Test");
        $display("========================================");
        
        enc_valid_in = 0;
        dec_valid_in = 0;
        dec_erasure = 0;
        
        // Reset
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // Tests
        run_test(4'hA, 4'h5, 3'b000, "No erasure");
        run_test(4'hA, 4'h5, 3'b001, "D0 erased");
        run_test(4'hA, 4'h5, 3'b010, "D1 erased");
        run_test(4'hA, 4'h5, 3'b100, "P0 erased");
        run_test(4'hF, 4'h0, 3'b001, "d0=F d1=0, D0 erased");
        run_test(4'h0, 4'hF, 3'b010, "d0=0 d1=F, D1 erased");
        run_test(4'h1, 4'h1, 3'b001, "d0=1 d1=1, D0 erased");
        
        // Summary
        repeat(3) @(posedge clk);
        $display("\n========================================");
        $display("  Results: %0d/%0d passed", passed, tests);
        $display("========================================");
        
        if (passed == tests)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        
        $finish;
    end

    // Timeout
    initial begin
        #5000;
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule

