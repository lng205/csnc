`timescale 1ns / 1ps

module fec_codec_tb;

  localparam int M      = 3;
  localparam int WIDTH  = 11;
  localparam int DATA_W = WIDTH - 1;

  logic [DATA_W-1:0] symbols_in [M];
  logic [DATA_W-1:0] symbols_ref[M];
  logic [WIDTH-1:0]  decode_coeffs [M][M];
  logic [WIDTH-1:0]  encode_coeffs [M][M];

  logic [DATA_W-1:0] symbols_out    [M];
  logic [WIDTH-1:0]  lifted_symbols [M];
  logic [WIDTH-1:0]  decoded_symbols[M];
  logic [WIDTH-1:0]  encoded_symbols[M];

  fec_codec #(
    .M(M),
    .WIDTH(WIDTH)
  ) dut (
    .symbols_in     (symbols_in),
    .decode_coeffs  (decode_coeffs),
    .encode_coeffs  (encode_coeffs),
    .symbols_out    (symbols_out),
    .lifted_symbols (lifted_symbols),
    .decoded_symbols(decoded_symbols),
    .encoded_symbols(encoded_symbols)
  );

  task automatic load_example_coeffs();
    // Coefficients generated from matrix_test.py with seed=42, packets=[0,3,4]
    decode_coeffs[0][0] = 11'd1;
    decode_coeffs[0][1] = 11'd511;
    decode_coeffs[0][2] = 11'd256;

    decode_coeffs[1][0] = 11'd0;
    decode_coeffs[1][1] = 11'd682;
    decode_coeffs[1][2] = 11'd853;

    decode_coeffs[2][0] = 11'd0;
    decode_coeffs[2][1] = 11'd853;
    decode_coeffs[2][2] = 11'd597;

    encode_coeffs[0][0] = 11'd1;
    encode_coeffs[0][1] = 11'd1;
    encode_coeffs[0][2] = 11'd1;

    encode_coeffs[1][0] = 11'd0;
    encode_coeffs[1][1] = 11'd2;
    encode_coeffs[1][2] = 11'd4;

    encode_coeffs[2][0] = 11'd0;
    encode_coeffs[2][1] = 11'd4;
    encode_coeffs[2][2] = 11'd16;
  endtask

  task automatic drive_payload();
    // Deterministic payload matches matrix_test.py convention (seed 42).
    symbols_in[0] = 10'd753;
    symbols_in[1] = 10'd1000;
    symbols_in[2] = 10'd748;
    symbols_ref   = symbols_in;
  endtask

  initial begin
    load_example_coeffs();
    drive_payload();

    #1ns;

    if (lifted_symbols[0] !== 11'd753 ||
        lifted_symbols[1] !== 11'd1000 ||
        lifted_symbols[2] !== 11'd748) begin
      $error("Lift stage mismatch: %p", lifted_symbols);
    end

    if (decoded_symbols[0] !== 11'd1954 ||
        decoded_symbols[1] !== 11'd305  ||
        decoded_symbols[2] !== 11'd1122) begin
      $error("Decode stage mismatch: %p", decoded_symbols);
    end

    if (encoded_symbols[0] !== 11'd753 ||
        encoded_symbols[1] !== 11'd1000 ||
        encoded_symbols[2] !== 11'd748) begin
      $error("Encode stage mismatch: %p", encoded_symbols);
    end

    if (symbols_out !== symbols_ref) begin
      $error("FEC codec mismatch. expected=%p got=%p", symbols_ref, symbols_out);
    end else begin
      $display("FEC codec passthrough test passed.");
    end

    $finish;
  end

endmodule : fec_codec_tb
