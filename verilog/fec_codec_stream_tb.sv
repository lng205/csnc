`timescale 1ns / 1ps

module fec_codec_stream_tb;

  localparam int M        = 3;
  localparam int WIDTH    = 11;
  localparam int DATA_W   = WIDTH - 1;
  localparam int INDEX_W  = (M * M <= 1) ? 1 : $clog2(M * M);

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n;

  logic cfg_we;
  logic cfg_select;
  logic [INDEX_W-1:0] cfg_index;
  logic [WIDTH-1:0]   cfg_data;

  logic                         symbols_valid;
  logic                         symbols_ready;
  logic [M*DATA_W-1:0]         symbols_in_flat;

  logic                         symbols_out_valid;
  logic                         symbols_out_ready;
  logic [M*DATA_W-1:0]         symbols_out_flat;

  logic [M*WIDTH-1:0]          debug_lifted_flat;
  logic [M*WIDTH-1:0]          debug_decoded_flat;
  logic [M*WIDTH-1:0]          debug_encoded_flat;

  fec_codec_stream #(
    .M       (M),
    .WIDTH   (WIDTH),
    .DATA_W  (DATA_W)
  ) dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .cfg_we             (cfg_we),
    .cfg_select         (cfg_select),
    .cfg_index          (cfg_index),
    .cfg_data           (cfg_data),
    .symbols_valid      (symbols_valid),
    .symbols_ready      (symbols_ready),
    .symbols_in_flat    (symbols_in_flat),
    .symbols_out_valid  (symbols_out_valid),
    .symbols_out_ready  (symbols_out_ready),
    .symbols_out_flat   (symbols_out_flat),
    .debug_lifted_flat  (debug_lifted_flat),
    .debug_decoded_flat (debug_decoded_flat),
    .debug_encoded_flat (debug_encoded_flat)
  );

  task automatic cfg_write(input bit encode_sel, input int row, input int col, input int value);
    cfg_select = encode_sel;
    cfg_index  = row * M + col;
    cfg_data   = value[WIDTH-1:0];
    cfg_we     = 1'b1;
    @(posedge clk);
    cfg_we     = 1'b0;
    cfg_select = 1'b0;
    cfg_index  = '0;
    cfg_data   = '0;
  endtask

  task automatic send_symbol_vector(input int values[M]);
    logic [M*DATA_W-1:0] payload;
    for (int idx = 0; idx < M; idx++) begin
      payload[idx * DATA_W +: DATA_W] = values[idx][DATA_W-1:0];
    end
    @(posedge clk);
    while (!symbols_ready) begin
      @(posedge clk);
    end

    symbols_in_flat = payload;
    symbols_valid   = 1'b1;
    @(posedge clk);
    #1ps;
    symbols_valid   = 1'b0;
    symbols_in_flat = '0;
  endtask

  function automatic void expect_vector(
    input string label,
    input logic [M*DATA_W-1:0] got,
    input int expected[M]
  );
    for (int idx = 0; idx < M; idx++) begin
      logic [DATA_W-1:0] slice;
      slice = got[idx * DATA_W +: DATA_W];
      if (slice !== expected[idx][DATA_W-1:0]) begin
        $error("%s mismatch at symbol %0d. expected=%0d got=%0d", label, idx, expected[idx], slice);
      end
    end
  endfunction

  function automatic void expect_debug(
    input string label,
    input logic [M*WIDTH-1:0] got,
    input int expected[M]
  );
    for (int idx = 0; idx < M; idx++) begin
      logic [WIDTH-1:0] slice;
      slice = got[idx * WIDTH +: WIDTH];
      if (slice !== expected[idx][WIDTH-1:0]) begin
        $error("%s mismatch at symbol %0d. expected=%0d got=%0d", label, idx, expected[idx], slice);
      end
    end
  endfunction

  int decode_ref [M][M] = '{
    '{1,   511, 256},
    '{0,   682, 853},
    '{0,   853, 597}
  };

  int encode_ref [M][M] = '{
    '{1, 1,  1},
    '{0, 2,  4},
    '{0, 4, 16}
  };

  int payload_ref [M] = '{753, 1000, 748};
  int decoded_ref [M] = '{1954, 305, 1122};

  initial begin
    rst_n               = 1'b0;
    cfg_we              = 1'b0;
    cfg_select          = 1'b0;
    cfg_index           = '0;
    cfg_data            = '0;
    symbols_valid       = 1'b0;
    symbols_in_flat     = '0;
    symbols_out_ready   = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Load coefficient matrices
    for (int r = 0; r < M; r++) begin
      for (int c = 0; c < M; c++) begin
        cfg_write(1'b0, r, c, decode_ref[r][c]);
      end
    end
    for (int r = 0; r < M; r++) begin
      for (int c = 0; c < M; c++) begin
        cfg_write(1'b1, r, c, encode_ref[r][c]);
      end
    end

    // Drive payload
    send_symbol_vector(payload_ref);

    // Wait for result
    @(posedge clk);
    wait (symbols_out_valid);
    #1ps;

    expect_vector("symbols_out", symbols_out_flat, payload_ref);
    expect_debug("lifted",  debug_lifted_flat,  payload_ref);
    expect_debug("decoded", debug_decoded_flat, decoded_ref);
    expect_debug("encoded", debug_encoded_flat, payload_ref);

    @(posedge clk);
    #1ps;
    if (!symbols_out_valid) begin
      $display("FEC codec stream test passed.");
    end

    $finish;
  end

endmodule : fec_codec_stream_tb
