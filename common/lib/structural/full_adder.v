`ifndef LAB1_COMMON_LIB_STRUCTURAL_FULL_ADDER_V
`define LAB1_COMMON_LIB_STRUCTURAL_FULL_ADDER_V

// one-bit full adder
//
//   sum  = a ^ b ^ cin
//   cout = (a & b) | (cin & (a ^ b))

module full_adder #(
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire axb;  // a ^ b
    wire c1;  // a & b
    wire c2;  // cin & (a ^ b)

    xor #(D) (axb, a, b);
    xor #(D) (sum, axb, cin);
    and #(D) (c1, a, b);
    and #(D) (c2, axb, cin);
    or #(D) (cout, c1, c2);
endmodule

`endif // LAB1_COMMON_LIB_STRUCTURAL_FULL_ADDER_V
