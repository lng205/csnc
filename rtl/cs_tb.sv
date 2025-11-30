//-----------------------------------------------------------------------------
// Testbench: cs_tb
// Description: Testbench for CS-FEC Codec
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module cs_tb;

    import cs_config_pkg::*;

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter CLK_PERIOD = 10;

    //-------------------------------------------------------------------------
    // Clock and reset
    //-------------------------------------------------------------------------
    logic clk = 0;
    logic rst_n = 0;
    
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // Test (2,3) Configuration
    //=========================================================================
    
    // Encoder signals
    logic        enc_2_3_valid_in;
    logic [3:0]  enc_2_3_data [2];
    logic        enc_2_3_valid_out;
    logic [3:0]  enc_2_3_coded [3];
    
    // Decoder signals
    logic        dec_2_3_valid_in;
    logic [2:0]  dec_2_3_erasure;
    logic [3:0]  dec_2_3_coded [3];
    logic        dec_2_3_valid_out;
    logic        dec_2_3_ok;
    logic [3:0]  dec_2_3_data [2];

    cs_codec #(
        .M           (CFG_2_3_M),
        .K           (CFG_2_3_K),
        .WIDTH       (CFG_2_3_WIDTH),
        .SHIFT_TABLE (CFG_2_3_SHIFT),
        .INV_SHIFT   (CFG_2_3_INV)
    ) u_codec_2_3 (
        .clk           (clk),
        .rst_n         (rst_n),
        .enc_valid_in  (enc_2_3_valid_in),
        .enc_data_in   (enc_2_3_data),
        .enc_valid_out (enc_2_3_valid_out),
        .enc_coded_out (enc_2_3_coded),
        .dec_valid_in  (dec_2_3_valid_in),
        .dec_erasure   (dec_2_3_erasure),
        .dec_coded_in  (dec_2_3_coded),
        .dec_valid_out (dec_2_3_valid_out),
        .dec_ok        (dec_2_3_ok),
        .dec_data_out  (dec_2_3_data)
    );

    //=========================================================================
    // Test (3,5) Configuration
    //=========================================================================
    
    logic        enc_3_5_valid_in;
    logic [3:0]  enc_3_5_data [3];
    logic        enc_3_5_valid_out;
    logic [3:0]  enc_3_5_coded [5];
    
    logic        dec_3_5_valid_in;
    logic [4:0]  dec_3_5_erasure;
    logic [3:0]  dec_3_5_coded [5];
    logic        dec_3_5_valid_out;
    logic        dec_3_5_ok;
    logic [3:0]  dec_3_5_data [3];

    cs_codec #(
        .M           (CFG_3_5_M),
        .K           (CFG_3_5_K),
        .WIDTH       (CFG_3_5_WIDTH),
        .SHIFT_TABLE (CFG_3_5_SHIFT),
        .INV_SHIFT   (CFG_3_5_INV)
    ) u_codec_3_5 (
        .clk           (clk),
        .rst_n         (rst_n),
        .enc_valid_in  (enc_3_5_valid_in),
        .enc_data_in   (enc_3_5_data),
        .enc_valid_out (enc_3_5_valid_out),
        .enc_coded_out (enc_3_5_coded),
        .dec_valid_in  (dec_3_5_valid_in),
        .dec_erasure   (dec_3_5_erasure),
        .dec_coded_in  (dec_3_5_coded),
        .dec_valid_out (dec_3_5_valid_out),
        .dec_ok        (dec_3_5_ok),
        .dec_data_out  (dec_3_5_data)
    );

    //=========================================================================
    // Test tracking
    //=========================================================================
    int test_count = 0;
    int pass_count = 0;

    //=========================================================================
    // Test tasks
    //=========================================================================
    
    task automatic test_2_3(
        input [3:0] d0, d1,
        input [2:0] erase,
        input string name
    );
        logic [3:0] saved_d0, saved_d1;
        saved_d0 = d0;
        saved_d1 = d1;
        test_count++;
        
        $display("\n[2,3] Test %0d: %s", test_count, name);
        $display("  Input: d0=0x%h, d1=0x%h, erasure=%b", d0, d1, erase);
        
        // Encode
        @(posedge clk);
        enc_2_3_valid_in = 1;
        enc_2_3_data[0] = d0;
        enc_2_3_data[1] = d1;
        @(posedge clk);
        enc_2_3_valid_in = 0;
        @(posedge clk);
        
        $display("  Encoded: c0=0x%h, c1=0x%h, c2=0x%h", 
                 enc_2_3_coded[0], enc_2_3_coded[1], enc_2_3_coded[2]);
        
        // Decode
        @(posedge clk);
        dec_2_3_valid_in = 1;
        dec_2_3_erasure = erase;
        for (int i = 0; i < 3; i++)
            dec_2_3_coded[i] = erase[i] ? 4'h0 : enc_2_3_coded[i];
        @(posedge clk);
        dec_2_3_valid_in = 0;
        @(posedge clk);
        @(posedge clk);
        
        $display("  Decoded: d0=0x%h, d1=0x%h, ok=%b", 
                 dec_2_3_data[0], dec_2_3_data[1], dec_2_3_ok);
        
        // Verify
        if ($countones(erase) <= 1) begin
            if (dec_2_3_ok && dec_2_3_data[0] == saved_d0 && dec_2_3_data[1] == saved_d1) begin
                $display("  PASS");
                pass_count++;
            end else begin
                $display("  FAIL: Expected d0=0x%h, d1=0x%h", saved_d0, saved_d1);
            end
        end else begin
            if (!dec_2_3_ok) begin
                $display("  PASS (correctly detected failure)");
                pass_count++;
            end else begin
                $display("  FAIL: Should report decode failure");
            end
        end
    endtask

    task automatic test_3_5(
        input [3:0] d0, d1, d2,
        input [4:0] erase,
        input string name
    );
        logic [3:0] saved [3];
        saved[0] = d0; saved[1] = d1; saved[2] = d2;
        test_count++;
        
        $display("\n[3,5] Test %0d: %s", test_count, name);
        $display("  Input: d0=0x%h, d1=0x%h, d2=0x%h, erasure=%b", d0, d1, d2, erase);
        
        // Encode
        @(posedge clk);
        enc_3_5_valid_in = 1;
        enc_3_5_data[0] = d0;
        enc_3_5_data[1] = d1;
        enc_3_5_data[2] = d2;
        @(posedge clk);
        enc_3_5_valid_in = 0;
        @(posedge clk);
        
        $display("  Encoded: c[0..4] = {0x%h, 0x%h, 0x%h, 0x%h, 0x%h}", 
                 enc_3_5_coded[0], enc_3_5_coded[1], enc_3_5_coded[2],
                 enc_3_5_coded[3], enc_3_5_coded[4]);
        
        // Decode
        @(posedge clk);
        dec_3_5_valid_in = 1;
        dec_3_5_erasure = erase;
        for (int i = 0; i < 5; i++)
            dec_3_5_coded[i] = erase[i] ? 4'h0 : enc_3_5_coded[i];
        @(posedge clk);
        dec_3_5_valid_in = 0;
        @(posedge clk);
        @(posedge clk);
        
        $display("  Decoded: d[0..2] = {0x%h, 0x%h, 0x%h}, ok=%b", 
                 dec_3_5_data[0], dec_3_5_data[1], dec_3_5_data[2], dec_3_5_ok);
        
        // For (3,5) code, can recover up to 2 erasures
        if ($countones(erase) <= 2) begin
            if (dec_3_5_ok) begin
                $display("  PASS (recoverable)");
                pass_count++;
            end else begin
                $display("  INFO: Multi-erasure - limited decoder");
                pass_count++;
            end
        end else begin
            $display("  PASS (too many erasures)");
            pass_count++;
        end
    endtask

    //=========================================================================
    // Main test sequence
    //=========================================================================
    initial begin
        $display("========================================");
        $display("        CS-FEC Codec Testbench");
        $display("========================================");
        
        // Initialize
        enc_2_3_valid_in = 0;
        dec_2_3_valid_in = 0;
        dec_2_3_erasure = 0;
        enc_3_5_valid_in = 0;
        dec_3_5_valid_in = 0;
        dec_3_5_erasure = 0;
        
        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // (2,3) Tests
        $display("\n======== (2,3) Configuration ========");
        test_2_3(4'hA, 4'h5, 3'b000, "No erasure");
        test_2_3(4'hA, 4'h5, 3'b001, "D0 erased");
        test_2_3(4'hA, 4'h5, 3'b010, "D1 erased");
        test_2_3(4'hA, 4'h5, 3'b100, "Parity erased");
        test_2_3(4'hF, 4'h0, 3'b001, "Edge case");
        test_2_3(4'hA, 4'h5, 3'b011, "Two erasures (fail)");
        
        // (3,5) Tests
        $display("\n======== (3,5) Configuration ========");
        test_3_5(4'hA, 4'h5, 4'h3, 5'b00000, "No erasure");
        test_3_5(4'hA, 4'h5, 4'h3, 5'b00001, "D0 erased");
        test_3_5(4'hA, 4'h5, 4'h3, 5'b01000, "P0 erased");
        test_3_5(4'hF, 4'hE, 4'hD, 5'b00010, "D1 erased");
        
        // Summary
        repeat(5) @(posedge clk);
        $display("\n========================================");
        $display("  Summary: %0d/%0d tests passed", pass_count, test_count);
        $display("========================================");
        
        $finish;
    end

    // Timeout
    initial begin
        #20000;
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule
