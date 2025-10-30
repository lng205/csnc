`timescale 1ns / 1ps

module fec_codec_stream #(
  parameter int M        = 3,
  parameter int WIDTH    = 11,
  parameter int DATA_W   = WIDTH - 1,
  parameter int INDEX_W  = (M * M <= 1) ? 1 : $clog2(M * M)
) (
  input  logic                         clk,
  input  logic                         rst_n,

  // Coefficient configuration
  input  logic                         cfg_we,
  input  logic                         cfg_select,   // 0: decode matrix, 1: encode matrix
  input  logic [INDEX_W-1:0]           cfg_index,
  input  logic [WIDTH-1:0]             cfg_data,

  // Symbol streaming interface
  input  logic                         symbols_valid,
  output logic                         symbols_ready,
  input  logic [M*DATA_W-1:0]          symbols_in_flat,

  output logic                         symbols_out_valid,
  input  logic                         symbols_out_ready,
  output logic [M*DATA_W-1:0]          symbols_out_flat,

  // Debug taps (mirrors Python snapshots)
  output logic [M*WIDTH-1:0]           debug_lifted_flat,
  output logic [M*WIDTH-1:0]           debug_decoded_flat,
  output logic [M*WIDTH-1:0]           debug_encoded_flat
);

  logic [WIDTH-1:0] decode_matrix [M][M];
  logic [WIDTH-1:0] encode_matrix [M][M];

  logic stage0_valid;
  logic [DATA_W-1:0] stage0_symbols [M];

  logic stage1_valid;
  logic [DATA_W-1:0] stage1_symbols [M];
  logic [WIDTH-1:0]  debug_lifted    [M];
  logic [WIDTH-1:0]  debug_decoded   [M];
  logic [WIDTH-1:0]  debug_encoded   [M];

  logic [DATA_W-1:0] core_symbols_out[M];
  logic [WIDTH-1:0]  core_lifted     [M];
  logic [WIDTH-1:0]  core_decoded    [M];
  logic [WIDTH-1:0]  core_encoded    [M];

  logic stage1_ready;
  logic stage0_fire;
  logic stage1_fire;

  assign stage1_ready   = !stage1_valid || symbols_out_ready;
  assign symbols_ready  = !stage0_valid || stage1_ready;
  assign stage0_fire    = symbols_valid && symbols_ready;
  assign stage1_fire    = stage0_valid && stage1_ready;

  // Coefficient store
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int r = 0; r < M; r++) begin
        for (int c = 0; c < M; c++) begin
          decode_matrix[r][c] <= '0;
          encode_matrix[r][c] <= '0;
        end
        decode_matrix[r][r] <= 'd1;
        encode_matrix[r][r] <= 'd1;
      end
    end else begin
      if (cfg_we) begin
        int row;
        int col;
        row = cfg_index / M;
        col = cfg_index % M;
        if (row < M && col < M) begin
          if (cfg_select) begin
            encode_matrix[row][col] <= cfg_data;
          end else begin
            decode_matrix[row][col] <= cfg_data;
          end
        end
      end
    end
  end

  // Stage 0: latch input symbols
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage0_valid <= 1'b0;
      for (int idx = 0; idx < M; idx++) begin
        stage0_symbols[idx] <= '0;
      end
    end else begin
      if (stage0_fire) begin
        for (int idx = 0; idx < M; idx++) begin
          stage0_symbols[idx] <= symbols_in_flat[idx * DATA_W +: DATA_W];
        end
        stage0_valid <= 1'b1;
      end else if (stage1_fire) begin
        stage0_valid <= 1'b0;
      end
    end
  end

  // Core combinational codec
  fec_codec #(
    .M      (M),
    .WIDTH  (WIDTH),
    .DATA_W (DATA_W)
  ) core (
    .symbols_in     (stage0_symbols),
    .decode_coeffs  (decode_matrix),
    .encode_coeffs  (encode_matrix),
    .symbols_out    (core_symbols_out),
    .lifted_symbols (core_lifted),
    .decoded_symbols(core_decoded),
    .encoded_symbols(core_encoded)
  );

  // Stage 1: capture outputs and debug taps
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage1_valid <= 1'b0;
      for (int idx = 0; idx < M; idx++) begin
        stage1_symbols[idx] <= '0;
        debug_lifted[idx]   <= '0;
        debug_decoded[idx]  <= '0;
        debug_encoded[idx]  <= '0;
      end
    end else begin
      if (stage1_fire) begin
        for (int idx = 0; idx < M; idx++) begin
          stage1_symbols[idx] <= core_symbols_out[idx];
          debug_lifted[idx]   <= core_lifted[idx];
          debug_decoded[idx]  <= core_decoded[idx];
          debug_encoded[idx]  <= core_encoded[idx];
        end
        stage1_valid <= 1'b1;
      end else if (symbols_out_ready && stage1_valid) begin
        stage1_valid <= 1'b0;
      end
    end
  end

  assign symbols_out_valid = stage1_valid;

  // Output flattening
  always_comb begin
    for (int idx = 0; idx < M; idx++) begin
      symbols_out_flat[idx * DATA_W +: DATA_W] = stage1_symbols[idx];
      debug_lifted_flat[idx * WIDTH +: WIDTH] = debug_lifted[idx];
      debug_decoded_flat[idx * WIDTH +: WIDTH] = debug_decoded[idx];
      debug_encoded_flat[idx * WIDTH +: WIDTH] = debug_encoded[idx];
    end
  end

endmodule : fec_codec_stream
