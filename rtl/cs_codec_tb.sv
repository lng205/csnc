//-----------------------------------------------------------------------------
// Testbench: cs_codec_tb
// Description: Testbench for (2,3) MDS Codec
//              Tests encoding and decoding with various erasure patterns
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module cs_codec_tb;

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter WIDTH = 4;
    parameter CLK_PERIOD = 10;

    //-------------------------------------------------------------------------
    // Signals
    //-------------------------------------------------------------------------
    logic                 clk;
    logic                 rst_n;
    
    // Encoder signals
    logic                 enc_valid_in;
    logic [WIDTH-1:0]     enc_data_0;
    logic [WIDTH-1:0]     enc_data_1;
    logic                 enc_valid_out;
    logic [WIDTH-1:0]     coded_0;
    logic [WIDTH-1:0]     coded_1;
    logic [WIDTH-1:0]     coded_2;
    
    // Decoder signals
    logic                 dec_valid_in;
    logic [2:0]           erasure;
    logic [WIDTH-1:0]     dec_coded_0;
    logic [WIDTH-1:0]     dec_coded_1;
    logic [WIDTH-1:0]     dec_coded_2;
    logic                 dec_valid_out;
    logic                 decode_ok;
    logic [WIDTH-1:0]     dec_data_0;
    logic [WIDTH-1:0]     dec_data_1;

    // Test tracking
    int test_count;
    int pass_count;

    //-------------------------------------------------------------------------
    // DUT instantiation
    //-------------------------------------------------------------------------
    cs_encoder_2_3 #(
        .WIDTH (WIDTH)
    ) u_encoder (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (enc_valid_in),
        .data_0    (enc_data_0),
        .data_1    (enc_data_1),
        .valid_out (enc_valid_out),
        .coded_0   (coded_0),
        .coded_1   (coded_1),
        .coded_2   (coded_2)
    );

    cs_decoder_2_3 #(
        .WIDTH (WIDTH)
    ) u_decoder (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (dec_valid_in),
        .erasure   (erasure),
        .coded_0   (dec_coded_0),
        .coded_1   (dec_coded_1),
        .coded_2   (dec_coded_2),
        .valid_out (dec_valid_out),
        .decode_ok (decode_ok),
        .data_0    (dec_data_0),
        .data_1    (dec_data_1)
    );

    //-------------------------------------------------------------------------
    // Clock generation
    //-------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //-------------------------------------------------------------------------
    // Test task: encode then decode with specified erasure
    //-------------------------------------------------------------------------
    task automatic test_codec(
        input [WIDTH-1:0] d0,
        input [WIDTH-1:0] d1,
        input [2:0]       erase_pattern,
        input string      test_name
    );
        logic [WIDTH-1:0] saved_d0, saved_d1;
        logic [WIDTH-1:0] c0, c1, c2;
        
        saved_d0 = d0;
        saved_d1 = d1;
        test_count++;
        
        $display("\n--- Test %0d: %s ---", test_count, test_name);
        $display("Input: data_0=0x%h, data_1=0x%h, erasure=%b", d0, d1, erase_pattern);
        
        // Encode
        @(posedge clk);
        enc_valid_in = 1;
        enc_data_0 = d0;
        enc_data_1 = d1;
        
        @(posedge clk);
        enc_valid_in = 0;
        
        @(posedge clk);  // Wait for encoder output
        c0 = coded_0;
        c1 = coded_1;
        c2 = coded_2;
        $display("Encoded: coded_0=0x%h, coded_1=0x%h, coded_2=0x%h", c0, c1, c2);
        
        // Decode with erasure
        @(posedge clk);
        dec_valid_in = 1;
        erasure = erase_pattern;
        dec_coded_0 = (erase_pattern[0]) ? 4'hX : c0;  // Mark erased as X
        dec_coded_1 = (erase_pattern[1]) ? 4'hX : c1;
        dec_coded_2 = (erase_pattern[2]) ? 4'hX : c2;
        
        @(posedge clk);
        dec_valid_in = 0;
        
        @(posedge clk);  // Wait for decoder output
        @(posedge clk);  // Additional cycle for combinational to settle
        
        $display("Decoded: data_0=0x%h, data_1=0x%h, ok=%b", dec_data_0, dec_data_1, decode_ok);
        
        // Check results
        if (erase_pattern == 3'b011 || erase_pattern == 3'b101 || 
            erase_pattern == 3'b110 || erase_pattern == 3'b111) begin
            // Multiple erasures - should fail
            if (!decode_ok) begin
                $display("PASS: Correctly detected unrecoverable erasure");
                pass_count++;
            end else begin
                $display("FAIL: Should have reported decode failure");
            end
        end else begin
            // Single or no erasure - should succeed
            if (decode_ok && dec_data_0 == saved_d0 && dec_data_1 == saved_d1) begin
                $display("PASS: Data recovered correctly");
                pass_count++;
            end else begin
                $display("FAIL: Expected data_0=0x%h, data_1=0x%h", saved_d0, saved_d1);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Main test sequence
    //-------------------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("  CS-FEC (2,3) Codec Testbench");
        $display("========================================");
        
        // Initialize
        rst_n = 0;
        enc_valid_in = 0;
        dec_valid_in = 0;
        enc_data_0 = 0;
        enc_data_1 = 0;
        erasure = 0;
        dec_coded_0 = 0;
        dec_coded_1 = 0;
        dec_coded_2 = 0;
        test_count = 0;
        pass_count = 0;
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // Test 1: No erasure
        test_codec(4'hA, 4'h5, 3'b000, "No erasure");
        
        // Test 2: Data 0 erased
        test_codec(4'hA, 4'h5, 3'b001, "Data 0 erased");
        
        // Test 3: Data 1 erased
        test_codec(4'hA, 4'h5, 3'b010, "Data 1 erased");
        
        // Test 4: Parity erased (should still work)
        test_codec(4'hA, 4'h5, 3'b100, "Parity erased");
        
        // Test 5: Different data, data 0 erased
        test_codec(4'hF, 4'h3, 3'b001, "Different data, D0 erased");
        
        // Test 6: All zeros
        test_codec(4'h0, 4'h0, 3'b001, "All zeros, D0 erased");
        
        // Test 7: All ones
        test_codec(4'hF, 4'hF, 3'b010, "All ones, D1 erased");
        
        // Test 8: Two erasures (should fail)
        test_codec(4'hA, 4'h5, 3'b011, "Two erasures (expect fail)");
        
        // Test 9: Random pattern
        test_codec(4'h7, 4'hB, 3'b001, "Random pattern");
        
        // Test 10: Edge case
        test_codec(4'h1, 4'h8, 3'b010, "Edge case");
        
        // Summary
        repeat(5) @(posedge clk);
        $display("\n========================================");
        $display("  Test Summary: %0d/%0d passed", pass_count, test_count);
        $display("========================================");
        
        if (pass_count == test_count) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end

    //-------------------------------------------------------------------------
    // Timeout watchdog
    //-------------------------------------------------------------------------
    initial begin
        #10000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
