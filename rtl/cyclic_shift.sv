//-----------------------------------------------------------------------------
// Module: cyclic_shift
// Description: Static cyclic right shifter - shift amount fixed at compile time
//              Pure combinational logic, synthesizes to simple wire routing
//-----------------------------------------------------------------------------

module cyclic_shift #(
    parameter WIDTH     = 4,
    parameter SHIFT_AMT = 0
) (
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);

    // Cyclic right shift: data_out[i] = data_in[(i + SHIFT_AMT) % WIDTH]
    generate
        genvar i;
        for (i = 0; i < WIDTH; i++) begin : shift_gen
            assign data_out[i] = data_in[(i + SHIFT_AMT) % WIDTH];
        end
    endgenerate

endmodule
