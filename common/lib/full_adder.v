// one-bit full adder
//
//   sum  = a ^ b ^ cin
//   cout = (a & b) | (cin & (a ^ b))

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
  wire axb;  // a ^ b
  wire c1;  // a & b
  wire c2;  // cin & (a ^ b)

  xor (axb, a, b);
  xor (sum, axb, cin);
  and (c1, a, b);
  and (c2, axb, cin);
  or (cout, c1, c2);
endmodule
