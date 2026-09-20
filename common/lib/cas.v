// CAS: controlled adder/subtractor
//   b' = b ^ op ;  {cout, s} = a + b' + cin
// op = 1 subtracts (two's complement: b inverted)
module cas #(
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire a,    // partial-remainder bit from the row above
    input  wire b,    // divisor bit (tied to 0 in the sign-extension cell)
    input  wire cin,  // carry in, from the cell to the right
    input  wire op,   // row operation: 1 = subtract, 0 = add
    output wire s,    // sum bit, down to the next row
    output wire cout  // carry out, to the cell on the left
);
  wire bx;  // b ^ op

  xor #(D) (bx, b, op);

  full_adder #(D) fa (
      .a   (a),
      .b   (bx),
      .cin (cin),
      .sum (s),
      .cout(cout)
  );
endmodule
