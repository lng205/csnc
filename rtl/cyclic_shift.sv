//-----------------------------------------------------------------------------
// Module: cyclic_shift
// Description: Parameterized cyclic right shift module
//              Shifts input by SHIFT_AMT positions to the right (circular)
//-----------------------------------------------------------------------------

module cyclic_shift #(
    parameter WIDTH     = 4,        // Data width (L-1)
    parameter SHIFT_AMT = 0         // Shift amount (0 to WIDTH-1)
) (
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    // Cyclic right shift: data_out[i] = data_in[(i + SHIFT_AMT) % WIDTH]
    generate
        genvar i;
        for (i = 0; i < WIDTH; i = i + 1) begin : shift_gen
            assign data_out[i] = data_in[(i + SHIFT_AMT) % WIDTH];
        end
    endgenerate

endmodule
