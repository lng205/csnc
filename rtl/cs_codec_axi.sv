//-----------------------------------------------------------------------------
// Module: cs_codec_axi
// Description: AXI-Lite wrapper for CS-FEC Codec
//              Allows PS to control PL accelerator via memory-mapped registers
//
// Register Map (32-bit aligned):
//   0x00: CTRL     - [0]: enc_start, [1]: dec_start, [31]: busy
//   0x04: STATUS   - [0]: enc_done, [1]: dec_done, [2]: dec_ok
//   0x08: CONFIG   - [7:0]: erasure mask for decoder
//   0x10-0x1C: DATA_IN[0-3]   - Encoder input data (M symbols)
//   0x20-0x3C: CODED_OUT[0-7] - Encoder output / Decoder input (K symbols)
//   0x40-0x4C: DATA_OUT[0-3]  - Decoder output data (M symbols)
//
// Usage:
//   Encode: Write DATA_IN -> Set enc_start -> Wait enc_done -> Read CODED_OUT
//   Decode: Write CODED_OUT + erasure -> Set dec_start -> Wait dec_done -> Read DATA_OUT
//-----------------------------------------------------------------------------

module cs_codec_axi #(
    parameter M     = 2,
    parameter K     = 3,
    parameter WIDTH = 4,
    parameter logic [3:0] SHIFT_TABLE [K-M][M] = '{default: '{default: 0}},
    parameter logic [3:0] INV_SHIFT   [K-M][M] = '{default: '{default: 0}}
) (
    // AXI-Lite Slave Interface
    input  logic        s_axi_aclk,
    input  logic        s_axi_aresetn,
    
    // Write address channel
    input  logic [5:0]  s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    
    // Write data channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    
    // Write response channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    
    // Read address channel
    input  logic [5:0]  s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    
    // Read data channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready
);

    //-------------------------------------------------------------------------
    // Register addresses
    //-------------------------------------------------------------------------
    localparam ADDR_CTRL      = 6'h00;
    localparam ADDR_STATUS    = 6'h04;
    localparam ADDR_CONFIG    = 6'h08;
    localparam ADDR_DATA_IN   = 6'h10;  // 0x10-0x1C (4 registers)
    localparam ADDR_CODED     = 6'h20;  // 0x20-0x3C (8 registers)
    localparam ADDR_DATA_OUT  = 6'h40;  // 0x40-0x4C (4 registers)

    //-------------------------------------------------------------------------
    // Internal signals
    //-------------------------------------------------------------------------
    logic [31:0] reg_ctrl;
    logic [31:0] reg_status;
    logic [31:0] reg_config;
    logic [31:0] reg_data_in [4];
    logic [31:0] reg_coded [8];
    logic [31:0] reg_data_out [4];
    
    // Codec signals
    logic             enc_start, dec_start;
    logic             enc_valid_in, dec_valid_in;
    logic             enc_valid_out, dec_valid_out;
    logic             dec_ok;
    logic [WIDTH-1:0] enc_data_in [M];
    logic [WIDTH-1:0] enc_coded_out [K];
    logic [WIDTH-1:0] dec_coded_in [K];
    logic [WIDTH-1:0] dec_data_out [M];
    logic [K-1:0]     dec_erasure;
    
    // State machine
    typedef enum logic [2:0] {
        IDLE,
        ENC_PROCESS,
        ENC_DONE,
        DEC_PROCESS,
        DEC_DONE
    } state_t;
    state_t state;

    //-------------------------------------------------------------------------
    // CS-FEC Codec instance
    //-------------------------------------------------------------------------
    cs_codec #(
        .M           (M),
        .K           (K),
        .WIDTH       (WIDTH),
        .SHIFT_TABLE (SHIFT_TABLE),
        .INV_SHIFT   (INV_SHIFT)
    ) u_codec (
        .clk            (s_axi_aclk),
        .rst_n          (s_axi_aresetn),
        .enc_valid_in   (enc_valid_in),
        .enc_data_in    (enc_data_in),
        .enc_valid_out  (enc_valid_out),
        .enc_coded_out  (enc_coded_out),
        .dec_valid_in   (dec_valid_in),
        .dec_erasure    (dec_erasure),
        .dec_coded_in   (dec_coded_in),
        .dec_valid_out  (dec_valid_out),
        .dec_ok         (dec_ok),
        .dec_data_out   (dec_data_out)
    );

    //-------------------------------------------------------------------------
    // Data mapping
    //-------------------------------------------------------------------------
    generate
        genvar i;
        for (i = 0; i < M; i++) begin : gen_enc_data
            assign enc_data_in[i] = reg_data_in[i][WIDTH-1:0];
        end
        for (i = 0; i < K; i++) begin : gen_dec_data
            assign dec_coded_in[i] = reg_coded[i][WIDTH-1:0];
        end
    endgenerate
    
    assign dec_erasure = reg_config[K-1:0];
    assign enc_start = reg_ctrl[0];
    assign dec_start = reg_ctrl[1];

    //-------------------------------------------------------------------------
    // State machine
    //-------------------------------------------------------------------------
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            state <= IDLE;
            enc_valid_in <= 1'b0;
            dec_valid_in <= 1'b0;
            reg_status <= 32'h0;
            for (int j = 0; j < 4; j++) reg_data_out[j] <= 32'h0;
            for (int j = 0; j < 8; j++) if (j >= K) reg_coded[j] <= 32'h0;
        end else begin
            enc_valid_in <= 1'b0;
            dec_valid_in <= 1'b0;
            
            case (state)
                IDLE: begin
                    reg_status[31] <= 1'b0;  // Not busy
                    if (enc_start) begin
                        state <= ENC_PROCESS;
                        enc_valid_in <= 1'b1;
                        reg_status[31] <= 1'b1;  // Busy
                        reg_status[0] <= 1'b0;   // Clear enc_done
                    end else if (dec_start) begin
                        state <= DEC_PROCESS;
                        dec_valid_in <= 1'b1;
                        reg_status[31] <= 1'b1;  // Busy
                        reg_status[1] <= 1'b0;   // Clear dec_done
                    end
                end
                
                ENC_PROCESS: begin
                    if (enc_valid_out) begin
                        state <= ENC_DONE;
                        // Capture encoded output
                        for (int j = 0; j < K; j++) begin
                            reg_coded[j] <= {{(32-WIDTH){1'b0}}, enc_coded_out[j]};
                        end
                    end
                end
                
                ENC_DONE: begin
                    reg_status[0] <= 1'b1;   // enc_done
                    reg_status[31] <= 1'b0;  // Not busy
                    if (!enc_start) state <= IDLE;
                end
                
                DEC_PROCESS: begin
                    if (dec_valid_out) begin
                        state <= DEC_DONE;
                        reg_status[2] <= dec_ok;
                        // Capture decoded output
                        for (int j = 0; j < M; j++) begin
                            reg_data_out[j] <= {{(32-WIDTH){1'b0}}, dec_data_out[j]};
                        end
                    end
                end
                
                DEC_DONE: begin
                    reg_status[1] <= 1'b1;   // dec_done
                    reg_status[31] <= 1'b0;  // Not busy
                    if (!dec_start) state <= IDLE;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // AXI-Lite Write Logic
    //-------------------------------------------------------------------------
    logic aw_en;
    
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
            aw_en <= 1'b1;
            reg_ctrl <= 32'h0;
            reg_config <= 32'h0;
            for (int j = 0; j < 4; j++) reg_data_in[j] <= 32'h0;
            for (int j = 0; j < 8; j++) reg_coded[j] <= 32'h0;
        end else begin
            // Write address ready
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
            end
            
            // Write data ready
            if (~s_axi_wready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
            
            // Write response
            if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid && ~s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;
                
                // Register write
                case (s_axi_awaddr[5:2])
                    4'h0: reg_ctrl <= s_axi_wdata;
                    4'h2: reg_config <= s_axi_wdata;
                    4'h4: reg_data_in[0] <= s_axi_wdata;
                    4'h5: reg_data_in[1] <= s_axi_wdata;
                    4'h6: reg_data_in[2] <= s_axi_wdata;
                    4'h7: reg_data_in[3] <= s_axi_wdata;
                    4'h8: reg_coded[0] <= s_axi_wdata;
                    4'h9: reg_coded[1] <= s_axi_wdata;
                    4'hA: reg_coded[2] <= s_axi_wdata;
                    4'hB: reg_coded[3] <= s_axi_wdata;
                    4'hC: reg_coded[4] <= s_axi_wdata;
                    4'hD: reg_coded[5] <= s_axi_wdata;
                    4'hE: reg_coded[6] <= s_axi_wdata;
                    4'hF: reg_coded[7] <= s_axi_wdata;
                endcase
            end
            
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_en <= 1'b1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // AXI-Lite Read Logic
    //-------------------------------------------------------------------------
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'h0;
            s_axi_rresp <= 2'b00;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end
            
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                
                // Register read
                case (s_axi_araddr[5:2])
                    4'h0: s_axi_rdata <= reg_ctrl;
                    4'h1: s_axi_rdata <= reg_status;
                    4'h2: s_axi_rdata <= reg_config;
                    4'h4: s_axi_rdata <= reg_data_in[0];
                    4'h5: s_axi_rdata <= reg_data_in[1];
                    4'h6: s_axi_rdata <= reg_data_in[2];
                    4'h7: s_axi_rdata <= reg_data_in[3];
                    4'h8: s_axi_rdata <= reg_coded[0];
                    4'h9: s_axi_rdata <= reg_coded[1];
                    4'hA: s_axi_rdata <= reg_coded[2];
                    4'hB: s_axi_rdata <= reg_coded[3];
                    4'hC: s_axi_rdata <= reg_coded[4];
                    4'hD: s_axi_rdata <= reg_coded[5];
                    4'hE: s_axi_rdata <= reg_coded[6];
                    4'hF: s_axi_rdata <= reg_coded[7];
                    default: s_axi_rdata <= 32'h0;
                endcase
                
                // DATA_OUT registers (0x40-0x4C -> 4'h10-4'h13)
                if (s_axi_araddr[5:4] == 2'b01) begin
                    s_axi_rdata <= reg_data_out[s_axi_araddr[3:2]];
                end
            end
            
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

